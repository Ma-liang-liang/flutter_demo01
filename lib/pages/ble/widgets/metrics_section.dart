import 'package:ble_plugin/ble_plugin.dart';
import 'package:flutter/material.dart';

import '../../../widgets/section_card.dart';

/// 运行时指标区域
class MetricsSection extends StatelessWidget {
  const MetricsSection({super.key, required this.metrics});

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
              style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}
