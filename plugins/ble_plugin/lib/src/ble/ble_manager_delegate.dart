/// 蓝牙管理器的委托协议。
///
/// 对应 iOS 参考实现中的 `BluetoothManagerDelegate`。所有方法都有默认
/// 空实现，使用方只需实现关心的回调。
library;

import 'ble_errors.dart';
import 'ble_models.dart';
import 'ble_profile.dart';

/// 蓝牙管理器的委托协议。
///
/// 声明为 `abstract mixin class`：既可作为抽象类实现，也可作为 mixin
/// 混入（示例 App 中 `State with BluetoothManagerDelegate`）。
abstract mixin class BluetoothManagerDelegate {
  /// 蓝牙适配器状态变化（如开关蓝牙、授权变更）。
  void onAdapterStateChanged(BleAdapterState state) {}

  /// 连接状态机变化（如 scanning → connecting → ready → disconnected）。
  void onConnectionStateChanged(BluetoothConnectionState state) {}

  /// 发现新设备或设备信息更新。
  void onDevicesDiscovered(List<BluetoothDevice> devices) {}

  /// 连接成功。
  void onDeviceConnected(BluetoothDevice device) {}

  /// 连接断开。
  void onDeviceDisconnected(BluetoothDevice? device, Object? error) {}

  /// 特征角色就绪，可以开始收发数据。
  void onCharacteristicsReady(Set<BluetoothCharacteristicRole> roles) {}

  /// 收到外设发来的数据。
  void onDataReceived(List<int> data, BluetoothCharacteristicRole? role) {}

  /// 传输进度更新。
  void onTransferProgress(BluetoothPacketProgress progress) {}

  /// 整个传输完成。
  void onTransferCompleted(String transferId) {}

  /// 运行时指标更新（连接耗时、收发字节数等）。
  void onMetricsUpdated(BluetoothMetricSnapshot metrics) {}

  /// 发生错误。
  void onError(BluetoothError error) {}

  /// 传输因断连被暂停（仅当 supportsResume = true 时触发）。
  void onTransferPaused(String transferId, int ackedOffset) {}

  /// 传输从断点恢复（重连后自动恢复）。
  void onTransferResumed(String transferId, int fromOffset) {}
}
