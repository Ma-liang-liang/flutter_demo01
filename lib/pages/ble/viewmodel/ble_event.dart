part of 'ble_bloc.dart';

/// BLE 模块事件定义
///
/// 使用 `sealed class` + `Equatable`，分两类：
/// - 用户事件（View 发出，无 `_` 前缀）
/// - 内部事件（delegate 回调转事件，`_` 前缀，View 不可见）
sealed class BleEvent extends Equatable {
  const BleEvent();

  @override
  List<Object?> get props => [];
}

// ──────────────────────────────────────────────────────────
// 用户事件
// ──────────────────────────────────────────────────────────

/// 页面初始化：注册 delegate + init manager
final class BleStarted extends BleEvent {
  const BleStarted();
}

/// 切换扫描（开始/停止）
final class BleScanToggled extends BleEvent {
  const BleScanToggled();
}

/// 选中设备连接
final class BleDeviceSelected extends BleEvent {
  const BleDeviceSelected(this.device);

  final BluetoothDevice device;

  @override
  List<Object?> get props => [device];
}

/// 断开连接
final class BleDisconnectRequested extends BleEvent {
  const BleDisconnectRequested();
}

/// 发送裸数据（字符串直接发送，UTF-8 编码）
final class BleSendRawRequested extends BleEvent {
  const BleSendRawRequested(this.text);

  final String text;

  @override
  List<Object?> get props => [text];
}

/// 可靠传输（字符串直接发送，UTF-8 编码）
final class BleSendReliableRequested extends BleEvent {
  const BleSendReliableRequested(this.text);

  final String text;

  @override
  List<Object?> get props => [text];
}

/// 取消传输
final class BleCancelTransferRequested extends BleEvent {
  const BleCancelTransferRequested();
}

/// 读取特征值
final class BleReadValueRequested extends BleEvent {
  const BleReadValueRequested();
}

/// 清空日志
final class BleLogCleared extends BleEvent {
  const BleLogCleared();
}

// ──────────────────────────────────────────────────────────
// 内部事件（delegate 回调 → add() 转事件）
// ──────────────────────────────────────────────────────────

final class _AdapterStateChanged extends BleEvent {
  const _AdapterStateChanged(this.state);

  final BleAdapterState state;

  @override
  List<Object?> get props => [state];
}

final class _ConnectionStateChanged extends BleEvent {
  const _ConnectionStateChanged(this.state);

  final BluetoothConnectionState state;

  @override
  List<Object?> get props => [state];
}

final class _DevicesDiscovered extends BleEvent {
  const _DevicesDiscovered(this.devices);

  final List<BluetoothDevice> devices;

  @override
  List<Object?> get props => [devices];
}

final class _CharacteristicsReady extends BleEvent {
  const _CharacteristicsReady(this.roles);

  final Set<BluetoothCharacteristicRole> roles;

  @override
  List<Object?> get props => [roles];
}

final class _TransferProgress extends BleEvent {
  const _TransferProgress(this.progress);

  final BluetoothPacketProgress progress;

  @override
  List<Object?> get props => [progress];
}

final class _TransferCompleted extends BleEvent {
  const _TransferCompleted(this.transferId);

  final String transferId;

  @override
  List<Object?> get props => [transferId];
}

final class _MetricsUpdated extends BleEvent {
  const _MetricsUpdated(this.metrics);

  final BluetoothMetricSnapshot metrics;

  @override
  List<Object?> get props => [metrics];
}

final class _ErrorOccurred extends BleEvent {
  const _ErrorOccurred(this.error);

  final BluetoothError error;

  @override
  List<Object?> get props => [error];
}

/// 日志追加事件（onDataReceived / onTransferPaused / onTransferResumed 等用）
final class _LogAdded extends BleEvent {
  const _LogAdded(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
