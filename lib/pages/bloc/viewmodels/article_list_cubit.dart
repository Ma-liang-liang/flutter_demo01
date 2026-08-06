import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/article_repository.dart';

/// 文章列表 Cubit（MVVM 中的 ViewModel 层）
///
/// 演示「异步请求 + 三态状态机」这一最常见的业务场景：
/// [ArticleStatus] 枚举 loading / success / failure 三种状态，
/// View 侧只需 switch 状态渲染对应 UI，不关心请求细节。
class ArticleListCubit extends Cubit<ArticleListState> {
  ArticleListCubit({ArticleRepository? repository})
    : _repository = repository ?? ArticleRepository.instance,
      super(const ArticleListState());

  final ArticleRepository _repository;

  /// 拉取数据：先置 loading，再根据结果落 success / failure
  Future<void> load() async {
    // 加载中禁止重复请求
    if (state.status == ArticleStatus.loading) return;

    emit(state.copyWith(status: ArticleStatus.loading));
    try {
      final articles = await _repository.fetchArticles();
      emit(
        state.copyWith(status: ArticleStatus.success, articles: articles),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: ArticleStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }
}

/// 加载状态枚举
enum ArticleStatus { initial, loading, success, failure }

/// 文章列表状态
class ArticleListState extends Equatable {
  const ArticleListState({
    this.status = ArticleStatus.initial,
    this.articles = const [],
    this.errorMessage = '',
  });

  final ArticleStatus status;
  final List<Article> articles;
  final String errorMessage;

  ArticleListState copyWith({
    ArticleStatus? status,
    List<Article>? articles,
    String? errorMessage,
  }) => ArticleListState(
    status: status ?? this.status,
    articles: articles ?? this.articles,
    errorMessage: errorMessage ?? this.errorMessage,
  );

  @override
  List<Object?> get props => [status, articles, errorMessage];
}
