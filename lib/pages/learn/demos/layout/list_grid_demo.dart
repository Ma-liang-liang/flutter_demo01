import 'package:flutter/material.dart';

import '../../../../widgets/demo_page_scaffold.dart';
import '../../../../widgets/section_card.dart';

/// 学习计划 · 布局组件 · 列表与网格
///
/// 演示 ListView.builder / separated、水平列表与 GridView 两种构造方式。
class ListGridDemo extends StatelessWidget {
  const ListGridDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return const DemoPageScaffold(
      title: '列表与网格',
      goal: '掌握 ListView.builder 懒加载长列表、ListView.separated 分隔列表、水平滚动列表，以及 GridView.count / extent 两种网格构造的区别。',
      children: [
        _BuilderSection(),
        _SeparatedSection(),
        _HorizontalSection(),
        _GridSection(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// ListView.builder 懒加载
// ---------------------------------------------------------------------------
class _BuilderSection extends StatelessWidget {
  const _BuilderSection();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'ListView.builder 懒加载',
      subtitle: '只构建可见项，适合成百上千条数据',
      icon: Icons.format_list_bulleted_outlined,
      child: SizedBox(
        height: 180,
        child: ListView.builder(
          itemCount: 100,
          itemBuilder: (context, index) => ListTile(
            dense: true,
            leading: CircleAvatar(child: Text('${index + 1}')),
            title: Text('消息标题 ${index + 1}'),
            subtitle: const Text('builder 按需创建，滚动到哪里构建到哪里'),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ListView.separated 分隔列表
// ---------------------------------------------------------------------------
class _SeparatedSection extends StatelessWidget {
  const _SeparatedSection();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'ListView.separated 分隔列表',
      subtitle: 'separatorBuilder 自定义分隔组件',
      icon: Icons.splitscreen_outlined,
      child: SizedBox(
        height: 160,
        child: ListView.separated(
          itemCount: 8,
          itemBuilder: (context, index) => ListTile(
            dense: true,
            leading: const Icon(Icons.settings_outlined),
            title: Text('设置项 ${index + 1}'),
            trailing: const Icon(Icons.chevron_right),
          ),
          // 分隔线可自定义为 Divider、SizedBox 或任意组件
          separatorBuilder: (context, index) => const Divider(height: 1, indent: 56),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 水平列表
// ---------------------------------------------------------------------------
class _HorizontalSection extends StatelessWidget {
  const _HorizontalSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: '水平滚动列表',
      subtitle: 'scrollDirection: Axis.horizontal，常见于横幅卡片',
      icon: Icons.view_carousel_outlined,
      child: SizedBox(
        height: 110,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: 10,
          itemBuilder: (context, index) => Container(
            width: 140,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primaryContainer,
                  theme.colorScheme.tertiaryContainer,
                ],
              ),
            ),
            child: Center(
              child: Text('卡片 ${index + 1}', style: theme.textTheme.titleMedium),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// GridView 两种构造
// ---------------------------------------------------------------------------
class _GridSection extends StatelessWidget {
  const _GridSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: 'GridView 网格',
      subtitle: 'count 固定列数 / extent 按最大宽度自适应列数',
      icon: Icons.grid_on_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('GridView.count（固定 3 列）',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          SizedBox(
            height: 150,
            child: GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var i = 1; i <= 6; i++)
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text('$i'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text('GridView.extent（每项最大 100，列数随屏宽变化）',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          SizedBox(
            height: 150,
            child: GridView.extent(
              maxCrossAxisExtent: 100,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var i = 1; i <= 8; i++)
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text('$i'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
