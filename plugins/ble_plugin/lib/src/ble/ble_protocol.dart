/// 蓝牙数据传输的应用层协议。
///
/// 对应 iOS 参考实现中的 `BluetoothTransferProtocol.swift`，纯 Dart 实现：
/// 1. `BluetoothTransferReliability` —— 可靠性级别（fireAndForget / applicationAck）
/// 2. `BluetoothTransferOptions` —— 传输配置（角色、窗口、重试等）
/// 3. `BluetoothProtocolFrame` / `BluetoothProtocolFrameType` —— 帧结构与帧类型
/// 4. `BluetoothProtocolCodec` —— 帧的编码、解码（含 CRC32 校验）
/// 5. `crc32Of` —— CRC32 计算（多项式 0xEDB88320，IEEE 802.3 标准）
library;

import 'dart:typed_data';

import 'ble_profile.dart';

/// 传输可靠性级别，决定是否需要外设回 ACK。
enum BluetoothTransferReliability {
  /// 只依赖平台写入队列，适合高频实时数据或设备不支持业务 ACK 的场景。
  /// 发出去就不管了，不等待确认，不重试。
  fireAndForget,

  /// 需要外设通过 notify 回 ACK，适合文件、OTA、关键配置等强一致传输。
  /// 每个数据包都要等外设确认，超时自动重试，达到最大重试次数后报错。
  applicationAck;
}

/// 传输配置选项，控制可靠传输的各种参数。
class BluetoothTransferOptions {
  /// 使用哪个特征角色发送数据。
  final BluetoothCharacteristicRole role;

  /// 可靠性级别。
  final BluetoothTransferReliability reliability;

  /// 单帧最大 payload 长度，null 表示自动计算（MTU - headerLength）。
  final int? maxPayloadLength;

  /// ACK 窗口大小：同时允许在途未确认的数据包数量。
  /// 值越大吞吐越高，但占用的蓝牙缓冲也越多。
  final int ackWindow;

  /// 单个包最大重试次数，超过后判定传输失败。
  final int maxRetries;

  /// 等待 ACK 的超时时间（秒），超时后触发重试。
  final double ackTimeout;

  /// 写入方式：withResponse 更可靠，withoutResponse 更快。
  /// null 表示根据特征属性自动选择。
  final BleWriteType? writeType;

  /// 是否使用应用层帧（包头+CRC），关闭后走裸数据写入。
  final bool useApplicationFrame;

  /// 是否支持断点续传（默认 false）。
  ///
  /// 开启后：断连时保存已确认的 offset，重连后自动从断点继续传输。
  /// 注意：开启时原始数据会保留在内存中直到传输完成或取消。
  final bool supportsResume;

  const BluetoothTransferOptions({
    this.role = BluetoothCharacteristicRole.dataWrite,
    this.reliability = BluetoothTransferReliability.applicationAck,
    this.maxPayloadLength,
    this.ackWindow = 6,
    this.maxRetries = 3,
    this.ackTimeout = 1.5,
    this.writeType,
    this.useApplicationFrame = true,
    this.supportsResume = false,
  });

  /// 复制当前配置并替换指定字段。
  BluetoothTransferOptions copyWith({
    BluetoothCharacteristicRole? role,
    BluetoothTransferReliability? reliability,
    int? maxPayloadLength,
    int? ackWindow,
    int? maxRetries,
    double? ackTimeout,
    BleWriteType? writeType,
    bool? useApplicationFrame,
    bool? supportsResume,
  }) {
    return BluetoothTransferOptions(
      role: role ?? this.role,
      reliability: reliability ?? this.reliability,
      maxPayloadLength: maxPayloadLength ?? this.maxPayloadLength,
      ackWindow: ackWindow ?? this.ackWindow,
      maxRetries: maxRetries ?? this.maxRetries,
      ackTimeout: ackTimeout ?? this.ackTimeout,
      writeType: writeType ?? this.writeType,
      useApplicationFrame: useApplicationFrame ?? this.useApplicationFrame,
      supportsResume: supportsResume ?? this.supportsResume,
    );
  }

