import 'package:flutter/material.dart';

/// 业务域颜色扩展示范
///
/// 当某个功能模块颜色较多时，单独建一个 ThemeExtension，
/// 避免全部堆进 AppColors 导致命名爆炸。
///
/// 原则：
/// - AppColors 只放全局通用的语义色（success/warning/danger）
/// - 域级颜色按模块拆分，如 StockColors、ChatColors、StatusColors
/// - 每个域内颜色用域前缀命名，语义清晰不冲突
@immutable
class StockColors extends ThemeExtension<StockColors> {
  const StockColors({
    required this.up,
    required this.upContainer,
    required this.down,
    required this.downContainer,
    required this.flat,
    required this.volumeBar,
  });

  /// 上涨
  final Color up;
  final Color upContainer;

  /// 下跌
  final Color down;
  final Color downContainer;

  /// 平盘
  final Color flat;

  /// 成交量柱
  final Color volumeBar;

  static const light = StockColors(
    up: Color(0xFFE53935),
    upContainer: Color(0xFFFFEBEE),
    down: Color(0xFF43A047),
    downContainer: Color(0xFFE8F5E9),
    flat: Color(0xFF9E9E9E),
    volumeBar: Color(0xFFBDBDBD),
  );

  static const dark = StockColors(
    up: Color(0xFFEF5350),
    upContainer: Color(0xFF330000),
    down: Color(0xFF66BB6A),
    downContainer: Color(0xFF003300),
    flat: Color(0xFFBDBDBD),
    volumeBar: Color(0xFF424242),
  );

  @override
  StockColors copyWith({
    Color? up,
    Color? upContainer,
    Color? down,
    Color? downContainer,
    Color? flat,
    Color? volumeBar,
  }) {
    return StockColors(
      up: up ?? this.up,
      upContainer: upContainer ?? this.upContainer,
      down: down ?? this.down,
      downContainer: downContainer ?? this.downContainer,
      flat: flat ?? this.flat,
      volumeBar: volumeBar ?? this.volumeBar,
    );
  }

  @override
  StockColors lerp(StockColors? other, double t) {
    if (other == null) return this;
    return StockColors(
      up: Color.lerp(up, other.up, t)!,
      upContainer: Color.lerp(upContainer, other.upContainer, t)!,
      down: Color.lerp(down, other.down, t)!,
      downContainer: Color.lerp(downContainer, other.downContainer, t)!,
      flat: Color.lerp(flat, other.flat, t)!,
      volumeBar: Color.lerp(volumeBar, other.volumeBar, t)!,
    );
  }
}
