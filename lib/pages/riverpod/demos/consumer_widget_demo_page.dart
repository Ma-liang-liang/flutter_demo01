import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../widgets/demo_page_scaffold.dart';
import '../../../widgets/section_card.dart';
import '../providers/state_provider_examples.dart';

/// Riverpod 演示 06：Consumer 与 ref 用法
///
/// 展示 Riverpod 的核心消费 API：
///   - ConsumerWidget（替代 StatelessWidget）
///   - Consumer（局部监听，避免整个页面重建）
///   - ref.watch vs ref.read
///   - ref.listen（副作用：SnackBar / 导航）
///   - ProviderScope override（覆盖 Provider 值）
class ConsumerWidgetDemoPage extends ConsumerWidget {
  const ConsumerWidgetDemoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const DemoPageScaffold(
      title: 'Consumer 与 ref 用法',
      goal: '掌握 Riverpod 核心 API：ConsumerWidget / Consumer 局部监听 / '
          'ref.watch 响应式读取 / ref.read 一次性读取 / ref.listen 副作用。',
      children: [
        _ConsumerWidgetSection(),
        _ConsumerSection(),
        _WatchVsReadSection(),
        _RefListenSection(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// ConsumerWidget：替代 StatelessWidget
// ---------------------------------------------------------------------------
class _ConsumerWidgetSection extends ConsumerWidget {
  const _ConsumerWidgetSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return SectionCard(
      title: 'ConsumerWidget',
      subtitle: '替代 StatelessWidget，build 方法多一个 WidgetRef 参数',
      icon: Icons.widgets_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ConsumerWidget 是 Riverpod 提供的基类，'
            '继承自 StatelessWidget，build 方法额外接收 WidgetRef 参数。\n'
            '通过 ref 即可访问所有 Provider，无需 context。',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          _CodeBlock(text: '''
// StatelessWidget → 无法访问 ref
class MyPage extends StatelessWidget {
  Widget build(BuildContext context) { ... }
}

// ConsumerWidget → 可通过 ref 访问 Provider
class MyPage extends ConsumerWidget {
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(counterProvider);
    return Text('\$count');
  }
}'''),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Consumer：局部监听，避免整个页面重建
// ---------------------------------------------------------------------------
class _ConsumerSection extends ConsumerWidget {
  const _ConsumerSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return SectionCard(
      title: 'Consumer（局部重建）',
      subtitle: '仅监听范围内的 Widget 重建，其余部分不受影响',
      icon: Icons.center_focus_strong_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '当页面中只有一小块区域需要响应 Provider 变化时，'
            '用 Consumer 包裹该区域，避免整个页面重建。\n'
            '下方「计数器区域」用 Consumer 包裹，外层文字不会重建。',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                // 外层文字：不监听任何 Provider，不会重建
                Text(
                  '这段文字不会因计数器变化而重建',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                // Consumer 包裹的区域：仅此处重建
                Consumer(
                  builder: (context, ref, _) {
                    final count = ref.watch(counterProvider);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '计数: $count',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.filled(
                      onPressed: () => ref.read(counterProvider.notifier).state--,
                      icon: const Icon(Icons.remove),
                    ),
                    const SizedBox(width: 16),
                    IconButton.filled(
                      onPressed: () => ref.read(counterProvider.notifier).state++,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _CodeBlock(text: '''
Consumer(
  builder: (context, ref, _) {
    final count = ref.watch(counterProvider);
    return Text('\$count');
  },
)'''),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ref.watch vs ref.read
// ---------------------------------------------------------------------------
class _WatchVsReadSection extends ConsumerWidget {
  const _WatchVsReadSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return SectionCard(
      title: 'ref.watch vs ref.read',
      subtitle: 'watch 建立监听（build 中）/ read 一次性读取（回调中）',
      icon: Icons.compare_arrows,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CompareRow(
            name: 'ref.watch',
            usage: '在 build 方法中调用',
            desc: '监听 Provider 值，值变化时自动重建当前 Widget',
            color: theme.colorScheme.primary,
          ),
          const Divider(),
          _CompareRow(
            name: 'ref.read',
            usage: '在回调 / 事件处理中调用',
            desc: '一次性读取当前值，不建立监听，不会触发重建',
            color: theme.colorScheme.tertiary,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: theme.colorScheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '注意：不要在回调（onPressed / onTap）中使用 ref.watch，'
                    '应使用 ref.read。watch 只能在 build 方法内调用。',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ref.listen：监听变化执行副作用
// ---------------------------------------------------------------------------
class _RefListenSection extends ConsumerWidget {
  const _RefListenSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(counterProvider);
    final theme = Theme.of(context);

    // ref.listen：监听 Provider 变化，执行副作用（不触发重建）
    // 与 ref.watch 区别：listen 用于「执行动作」，watch 用于「更新 UI」
    ref.listen<int>(counterProvider, (previous, next) {
      // 当计数器变化时弹出 SnackBar
      if (previous != null && next > previous) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('计数增加了！现在: $next'),
            duration: const Duration(milliseconds: 800),
          ),
        );
      }
    });

    return SectionCard(
      title: 'ref.listen（副作用）',
      subtitle: '监听变化执行动作：SnackBar / 导航 / 日志',
      icon: Icons.notifications_active_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ref.listen 在 build 中注册监听，当值变化时回调。'
            '适合执行不需要重建 UI 的副作用（如弹提示、跳页面）。',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  '$count',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '点击 + 增加，观察 SnackBar',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filled(
                onPressed: () => ref.read(counterProvider.notifier).state--,
                icon: const Icon(Icons.remove),
              ),
              const SizedBox(width: 16),
              IconButton.filled(
                onPressed: () => ref.read(counterProvider.notifier).state++,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _CodeBlock(text: '''
@override
Widget build(BuildContext context, WidgetRef ref) {
  // 注册监听：值变化时执行副作用
  ref.listen<int>(counterProvider, (previous, next) {
    if (next > previous) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('增加了！现在: \$next')),
      );
    }
  });

  // ref.watch 用于渲染 UI
  final count = ref.watch(counterProvider);
  return Text('\$count');
}'''),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 辅助组件
// ---------------------------------------------------------------------------
class _CompareRow extends StatelessWidget {
  const _CompareRow({
    required this.name,
    required this.usage,
    required this.desc,
    required this.color,
  });

  final String name;
  final String usage;
  final String desc;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              name,
              style: TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(usage, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(desc, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: SelectableText(
        text.trim(),
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          height: 1.5,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}
