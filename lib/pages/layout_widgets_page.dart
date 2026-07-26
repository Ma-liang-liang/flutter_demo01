import 'package:flutter/material.dart';

import '../data/learning_plan_data.dart';
import '../widgets/learning_entry_card.dart';
import '../widgets/section_card.dart';

/// Tab3: 布局组件展示页面
///
/// 展示常用的布局组件：Row、Column、Stack、GridView、ListView、
/// Wrap、Expanded、Align 等。
class LayoutWidgetsPage extends StatelessWidget {
  const LayoutWidgetsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        // 学习计划入口：点击进入本分类的章节列表（二级页面）
        LearningEntryCard(chapter: LearningPlanData.layoutChapter),
        _RowColumnSection(),
        _StackSection(),
        _GridViewSection(),
        _WrapSection(),
        _ExpandedFlexSection(),
        _ListSection(),
        _ConstraintsSection(),
        _TableSection(),
        _IndexedStackSection(),
        _SliversSection(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Row / Column 区域
// ---------------------------------------------------------------------------
class _RowColumnSection extends StatelessWidget {
  const _RowColumnSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: 'Row / Column',
      subtitle: '水平 & 垂直排列',
      icon: Icons.view_column,
      child: Column(
        children: [
          const Text('Row (水平排列)'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(4, (i) => _colorBox(theme, i)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Column (垂直排列)'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: List.generate(
                      3,
                      (i) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _wideBar(theme, i),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _colorBox(ThemeData theme, int index) {
    final colors = [
      theme.colorScheme.primary,
      theme.colorScheme.secondary,
      theme.colorScheme.tertiary,
      theme.colorScheme.error,
    ];
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: colors[index],
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget _wideBar(ThemeData theme, int index) {
    final colors = [
      theme.colorScheme.primary,
      theme.colorScheme.secondary,
      theme.colorScheme.tertiary,
    ];
    return Container(
      height: 24,
      decoration: BoxDecoration(
        color: colors[index].withValues(alpha: 0.3 + index * 0.2),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stack 区域
// ---------------------------------------------------------------------------
class _StackSection extends StatelessWidget {
  const _StackSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: 'Stack',
      subtitle: '层叠布局 / Positioned',
      icon: Icons.layers,
      child: SizedBox(
        height: 160,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '左上角',
                  style: TextStyle(color: theme.colorScheme.onPrimary),
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '右下角',
                  style: TextStyle(color: theme.colorScheme.onTertiary),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: CircleAvatar(
                backgroundColor: theme.colorScheme.error,
                radius: 16,
                child: const Text(
                  '3',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
            Center(
              child: Icon(
                Icons.image,
                size: 64,
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// GridView 区域
// ---------------------------------------------------------------------------
class _GridViewSection extends StatelessWidget {
  const _GridViewSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: 'GridView',
      subtitle: '网格布局 (3列)',
      icon: Icons.grid_view,
      child: SizedBox(
        height: 280,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: 9,
          itemBuilder: (context, index) {
            return Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Wrap 区域
// ---------------------------------------------------------------------------
class _WrapSection extends StatelessWidget {
  const _WrapSection();

  @override
  Widget build(BuildContext context) {
    final tags = [
      'Flutter',
      'Dart',
      'Material 3',
      'iOS',
      'Android',
      'Web',
      '桌面端',
      '响应式',
      '跨平台',
      '开源',
    ];
    return SectionCard(
      title: 'Wrap',
      subtitle: '自动换行布局',
      icon: Icons.wrap_text,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: tags
            .map(
              (tag) => Chip(
                label: Text(tag),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            )
            .toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Expanded / Flex 区域
// ---------------------------------------------------------------------------
class _ExpandedFlexSection extends StatelessWidget {
  const _ExpandedFlexSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: 'Expanded / Flex',
      subtitle: '弹性分配空间',
      icon: Icons.space_bar,
      child: Column(
        children: [
          const Text('flex: 1 : 2 : 1'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: _flexBox(theme, theme.colorScheme.primary, '1'),
              ),
              const SizedBox(width: 4),
              Expanded(
                flex: 2,
                child: _flexBox(theme, theme.colorScheme.secondary, '2'),
              ),
              const SizedBox(width: 4),
              Expanded(
                flex: 1,
                child: _flexBox(theme, theme.colorScheme.tertiary, '1'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('固定宽度 + Expanded'),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 60,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '固定',
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      'Expanded 填充剩余',
                      style: TextStyle(color: theme.colorScheme.primary),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _flexBox(ThemeData theme, Color color, String label) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Center(
        child: Text('flex $label', style: TextStyle(color: color)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ListView 区域
// ---------------------------------------------------------------------------
class _ListSection extends StatelessWidget {
  const _ListSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: 'ListView',
      subtitle: '列表 / ListTile',
      icon: Icons.list,
      child: SizedBox(
        height: 200,
        child: ListView.separated(
          itemCount: 6,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            const icons = [
              Icons.flight,
              Icons.restaurant,
              Icons.hotel,
              Icons.local_cafe,
              Icons.shopping_bag,
              Icons.movie,
            ];
            const titles = ['机票', '餐饮', '酒店', '咖啡', '购物', '电影'];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(
                  icons[index],
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ),
              title: Text(titles[index]),
              subtitle: Text('这是第 ${index + 1} 个列表项'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 约束与尺寸区域
// ---------------------------------------------------------------------------

/// 演示常用的尺寸约束组件：
/// - ConstrainedBox: 给子组件添加最大/最小宽高约束
/// - AspectRatio: 强制子组件保持固定宽高比
/// - FractionallySizedBox: 按父容器的比例设置尺寸
class _ConstraintsSection extends StatelessWidget {
  const _ConstraintsSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: '约束与尺寸',
      subtitle: 'ConstrainedBox / AspectRatio / FractionallySizedBox',
      icon: Icons.aspect_ratio,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ConstrainedBox (maxWidth: 200)'),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '这段文字很长，但被 ConstrainedBox 限制在 200 宽度内，超出会自动换行。',
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('AspectRatio (16:9)'),
          const SizedBox(height: 8),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  '16 : 9',
                  style: TextStyle(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('FractionallySizedBox (宽度 70%)'),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: FractionallySizedBox(
              widthFactor: 0.7,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '70%',
                    style: TextStyle(
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Table 区域
// ---------------------------------------------------------------------------

/// 演示 Table 表格布局：
/// - border 设置表格边框
/// - columnWidths 控制各列宽度比例
class _TableSection extends StatelessWidget {
  const _TableSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: 'Table',
      subtitle: '表格布局',
      icon: Icons.table_chart,
      child: Table(
        border: TableBorder.all(
          color: theme.colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FlexColumnWidth(3),
          2: FlexColumnWidth(2),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
            ),
            children: [
              _tableCell('组件', theme, bold: true),
              _tableCell('用途', theme, bold: true),
              _tableCell('难度', theme, bold: true),
            ],
          ),
          TableRow(
            children: [
              _tableCell('Row', theme),
              _tableCell('水平排列', theme),
              _tableCell('⭐', theme),
            ],
          ),
          TableRow(
            children: [
              _tableCell('Stack', theme),
              _tableCell('层叠布局', theme),
              _tableCell('⭐⭐', theme),
            ],
          ),
          TableRow(
            children: [
              _tableCell('Slivers', theme),
              _tableCell('高级滚动', theme),
              _tableCell('⭐⭐⭐', theme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tableCell(String text, ThemeData theme, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// IndexedStack 区域
// ---------------------------------------------------------------------------

/// 演示 IndexedStack：
/// - 与 Stack 类似，但同一时间只显示 index 对应的子组件
/// - 切换时保持其他子组件的状态（不会重建）
class _IndexedStackSection extends StatefulWidget {
  const _IndexedStackSection();

  @override
  State<_IndexedStackSection> createState() => _IndexedStackSectionState();
}

class _IndexedStackSectionState extends State<_IndexedStackSection> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: 'IndexedStack',
      subtitle: '按索引切换显示 / 保持状态',
      icon: Icons.tab,
      child: Column(
        children: [
          Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IndexedStack(
              index: _index,
              children: [
                Center(
                  child: Icon(
                    Icons.home,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Center(
                  child: Icon(
                    Icons.favorite,
                    size: 48,
                    color: theme.colorScheme.error,
                  ),
                ),
                Center(
                  child: Icon(
                    Icons.settings,
                    size: 48,
                    color: theme.colorScheme.tertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                icon: Icon(Icons.home),
                label: Text('首页'),
              ),
              ButtonSegment(
                value: 1,
                icon: Icon(Icons.favorite),
                label: Text('喜欢'),
              ),
              ButtonSegment(
                value: 2,
                icon: Icon(Icons.settings),
                label: Text('设置'),
              ),
            ],
            selected: {_index},
            onSelectionChanged: (set) => setState(() => _index = set.first),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CustomScrollView + Slivers 区域
// ---------------------------------------------------------------------------

/// 演示 CustomScrollView 与 Sliver 家族：
/// - SliverAppBar: 可折叠的头部（pinned 固定 / expandedHeight 展开高度）
/// - SliverList: 懒加载列表
/// - SliverGrid: 懒加载网格
/// 注意: Sliver 组件只能放在 CustomScrollView 中，不能直接放在普通布局里
class _SliversSection extends StatelessWidget {
  const _SliversSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: 'CustomScrollView + Slivers',
      subtitle: 'SliverAppBar / SliverList / SliverGrid',
      icon: Icons.view_day,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 320,
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 100,
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                flexibleSpace: FlexibleSpaceBar(
                  title: const Text('SliverAppBar'),
                  background: Container(
                    color: theme.colorScheme.primaryContainer,
                    child: Center(
                      child: Icon(
                        Icons.wb_sunny,
                        size: 40,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => ListTile(
                    dense: true,
                    leading: Text(
                      '${index + 1}',
                      style: TextStyle(color: theme.colorScheme.primary),
                    ),
                    title: Text('SliverList 第 ${index + 1} 行'),
                  ),
                  childCount: 4,
                ),
              ),
              SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(child: Text('G${index + 1}')),
                  ),
                  childCount: 6,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
