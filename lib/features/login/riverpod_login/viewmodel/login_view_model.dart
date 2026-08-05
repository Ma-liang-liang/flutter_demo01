import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/models/user.dart';
import '../../common/repositories/auth_repository.dart';

/// 登录提交状态
enum LoginStatus {
  /// 初始 / 空闲
  initial,

  /// 正在提交（请求进行中）
  submitting,

  /// 登录成功
  success,

  /// 登录失败
  failure,
}

/// 登录模块状态
///
/// 单一不可变状态类 + `copyWith`，与 Bloc 版完全同构，
/// 便于对比两种方案在「状态建模」层面的一致性。
final class LoginState extends Equatable {
  const LoginState({
    this.username = '',
    this.password = '',
    this.status = LoginStatus.initial,
    this.user,
    this.errorMessage,
  });

  /// 账号输入值
  final String username;

  /// 密码输入值
  final String password;

  /// 提交流程状态
  final LoginStatus status;

  /// 登录成功后的用户信息
  final User? user;

  /// 登录失败的错误信息
  final String? errorMessage;

  /// 表单是否可提交：账号非空且密码不少于 6 位，且当前不在提交中
  bool get canSubmit =>
      username.trim().isNotEmpty &&
      password.length >= 6 &&
      status != LoginStatus.submitting;

  /// 是否处于登录成功状态
  bool get isLoggedIn => status == LoginStatus.success;

  LoginState copyWith({
    String? username,
    String? password,
    LoginStatus? status,
    User? user,
    String? errorMessage,
    bool clearUser = false,
    bool clearErrorMessage = false,
  }) {
    return LoginState(
      username: username ?? this.username,
      password: password ?? this.password,
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [username, password, status, user, errorMessage];
}

/// 登录 ViewModel（Riverpod 实现）
///
/// MVVM 中的 ViewModel 层，继承 [Notifier]：
/// 1. `build()` 返回初始状态，Provider 被销毁时自动清理（无需手动 dispose）
/// 2. View 直接调用 ViewModel 的公开方法（区别于 Bloc 的事件机制）
/// 3. 通过 `state = ...` 发布新的不可变状态驱动 View 重建
///
/// 依赖可通过 [ref] 读取其他 Provider（生产环境中 AuthRepository 也会
/// 以 Provider 形式注入，便于测试时 override 替换为 Mock）。
///
/// 继承 [AutoDisposeNotifier] 以配合 `autoDispose` Provider：
/// 无监听者时状态自动销毁，再次监听时重新 `build()`。
class LoginViewModel extends AutoDisposeNotifier<LoginState> {
  /// Model 层仓库（生产环境建议改为通过 ref.read 注入的 Provider）
  final AuthRepository _authRepository = AuthRepository.instance;

  /// 提供初始状态；本方法在 Provider 首次被监听时调用
  @override
  LoginState build() => const LoginState();

  /// 账号输入变化：更新状态并清除上一次的错误提示
  void usernameChanged(String value) {
    state = state.copyWith(username: value, clearErrorMessage: true);
  }

  /// 密码输入变化
  void passwordChanged(String value) {
    state = state.copyWith(password: value, clearErrorMessage: true);
  }

  /// 提交登录
  ///
  /// 完整流程：校验 → 置提交中 → 调仓库 → 成功 / 失败落状态。
  /// Riverpod 没有 Bloc 的串行事件队列，需自行做防重入判断。
  Future<void> submitLogin() async {
    // 防重入 + 表单校验兜底
    if (!state.canSubmit) return;

    state = state.copyWith(
      status: LoginStatus.submitting,
      clearErrorMessage: true,
    );

    try {
      final user = await _authRepository.login(
        username: state.username,
        password: state.password,
      );
      state = state.copyWith(status: LoginStatus.success, user: user);
    } on AuthException catch (e) {
      state = state.copyWith(
        status: LoginStatus.failure,
        errorMessage: e.message,
      );
    } catch (_) {
      state = state.copyWith(
        status: LoginStatus.failure,
        errorMessage: '登录失败，请稍后重试',
      );
    }
  }

  /// 退出登录：调用仓库并重置状态回初始（保留输入框内容）
  Future<void> logout() async {
    await _authRepository.logout();
    state = const LoginState().copyWith(
      username: state.username,
      password: state.password,
    );
  }
}

/// 登录 ViewModel 的 Provider
///
/// 命名规范：`xxxViewModelProvider` 与 [LoginViewModel] 同文件定义。
/// `autoDispose` 保证页面销毁后状态自动释放，再次进入重新构建。
final loginViewModelProvider =
    NotifierProvider.autoDispose<LoginViewModel, LoginState>(
      LoginViewModel.new,
    );
