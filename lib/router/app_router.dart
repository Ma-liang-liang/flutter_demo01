import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/learning_plan_data.dart';
import '../features/login/bloc_login/view/bloc_login_page.dart';
import '../features/login/riverpod_login/view/riverpod_login_page.dart';
import '../pages/animation_interaction_page.dart';
import '../pages/basic_widgets_page.dart';
import '../pages/ble_demo_page.dart';
import '../pages/bloc/bloc_demo_data.dart';
import '../pages/bloc/bloc_home_page.dart';
import '../pages/form_widgets_page.dart';
import '../pages/layout_widgets_page.dart';
import '../pages/learn/topic_list_page.dart';
import '../pages/nav_bar_demo_page.dart';
import '../pages/plugin_test_page.dart';
import '../pages/network_demo_page.dart';
import '../pages/riverpod/riverpod_demo_data.dart';
import '../pages/riverpod/riverpod_home_page.dart';

/// 路由路径常量
class AppRoutePath {
  AppRoutePath._();

  static const basic = '/basic';
  static const form = '/form';
  static const layout = '/layout';
  static const animation = '/animation';
  static const plugin = '/plugin';

  /// 学习计划二级页面前缀
  static const learn = '/learn';

  /// 自定义导航条演示页面
  static const navBarDemo = '/nav_bar_demo';

  /// Riverpod 状态管理模块
  static const riverpod = '/riverpod';

  /// Bloc 状态管理模块
  static const bloc = '/bloc';

  /// 登录对比模块（Bloc vs Riverpod 两套实现）
  static const login = '/login';

  /// 网络组件演示页面
  static const networkDemo = '/network_demo';

  /// BLE 蓝牙插件演示页面
  static const bleDemo = '/ble_demo';
}

/// 路由名称常量（用于 context.pushNamed / context.goNamed）
///
/// 统一管理路由名称，避免散落在各调用方的字符串中。
/// 配合 `navigators/` 目录下的 BuildContext 扩展使用，调用方无需关心名称与路径细节。
class AppRouteName {
  AppRouteName._();

  /// Tab 根页面
  static const basic = 'basic';
  static const form = 'form';
  static const layout = 'layout';
  static const animation = 'animation';
  static const plugin = 'plugin';

  /// 学习计划 · 二级页面（主题列表）
  static const topicList = 'topicList';

  /// 学习计划 · 三级页面（演示页面）
  static const topicDemo = 'topicDemo';

  /// 自定义导航条演示页面
  static const navBarDemo = 'navBarDemo';

  /// Riverpod 模块 · 二级页面（演示列表）
  static const riverpodHome = 'riverpodHome';

  /// Riverpod 模块 · 三级页面（具体演示）
  static const riverpodDemo = 'riverpodDemo';

  /// Bloc 模块 · 二级页面（演示列表）
  static const blocHome = 'blocHome';

  /// Bloc 模块 · 三级页面（具体演示）
  static const blocDemo = 'blocDemo';

  /// 登录对比 · Bloc 版登录页面
  static const loginBloc = 'loginBloc';

  /// 登录对比 · Riverpod 版登录页面
  static const loginRiverpod = 'loginRiverpod';

  /// 网络组件演示页面
  static const networkDemo = 'networkDemo';

  /// BLE 蓝牙插件演示页面
  static const bleDemo = 'bleDemo';
}

