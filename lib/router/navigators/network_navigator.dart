import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../app_router.dart';

/// 网络模块导航扩展
///
/// 封装网络组件演示相关的页面跳转，调用方通过 `context.navToXxx` 跳转，
/// 无需感知路由路径与命名细节。
extension NetworkNavigator on BuildContext {
  /// 进入网络组件演示页面（二级页面）
  ///
  /// 全屏覆盖底部导航 Shell，返回后回到之前的 Tab。
  void navToNetworkDemo() => pushNamed(AppRouteName.networkDemo);
}
