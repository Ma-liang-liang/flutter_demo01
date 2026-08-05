import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../common/models/user.dart';
import '../../common/repositories/auth_repository.dart';

part 'login_event.dart';
part 'login_state.dart';

/// 登录 ViewModel（Bloc 实现）
///
/// MVVM 中的 ViewModel 层，职责：
/// 1. 接收 View 发来的事件（[LoginEvent]）
/// 2. 调用 Model 层的 [AuthRepository] 执行业务
/// 3. 产出不可变状态（[LoginState]）驱动 View 重建
///
/// View 不直接持有业务逻辑，所有逻辑收敛在本类中，可脱离 UI 单独单测。
///
/// 事件流默认按顺序处理（同一时刻只有一个 handler 在执行），
/// 天然避免了重复点击提交导致的并发请求问题。
class LoginBloc extends Bloc<LoginEvent, LoginState> {
  LoginBloc({AuthRepository? authRepository})
    : _authRepository = authRepository ?? AuthRepository.instance,
      super(const LoginState()) {
    on<UsernameChanged>(_onUsernameChanged);
    on<PasswordChanged>(_onPasswordChanged);
    on<LoginSubmitted>(_onLoginSubmitted);
    on<LogoutRequested>(_onLogoutRequested);
  }

  final AuthRepository _authRepository;

  /// 账号输入变化：更新状态并清除上一次的错误提示
  void _onUsernameChanged(UsernameChanged event, Emitter<LoginState> emit) {
    emit(state.copyWith(username: event.username, clearErrorMessage: true));
  }

  /// 密码输入变化
  void _onPasswordChanged(PasswordChanged event, Emitter<LoginState> emit) {
    emit(state.copyWith(password: event.password, clearErrorMessage: true));
  }

  /// 提交登录
  ///
  /// 完整流程：校验 → 置提交中 → 调仓库 → 成功 / 失败落状态。
  /// 任何异常都收敛为 [LoginStatus.failure]，View 只需消费状态。
  Future<void> _onLoginSubmitted(
    LoginSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    // 防御性校验：按钮已按 canSubmit 置灰，这里兜底
    if (!state.canSubmit) return;

    emit(state.copyWith(status: LoginStatus.submitting, clearErrorMessage: true));

    try {
      final user = await _authRepository.login(
        username: state.username,
        password: state.password,
      );
      emit(state.copyWith(status: LoginStatus.success, user: user));
    } on AuthException catch (e) {
      emit(
        state.copyWith(status: LoginStatus.failure, errorMessage: e.message),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: LoginStatus.failure,
          errorMessage: '登录失败，请稍后重试',
        ),
      );
    }
  }

  /// 退出登录：调用仓库并重置状态回初始
  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<LoginState> emit,
  ) async {
    await _authRepository.logout();
    emit(
      const LoginState().copyWith(
        username: state.username,
        password: state.password,
      ),
    );
  }
}
