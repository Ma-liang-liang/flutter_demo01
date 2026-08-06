import 'package:ble_plugin/ble_plugin.dart';
import 'package:flutter/material.dart';

import '../../../widgets/section_card.dart';

/// 设备列表区域
class DeviceListSection extends StatelessWidget {
  const DeviceListSection({
    super.key,
    required this.devices,
    required this.connectedDeviceId,
    required this.onConnect,
    required this.onDisconnect,
  });

  final List<BluetoothDevice> devices;
  final String? connectedDeviceId;
  final ValueChanged<BluetoothDevice> onConnect;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                  connectedDeviceId == device.identifier
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
              trailing: connectedDeviceId == device.identifier
                  ? TextButton(onPressed: onDisconnect, child: const Text('断开'))
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
