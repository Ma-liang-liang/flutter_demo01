part of 'ble_bloc.dart';

/// BLE 演示页面状态
///
/// 单一不可变状态类 + `copyWith`，所有 UI 数据集中管理。
/// 每次状态变化产生新实例，Bloc 框架通过 `props` 对比决定是否重建。
class BleState extends Equatable {
  const BleState({
    this.adapterState = BleAdapterState.unknown,
    this.connectionState = const IdleState(),
    this.devices = const [],
    this.readyRoles = const {},
    this.progress,
    this.metrics = const BluetoothMetricSnapshot(),
    this.activeTransferId,
    this.logs = const [],
  });

  /// 蓝牙适配器状态
  final BleAdapterState adapterState;

  /// 连接状态机
  final BluetoothConnectionState connectionState;

  /// 已发现设备列表
  final List<BluetoothDevice> devices;

  /// 就绪的特征角色
  final Set<BluetoothCharacteristicRole> readyRoles;

  /// 传输进度
  final BluetoothPacketProgress? progress;

  /// 运行时指标
  final BluetoothMetricSnapshot metrics;

  /// 当前传输 ID
  final String? activeTransferId;

  /// 事件日志（最新在上）
  final List<String> logs;

  // ── 派生值（View 不做逻辑，只读取） ──

  /// 适配器是否已开启
  bool get isPoweredOn => adapterState == BleAdapterState.poweredOn;

  /// 是否正在扫描
  bool get isScanning => connectionState is ScanningState;

  /// 是否已就绪可传输
  bool get isReady => connectionState is ReadyState;

  /// 是否有传输进行中
  bool get hasActiveTransfer => activeTransferId != null;

  /// 已连接的设备 ID
  String? get connectedDeviceId => switch (connectionState) {
        ReadyState(:final deviceId) => deviceId,
        DiscoveringState(:final deviceId) => deviceId,
        ConnectingState(:final deviceId) => deviceId,
        ReconnectingState(:final deviceId) => deviceId,
        _ => null,
      };

  /// 是否有可写入的角色
  bool get hasWriteRole =>
      readyRoles.contains(BluetoothCharacteristicRole.commandWrite) ||
      readyRoles.contains(BluetoothCharacteristicRole.dataWrite);

  /// 是否有可读取的角色
  bool get hasReadRole => readyRoles.contains(BluetoothCharacteristicRole.read);

  BleState copyWith({
    BleAdapterState? adapterState,
    BluetoothConnectionState? connectionState,
    List<BluetoothDevice>? devices,
    Set<BluetoothCharacteristicRole>? readyRoles,
    BluetoothPacketProgress? progress,
    BluetoothMetricSnapshot? metrics,
    String? activeTransferId,
    List<String>? logs,
    bool clearProgress = false,
    bool clearTransferId = false,
  }) {
    return BleState(
      adapterState: adapterState ?? this.adapterState,
      connectionState: connectionState ?? this.connectionState,
      devices: devices ?? this.devices,
      readyRoles: readyRoles ?? this.readyRoles,
      progress: clearProgress ? null : (progress ?? this.progress),
      metrics: metrics ?? this.metrics,
      activeTransferId:
          clearTransferId ? null : (activeTransferId ?? this.activeTransferId),
      logs: logs ?? this.logs,
    );
  }

  @override
  List<Object?> get props => [
        adapterState,
        connectionState,
        devices,
        readyRoles,
        progress,
        metrics,
        activeTransferId,
        logs,
      ];
}
