import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../viewmodels/save_form_cubit.dart';
import '../widgets/explanation_card.dart';

/// 演示 4 · BlocListener 与 BlocConsumer
///
/// 弹 SnackBar / Dialog / 路由跳转这类「一次性副作用」
/// 不能写在 build 里，要用 listener 消费。
class ListenerConsumerDemoPage extends StatelessWidget {
  const ListenerConsumerDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SaveFormCubit(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Listener 与 Consumer')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            ExplanationCard(
              title: '一次性副作用为什么不能放在 build 里',
              points: [
                'build 可能被父级重建、热重载等多次触发，'
                    '把弹框逻辑放 builder 里会导致重复弹出。',
                '`BlocListener` 只在「状态发生变化」时回调一次，'
                    '天生适合 SnackBar / Dialog / 页面跳转等一次性动作。',
                '`BlocConsumer` = `BlocListener` + `BlocBuilder` 的合体，'
                    '同一个状态既要弹提示又要改 UI 时用它，少一层嵌套。',
              ],
            ),
            _SubmitCard(),
            ExplanationCard(
              title: 'listenWhen 与状态复位',
              points: [
                '`listenWhen: (prev, curr) => ...` 可以过滤关心的状态变化，'
                    '避免无关状态变更触发副作用。',
                '副作用消费完毕后调用 `acknowledge()` 把状态复位为 idle，'
                    '防止页面重建时重复消费同一条消息。',
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 提交卡片：BlocConsumer 同时处理 UI 与副作用
class _SubmitCard extends StatefulWidget {
  const _SubmitCard();

  @override
  State<_SubmitCard> createState() => _SubmitCardState();
}

class _SubmitCardState extends State<_SubmitCard> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: BlocConsumer<SaveFormCubit, SaveFormState>(
          // 只在成功或失败时触发 listener
          listenWhen: (prev, curr) =>
              curr.status == SaveStatus.success ||
              curr.status == SaveStatus.failure,
          listener: (context, state) {
            final cubit = context.read<SaveFormCubit>();
            if (state.status == SaveStatus.success) {
              // 成功：弹 SnackBar（一次性副作用）
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: theme.colorScheme.inverseSurface,
                ),
              );
            } else {
              // 失败：弹 Dialog（一次性副作用）
              showDialog<void>(
                context: context,
                builder: (_) => AlertDialog(
                  icon: const Icon(Icons.error_outline),
                  title: const Text('保存失败'),
                  content: Text(state.message),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('知道了'),
                    ),
                  ],
                ),
              );
            }
            // 副作用消费完毕，复位状态
            cubit.acknowledge();
          },
          builder: (context, state) {
            final submitting = state.status == SaveStatus.submitting;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _controller,
                  enabled: !submitting,
                  decoration: const InputDecoration(
                    labelText: '写点什么再提交',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: submitting
                      ? null
                      : () => context.read<SaveFormCubit>().submit(
                            content: _controller.text,
                          ),
                  icon: submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_outlined),
                  label: Text(submitting ? '提交中…' : '提交（1/3 概率失败）'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
