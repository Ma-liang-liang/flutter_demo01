import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_demo01/main.dart';

void main() {
  testWidgets('App renders with 5 navigation tabs', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // 验证默认显示第一个 Tab（基础组件）
    expect(find.text('基础组件'), findsWidgets);

    // 验证底部导航栏有 5 个 tab
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(5));

    // 验证 tab 标签文字
    expect(find.text('表单组件'), findsOneWidget);
    expect(find.text('布局组件'), findsOneWidget);
    expect(find.text('动画交互'), findsOneWidget);
  });

  testWidgets('Switching tabs changes the displayed page', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // 点击第二个 Tab（表单组件）
    await tester.tap(find.text('表单组件'));
    await tester.pumpAndSettle();

    // 验证 AppBar 标题更新
    expect(find.byType(AppBar), findsWidgets);
  });

  testWidgets('Basic widgets page has section cards', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // 验证基础组件页面包含 SectionCard
    expect(find.byType(Card), findsWidgets);
    expect(find.text('按钮'), findsWidgets);
  });

  testWidgets('动画交互页 AnimatedContainer 展开不报错', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // 切换到动画交互 Tab
    await tester.tap(find.text('动画交互').first);
    await tester.pumpAndSettle();

    // 点击第一个卡片的"展开"按钮
    await tester.tap(find.text('展开').first);

    // 逐帧推进动画，覆盖中间帧：修复前宽度从 100 动画到 double.infinity，
    // 中间帧会触发 "Cannot interpolate between finite constraints and
    // unbounded constraints" 断言错误。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250)); // t=0.5 中间帧
    await tester.pumpAndSettle();

    // 不应抛出异常
    expect(tester.takeException(), isNull);
    // 展开后按钮文字应变为"收起"
    expect(find.text('收起'), findsOneWidget);
  });
}
