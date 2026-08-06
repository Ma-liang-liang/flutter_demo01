import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/article_repository.dart';
import '../viewmodels/article_list_cubit.dart';
import '../widgets/explanation_card.dart';

/// 演示 3 · 异步加载三态
///
/// 业务中最常见的场景：发起网络请求，按 loading / success / failure
/// 三种状态渲染不同 UI。View 只 switch 状态，不关心请求细节。
class AsyncStateDemoPage extends StatelessWidget {
  const AsyncStateDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      // `..load()`：创建后立即触发首次加载
      create: (_) => ArticleListCubit()..load(),
      child: Scaffold(
        appBar: AppBar(title: const Text('异步加载三态')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const ExplanationCard(
              title: '三态状态机模式',
              points: [
                '状态里放一个 `status` 枚举（initial / loading / success / failure），'
                    'View 根据枚举 switch 出四种 UI，这是 Bloc 官方推荐的写法。',
                '请求失败时把错误信息收敛进状态的 `errorMessage`，'
                    'View 不做 try/catch、不感知异常类型。',
                '重试 / 重新加载只需再次调用 `load()`，状态机自动重走一遍。',
              ],
            ),
            BlocBuilder<ArticleListCubit, ArticleListState>(
              builder: (context, state) {
                return switch (state.status) {
                  ArticleStatus.initial => const SizedBox.shrink(),
                  ArticleStatus.loading => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  ArticleStatus.failure => _FailureCard(
                    message: state.errorMessage,
                  ),
                  ArticleStatus.success => _ArticleList(
                    articles: state.articles,
                  ),
                };
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 失败态卡片：展示错误信息 + 重试按钮
class _FailureCard extends StatelessWidget {
  const _FailureCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              '加载失败',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.read<ArticleListCubit>().load(),
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 成功态：文章列表（支持下拉刷新）
class _ArticleList extends StatelessWidget {
  const _ArticleList({required this.articles});

  final List<Article> articles;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
          Card(
            child: Column(
              children: [
                for (var i = 0; i < articles.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  ListTile(
                    leading: CircleAvatar(
                      radius: 14,
                      child: Text('${articles[i].id + 1}'),
                    ),
                    title: Text(articles[i].title),
                    subtitle: Text('作者：${articles[i].author}'),
                  ),
                ],
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => context.read<ArticleListCubit>().load(),
            icon: const Icon(Icons.refresh),
            label: const Text('重新加载（约 1/3 概率失败）'),
          ),
      ],
    );
  }
}
