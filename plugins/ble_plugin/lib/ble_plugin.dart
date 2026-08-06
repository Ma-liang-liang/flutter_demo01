/// 跨平台 BLE 蓝牙插件。
///
/// **架构：**
/// - 所有业务逻辑在 Dart 层实现（应用层协议、可靠传输、ACK 窗口、
///   自动重连、断点续传、指标统计）
/// - 原生端（iOS Swift / Android Kotlin）只做底层桥接
///
/// **快速开始：**
/// ```dart
/// // 1. 初始化（App 启动时）
/// final manager = BluetoothManager.shared;
/// await manager.init();
///
/// // 2. 监听事件
/// manager.addDelegate(myDelegate);
///
/// // 3. 配置设备协议画像（可选，默认通用 Demo 模式）
/// await manager.updateConfiguration(BluetoothTransferConfiguration(
///   profile: BluetoothDeviceProfile(
///     name: 'My Device',
///     scanServiceUuids: ['FFF0'],
///     serviceUuids: ['FFF0'],
///     characteristics: [
///       BluetoothCharacteristicProfile(
///         role: BluetoothCharacteristicRole.commandWrite,
///         serviceUuid: 'FFF0',
///         characteristicUuid: 'FFF1',
///       ),
///       BluetoothCharacteristicProfile(
///         role: BluetoothCharacteristicRole.notify,
///         serviceUuid: 'FFF0',
///         characteristicUuid: 'FFF2',
///         enableNotify: true,
///       ),
///     ],
///   ),
/// ));
///
/// // 4. 扫描 → 连接 → 传输
/// await manager.startScan();
/// await manager.connect(device);
/// await manager.sendReliableData(data);
/// ```
library;

export 'src/ble/ble_errors.dart';
export 'src/ble/ble_manager.dart';
export 'src/ble/ble_manager_delegate.dart';
export 'src/ble/ble_models.dart';
export 'src/ble/ble_profile.dart';
export 'src/ble/ble_protocol.dart';
export 'src/ble/ble_stream_events.dart';
export 'src/ble/ble_transfer.dart';
export 'src/platform/ble_bridge.dart';
export 'src/platform/ble_bridge_events.dart';
