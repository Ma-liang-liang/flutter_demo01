import 'package:flutter/material.dart';

import '../../../../widgets/demo_page_scaffold.dart';
import '../../../../widgets/section_card.dart';

/// 学习计划 · 动画交互 · 手势交互
///
/// 演示 GestureDetector 点击/长按/拖拽、InkWell 水波纹、Draggable 拖放。
class GestureDemo extends StatefulWidget {
  const GestureDemo({super.key});

  @override
  State<GestureDemo> createState() => _GestureDemoState();
}

class _GestureDemoState extends State<GestureDemo> {
  String _lastGesture = '还没有手势操作';
  Offset _ballPosition = const Offset(120, 40);
  bool _dropSuccess = false;

  @override
  Widget build(BuildContext context) {
    return DemoPageScaffold(
      title: '手势交互',
      goal: '掌握 GestureDetector 的点击、双击、长按与拖拽手势，理解 InkWell 水波纹的使用条件，学会 Draggable + DragTarget 实现拖放功能。',
      children: [
        _TapSection(
          lastGesture: _lastGesture,
          onGesture: (name) => setState(() => _lastGesture = name),
        ),
        _PanSection(
          position: _ballPosition,
          onPan: (delta) => setState(() => _ballPosition += delta),
        ),
        const _InkWellSection(),
        _DragSection(
          success: _dropSuccess,
          onAccepted: () => setState(() => _dropSuccess = true),
          onReset: () => setState(() => _dropSuccess = false),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 点击 / 双击 / 长按
// ---------------------------------------------------------------------------
class _TapSection extends StatelessWidget {
  const _TapSection({required this.lastGesture, required this.onGesture});

  final String lastGesture;
  final ValueChanged<String> onGesture;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: '点击 / 双击 / 长按',
      subtitle: 'GestureDetector 基础手势',
      icon: Icons.touch_app_outlined,
      child: Column(
        children: [
          GestureDetector(
            onTap: () => onGesture('触发了：单击 onTap'),
            onDoubleTap: () => onGesture('触发了：双击 onDoubleTap'),
            onLongPress: () => onGesture('触发了：长按 onLongPress'),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Text('单击 / 双击 / 长按 我'),
            ),
          ),
          const SizedBox(height: 12),
          Text(lastGesture, style: TextStyle(color: theme.colorScheme.primary)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 拖拽移动
// ---------------------------------------------------------------------------
class _PanSection extends StatelessWidget {
  const _PanSection({required this.position, required this.onPan});

  final Offset position;
  final ValueChanged<Offset> onPan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: '拖拽移动',
      subtitle: 'onPanUpdate 回调手指滑动的位移增量',
      icon: Icons.pan_tool_outlined,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            Positioned(
              left: position.dx,
              top: position.dy,
              child: GestureDetector(
                // details.delta 是本次滑动的位移增量
                onPanUpdate: (details) => onPan(details.delta),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.colorScheme.primary,
                  child: Icon(Icons.drag_indicator, color: theme.colorScheme.onPrimary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// InkWell 水波纹
// ---------------------------------------------------------------------------
class _InkWellSection extends StatelessWidget {
  const _InkWellSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: 'InkWell 水波纹',
      subtitle: '需要 Material 祖先组件才能显示波纹',
      icon: Icons.water_drop_outlined,
      child: Column(
        children: [
          // InkWell 配合 Material 才会出现点击波纹效果
          Material(
            color: theme.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {},
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 20, horizontal: 32),
                child: Text('点我看水波纹（InkWell）'),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '提示：InkResponse / InkWell 的波纹绘制在最近的 Material 组件上',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Draggable 拖放
// ---------------------------------------------------------------------------
class _DragSection extends StatelessWidget {
  const _DragSection({
    required this.success,
    required this.onAccepted,
    required this.onReset,
  });

  final bool success;
  final VoidCallback onAccepted;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: 'Draggable 拖放',
      subtitle: '把左侧色块拖进右侧目标框',
      icon: Icons.move_down_outlined,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (!success)
                // 可拖拽组件：feedback 是拖动时跟随手指的样式
                Draggable<String>(
                  data: 'color-block',
                  feedback: _DragBlock(color: theme.colorScheme.primary.withValues(alpha: 0.7)),
                  childWhenDragging: _DragBlock(color: theme.colorScheme.surfaceContainerHighest),
                  child: _DragBlock(color: theme.colorScheme.primary),
                )
              else
                _DragBlock(color: theme.colorScheme.surfaceContainerHighest),
              // 拖放目标
              DragTarget<String>(
                onAcceptWithDetails: (details) => onAccepted(),
                builder: (context, candidateData, rejectedData) {
                  final hovering = candidateData.isNotEmpty;
                  return Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: success
                          ? theme.colorScheme.primary
                          : hovering
                              ? theme.colorScheme.primaryContainer
                              : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outline,
                        style: success ? BorderStyle.solid : BorderStyle.none,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(success ? '已放入!' : '目标框'),
                  );
                },
              ),
            ],
          ),
          if (success) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onReset, child: const Text('重置再玩一次')),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 拖拽色块
// ---------------------------------------------------------------------------
class _DragBlock extends StatelessWidget {
  const _DragBlock({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
