import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../app_router.dart';

/// Riverpod 模块导航扩展
///
/// 封装 Riverpod 模块相关的页面跳转，调用方通过 `context.navToXxx` 跳转，
/// 无需感知路由路径与命名细节。
extension RiverpodNavigator on BuildContext {
  /// 进入 Riverpod 模块列表页（二级页面）
  ///
  /// 全屏覆盖底部导航 Shell，返回后回到之前的 Tab。
  void navToRiverpodHome() => pushNamed(AppRouteName.riverpodHome);

  /// 进入 Riverpod 模块具体演示页面（三级页面）
  ///
  /// [demoId] 对应 [RiverpodDemoData] 中的 id，如 'provider'、'future_provider'。
  void navToRiverpodDemo(String demoId) => pushNamed(
        AppRouteName.riverpodDemo,
        pathParameters: {'demoId': demoId},
      );
}
