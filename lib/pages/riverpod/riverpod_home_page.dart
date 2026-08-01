import 'package:flutter/material.dart';

import '../../router/navigators/riverpod_navigator.dart';
import 'riverpod_demo_data.dart';

/// Riverpod 模块 · 二级页面：演示列表
///
/// 展示 Riverpod 常用 Provider 类型的入口列表，
/// 点击进入对应的三级演示页面。
class RiverpodHomePage extends StatelessWidget {
  const RiverpodHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Riverpod 状态管理')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 模块介绍卡
          Card(
            color: theme.colorScheme.primaryContainer,
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.water_drop,
                    size: 20,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Riverpod 状态管理框架',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Riverpod 是 Flutter 的响应式状态管理和依赖注入框架。'
                          '本模块通过 6 个演示页面，循序渐进介绍 Provider、StateProvider、'
                          'FutureProvider、StreamProvider、NotifierProvider 及 Consumer 的用法。',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 演示列表
          for (var i = 0; i < RiverpodDemoData.demos.length; i++)
            _DemoCard(
              index: i + 1,
              item: RiverpodDemoData.demos[i],
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 演示项卡片：序号 + 图标 + 标题简介 + 跳转箭头
// ---------------------------------------------------------------------------
class _DemoCard extends StatelessWidget {
  const _DemoCard({required this.index, required this.item});

  /// 显示序号（1-based）
  final int index;

  final RiverpodDemoItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(item.icon, color: theme.colorScheme.onPrimaryContainer),
        ),
        title: Text(
          '${index.toString().padLeft(2, '0')} · ${item.title}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(item.subtitle),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // 进入三级演示页面
          context.navToRiverpodDemo(item.id);
        },
      ),
    );
  }
}
