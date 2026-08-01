import 'package:flutter/material.dart';

import 'demos/consumer_widget_demo_page.dart';
import 'demos/future_provider_demo_page.dart';
import 'demos/notifier_provider_demo_page.dart';
import 'demos/provider_demo_page.dart';
import 'demos/state_provider_demo_page.dart';
import 'demos/stream_provider_demo_page.dart';

/// Riverpod 演示项模型
///
/// 对应 Riverpod 模块列表中的一项，点击后进入对应的演示页面。
class RiverpodDemoItem {
  const RiverpodDemoItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.demoPage,
  });

  /// 唯一标识，用于路由路径参数
  final String id;

  /// 演示标题
  final String title;

  /// 简介说明
  final String subtitle;

  /// 列表项前缀图标
  final IconData icon;

  /// 点击后进入的演示页面
  final Widget demoPage;
}

/// Riverpod 模块全部演示项
///
/// 新增演示时，在此列表中追加一项即可，路由与列表自动联动。
class RiverpodDemoData {
  RiverpodDemoData._();

  static const demos = <RiverpodDemoItem>[
    RiverpodDemoItem(
      id: 'provider',
      title: 'Provider 基础用法',
      subtitle: '只读值 / 计算缓存 / Provider 组合依赖',
      icon: Icons.lock_outline,
      demoPage: ProviderDemoPage(),
    ),
    RiverpodDemoItem(
      id: 'state_provider',
      title: 'StateProvider 用法',
      subtitle: '计数器 / 主题切换 / 字号缩放',
      icon: Icons.toggle_on_outlined,
      demoPage: StateProviderDemoPage(),
    ),
    RiverpodDemoItem(
      id: 'future_provider',
      title: 'FutureProvider 用法',
      subtitle: '异步加载 / 三态处理 / refresh 刷新',
      icon: Icons.cloud_download_outlined,
      demoPage: FutureProviderDemoPage(),
    ),
    RiverpodDemoItem(
      id: 'stream_provider',
      title: 'StreamProvider 用法',
      subtitle: '实时计时器 / 倒计时 / 模拟行情',
      icon: Icons.stream_outlined,
      demoPage: StreamProviderDemoPage(),
    ),
    RiverpodDemoItem(
      id: 'notifier_provider',
      title: 'NotifierProvider 用法',
      subtitle: 'Todo 增删改查 / 购物车 / 派生 Provider',
      icon: Icons.manage_history,
      demoPage: NotifierProviderDemoPage(),
    ),
    RiverpodDemoItem(
      id: 'consumer',
      title: 'Consumer 与 ref 用法',
      subtitle: 'ConsumerWidget / Consumer / watch vs read / listen',
      icon: Icons.construction_outlined,
      demoPage: ConsumerWidgetDemoPage(),
    ),
  ];

  /// 按 id 查找演示项
  static RiverpodDemoItem? byId(String id) {
    for (final demo in demos) {
      if (demo.id == id) return demo;
    }
    return null;
  }
}
