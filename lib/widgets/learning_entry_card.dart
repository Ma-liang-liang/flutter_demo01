import 'package:flutter/material.dart';

import '../models/learning_topic.dart';
import '../pages/learn/topic_list_page.dart';

/// 主页面顶部的「学习计划」入口卡片
///
/// 展示章节标题与主题数量，点击进入该分类的学习章节列表（二级页面）。
class LearningEntryCard extends StatelessWidget {
  const LearningEntryCard({super.key, required this.chapter});

  /// 当前主页面分类对应的学习章节
  final LearningChapter chapter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.primary,
      child: InkWell(
        onTap: () {
          // 进入学习计划章节列表（二级页面）
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (context) => TopicListPage(chapter: chapter),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.school, color: theme.colorScheme.onPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chapter.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${chapter.topics.length} 个主题 · 循序渐进学习路径',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimary.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward, color: theme.colorScheme.onPrimary),
            ],
          ),
        ),
      ),
    );
  }
}
