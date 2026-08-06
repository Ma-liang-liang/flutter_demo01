import 'dart:math';

/// 文章实体（MVVM 中的 Model 层 · 实体）
class Article {
  const Article({required this.id, required this.title, required this.author});

  final int id;
  final String title;
  final String author;
}

/// 模拟文章仓库（MVVM 中的 Model 层 · Repository）
///
/// 演示用：随机延时 0.8~1.5s 模拟网络请求，约 1/3 概率抛出异常，
/// 用于展示 Bloc 对「加载中 / 成功 / 失败」三态的统一处理。
class ArticleRepository {
  ArticleRepository._();

  static final ArticleRepository instance = ArticleRepository._();

  static const _titles = [
    '深入理解 Bloc的事件驱动模型',
    'Cubit与Bloc该如何选择',
    'Flutter状态管理方案横向对比',
    'Equatable在状态去重中的作用',
    'BlocListener处理一次性副作用',
    'RepositoryProvider依赖注入实践',
  ];

  static const _authors = ['阿澜', '小枫', '老周', '青柠', '一舟'];

  final _random = Random();

  /// 拉取文章列表（模拟网络）
  Future<List<Article>> fetchArticles() async {
    await Future<void>.delayed(
      Duration(milliseconds: 800 + _random.nextInt(700)),
    );
    // 约 1/3 概率失败，用于演示 failure 状态
    if (_random.nextInt(3) == 0) {
      throw const SocketTimeoutException('请求超时，请重试');
    }
    final count = 4 + _random.nextInt(3);
    return List.generate(count, (i) {
      final title = _titles[(i + _random.nextInt(_titles.length)) % _titles.length];
      return Article(
        id: i,
        title: title,
        author: _authors[_random.nextInt(_authors.length)],
      );
    });
  }
}

/// 模拟网络异常
class SocketTimeoutException implements Exception {
  const SocketTimeoutException(this.message);

  final String message;

  @override
  String toString() => message;
}
