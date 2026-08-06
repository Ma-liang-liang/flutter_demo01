import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../viewmodels/countdown_bloc.dart';
import '../widgets/explanation_card.dart';

/// 演示 6 · Bloc 与 Stream 倒计时
///
/// Bloc 内部订阅周期流，tick 转成内部事件更新状态，
/// 展示流驱动的状态更新与 bloc 关闭时的资源清理。
class StreamCountdownDemoPage extends StatelessWidget {
  const StreamCountdownDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CountdownBloc(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Bloc 与 Stream')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            ExplanationCard(
              title: 'Bloc 里如何处理 Stream',
              points: [
                '流的回调发生在事件处理流程之外，不能直接 `emit`。'
                    '标准做法：在流回调里 `add(内部事件)`，把流的输出转成事件。',
                '内部事件用私有类表示（如 `_Tick`），View 看不到也无法发送，'
                    '保证状态变更只经过 ViewModel 自己的管道。',
                '所有事件仍然串行处理，tick 与暂停 / 重置不会互相打架。',
              ],
            ),
            _CountdownCard(),
            ExplanationCard(
              title: '生命周期与内存泄漏',
              points: [
                '`BlocProvider` 在子树销毁时自动调用 bloc 的 `close()`。',
                'bloc 内部持有的 `StreamSubscription` 必须在 `close()` 里取消，'
                    '否则页面销毁后流仍在回调，造成内存泄漏。',
                '倒计时结束、暂停时也要及时 cancel，避免无意义的 tick。',
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 倒计时交互卡片：进度环 + 控制按钮
class _CountdownCard extends StatelessWidget {
  const _CountdownCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: BlocBuilder<CountdownBloc, CountdownState>(
          builder: (context, state) {
            return Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 160,
                      height: 160,
                      child: CircularProgressIndicator(
                        value: state.progress,
                        strokeWidth: 10,
                        color: state.status == CountdownStatus.finished
                            ? theme.colorScheme.tertiary
                            : theme.colorScheme.primary,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                    Text(
                      state.status == CountdownStatus.idle
                          ? '--'
                          : '${state.remaining}s',
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  switch (state.status) {
                    CountdownStatus.idle => '选择时长后开始',
                    CountdownStatus.running => '倒计时进行中…',
                    CountdownStatus.paused => '已暂停',
                    CountdownStatus.finished => '时间到！🎉',
                  },
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    if (state.status == CountdownStatus.idle ||
                        state.status == CountdownStatus.finished) ...[
                      for (final seconds in [10, 30, 60])
                        FilledButton.tonal(
                          onPressed: () => context
                              .read<CountdownBloc>()
                              .add(CountdownStarted(seconds)),
                          child: Text('${seconds}s'),
                        ),
                    ],
                    if (state.status == CountdownStatus.running)
                      OutlinedButton(
                        onPressed: () => context
                            .read<CountdownBloc>()
                            .add(const CountdownPaused()),
                        child: const Text('暂停'),
                      ),
                    if (state.status == CountdownStatus.paused)
                      FilledButton(
                        onPressed: () => context
                            .read<CountdownBloc>()
                            .add(const CountdownResumed()),
                        child: const Text('继续'),
                      ),
                    if (state.status != CountdownStatus.idle)
                      TextButton(
                        onPressed: () => context
                            .read<CountdownBloc>()
                            .add(const CountdownReset()),
                        child: const Text('重置'),
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
}
