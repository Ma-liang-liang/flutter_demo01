/// 一次传输的完整上下文，管理数据包队列、ACK 状态、重试和超时。
///
/// 对应 iOS 参考实现中的 `ActiveTransfer`，纯 Dart 实现。
/// 采用懒加载设计：只保存原始数据，按需生成帧，避免大文件一次性加载
/// 全部帧到内存。
///
/// 生命周期：创建 → `nextPacket()` 循环写入 → 全部 ACK → complete
library;

import 'dart:async';
import 'dart:typed_data';

import 'ble_profile.dart';
import 'ble_protocol.dart';

/// 单个数据包。
class TransferPacket {
  /// 包序号（用于 ACK 匹配）。
  final int sequence;

  /// 编码后的帧数据（含头部或裸数据）。
  final Uint8List data;

  /// 原始 payload 大小（不含头部，用于进度统计）。
  final int payloadSize;

  const TransferPacket({
    required this.sequence,
    required this.data,
    required this.payloadSize,
  });
}

/// 一次传输的完整上下文。
class ActiveTransfer {
  /// 本次传输的唯一 ID。
  final String id;

  /// 传输配置。
  final BluetoothTransferOptions options;

  /// 总 payload 字节数（用于进度计算）。
  final int totalPayloadBytes;

  // MARK: 懒加载数据源

  /// 原始数据（仅保存引用，不预创建全部帧）。
  final Uint8List sourceData;

  /// 每帧 payload 最大长度。
  final int maxPayloadLength;

  /// 是否使用应用层帧（sendRaw = false, sendReliableData = true）。
  final bool useApplicationFrame;

  /// 总帧数。
  final int totalFrameCount;

  // MARK: 传输状态

  /// 下一个待发送包的索引。
  int _nextIndex;

  /// 待重试的数据包队列。
  final List<TransferPacket> _retryQueue = [];

  /// 已发送但未确认的数据包（key 为序号）。
  final Map<int, TransferPacket> _inFlight = {};

  /// 各包已重试的次数。
  final Map<int, int> _retryCounts = {};

  /// 已确认的数据包序号集合（用于去重，防止重复 ACK）。
  final Set<int> _ackedSequences = {};

  /// 各包的超时定时器。
  final Map<int, Timer> _timeoutTimers = {};

  /// withResponse 模式下正在等待响应的槽位数。
  int _responseSlots = 0;

  /// 已确认的字节数（累加，避免遍历全部包）。
  int _ackedBytes;

  /// 递增的传输 ID 计数器。
  static int _idCounter = 0;

  /// 生成一个简短且唯一的传输 ID。
  static String _generateId() {
    _idCounter += 1;
    final now = DateTime.now().microsecondsSinceEpoch;
    return '$now-$_idCounter';
  }

  // MARK: 初始化

  /// 创建新传输（[resumeOffset] > 0 时从断点恢复）。
  ActiveTransfer({
    required Uint8List data,
    required int maxPayloadLength,
    required BluetoothTransferOptions options,
    int resumeOffset = 0,
    String? id,
  })  : id = id ?? _generateId(),
        options = options,
        sourceData = data,
        maxPayloadLength = maxPayloadLength > 1 ? maxPayloadLength : 1,
        useApplicationFrame = options.useApplicationFrame,
        totalPayloadBytes = data.length,
        totalFrameCount = (() {
          final safe = maxPayloadLength > 1 ? maxPayloadLength : 1;
          return data.isEmpty ? 1 : (data.length + safe - 1) ~/ safe;
        })(),
        _nextIndex = (() {
          final safe = maxPayloadLength > 1 ? maxPayloadLength : 1;
          if (resumeOffset <= 0) return 0;
          final frameCount = data.isEmpty ? 1 : (data.length + safe - 1) ~/ safe;
          // resumeOffset 已覆盖全部数据：无需再发包
          if (resumeOffset >= data.length) return frameCount;
          // 从断点所在帧继续（向下取整到帧边界）
          final index = resumeOffset ~/ safe;
          return index > frameCount ? frameCount : index;
        })(),
        _ackedBytes = resumeOffset > 0 ? resumeOffset : 0;

  // MARK: 懒加载生成帧

