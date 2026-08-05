import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../utils/app_colors.dart';
import '../../../widgets/demo_page_scaffold.dart';
import '../../../widgets/section_card.dart';
import '../providers/notifier_provider_examples.dart';

/// Riverpod 演示 05：NotifierProvider 用法
///
/// 展示 Notifier 类封装复杂业务逻辑：Todo 列表增删改查 + 派生 Provider，
/// 以及购物车状态管理。
class NotifierProviderDemoPage extends ConsumerWidget {
  const NotifierProviderDemoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const DemoPageScaffold(
      title: 'NotifierProvider 用法',
      goal: 'NotifierProvider 配合 Notifier 类，封装复杂业务逻辑的状态管理。'
          '通过 build() 初始化、方法中 state = ... 更新，派生 Provider 自动联动。',
      children: [
        _TodoListSection(),
        _CartSection(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Todo 列表：增删改查 + 派生 Provider
// ---------------------------------------------------------------------------
class _TodoListSection extends ConsumerWidget {
  const _TodoListSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ref.watch 读取状态列表
    final todos = ref.watch(todoListProvider);
    // 派生 Provider：自动计算
    final incomplete = ref.watch(incompleteCountProvider);
    final complete = ref.watch(completeCountProvider);
    final theme = Theme.of(context);
    final appColors = theme.extension<AppColors>()!;
    final controller = TextEditingController();

    return SectionCard(
      title: 'Todo 列表（增删改查）',
      subtitle: 'Notifier<T> + 业务方法 + 派生 Provider',
      icon: Icons.checklist,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 统计栏
          Row(
            children: [
              _StatChip(label: '未完成', count: incomplete, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              _StatChip(label: '已完成', count: complete, color: appColors.success),
              const Spacer(),
              if (complete > 0)
                TextButton.icon(
                  onPressed: () => ref.read(todoListProvider.notifier).clearCompleted(),
                  icon: const Icon(Icons.cleaning_services_outlined, size: 18),
                  label: const Text('清除已完成'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // 输入框 + 添加按钮
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    hintText: '输入新任务...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  onSubmitted: (value) {
                    ref.read(todoListProvider.notifier).add(value);
                    controller.clear();
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () {
                  ref.read(todoListProvider.notifier).add(controller.text);
                  controller.clear();
                },
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Todo 列表
          if (todos.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: Text('暂无任务', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: todos.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final todo = todos[index];
                  return ListTile(
                    leading: Checkbox(
                      value: todo.completed,
                      onChanged: (_) => ref.read(todoListProvider.notifier).toggle(todo.id),
                    ),
                    title: Text(
                      todo.title,
                      style: TextStyle(
                        decoration: todo.completed ? TextDecoration.lineThrough : null,
                        color: todo.completed ? theme.colorScheme.outline : null,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () => ref.read(todoListProvider.notifier).remove(todo.id),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
          _CodeBlock(text: '''
class TodoListNotifier extends Notifier<List<Todo>> {
  @override
  List<Todo> build() => [/* 初始数据 */];

  void add(String title) {
    state = [...state, Todo(id: '...', title: title)];
  }

  void toggle(String id) {
    state = [
      for (final t in state)
        if (t.id == id) t.copyWith(completed: !t.completed) else t,
    ];
  }
}

final todoListProvider =
    NotifierProvider<TodoListNotifier, List<Todo>>(TodoListNotifier.new);

// 派生 Provider：自动联动
final incompleteCountProvider = Provider<int>((ref) {
  return ref.watch(todoListProvider).where((t) => !t.completed).length;
});'''),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 购物车：展示带计算逻辑的状态管理
// ---------------------------------------------------------------------------
class _CartSection extends ConsumerWidget {
  const _CartSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(cartProvider);
    final totalCount = ref.watch(cartItemCountProvider);
    final totalPrice = ref.watch(cartTotalPriceProvider);
    final theme = Theme.of(context);

    return SectionCard(
      title: '购物车（带计算逻辑）',
      subtitle: 'Notifier + 派生 Provider 自动计算总价',
      icon: Icons.shopping_cart_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (items.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: Text('购物车为空', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ListTile(
                    title: Text(item.name),
                    subtitle: Text('¥${item.price.toStringAsFixed(2)}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, size: 20),
                          onPressed: () => ref.read(cartProvider.notifier).decrement(item.id),
                        ),
                        Text('${item.quantity}', style: const TextStyle(fontSize: 16)),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, size: 20),
                          onPressed: () => ref.read(cartProvider.notifier).increment(item.id),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          const Divider(),
          // 汇总栏（派生 Provider 自动更新）
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('共 $totalCount 件商品', style: theme.textTheme.bodyMedium),
                Text(
                  '合计：¥${totalPrice.toStringAsFixed(2)}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: () => ref.read(cartProvider.notifier).addItem('蛋糕', 48),
                icon: const Icon(Icons.add),
                label: const Text('加一份蛋糕'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => ref.read(cartProvider.notifier).clear(),
                child: const Text('清空'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'cartItemCountProvider 和 cartTotalPriceProvider 依赖 cartProvider，'
            '购物车变化时自动重新计算。',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 辅助组件
// ---------------------------------------------------------------------------
class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.count, required this.color});

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: color)),
          const SizedBox(width: 4),
          Text('$count', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
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
