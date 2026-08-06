import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'viewmodel/ble_bloc.dart';
import 'widgets/adapter_section.dart';
import 'widgets/connection_state_section.dart';
import 'widgets/device_list_section.dart';
import 'widgets/log_section.dart';
import 'widgets/metrics_section.dart';
import 'widgets/transfer_section.dart';

/// BLE 蓝牙插件功能演示页面（MVVM + BLoC）
///
/// View 层职责：
/// - 通过 BlocProvider 创建 BleBloc
/// - 通过 BlocBuilder 消费 BleState 渲染 UI
/// - 用户操作转为事件发送给 Bloc
///
/// View 不含任何业务逻辑，所有 BLE 交互通过 Bloc 事件驱动。
class BleDemoPage extends StatelessWidget {
  const BleDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => BleBloc()..add(const BleStarted()),
      child: const _BleView(),
    );
  }
}

class _BleView extends StatefulWidget {
  const _BleView();

  @override
  State<_BleView> createState() => _BleViewState();
}

class _BleViewState extends State<_BleView> {
  final _dataController = TextEditingController(text: 'Hello BLE');

  @override
  void dispose() {
    _dataController.dispose();
    super.dispose();
  }

  void _dispatch(BuildContext context, BleEvent event) =>
      context.read<BleBloc>().add(event);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BleBloc, BleState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('BLE 蓝牙插件演示'),
            actions: [
              IconButton(
                onPressed: () =>
                    _dispatch(context, const BleLogCleared()),
                icon: const Icon(Icons.delete_outline),
                tooltip: '清空日志',
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AdapterSection(
                adapterState: state.adapterState,
                isScanning: state.isScanning,
                onScanToggled: () =>
                    _dispatch(context, const BleScanToggled()),
              ),
              if (state.devices.isNotEmpty)
                DeviceListSection(
                  devices: state.devices,
                  connectedDeviceId: state.connectedDeviceId,
                  onConnect: (device) =>
                      _dispatch(context, BleDeviceSelected(device)),
                  onDisconnect: () =>
                      _dispatch(context, const BleDisconnectRequested()),
                ),
              if (state.isReady)
                TransferSection(
                  readyRoles: state.readyRoles,
                  progress: state.progress,
                  hasActiveTransfer: state.hasActiveTransfer,
                  activeTransferId: state.activeTransferId,
                  hasWriteRole: state.hasWriteRole,
                  hasReadRole: state.hasReadRole,
                  dataController: _dataController,
                  onSendRaw: () => _dispatch(
                      context, BleSendRawRequested(_dataController.text)),
                  onSendReliable: () => _dispatch(
                      context, BleSendReliableRequested(_dataController.text)),
                  onCancelTransfer: () =>
                      _dispatch(context, const BleCancelTransferRequested()),
                  onReadValue: () =>
                      _dispatch(context, const BleReadValueRequested()),
                ),
              MetricsSection(metrics: state.metrics),
              ConnectionStateSection(state: state.connectionState),
              LogSection(
                logs: state.logs,
                onCleared: () =>
                    _dispatch(context, const BleLogCleared()),
              ),
            ],
          ),
        );
      },
    );
  }
}
