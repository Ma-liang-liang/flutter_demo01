import 'dart:typed_data';

import 'package:ble_plugin/ble_plugin.dart';
import 'package:flutter/material.dart';

import '../widgets/section_card.dart';

/// BLE 蓝牙插件功能演示页面
///
/// 充分展示 ble_plugin 的核心能力：
/// - 适配器状态监听
/// - 设备扫描与列表展示
/// - 连接 / 断开 / 自动重连状态机
/// - 裸数据写入（sendRaw）
/// - 可靠传输（sendReliableData）含 ACK 窗口与进度
/// - 读取特征值（readValue）
/// - 传输取消（cancelTransfer）
/// - 运行时指标统计
/// - 断点续传上下文
class BleDemoPage extends StatefulWidget {
  const BleDemoPage({super.key});

  @override
  State<BleDemoPage> createState() => _BleDemoPageState();
}

class _BleDemoPageState extends State<BleDemoPage>
    with BluetoothManagerDelegate {
  // ──────────────────────────────────────────────────────────
  // 状态
  // ──────────────────────────────────────────────────────────

  final _manager = BluetoothManager.shared;

  /// 适配器状态
  BleAdapterState _adapterState = BleAdapterState.unknown;

  /// 连接状态机
  BluetoothConnectionState _connectionState = const IdleState();

  /// 已发现设备列表
  List<BluetoothDevice> _devices = [];

  /// 就绪的特征角色
  Set<BluetoothCharacteristicRole> _readyRoles = {};

  /// 传输进度
  BluetoothPacketProgress? _progress;

  /// 运行时指标
  BluetoothMetricSnapshot _metrics = const BluetoothMetricSnapshot();

  /// 事件日志
  final List<String> _logs = [];

  /// 当前传输 ID
  String? _activeTransferId;

  /// 输入框控制器
  final _dataController = TextEditingController(text: 'Hello BLE');

  // ──────────────────────────────────────────────────────────
  // 生命周期
  // ──────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _manager.addDelegate(this);
    _manager.init().then((_) {
      _log('BluetoothManager 初始化完成');
    });
  }

  @override
  void dispose() {
    _manager.removeDelegate(this);
    _dataController.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────
  // Delegate 回调
  // ──────────────────────────────────────────────────────────

  @override
  void onAdapterStateChanged(BleAdapterState state) {
    setState(() {
      _adapterState = state;
    });
    _log('适配器状态: ${state.name}');
  }

  @override
  void onConnectionStateChanged(BluetoothConnectionState state) {
    setState(() {
      _connectionState = state;
    });
    _log('连接状态: $state');
  }

  @override
  void onDevicesDiscovered(List<BluetoothDevice> devices) {
    setState(() {
      _devices = devices;
    });
    _log('发现 ${devices.length} 个设备');
  }

  @override
  void onCharacteristicsReady(Set<BluetoothCharacteristicRole> roles) {
    setState(() {
      _readyRoles = roles;
    });
    _log('特征就绪: ${roles.map((r) => r.name).join(', ')}');
  }

  @override
  void onDataReceived(List<int> data, BluetoothCharacteristicRole? role) {
    _log('收到数据 [${role?.name ?? 'unknown'}]: ${data.length} bytes');
  }

  @override
  void onTransferProgress(BluetoothPacketProgress progress) {
    setState(() {
      _progress = progress;
    });
  }

  @override
  void onTransferCompleted(String transferId) {
    _log('传输完成: $transferId');
    setState(() {
      _activeTransferId = null;
      _progress = null;
    });
  }

  @override
  void onTransferPaused(String transferId, int ackedOffset) {
    _log('传输暂停 [断点续传]: $transferId @ $ackedOffset bytes');
  }

  @override
  void onTransferResumed(String transferId, int fromOffset) {
    _log('传输恢复 [断点续传]: $transferId from $fromOffset bytes');
  }

  @override
  void onMetricsUpdated(BluetoothMetricSnapshot metrics) {
    setState(() {
      _metrics = metrics;
    });
  }

  @override
  void onError(BluetoothError error) {
    _log('错误: ${error.type.name} — ${error.message}');
  }

  // ──────────────────────────────────────────────────────────
  // 操作
  // ──────────────────────────────────────────────────────────

  Future<void> _startScan() async {
    _log('开始扫描...');
    await _manager.startScan();
  }

  Future<void> _stopScan() async {
    await _manager.stopScan();
    _log('停止扫描');
  }

  Future<void> _connectDevice(BluetoothDevice device) async {
    _log('连接设备: ${device.name} (${device.identifier})');
    await _manager.connect(device);
  }

  Future<void> _disconnect() async {
    _log('断开连接...');
    await _manager.disconnect();
  }

  Future<void> _sendRaw() async {
    final data = Uint8List.fromList(_dataController.text.codeUnits);
    _log('发送裸数据: ${data.length} bytes');
    await _manager.sendRaw(data);
  }

  Future<void> _sendReliable() async {
    final data = Uint8List.fromList(_dataController.text.codeUnits);
    _log('发送可靠数据: ${data.length} bytes');
    final id = await _manager.sendReliableData(data);
    if (id != null) {
      setState(() {
        _activeTransferId = id;
      });
      _log('传输已创建: $id');
    }
  }

  Future<void> _cancelTransfer() async {
    _log('取消传输...');
    await _manager.cancelTransfer();
    setState(() {
      _activeTransferId = null;
      _progress = null;
    });
  }

  Future<void> _readValue() async {
    _log('读取特征值...');
    await _manager.readValue();
  }

  // ──────────────────────────────────────────────────────────
  // UI
  // ──────────────────────────────────────────────────────────

  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    setState(() {
      _logs.insert(0, '[$timestamp] $message');
      if (_logs.length > 50) _logs.removeLast();
    });
  }

  bool get _isReady => _connectionState is ReadyState;
  bool get _isScanning => _connectionState is ScanningState;
  bool get _hasActiveTransfer => _activeTransferId != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE 蓝牙插件演示'),
        actions: [
          IconButton(
            onPressed: () => setState(_logs.clear),
            icon: const Icon(Icons.delete_outline),
            tooltip: '清空日志',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AdapterSection(
            state: _adapterState,
            onScan: _isScanning ? _stopScan : _startScan,
            isScanning: _isScanning,
          ),
          if (_devices.isNotEmpty)
            _DeviceListSection(
              devices: _devices,
              connectionState: _connectionState,
              onConnect: _connectDevice,
              onDisconnect: _disconnect,
            ),
          if (_isReady)
            _TransferSection(
              dataController: _dataController,
              readyRoles: _readyRoles,
              progress: _progress,
              hasActiveTransfer: _hasActiveTransfer,
              activeTransferId: _activeTransferId,
              onSendRaw: _sendRaw,
              onSendReliable: _sendReliable,
              onCancelTransfer: _cancelTransfer,
              onReadValue: _readValue,
            ),
          _MetricsSection(metrics: _metrics),
          _ConnectionStateSection(state: _connectionState),
          _LogSection(logs: _logs),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────
// 适配器与扫描区域
// ────────────────────────────────────────────────────────────────
class _AdapterSection extends StatelessWidget {
  const _AdapterSection({
    required this.state,
    required this.onScan,
    required this.isScanning,
  });

  final BleAdapterState state;
  final VoidCallback onScan;
  final bool isScanning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPoweredOn = state == BleAdapterState.poweredOn;

    return SectionCard(
      title: '蓝牙适配器',
      subtitle: '适配器状态与设备扫描',
      icon: Icons.bluetooth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isPoweredOn
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPoweredOn ? Icons.bluetooth : Icons.bluetooth_disabled,
                      size: 16,
                      color: isPoweredOn
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      state.name,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: isPoweredOn
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: isPoweredOn ? onScan : null,
                icon: isScanning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: Text(isScanning ? '停止扫描' : '开始扫描'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────
// 设备列表区域
// ────────────────────────────────────────────────────────────────
class _DeviceListSection extends StatelessWidget {
  const _DeviceListSection({
    required this.devices,
    required this.connectionState,
    required this.onConnect,
    required this.onDisconnect,
  });

  final List<BluetoothDevice> devices;
  final BluetoothConnectionState connectionState;
  final ValueChanged<BluetoothDevice> onConnect;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final connectedId = switch (connectionState) {
      ReadyState(:final deviceId) => deviceId,
      DiscoveringState(:final deviceId) => deviceId,
      ConnectingState(:final deviceId) => deviceId,
      ReconnectingState(:final deviceId) => deviceId,
      _ => null,
    };

    return SectionCard(
      title: '发现的设备',
      subtitle: '${devices.length} 个设备（按 RSSI 排序）',
      icon: Icons.devices,
      child: Column(
        children: [
          for (final device in devices.take(5))
            ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                child: Icon(
                  connectedId == device.identifier
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ),
              title: Text(device.name, style: theme.textTheme.bodyMedium),
              subtitle: Text(
                '${device.identifier}  ·  RSSI ${device.rssi} dBm',
                style: theme.textTheme.bodySmall,
              ),
              trailing: connectedId == device.identifier
                  ? TextButton(
                      onPressed: onDisconnect,
                      child: const Text('断开'),
                    )
                  : TextButton(
                      onPressed: () => onConnect(device),
                      child: const Text('连接'),
                    ),
            ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────
// 数据传输区域
// ────────────────────────────────────────────────────────────────
class _TransferSection extends StatelessWidget {
  const _TransferSection({
    required this.dataController,
    required this.readyRoles,
    required this.progress,
    required this.hasActiveTransfer,
    required this.activeTransferId,
    required this.onSendRaw,
    required this.onSendReliable,
    required this.onCancelTransfer,
    required this.onReadValue,
  });

  final TextEditingController dataController;
  final Set<BluetoothCharacteristicRole> readyRoles;
  final BluetoothPacketProgress? progress;
  final bool hasActiveTransfer;
  final String? activeTransferId;
  final VoidCallback onSendRaw;
  final VoidCallback onSendReliable;
  final VoidCallback onCancelTransfer;
  final VoidCallback onReadValue;

  @override
  Widget build(BuildContext context) {
    final hasWriteRole = readyRoles.contains(BluetoothCharacteristicRole.commandWrite) ||
        readyRoles.contains(BluetoothCharacteristicRole.dataWrite);
    final hasReadRole = readyRoles.contains(BluetoothCharacteristicRole.read);

    return SectionCard(
      title: '数据传输',
      subtitle: 'sendRaw / sendReliableData / readValue / cancelTransfer',
      icon: Icons.swap_horiz,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 就绪角色标签
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final role in readyRoles)
                Chip(
                  label: Text(role.name),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 12),
          // 数据输入
          TextField(
            controller: dataController,
            decoration: const InputDecoration(
              labelText: '发送数据',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          // 操作按钮
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: hasWriteRole ? onSendRaw : null,
                icon: const Icon(Icons.flash_on),
                label: const Text('裸数据'),
              ),
              FilledButton.tonalIcon(
                onPressed: hasWriteRole ? onSendReliable : null,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('可靠传输'),
              ),
              OutlinedButton.icon(
                onPressed: hasReadRole ? onReadValue : null,
                icon: const Icon(Icons.download),
                label: const Text('读取'),
              ),
              if (hasActiveTransfer)
                OutlinedButton.icon(
                  onPressed: onCancelTransfer,
                  icon: const Icon(Icons.cancel),
                  label: const Text('取消传输'),
                ),
            ],
          ),
          // 传输进度
          if (progress != null) ...[
            const SizedBox(height: 16),
            _ProgressView(progress: progress!, transferId: activeTransferId),
          ],
        ],
      ),
    );
  }
}

class _ProgressView extends StatelessWidget {
  const _ProgressView({required this.progress, required this.transferId});

  final BluetoothPacketProgress progress;
  final String? transferId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = progress.ratio;
    final isComplete = ratio >= 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '传输进度',
              style: theme.textTheme.labelMedium,
            ),
            const Spacer(),
            Text(
              '${progress.sentBytes} / ${progress.totalBytes} bytes',
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: ratio,
          minHeight: 8,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
        ),
        const SizedBox(height: 4),
        Text(
          isComplete ? '✓ 传输完成' : '${(ratio * 100).toStringAsFixed(1)}%',
          style: theme.textTheme.bodySmall?.copyWith(
            color: isComplete
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────
// 运行时指标区域
// ────────────────────────────────────────────────────────────────
class _MetricsSection extends StatelessWidget {
  const _MetricsSection({required this.metrics});

  final BluetoothMetricSnapshot metrics;

  @override
  Widget build(BuildContext context) {
    final cost = metrics.connectionCost;

    return SectionCard(
      title: '运行时指标',
      subtitle: '连接耗时 / 收发字节 / 重连次数 / 最大写入长度',
      icon: Icons.analytics,
      child: Column(
        children: [
          _MetricRow(label: '连接耗时', value: cost != null ? '${cost.inMilliseconds} ms' : '—'),
          _MetricRow(label: '已发送', value: '${metrics.transmittedBytes} bytes'),
          _MetricRow(label: '已接收', value: '${metrics.receivedBytes} bytes'),
          _MetricRow(label: '重连次数', value: '${metrics.reconnectAttempts}'),
          _MetricRow(label: '最大写入', value: '${metrics.maximumWriteLength} bytes'),
          _MetricRow(label: 'RSSI', value: metrics.lastRSSI != null ? '${metrics.lastRSSI} dBm' : '—'),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────
// 连接状态机区域
// ────────────────────────────────────────────────────────────────
class _ConnectionStateSection extends StatelessWidget {
  const _ConnectionStateSection({required this.state});

  final BluetoothConnectionState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SectionCard(
      title: '连接状态机',
      subtitle: 'idle → scanning → connecting → discovering → ready',
      icon: Icons.account_tree,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          state.toString(),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontFamily: 'monospace',
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────
// 事件日志区域
// ────────────────────────────────────────────────────────────────
class _LogSection extends StatelessWidget {
  const _LogSection({required this.logs});

  final List<String> logs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SectionCard(
      title: '事件日志',
      subtitle: '${logs.length} 条记录（最新在上）',
      icon: Icons.terminal,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 300),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: logs.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(
                logs[index],
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  height: 1.4,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
