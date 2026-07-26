import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../widgets/demo_page_scaffold.dart';
import '../../../../widgets/section_card.dart';

/// 学习计划 · 基础组件 · 文本深入
///
/// 演示 Text 的样式定制、溢出处理、富文本与可选中文本。
class TextDeepDemo extends StatelessWidget {
  const TextDeepDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return const DemoPageScaffold(
      title: '文本深入',
      goal: '掌握 Text 常用样式属性、长文本溢出处理策略、TextSpan 富文本组合，以及 SelectableText 的使用场景。',
      children: [
        _StyleSection(),
        _OverflowSection(),
        _RichTextSection(),
        _SelectableSection(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 样式定制
// ---------------------------------------------------------------------------
class _StyleSection extends StatelessWidget {
  const _StyleSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: '样式定制',
      subtitle: 'color / fontWeight / letterSpacing / decoration',
      icon: Icons.palette_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '彩色 + 加粗 + 字号 20',
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '字间距 4，行高 1.8',
            style: TextStyle(letterSpacing: 4, height: 1.8),
          ),
          const SizedBox(height: 8),
          const Text(
            '下划线 + 删除线组合常见于价格展示',
            style: TextStyle(
              decoration: TextDecoration.underline,
              decorationStyle: TextDecorationStyle.wavy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '¥199.00',
            style: TextStyle(
              decoration: TextDecoration.lineThrough,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '背景色高亮文本',
            style: TextStyle(
              backgroundColor: theme.colorScheme.tertiaryContainer,
              color: theme.colorScheme.onTertiaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 溢出处理
// ---------------------------------------------------------------------------
class _OverflowSection extends StatelessWidget {
  const _OverflowSection();

  static const _longText = '这是一段很长很长的文本，用来演示 TextOverflow 的各种处理策略，看看超出显示区域后会有什么效果。';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return SectionCard(
      title: '溢出处理',
      subtitle: 'overflow + maxLines 控制长文本显示',
      icon: Icons.cut_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ellipsis（省略号）', style: labelStyle),
          const Text(_longText, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 12),
          Text('fade（渐隐）', style: labelStyle),
          const Text(_longText, maxLines: 1, overflow: TextOverflow.fade, softWrap: false),
          const SizedBox(height: 12),
          Text('maxLines: 2（两行后省略）', style: labelStyle),
          const Text(_longText, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 富文本
// ---------------------------------------------------------------------------
class _RichTextSection extends StatelessWidget {
  const _RichTextSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: '富文本组合',
      subtitle: 'Text.rich / TextSpan 嵌套与点击事件',
      icon: Icons.text_snippet_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text.rich 是 RichText 的简写形式
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: '会员价 '),
                TextSpan(
                  text: '¥99',
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const TextSpan(text: ' /年'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // WidgetSpan 可以在文本中内嵌任意组件
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: '内嵌图标 '),
                WidgetSpan(
                  child: Icon(Icons.eco, size: 18, color: theme.colorScheme.primary),
                ),
                const TextSpan(text: ' 与文本混排'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // recognizer 可为某段文字单独添加点击事件
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: '登录即表示同意'),
                TextSpan(
                  text: '《用户协议》',
                  style: TextStyle(color: theme.colorScheme.primary),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => _showSnackBar(context, '点击了用户协议'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 可选中文本
// ---------------------------------------------------------------------------
class _SelectableSection extends StatelessWidget {
  const _SelectableSection();

  @override
  Widget build(BuildContext context) {
    return const SectionCard(
      title: '可选中文本',
      subtitle: 'SelectableText 支持长按复制',
      icon: Icons.content_copy_outlined,
      child: SelectableText(
        '长按这段文字可以试试复制功能。\n适合用于订单号、邀请码等需要用户复制的场景：INVITE-2026-07-26',
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 辅助方法
// ---------------------------------------------------------------------------
void _showSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 1)));
}
