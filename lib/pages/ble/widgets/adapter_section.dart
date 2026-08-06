import 'package:ble_plugin/ble_plugin.dart';
import 'package:flutter/material.dart';

import '../../../widgets/section_card.dart';

/// 适配器状态与扫描按钮区域
class AdapterSection extends StatelessWidget {
  const AdapterSection({
    super.key,
    required this.adapterState,
    required this.isScanning,
    required this.onScanToggled,
  });

  final BleAdapterState adapterState;
  final bool isScanning;
  final VoidCallback onScanToggled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPoweredOn = adapterState == BleAdapterState.poweredOn;

    return SectionCard(
      title: '蓝牙适配器',
      subtitle: '适配器状态与设备扫描',
      icon: Icons.bluetooth,
      child: Row(
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
                  adapterState.name,
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
            onPressed: isPoweredOn ? onScanToggled : null,
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
    );
  }
}
