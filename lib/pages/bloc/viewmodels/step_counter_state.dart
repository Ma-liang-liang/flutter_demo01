part of 'step_counter_bloc.dart';

/// 步长计数器状态
///
/// 包含当前计数 [count] 与步长 [step] 两个字段，
/// 使用 `sealed class` + [Equatable]，支持模式匹配且具备值相等性。
class StepCounterState extends Equatable {
  const StepCounterState({this.count = 0, this.step = 1});

  final int count;
  final int step;

  StepCounterState copyWith({int? count, int? step}) => StepCounterState(
    count: count ?? this.count,
    step: step ?? this.step,
  );

  @override
  List<Object?> get props => [count, step];
}
