import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

// ===========================================================================
// FutureProvider —— 异步数据
//
// FutureProvider 用于包装一个返回 Future 的操作，自动处理：
//   - loading（加载中）
//   - data（加载成功）
//   - error（加载失败）
//
// 常见场景：网络请求、数据库读取、文件 IO。
//
// 使用 ref.watch 获取 AsyncValue<T>，配合 .when / .maybeWhen / .value
// 进行 UI 渲染。调用 ref.refresh(provider) 可手动重新加载。
// ===========================================================================

/// 模拟网络请求：延迟后返回一段文本
///
/// 有 20% 概率抛出异常，用于演示 error 状态。
Future<String> _fetchGreeting() async {
  await Future.delayed(const Duration(seconds: 2));

  if (Random().nextDouble() < 0.2) {
    throw Exception('网络请求失败，请重试');
  }

  final messages = [
    '欢迎使用 Riverpod！',
    'FutureProvider 让异步变得简单',
    '数据加载成功！',
    '这是一条来自「服务器」的消息',
  ];
  return messages[Random().nextInt(messages.length)];
}

/// FutureProvider：包装上面的异步函数
///
/// ref.watch(asyncGreetingProvider) → `AsyncValue<String>`
/// ref.refresh(asyncGreetingProvider) → 重新触发请求
final asyncGreetingProvider = FutureProvider<String>((ref) async {
  return _fetchGreeting();
});

/// 模拟获取用户列表
class SimpleUser {
  const SimpleUser({required this.id, required this.name, required this.email});

  final int id;
  final String name;
  final String email;
}

Future<List<SimpleUser>> _fetchUsers() async {
  await Future.delayed(const Duration(seconds: 2));

  if (Random().nextDouble() < 0.2) {
    throw Exception('获取用户列表失败');
  }

  return List.generate(8, (i) {
    return SimpleUser(
      id: i + 1,
      name: '用户 ${i + 1}',
      email: 'user${i + 1}@example.com',
    );
  });
}

/// autoDispose FutureProvider：当没有监听者时自动释放状态
///
/// 适合列表页等「离开页面即丢弃数据」的场景，避免内存泄漏。
/// 与不带 autoDispose 的 Provider 区别：每次重新进入页面都会重新加载。
final autoDisposeUsersProvider =
    FutureProvider.autoDispose<List<SimpleUser>>((ref) async {
  // keepAlive: 如果需要在一定时间内不重复请求，可配合 ref.keepAlive()
  // final link = ref.keepAlive();
  // Timer(Duration(minutes: 5), link.close);
  return _fetchUsers();
});

/// 模拟随机数生成器（每次 refresh 都不同）
final randomNumberProvider = FutureProvider.autoDispose<int>((ref) async {
  await Future.delayed(const Duration(milliseconds: 800));
  return Random().nextInt(100);
});
