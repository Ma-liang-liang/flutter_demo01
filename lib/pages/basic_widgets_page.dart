import 'package:flutter/material.dart';

import '../data/learning_plan_data.dart';
import '../router/navigators/basic_navigator.dart';
import '../router/navigators/ble_navigator.dart';
import '../router/navigators/bloc_navigator.dart';
import '../router/navigators/login_navigator.dart';
import '../router/navigators/network_navigator.dart';
import '../router/navigators/riverpod_navigator.dart';
import '../widgets/learning_entry_card.dart';
import '../widgets/section_card.dart';

/// Tab1: 基础组件展示页面
///
/// 展示常用的基础 UI 组件：按钮、文本样式、图标、卡片、Chip 等。
class BasicWidgetsPage extends StatelessWidget {
  const BasicWidgetsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        // 学习计划入口：点击进入本分类的章节列表（二级页面）
        LearningEntryCard(chapter: LearningPlanData.basicChapter),
        _ButtonsSection(),
        _TextSection(),
        _IconsSection(),
        _ChipsSection(),
        _CardsSection(),
        _LoginCompareSection(),
        _RiverpodSection(),
        _BlocSection(),
        _CustomNavBarSection(),
        _NetworkSection(),
        _BleSection(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 按钮区域
// ---------------------------------------------------------------------------
class _ButtonsSection extends StatelessWidget {
  const _ButtonsSection();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '按钮',
      subtitle: 'Filled / Outlined / Text / IconButton / FAB',
      icon: Icons.smart_button,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          FilledButton(
            onPressed: () => _showSnackBar(context, 'FilledButton 点击'),
            child: const Text('Filled'),
          ),
          FilledButton.tonal(
            onPressed: () => _showSnackBar(context, 'TonalButton 点击'),
            child: const Text('Tonal'),
          ),
          OutlinedButton(
            onPressed: () => _showSnackBar(context, 'OutlinedButton 点击'),
            child: const Text('Outlined'),
          ),
          TextButton(
            onPressed: () => _showSnackBar(context, 'TextButton 点击'),
            child: const Text('Text'),
          ),
          ElevatedButton(
            onPressed: () => _showSnackBar(context, 'ElevatedButton 点击'),
            child: const Text('Elevated'),
          ),
          IconButton.filled(
            onPressed: () => _showSnackBar(context, 'IconButton 点击'),
            icon: const Icon(Icons.thumb_up),
          ),
          IconButton.outlined(
            onPressed: () => _showSnackBar(context, 'Outlined IconButton 点击'),
            icon: const Icon(Icons.favorite),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 文本区域
// ---------------------------------------------------------------------------
class _TextSection extends StatelessWidget {
  const _TextSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: '文本样式',
      subtitle: '不同字体大小 / Google Fonts',
      icon: Icons.text_fields,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Display Large', style: theme.textTheme.displaySmall),
          Text('Headline Medium', style: theme.textTheme.headlineMedium),
          Text('Title Large', style: theme.textTheme.titleLarge),
          Text('Body Medium — 这是一段正文文本，用于展示默认正文字体样式。'),
          Text(
            'Google Fonts (Pacifico)',
            style: TextStyle(
              fontSize: 24,
              fontFamily: 'serif',
              fontStyle: FontStyle.italic,
            ),
          ),
          Text(
            'Google Fonts (RobotoMono)',
            style: TextStyle(
              fontSize: 16,
              fontFamily: 'monospace',
            ),
          ),
          RichText(
            text: TextSpan(
              style: theme.textTheme.bodyMedium,
              children: [
                const TextSpan(text: 'RichText 支持 '),
                TextSpan(
                  text: '粗体',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: '、'),
                TextSpan(
                  text: '彩色',
                  style: TextStyle(color: theme.colorScheme.primary),
                ),
                const TextSpan(text: '、'),
                TextSpan(
                  text: '斜体',
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
                const TextSpan(text: ' 等混合样式。'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 图标区域
// ---------------------------------------------------------------------------
class _IconsSection extends StatelessWidget {
  const _IconsSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const icons = [
      Icons.home, Icons.search, Icons.person, Icons.settings,
      Icons.notifications, Icons.email, Icons.favorite, Icons.star,
      Icons.bookmark, Icons.share, Icons.camera, Icons.music_note,
    ];

    return SectionCard(
      title: '图标',
      subtitle: 'Material Icons 网格',
      icon: Icons.grid_view,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: icons.length,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icons[index], color: theme.colorScheme.primary),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chip 区域
// ---------------------------------------------------------------------------
class _ChipsSection extends StatelessWidget {
  const _ChipsSection();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Chip 组件',
      subtitle: 'Chip / ActionChip / FilterChip',
      icon: Icons.label,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          const Chip(label: Text('Chip'), avatar: Icon(Icons.person)),
          ActionChip(
            label: const Text('ActionChip'),
            avatar: const Icon(Icons.play_arrow),
            onPressed: () => _showSnackBar(context, 'ActionChip 点击'),
          ),
          FilterChip(
            label: const Text('FilterChip'),
            selected: true,
            onSelected: (v) => _showSnackBar(context, 'FilterChip: $v'),
          ),
          InputChip(
            label: const Text('InputChip'),
            avatar: const Icon(Icons.account_circle),
            onDeleted: () => _showSnackBar(context, 'InputChip 删除'),
          ),
          const Chip(
            label: Text('删除样式'),
            deleteIcon: Icon(Icons.cancel),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 卡片区域
// ---------------------------------------------------------------------------
class _CardsSection extends StatelessWidget {
  const _CardsSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: '卡片',
      subtitle: 'Card + ListTile 组合',
      icon: Icons.credit_card,
      child: Column(
        children: [
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(Icons.person, color: theme.colorScheme.primary),
              ),
              title: const Text('用户名称'),
              subtitle: const Text('user@example.com'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showSnackBar(context, '点击用户卡片'),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('位置卡片',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '这是一段卡片内容描述文本，展示 Card 内部使用 Padding + Column 排列内容的方式。',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 辅助方法
// ---------------------------------------------------------------------------
void _showSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 1)));
}

// ---------------------------------------------------------------------------
// 登录对比模块入口（Bloc vs Riverpod）
// ---------------------------------------------------------------------------
class _LoginCompareSection extends StatelessWidget {
  const _LoginCompareSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: 'Bloc vs Riverpod 登录对比',
      subtitle: '同一业务 / 同一 MVVM 架构 / 两种状态管理实现',
      icon: Icons.compare_arrows,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.compare_arrows,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '共享同一个模拟登录仓库，分别用 Bloc（事件驱动）和 Riverpod（Notifier 方法调用）'
                  '实现 MVVM 登录模块，进入两个页面即可对比两种方案的实现差异。',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => context.navToBlocLogin(),
                  icon: const Icon(Icons.hub),
                  label: const Text('Bloc 版'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => context.navToRiverpodLogin(),
                  icon: const Icon(Icons.water_drop),
                  label: const Text('Riverpod 版'),
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
// Riverpod 状态管理模块入口
// ---------------------------------------------------------------------------
class _RiverpodSection extends StatelessWidget {
  const _RiverpodSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: 'Riverpod 状态管理',
      subtitle: 'Provider / StateProvider / FutureProvider / StreamProvider / Notifier',
      icon: Icons.water_drop,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.water_drop,
              color: theme.colorScheme.onTertiaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '通过 6 个演示页面，循序渐进掌握 Riverpod 状态管理框架的核心用法。',
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => context.navToRiverpodHome(),
            child: const Text('进入学习'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bloc 状态管理模块入口
// ---------------------------------------------------------------------------
class _BlocSection extends StatelessWidget {
  const _BlocSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: 'Bloc 状态管理',
      subtitle: 'Cubit / 事件驱动 / 异步三态 / Listener / 依赖注入 / Stream',
      icon: Icons.hub,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.hub,
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '以 MVVM 分层组织代码，通过 6 个演示页面掌握 Bloc / Cubit 的常用用法，每个页面都附带原理讲解。',
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => context.navToBlocHome(),
            child: const Text('进入学习'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 网络组件演示入口
// ---------------------------------------------------------------------------
class _NetworkSection extends StatelessWidget {
  const _NetworkSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: 'dio_network 网络封装',
      subtitle: '统一配置 / 公参 / 业务拦截 / 泛型转模型 / 日志开关',
      icon: Icons.cloud,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.cloud,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '基于 Dio 的业务层网络封装，演示统一配置、公参注入、业务码拦截、泛型字典转模型等完整能力。',
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => context.navToNetworkDemo(),
            child: const Text('进入演示'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 自定义导航条演示入口
// ---------------------------------------------------------------------------
class _CustomNavBarSection extends StatelessWidget {
  const _CustomNavBarSection();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '自定义导航条',
      subtitle: '不依赖系统 AppBar / 完全自定义',
      icon: Icons.navigation,
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () => context.navToNavBarDemo(),
              icon: const Icon(Icons.open_in_new),
              label: const Text('查看导航条演示'),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// BLE 蓝牙插件演示入口
// ---------------------------------------------------------------------------
class _BleSection extends StatelessWidget {
  const _BleSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: 'ble_plugin 蓝牙插件',
      subtitle: '扫描 / 连接 / 可靠传输 / ACK 窗口 / 断点续传 / 自动重连',
      icon: Icons.bluetooth,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.bluetooth,
              color: theme.colorScheme.onTertiaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '跨平台 BLE 插件：应用层协议帧（CRC32 + ACK 窗口）、自动重连（指数退避）、'
              '断点续传、运行时指标统计。业务逻辑全在 Dart 层，原生只做桥接。',
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => context.navToBleDemo(),
            child: const Text('进入演示'),
          ),
        ],
      ),
    );
  }
}

