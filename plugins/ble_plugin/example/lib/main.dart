/// ble_plugin 的示例应用：BLE 调试页面。
///
/// 模仿 iOS Demo（BluetoothManager.md 8.1 节）的界面布局：
/// 顶部连接与状态 → 操作区 → 附近设备列表 → 实时日志。
library;

import 'package:ble_plugin/ble_plugin.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const BleDebugApp());
}

class BleDebugApp extends StatelessWidget {
  const BleDebugApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BLE 调试',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const BleDebugPage(),
    );
  }
}

/// 调试主页面。
class BleDebugPage extends StatefulWidget {
  const BleDebugPage({super.key});

  @override
  State<BleDebugPage> createState() => _BleDebugPageState();
}

/// 页面状态：同时实现 [BluetoothManagerDelegate]，直接消费蓝牙事件。
class _BleDebugPageState extends State<BleDebugPage>
    with BluetoothManagerDelegate {
  /// 蓝牙管理器单例。
  final BluetoothManager _manager = BluetoothManager.shared;

  // MARK: - UI 状态

  /// 最近一次适配器状态。
  BleAdapterState _adapterState = BleAdapterState.unknown;

  /// 当前连接状态。
  BluetoothConnectionState _connectionState = const IdleState();

  /// 扫描到的设备列表。
  List<BluetoothDevice> _devices = const [];

  /// 已连接的设备。
  BluetoothDevice? _connectedDevice;

  /// 特征就绪的角色集合。
  Set<BluetoothCharacteristicRole> _readyRoles = const {};

  /// 传输进度。
  BluetoothPacketProgress? _progress;

  /// 运行时指标。
  BluetoothMetricSnapshot _metrics = const BluetoothMetricSnapshot();

  /// 日志（最新在最前）。
  final List<String> _logs = [];

  // MARK: - 生命周期

  @override
  void initState() {
    super.initState();
    _manager.addDelegate(this);
    _initialize();
  }

  @override
  void dispose() {
    _manager.removeDelegate(this);
    super.dispose();
  }

  /// 初始化并启动扫描（示例 App 启动即进入调试模式）。
  Future<void> _initialize() async {
    _log('初始化蓝牙管理器…');
    await _manager.init();
    await _manager.updateConfiguration(
      const BluetoothTransferConfiguration(
        profile: BluetoothDeviceProfile.genericDemo,
        scanTimeout: 12,
        connectTimeout: 8,
        reconnectMaxAttempts: 3,
        reconnectBaseDelay: 1,
      ),
    );
    _log('初始化完成，开始扫描（12s 超时）…');
    await _manager.startScan();
  }

  // MARK: - 操作

  Future<void> _toggleScan() async {
    if (_connectionState is ScanningState) {
      _log('停止扫描');
      await _manager.stopScan();
    } else {
      _log('开始扫描…');
      await _manager.startScan();
    }
  }

  Future<void> _connect(BluetoothDevice device) async {
    _log('连接 ${device.name} (${_shortId(device.identifier)})');
    await _manager.connect(device);
  }

  Future<void> _disconnect() async {
    _log('断开连接');
    await _manager.disconnect();
  }

  Future<void> _sendCommand() async {
    // 模拟一条命令：帧头 0xAA 0x01 校验位
    final data = <int>[0xAA, 0x01, 0x55];
    _log('发送命令: ${hexString(data)}');
    await _manager.sendRaw(
      data,
      role: BluetoothCharacteristicRole.commandWrite,
    );
  }

  Future<void> _sendBulkData() async {
    // 模拟 20KB 数据（可靠传输 + 断点续传）
    final data = Uint8List.fromList(
      List.generate(20 * 1024, (i) => i % 256),
    );
    _log('可靠传输开始: ${data.length} 字节（ACK 窗口=6, 重试=3, 断点续传）');
    await _manager.sendReliableData(
      data,
      options: const BluetoothTransferOptions(
        role: BluetoothCharacteristicRole.dataWrite,
        reliability: BluetoothTransferReliability.applicationAck,
        ackWindow: 6,
        maxRetries: 3,
        ackTimeout: 1.5,
        supportsResume: true,
      ),
    );
  }

  Future<void> _read() async {
    _log('读取特征值…');
    await _manager.readValue(role: BluetoothCharacteristicRole.read);
  }

  // MARK: - 工具

  void _log(String message) {
    final now = DateTime.now();
    final time = '${now.hour.toString().padLeft(2, '0')}'
        ':${now.minute.toString().padLeft(2, '0')}'
        ':${now.second.toString().padLeft(2, '0')}';
    final line = '[$time] $message';
    debugPrint(line);
    if (!mounted) return;
    setState(() {
      _logs.insert(0, line);
      if (_logs.length > 200) _logs.removeRange(200, _logs.length);
    });
  }

  static String hexString(List<int> data) {
    final buffer = StringBuffer();
    for (final byte in data) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0').toUpperCase());
      buffer.write(' ');
    }
    return buffer.toString().trim();
  }

  static String _shortId(String id) => id.length > 8
      ? '${id.substring(0, 4)}…${id.substring(id.length - 4)}'
      : id;

  /// 连接状态文案。
  String get _stateText => switch (_connectionState) {
        IdleState() => '空闲',
        ScanningState() => '扫描中…',
        ConnectingState(:final deviceId) => '连接中 (${_shortId(deviceId)})',
        DiscoveringState() => '发现服务…',
        ReadyState(:final deviceId) => '已就绪 (${_shortId(deviceId)})',
        DisconnectingState() => '断开中…',
        DisconnectedState() => '已断开',
        ReconnectingState(:final attempt) => '重连中 (第 $attempt 次)',
        FailedState(:final message) => '失败: $message',
      };

  // MARK: - BluetoothManagerDelegate 实现

  @override
  void onAdapterStateChanged(BleAdapterState state) {
    if (!mounted) return;
    setState(() => _adapterState = state);
    _log('蓝牙状态: ${state.name}');
  }

  @override
  void onConnectionStateChanged(BluetoothConnectionState state) {
    if (!mounted) return;
    setState(() => _connectionState = state);
    _log('连接状态: $_stateText');
  }

  @override
  void onDevicesDiscovered(List<BluetoothDevice> devices) {
    if (!mounted) return;
    setState(() => _devices = devices);
  }

  @override
  void onDeviceConnected(BluetoothDevice device) {
    if (!mounted) return;
    setState(() => _connectedDevice = device);
    _log('已连接: ${device.name}');
  }

  @override
  void onDeviceDisconnected(BluetoothDevice? device, Object? error) {
    if (!mounted) return;
    setState(() {
      _connectedDevice = null;
      _readyRoles = const {};
      _progress = null;
    });
    _log(error == null ? '已断开: ${device?.name ?? ""}' : '断开(异常): $error');
  }

  @override
  void onCharacteristicsReady(Set<BluetoothCharacteristicRole> roles) {
    if (!mounted) return;
    setState(() => _readyRoles = roles);
    _log('特征就绪: ${roles.map((r) => r.name).join(", ")}');
  }

  @override
  void onDataReceived(List<int> data, BluetoothCharacteristicRole? role) {
    final preview = data.length > 24
        ? '${hexString(data.take(24).toList())} … (${data.length} B)'
        : hexString(data);
    _log('收到数据[${role?.name ?? "?"}]: $preview');
  }

  @override
  void onTransferProgress(BluetoothPacketProgress progress) {
    if (!mounted) return;
    setState(() => _progress = progress);
  }

  @override
  void onTransferCompleted(String transferId) {
    if (!mounted) return;
    setState(() => _progress = null);
    _log('传输完成: $_shortId(transferId)');
  }

  @override
  void onMetricsUpdated(BluetoothMetricSnapshot metrics) {
    if (!mounted) return;
    setState(() => _metrics = metrics);
  }

  @override
  void onError(BluetoothError error) {
    _log('错误: $error');
  }

  @override
  void onTransferPaused(String transferId, int ackedOffset) {
    _log('传输暂停(断连): $_shortId(transferId) @ $ackedOffset B');
  }

  @override
  void onTransferResumed(String transferId, int fromOffset) {
    _log('传输恢复: $_shortId(transferId) @ $fromOffset B');
  }

  // MARK: - 构建 UI

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE 调试'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bluetooth_searching),
            tooltip: '切换扫描',
            onPressed: _toggleScan,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildStatusCard(),
            _buildActionBar(),
            Expanded(
              child: _devices.isEmpty && _logs.isEmpty
                  ? const Center(child: Text('暂无设备，点击扫描开始搜索'))
                  : ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        if (_devices.isNotEmpty) ...[
                          const _SectionTitle('附近设备'),
                          ..._buildDeviceRows(),
                          const Divider(height: 24),
                        ],
                        const _SectionTitle('运行日志'),
                        ..._buildLogRows(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// 顶部：状态卡片（蓝牙状态 / 连接状态 / 设备 / 指标 / 传输进度）。
  Widget _buildStatusCard() {
    final progress = _progress;
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatusDot(active: _adapterState == BleAdapterState.poweredOn),
                const SizedBox(width: 8),
                Text(
                  '蓝牙: ${_adapterState.name}  ·  $_stateText',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _connectedDevice?.name ?? '未连接设备',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'TX: ${_metrics.transmittedBytes} B  ·  RX: ${_metrics.receivedBytes} B'
              '  ·  最大写入: ${_metrics.maximumWriteLength} B'
              '  ·  重连: ${_metrics.reconnectAttempts} 次'
              '  ·  RSSI: ${_metrics.lastRSSI ?? "-"} dBm',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              '就绪角色: ${_readyRoles.isEmpty ? "无" : _readyRoles.map((r) => r.name).join(", ")}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (progress != null && progress.totalBytes > 0) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: progress.ratio),
              const SizedBox(height: 4),
              Text(
                '传输: ${progress.sentBytes} / ${progress.totalBytes} B'
                ' (${(progress.ratio * 100).toStringAsFixed(1)}%)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 操作区：扫描 / 断开 / 发命令 / 发大数据 / 读取。
  Widget _buildActionBar() {
    final isScanning = _connectionState is ScanningState;
    final isReady = _connectionState is ReadyState;
    final canDisconnect = _connectedDevice != null &&
        (_connectionState is ReadyState ||
            _connectionState is DisconnectingState);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ActionChip(
            avatar: Icon(isScanning ? Icons.stop : Icons.search),
            label: Text(isScanning ? '停止扫描' : '扫描'),
            onPressed: _toggleScan,
          ),
          ActionChip(
            avatar: const Icon(Icons.link_off),
            label: const Text('断开'),
            onPressed: canDisconnect ? _disconnect : null,
          ),
          ActionChip(
            avatar: const Icon(Icons.send),
            label: const Text('发命令'),
            onPressed: isReady ? _sendCommand : null,
          ),
          ActionChip(
            avatar: const Icon(Icons.data_object),
            label: const Text('发大数据(20KB)'),
            onPressed: isReady ? _sendBulkData : null,
          ),
          ActionChip(
            avatar: const Icon(Icons.download),
            label: const Text('读取'),
            onPressed: isReady ? _read : null,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDeviceRows() {
    return [
      for (final device in _devices)
        ListTile(
          dense: true,
          leading: Icon(
            _connectedDevice?.identifier == device.identifier
                ? Icons.bluetooth_connected
                : Icons.bluetooth_searching,
            color: _connectedDevice?.identifier == device.identifier
                ? Colors.teal
                : null,
          ),
          title: Text(device.name),
          subtitle: Text(
            '${_shortId(device.identifier)}  ·  RSSI: ${device.rssi} dBm',
          ),
          trailing: _connectedDevice?.identifier == device.identifier
              ? const Icon(Icons.check_circle, color: Colors.teal)
              : null,
          onTap: _connectedDevice?.identifier == device.identifier
              ? null
              : () => _connect(device),
        ),
    ];
  }

  List<Widget> _buildLogRows() {
    return [
      for (final line in _logs)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: SelectableText(
            line,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
    ];
  }
}

/// 列表分组标题。
class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

/// 状态圆点（亮起表示启用）。
class _StatusDot extends StatelessWidget {
  final bool active;

  const _StatusDot({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? Colors.green : Colors.grey,
      ),
    );
  }
}
