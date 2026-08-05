import '../models/user.dart';

/// 认证仓库（模拟实现）
///
/// Model 层的仓库类，Bloc / Riverpod 两套实现共用同一个仓库，
/// 保证对比时业务逻辑（模拟网络延迟、账号校验、错误场景）完全一致，
/// 差异仅体现在状态管理层。
///
/// 生产环境中这里会替换为基于 Dio / HTTP 的真实实现，
/// ViewModel 层不需要任何改动（依赖接口而非实现）。
class AuthRepository {
  const AuthRepository();

  /// 单例实例
  ///
  /// 模拟登录场景无状态持久化需求，直接使用常量单例；
  /// 生产环境可替换为带本地存储（SharedPreferences）的实现。
  static const instance = AuthRepository();

  /// 内置的合法账号（账号 -> 密码）
  static const _accounts = <String, String>{
    'admin': '123456',
    'flutter': 'dart2026',
  };

  /// 模拟登录请求
  ///
  /// 业务规则：
  /// - 模拟 1.5 秒网络延迟
  /// - 账号不存在 → 抛出 [AuthException]（账号不存在）
  /// - 密码错误   → 抛出 [AuthException]（密码错误）
  /// - 校验通过   → 返回 [User]
  Future<User> login({
    required String username,
    required String password,
  }) async {
    // 模拟网络请求耗时
    await Future<void>.delayed(const Duration(milliseconds: 1500));

    final trimmedUsername = username.trim();
    if (!_accounts.containsKey(trimmedUsername)) {
      throw const AuthException('账号不存在');
    }
    if (_accounts[trimmedUsername] != password) {
      throw const AuthException('密码错误，请重试');
    }

    return User(
      id: 'u_${trimmedUsername.hashCode}',
      username: trimmedUsername,
      nickname: '用户 $trimmedUsername',
    );
  }

  /// 模拟退出登录
  Future<void> logout() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
}
