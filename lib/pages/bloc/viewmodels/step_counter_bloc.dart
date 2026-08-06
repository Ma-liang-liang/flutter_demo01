import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'step_counter_event.dart';
part 'step_counter_state.dart';

/// 步长计数器 Bloc（MVVM 中的 ViewModel 层）
///
/// 与 Cubit 不同，Bloc 是「事件驱动」的：
/// 1. View 通过 `bloc.add(event)` 发送事件，而不是直接调方法；
/// 2. 构造函数里用 `on<XxxEvent>(handler)` 注册每个事件的处理函数；
/// 3. handler 内部通过 `emit` 产出新状态。
///
/// 事件驱动的好处：
/// - 事件流天然串行（同一时刻只处理一个事件），避免并发竞态；
/// - 所有变更都有「事件来源」，方便埋点、回放、单测；
/// - 事件本身可以携带元信息（本例 [StepChanged] 携带步长）。
class StepCounterBloc extends Bloc<StepCounterEvent, StepCounterState> {
  StepCounterBloc() : super(const StepCounterState()) {
    on<IncrementPressed>(_onIncrementPressed);
    on<DecrementPressed>(_onDecrementPressed);
    on<StepChanged>(_onStepChanged);
    on<ResetPressed>(_onResetPressed);
  }

  void _onIncrementPressed(
    IncrementPressed event,
    Emitter<StepCounterState> emit,
  ) {
    emit(state.copyWith(count: state.count + state.step));
  }

  void _onDecrementPressed(
    DecrementPressed event,
    Emitter<StepCounterState> emit,
  ) {
    emit(state.copyWith(count: state.count - state.step));
  }

  void _onStepChanged(StepChanged event, Emitter<StepCounterState> emit) {
    emit(state.copyWith(step: event.step));
  }

  void _onResetPressed(
    ResetPressed event,
    Emitter<StepCounterState> emit,
  ) {
    // 注意：这里 emit 的是「新实例」而非 copyWith，等价于回到初始态
    emit(StepCounterState(step: state.step));
  }
}
