import 'package:flutter/material.dart';

import '../../../../utils/theme_ext.dart';
import '../../../../widgets/demo_page_scaffold.dart';
import '../../../../widgets/section_card.dart';

/// 学习计划 · 布局组件 · 层叠定位
///
/// 演示 Stack 层叠、Positioned 精确定位，以及角标、图片遮罩两个实战场景。
class StackDemo extends StatelessWidget {
  const StackDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return const DemoPageScaffold(
      title: '层叠定位',
      goal: '掌握 Stack 的子组件层叠规则与 alignment 对齐，学会用 Positioned 精确定位，完成头像角标与图片文字遮罩两个常见实战布局。',
      children: [
        _BasicSection(),
        _PositionedSection(),
        _BadgeSection(),
        _OverlaySection(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Stack 基础层叠
// ---------------------------------------------------------------------------
class _BasicSection extends StatelessWidget {
  const _BasicSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: 'Stack 基础层叠',
      subtitle: '后声明的子组件显示在上层，alignment 统一对齐',
      icon: Icons.layers_outlined,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Positioned 精确定位
// ---------------------------------------------------------------------------
class _PositionedSection extends StatelessWidget {
  const _PositionedSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: 'Positioned 精确定位',
      subtitle: 'top / right / bottom / left 相对 Stack 边缘定位',
      icon: Icons.open_in_full_outlined,
      child: Center(
        child: Container(
          width: 220,
          height: 140,
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outline),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              const Positioned(top: 8, left: 8, child: _Tag(label: '左上')),
              const Positioned(top: 8, right: 8, child: _Tag(label: '右上')),
              const Positioned(bottom: 8, left: 8, child: _Tag(label: '左下')),
              const Positioned(bottom: 8, right: 8, child: _Tag(label: '右下')),
              Positioned(
                // left + right 同时给 0，宽度即被约束为拉伸
                left: 0,
                right: 0,
                top: 60,
                child: Center(
                  child: Text(
                    '居中（left:0 + right:0）',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 实战：头像 + 消息角标
// ---------------------------------------------------------------------------
class _BadgeSection extends StatelessWidget {
  const _BadgeSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: '实战：头像消息角标',
      subtitle: 'Stack + Positioned 组合的典型应用',
      icon: Icons.notifications_active_outlined,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 红点角标
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: const Icon(Icons.person),
              ),
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error,
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.colorScheme.surface, width: 2),
                  ),
                ),
              ),
            ],
          ),
          // 数字角标
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: theme.colorScheme.secondaryContainer,
                child: const Icon(Icons.shopping_cart_outlined),
              ),
              Positioned(
                right: -8,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: theme.colorScheme.surface, width: 1.5),
                  ),
                  child: Text(
                    '99+',
                    style: TextStyle(fontSize: 10, color: theme.colorScheme.onError),
                  ),
                ),
              ),
            ],
          ),
          // 在线状态角标
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: theme.colorScheme.tertiaryContainer,
                child: const Icon(Icons.face),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: context.appColors.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.colorScheme.surface, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 实战：图片 + 渐变遮罩 + 文字
// ---------------------------------------------------------------------------
class _OverlaySection extends StatelessWidget {
  const _OverlaySection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: '实战：图片渐变遮罩文字',
      subtitle: '信息流卡片的常见布局方式',
      icon: Icons.photo_library_outlined,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 160,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 底层：背景图（此处用色块模拟）
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [theme.colorScheme.primary, theme.colorScheme.tertiary],
                  ),
                ),
                child: const Center(child: FlutterLogo(size: 64)),
              ),
              // 中层：底部向上渐变的黑色遮罩，保证文字可读性
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 80,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        context.appColors.scrim,
                      ],
                    ),
                  ),
                ),
              ),
              // 上层：标题与副标题
              const Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '层叠布局实战示例',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '背景图 + 渐变遮罩 + 文字 三层叠加',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 定位标签
// ---------------------------------------------------------------------------
class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: theme.textTheme.bodySmall),
    );
  }
}
