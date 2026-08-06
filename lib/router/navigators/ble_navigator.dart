import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../app_router.dart';

/// BLE 蓝牙插件模块导航扩展
///
/// 封装 BLE 演示相关的页面跳转，调用方通过 `context.navToXxx` 跳转，
/// 无需感知路由路径与命名细节。
extension BleNavigator on BuildContext {
  /// 进入 BLE 蓝牙插件演示页面（二级页面）
  ///
  /// 全屏覆盖底部导航 Shell，返回后回到之前的 Tab。
  void navToBleDemo() => pushNamed(AppRouteName.bleDemo);
}