/// 底部导航 Tab 配置
class TabConfig {
  const TabConfig({
    required this.path,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  /// 路由路径，如 '/basic'
  final String path;

  /// NavigationBar 显示的文字
  final String label;

  /// 未选中图标
  final IconData icon;

  /// 选中图标
  final IconData selectedIcon;
}

/// 5 个 Tab 的配置
const tabConfigs = <TabConfig>[
  TabConfig(
    path: AppRoutePath.basic,
    label: '基础组件',
    icon: Icons.widgets_outlined,
    selectedIcon: Icons.widgets,
  ),
  TabConfig(
    path: AppRoutePath.form,
    label: '表单组件',
    icon: Icons.edit_note_outlined,
    selectedIcon: Icons.edit_note,
  ),
  TabConfig(
    path: AppRoutePath.layout,
    label: '布局组件',
    icon: Icons.view_quilt_outlined,
    selectedIcon: Icons.view_quilt,
  ),
  TabConfig(
    path: AppRoutePath.animation,
    label: '动画交互',
    icon: Icons.animation_outlined,
    selectedIcon: Icons.animation,
  ),
  TabConfig(
    path: AppRoutePath.plugin,
    label: '原生插件',
    icon: Icons.extension_outlined,
    selectedIcon: Icons.extension,
  ),
];

/// 应用路由配置
///
/// 路由分为两层：
///
/// 1. **ShellRoute（底部导航层）** — 使用 [StatefulShellRoute.indexedStack]
///    - 5 个 Tab 分支，底部 [NavigationBar] 常驻
///    - 切换 Tab 时各 Tab 状态互不影响（IndexedStack 保活）
///    - Shell 提供 AppBar 显示当前 Tab 标题
///
/// 2. **顶层路由（全屏页面层）** — 放在 ShellRoute 之外
///    - `/learn/:chapterId` → 学习计划主题列表（二级页面）
///    - `/learn/:chapterId/:topicIndex` → 三级演示页面
///    - 通过 `context.navToXxx` 扩展方法进入，全屏覆盖 Shell（底部导航自动隐藏）
///    - 返回后回到之前的 Tab，Tab 状态保持不变
///
/// 所有 GoRoute 均设置了 `name` 命名路由（见 [AppRouteName]），
/// 调用方应通过 `navigators/` 目录下扩展方法的 `context.navXxx` 跳转，避免裸字符串拼接路径。
///
/// 返回工厂函数而非全局单例，确保每次创建 [MaterialApp.router] 时
/// 获得独立的路由状态（测试隔离、热重载不残留旧状态）。
GoRouter createAppRouter() => GoRouter(
      initialLocation: AppRoutePath.basic,
      routes: [
        // ──────────────────────────────────────────────────────────────
        // 底部导航 Shell（5 个 Tab）
        // ──────────────────────────────────────────────────────────────
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              _MainShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  name: AppRouteName.basic,
                  path: AppRoutePath.basic,
                  builder: (context, state) => const BasicWidgetsPage(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  name: AppRouteName.form,
                  path: AppRoutePath.form,
                  builder: (context, state) => const FormWidgetsPage(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  name: AppRouteName.layout,
                  path: AppRoutePath.layout,
                  builder: (context, state) => const LayoutWidgetsPage(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  name: AppRouteName.animation,
                  path: AppRoutePath.animation,
                  builder: (context, state) => const AnimationInteractionPage(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  name: AppRouteName.plugin,
                  path: AppRoutePath.plugin,
                  builder: (context, state) => const PluginTestPage(),
                ),
              ],
            ),
          ],
        ),

        // ──────────────────────────────────────────────────────────────
        // 全屏子页面（Shell 之外，底部导航自动隐藏）
        // ──────────────────────────────────────────────────────────────

        /// 二级页面：学习计划主题列表
        GoRoute(
          name: AppRouteName.topicList,
          path: '${AppRoutePath.learn}/:chapterId',
          builder: (context, state) {
            final chapterId = state.pathParameters['chapterId']!;
            return TopicListPage(chapter: LearningPlanData.byId(chapterId));
          },
          routes: [
            /// 三级页面：具体演示页面
            GoRoute(
              name: AppRouteName.topicDemo,
              path: ':topicIndex',
              builder: (context, state) {
                final chapterId = state.pathParameters['chapterId']!;
                final topicIndex =
                    int.parse(state.pathParameters['topicIndex']!);
                return LearningPlanData.byId(chapterId)
                    .topics[topicIndex]
                    .demoPage;
              },
            ),
          ],
        ),

        /// 二级页面：自定义导航条演示
        GoRoute(
          name: AppRouteName.navBarDemo,
          path: AppRoutePath.navBarDemo,
          builder: (context, state) => const NavBarDemoPage(),
        ),
    
        /// 二级页面：Riverpod 模块列表
        GoRoute(
          name: AppRouteName.riverpodHome,
          path: AppRoutePath.riverpod,
          builder: (context, state) => const RiverpodHomePage(),
          routes: [
            /// 三级页面：具体演示页面
            GoRoute(
              name: AppRouteName.riverpodDemo,
              path: ':demoId',
              builder: (context, state) {
                final demoId = state.pathParameters['demoId']!;
                final demo = RiverpodDemoData.byId(demoId);
                if (demo == null) {
                  return Scaffold(
                    appBar: AppBar(title: const Text('未找到')),
                    body: const Center(child: Text('未找到对应的演示页面')),
                  );
                }
                return demo.demoPage;
              },
            ),
          ],
        ),

        /// 二级页面：网络组件演示
        GoRoute(
          name: AppRouteName.networkDemo,
          path: AppRoutePath.networkDemo,
          builder: (context, state) => const NetworkDemoPage(),
        ),

        /// 二级页面：BLE 蓝牙插件演示
        GoRoute(
          name: AppRouteName.bleDemo,
          path: AppRoutePath.bleDemo,
          builder: (context, state) => const BleDemoPage(),
        ),

        /// 二级页面：Bloc 模块列表
        GoRoute(
          name: AppRouteName.blocHome,
          path: AppRoutePath.bloc,
          builder: (context, state) => const BlocHomePage(),
          routes: [
            /// 三级页面：具体演示页面
            GoRoute(
              name: AppRouteName.blocDemo,
              path: ':demoId',
              builder: (context, state) {
                final demoId = state.pathParameters['demoId']!;
                final demo = BlocDemoData.byId(demoId);
                if (demo == null) {
                  return Scaffold(
                    appBar: AppBar(title: const Text('未找到')),
                    body: const Center(child: Text('未找到对应的演示页面')),
                  );
                }
                return demo.demoPage;
              },
            ),
          ],
        ),

        /// 登录对比模块：Bloc 版登录页面
        GoRoute(
          name: AppRouteName.loginBloc,
          path: '${AppRoutePath.login}/bloc',
          builder: (context, state) => const BlocLoginPage(),
        ),

        /// 登录对比模块：Riverpod 版登录页面
        GoRoute(
          name: AppRouteName.loginRiverpod,
          path: '${AppRoutePath.login}/riverpod',
          builder: (context, state) => const RiverpodLoginPage(),
        ),
      ],
    );

/// 底部导航栏 Shell 容器
///
/// 仅在 Tab 根页面可见。当用户通过 `context.push` 进入 `/learn/...` 子页面时，
/// 子页面运行在根导航器上，全屏覆盖本 Shell（包括 AppBar 和底部导航栏），
/// 返回后自动回到之前的 Tab 且 Tab 状态保持不变。
class _MainShell extends StatelessWidget {
  const _MainShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final currentTab = tabConfigs[navigationShell.currentIndex];

    return Scaffold(
      appBar: AppBar(title: Text(currentTab.label)),
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          // 切换到目标 Tab；若点击的是当前 Tab 则重置到该 Tab 的初始页面
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: [
          for (final tab in tabConfigs)
            NavigationDestination(
              icon: Icon(tab.icon),
              selectedIcon: Icon(tab.selectedIcon),
              label: tab.label,
            ),
        ],
      ),
    );
  }
}
