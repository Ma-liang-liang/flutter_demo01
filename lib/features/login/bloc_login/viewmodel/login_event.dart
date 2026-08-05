part of 'login_bloc.dart';

/// 登录模块事件定义
///
/// MVVM 中 View 与 ViewModel 之间的交互媒介：
/// View 不直接调用 ViewModel 的方法，而是「发送事件」，
/// 由 Bloc 内部决定如何处理并驱动状态变化。
///
/// 使用 `sealed class` 配合 Dart 3 模式匹配，
/// 保证 `switch` 处理事件时编译器强制覆盖所有分支（不生成代码，纯手写）。
sealed class LoginEvent extends Equatable {
  const LoginEvent();

  @override
  List<Object?> get props => [];
}

/// 账号输入变化
final class UsernameChanged extends LoginEvent {
  const UsernameChanged(this.username);

  final String username;

  @override
  List<Object?> get props => [username];
}

/// 密码输入变化
final class PasswordChanged extends LoginEvent {
  const PasswordChanged(this.password);

  final String password;

  @override
  List<Object?> get props => [password];
}

/// 提交登录
final class LoginSubmitted extends LoginEvent {
  const LoginSubmitted();
}

/// 退出登录（重置回初始状态）
final class LogoutRequested extends LoginEvent {
  const LogoutRequested();
}
