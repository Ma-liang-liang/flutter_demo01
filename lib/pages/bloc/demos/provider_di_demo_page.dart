import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/product.dart';
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
                '点击加购后无需任何手动传值，购物车区的行明细与总价自动刷新——'
                    '这就是「单一数据源 + 依赖注入」带来的解耦效果。',
                '总价不是单独存的字段，而是从行项目派生的 getter，'
                    '保证数据永远一致。',
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 商品区：三个商品价格各不相同，点击加购
class _GoodsSection extends StatelessWidget {
  const _GoodsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final product in sampleProducts) _GoodsCard(product: product),
      ],
    );
  }
}

class _GoodsCard extends StatelessWidget {
  const _GoodsCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Text(product.emoji, style: const TextStyle(fontSize: 28)),
        title: Text(product.name),
        subtitle: Text('¥ ${product.price.toStringAsFixed(1)}'),
        trailing: FilledButton.tonal(
          // 加购时传入完整的 Product 实体（价格随实体走）
          onPressed: () => context.read<CartCubit>().add(product),
          child: const Text('加入购物车'),
        ),
      ),
    );
  }
}

/// 购物车区：行明细、总价、清空、查看详情（Dialog 演示 BlocProvider.value）
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
                      count: state.totalCount,
                      backgroundColor: theme.colorScheme.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (state.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      '购物车还是空的，去上面加购吧',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else ...[
                  // 行明细：每行独立增减数量，小计 = 单价 × 数量
                  for (final line in state.items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${line.product.emoji} ${line.product.name}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '¥ ${line.product.price.toStringAsFixed(1)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () => context
                                .read<CartCubit>()
                                .removeOne(line.product.id),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text('${line.quantity}'),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () =>
                                context.read<CartCubit>().add(line.product),
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                          SizedBox(
                            width: 64,
                            child: Text(
                              '¥ ${line.subtotal.toStringAsFixed(1)}',
                              textAlign: TextAlign.right,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Divider(),
                  Text(
                    '合计：¥ ${state.totalPrice.toStringAsFixed(1)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed:
                          state.isEmpty
                              ? null
                              : () => context.read<CartCubit>().clear(),
                      child: const Text('清空'),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: state.isEmpty
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
            builder: (context, state) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in state.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${line.product.emoji} ${line.product.name} × ${line.quantity}',
                          ),
                        ),
                        Text('¥ ${line.subtotal.toStringAsFixed(1)}'),
                      ],
                    ),
                  ),
                const Divider(),
                Text(
                  '共 ${state.totalCount} 件，合计 ¥ ${state.totalPrice.toStringAsFixed(1)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '本 Dialog 通过 BlocProvider.value 共享页面上的同一个 CartCubit，'
                  '这里看到的数据与页面完全同步。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
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
