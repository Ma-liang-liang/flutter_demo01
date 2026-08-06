import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../viewmodels/counter_cubit.dart';
import '../widgets/explanation_card.dart';

/// 演示 1 · Cubit 基础用法
///
/// 通过最经典的计数器，展示 Bloc 体系的最小闭环：
/// View 调用 Cubit 方法 → Cubit emit 新状态 → BlocBuilder 重建 UI。
class CubitBasicDemoPage extends StatelessWidget {
  const CubitBasicDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    // BlocProvider：创建 CounterCubit 并注入子树，
    // 页面销毁时自动调用 cubit.close() 释放资源
    return BlocProvider(
      create: (_) => CounterCubit(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Cubit 基础用法')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            ExplanationCard(
              title: 'Cubit 是什么',
              points: [
                'Cubit 是 Bloc 的简化版，继承自 `Cubit<State>`，'
                    '直接暴露方法，方法内用 `emit(新状态)` 通知 UI 更新。',
                'MVVM 视角：Cubit 就是 ViewModel，持有业务逻辑；'
                    '页面是 View，只负责「发指令」和「渲染状态」。',
                '状态类必须是不可变的（字段全 final），'
                    '每次变化都 emit 一个「新实例」，而不是修改旧对象。',
              ],
            ),
            _CounterCard(),
            ExplanationCard(
              title: 'View 与 Cubit 的两种交互方向',
              points: [
                'View → Cubit：`context.read<CounterCubit>().increment()`，'
                    'read 只取实例、不监听，适合事件触发。',
                'Cubit → View：`BlocBuilder<CounterCubit, CounterState>` '
                    '监听状态变化，状态变了才重建内部的 builder。',
                '状态类继承 `Equatable` 后，emit 内容相同的状态不会触发重建，'
                    '这是 Bloc 自带的去重优化。',
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 计数器卡片：本页面唯一的交互区
class _CounterCard extends StatelessWidget {
  const _CounterCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text('当前计数', style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            // BlocBuilder 只包裹真正依赖状态的最小范围
            BlocBuilder<CounterCubit, CounterState>(
              builder: (context, state) => Text(
                '${state.count}',
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: state.isNegative
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filled(
                  onPressed: () => context.read<CounterCubit>().decrement(),
                  icon: const Icon(Icons.remove),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () => context.read<CounterCubit>().reset(),
                  child: const Text('重置'),
                ),
                const SizedBox(width: 12),
                IconButton.filled(
                  onPressed: () => context.read<CounterCubit>().increment(),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.read<CounterCubit>().addBy(10),
              child: const Text('一次 +10'),
            ),
          ],
        ),
      ),
    );
  }
}
