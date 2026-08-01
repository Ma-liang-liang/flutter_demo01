import 'package:flutter_riverpod/flutter_riverpod.dart';

// ===========================================================================
// StateProvider —— 简单可变状态
//
// StateProvider 是 Provider 的可变版本，适合管理简单的独立状态：
//   - 计数器
//   - 开关 / 勾选
//   - 当前选中的索引 / 选项
//
// 与 Provider 不同，StateProvider 暴露的值可以通过 ref.read.notifier
// 获取并修改，无需自定义 Notifier 类。
//
// 适用场景：状态逻辑简单（仅赋值 / 自增），不需要复杂业务方法。
// ===========================================================================

/// 计数器 StateProvider
///
/// 读取：ref.watch(counterProvider) → int
/// 修改：ref.read(counterProvider.notifier).state++ / state = 0
final counterProvider = StateProvider<int>((ref) {
  return 0;
});

/// 主题模式 StateProvider：light / dark / system
///
/// 用 String 而非枚举是为了演示简单，实际项目建议用枚举。
final themeModeProvider = StateProvider<String>((ref) {
  return 'light';
});

/// 字号缩放 StateProvider
final fontScaleProvider = StateProvider<double>((ref) {
  return 1.0;
});

/// 当前选中颜色索引 StateProvider
final selectedColorIndexProvider = StateProvider<int>((ref) {
  return 0;
});