  @override
  String toString() =>
      'BluetoothTransferOptions(role: $role, reliability: $reliability, '
      'ackWindow: $ackWindow, maxRetries: $maxRetries, ackTimeout: $ackTimeout)';
}

/// 应用层帧类型，区分不同用途的数据包。
enum BluetoothProtocolFrameType {
  /// 数据帧：携带实际 payload。
  data(1),

  /// 确认帧：外设回传给 App，表示某个序号的数据包已收到。
  ack(2),

  /// 完成帧：标记整个传输结束（当前未使用，预留）。
  complete(3),

  /// 续传请求帧：请求从某个 offset 继续传输（当前未使用，预留）。
  resumeRequest(4);

  /// 帧类型在字节流中的原始值。
  final int rawValue;

  const BluetoothProtocolFrameType(this.rawValue);

  /// 从原始值解析帧类型。
  static BluetoothProtocolFrameType? fromRawValue(int value) {
    for (final t in BluetoothProtocolFrameType.values) {
      if (t.rawValue == value) return t;
    }
    return null;
  }
}

/// 应用层数据帧结构。
///
/// 帧布局（大端序）：
/// ```text
/// | magic(2B) | version(1B) | type(1B) | sequence(4B) | offset(4B) | totalLength(4B) | payloadLen(2B) | crc32(4B) | payload(NB) |
/// | 0xA55A   | 0x01        |          |             |            |                  |               |          |              |
/// ```
/// 头部固定 22 字节，payload 长度可变。
class BluetoothProtocolFrame {
  /// 魔数，用于帧同步（接收方据此判断数据是否为合法帧）。
  static const int magic = 0xA55A;

  /// 协议版本号，用于未来升级兼容。
  static const int version = 1;

  /// 头部固定长度：magic(2) + version(1) + type(1) + sequence(4) + offset(4)
  /// + totalLength(4) + payloadLen(2) + crc32(4) = 22。
  static const int headerLength = 22;

  /// 帧类型。
  final BluetoothProtocolFrameType type;

  /// 帧序号（从 0 递增），用于 ACK 匹配和重排序。
  final int sequence;

  /// 该帧 payload 在整个数据中的字节偏移。
  final int offset;

  /// 整个传输数据的总长度（所有帧的 payload 拼接后的大小）。
  final int totalLength;

  /// 实际负载。
  final Uint8List payload;

  const BluetoothProtocolFrame({
    required this.type,
    required this.sequence,
    required this.offset,
    required this.totalLength,
    required this.payload,
  });
}

/// 帧编解码器，负责将原始数据拆分为帧、编码为字节流、以及从字节流解码出帧。
class BluetoothProtocolCodec {
  const BluetoothProtocolCodec._();

  /// 将一段原始数据拆分为多个数据帧。
  ///
  /// - [data]: 原始数据
  /// - [maxPayloadLength]: 每帧 payload 的最大长度
  static List<BluetoothProtocolFrame> makeDataFrames(
    Uint8List data, {
    required int maxPayloadLength,
  }) {
    // 限制单帧 payload 不超过 UInt16.max（帧头中 payloadLen 字段为 UInt16）
    final safeMaxPayload = maxPayloadLength > 0xFFFF ? 0xFFFF : maxPayloadLength;
    // 空数据也要发一帧，让接收方知道传输开始和结束
    if (data.isEmpty) {
      return [
        BluetoothProtocolFrame(
          type: BluetoothProtocolFrameType.data,
          sequence: 0,
          offset: 0,
          totalLength: 0,
          payload: Uint8List(0),
        ),
      ];
    }

    final frames = <BluetoothProtocolFrame>[];
    var sequence = 0;
    var offset = 0;
    while (offset < data.length) {
      final end = (offset + safeMaxPayload < data.length)
          ? offset + safeMaxPayload
          : data.length;
      frames.add(
        BluetoothProtocolFrame(
          type: BluetoothProtocolFrameType.data,
          sequence: sequence,
          offset: offset,
          totalLength: data.length,
          payload: Uint8List.sublistView(data, offset, end),
        ),
      );
      sequence += 1;
      offset = end;
    }
    return frames;
  }

