part of 'login_bloc.dart';

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
/// 单一不可变状态类 + `copyWith`，所有字段集中管理，
/// 每次状态变化都产生新实例，View 通过对比新旧状态决定是否重建。
///
/// `props` 决定两个状态是否相等：相等的状态不会触发 View 重建。
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
