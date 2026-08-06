import 'package:ble_plugin/ble_plugin.dart';
import 'package:flutter/material.dart';

import '../../../widgets/section_card.dart';

/// 连接状态机区域
class ConnectionStateSection extends StatelessWidget {
  const ConnectionStateSection({super.key, required this.state});

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
