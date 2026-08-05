import 'package:equatable/equatable.dart';

/// 登录用户实体
///
/// Model 层的数据实体，Bloc / Riverpod 两套实现共用，
/// 保证对比时业务数据模型完全一致，差异仅体现在状态管理层。
class User extends Equatable {
  const User({
    required this.id,
    required this.username,
    required this.nickname,
  });

  /// 用户唯一标识
  final String id;

  /// 登录账号
  final String username;

  /// 展示昵称
  final String nickname;

  @override
  List<Object?> get props => [id, username, nickname];
}

/// 登录业务异常
///
/// 仓库层抛出的领域异常，携带面向用户的错误文案，
/// ViewModel 层捕获后直接透出给 View 展示。
class AuthException implements Exception {
  const AuthException(this.message);

  /// 面向用户的错误描述
  final String message;

  @override
  String toString() => 'AuthException: $message';
}
