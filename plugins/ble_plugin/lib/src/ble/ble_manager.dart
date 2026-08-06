/// 蓝牙核心管理器，封装 BLE 的完整通信流程。
///
/// 对应 iOS 参考实现中的 `BluetoothManager.swift`，纯 Dart 实现：
///
/// **主要职责：**
/// 1. 扫描 —— 按 service UUID 过滤扫描附近 BLE 设备（超时自动停止）
/// 2. 连接 —— 连接设备、发现服务和特征、自动重连（指数退避 + 随机抖动）
/// 3. 传输 —— 三种数据接口：
///    - [sendRaw]: 裸数据写入，不加应用层包头，适合简单调试
///    - [sendReliableData]: 可靠传输，含包头+CRC+ACK窗口+超时重试
///    - [readValue]: 读取外设特征值
/// 4. 状态管理 —— 维护连接状态机，通过响应式 Stream 通知外部
///    （delegate 为过渡兼容，后续将移除）
/// 5. 指标统计 —— 记录连接耗时、收发字节数、重连次数等
/// 6. 断点续传 —— supportsResume 开启后，断连自动保存进度，重连后恢复
///
/// **架构说明：**
/// 原生端（iOS Swift / Android Kotlin）只做底层桥接（扫描/连接/读写/订阅），
/// 本类实现全部业务逻辑：应用层协议、ACK 窗口、自动重连、断点续传、指标。
///
/// **线程模型：**
/// Dart 单线程事件循环，所有公开操作与原生事件通过串行队列
/// [_enqueue] 顺序执行，避免状态竞争。
library;

import 'dart:async';
import 'dart:typed_data';

import '../platform/ble_bridge.dart' show BleBridge, PlatformBridgeException;
import '../platform/ble_bridge_events.dart';
import 'ble_errors.dart';
import 'ble_manager_delegate.dart';
import 'ble_models.dart';
import 'ble_profile.dart';
import 'ble_protocol.dart';
import 'ble_stream_events.dart';
import 'ble_transfer.dart';

part 'ble_manager_transfer.dart';

/// 蓝牙核心管理器（单例）。
///
/// **事件通知（Stream 优先）：**
/// 以响应式 Stream 对外通知（参考 flutter_blue_plus 设计风格）：
/// 订阅即得当前值、流永不主动关闭。事件源直接来自内部状态变更，
/// 不依赖 [BluetoothManagerDelegate]（后者仅为过渡期兼容保留）。
///
/// 主要流：
/// - [adapterStateStream]：适配器状态
/// - [connectionStateStream]：连接状态机
/// - [scanResultsStream]：扫描结果快照
/// - [currentDeviceStream]：当前连接设备
/// - [dataStream]：收到外设的数据
/// - [errorStream]：错误通知
/// - [metricsStream] / [progressStream] / [transferEventsStream]：传输相关
class BluetoothManager {
  // MARK: 单例

  /// 全局单例。
  static final BluetoothManager shared = BluetoothManager._();

  /// 平台桥接（测试时可注入 mock）。
  static BleBridge bridge = BleBridge.instance;

  // MARK: 内部状态

  /// 是否已完成初始化（配置原生端 + 订阅事件流）。
  bool _initialized = false;

  /// 原生事件流订阅。
  StreamSubscription<BleBridgeEvent>? _eventSubscription;

  /// 当前传输配置。
  BluetoothTransferConfiguration _configuration =
      const BluetoothTransferConfiguration();

  /// 已发现的设备字典（key 为设备标识，便于去重和更新）。
  final Map<String, BluetoothDevice> _discoveredMap = {};

  /// 当前已连接的设备标识。
  String? _connectedPeripheralId;

  /// 当前已连接的设备模型。
  BluetoothDevice? _connectedDevice;

  /// 角色到特征 UUID 的映射（如 commandWrite → 目标特征）。
  final Map<BluetoothCharacteristicRole, _TargetCharacteristic>
      _characteristicsByRole = {};

  /// 特征 UUID 到角色的反向映射，收到数据时用于判断来源。
  final Map<String, BluetoothCharacteristicRole> _characteristicRolesByUuid =
      {};

  /// 是否允许自动重连（主动断开时设为 false）。
  bool _shouldAutoReconnect = true;

  /// 已请求特征发现的服务集合（key: `deviceId|serviceUuid`）。
  ///
  /// Android 端 `discoverCharacteristics` 实际是全量 `discoverServices`，
  /// 若设备存在无特征的空服务，Dart 层会收到全量上报再次触发特征发现，
  /// 形成循环；用该集合去重，确保每个服务只请求一次特征发现。
  final Set<String> _characteristicDiscoveryRequested = {};

  /// 当前已尝试的重连次数。
  int _reconnectAttempts = 0;

  /// 延迟重连的定时器。
  Timer? _pendingReconnectTimer;

  /// 当前正在进行的传输。
  ActiveTransfer? _activeTransfer;

  /// 运行时指标。
  BluetoothMetricSnapshot _metrics = const BluetoothMetricSnapshot();

  /// 断点续传上下文（断连时保存，重连后恢复）。
  _PendingResumeContext? _pendingResume;

