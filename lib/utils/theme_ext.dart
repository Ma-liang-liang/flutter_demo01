import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'stock_colors.dart';

/// BuildContext 主题快捷访问
///
/// 将 `Theme.of(context).colorScheme.surface` 简化为 `context.colors.surface`
///
/// 使用前：
/// ```dart
/// final theme = Theme.of(context);
/// theme.colorScheme.primary
/// theme.textTheme.bodyMedium
/// Theme.of(context).extension<AppColors>()!.success
/// ```
///
/// 使用后：
/// ```dart
/// context.colors.primary
/// context.text.bodyMedium
/// context.appColors.success
/// ```
extension BuildContextThemeX on BuildContext {
  /// ColorScheme 快捷访问
  ColorScheme get colors => Theme.of(this).colorScheme;

  /// TextTheme 快捷访问
  TextTheme get text => Theme.of(this).textTheme;

  /// AppColors 扩展颜色快捷访问
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;

  /// ThemeData 快捷访问（少数场景需要直接取 theme 时用）
  ThemeData get theme => Theme.of(this);

  /// StockColors 股票域颜色快捷访问
  StockColors get stockColors => Theme.of(this).extension<StockColors>()!;
}
