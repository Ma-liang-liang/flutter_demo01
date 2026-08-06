/// 蓝牙管理器的 Stream 事件模型。
///
/// `BluetoothManager` 以响应式 Stream 对外通知（参考 flutter_blue_plus
/// 的设计风格）：订阅即得当前值、流永不主动关闭。本文件定义各条流
/// 携带的值类型：
///
/// - [BluetoothDataReceived] —— dataStream 的值（收到外设数据）
/// - [BluetoothTransferEvent] —— transferEventsStream 的值（传输生命周期）
library;

import 'dart:typed_data';

import 'ble_profile.dart';

/// 收到外设发来的数据。
///
/// 若数据符合应用层协议帧格式，[data] 为帧的纯净 payload（不含帧头）；
/// 否则为原始字节。数据来源特征的角色通过 [role] 提供（可能为 null，
/// 如特征未匹配到任何角色时）。
class BluetoothDataReceived {
  /// 数据内容。
  final Uint8List data;

  /// 来源特征的角色（notify / read 等），未匹配时为空。
  final BluetoothCharacteristicRole? role;

  /// 来源设备标识。
  final String deviceId;

  const BluetoothDataReceived({
    required this.data,
    required this.role,
    required this.deviceId,
  });
}

/// 传输生命周期事件（sealed class，支持模式匹配）。
sealed class BluetoothTransferEvent {
  /// 本次传输的唯一 ID。
  final String transferId;

  const BluetoothTransferEvent({required this.transferId});
}

/// 整个传输完成（所有数据包已确认）。
class BluetoothTransferCompleted extends BluetoothTransferEvent {
  const BluetoothTransferCompleted({required super.transferId});
}

/// 传输因断连被暂停（仅当 supportsResume = true 时触发）。
class BluetoothTransferPaused extends BluetoothTransferEvent {
  /// 暂停时已确认的字节偏移，供断点续传使用。
  final int ackedOffset;

  const BluetoothTransferPaused({
    required super.transferId,
    required this.ackedOffset,
  });
}

/// 传输从断点恢复（重连后自动继续）。
class BluetoothTransferResumed extends BluetoothTransferEvent {
  /// 恢复起点字节偏移。
  final int fromOffset;

  const BluetoothTransferResumed({
    required super.transferId,
    required this.fromOffset,
  });
}
