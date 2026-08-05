import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../utils/app_colors.dart';
import '../../../widgets/demo_page_scaffold.dart';
import '../../../widgets/section_card.dart';
import '../providers/stream_provider_examples.dart';

/// Riverpod 演示 04：StreamProvider 用法
///
/// 展示 StreamProvider 处理流式数据：实时计时器、倒计时、模拟股票行情。
/// 与 FutureProvider 类似返回 AsyncValue，但持续接收多个值。
class StreamProviderDemoPage extends ConsumerWidget {
  const StreamProviderDemoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const DemoPageScaffold(
      title: 'StreamProvider 用法',
      goal: 'StreamProvider 包装 Stream，适用于实时数据推送场景。'
          '持续接收多个值，同样返回 AsyncValue 支持三态渲染。',
      children: [
        _TimerSection(),
        _CountdownSection(),
        _StockPriceSection(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 实时计时器
// ---------------------------------------------------------------------------
class _TimerSection extends ConsumerWidget {
  const _TimerSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCount = ref.watch(timerStreamProvider);
    final theme = Theme.of(context);

    return SectionCard(
      title: '实时计时器',
      subtitle: 'async* 生成器 / 每秒 yield 一个值',
      icon: Icons.timer_outlined,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                asyncCount.when(
                  loading: () => const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (_, _) => const Icon(Icons.error),
                  data: (count) => Text(
                    '$count',
                    style: theme.textTheme.displayLarge?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '秒',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _CodeBlock(text: '''
final timerStreamProvider =
    StreamProvider.autoDispose<int>((ref) async* {
  int count = 0;
  while (true) {
    await Future.delayed(Duration(seconds: 1));
    count++;
    yield count;
  }
});'''),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 倒计时
// ---------------------------------------------------------------------------
class _CountdownSection extends ConsumerWidget {
  const _CountdownSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCount = ref.watch(countdownStreamProvider);
    final theme = Theme.of(context);

    return SectionCard(
      title: '倒计时（10 → 0）',
      subtitle: 'Stream.periodic + take(11)',
      icon: Icons.hourglass_top_outlined,
      child: Column(
        children: [
          SizedBox(
            height: 120,
            child: Center(
              child: asyncCount.when(
                loading: () => const CircularProgressIndicator(),
                error: (_, _) => const Icon(Icons.error),
                data: (value) {
                  final isDone = value <= 0;
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isDone ? '完成！' : '$value',
                        style: theme.textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDone ? theme.colorScheme.primary : null,
                        ),
                      ),
                      if (!isDone) ...[
                        const SizedBox(height: 8),
                        // 线性进度条
                        SizedBox(
                          width: 200,
                          child: LinearProgressIndicator(
                            value: (10 - value) / 10,
                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          ),
                        ),
                      ],
                      if (isDone)
                        FilledButton(
                          onPressed: () => ref.invalidate(countdownStreamProvider),
                          child: const Text('重新开始'),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Stream.periodic 每秒发出一个值，take(11) 限制为 11 次。',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 模拟实时股票行情
// ---------------------------------------------------------------------------
class _StockPriceSection extends ConsumerWidget {
  const _StockPriceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncStock = ref.watch(stockPriceProvider);
    final theme = Theme.of(context);

    return SectionCard(
      title: '模拟实时行情',
      subtitle: '每 800ms 更新价格 / 涨跌颜色变化',
      icon: Icons.trending_up,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          asyncStock.when(
            loading: () => const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => const SizedBox(
              height: 80,
              child: Center(child: Icon(Icons.error)),
            ),
            data: (stock) {
              final isUp = stock.change >= 0;
              final appColors = Theme.of(context).extension<AppColors>()!;
              final color = isUp ? appColors.success : appColors.danger;
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stock.symbol,
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Flutter Corp.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '¥${stock.price.toStringAsFixed(2)}',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        Row(
                          children: [
                            Icon(
                              isUp ? Icons.arrow_upward : Icons.arrow_downward,
                              size: 16,
                              color: color,
                            ),
                            Text(
                              '${stock.change >= 0 ? '+' : ''}${stock.change.toStringAsFixed(2)}',
                              style: TextStyle(color: color, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _CodeBlock(text: '''
final stockPriceProvider =
    StreamProvider.autoDispose<StockPrice>((ref) async* {
  double price = 100.0;
  while (true) {
    await Future.delayed(Duration(milliseconds: 800));
    final delta = (Random().nextDouble() * 6 - 3);
    price = (price + delta).clamp(50.0, 200.0);
    yield StockPrice(symbol: 'FLTR', price: price, change: delta);
  }
});'''),
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
