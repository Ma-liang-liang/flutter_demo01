import 'package:flutter/material.dart';

import '../../../../widgets/demo_page_scaffold.dart';
import '../../../../widgets/section_card.dart';

/// 学习计划 · 基础组件 · 图片与图标
///
/// 演示图片的形状裁剪、BoxFit 填充模式、网络图片加载兜底，以及图标定制。
class ImageIconDemo extends StatelessWidget {
  const ImageIconDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return const DemoPageScaffold(
      title: '图片与图标',
      goal: '掌握 ClipRRect / CircleAvatar 图片裁剪，理解 BoxFit 各填充模式的差异，学会为网络图片添加加载中与失败兜底，以及图标的常用定制方式。',
      children: [
        _ShapeSection(),
        _BoxFitSection(),
        _NetworkSection(),
        _IconSection(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 形状裁剪
// ---------------------------------------------------------------------------
class _ShapeSection extends StatelessWidget {
  const _ShapeSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: '形状裁剪',
      subtitle: 'ClipRRect 圆角 / ClipOval 圆形 / CircleAvatar 头像',
      icon: Icons.crop_outlined,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 圆角矩形：通用图片卡片样式
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 80,
              height: 80,
              color: theme.colorScheme.primaryContainer,
              child: const FlutterLogo(size: 48),
            ),
          ),
          // 圆形：常用于用户头像
          ClipOval(
            child: Container(
              width: 80,
              height: 80,
              color: theme.colorScheme.secondaryContainer,
              child: const FlutterLogo(size: 48),
            ),
          ),
          // CircleAvatar：自带占位文字/图标的头像组件
          CircleAvatar(
            radius: 40,
            backgroundColor: theme.colorScheme.tertiaryContainer,
            child: Text('张', style: TextStyle(fontSize: 28, color: theme.colorScheme.onTertiaryContainer)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// BoxFit 填充模式
// ---------------------------------------------------------------------------
class _BoxFitSection extends StatelessWidget {
  const _BoxFitSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const fits = [
      (BoxFit.cover, 'cover'),
      (BoxFit.contain, 'contain'),
      (BoxFit.fill, 'fill'),
      (BoxFit.fitWidth, 'fitWidth'),
    ];
    return SectionCard(
      title: 'BoxFit 填充模式',
      subtitle: '图片在容器内的缩放与裁剪策略',
      icon: Icons.aspect_ratio_outlined,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final (fit, name) in fits)
            Column(
              children: [
                Container(
                  width: 70,
                  height: 100,
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outline),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Image.network(
                        // 教学占位地址，实际项目替换为业务图片 URL
                        'https://invalid.example/photo.jpg',
                        fit: fit,
                        // 加载失败时展示兜底图标，保证界面不破碎
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.image,
                          size: 32,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(name, style: theme.textTheme.bodySmall),
              ],
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 网络图片与兜底
// ---------------------------------------------------------------------------
class _NetworkSection extends StatelessWidget {
  const _NetworkSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: '网络图片加载',
      subtitle: 'loadingBuilder 加载中 / errorBuilder 失败兜底',
      icon: Icons.cloud_download_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '下面演示一个加载失败的场景（教学占位地址不可访问），'
            'errorBuilder 会接管显示兜底 UI，避免红屏报错：',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              'https://invalid.example/banner.jpg',
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              // 加载中显示进度指示
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  height: 120,
                  alignment: Alignment.center,
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: CircularProgressIndicator(
                    value: progress.expectedTotalBytes != null
                        ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
              // 加载失败显示兜底内容
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 120,
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image_outlined, size: 32, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(height: 4),
                      Text('图片加载失败，显示兜底', style: theme.textTheme.bodySmall),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 图标定制
// ---------------------------------------------------------------------------
class _IconSection extends StatelessWidget {
  const _IconSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: '图标定制',
      subtitle: '大小 / 颜色 / 阴影 / 圆形背景',
      icon: Icons.emoji_symbols_outlined,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Icon(Icons.favorite, size: 40, color: theme.colorScheme.error),
          // 带阴影的图标
          Icon(
            Icons.star,
            size: 40,
            color: Colors.amber,
            shadows: [
              Shadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(2, 2)),
            ],
          ),
          // 圆形背景图标：常用于功能入口
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.qr_code, color: theme.colorScheme.onPrimaryContainer),
          ),
          // 渐变色图标：ShaderMask 实现
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [theme.colorScheme.primary, theme.colorScheme.tertiary],
            ).createShader(bounds),
            child: const Icon(Icons.whatshot, size: 40, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
