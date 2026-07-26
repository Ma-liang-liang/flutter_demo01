import 'package:flutter/material.dart';

import '../../../../widgets/demo_page_scaffold.dart';
import '../../../../widgets/section_card.dart';

/// 学习计划 · 动画交互 · 隐式动画
///
/// 演示 AnimatedContainer / AnimatedOpacity / AnimatedAlign / AnimatedDefaultTextStyle，
/// 只需切换状态值即可自动播放过渡动画。
class ImplicitAnimDemo extends StatefulWidget {
  const ImplicitAnimDemo({super.key});

  @override
  State<ImplicitAnimDemo> createState() => _ImplicitAnimDemoState();
}

class _ImplicitAnimDemoState extends State<ImplicitAnimDemo> {
  bool _expanded = false;
  bool _visible = true;
  bool _alignEnd = false;
  bool _bigText = false;

  @override
  Widget build(BuildContext context) {
    return DemoPageScaffold(
      title: '隐式动画',
      goal: '掌握 AnimatedXxx 系列隐式动画组件：只需改变属性值并 setState，Flutter 自动补全中间过渡帧，无需手动管理动画控制器。',
      children: [
        _ContainerSection(
          expanded: _expanded,
          onToggle: () => setState(() => _expanded = !_expanded),
        ),
        _OpacitySection(
          visible: _visible,
          onToggle: () => setState(() => _visible = !_visible),
        ),
        _AlignSection(
          alignEnd: _alignEnd,
          onToggle: () => setState(() => _alignEnd = !_alignEnd),
        ),
        _TextStyleSection(
          big: _bigText,
          onToggle: () => setState(() => _bigText = !_bigText),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// AnimatedContainer
// ---------------------------------------------------------------------------
class _ContainerSection extends StatelessWidget {
  const _ContainerSection({required this.expanded, required this.onToggle});

  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: 'AnimatedContainer',
      subtitle: '尺寸 / 颜色 / 圆角同时过渡',
      icon: Icons.crop_square_outlined,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            // 注意：尺寸动画要给具体数值，不能用 double.infinity
            width: expanded ? 240 : 120,
            height: expanded ? 120 : 60,
            decoration: BoxDecoration(
              color: expanded ? theme.colorScheme.tertiary : theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(expanded ? 24 : 8),
            ),
            child: Icon(
              expanded ? Icons.zoom_out_map : Icons.zoom_in_map,
              color: theme.colorScheme.onPrimary,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: onToggle, child: const Text('切换尺寸与颜色')),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AnimatedOpacity
// ---------------------------------------------------------------------------
class _OpacitySection extends StatelessWidget {
  const _OpacitySection({required this.visible, required this.onToggle});

  final bool visible;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: 'AnimatedOpacity',
      subtitle: '透明度淡入淡出',
      icon: Icons.opacity_outlined,
      child: Column(
        children: [
          AnimatedOpacity(
            duration: const Duration(milliseconds: 600),
            opacity: visible ? 1.0 : 0.2,
            child: Container(
              width: 200,
              height: 60,
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Text('我会淡入淡出'),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: onToggle, child: const Text('切换透明度')),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AnimatedAlign
// ---------------------------------------------------------------------------
class _AlignSection extends StatelessWidget {
  const _AlignSection({required this.alignEnd, required this.onToggle});

  final bool alignEnd;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: 'AnimatedAlign',
      subtitle: '对齐位置平滑移动',
      icon: Icons.align_horizontal_right_outlined,
      child: Column(
        children: [
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOutBack,
              alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: CircleAvatar(
                  backgroundColor: theme.colorScheme.primary,
                  child: Icon(Icons.rocket_launch, color: theme.colorScheme.onPrimary, size: 20),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: onToggle, child: const Text('移动位置')),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AnimatedDefaultTextStyle
// ---------------------------------------------------------------------------
class _TextStyleSection extends StatelessWidget {
  const _TextStyleSection({required this.big, required this.onToggle});

  final bool big;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: 'AnimatedDefaultTextStyle',
      subtitle: '文字大小颜色渐变切换',
      icon: Icons.format_size_outlined,
      child: Column(
        children: [
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 400),
            style: big
                ? theme.textTheme.headlineSmall!.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  )
                : theme.textTheme.bodyMedium!,
            child: const Text('观察我的样式渐变'),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: onToggle, child: const Text('切换文字样式')),
        ],
      ),
    );
  }
}
