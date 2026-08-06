// ble_plugin 示例应用的集成测试（需在真机/模拟器上运行）。
//
// 验证调试页在真实平台（含原生桥接）下能正常加载。
// 蓝牙权限需由宿主 App 在启动时授予，测试只验证 UI 生命周期。

import 'package:ble_plugin_example/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('BLE 调试页加载', (WidgetTester tester) async {
    await tester.pumpWidget(const BleDebugApp());
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('BLE 调试'), findsOneWidget);
    expect(find.text('扫描'), findsOneWidget);
  });
}
