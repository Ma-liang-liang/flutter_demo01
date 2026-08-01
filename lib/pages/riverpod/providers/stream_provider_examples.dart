import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

// ===========================================================================
// StreamProvider —— 流式数据
//
// StreamProvider 用于包装一个 Stream，与 FutureProvider 类似但适用于：
//   - 实时数据推送（WebSocket / SSE）
//   - 定时器 / 倒计时
//   - 数据库变化监听
//   - Firebase / Supabase 实时订阅
//
// 返回 AsyncValue<T>，同样支持 loading / data / error 三态。
// ===========================================================================

/// 定时器 StreamProvider：每秒发出一个递增的计数值
///
/// ref.watch(timerStreamProvider) → `AsyncValue<int>`
/// 离开页面后 stream 自动取消订阅（autoDispose）。
final timerStreamProvider = StreamProvider.autoDispose<int>((ref) async* {
  int count = 0;
  // async* 生成器：每秒 yield 一个值
  while (true) {
    await Future.delayed(const Duration(seconds: 1));
    count++;
    yield count;
  }
});

/// 倒计时 StreamProvider：从 10 倒数到 0
///
/// 使用 Stream.periodic 创建固定次数的流。
final countdownStreamProvider = StreamProvider.autoDispose<int>((ref) {
  return Stream.periodic(
    const Duration(seconds: 1),
    (elapsed) => 10 - elapsed,
  ).take(11); // 10 → 0，共 11 次
});

/// 模拟实时股票价格流
class StockPrice {
  const StockPrice({required this.symbol, required this.price, required this.change});

  final String symbol;
  final double price;
  final double change; // 涨跌幅
}

final stockPriceProvider = StreamProvider.autoDispose<StockPrice>((ref) async* {
  double price = 100.0;
  final random = _SimpleRandom();

  while (true) {
    await Future.delayed(const Duration(milliseconds: 800));
    // 随机波动 -3 ~ +3
    final delta = (random.nextDouble() * 6 - 3);
    price = (price + delta).clamp(50.0, 200.0);
    yield StockPrice(
      symbol: 'FLTR',
      price: price,
      change: delta,
    );
  }
});

/// 简易随机数生成器（避免每次创建 Random 实例）
class _SimpleRandom {
  int _seed = DateTime.now().millisecondsSinceEpoch;
  double nextDouble() {
    _seed = (_seed * 1103515245 + 12345) & 0x7fffffff;
    return _seed / 0x7fffffff;
  }
}
