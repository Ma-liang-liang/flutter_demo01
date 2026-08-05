import 'package:flutter/material.dart';

import '../../../../utils/theme_ext.dart';
import '../../../../widgets/demo_page_scaffold.dart';
import '../../../../widgets/section_card.dart';

/// 学习计划 · 布局组件 · 行列布局深入
///
/// 演示 MainAxisAlignment / CrossAxisAlignment 对齐方式与 Expanded 比例分配。
class RowColumnDemo extends StatelessWidget {
  const RowColumnDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return const DemoPageScaffold(
      title: '行列布局深入',
      goal: '理解主轴与交叉轴的概念，掌握 MainAxisAlignment 六种对齐方式，学会用 Expanded 按比例分配剩余空间。',
      children: [
        _MainAxisSection(),
        _CrossAxisSection(),
        _ExpandedSection(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 主轴对齐
// ---------------------------------------------------------------------------
class _MainAxisSection extends StatelessWidget {
  const _MainAxisSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Row 的主轴是水平方向
    const alignments = [
      (MainAxisAlignment.start, 'start'),
      (MainAxisAlignment.center, 'center'),
      (MainAxisAlignment.end, 'end'),
      (MainAxisAlignment.spaceBetween, 'spaceBetween'),
      (MainAxisAlignment.spaceAround, 'spaceAround'),
      (MainAxisAlignment.spaceEvenly, 'spaceEvenly'),
    ];
    return SectionCard(
      title: '主轴对齐 MainAxisAlignment',
      subtitle: '控制子组件在主轴方向的分布',
      icon: Icons.align_horizontal_left_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (alignment, name) in alignments) ...[
            Text(name, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: alignment,
                children: [
                  _ColorBox(color: context.colors.error),
                  _ColorBox(color: context.appColors.success),
                  _ColorBox(color: context.colors.primary),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 交叉轴对齐
// ---------------------------------------------------------------------------
class _CrossAxisSection extends StatelessWidget {
  const _CrossAxisSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Row 的交叉轴是垂直方向
    const alignments = [
      (CrossAxisAlignment.start, 'start'),
      (CrossAxisAlignment.center, 'center'),
      (CrossAxisAlignment.end, 'end'),
      (CrossAxisAlignment.stretch, 'stretch（拉伸填满）'),
    ];
    return SectionCard(
      title: '交叉轴对齐 CrossAxisAlignment',
      subtitle: '控制子组件在交叉轴方向的分布',
      icon: Icons.align_vertical_top_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (alignment, name) in alignments) ...[
            Text(name, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Container(
              height: 60,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: alignment,
                children: [
                  _ColorBox(color: context.colors.error, height: 24),
                  _ColorBox(color: context.appColors.success, height: 40),
                  _ColorBox(color: context.colors.primary, height: 32),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Expanded 比例分配
// ---------------------------------------------------------------------------
class _ExpandedSection extends StatelessWidget {
  const _ExpandedSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: 'Expanded 比例分配',
      subtitle: 'flex 系数决定剩余空间的分配比例',
      icon: Icons.view_week_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('1 : 2 : 1 分配', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          SizedBox(
            height: 40,
            child: Row(
              children: [
                Expanded(child: Container(color: context.colors.errorContainer)),
                Expanded(flex: 2, child: Container(color: context.colors.secondaryContainer)),
                Expanded(child: Container(color: context.colors.primaryContainer)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text('实战：聊天消息输入栏（输入框占满剩余空间）',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Row(
            children: [
              IconButton.outlined(onPressed: () {}, icon: const Icon(Icons.add)),
              const SizedBox(width: 8),
              // Expanded 让输入框填满按钮之外的剩余宽度
              const Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: '发送消息...',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(onPressed: () {}, icon: const Icon(Icons.send)),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 彩色演示方块
// ---------------------------------------------------------------------------
class _ColorBox extends StatelessWidget {
  const _ColorBox({required this.color, this.height = 32});

  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: height,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}
