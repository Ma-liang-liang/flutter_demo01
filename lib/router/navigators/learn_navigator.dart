import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../app_router.dart';

/// 学习计划模块导航扩展
///
/// 封装学习计划相关的页面跳转，调用方通过 `context.navToXxx` 跳转，
/// 无需感知路由路径与命名细节。
extension LearnNavigator on BuildContext {
  /// 进入学习计划 · 二级页面（主题列表）
  ///
  /// 全屏覆盖底部导航 Shell，返回后回到之前的 Tab。
  void navToTopicList(String chapterId) => pushNamed(
        AppRouteName.topicList,
        pathParameters: {'chapterId': chapterId},
      );

  /// 进入学习计划 · 三级演示页面
  ///
  /// [topicIndex] 为 0-based 的主题索引。
  void navToTopicDemo(String chapterId, int topicIndex) => pushNamed(
        AppRouteName.topicDemo,
        pathParameters: {
          'chapterId': chapterId,
          'topicIndex': '$topicIndex',
        },
      );
}
