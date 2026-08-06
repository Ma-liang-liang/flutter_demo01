import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../viewmodels/step_counter_bloc.dart';
import '../widgets/explanation_card.dart';

/// 演示 2 · Bloc 事件驱动
///
/// 与 Cubit 不同，Bloc 用「事件」代替方法调用：
/// View 发送 Event → Bloc 匹配 handler → emit 新状态。
class BlocEventDemoPage extends StatelessWidget {
  const BlocEventDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => StepCounterBloc(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Bloc 事件驱动')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            ExplanationCard(
              title: 'Bloc 的三件套',
              points: [
                'Event：用户意图的不可变描述，如 `IncrementPressed()`、'
                    '`StepChanged(5)`，事件可以携带数据。',
                'State：某一时刻的完整界面数据快照，字段全 final。',
                'Bloc：构造函数里用 `on<XxxEvent>(handler)` 注册处理器，'
                    'handler 中通过 `emit` 产出新状态。',
              ],
            ),
            _StepCounterCard(),
            ExplanationCard(
              title: '为什么用事件而不是直接调方法',
              points: [
                '事件流默认串行处理，天然避免重复点击造成的并发竞态。',
                '每次状态变更都有明确的「事件来源」，便于日志、埋点和回放调试。',
                'Bloc 与 View 完全解耦：Bloc 不知道按钮的存在，'
                    '只认识事件，因此可以脱离 UI 单独做单元测试。',
                '经验法则：简单页面用 Cubit，复杂流程（表单、多步骤业务）用 Bloc。',
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 步长计数器交互卡片
class _StepCounterCard extends StatelessWidget {
  const _StepCounterCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: BlocBuilder<StepCounterBloc, StepCounterState>(
          builder: (context, state) {
            return Column(
              children: [
                Text(
                  '${state.count}',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '当前步长：${state.step}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.filled(
                      // View 只负责把「意图」包装成事件发出去
                      onPressed: () => context
                          .read<StepCounterBloc>()
                          .add(const DecrementPressed()),
                      icon: const Icon(Icons.remove),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: () => context
                          .read<StepCounterBloc>()
                          .add(const ResetPressed()),
                      child: const Text('重置'),
                    ),
                    const SizedBox(width: 12),
                    IconButton.filled(
                      onPressed: () => context
                          .read<StepCounterBloc>()
                          .add(const IncrementPressed()),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // 事件携带数据：切换步长时发出 StepChanged(step)
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 1, label: Text('步长 1')),
                    ButtonSegment(value: 5, label: Text('步长 5')),
                    ButtonSegment(value: 10, label: Text('步长 10')),
                  ],
                  selected: {state.step},
                  onSelectionChanged: (selection) => context
                      .read<StepCounterBloc>()
                      .add(StepChanged(selection.first)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
