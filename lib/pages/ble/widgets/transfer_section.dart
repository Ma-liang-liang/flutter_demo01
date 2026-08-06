import 'package:ble_plugin/ble_plugin.dart';
import 'package:flutter/material.dart';

import '../../../widgets/section_card.dart';

/// 数据传输区域
class TransferSection extends StatelessWidget {
  const TransferSection({
    super.key,
    required this.readyRoles,
    required this.progress,
    required this.hasActiveTransfer,
    required this.activeTransferId,
    required this.hasWriteRole,
    required this.hasReadRole,
    required this.dataController,
    required this.onSendRaw,
    required this.onSendReliable,
    required this.onCancelTransfer,
    required this.onReadValue,
  });

  final Set<BluetoothCharacteristicRole> readyRoles;
  final BluetoothPacketProgress? progress;
  final bool hasActiveTransfer;
  final String? activeTransferId;
  final bool hasWriteRole;
  final bool hasReadRole;
  final TextEditingController dataController;
  final VoidCallback onSendRaw;
  final VoidCallback onSendReliable;
  final VoidCallback onCancelTransfer;
  final VoidCallback onReadValue;

  @override
  Widget build(BuildContext context) {
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
            Text('传输进度', style: theme.textTheme.labelMedium),
            const Spacer(),
            Text(
              '${progress.sentBytes} / ${progress.totalBytes} bytes',
              style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
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