  /// 进度回调节流时间戳。
  DateTime? _lastProgressNotifyTime;

  /// 串行操作队列，保证所有公开操作与事件处理顺序执行。
  Future<void> _operationQueue = Future.value();

  /// 蓝牙适配器当前状态。
  BleAdapterState _adapterState = BleAdapterState.unknown;

  /// 连接状态机（内部存储）。
  BluetoothConnectionState _connectionState = const IdleState();

  // MARK: 弱引用 delegate 表

  final List<WeakReference<BluetoothManagerDelegate>> _delegates = [];

  // MARK: Stream 控制器（独立事件源，不依赖 delegate）

  final _ValueStreamController<BleAdapterState> _adapterStateStreamCtrl =
      _ValueStreamController(initialValue: BleAdapterState.unknown);

  final _ValueStreamController<BluetoothConnectionState>
      _connectionStateStreamCtrl =
      _ValueStreamController(initialValue: const IdleState());

  final _ValueStreamController<List<BluetoothDevice>> _scanResultsStreamCtrl =
      _ValueStreamController(initialValue: const []);

  final _ValueStreamController<BluetoothDevice?> _currentDeviceStreamCtrl =
      _ValueStreamController<BluetoothDevice?>();

  final _ValueStreamController<Set<BluetoothCharacteristicRole>>
      _characteristicRolesStreamCtrl =
      _ValueStreamController(initialValue: const {});

  final _ValueStreamController<BluetoothDataReceived> _dataStreamCtrl =
      _ValueStreamController();

  final _ValueStreamController<BluetoothError> _errorStreamCtrl =
      _ValueStreamController();

  final _ValueStreamController<BluetoothMetricSnapshot> _metricsStreamCtrl =
      _ValueStreamController(initialValue: const BluetoothMetricSnapshot());

  final _ValueStreamController<BluetoothPacketProgress> _progressStreamCtrl =
      _ValueStreamController();

  final _ValueStreamController<BluetoothTransferEvent> _transferEventsStreamCtrl =
      _ValueStreamController();

  // MARK: 只读属性

  /// 蓝牙适配器当前状态。
  BleAdapterState get adapterState => _adapterState;

  /// 当前连接状态。
  BluetoothConnectionState get connectionState => _connectionState;

  /// 当前已连接的设备。
  BluetoothDevice? get currentDevice => _connectedDevice;

  /// 当前传输配置。
  BluetoothTransferConfiguration get configuration => _configuration;

  /// 当前运行时指标。
  BluetoothMetricSnapshot get metrics => _metrics;

  /// 当前是否有传输进行中。
  bool get isTransferActive => _activeTransfer != null;

  // MARK: Stream API（订阅即得当前值，流永不主动关闭）

  /// 蓝牙适配器状态流（unknown / poweredOn / poweredOff ...）。
  Stream<BleAdapterState> get adapterStateStream =>
      _adapterStateStreamCtrl.stream;

  /// 连接状态机流（scanning / connecting / ready / disconnected ...）。
  Stream<BluetoothConnectionState> get connectionStateStream =>
      _connectionStateStreamCtrl.stream;

  /// 扫描结果快照流（按 RSSI 降序），停止扫描后保留最后结果。
  Stream<List<BluetoothDevice>> get scanResultsStream =>
      _scanResultsStreamCtrl.stream;

  /// 当前连接设备流（断开后推送 null）。
  Stream<BluetoothDevice?> get currentDeviceStream =>
      _currentDeviceStreamCtrl.stream;

  /// 已就绪的特征角色流（可收发数据的角色集合）。
  Stream<Set<BluetoothCharacteristicRole>> get characteristicRolesStream =>
      _characteristicRolesStreamCtrl.stream;

  /// 收到外设数据流（应用层帧已剥离帧头，角色见 [BluetoothDataReceived.role]）。
  Stream<BluetoothDataReceived> get dataStream => _dataStreamCtrl.stream;

  /// 错误流。
  Stream<BluetoothError> get errorStream => _errorStreamCtrl.stream;

  /// 运行时指标流（连接耗时、收发字节数、RSSI、MTU 等）。
  Stream<BluetoothMetricSnapshot> get metricsStream =>
      _metricsStreamCtrl.stream;

  /// 传输进度流（节流频率由 [BluetoothTransferConfiguration.progressThrottleMs] 控制）。
  Stream<BluetoothPacketProgress> get progressStream =>
      _progressStreamCtrl.stream;

  /// 传输生命周期流（completed / paused / resumed）。
  Stream<BluetoothTransferEvent> get transferEventsStream =>
      _transferEventsStreamCtrl.stream;

  // MARK: 初始化

  BluetoothManager._();

