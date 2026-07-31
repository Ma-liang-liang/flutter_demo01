import 'package:flutter/material.dart';

import '../widgets/custom_nav_bar.dart';
import '../widgets/section_card.dart';

/// 自定义导航条演示页面
///
/// 展示 [CustomNavBar] 的多种用法：带返回按钮、自定义颜色、
/// 左对齐标题、右侧操作按钮等。
class NavBarDemoPage extends StatelessWidget {
  const NavBarDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      // ── 使用 CustomNavBar 替代系统 AppBar ──
      appBar: CustomNavBar.withBack(
        title: '自定义导航条演示',
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _showSnackBar(context, '点击了分享'),
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () => _showSnackBar(context, '点击了更多'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 说明卡片
          SectionCard(
            title: '什么是自定义导航条',
            subtitle: '不依赖系统 AppBar，完全用 Widget 实现',
            icon: Icons.info_outline,
            child: Text(
              'CustomNavBar 是一个通用的导航条组件，自动处理状态栏安全区域，'
              '支持自定义标题、返回按钮、右侧操作按钮、背景色等。\n\n'
              '相比系统 AppBar，它可以完全控制样式和布局，适合需要'
              '高度定制导航栏的场景。',
              style: theme.textTheme.bodyMedium,
            ),
          ),

          // 基础用法
          SectionCard(
            title: '基础用法',
            subtitle: '标题 + 返回按钮 + 右侧操作',
            icon: Icons.navigation,
            child: _CodeBlock(
              code: 'CustomNavBar.withBack(\n'
                  '  title: \'页面标题\',\n'
                  '  actions: [\n'
                  '    IconButton(icon: Icon(Icons.share), ...),\n'
                  '  ],\n'
                  ')',
            ),
          ),

          // 深色背景演示入口
          SectionCard(
            title: '深色背景导航条',
            subtitle: '自定义背景色 + 前景色',
            icon: Icons.dark_mode,
            child: FilledButton.icon(
              onPressed: () => _pushColoredNavBar(context),
              icon: const Icon(Icons.palette),
              label: const Text('查看深色背景效果'),
            ),
          ),

          // 左对齐标题演示入口
          SectionCard(
            title: '左对齐标题',
            subtitle: 'Android 风格，标题靠左',
            icon: Icons.align_horizontal_left,
            child: OutlinedButton.icon(
              onPressed: () => _pushLeftAlignNavBar(context),
              icon: const Icon(Icons.format_align_left),
              label: const Text('查看左对齐效果'),
            ),
          ),

          // 自定义标题 Widget 演示入口
          SectionCard(
            title: '自定义标题 Widget',
            subtitle: '标题位置放任意 Widget',
            icon: Icons.widgets,
            child: OutlinedButton.icon(
              onPressed: () => _pushCustomTitleNavBar(context),
              icon: const Icon(Icons.title),
              label: const Text('查看自定义标题效果'),
            ),
          ),

          // API 参数说明
          SectionCard(
            title: '常用参数',
            subtitle: 'CustomNavBar 构造参数',
            icon: Icons.list_alt,
            child: _ParamTable(),
          ),
        ],
      ),
    );
  }

  /// 跳转到深色背景导航条页面
  void _pushColoredNavBar(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ColoredNavBarPage(),
      ),
    );
  }

  /// 跳转到左对齐标题导航条页面
  void _pushLeftAlignNavBar(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _LeftAlignNavBarPage(),
      ),
    );
  }

  /// 跳转到自定义标题导航条页面
  void _pushCustomTitleNavBar(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _CustomTitleNavBarPage(),
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
      );
  }
}

// ---------------------------------------------------------------------------
// 深色背景导航条
// ---------------------------------------------------------------------------
class _ColoredNavBarPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomNavBar.withBack(
        title: '深色导航条',
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '这个导航条使用了自定义背景色和前景色\n'
            'backgroundColor + foregroundColor',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 左对齐标题导航条
// ---------------------------------------------------------------------------
class _LeftAlignNavBarPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomNavBar(
        title: '左对齐标题',
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
        ],
      ),
      body: const Center(
        child: Text('标题靠左显示（Android 风格）'),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 自定义标题 Widget 导航条
// ---------------------------------------------------------------------------
class _CustomTitleNavBarPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: CustomNavBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        // 用自定义 Widget 代替纯文字标题
        titleWidget: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              '自定义标题',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {},
          ),
        ],
      ),
      body: const Center(
        child: Text('标题位置可以放任意 Widget（图标+文字、搜索框等）'),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 代码块展示
// ---------------------------------------------------------------------------
class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        code,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 参数说明表格
// ---------------------------------------------------------------------------
class _ParamTable extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const params = [
      ('title', '标题文字'),
      ('titleWidget', '自定义标题 Widget（优先级高于 title）'),
      ('leading', '左侧 Widget（返回按钮、菜单等）'),
      ('actions', '右侧操作按钮列表'),
      ('backgroundColor', '背景色'),
      ('foregroundColor', '前景色（文字/图标）'),
      ('height', '导航栏高度，默认 44'),
      ('centerTitle', '标题是否居中，默认 true'),
      ('bottom', '底部附加 Widget（如 TabBar）'),
    ];

    final theme = Theme.of(context);
    return Table(
      border: TableBorder.all(
        color: theme.colorScheme.outlineVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(3),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
          ),
          children: [
            _cell('参数', theme, bold: true),
            _cell('说明', theme, bold: true),
          ],
        ),
        for (final (name, desc) in params)
          TableRow(
            children: [
              _cell(name, theme),
              _cell(desc, theme),
            ],
          ),
      ],
    );
  }

  Widget _cell(String text, ThemeData theme, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: text.contains('backgroundColor') || bold
              ? null
              : 'monospace',
          fontSize: 13,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
