import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// 计数器 Cubit（MVVM 中的 ViewModel 层）
///
/// Cubit 是 Bloc 的简化版：不需要定义 Event，直接暴露方法，
/// 方法内部通过 `emit(新状态)` 通知 View 重建。
///
/// 状态类继承 [Equatable]：Bloc 框架通过 `==` 判断状态是否变化，
/// 相同状态不会触发 UI 重建（去重优化）。
class CounterCubit extends Cubit<CounterState> {
  CounterCubit() : super(const CounterState());

  /// 加 1
  void increment() => emit(state.copyWith(count: state.count + 1));

  /// 减 1
  void decrement() => emit(state.copyWith(count: state.count - 1));

  /// 按步长增减
  void addBy(int step) => emit(state.copyWith(count: state.count + step));

  /// 重置为 0
  void reset() => emit(const CounterState());
}

/// 计数器状态（不可变值对象）
///
/// 状态字段一律 final，"修改状态"实际上是 emit 一个新实例。
/// 不可变状态是 Bloc 体系的核心约定：保证状态可预测、可追溯。
class CounterState extends Equatable {
  const CounterState({this.count = 0});

  final int count;

  /// 派生值：UI 需要的展示信息尽量在状态里计算好，View 不做逻辑
  bool get isNegative => count < 0;

  CounterState copyWith({int? count}) =>
      CounterState(count: count ?? this.count);

  @override
  List<Object?> get props => [count];
}