  /// 初始化管理器：配置原生端并开始监听底层事件。
  ///
  /// 通常在 App 启动时调用一次；后续可重复调用（幂等）。
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await bridge.configure(
        restorationIdentifier: _configuration.restorationIdentifier,
      );
    } on PlatformBridgeException catch (e) {
      _notifyFailure(_bridgeError(e));
    }
    _eventSubscription = bridge.events().listen(_handleBridgeEvent);
  }

  /// 释放资源（取消订阅与所有定时器）。
  Future<void> dispose() async {
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    _pendingReconnectTimer?.cancel();
    _activeTransfer?.cancelTimeouts();
    _activeTransfer = null;
    _initialized = false;
    // 关闭所有 Stream 控制器
    await _adapterStateStreamCtrl.close();
    await _connectionStateStreamCtrl.close();
    await _scanResultsStreamCtrl.close();
    await _currentDeviceStreamCtrl.close();
    await _characteristicRolesStreamCtrl.close();
    await _dataStreamCtrl.close();
    await _errorStreamCtrl.close();
    await _metricsStreamCtrl.close();
    await _progressStreamCtrl.close();
    await _transferEventsStreamCtrl.close();
  }

  // MARK: - Delegate 管理

  /// 添加监听者（弱引用持有，对象被回收后自动失效）。
  void addDelegate(BluetoothManagerDelegate delegate) {
    _delegates.add(WeakReference(delegate));
    _compactDelegates();
  }

  /// 移除监听者。
  void removeDelegate(BluetoothManagerDelegate delegate) {
    _delegates.removeWhere((ref) => ref.target == delegate);
  }

  /// 清理已失效的弱引用，并返回存活的 delegate 列表。
  List<BluetoothManagerDelegate> get _liveDelegates {
    final live = <BluetoothManagerDelegate>[];
    _delegates.removeWhere((ref) {
      final target = ref.target;
      if (target == null) return true; // GC 后自动移除
      live.add(target);
      return false;
    });
    return live;
  }

  void _compactDelegates() {
    _delegates.removeWhere((ref) => ref.target == null);
  }

  // MARK: - 配置

  /// 更新传输配置（通过串行队列生效，线程安全）。
  Future<void> updateConfiguration(
    BluetoothTransferConfiguration configuration,
  ) async {
    await _enqueue(() async {
      _configuration = configuration;
    });
  }

  // MARK: - 扫描

  /// 开始扫描附近 BLE 设备。
  ///
  /// - [serviceUuids]: 要过滤的 service UUID，null 则使用配置中的 profile
  /// - [timeout]: 扫描超时时间（秒），null 则使用配置中的 scanTimeout
  Future<void> startScan({
    List<String>? serviceUuids,
    double? timeout,
  }) async {
    await _enqueue(() async {
      // 蓝牙必须处于 poweredOn 状态
      if (_adapterState != BleAdapterState.poweredOn) {
        _notifyFailure(BluetoothError.adapterPoweredOff());
        return;
      }
      // 清空之前的扫描结果
      _discoveredMap.clear();
      _setConnectionState(const ScanningState());
      final targetServices =
          serviceUuids ?? _configuration.profile.scanServiceUuids;
      try {
        await bridge.startScan(serviceUuids: targetServices);
      } on PlatformBridgeException catch (e) {
        _notifyFailure(_bridgeError(e));
        _setConnectionState(const IdleState());
        return;
      }
      _scheduleScanTimeout(
        Duration(milliseconds:
            ((timeout ?? _configuration.scanTimeout) * 1000).round()),
      );
    });
  }

  /// 停止扫描。
  Future<void> stopScan() async {
    await _enqueue(() async {
      await bridge.stopScan();
      if (_connectionState is ScanningState) {
        _setConnectionState(const IdleState());
      }
    });
  }

  /// 从系统缓存中检索已知外设（之前连接过的设备）。
  Future<List<BluetoothDevice>> retrieveKnownPeripherals(
    List<String> identifiers,
  ) async {
    return _enqueue(() async {
      final raw = await bridge.retrieveKnownPeripherals(identifiers);
      final devices = [
        for (final map in raw) BluetoothDevice.fromMap(map),
      ];
      for (final device in devices) {
        _discoveredMap[device.identifier] = device;
      }
      _notifyDiscoveredDevices();
      return devices;
    });
  }

  /// 检索当前已通过系统连接的外设（如其他 App 连接的设备）。
  Future<List<BluetoothDevice>> retrieveConnectedPeripherals(
    List<String> serviceUuids,
  ) async {
    return _enqueue(() async {
      final raw = await bridge.retrieveConnectedPeripherals(serviceUuids);
      final devices = [
        for (final map in raw) BluetoothDevice.fromMap(map),
      ];
      for (final device in devices) {
        _discoveredMap[device.identifier] = device;
      }
      _notifyDiscoveredDevices();
      return devices;
    });
  }

  // MARK: - 连接

  /// 连接指定设备，开启自动重连。
  Future<void> connect(BluetoothDevice device) async {
    await _enqueue(() async {
      _shouldAutoReconnect = true;
      _reconnectAttempts = 0;
      await _connectInternal(device);
    });
  }

  /// 断开当前连接（不触发自动重连）。
  Future<void> disconnect() async {
    await _enqueue(() async {
      _shouldAutoReconnect = false;
      _pendingReconnectTimer?.cancel();
      _pendingReconnectTimer = null;
      // 取消正在进行的传输
      _cancelActiveTransfer();
      final peripheralId = _connectedPeripheralId;
      if (peripheralId == null) {
        _setConnectionState(const IdleState());
        return;
      }
      _setConnectionState(DisconnectingState(peripheralId));
      await bridge.disconnect(peripheralId);
    });
  }

  // MARK: - 数据写入（实现见 ble_manager_transfer.dart）

  /// 原始写入接口，适合临时调试或外设协议不支持 App 层包头的情况。
  /// 生产中的文件/OTA/关键命令建议优先使用 [sendReliableData]。
  ///
  /// - [data]: 要发送的原始数据
  /// - [role]: 写入特征角色，默认 commandWrite
  /// - [writeType]: 写入方式，null 则自动选择
  Future<void> sendRaw(
    List<int> data, {
    BluetoothCharacteristicRole role =
        BluetoothCharacteristicRole.commandWrite,
    BleWriteType? writeType,
  }) {
    return _sendRawImpl(this, data, role: role, writeType: writeType);
  }

  /// 可靠传输接口：App 层包头 + CRC + ACK 窗口 + 超时重试。
  ///
  /// 注意：外设固件需要按 [BluetoothProtocolCodec] 的格式回 ACK，
  /// 否则会触发超时重试。
  ///
  /// - [data]: 要发送的数据
  /// - [options]: 传输配置（角色、可靠性、窗口大小、重试次数等）
  ///
  /// 返回传输 ID，可用于关联 [BluetoothManagerDelegate.onTransferCompleted]
  /// 和 [BluetoothManagerDelegate.onTransferPaused] 回调。传输失败时返回 null。
  Future<String?> sendReliableData(
    List<int> data, {
    BluetoothTransferOptions options = const BluetoothTransferOptions(),
  }) {
    return _sendReliableDataImpl(this, data, options: options);
  }

  /// 读取指定角色的特征值（异步操作，结果通过
  /// [BluetoothManagerDelegate.onDataReceived] 回调返回）。
  ///
  /// - [role]: 要读取的特征角色，默认 read
  Future<void> readValue({
    BluetoothCharacteristicRole role = BluetoothCharacteristicRole.read,
  }) {
    return _readValueImpl(this, role: role);
  }

  /// 取消当前正在进行的传输。
  ///
  /// 清理所有超时定时器并释放传输上下文。不会断开蓝牙连接。
  /// 如果当前没有传输进行中，则什么都不做。
  Future<void> cancelTransfer() async {
    await _enqueue(() async {
      _cancelActiveTransfer();
    });
  }

  // MARK: - 内部：传输薄壳（实现见 ble_manager_transfer.dart）

  void _flushActiveTransfer() => _flushActiveTransferImpl(this);

  bool _handleApplicationFrame(BluetoothProtocolFrame frame) {
    return _handleApplicationFrameImpl(this, frame);
  }

  void _cancelActiveTransfer() => _cancelActiveTransferImpl(this);

  Future<int> _queryMaximumWriteLength(
    BleWriteType writeType, {
    required int fallback,
  }) {
    return _queryMaximumWriteLengthImpl(this, writeType, fallback: fallback);
  }

  void _resumePendingTransferIfNeeded() =>
      _resumePendingTransferIfNeededImpl(this);

  // MARK: - 内部：串行队列

  /// 将操作加入串行队列，保证顺序执行（与 iOS 的专用串行队列等价）。
  Future<T> _enqueue<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _operationQueue = _operationQueue.then((_) async {
      try {
        completer.complete(await action());
      } catch (e, s) {
        completer.completeError(e, s);
      }
    });
    return completer.future;
  }

  // MARK: - 内部：连接流程

  /// 实际连接外设的内部方法。
  Future<void> _connectInternal(BluetoothDevice device) async {
    // 先停止扫描，避免扫描和连接抢占资源
    await bridge.stopScan();
    // 取消正在进行的传输
    _cancelActiveTransfer();
    // 清空特征缓存
    _characteristicsByRole.clear();
    _characteristicRolesByUuid.clear();
    _connectedPeripheralId = device.identifier;
    // 记录设备引用：连接失败/超时后自动重连需要它
    // （与 iOS 参考实现 connectInternal 中设置 connectedPeripheral 一致）
    _connectedDevice = device;
    // 重置特征发现去重表
    _characteristicDiscoveryRequested.clear();
    // 记录连接开始时间
    _metrics = _metrics.copyWith(
      connectStartedAt: DateTime.now(),
      clearReadyAt: true,
    );
    _setConnectionState(ConnectingState(device.identifier));
    try {
      await bridge.connect(
        device.identifier,
        timeout: Duration(
          milliseconds: (_configuration.connectTimeout * 1000).round(),
        ),
      );
    } on PlatformBridgeException catch (e) {
      _notifyFailure(_bridgeError(e));
    }
  }

  /// 设置扫描超时定时器。
  void _scheduleScanTimeout(Duration timeout) {
    Timer(timeout, () {
      _enqueue(() async {
        await bridge.stopScan();
        if (_connectionState is ScanningState) {
          _setConnectionState(const IdleState());
        }
      });
    });
  }

  /// 触发自动重连（指数退避 + 随机抖动）。
  ///
  /// 延迟序列（baseDelay=1s 时的示例）：
  /// 第 1 次：0.5~1.0s  第 2 次：1.0~2.0s  第 3 次：2.0~4.0s
  /// 第 4 次：4.0~8.0s  第 5 次：8.0~16.0s（上限 16s）
  /// 加入随机抖动（equal jitter）避免多设备同时断连后同步重连造成
  /// "惊群效应"。
  void _scheduleReconnect() {
    // 检查是否允许重连、外设已断开、且未超过最大次数
    if (!_shouldAutoReconnect) return;
    final device = _connectedDevice;
    if (device == null) return;
    if (_reconnectAttempts >= _configuration.reconnectMaxAttempts) return;

    _reconnectAttempts += 1;
    _metrics = _metrics.copyWith(reconnectAttempts: _reconnectAttempts);
    // 指数退避：baseDelay × 2^(attempt-1)，上限 16 秒
    final baseDelay = _minDouble(
      (1 << (_reconnectAttempts - 1)).toDouble() *
          _configuration.reconnectBaseDelay,
      16,
    );
    // equal jitter：保留一半固定延迟 + 一半随机延迟
    final jitter = 0.5 * baseDelay;
    final delay = baseDelay / 2 + jitter;
    _setConnectionState(
      ReconnectingState(device.identifier, _reconnectAttempts),
    );
    _notifyMetrics();

    // 延迟后重新连接
    _pendingReconnectTimer?.cancel();
    _pendingReconnectTimer = Timer(
      Duration(milliseconds: (delay * 1000).round()),
      () {
        _enqueue(() => _connectInternal(device));
      },
    );
  }

  // MARK: - 内部：特征发现与就绪

  /// 特征发现后，匹配角色并设置通知。
  void _markReadyIfPossible(
    BleServiceInfo service,
    BleCharacteristicInfo characteristic,
  ) {
    final profile = _configuration.profile;
    // 方式一：根据 profile 配置匹配角色
    var role = profile.roleFor(
      serviceUuid: service.uuid,
      characteristicUuid: characteristic.uuid,
    );
    if (role == null && profile.characteristics.isEmpty) {
      // Demo fallback：没有 profile 时根据属性自动猜测角色。线上不要依赖这个逻辑。
      if (characteristic.properties
              .contains(BluetoothCharacteristicProperty.notify) ||
          characteristic.properties
              .contains(BluetoothCharacteristicProperty.indicate)) {
        role = BluetoothCharacteristicRole.notify;
      }
      if (characteristic.properties
              .contains(BluetoothCharacteristicProperty.writeWithoutResponse) ||
          characteristic.properties
              .contains(BluetoothCharacteristicProperty.write)) {
        // 有写入属性 → 命令/数据写入角色
        final writeRole = _characteristicRolesByUuid[characteristic.uuid];
        if (writeRole == null ||
            writeRole == BluetoothCharacteristicRole.notify) {
          final target = _TargetCharacteristic(
            service.uuid,
            characteristic.uuid,
            characteristic.properties,
          );
          _characteristicsByRole[BluetoothCharacteristicRole.commandWrite] =
              target;
          _characteristicsByRole[BluetoothCharacteristicRole.dataWrite] =
              target;
          _characteristicRolesByUuid[characteristic.uuid] =
              BluetoothCharacteristicRole.dataWrite;
        }
      }
      if (characteristic.properties
          .contains(BluetoothCharacteristicProperty.read)) {
        role ??= BluetoothCharacteristicRole.read;
      }
    }
    if (role != null) {
      _characteristicsByRole[role] = _TargetCharacteristic(
        service.uuid,
        characteristic.uuid,
        characteristic.properties,
      );
      _characteristicRolesByUuid[characteristic.uuid] = role;
    }

    // 判断是否需要订阅通知
    final shouldNotifyByProfile = profile.characteristics.any(
      (c) =>
          c.serviceUuid.toLowerCase() == service.uuid.toLowerCase() &&
          c.characteristicUuid.toLowerCase() ==
              characteristic.uuid.toLowerCase() &&
          c.enableNotify,
    );
    final hasNotifyProperty = characteristic.properties
            .contains(BluetoothCharacteristicProperty.notify) ||
        characteristic.properties
            .contains(BluetoothCharacteristicProperty.indicate);
    if (shouldNotifyByProfile || hasNotifyProperty) {
      final deviceId = _connectedPeripheralId;
      if (deviceId != null) {
        bridge.setNotifyValue(
          deviceId,
          service.uuid,
          characteristic.uuid,
          enabled: true,
        );
      }
    }

    // 至少有一个特征就绪时，标记整体就绪
    if (_characteristicsByRole.isNotEmpty) {
      _markReady();
    }
  }

  /// 标记设备已就绪，可开始传输。
  void _markReady() {
    final deviceId = _connectedPeripheralId;
    if (deviceId == null) return;
    if (_metrics.readyAt == null) {
      _metrics = _metrics.copyWith(readyAt: DateTime.now());
    }
    // 异步记录最大写入长度
    _queryMaximumWriteLength(BleWriteType.withoutResponse, fallback: 20)
        .then((length) {
      _metrics = _metrics.copyWith(maximumWriteLength: length);
      _notifyMetrics();
    });
    _setConnectionState(ReadyState(deviceId));
    _notifyReadyRoles();
    _notifyMetrics();
    // 主动请求更大的 MTU（Android 生效；iOS 自动协商，返回当前值）。
    // 协商结果通过 mtuChanged 事件更新 metrics.maximumWriteLength。
    BluetoothManager.bridge
        .requestMtu(deviceId, 512)
        .catchError((Object e) {
      // MTU 协商失败不影响连接，忽略
      return 0;
    });
    // 如果有待恢复的断点续传，自动恢复
    _resumePendingTransferIfNeeded();
  }

  // MARK: - 内部：事件处理

  /// 处理原生底层事件（统一入口）。
  Future<void> _handleBridgeEvent(BleBridgeEvent event) async {
    await _enqueue(() async {
      switch (event) {
        case BleStateChangedEvent(:final state):
          _adapterState = state;
          _adapterStateStreamCtrl.add(state);
          for (final delegate in _liveDelegates) {
            delegate.onAdapterStateChanged(state);
          }
        case BleDeviceDiscoveredEvent(:final deviceId, :final name, :final rssi):
          _metrics = _metrics.copyWith(lastRSSI: rssi);
          _discoveredMap[deviceId] = BluetoothDevice(
            identifier: deviceId,
            name: name,
            rssi: rssi,
          );
          _notifyDiscoveredDevices();
          _notifyMetrics();
        case BleConnectionChangedEvent(
            :final deviceId,
            :final state,
            :final error
          ):
          await _handleConnectionChanged(deviceId, state, error);
        case BleServicesDiscoveredEvent(:final deviceId, :final service):
          await _handleServicesDiscovered(deviceId, service);
        case BleCharacteristicValueChangedEvent(
            :final deviceId,
            :final serviceId,
            :final characteristicId,
            :final value
          ):
          _handleValueChanged(deviceId, serviceId, characteristicId, value);
        case BleWriteCompletedEvent(
            :final deviceId,
            :final serviceId,
            :final characteristicId,
            :final error
          ):
          _handleWriteCompleted(deviceId, serviceId, characteristicId, error);
        case BleReadFailedEvent(:final error):
          // 读操作失败：通知错误，但不取消写入传输队列
          _notifyFailure(BluetoothError.platformError(
            error ?? 'Read failed.',
            {'code': 'readFailed'},
          ));
        case BleReadyToWriteEvent():
          _flushActiveTransfer();
        case BleMtuChangedEvent(:final mtu):
          _metrics = _metrics.copyWith(
            maximumWriteLength:
                mtu > 0 ? mtu - 3 : _metrics.maximumWriteLength,
          );
          _notifyMetrics();
        case BleStateRestoredEvent(:final deviceId):
          // App 被系统杀掉后恢复连接：重新走服务发现流程
          _connectedPeripheralId = deviceId;
          final device = BluetoothDevice(
            identifier: deviceId,
            name: 'Restored Device',
          );
          _connectedDevice = device;
          _currentDeviceStreamCtrl.add(device);
          _setConnectionState(DiscoveringState(deviceId));
          for (final delegate in _liveDelegates) {
            delegate.onDeviceConnected(device);
          }
          await bridge.discoverServices(
            deviceId,
            serviceUuids: _configuration.profile.serviceUuids,
          );
      }
    });
  }

  /// 处理底层连接状态变化。
  Future<void> _handleConnectionChanged(
    String deviceId,
    String state,
    String? error,
  ) async {
    switch (state) {
      case 'connected':
        // 重置重连计数
        _reconnectAttempts = 0;
        _metrics = _metrics.copyWith(reconnectAttempts: 0);
        final device = _discoveredMap[deviceId] ??
            BluetoothDevice(identifier: deviceId, name: 'Bluetooth Device');
        _connectedDevice = device;
        _connectedPeripheralId = deviceId;
        _currentDeviceStreamCtrl.add(device);
        // 进入服务发现阶段
        _setConnectionState(DiscoveringState(deviceId));
        for (final delegate in _liveDelegates) {
          delegate.onDeviceConnected(device);
        }
        await bridge.discoverServices(
          deviceId,
          serviceUuids: _configuration.profile.serviceUuids,
        );
      case 'disconnected':
        await _handleDisconnected(deviceId, error);
      case 'failed':
        _notifyFailure(_connectionFailedError(error));
        _scheduleReconnect();
    }
  }

  /// 处理断开。
  Future<void> _handleDisconnected(String deviceId, String? error) async {
    final device = _connectedDevice;
    // 清理特征缓存
    _characteristicsByRole.clear();
    _characteristicRolesByUuid.clear();
    _characteristicDiscoveryRequested.clear();
    // 处理正在进行的传输
    final transfer = _activeTransfer;
    if (transfer != null) {
      if (transfer.options.supportsResume && error != null) {
        // 断点续传：保存上下文，等待重连后恢复
        _pendingResume = _PendingResumeContext(
          data: transfer.sourceData,
          maxPayloadLength: transfer.maxPayloadLength,
          options: transfer.options,
          ackedOffset: transfer.ackedOffset,
          transferId: transfer.id,
        );
        final pausedId = transfer.id;
        final pausedOffset = transfer.ackedOffset;
        _cancelActiveTransfer();
        _transferEventsStreamCtrl.add(
          BluetoothTransferPaused(
            transferId: pausedId,
            ackedOffset: pausedOffset,
          ),
        );
        for (final delegate in _liveDelegates) {
          delegate.onTransferPaused(pausedId, pausedOffset);
        }
      } else {
        // 不支持续传或主动断开 → 直接取消
        _cancelActiveTransfer();
      }
    }
    _setConnectionState(DisconnectedState(deviceId));
    for (final delegate in _liveDelegates) {
      delegate.onDeviceDisconnected(device, error);
    }

    if (error != null && _shouldAutoReconnect) {
      // 异常断开且允许重连 → 触发自动重连（保留设备引用供重连使用）
      _scheduleReconnect();
    } else {
      // 主动断开或不允许重连 → 清空引用，释放内存
      _connectedPeripheralId = null;
      _connectedDevice = null;
      _currentDeviceStreamCtrl.add(null);
    }
  }

  /// 处理服务发现事件。
  Future<void> _handleServicesDiscovered(
    String deviceId,
    BleServiceInfo service,
  ) async {
    if (service.uuid.isEmpty) return;
    // 特征为空 → 继续发现特征（iOS 流程）
    if (service.characteristics.isEmpty) {
      // 同一服务只请求一次特征发现，避免 Android 空服务导致的循环请求
      final key = '$deviceId|${service.uuid.toLowerCase()}';
      if (_characteristicDiscoveryRequested.contains(key)) return;
      _characteristicDiscoveryRequested.add(key);
      await bridge.discoverCharacteristics(
        deviceId,
        service.uuid,
        characteristicUuids:
            _configuration.profile.characteristicUuidsFor(service.uuid),
      );
      return;
    }
    // 特征已齐 → 匹配角色（Android 流程 / iOS 特征发现完成）
    for (final characteristic in service.characteristics) {
      _markReadyIfPossible(service, characteristic);
    }
  }

  /// 处理特征值更新（notify 推送 / read 响应均触发）。
  void _handleValueChanged(
    String deviceId,
    String serviceId,
    String characteristicId,
    Uint8List value,
  ) {
    // 更新接收字节数
    _metrics = _metrics.copyWith(
      receivedBytes: _metrics.receivedBytes + value.length,
    );
    // 根据特征 UUID 反查角色
    final role = _characteristicRolesByUuid[characteristicId];

    // 尝试解码为应用层帧
    final frame = BluetoothProtocolCodec.decode(value);
    if (frame != null) {
      if (_handleApplicationFrame(frame)) {
        // 是 ACK 帧且已处理
        _notifyMetrics();
        return;
      }
      // 是应用层帧但非 ACK（如 .data / .complete / .resumeRequest）
      // 传递纯净 payload，不包含帧头
      _dataStreamCtrl.add(BluetoothDataReceived(
        data: frame.payload,
        role: role,
        deviceId: deviceId,
      ));
      for (final delegate in _liveDelegates) {
        delegate.onDataReceived(frame.payload, role);
      }
      _notifyMetrics();
      return;
    }

    // 非应用层帧（裸数据），直接传递原始字节
    _dataStreamCtrl.add(BluetoothDataReceived(
      data: value,
      role: role,
      deviceId: deviceId,
    ));
    for (final delegate in _liveDelegates) {
      delegate.onDataReceived(value, role);
    }
    _notifyMetrics();
  }

  /// 处理写入完成回调（仅 withResponse 模式触发）。
  void _handleWriteCompleted(
    String deviceId,
    String serviceId,
    String characteristicId,
    String? error,
  ) {
    if (error != null) {
      _notifyFailure(BluetoothError.platformError(error));
      // 写入失败，取消当前传输，避免卡在等 ACK 超时
      _cancelActiveTransfer();
      return;
    }
    // 释放一个写入响应槽位
    _activeTransfer?.releaseWriteResponseSlot();
    // 继续刷新传输队列
    _flushActiveTransfer();
  }

  // MARK: - 内部：状态管理

  /// 设置连接状态并通知 delegate。
  void _setConnectionState(BluetoothConnectionState state) {
    _connectionState = state;
    _connectionStateStreamCtrl.add(state);
    for (final delegate in _liveDelegates) {
      delegate.onConnectionStateChanged(state);
    }
  }

  // MARK: - 内部：通知方法

  /// 通知 delegate 设备列表更新（按 RSSI 降序排列，信号强的在前）。
  void _notifyDiscoveredDevices() {
    final devices = _discoveredMap.values.toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
    _scanResultsStreamCtrl.add(devices);
    for (final delegate in _liveDelegates) {
      delegate.onDevicesDiscovered(devices);
    }
  }

  /// 将连接失败事件映射为具体错误类型。
  ///
  /// 原生端超时通过事件上报（不经过 MethodChannel 错误码），
  /// 这里按错误文本识别超时，使 [BluetoothErrorType.connectTimeout]
  /// 对调用方生效；其余错误保留为平台错误。
  BluetoothError _connectionFailedError(String? error) {
    if (error == null) return const BluetoothError.peripheralNotFound();
    final lower = error.toLowerCase();
    if (lower.contains('timed out') || lower.contains('timeout')) {
      return const BluetoothError.connectTimeout();
    }
    return BluetoothError.platformError(error);
  }

  /// 通知 delegate 特征角色就绪。
  void _notifyReadyRoles() {
    final roles = _characteristicsByRole.keys.toSet();
    _characteristicRolesStreamCtrl.add(roles);
    for (final delegate in _liveDelegates) {
      delegate.onCharacteristicsReady(roles);
    }
  }

  /// 通知 delegate 传输进度（节流：最少间隔由配置决定，传输完成时立即通知）。
  void _notifyProgress() {
    final transfer = _activeTransfer;
    if (transfer == null) return;
    final now = DateTime.now();
    final isComplete = transfer.isComplete;
    // 节流：非完成状态下至少间隔 progressThrottleMs，避免高频回调卡顿主线程
    final throttleMs = _configuration.progressThrottleMs;
    if (!isComplete && throttleMs > 0) {
      final last = _lastProgressNotifyTime;
      if (last != null &&
          now.difference(last) < Duration(milliseconds: throttleMs)) {
        return;
      }
    }
    _lastProgressNotifyTime = now;
    final progress = BluetoothPacketProgress(
      sentBytes: transfer.ackedPayloadBytes,
      totalBytes: transfer.totalPayloadBytes,
    );
    _progressStreamCtrl.add(progress);
    for (final delegate in _liveDelegates) {
      delegate.onTransferProgress(progress);
    }
  }

  /// 通知 delegate 指标更新。
  void _notifyMetrics() {
    final snapshot = _metrics;
    _metricsStreamCtrl.add(snapshot);
    for (final delegate in _liveDelegates) {
      delegate.onMetricsUpdated(snapshot);
    }
  }

  /// 通知 delegate 发生错误。
  void _notifyFailure(BluetoothError error) {
    _errorStreamCtrl.add(error);
    for (final delegate in _liveDelegates) {
      delegate.onError(error);
    }
  }

  // MARK: - 工具方法

  /// 将平台桥接异常映射为具体的蓝牙错误类型。
  BluetoothError _bridgeError(PlatformBridgeException e) {
    switch (e.code) {
      case 'connectTimeout':
        return const BluetoothError.connectTimeout();
      case 'peripheralNotFound':
        return const BluetoothError.peripheralNotFound();
      case 'missingPermission':
        return BluetoothError.platformError(
          'Bluetooth permission not granted.',
          {'code': e.code},
        );
      default:
        return BluetoothError.platformError(e.message, {'code': e.code});
    }
  }

  static double _minDouble(double a, double b) => a < b ? a : b;
}

