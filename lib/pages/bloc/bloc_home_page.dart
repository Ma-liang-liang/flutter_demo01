import 'package:flutter/material.dart';

import '../../router/navigators/bloc_navigator.dart';
import 'bloc_demo_data.dart';

/// Bloc 模块 · 二级页面：演示列表
///
/// 展示 Bloc / Cubit 常用用法的入口列表，
/// 点击进入对应的三级演示页面。
class BlocHomePage extends StatelessWidget {
  const BlocHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Bloc 状态管理')),
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
                    Icons.hub,
                    size: 20,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bloc 状态管理框架（MVVM 视角）',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Bloc 是「事件驱动 + 单向数据流」的状态管理方案。'
                          '在 MVVM 中：Cubit/Bloc 充当 ViewModel，持有业务逻辑与不可变状态；'
                          '页面是 View，只发事件、渲染状态；Repository/Service 是 Model 层。'
                          '本模块通过 6 个演示页面，从 Cubit 基础到 Stream 结合循序渐进讲解。',
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
          // MVVM 分层速览卡
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '本模块的 MVVM 分层',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _LayerRow(
                    layer: 'View',
                    path: 'demos/*.dart',
                    desc: '页面与组件：发事件、BlocBuilder 渲染',
                  ),
                  _LayerRow(
                    layer: 'ViewModel',
                    path: 'viewmodels/*.dart',
                    desc: 'Cubit/Bloc：业务逻辑、emit 不可变状态',
                  ),
                  _LayerRow(
                    layer: 'Model',
                    path: 'data/*.dart',
                    desc: 'Repository/实体：数据获取与业务规则',
                  ),
                ],
              ),
            ),
          ),
          // 演示列表
          for (var i = 0; i < BlocDemoData.demos.length; i++)
            _DemoCard(index: i + 1, item: BlocDemoData.demos[i]),
        ],
      ),
    );
  }
}

/// 分层说明行
class _LayerRow extends StatelessWidget {
  const _LayerRow({
    required this.layer,
    required this.path,
    required this.desc,
  });

  final String layer;
  final String path;
  final String desc;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 76,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              layer,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  path,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
                Text(
                  desc,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
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

  final BlocDemoItem item;

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
          context.navToBlocDemo(item.id);
        },
      ),
    );
  }
}
