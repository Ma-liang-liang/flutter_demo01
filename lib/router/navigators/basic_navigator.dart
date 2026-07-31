import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../app_router.dart';

/// 基础组件模块导航扩展
///
/// 封装基础组件相关的页面跳转，调用方通过 `context.navToXxx` 跳转，
/// 无需感知路由路径与命名细节。
extension BasicNavigator on BuildContext {
  /// 进入自定义导航条演示页面
  void navToNavBarDemo() => pushNamed(AppRouteName.navBarDemo);
}
