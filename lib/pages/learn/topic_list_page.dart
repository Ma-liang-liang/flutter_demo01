import 'package:flutter/material.dart';

import '../../models/learning_topic.dart';
import '../../router/app_navigator.dart';

/// 学习计划 · 二级页面：章节主题列表
///
/// 接收一个 [LearningChapter]，展示章节学习目标与包含的主题列表，
/// 点击主题进入对应的三级演示页面。
class TopicListPage extends StatelessWidget {
  const TopicListPage({super.key, required this.chapter});

  final LearningChapter chapter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(chapter.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 章节学习目标说明卡
          Card(
            color: theme.colorScheme.secondaryContainer,
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.school_outlined,
                    size: 20,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      chapter.goal,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 主题列表
          for (var i = 0; i < chapter.topics.length; i++)
            _TopicCard(
              index: i + 1,
              topic: chapter.topics[i],
              chapterId: chapter.id,
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 主题卡片：序号 + 图标 + 标题简介 + 跳转箭头
// ---------------------------------------------------------------------------
class _TopicCard extends StatelessWidget {
  const _TopicCard({
    required this.index,
    required this.topic,
    required this.chapterId,
  });

  /// 显示序号（1-based）
  final int index;

  final LearningTopic topic;

  /// 所属章节 ID，用于拼路由路径
  final String chapterId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(topic.icon, color: theme.colorScheme.onPrimaryContainer),
        ),
        title: Text(
          '${index.toString().padLeft(2, '0')} · ${topic.title}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(topic.subtitle),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // 进入三级演示页面
          // 全屏覆盖 Shell，返回后回到主题列表
          AppNavigator.toTopicDemo(context, chapterId, index - 1);
        },
      ),
    );
  }
}
