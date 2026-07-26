import 'package:flutter/material.dart';

import '../../../../widgets/demo_page_scaffold.dart';
import '../../../../widgets/section_card.dart';

/// 学习计划 · 动画交互 · 显式动画
///
/// 演示 AnimationController 的手动控制、RotationTransition / ScaleTransition，
/// 以及用 AnimatedBuilder 组合多个动画效果。
class ExplicitAnimDemo extends StatefulWidget {
  const ExplicitAnimDemo({super.key});

  @override
  State<ExplicitAnimDemo> createState() => _ExplicitAnimDemoState();
}

// SingleTickerProviderStateMixin 为 AnimationController 提供 vsync 时钟
class _ExplicitAnimDemoState extends State<ExplicitAnimDemo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    // CurvedAnimation 为缩放添加弹性曲线
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    // 控制器必须释放，否则造成内存泄漏
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DemoPageScaffold(
      title: '显式动画',
      goal: '掌握 AnimationController 的播放 / 反转 / 循环 / 停止控制，学会用 CurvedAnimation 添加缓动曲线，以及用 AnimatedBuilder 高效组合多个动画。',
      children: [
        _RotateSection(controller: _controller),
        _ScaleSection(animation: _scaleAnimation),
        _CombinedSection(controller: _controller),
        _ControlSection(controller: _controller),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// RotationTransition 旋转
// ---------------------------------------------------------------------------
class _RotateSection extends StatelessWidget {
  const _RotateSection({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: 'RotationTransition 旋转',
      subtitle: '控制器数值 0~1 映射为 0~1 整圈',
      icon: Icons.rotate_right_outlined,
      child: Center(
        child: RotationTransition(
          turns: controller,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.settings, size: 40, color: theme.colorScheme.primary),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ScaleTransition 弹性缩放
// ---------------------------------------------------------------------------
class _ScaleSection extends StatelessWidget {
  const _ScaleSection({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: 'ScaleTransition 弹性缩放',
      subtitle: 'Curves.elasticOut 带回弹效果',
      icon: Icons.zoom_in_outlined,
      child: Center(
        child: ScaleTransition(
          scale: animation,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.favorite, size: 40, color: theme.colorScheme.tertiary),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AnimatedBuilder 组合动画
// ---------------------------------------------------------------------------
class _CombinedSection extends StatelessWidget {
  const _CombinedSection({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: 'AnimatedBuilder 组合动画',
      subtitle: '旋转 + 缩放 + 位移 一次驱动',
      icon: Icons.auto_awesome_outlined,
      child: SizedBox(
        height: 100,
        child: Center(
          // AnimatedBuilder 只在动画值变化时重建 builder 内部，性能更好
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, child) {
              final value = controller.value;
              return Transform.translate(
                offset: Offset(0, -30 * value),
                child: Transform.rotate(
                  angle: value * 2 * 3.14159,
                  child: Transform.scale(
                    scale: 0.5 + value * 0.8,
                    child: child,
                  ),
                ),
              );
            },
            // 不随动画变化的部分放 child，避免重复构建
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [theme.colorScheme.primary, theme.colorScheme.tertiary],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 控制器操作按钮
// ---------------------------------------------------------------------------
class _ControlSection extends StatelessWidget {
  const _ControlSection({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '控制器操作',
      subtitle: 'forward / reverse / repeat / reset',
      icon: Icons.play_circle_outline,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          FilledButton.tonalIcon(
            onPressed: () => controller.forward(from: 0),
            icon: const Icon(Icons.play_arrow),
            label: const Text('播放'),
          ),
          FilledButton.tonalIcon(
            onPressed: () => controller.reverse(from: 1),
            icon: const Icon(Icons.fast_rewind),
            label: const Text('反转'),
          ),
          FilledButton.tonalIcon(
            onPressed: () => controller.repeat(reverse: true),
            icon: const Icon(Icons.repeat),
            label: const Text('往返循环'),
          ),
          FilledButton.tonalIcon(
            onPressed: () => controller.reset(),
            icon: const Icon(Icons.stop),
            label: const Text('重置'),
          ),
        ],
      ),
    );
  }
}
