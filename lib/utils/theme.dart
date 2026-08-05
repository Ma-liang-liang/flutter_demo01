import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 应用主题配置
///
/// 架构说明：
/// - [AppColors] 通过 [ThemeExtension] 注入，提供 ColorScheme 之外的语义颜色
/// - 新增暗色模式时只需在 [AppColors.dark] 中调整色值，UI 代码无需改动
/// - 所有 Widget 应通过 `Theme.of(context)` 取色，禁止硬编码 Colors.xxx
class AppTheme {
  AppTheme._();

  /// 主色调
  static const Color primaryColor = Color(0xFF6750A4);

  /// 亮色主题
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
    );
    return _buildTheme(colorScheme, AppColors.light);
  }

  /// 暗色主题
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
    );
    return _buildTheme(colorScheme, AppColors.dark);
  }

  static ThemeData _buildTheme(ColorScheme colorScheme, AppColors appColors) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      extensions: [appColors],
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
    );
  }
}
