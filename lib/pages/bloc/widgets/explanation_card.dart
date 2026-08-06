import 'package:flutter/material.dart';

/// Bloc 演示页面的讲解卡片
///
/// 统一演示页面中「原理讲解」区块的样式：
/// 标题 + 正文段落，正文中支持 `代码` 高亮标记。
class ExplanationCard extends StatelessWidget {
  const ExplanationCard({
    super.key,
    required this.title,
    required this.points,
  });

  /// 讲解标题，如「核心概念」
  final String title;

  /// 讲解要点列表，每条一个段落
  final List<String> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final point in points) ...[
              _PointText(point: point),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }
}

/// 单个要点文本：支持用反引号包裹的代码片段高亮
class _PointText extends StatelessWidget {
  const _PointText({required this.point});

  final String point;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bodyStyle = theme.textTheme.bodySmall?.copyWith(height: 1.6);
    final codeStyle = bodyStyle?.copyWith(
      fontFamily: 'monospace',
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      color: theme.colorScheme.primary,
    );

    // 按反引号切分：偶数段为普通文本，奇数段为代码
    final segments = point.split('`');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                for (var i = 0; i < segments.length; i++)
                  TextSpan(
                    text: segments[i],
                    style: i.isOdd ? codeStyle : bodyStyle,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
