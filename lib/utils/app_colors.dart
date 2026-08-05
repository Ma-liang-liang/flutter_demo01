import 'package:flutter/material.dart';

/// 语义化颜色定义
///
/// 设计原则：
/// 1. 只定义业务语义颜色（如 success/warning/danger），不定义 UI 实现细节
/// 2. 同时提供 light 和 dark 两套，确保暗色模式开箱即用
/// 3. 命名按语义而非外观（用 `success` 不用 `green`）
/// 4. 新增颜色时只需在这里加一组 light/dark，UI 代码不用改
///
/// 使用方式：
/// ```dart
/// final colors = Theme.of(context).extension<AppColors>()!;
/// colors.success  // 亮色返回绿色，暗色自动返回适配的绿色
/// ```
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.onWarning,
    required this.danger,
    required this.onDanger,
    required this.scrim,
    required this.codeBlockBackground,
    required this.codeBlockForeground,
  });

  /// 成功状态颜色（涨/已完成/在线等）
  final Color success;
  final Color onSuccess;

  /// 警告/待处理状态
  final Color warning;
  final Color onWarning;

  /// 危险/删除/跌等
  final Color danger;
  final Color onDanger;

  /// 遮罩层颜色（弹窗背景半透明蒙层）
  final Color scrim;

  /// 代码块/日志区域背景
  final Color codeBlockBackground;

  /// 代码块/日志区域文字
  final Color codeBlockForeground;

  /// 亮色模式颜色集
  static const light = AppColors(
    success: Color(0xFF2E7D32),
    onSuccess: Color(0xFFFFFFFF),
    warning: Color(0xFFF57C00),
    onWarning: Color(0xFF000000),
    danger: Color(0xFFC62828),
    onDanger: Color(0xFFFFFFFF),
    scrim: Color(0xB3000000),
    codeBlockBackground: Color(0xFFF5F5F5),
    codeBlockForeground: Color(0xFF1A1A1A),
  );

  /// 暗色模式颜色集（后期迭代时启用，现在已就绪）
  static const dark = AppColors(
    success: Color(0xFF66BB6A),
    onSuccess: Color(0xFF003300),
    warning: Color(0xFFFFB74D),
    onWarning: Color(0xFF332200),
    danger: Color(0xFFEF5350),
    onDanger: Color(0xFF330000),
    scrim: Color(0xB3000000),
    codeBlockBackground: Color(0xFF1E1E1E),
    codeBlockForeground: Color(0xFFE0E0E0),
  );

  @override
  AppColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? warning,
    Color? onWarning,
    Color? danger,
    Color? onDanger,
    Color? scrim,
    Color? codeBlockBackground,
    Color? codeBlockForeground,
  }) {
    return AppColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      danger: danger ?? this.danger,
      onDanger: onDanger ?? this.onDanger,
      scrim: scrim ?? this.scrim,
      codeBlockBackground: codeBlockBackground ?? this.codeBlockBackground,
      codeBlockForeground: codeBlockForeground ?? this.codeBlockForeground,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      onDanger: Color.lerp(onDanger, other.onDanger, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      codeBlockBackground:
          Color.lerp(codeBlockBackground, other.codeBlockBackground, t)!,
      codeBlockForeground:
          Color.lerp(codeBlockForeground, other.codeBlockForeground, t)!,
    );
  }
}
