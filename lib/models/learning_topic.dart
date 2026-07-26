import 'package:flutter/material.dart';

/// 学习主题
///
/// 对应学习计划中的一个知识点（三级演示页面的元信息）。
class LearningTopic {
  const LearningTopic({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.demoPage,
  });

  /// 主题标题，如「文本深入」
  final String title;

  /// 主题简介，展示该主题覆盖的知识点
  final String subtitle;

  /// 列表项前缀图标
  final IconData icon;

  /// 点击后进入的三级演示页面
  final Widget demoPage;
}

/// 学习章节
///
/// 对应一个主 Tab 分类（基础/表单/布局/动画）的完整学习计划，
/// 由若干 [LearningTopic] 组成。
class LearningChapter {
  const LearningChapter({
    required this.id,
    required this.title,
    required this.goal,
    required this.topics,
  });

  /// 章节唯一标识，如 'basic'
  final String id;

  /// 章节标题，如「基础组件学习计划」
  final String title;

  /// 学习目标描述，展示在章节列表页顶部
  final String goal;

  /// 本章节包含的学习主题
  final List<LearningTopic> topics;
}
