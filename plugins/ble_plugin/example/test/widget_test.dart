// ble_plugin 示例应用的 widget 测试。
//
// 使用 FakeBleBridge 隔离真实蓝牙，仅验证 UI 能正常构建与交互。

import 'dart:async';

import 'package:ble_plugin/ble_plugin.dart';
import 'package:ble_plugin_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

/// 测试用桥接实现：不发事件、不访问原生端。
class FakeBleBridge implements BleBridge {
  @override
  Future<void> configure({required String restorationIdentifier}) async {}

  @override
  Future<void> startScan({
    List<String>? serviceUuids,
    bool allowDuplicates = false,
  }) async {}

  @override
  Future<void> stopScan() async {}

  @override
  Future<void> connect(String deviceId, {required Duration timeout}) async {}

  @override
  Future<void> disconnect(String deviceId) async {}

  @override
  Future<void> discoverServices(
    String deviceId, {
    List<String>? serviceUuids,
  }) async {}

  @override
  Future<void> discoverCharacteristics(
    String deviceId,
    String serviceId, {
    List<String>? characteristicUuids,
  }) async {}

  @override
  Future<void> readValue(
    String deviceId,
    String serviceId,
    String characteristicId,
  ) async {}

  @override
  Future<bool> writeValue(
    String deviceId,
    String serviceId,
    String characteristicId,
    List<int> value, {
    required bool writeWithResponse,
  }) async {
    return true;
  }

  @override
  Future<void> setNotifyValue(
    String deviceId,
    String serviceId,
    String characteristicId, {
    required bool enabled,
  }) async {}

  @override
  Future<int> requestMtu(String deviceId, int mtu) async => 23;

  @override
  Future<int> maximumWriteLength(
    String deviceId, {
    required bool withResponse,
  }) async {
    return 20;
  }

  @override
  Future<List<Map<String, Object?>>> retrieveKnownPeripherals(
    List<String> identifiers,
  ) async {
    return const [];
  }

  @override
  Future<List<Map<String, Object?>>> retrieveConnectedPeripherals(
    List<String> serviceUuids,
  ) async {
    return const [];
  }

  @override
  Stream<BleBridgeEvent> events() => const Stream.empty();
}

void main() {
  testWidgets('BLE 调试页可以构建并显示核心控件', (WidgetTester tester) async {
    BluetoothManager.bridge = FakeBleBridge();

    await tester.pumpWidget(const BleDebugApp());
    await tester.pump();

    // 标题
    expect(find.text('BLE 调试'), findsOneWidget);
    // 操作区按钮
    expect(find.text('扫描'), findsOneWidget);
    expect(find.text('断开'), findsOneWidget);
    expect(find.text('发命令'), findsOneWidget);
    // 状态卡片
    expect(find.textContaining('蓝牙:'), findsOneWidget);
    expect(find.textContaining('未连接设备'), findsOneWidget);
  });
}
