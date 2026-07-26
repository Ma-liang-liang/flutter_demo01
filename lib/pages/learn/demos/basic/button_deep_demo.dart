import 'package:flutter/material.dart';

import '../../../../widgets/demo_page_scaffold.dart';
import '../../../../widgets/section_card.dart';

/// 学习计划 · 基础组件 · 按钮深入
///
/// 演示按钮样式定制、禁用与加载状态、SegmentedButton / ToggleButtons 按钮组。
class ButtonDeepDemo extends StatefulWidget {
  const ButtonDeepDemo({super.key});

  @override
  State<ButtonDeepDemo> createState() => _ButtonDeepDemoState();
}

class _ButtonDeepDemoState extends State<ButtonDeepDemo> {
  bool _loading = false;
  int _segment = 0;
  final List<bool> _toggles = [true, false, false];

  /// 模拟异步操作，展示按钮加载态
  Future<void> _mockSubmit() async {
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _loading = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('提交成功'), duration: Duration(seconds: 1)));
  }

  @override
  Widget build(BuildContext context) {
    return DemoPageScaffold(
      title: '按钮深入',
      goal: '学会用 styleFrom 定制按钮外观，处理禁用与加载状态，掌握 SegmentedButton 与 ToggleButtons 两种按钮组的用法。',
      children: [
        const _StyleSection(),
        _StateSection(loading: _loading, onSubmit: _mockSubmit),
        _GroupSection(
          segment: _segment,
          toggles: _toggles,
          onSegmentChanged: (v) => setState(() => _segment = v),
          onToggle: (i) => setState(() => _toggles[i] = !_toggles[i]),
        ),
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
      subtitle: 'styleFrom 定制颜色、圆角、尺寸',
      icon: Icons.format_paint_outlined,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          // 大圆角胶囊按钮
          FilledButton(
            onPressed: () {},
            style: FilledButton.styleFrom(
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            child: const Text('胶囊按钮'),
          ),
          // 自定义配色
          FilledButton(
            onPressed: () {},
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.tertiary,
              foregroundColor: theme.colorScheme.onTertiary,
            ),
            child: const Text('自定义配色'),
          ),
          // 固定尺寸
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(140, 48),
              side: BorderSide(color: theme.colorScheme.primary, width: 2),
            ),
            child: const Text('固定尺寸'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 状态变化
// ---------------------------------------------------------------------------
class _StateSection extends StatelessWidget {
  const _StateSection({required this.loading, required this.onSubmit});

  final bool loading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '禁用与加载状态',
      subtitle: 'onPressed 为 null 即禁用；加载中替换 child',
      icon: Icons.hourglass_top_outlined,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const FilledButton(onPressed: null, child: Text('禁用状态')),
          FilledButton.icon(
            // 加载中再次禁用，防止重复提交
            onPressed: loading ? null : onSubmit,
            icon: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: Text(loading ? '提交中...' : '模拟提交'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 按钮组
// ---------------------------------------------------------------------------
class _GroupSection extends StatelessWidget {
  const _GroupSection({
    required this.segment,
    required this.toggles,
    required this.onSegmentChanged,
    required this.onToggle,
  });

  final int segment;
  final List<bool> toggles;
  final ValueChanged<int> onSegmentChanged;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '按钮组',
      subtitle: 'SegmentedButton 单选 / ToggleButtons 多状态',
      icon: Icons.view_column_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Material 3 推荐的单选按钮组
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('列表'), icon: Icon(Icons.list)),
              ButtonSegment(value: 1, label: Text('网格'), icon: Icon(Icons.grid_view)),
              ButtonSegment(value: 2, label: Text('卡片'), icon: Icon(Icons.view_agenda)),
            ],
            selected: {segment},
            onSelectionChanged: (values) => onSegmentChanged(values.first),
          ),
          const SizedBox(height: 16),
          // 经典的多开关按钮组
          ToggleButtons(
            isSelected: toggles,
            onPressed: onToggle,
            borderRadius: BorderRadius.circular(8),
            children: const [
              Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Icon(Icons.format_bold)),
              Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Icon(Icons.format_italic)),
              Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Icon(Icons.format_underline)),
            ],
          ),
        ],
      ),
    );
  }
}
