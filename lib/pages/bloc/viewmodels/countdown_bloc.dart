import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// 倒计时 Bloc（MVVM 中的 ViewModel 层）
///
/// 演示 Bloc 与 Stream 的结合：Bloc 内部订阅一个周期流，
/// 每次 tick 通过 `add(_Tick())` 转成事件再更新状态。
///
/// 为什么不直接 emit？因为 emit 只能在事件处理流程内调用，
/// 而流的回调发生在 handler 之外；转成事件后所有状态变更
/// 仍然走同一条串行管道，保证线程安全与可追溯性。
///
/// 生命周期要点：bloc 关闭（页面销毁）时必须取消订阅，
/// 否则会内存泄漏——在 [close] 中处理是标准做法。
class CountdownBloc extends Bloc<CountdownEvent, CountdownState> {
  CountdownBloc() : super(const CountdownState()) {
    on<CountdownStarted>(_onStarted);
    on<CountdownPaused>(_onPaused);
    on<CountdownResumed>(_onResumed);
    on<CountdownReset>(_onReset);
    on<_Tick>(_onTick);
  }

  StreamSubscription<int>? _ticker;

  void _onStarted(CountdownStarted event, Emitter<CountdownState> emit) {
    _ticker?.cancel();
    // 每秒发一个递增整数，Bloc 把它转成 _Tick 事件
    _ticker = Stream<int>.periodic(const Duration(seconds: 1), (i) => i + 1)
        .listen((_) => add(const _Tick()));
    emit(
      state.copyWith(
        status: CountdownStatus.running,
        total: event.seconds,
        remaining: event.seconds,
      ),
    );
  }

  void _onPaused(CountdownPaused event, Emitter<CountdownState> emit) {
    _ticker?.cancel();
    emit(state.copyWith(status: CountdownStatus.paused));
  }

  void _onResumed(CountdownResumed event, Emitter<CountdownState> emit) {
    if (state.remaining <= 0) return;
    _ticker = Stream<int>.periodic(const Duration(seconds: 1), (i) => i + 1)
        .listen((_) => add(const _Tick()));
    emit(state.copyWith(status: CountdownStatus.running));
  }

  void _onReset(CountdownReset event, Emitter<CountdownState> emit) {
    _ticker?.cancel();
    emit(const CountdownState());
  }

  void _onTick(_Tick event, Emitter<CountdownState> emit) {
    final remaining = state.remaining - 1;
    if (remaining <= 0) {
      _ticker?.cancel();
      emit(state.copyWith(status: CountdownStatus.finished, remaining: 0));
    } else {
      emit(state.copyWith(remaining: remaining));
    }
  }

  /// bloc 关闭时取消订阅，防止内存泄漏
  @override
  Future<void> close() {
    _ticker?.cancel();
    return super.close();
  }
}

enum CountdownStatus { idle, running, paused, finished }

/// 事件（下划线开头的 [_Tick] 是 Bloc 内部事件，View 不可见）
sealed class CountdownEvent extends Equatable {
  const CountdownEvent();

  @override
  List<Object?> get props => [];
}

final class CountdownStarted extends CountdownEvent {
  const CountdownStarted(this.seconds);

  final int seconds;

  @override
  List<Object?> get props => [seconds];
}

final class CountdownPaused extends CountdownEvent {
  const CountdownPaused();
}

final class CountdownResumed extends CountdownEvent {
  const CountdownResumed();
}

final class CountdownReset extends CountdownEvent {
  const CountdownReset();
}

final class _Tick extends CountdownEvent {
  const _Tick();
}

class CountdownState extends Equatable {
  const CountdownState({
    this.status = CountdownStatus.idle,
    this.total = 0,
    this.remaining = 0,
  });

  final CountdownStatus status;
  final int total;
  final int remaining;

  /// 进度 0.0 ~ 1.0，供进度环使用
  double get progress => total == 0 ? 0 : remaining / total;

  CountdownState copyWith({
    CountdownStatus? status,
    int? total,
    int? remaining,
  }) => CountdownState(
    status: status ?? this.status,
    total: total ?? this.total,
    remaining: remaining ?? this.remaining,
  );

  @override
  List<Object?> get props => [status, total, remaining];
}
