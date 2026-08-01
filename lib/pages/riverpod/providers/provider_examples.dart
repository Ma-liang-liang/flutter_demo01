import 'package:flutter_riverpod/flutter_riverpod.dart';

// ===========================================================================
// Provider —— 只读 / 计算型 Provider
//
// Provider 是 Riverpod 中最基础的 Provider 类型，适合：
//   - 缓存计算结果（避免重复计算）
//   - 提供依赖注入对象（Service / Repository）
//   - 组合其他 Provider 的值产生派生数据
//
// Provider 返回的值不可变，调用方只能通过 ref.watch 读取，不能直接修改。
// 当依赖的 Provider 变化时，Provider 会自动重新计算。
// ===========================================================================

/// 基础只读 Provider：返回一个固定字符串
///
/// 使用方式：ref.watch(greetingProvider) → 'Hello, Riverpod!'
final greetingProvider = Provider<String>((ref) {
  return 'Hello, Riverpod!';
});

/// 数值 Provider：提供初始计数
final baseCountProvider = Provider<int>((ref) {
  return 10;
});

/// 组合型 Provider：依赖 [baseCountProvider]，在其基础上计算
///
/// ref.watch(baseCountProvider) 建立依赖关系：
/// 当 baseCountProvider 变化时，doubledCountProvider 自动重新计算。
final doubledCountProvider = Provider<int>((ref) {
  final base = ref.watch(baseCountProvider);
  return base * 2;
});

/// 对象 Provider：返回一个自定义数据模型
class UserInfo {
  const UserInfo({required this.name, required this.age, required this.city});

  final String name;
  final int age;
  final String city;

  String get summary => '$name，$age 岁，来自 $city';
}

final userInfoProvider = Provider<UserInfo>((ref) {
  return const UserInfo(name: '张三', age: 28, city: '北京');
});

/// 计算型 Provider：根据 [userInfoProvider] 生成问候语
///
/// 展示 Provider 之间的链式依赖：greetingWithUserInfo → userInfoProvider
final greetingWithUserInfoProvider = Provider<String>((ref) {
  final user = ref.watch(userInfoProvider);
  return '你好，${user.name}！你今年 ${user.age} 岁，住在${user.city}。';
});
