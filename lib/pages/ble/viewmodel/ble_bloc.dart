import 'dart:async';
import 'dart:convert';

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
/// 3. 订阅 [BluetoothManager] 的响应式 Stream（adapterStateStream /
///    connectionStateStream / scanResultsStream / dataStream /
///    errorStream / transferEventsStream 等），将流事件转为
///    内部事件（`_` 前缀）走 Bloc 串行管道
/// 4. 产出不可变状态（[BleState]）驱动 View 重建
///
/// 设计参照 CountdownBloc：外部流回调 → `add(内部事件)` → handler → emit，
/// 保证所有状态变更走同一条串行管道，线程安全且可追溯。
///
/// Stream 方式优于 delegate：
/// - 无 `onError` 方法签名冲突（BlocBase.onError vs Delegate.onError）
/// - 订阅即得当前值（BehaviorSubject 语义），页面重建后不丢状态
/// - 流订阅可精确取消，生命周期更清晰
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
    // 内部事件（Stream 回调 → add(事件) → handler）
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

  /// Stream 订阅列表（close 时统一取消）。
  final List<StreamSubscription> _subscriptions = [];

  // ──────────────────────────────────────────────────────────
  // 用户事件处理
  // ──────────────────────────────────────────────────────────

  Future<void> _onStarted(BleStarted event, Emitter<BleState> emit) async {
    await _manager.init();
    // 订阅即得当前值：首次订阅会立即收到 manager 的初始状态
    _subscriptions.addAll([
      _manager.adapterStateStream.listen(
        (s) => add(_AdapterStateChanged(s)),
      ),
      _manager.connectionStateStream.listen(
        (s) => add(_ConnectionStateChanged(s)),
      ),
      _manager.scanResultsStream.listen(
        (devices) => add(_DevicesDiscovered(devices)),
      ),
      _manager.characteristicRolesStream.listen(
        (roles) => add(_CharacteristicsReady(roles)),
      ),
      _manager.progressStream.listen(
        (p) => add(_TransferProgress(p)),
      ),
      _manager.transferEventsStream.listen(_onTransferEvent),
      _manager.metricsStream.listen(
        (m) => add(_MetricsUpdated(m)),
      ),
      _manager.errorStream.listen(
        (e) => add(_ErrorOccurred(e)),
      ),
      _manager.dataStream.listen(
        (d) => add(_LogAdded(
          '收到数据 [${d.role?.name ?? 'unknown'}]: ${d.data.length} bytes',
        )),
      ),
    ]);
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
    final bytes = utf8.encode(event.text);
    _log(emit, '发送字符串: "${event.text}" (${bytes.length} bytes)');
    await _manager.sendRawString(event.text);
  }

  Future<void> _onSendReliableRequested(
    BleSendReliableRequested event,
    Emitter<BleState> emit,
  ) async {
    final bytes = utf8.encode(event.text);
    _log(emit, '发送可靠字符串: "${event.text}" (${bytes.length} bytes)');
    final id = await _manager.sendReliableString(event.text);
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
  // 内部事件处理（Stream → add(事件) → handler）
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
  // transferEventsStream 的 sealed class 分流
  // ──────────────────────────────────────────────────────────

  void _onTransferEvent(BluetoothTransferEvent event) {
    switch (event) {
      case BluetoothTransferCompleted():
        add(_TransferCompleted(event.transferId));
      case BluetoothTransferPaused():
        add(_LogAdded(
          '传输暂停 [断点续传]: ${event.transferId} @ ${event.ackedOffset} bytes',
        ));
      case BluetoothTransferResumed():
        add(_LogAdded(
          '传输恢复 [断点续传]: ${event.transferId} from ${event.fromOffset} bytes',
        ));
    }
  }

  // ──────────────────────────────────────────────────────────
  // 生命周期
  // ──────────────────────────────────────────────────────────

  @override
  Future<void> close() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
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