  /// 构造一个 ACK 帧。
  static BluetoothProtocolFrame makeAck({
    required int sequence,
    required int offset,
    required int totalLength,
  }) {
    return BluetoothProtocolFrame(
      type: BluetoothProtocolFrameType.ack,
      sequence: sequence,
      offset: offset,
      totalLength: totalLength,
      payload: Uint8List(0),
    );
  }

  /// 将帧编码为字节流（大端序），可直接写入蓝牙特征。
  static Uint8List encode(BluetoothProtocolFrame frame) {
    final payload = frame.payload;
    final payloadLen = payload.length > 0xFFFF ? 0xFFFF : payload.length;
    final data = Uint8List(BluetoothProtocolFrame.headerLength + payloadLen);
    final bd = ByteData.sublistView(data);

    // magic(2B)
    bd.setUint16(0, BluetoothProtocolFrame.magic);
    // version(1B)
    bd.setUint8(2, BluetoothProtocolFrame.version);
    // type(1B)
    bd.setUint8(3, frame.type.rawValue);
    // sequence(4B)
    bd.setUint32(4, frame.sequence);
    // offset(4B)
    bd.setUint32(8, frame.offset);
    // totalLength(4B)
    bd.setUint32(12, frame.totalLength);
    // payloadLen(2B)
    bd.setUint16(16, payloadLen);
    // crc32(4B)
    bd.setUint32(18, crc32Of(payload));
    // payload
    data.setRange(
      BluetoothProtocolFrame.headerLength,
      BluetoothProtocolFrame.headerLength + payloadLen,
      payload,
    );

    return data;
  }

  /// 从字节流解码出帧。
  ///
  /// 会校验魔数、版本号、长度和 CRC32，任一不匹配则返回 null。
  static BluetoothProtocolFrame? decode(Uint8List data) {
    // 1. 长度至少要能装下头部
    if (data.length < BluetoothProtocolFrame.headerLength) return null;
    final bd = ByteData.sublistView(data);

    // 2. 校验魔数
    if (bd.getUint16(0) != BluetoothProtocolFrame.magic) return null;
    // 3. 校验版本号
    if (bd.getUint8(2) != BluetoothProtocolFrame.version) return null;

    // 4. 逐字段解析头部
    final type = BluetoothProtocolFrameType.fromRawValue(bd.getUint8(3));
    if (type == null) return null;
    final sequence = bd.getUint32(4);
    final offset = bd.getUint32(8);
    final totalLength = bd.getUint32(12);
    final payloadLength = bd.getUint16(16);
    final expectedCrc = bd.getUint32(18);

    // 5. 截取 payload 并校验长度
    final payloadEnd = BluetoothProtocolFrame.headerLength + payloadLength;
    if (data.length < payloadEnd) return null;
    final payload = Uint8List.sublistView(
      data,
      BluetoothProtocolFrame.headerLength,
      payloadEnd,
    );

    // 6. CRC32 校验，防止数据损坏
    if (crc32Of(payload) != expectedCrc) return null;

    return BluetoothProtocolFrame(
      type: type,
      sequence: sequence,
      offset: offset,
      totalLength: totalLength,
      payload: payload,
    );
  }
}

/// 计算 CRC32 校验值。
///
/// 使用多项式 0xEDB88320（IEEE 802.3 标准），初始值 0xFFFFFFFF，最终异或
/// 0xFFFFFFFF。用于检测数据在传输过程中是否发生位翻转或损坏。
/// 与 iOS 参考实现完全一致，保证跨端兼容。
int crc32Of(List<int> data) {
  var crc = 0xFFFFFFFF;
  for (final byte in data) {
    crc ^= byte & 0xFF;
    for (var i = 0; i < 8; i++) {
      if (crc & 1 == 1) {
        crc = (crc >> 1) ^ 0xEDB88320;
      } else {
        crc >>= 1;
      }
    }
  }
  return crc ^ 0xFFFFFFFF;
}
