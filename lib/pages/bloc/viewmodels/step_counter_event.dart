part of 'step_counter_bloc.dart';

/// 事件基类：所有事件继承 [StepCounterEvent] 并继承 [Equatable]，
/// 保证相同内容的事件被视为同一事件（可用于去重、日志对比）。
sealed class StepCounterEvent extends Equatable {
  const StepCounterEvent();

  @override
  List<Object?> get props => [];
}

/// 点击「加」按钮
final class IncrementPressed extends StepCounterEvent {
  const IncrementPressed();
}

/// 点击「减」按钮
final class DecrementPressed extends StepCounterEvent {
  const DecrementPressed();
}

/// 步长发生变化（事件可携带数据）
final class StepChanged extends StepCounterEvent {
  const StepChanged(this.step);

  final int step;

  @override
  List<Object?> get props => [step];
}

/// 点击「重置」按钮
final class ResetPressed extends StepCounterEvent {
  const ResetPressed();
}
