import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../widgets/demo_page_scaffold.dart';
import '../../../widgets/section_card.dart';
import '../providers/state_provider_examples.dart';

/// Riverpod 演示 02：StateProvider 用法
///
/// 展示 StateProvider 管理简单可变状态：计数器、主题切换、字号缩放。
/// 通过 ref.read(provider.notifier).state 修改值。
class StateProviderDemoPage extends ConsumerWidget {
  const StateProviderDemoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const DemoPageScaffold(
      title: 'StateProvider 用法',
      goal: 'StateProvider 适合管理简单的可变状态（计数器、开关、选中项）。'
          '通过 ref.watch 读取、ref.read(xxx.notifier).state 修改，无需自定义 Notifier。',
      children: [
        _CounterSection(),
        _ThemeModeSection(),
        _FontScaleSection(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 计数器：最经典的 StateProvider 用法
// ---------------------------------------------------------------------------
class _CounterSection extends ConsumerWidget {
  const _CounterSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ref.watch：读取当前值，值变化时自动重建
    final count = ref.watch(counterProvider);
    final theme = Theme.of(context);

    return SectionCard(
      title: '计数器',
      subtitle: 'ref.watch 读取 / ref.read(xxx.notifier).state 修改',
      icon: Icons.exposure,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  '$count',
                  style: theme.textTheme.displayLarge?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '当前计数',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // ref.read：在回调中一次性读取并修改（不建立监听）
              IconButton.filled(
                onPressed: () => ref.read(counterProvider.notifier).state--,
                icon: const Icon(Icons.remove),
              ),
              FilledButton.tonal(
                onPressed: () => ref.read(counterProvider.notifier).state = 0,
                child: const Text('重置'),
              ),
              IconButton.filled(
                onPressed: () => ref.read(counterProvider.notifier).state++,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _CodeBlock(text: '''
// 定义
final counterProvider = StateProvider<int>((ref) => 0);

// 读取（build 中）
final count = ref.watch(counterProvider);

// 修改（回调中）
ref.read(counterProvider.notifier).state++;
ref.read(counterProvider.notifier).state = 0;'''),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 主题模式切换
// ---------------------------------------------------------------------------
class _ThemeModeSection extends ConsumerWidget {
  const _ThemeModeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final theme = Theme.of(context);

    return SectionCard(
      title: '主题模式切换',
      subtitle: 'String 类型 StateProvider + SegmentedButton',
      icon: Icons.dark_mode_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'light', label: Text('浅色'), icon: Icon(Icons.light_mode)),
              ButtonSegment(value: 'dark', label: Text('深色'), icon: Icon(Icons.dark_mode)),
              ButtonSegment(value: 'system', label: Text('跟随系统'), icon: Icon(Icons.settings_brightness)),
            ],
            selected: {mode},
            onSelectionChanged: (selection) {
              // 修改 StateProvider 的值
              ref.read(themeModeProvider.notifier).state = selection.first;
            },
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('当前模式：$mode'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 字号缩放滑块
// ---------------------------------------------------------------------------
class _FontScaleSection extends ConsumerWidget {
  const _FontScaleSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = ref.watch(fontScaleProvider);
    final theme = Theme.of(context);

    return SectionCard(
      title: '字号缩放',
      subtitle: 'double 类型 StateProvider + Slider',
      icon: Icons.format_size,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 用 scale 实时影响文字大小，展示响应式效果
          Text(
            'Riverpod 让状态管理更简单',
            style: TextStyle(
              fontSize: 16 * scale,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('A', style: TextStyle(fontSize: 12)),
              Expanded(
                child: Slider(
                  value: scale,
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  label: '${scale.toStringAsFixed(1)}x',
                  onChanged: (value) {
                    // 拖动时实时更新 StateProvider
                    ref.read(fontScaleProvider.notifier).state = value;
                  },
                ),
              ),
              const Text('A', style: TextStyle(fontSize: 24)),
            ],
          ),
          Text('缩放比例：${scale.toStringAsFixed(1)}x',
              style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 代码展示块
// ---------------------------------------------------------------------------
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
