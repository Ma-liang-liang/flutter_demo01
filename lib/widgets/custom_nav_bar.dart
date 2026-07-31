import 'package:flutter/material.dart';

/// 通用自定义导航条
///
/// 不依赖系统 [AppBar]，完全用自定义 Widget 实现，可灵活控制样式。
/// 自动处理状态栏安全区域（[SafeArea] / [MediaQuery.paddingOf]）。
///
/// 两种使用方式：
///
/// **方式一：作为 Scaffold.appBar（推荐，Scaffold 自动处理布局）**
/// ```dart
/// Scaffold(
///   appBar: CustomNavBar(title: '页面标题'),
///   body: ...,
/// )
/// ```
///
/// **方式二：放在 body 的 Column 中（需要手动布局）**
/// ```dart
/// Scaffold(
///   body: Column(
///     children: [
///       CustomNavBar(title: '页面标题'),
///       Expanded(child: ...),
///     ],
///   ),
/// )
/// ```
class CustomNavBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomNavBar({
    super.key,
    this.title,
    this.titleWidget,
    this.leading,
    this.actions = const [],
    this.backgroundColor,
    this.foregroundColor,
    this.height = 44,
    this.bottom,
    this.centerTitle = true,
  });

  /// 创建带返回按钮的导航条（二级页面常用）
  factory CustomNavBar.withBack({
    Key? key,
    required String title,
    List<Widget> actions = const [],
    Color? backgroundColor,
    Color? foregroundColor,
    VoidCallback? onBackPressed,
  }) {
    return CustomNavBar(
      key: key,
      title: title,
      leading: _BackButton(
        onPressed: onBackPressed,
        color: foregroundColor,
      ),
      actions: actions,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
    );
  }

  /// 标题文字
  final String? title;

  /// 自定义标题 Widget（优先级高于 [title]）
  final Widget? titleWidget;

  /// 左侧 Widget（如返回按钮、菜单按钮）
  final Widget? leading;

  /// 右侧操作按钮列表
  final List<Widget> actions;

  /// 背景色（默认取 theme.colorScheme.surface）
  final Color? backgroundColor;

  /// 前景色（文字/图标颜色，默认取 theme.colorScheme.onSurface）
  final Color? foregroundColor;

  /// 导航栏内容区高度（不含状态栏），默认 44（iOS 标准）
  final double height;

  /// 底部附加 Widget（如 [TabBar]），放在导航栏下方
  final PreferredSizeWidget? bottom;

  /// 标题是否居中，默认 true
  final bool centerTitle;

  @override
  Size get preferredSize {
    final bottomHeight = bottom?.preferredSize.height ?? 0;
    return Size.fromHeight(height + bottomHeight);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topPadding = MediaQuery.paddingOf(context).top;
    final fg = foregroundColor ?? theme.colorScheme.onSurface;

    return Container(
      color: backgroundColor ?? theme.colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 状态栏安全区域
          SizedBox(height: topPadding),
          // 导航栏内容
          SizedBox(
            height: height,
            child: _buildContent(context, theme, fg),
          ),
          // 底部附加（如 TabBar）
          ?bottom,
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, ThemeData theme, Color fg) {
    final titleChild = titleWidget ??
        (title != null
            ? Text(
                title!,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              )
            : null);

    if (centerTitle) {
      // 居中布局：Stack 实现左 / 中 / 右
      return Stack(
        alignment: Alignment.center,
        children: [
          // 左侧
          Align(
            alignment: Alignment.centerLeft,
            child: leading ?? const SizedBox(width: 8),
          ),
          // 中间标题
          ?titleChild,
          // 右侧
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: actions,
            ),
          ),
        ],
      );
    }

    // 左对齐布局：Row 实现
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          ?leading,
          if (titleChild != null) ...[
            const SizedBox(width: 8),
            Expanded(child: titleChild),
          ],
          ...actions,
        ],
      ),
    );
  }
}

/// 返回按钮
class _BackButton extends StatelessWidget {
  const _BackButton({this.onPressed, this.color});

  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_ios_new, size: 20),
      color: color,
      onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
    );
  }
}
