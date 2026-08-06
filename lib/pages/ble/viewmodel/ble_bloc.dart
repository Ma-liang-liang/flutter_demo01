import 'dart:typed_data';

import 'package:ble_plugin/ble_plugin.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'ble_event.dart';
part 'ble_state.dart';

/// BLE 蓝牙演示页面 ViewModel（Bloc 实现）
///
/// MVVM 中的 ViewModel 层，职责：
/// 1. 接收 View 发来的用户事件（[BleEvent]）
/// 2. 通过 [BluetoothManager] 单例执行 BLE 操作
/// 3. 通过 [_BleDelegateAdapter] 接收原生回调，
///    将回调转为内部事件（`_` 前缀）走 Bloc 串行管道
/// 4. 产出不可变状态（[BleState]）驱动 View 重建
///
/// 设计参照 CountdownBloc：外部回调（Stream/Delegate）
/// → `add(内部事件)` → handler → emit 状态，
/// 保证所有状态变更走同一条串行管道，线程安全且可追溯。
///
/// 注意：[BluetoothManagerDelegate] 的 `onError(BluetoothError)` 与
/// [BlocBase] 的 `onError(Object, StackTrace)` 签名冲突，因此不能
/// 直接用 `with BluetoothManagerDelegate`，而是通过独立的
/// [_BleDelegateAdapter] 桥接。
class BleBloc extends Bloc<BleEvent, BleState> {
  BleBloc() : super(const BleState()) {
    on<BleStarted>(_onStarted);
    on<BleScanToggled>(_onScanToggled);
    on<BleDeviceSelected>(_onDeviceSelected);
    on<BleDisconnectRequested>(_onDisconnectRequested);
    on<BleSendRawRequested>(_onSendRawRequested);
    on<BleSendReliableRequested>(_onSendReliableRequested);
    on<BleCancelTransferRequested>(_onCancelTransferRequested);
    on<BleReadValueRequested>(_onReadValueRequested);
    on<BleLogCleared>(_onLogCleared);
    on<_AdapterStateChanged>(_onAdapterStateChanged);
    on<_ConnectionStateChanged>(_onConnectionStateChanged);
    on<_DevicesDiscovered>(_onDevicesDiscovered);
    on<_CharacteristicsReady>(_onCharacteristicsReady);
    on<_TransferProgress>(_onTransferProgress);
    on<_TransferCompleted>(_onTransferCompleted);
    on<_MetricsUpdated>(_onMetricsUpdated);
    on<_ErrorOccurred>(_onErrorOccurred);
    on<_LogAdded>(_onLogAdded);
  }

  final _manager = BluetoothManager.shared;
  late final _BleDelegateAdapter _delegate = _BleDelegateAdapter(this);

  // ──────────────────────────────────────────────────────────
  // 用户事件处理
  // ──────────────────────────────────────────────────────────

  Future<void> _onStarted(BleStarted event, Emitter<BleState> emit) async {
    _manager.addDelegate(_delegate);
    await _manager.init();
    emit(state.copyWith(
      adapterState: _manager.adapterState,
      connectionState: _manager.connectionState,
      metrics: _manager.metrics,
    ));
    _log(emit, 'BluetoothManager 初始化完成');
  }

  Future<void> _onScanToggled(BleScanToggled event, Emitter<BleState> emit) async {
    if (state.isScanning) {
      await _manager.stopScan();
    } else {
      _log(emit, '开始扫描...');
      await _manager.startScan();
    }
  }

  Future<void> _onDeviceSelected(
    BleDeviceSelected event,
    Emitter<BleState> emit,
  ) async {
    _log(emit, '连接设备: ${event.device.name}');
    await _manager.connect(event.device);
  }

  Future<void> _onDisconnectRequested(
    BleDisconnectRequested event,
    Emitter<BleState> emit,
  ) async {
    _log(emit, '断开连接...');
    await _manager.disconnect();
  }

  Future<void> _onSendRawRequested(
    BleSendRawRequested event,
    Emitter<BleState> emit,
  ) async {
    _log(emit, '发送裸数据: ${event.data.length} bytes');
    await _manager.sendRaw(event.data);
  }

  Future<void> _onSendReliableRequested(
    BleSendReliableRequested event,
    Emitter<BleState> emit,
  ) async {
    _log(emit, '发送可靠数据: ${event.data.length} bytes');
    final id = await _manager.sendReliableData(event.data);
    if (id != null) {
      emit(state.copyWith(activeTransferId: id));
      _log(emit, '传输已创建: $id');
    }
  }

  Future<void> _onCancelTransferRequested(
    BleCancelTransferRequested event,
    Emitter<BleState> emit,
  ) async {
    _log(emit, '取消传输...');
    await _manager.cancelTransfer();
    emit(state.copyWith(clearProgress: true, clearTransferId: true));
  }

  Future<void> _onReadValueRequested(
    BleReadValueRequested event,
    Emitter<BleState> emit,
  ) async {
    _log(emit, '读取特征值...');
    await _manager.readValue();
  }

