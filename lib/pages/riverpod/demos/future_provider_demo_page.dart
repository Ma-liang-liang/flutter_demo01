import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../widgets/demo_page_scaffold.dart';
import '../../../widgets/section_card.dart';
import '../providers/future_provider_examples.dart';

/// Riverpod 演示 03：FutureProvider 用法
///
/// 展示 FutureProvider 处理异步操作的三态（loading / data / error），
/// 以及 ref.refresh 手动刷新、autoDispose 自动释放。
class FutureProviderDemoPage extends ConsumerWidget {
  const FutureProviderDemoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const DemoPageScaffold(
      title: 'FutureProvider 用法',
      goal: 'FutureProvider 包装异步操作，自动管理 loading / data / error 三态。'
          '通过 AsyncValue.when 分支渲染，ref.refresh 手动重新加载。',
      children: [
        _AsyncGreetingSection(),
        _UserListSection(),
        _RandomNumberSection(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 异步问候语：展示 .when 三态处理
// ---------------------------------------------------------------------------
class _AsyncGreetingSection extends ConsumerWidget {
  const _AsyncGreetingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ref.watch 返回 AsyncValue<String>
    final asyncValue = ref.watch(asyncGreetingProvider);
    final theme = Theme.of(context);

    return SectionCard(
      title: '异步请求 + 三态处理',
      subtitle: 'AsyncValue.when → loading / data / error',
      icon: Icons.cloud_download_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // .when 是最常用的三态处理方式
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: asyncValue.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, stack) => Row(
                children: [
                  Icon(Icons.error_outline, color: theme.colorScheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('$err', style: TextStyle(color: theme.colorScheme.error)),
                  ),
                ],
              ),
              data: (message) => Row(
                children: [
                  Icon(Icons.check_circle, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(message, style: theme.textTheme.titleMedium),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.icon(
                onPressed: () {
                  // ref.invalidate：标记 Provider 为脏，下次 watch 时重新执行
                  ref.invalidate(asyncGreetingProvider);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('刷新'),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: () {
                  // ref.refresh：手动重新触发并返回新 AsyncValue
                  // 此处仅触发刷新，不使用返回值
                  // ignore: unused_result
                  ref.refresh(asyncGreetingProvider);
                },
                icon: const Icon(Icons.restart_alt),
                label: const Text('refresh'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _CodeBlock(text: '''
final asyncGreetingProvider = FutureProvider<String>((ref) async {
  return await fetchGreeting(); // 可能抛异常
});

// 使用
final asyncValue = ref.watch(asyncGreetingProvider);

asyncValue.when(
  loading: () => CircularProgressIndicator(),
  error: (err, stack) => Text('错误：\$err'),
  data: (value) => Text(value),
);

// 标记为脏，下次 watch 重新执行
ref.invalidate(asyncGreetingProvider);

// 或手动刷新（返回新 AsyncValue）
ref.refresh(asyncGreetingProvider);'''),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 用户列表：autoDispose + .value 简化写法
// ---------------------------------------------------------------------------
class _UserListSection extends ConsumerWidget {
  const _UserListSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncUsers = ref.watch(autoDisposeUsersProvider);
    final theme = Theme.of(context);

    return SectionCard(
      title: '用户列表（autoDispose）',
      subtitle: '.value 简化写法 / 离开页面自动释放',
      icon: Icons.people_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // .value：当有数据时返回 Widget，否则返回 null（配合 ?? 使用）
          // 比 .when 更简洁，适合「加载中显示占位，有数据时渲染列表」的场景
          SizedBox(
            height: 280,
            child: asyncUsers.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                    const SizedBox(height: 8),
                    Text('$err', style: TextStyle(color: theme.colorScheme.error)),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => ref.invalidate(autoDisposeUsersProvider),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
              data: (users) => ListView.separated(
                itemCount: users.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final user = users[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text('${user.id}', style: TextStyle(color: theme.colorScheme.primary)),
                    ),
                    title: Text(user.name),
                    subtitle: Text(user.email),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'autoDispose：离开页面后状态自动销毁，再次进入重新加载。',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 随机数：展示 refresh 返回新值
// ---------------------------------------------------------------------------
class _RandomNumberSection extends ConsumerWidget {
  const _RandomNumberSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncNumber = ref.watch(randomNumberProvider);
    final theme = Theme.of(context);

    return SectionCard(
      title: '随机数（refresh 演示）',
      subtitle: 'ref.refresh → 返回新 AsyncValue / 重新执行',
      icon: Icons.casino_outlined,
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: asyncNumber.when(
                loading: () => const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (_, _) => const Icon(Icons.error),
                data: (n) => Text(
                  '$n',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('点击按钮生成新的随机数', style: theme.textTheme.bodyMedium),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => ref.refresh(randomNumberProvider),
                  icon: const Icon(Icons.shuffle),
                  label: const Text('生成'),
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
