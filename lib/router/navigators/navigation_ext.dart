import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// 通用导航扩展
///
/// 提供 `nav` 前缀的通用导航方法，与 GoRouter 原生的 `context.push` /
/// `context.pop` 区分开。输入 `context.nav` 即可在 IDE 中筛选出全部自定义方法。
///
/// 模块专属的跳转方法放在 `navigators/` 下各自的文件中，
/// 通过 Extension on [BuildContext] 扩展，新增模块只需新建一个文件。
extension NavigationExt on BuildContext {
  /// 安全返回上一页
  ///
  /// 内部做了 [canPop] 检查，避免空栈时调用 [pop] 抛异常。
  /// 可选传入 [result] 供上一页接收返回值。
  void navBack<T>([T? result]) {
    if (canPop()) pop(result);
  }

  /// 切换底部导航 Tab
  ///
  /// [index] 对应 [tabConfigs] 中的索引（0-4）。
  /// 若点击的是当前 Tab，则重置到该 Tab 的初始页面。
  void navSwitchTab(int index) {
    final shell = StatefulNavigationShell.of(this);
    shell.goBranch(
      index,
      initialLocation: index == shell.currentIndex,
    );
  }
}
