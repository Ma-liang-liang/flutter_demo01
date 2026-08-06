import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// 保存表单 Cubit（MVVM 中的 ViewModel 层）
///
/// 演示「一次性副作用」场景：提交成功后弹 SnackBar、失败后弹 Dialog。
/// 这类动作只应执行一次，不能放进 BlocBuilder（build 可能被多次触发），
/// 正确做法是在 View 层用 BlocListener / BlocConsumer 的 listener 消费。
class SaveFormCubit extends Cubit<SaveFormState> {
  SaveFormCubit() : super(const SaveFormState());

  final _random = Random();

  /// 模拟提交：约 1/3 概率失败
  Future<void> submit({required String content}) async {
    if (state.status == SaveStatus.submitting) return;

    emit(state.copyWith(status: SaveStatus.submitting));
    await Future<void>.delayed(const Duration(milliseconds: 900));

    if (_random.nextInt(3) == 0) {
      emit(state.copyWith(status: SaveStatus.failure, message: '服务器繁忙，保存失败'));
    } else {
      emit(
        state.copyWith(
          status: SaveStatus.success,
          message: '保存成功（第 ${_random.nextInt(90) + 10} 次模拟）',
        ),
      );
    }
  }

  /// 副作用消费完毕后将状态复位，避免重复触发
  void acknowledge() => emit(state.copyWith(status: SaveStatus.idle));
}

enum SaveStatus { idle, submitting, success, failure }

class SaveFormState extends Equatable {
  const SaveFormState({this.status = SaveStatus.idle, this.message = ''});

  final SaveStatus status;
  final String message;

  SaveFormState copyWith({SaveStatus? status, String? message}) =>
      SaveFormState(
        status: status ?? this.status,
        message: message ?? this.message,
      );

  @override
  List<Object?> get props => [status, message];
}
