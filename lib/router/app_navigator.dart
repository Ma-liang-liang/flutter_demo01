import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'app_router.dart';

/// 应用导航管理类
///
/// 所有页面跳转的统一入口。页面/组件不应直接调用 `context.push` /
/// `context.pushNamed`，而应通过本类的语义化方法跳转。
///
/// ## 设计目标
///
/// - **路径收口**：路由路径与命名路由仅在 [AppRoutePath] / [AppRouteName]
///   和 [createAppRouter] 中定义，调用方无需感知。
/// - **类型安全**：方法签名约束参数类型，避免字符串拼接出错。
/// - **可扩展**：后续可在方法内统一加入埋点、日志、权限拦截等逻辑。
///
/// ## 使用示例
///
/// ```dart
/// // 进入学习计划主题列表
/// AppNavigator.toTopicList(context, chapter.id);
///
/// // 进入三级演示页面
/// AppNavigator.toTopicDemo(context, chapterId, topicIndex);
///
/// // 返回上一页
/// AppNavigator.back(context);
/// ```
class AppNavigator {
  AppNavigator._();

  // ──────────────────────────────────────────────────────────────
  // 学习计划相关
  // ──────────────────────────────────────────────────────────────

  /// 进入学习计划 · 二级页面（主题列表）
  ///
  /// 全屏覆盖底部导航 Shell，返回后回到之前的 Tab。
  static void toTopicList(BuildContext context, String chapterId) {
    context.pushNamed(
      AppRouteName.topicList,
      pathParameters: {'chapterId': chapterId},
    );
  }

  /// 进入学习计划 · 三级演示页面
  ///
  /// [topicIndex] 为 0-based 的主题索引。
  static void toTopicDemo(
    BuildContext context,
    String chapterId,
    int topicIndex,
  ) {
    context.pushNamed(
      AppRouteName.topicDemo,
      pathParameters: {
        'chapterId': chapterId,
        'topicIndex': '$topicIndex',
      },
    );
  }

  // ──────────────────────────────────────────────────────────────
  // 演示页面
  // ──────────────────────────────────────────────────────────────

  /// 进入自定义导航条演示页面
  static void toNavBarDemo(BuildContext context) {
    context.pushNamed(AppRouteName.navBarDemo);
  }

  // ──────────────────────────────────────────────────────────────
  // 通用导航
  // ──────────────────────────────────────────────────────────────

  /// 返回上一页
  ///
  /// 可选传入 [result] 供调用方接收返回值。
  static void back<T>(BuildContext context, [T? result]) {
    if (context.canPop()) {
      context.pop(result);
    }
  }

  /// 切换底部导航 Tab
  ///
  /// [index] 对应 [tabConfigs] 中的索引（0-4）。
  /// 若点击的是当前 Tab，则重置到该 Tab 的初始页面。
  static void switchTab(BuildContext context, int index) {
    final shell = StatefulNavigationShell.of(context);
    shell.goBranch(
      index,
      initialLocation: index == shell.currentIndex,
    );
  }
}
