import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../widgets/demo_page_scaffold.dart';
import '../../../widgets/section_card.dart';
import '../providers/provider_examples.dart';

/// Riverpod 演示 01：Provider 基础用法
///
/// 展示 Provider 的只读特性、Provider 之间的依赖组合，
/// 以及 ref.watch 读取值的响应式更新。
class ProviderDemoPage extends ConsumerWidget {
  const ProviderDemoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const DemoPageScaffold(
      title: 'Provider 基础用法',
      goal: 'Provider 是 Riverpod 最基础的类型，用于提供只读值 / 计算结果 / 依赖注入对象。'
          '当依赖的 Provider 变化时自动重新计算，无需手动通知。',
      children: [
        _ReadOnlySection(),
        _CombinedSection(),
        _ObjectSection(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 只读 Provider
// ---------------------------------------------------------------------------
class _ReadOnlySection extends ConsumerWidget {
  const _ReadOnlySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ref.watch：监听 Provider 值，当值变化时自动重建 Widget
    final greeting = ref.watch(greetingProvider);

    return SectionCard(
      title: '只读 Provider',
      subtitle: 'Provider<T> → ref.watch → 读取值',
      icon: Icons.lock_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              greeting,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
            ),
          ),
          const SizedBox(height: 12),
          _CodeBlock(text: '''
// 定义
final greetingProvider = Provider<String>((ref) {
  return 'Hello, Riverpod!';
});

// 使用（在 ConsumerWidget 中）
final greeting = ref.watch(greetingProvider);'''),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 组合型 Provider：Provider 之间依赖
// ---------------------------------------------------------------------------
class _CombinedSection extends ConsumerWidget {
  const _CombinedSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final base = ref.watch(baseCountProvider);
    final doubled = ref.watch(doubledCountProvider);

    return SectionCard(
      title: 'Provider 组合',
      subtitle: '一个 Provider 依赖另一个 Provider 的值',
      icon: Icons.link,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ValueChip(label: 'baseCount', value: '$base'),
              const Text('× 2', style: TextStyle(fontSize: 20, color: Colors.grey)),
              const Text('=', style: TextStyle(fontSize: 20, color: Colors.grey)),
              _ValueChip(label: 'doubledCount', value: '$doubled', highlight: true),
            ],
          ),
          const SizedBox(height: 12),
          _CodeBlock(text: '''
final baseCountProvider = Provider<int>((ref) => 10);

// doubledCountProvider 依赖 baseCountProvider
final doubledCountProvider = Provider<int>((ref) {
  final base = ref.watch(baseCountProvider);
  return base * 2;
});'''),
          const SizedBox(height: 8),
          Text(
            '当 baseCountProvider 变化时，doubledCountProvider 自动重新计算。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 对象 Provider + 链式依赖
// ---------------------------------------------------------------------------
class _ObjectSection extends ConsumerWidget {
  const _ObjectSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userInfoProvider);
    final greeting = ref.watch(greetingWithUserInfoProvider);
    final theme = Theme.of(context);

    return SectionCard(
      title: '对象 Provider + 链式依赖',
      subtitle: 'Provider 返回自定义对象，另一个 Provider 依赖它',
      icon: Icons.account_circle_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: theme.colorScheme.secondaryContainer,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primary,
                child: Text(user.name.characters.first,
                    style: TextStyle(color: theme.colorScheme.onPrimary)),
              ),
              title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${user.age} 岁 · ${user.city}'),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              greeting,
              style: TextStyle(color: theme.colorScheme.onTertiaryContainer),
            ),
          ),
          const SizedBox(height: 12),
          _CodeBlock(text: '''
final userInfoProvider = Provider<UserInfo>((ref) {
  return UserInfo(name: '张三', age: 28, city: '北京');
});

// 链式依赖：greetingWithUserInfoProvider → userInfoProvider
final greetingWithUserInfoProvider = Provider<String>((ref) {
  final user = ref.watch(userInfoProvider);
  return '你好，\${user.name}！';
});'''),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 辅助组件
// ---------------------------------------------------------------------------
class _ValueChip extends StatelessWidget {
  const _ValueChip({required this.label, required this.value, this.highlight = false});

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: highlight ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: highlight ? theme.colorScheme.onPrimary : null,
            ),
          ),
        ),
      ],
    );
  }
}

/// 代码展示块（等宽字体 + 背景色）
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