  void _onLogCleared(BleLogCleared event, Emitter<BleState> emit) {
    emit(state.copyWith(logs: const []));
  }

  // ──────────────────────────────────────────────────────────
  // 内部事件处理（delegate 回调 → add(事件) → handler）
  // ──────────────────────────────────────────────────────────

  void _onAdapterStateChanged(_AdapterStateChanged event, Emitter<BleState> emit) {
    emit(state.copyWith(adapterState: event.state));
    _log(emit, '适配器状态: ${event.state.name}');
  }

  void _onConnectionStateChanged(_ConnectionStateChanged event, Emitter<BleState> emit) {
    emit(state.copyWith(connectionState: event.state));
    _log(emit, '连接状态: ${event.state}');
  }

  void _onDevicesDiscovered(_DevicesDiscovered event, Emitter<BleState> emit) {
    emit(state.copyWith(devices: event.devices));
    _log(emit, '发现 ${event.devices.length} 个设备');
  }

  void _onCharacteristicsReady(_CharacteristicsReady event, Emitter<BleState> emit) {
    emit(state.copyWith(readyRoles: event.roles));
    _log(emit, '特征就绪: ${event.roles.map((r) => r.name).join(', ')}');
  }

  void _onTransferProgress(_TransferProgress event, Emitter<BleState> emit) {
    emit(state.copyWith(progress: event.progress));
  }

  void _onTransferCompleted(_TransferCompleted event, Emitter<BleState> emit) {
    _log(emit, '传输完成: ${event.transferId}');
    emit(state.copyWith(clearProgress: true, clearTransferId: true));
  }

  void _onMetricsUpdated(_MetricsUpdated event, Emitter<BleState> emit) {
    emit(state.copyWith(metrics: event.metrics));
  }

  void _onErrorOccurred(_ErrorOccurred event, Emitter<BleState> emit) {
    _log(emit, '错误: ${event.error.type.name} — ${event.error.message}');
  }

  void _onLogAdded(_LogAdded event, Emitter<BleState> emit) {
    _log(emit, event.message);
  }

  // ──────────────────────────────────────────────────────────
  // 生命周期
  // ──────────────────────────────────────────────────────────

  @override
  Future<void> close() {
    _manager.removeDelegate(_delegate);
    return super.close();
  }

  // ──────────────────────────────────────────────────────────
  // 工具方法
  // ──────────────────────────────────────────────────────────

  /// 追加一条日志到状态
  void _log(Emitter<BleState> emit, String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    final entry = '[$timestamp] $message';
    emit(state.copyWith(logs: [entry, ...state.logs.take(49)]));
  }
}

/// [BluetoothManagerDelegate] 适配器
///
/// 解决 `BluetoothManagerDelegate.onError(BluetoothError)` 与
/// `BlocBase.onError(Object, StackTrace)` 的签名冲突：将 delegate
/// 实现从 Bloc 上拆离，通过独立适配器把回调转为 Bloc 事件。
class _BleDelegateAdapter implements BluetoothManagerDelegate {
  _BleDelegateAdapter(this._bloc);

  final BleBloc _bloc;

  @override
  void onAdapterStateChanged(BleAdapterState state) =>
      _bloc.add(_AdapterStateChanged(state));

  @override
  void onDeviceConnected(BluetoothDevice device) {
    // 连接成功通过 onConnectionStateChanged 体现，此处无需单独处理
  }

  @override
  void onDeviceDisconnected(BluetoothDevice? device, Object? error) {
    // 断开通过 onConnectionStateChanged 体现，此处无需单独处理
  }

  @override
  void onConnectionStateChanged(BluetoothConnectionState state) =>
      _bloc.add(_ConnectionStateChanged(state));

  @override
  void onDevicesDiscovered(List<BluetoothDevice> devices) =>
      _bloc.add(_DevicesDiscovered(devices));

  @override
  void onCharacteristicsReady(Set<BluetoothCharacteristicRole> roles) =>
      _bloc.add(_CharacteristicsReady(roles));

  @override
  void onDataReceived(List<int> data, BluetoothCharacteristicRole? role) {
    _bloc.add(_LogAdded(
      '收到数据 [${role?.name ?? 'unknown'}]: ${data.length} bytes',
    ));
  }

  @override
  void onTransferProgress(BluetoothPacketProgress progress) =>
      _bloc.add(_TransferProgress(progress));

  @override
  void onTransferCompleted(String transferId) =>
      _bloc.add(_TransferCompleted(transferId));

  @override
  void onTransferPaused(String transferId, int ackedOffset) {
    _bloc.add(_LogAdded(
      '传输暂停 [断点续传]: $transferId @ $ackedOffset bytes',
    ));
  }

  @override
  void onTransferResumed(String transferId, int fromOffset) {
    _bloc.add(_LogAdded(
      '传输恢复 [断点续传]: $transferId from $fromOffset bytes',
    ));
  }

  @override
  void onMetricsUpdated(BluetoothMetricSnapshot metrics) =>
      _bloc.add(_MetricsUpdated(metrics));

  @override
  void onError(BluetoothError error) =>
      _bloc.add(_ErrorOccurred(error));
}
