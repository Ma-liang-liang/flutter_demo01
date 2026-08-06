import 'package:flutter/material.dart';

import 'demos/async_state_demo_page.dart';
import 'demos/bloc_event_demo_page.dart';
import 'demos/cubit_basic_demo_page.dart';
import 'demos/listener_consumer_demo_page.dart';
import 'demos/provider_di_demo_page.dart';
import 'demos/stream_countdown_demo_page.dart';

/// Bloc 演示项模型
///
/// 对应 Bloc 模块列表中的一项，点击后进入对应的演示页面。
class BlocDemoItem {
  const BlocDemoItem({
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

/// Bloc 模块全部演示项
///
/// 新增演示时，在此列表中追加一项即可，路由与列表自动联动。
class BlocDemoData {
  BlocDemoData._();

  static const demos = <BlocDemoItem>[
    BlocDemoItem(
      id: 'cubit_basic',
      title: 'Cubit 基础用法',
      subtitle: '计数器 / emit 新状态 / BlocBuilder / Equatable 去重',
      icon: Icons.calculate_outlined,
      demoPage: CubitBasicDemoPage(),
    ),
    BlocDemoItem(
      id: 'bloc_event',
      title: 'Bloc 事件驱动',
      subtitle: 'Event 三件套 / on 注册 handler / 串行事件流',
      icon: Icons.event_repeat_outlined,
      demoPage: BlocEventDemoPage(),
    ),
    BlocDemoItem(
      id: 'async_state',
      title: '异步加载三态',
      subtitle: '模拟网络 / loading / success / failure / 重试',
      icon: Icons.cloud_sync_outlined,
      demoPage: AsyncStateDemoPage(),
    ),
    BlocDemoItem(
      id: 'listener_consumer',
      title: 'Listener 与 Consumer',
      subtitle: '一次性副作用 / SnackBar / Dialog / listenWhen',
      icon: Icons.notifications_active_outlined,
      demoPage: ListenerConsumerDemoPage(),
    ),
    BlocDemoItem(
      id: 'provider_di',
      title: '依赖注入与实例共享',
      subtitle: 'BlocProvider / MultiBlocProvider / RepositoryProvider / value',
      icon: Icons.share_outlined,
      demoPage: ProviderDiDemoPage(),
    ),
    BlocDemoItem(
      id: 'stream_countdown',
      title: 'Bloc 与 Stream',
      subtitle: '倒计时 / 内部事件 / close 时取消订阅',
      icon: Icons.timer_outlined,
      demoPage: StreamCountdownDemoPage(),
    ),
  ];

  /// 按 id 查找演示项
  static BlocDemoItem? byId(String id) {
    for (final demo in demos) {
      if (demo.id == id) return demo;
    }
    return null;
  }
}