/// 带最近值缓存的广播流控制器（BehaviorSubject 语义，零依赖）。
///
/// 每个新订阅者订阅时立即重放最近一次值（per-subscription，不影响
/// 已有订阅者），与 flutter_blue_plus 的流行为一致：页面重建后
/// 订阅即可拿到当前状态，无需先查 getter。
class _ValueStreamController<T> {
  /// 内部广播控制器（订阅分发由 [stream] 的 Stream.multi 完成）。
  final StreamController<T> _controller = StreamController<T>.broadcast();

  /// 最近一次值。
  T? _value;

  /// 是否已推送过值。
  bool _hasValue;

  _ValueStreamController({T? initialValue})
      : _hasValue = initialValue != null,
        _value = initialValue;

  /// 最近一次值（未推送过时为初始值）。
  T? get value => _value;

  /// 对外暴露的流：每个订阅者立即收到当前值，随后收到增量事件。
  ///
  /// 控制器已关闭（dispose 后）时：重放缓存值后正常关闭，不抛错。
  Stream<T> get stream => Stream.multi((listener) {
        if (_hasValue) {
          listener.add(_value as T);
        }
        // 已关闭（dispose 后）：只能拿到最近值，流立即结束
        if (_controller.isClosed) {
          listener.close();
          return;
        }
        final sub = _controller.stream.listen(
          listener.add,
          onError: listener.addError,
          onDone: listener.close,
        );
        listener.onCancel = sub.cancel;
      });

  /// 推送新值：缓存并广播给所有订阅者。
  void add(T newValue) {
    _hasValue = true;
    _value = newValue;
    if (!_controller.isClosed) {
      _controller.add(newValue);
    }
  }

  /// 关闭流（幂等：重复调用安全）。
  Future<void> close() {
    if (_controller.isClosed) return Future.value();
    return _controller.close();
  }
}

/// 角色对应的目标特征（服务 UUID + 特征 UUID + 属性）。
class _TargetCharacteristic {
  final String serviceId;
  final String characteristicId;
  final Set<BluetoothCharacteristicProperty> properties;

  const _TargetCharacteristic(
    this.serviceId,
    this.characteristicId,
    this.properties,
  );
}

/// 断点续传上下文（断连时保存，重连后恢复）。
class _PendingResumeContext {
  final Uint8List data;
  final int maxPayloadLength;
  final BluetoothTransferOptions options;
  final int ackedOffset;
  final String transferId;

  const _PendingResumeContext({
    required this.data,
    required this.maxPayloadLength,
    required this.options,
    required this.ackedOffset,
    required this.transferId,
  });
}

