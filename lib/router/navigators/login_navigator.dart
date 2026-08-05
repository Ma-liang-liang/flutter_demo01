import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../app_router.dart';

/// 登录对比模块导航扩展
///
/// 封装 Bloc / Riverpod 两套登录实现的页面跳转，
/// 调用方通过 `context.navToXxx` 跳转，无需感知路由路径与命名细节。
extension LoginNavigator on BuildContext {
  /// 进入 Bloc 版登录页面
  void navToBlocLogin() => pushNamed(AppRouteName.loginBloc);

  /// 进入 Riverpod 版登录页面
  void navToRiverpodLogin() => pushNamed(AppRouteName.loginRiverpod);
}