  /// 按索引生成单个数据包（按需创建，不预存全部）。
  TransferPacket makePacket(int index) {
    final payloadStart = index * maxPayloadLength;
    final payloadEnd = (payloadStart + maxPayloadLength) < sourceData.length
        ? payloadStart + maxPayloadLength
        : sourceData.length;
    final payload = Uint8List.sublistView(sourceData, payloadStart, payloadEnd);

    final Uint8List encodedData;
    if (useApplicationFrame) {
      // 应用层帧：加帧头 + CRC32
      encodedData = BluetoothProtocolCodec.encode(
        BluetoothProtocolFrame(
          type: BluetoothProtocolFrameType.data,
          sequence: index,
          offset: payloadStart,
          totalLength: sourceData.length,
          payload: payload,
        ),
      );
    } else {
      // 裸数据：直接使用 payload
      encodedData = payload;
    }

    return TransferPacket(
      sequence: index,
      data: encodedData,
      payloadSize: payload.length,
    );
  }

  // MARK: 状态查询

  /// 已确认的 payload 字节数。
  int get ackedPayloadBytes => _ackedBytes;

  /// 已确认的字节偏移量（用于断点续传）。
  int get ackedOffset => _ackedBytes;

  /// 所有包是否都已确认。
  bool get isComplete => _ackedBytes >= totalPayloadBytes;

  /// 是否可以发送下一个包。
  ///
  /// 条件：有包待发 + 未超过 ACK 窗口 + 未超过响应窗口。
  bool get canSendNext {
    if (_retryQueue.isNotEmpty || _nextIndex < totalFrameCount) {
      // applicationAck 模式：在途包数不能超过窗口
      if (options.reliability == BluetoothTransferReliability.applicationAck &&
          _inFlight.length >= options.ackWindow) {
        return false;
      }
      // withResponse 模式：等待响应的包数不能超过窗口
      if (options.writeType == BleWriteType.withResponse &&
          _responseSlots >= options.ackWindow) {
        return false;
      }
      return true;
    }
    return false;
  }

  // MARK: 包操作

  /// 取下一个待发送的包（优先重试队列，否则懒加载生成新包）。
  TransferPacket? nextPacket() {
    // 优先发送重试队列中的包
    if (_retryQueue.isNotEmpty) {
      final packet = _retryQueue.removeAt(0);
      _inFlight[packet.sequence] = packet;
      if (options.writeType == BleWriteType.withResponse) {
        _responseSlots += 1;
      }
      return packet;
    }

    // 懒加载生成新包
    if (_nextIndex >= totalFrameCount) return null;
    final packet = makePacket(_nextIndex);
    _nextIndex += 1;
    _inFlight[packet.sequence] = packet;
    if (options.writeType == BleWriteType.withResponse) {
      _responseSlots += 1;
    }
    return packet;
  }

  /// 标记某个包为已确认。
  void markAcked(int sequence) {
    if (!_ackedSequences.add(sequence)) return; // 去重

    // 累加已确认字节数
    final payloadStart = sequence * maxPayloadLength;
    final payloadEnd = (payloadStart + maxPayloadLength) < sourceData.length
        ? payloadStart + maxPayloadLength
        : sourceData.length;
    _ackedBytes += payloadEnd - payloadStart;

    _inFlight.remove(sequence);
    _retryQueue.removeWhere((p) => p.sequence == sequence);
    _timeoutTimers.remove(sequence)?.cancel();
  }

  /// 重试某个包。
  ///
  /// 返回 true 表示可以重试，false 表示已超过最大重试次数。
  bool retry(int sequence) {
    final packet = _inFlight[sequence];
    if (packet == null) return true;
    final count = (_retryCounts[sequence] ?? 0) + 1;
    _retryCounts[sequence] = count;
    // 超过最大重试次数，返回 false
    if (count > options.maxRetries) return false;
    // 从在途列表移除，加入重试队列
    _inFlight.remove(sequence);
    _timeoutTimers.remove(sequence)?.cancel();
    _retryQueue.insert(0, packet);
    return true;
  }

  /// 注册某个包的超时定时器。
  void registerTimeout(Timer timer, int sequence) {
    _timeoutTimers.remove(sequence)?.cancel();
    _timeoutTimers[sequence] = timer;
  }

  /// 释放一个 withResponse 的响应槽位。
  void releaseWriteResponseSlot() {
    if (_responseSlots > 0) _responseSlots -= 1;
  }

  /// 取消所有超时定时器（传输取消时调用）。
  void cancelTimeouts() {
    for (final timer in _timeoutTimers.values) {
      timer.cancel();
    }
    _timeoutTimers.clear();
  }
}
