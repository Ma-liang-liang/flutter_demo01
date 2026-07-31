import 'package:flutter/material.dart';

import '../data/learning_plan_data.dart';
import '../router/app_navigator.dart';
import '../widgets/learning_entry_card.dart';
import '../widgets/section_card.dart';

/// Tab1: 基础组件展示页面
///
/// 展示常用的基础 UI 组件：按钮、文本样式、图标、卡片、Chip 等。
class BasicWidgetsPage extends StatelessWidget {
  const BasicWidgetsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        // 学习计划入口：点击进入本分类的章节列表（二级页面）
        LearningEntryCard(chapter: LearningPlanData.basicChapter),
        _ButtonsSection(),
        _TextSection(),
        _IconsSection(),
        _ChipsSection(),
        _CardsSection(),
        _CustomNavBarSection(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 按钮区域
// ---------------------------------------------------------------------------
class _ButtonsSection extends StatelessWidget {
  const _ButtonsSection();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '按钮',
      subtitle: 'Filled / Outlined / Text / IconButton / FAB',
      icon: Icons.smart_button,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          FilledButton(
            onPressed: () => _showSnackBar(context, 'FilledButton 点击'),
            child: const Text('Filled'),
          ),
          FilledButton.tonal(
            onPressed: () => _showSnackBar(context, 'TonalButton 点击'),
            child: const Text('Tonal'),
          ),
          OutlinedButton(
            onPressed: () => _showSnackBar(context, 'OutlinedButton 点击'),
            child: const Text('Outlined'),
          ),
          TextButton(
            onPressed: () => _showSnackBar(context, 'TextButton 点击'),
            child: const Text('Text'),
          ),
          ElevatedButton(
            onPressed: () => _showSnackBar(context, 'ElevatedButton 点击'),
            child: const Text('Elevated'),
          ),
          IconButton.filled(
            onPressed: () => _showSnackBar(context, 'IconButton 点击'),
            icon: const Icon(Icons.thumb_up),
          ),
          IconButton.outlined(
            onPressed: () => _showSnackBar(context, 'Outlined IconButton 点击'),
            icon: const Icon(Icons.favorite),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 文本区域
// ---------------------------------------------------------------------------
class _TextSection extends StatelessWidget {
  const _TextSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: '文本样式',
      subtitle: '不同字体大小 / Google Fonts',
      icon: Icons.text_fields,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Display Large', style: theme.textTheme.displaySmall),
          Text('Headline Medium', style: theme.textTheme.headlineMedium),
          Text('Title Large', style: theme.textTheme.titleLarge),
          Text('Body Medium — 这是一段正文文本，用于展示默认正文字体样式。'),
          Text(
            'Google Fonts (Pacifico)',
            style: TextStyle(
              fontSize: 24,
              fontFamily: 'serif',
              fontStyle: FontStyle.italic,
            ),
          ),
          Text(
            'Google Fonts (RobotoMono)',
            style: TextStyle(
              fontSize: 16,
              fontFamily: 'monospace',
            ),
          ),
          RichText(
            text: TextSpan(
              style: theme.textTheme.bodyMedium,
              children: [
                const TextSpan(text: 'RichText 支持 '),
                TextSpan(
                  text: '粗体',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: '、'),
                TextSpan(
                  text: '彩色',
                  style: TextStyle(color: theme.colorScheme.primary),
                ),
                const TextSpan(text: '、'),
                TextSpan(
                  text: '斜体',
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
                const TextSpan(text: ' 等混合样式。'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 图标区域
// ---------------------------------------------------------------------------
class _IconsSection extends StatelessWidget {
  const _IconsSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const icons = [
      Icons.home, Icons.search, Icons.person, Icons.settings,
      Icons.notifications, Icons.email, Icons.favorite, Icons.star,
      Icons.bookmark, Icons.share, Icons.camera, Icons.music_note,
    ];

    return SectionCard(
      title: '图标',
      subtitle: 'Material Icons 网格',
      icon: Icons.grid_view,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: icons.length,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icons[index], color: theme.colorScheme.primary),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chip 区域
// ---------------------------------------------------------------------------
class _ChipsSection extends StatelessWidget {
  const _ChipsSection();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Chip 组件',
      subtitle: 'Chip / ActionChip / FilterChip',
      icon: Icons.label,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          const Chip(label: Text('Chip'), avatar: Icon(Icons.person)),
          ActionChip(
            label: const Text('ActionChip'),
            avatar: const Icon(Icons.play_arrow),
            onPressed: () => _showSnackBar(context, 'ActionChip 点击'),
          ),
          FilterChip(
            label: const Text('FilterChip'),
            selected: true,
            onSelected: (v) => _showSnackBar(context, 'FilterChip: $v'),
          ),
          InputChip(
            label: const Text('InputChip'),
            avatar: const Icon(Icons.account_circle),
            onDeleted: () => _showSnackBar(context, 'InputChip 删除'),
          ),
          const Chip(
            label: Text('删除样式'),
            deleteIcon: Icon(Icons.cancel),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 卡片区域
// ---------------------------------------------------------------------------
class _CardsSection extends StatelessWidget {
  const _CardsSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: '卡片',
      subtitle: 'Card + ListTile 组合',
      icon: Icons.credit_card,
      child: Column(
        children: [
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(Icons.person, color: theme.colorScheme.primary),
              ),
              title: const Text('用户名称'),
              subtitle: const Text('user@example.com'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showSnackBar(context, '点击用户卡片'),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('位置卡片',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '这是一段卡片内容描述文本，展示 Card 内部使用 Padding + Column 排列内容的方式。',
                  ),
                ],
              ),
            ),
          ),
        ],
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

// ---------------------------------------------------------------------------
// 自定义导航条演示入口
// ---------------------------------------------------------------------------
class _CustomNavBarSection extends StatelessWidget {
  const _CustomNavBarSection();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '自定义导航条',
      subtitle: '不依赖系统 AppBar / 完全自定义',
      icon: Icons.navigation,
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () => AppNavigator.toNavBarDemo(context),
              icon: const Icon(Icons.open_in_new),
              label: const Text('查看导航条演示'),
            ),
          ),
        ],
      ),
    );
  }
}

