import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../viewmodels/cart_cubit.dart';
import '../widgets/explanation_card.dart';

/// 演示 5 · Provider 依赖注入与实例共享
///
/// 展示 BlocProvider / MultiBlocProvider / RepositoryProvider /
/// BlocProvider.value 四种注入方式，以及「一个实例多处共享」。
class ProviderDiDemoPage extends StatelessWidget {
  const ProviderDiDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 顶层创建一个 CartCubit，下方所有子组件共享同一个实例：
    // 商品区加购 → 购物车区数量同步更新，无需手动传值。
    //
    // 如果页面需要多个 Bloc/Cubit，用 MultiBlocProvider 平铺：
    // MultiBlocProvider(providers: [
    //   BlocProvider(create: (_) => CartCubit()),
    //   BlocProvider(create: (_) => OtherCubit()),
    // ], child: ...)
    return BlocProvider(
      create: (_) => CartCubit(),
      child: Scaffold(
        appBar: AppBar(title: const Text('依赖注入与实例共享')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            ExplanationCard(
              title: '四种注入方式',
              points: [
                '`BlocProvider(create: ...)`：创建并持有实例，'
                    'Provider 销毁时自动 close。子树通过 `context.read / watch` 获取。',
                '`MultiBlocProvider`：需要注入多个 Bloc 时平铺书写，避免层层嵌套。',
                '`RepositoryProvider`：注入 Model 层的 Repository / Service，'
                    '用法与 BlocProvider 一致，语义上区分「状态」与「依赖」。',
                '`BlocProvider.value(value: existing)`：只共享、不创建，'
                    '常用于把已有实例传给 Dialog / 新路由，生命周期仍由原处管理。',
              ],
            ),
            _GoodsSection(),
            _CartSection(),
            ExplanationCard(
              title: '实例共享的效果',
              points: [
                '上方「商品区」和下方「购物车区」是两个独立的子组件，'
                    '它们各自 BlocBuilder 监听同一个 CartCubit。',
                '点击加购后无需任何手动传值，购物车区自动刷新——'
                    '这就是「单一数据源 + 依赖注入」带来的解耦效果。',
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 商品区：两个商品卡片，点击加购
class _GoodsSection extends StatelessWidget {
  const _GoodsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _GoodsCard(name: 'Flutter 实战指南', emoji: '📘'),
        _GoodsCard(name: '状态管理徽章', emoji: '🏅'),
      ],
    );
  }
}

class _GoodsCard extends StatelessWidget {
  const _GoodsCard({required this.name, required this.emoji});

  final String name;
  final String emoji;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Text(emoji, style: const TextStyle(fontSize: 28)),
        title: Text(name),
        subtitle: const Text('¥ 19.9'),
        trailing: FilledButton.tonal(
          onPressed: () => context.read<CartCubit>().add(name),
          child: const Text('加入购物车'),
        ),
      ),
    );
  }
}

/// 购物车区：数量、总价、清空、查看详情（Dialog 演示 BlocProvider.value）
class _CartSection extends StatelessWidget {
  const _CartSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: BlocBuilder<CartCubit, CartState>(
          builder: (context, state) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shopping_cart_outlined),
                    const SizedBox(width: 8),
                    Text(
                      '购物车（共享同一实例）',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Badge.count(
                      count: state.itemCount,
                      backgroundColor: theme.colorScheme.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  state.lastAction.isEmpty ? '还没有操作' : state.lastAction,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '合计：¥ ${state.totalPrice.toStringAsFixed(1)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed:
                          state.itemCount == 0
                              ? null
                              : () => context.read<CartCubit>().remove(),
                      child: const Text('移除一件'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed:
                          state.itemCount == 0
                              ? null
                              : () => context.read<CartCubit>().clear(),
                      child: const Text('清空'),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: state.itemCount == 0
                          ? null
                          : () => _showCartDialog(context),
                      child: const Text('查看详情'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Dialog 运行在 Overlay 层，拿不到页面内的 Provider，
  /// 需要用 `BlocProvider.value` 把已有实例共享进去（不创建、不销毁）
  void _showCartDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<CartCubit>(),
        child: AlertDialog(
          title: const Text('购物车详情'),
          content: BlocBuilder<CartCubit, CartState>(
            builder: (context, state) => Text(
              '共 ${state.itemCount} 件商品，'
              '合计 ¥ ${state.totalPrice.toStringAsFixed(1)}。\n\n'
              '本 Dialog 通过 BlocProvider.value 共享页面上的同一个 CartCubit，'
              '这里看到的数据与页面完全同步。',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('关闭'),
            ),
          ],
        ),
      ),
    );
  }
}
