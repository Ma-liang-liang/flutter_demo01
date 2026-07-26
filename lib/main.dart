import 'package:flutter/material.dart';

import 'pages/animation_interaction_page.dart';
import 'pages/basic_widgets_page.dart';
import 'pages/form_widgets_page.dart';
import 'pages/layout_widgets_page.dart';
import 'pages/plugin_test_page.dart';
import 'utils/theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter 组件演示',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const MainScaffold(),
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  static const _pages = <Widget>[
    BasicWidgetsPage(),
    FormWidgetsPage(),
    LayoutWidgetsPage(),
    AnimationInteractionPage(),
    PluginTestPage(),
  ];

  static const _titles = ['基础组件', '表单组件', '布局组件', '动画交互', '原生插件'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_currentIndex])),
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.widgets_outlined),
            selectedIcon: Icon(Icons.widgets),
            label: '基础组件',
          ),
          NavigationDestination(
            icon: Icon(Icons.edit_note_outlined),
            selectedIcon: Icon(Icons.edit_note),
            label: '表单组件',
          ),
          NavigationDestination(
            icon: Icon(Icons.view_quilt_outlined),
            selectedIcon: Icon(Icons.view_quilt),
            label: '布局组件',
          ),
          NavigationDestination(
            icon: Icon(Icons.animation_outlined),
            selectedIcon: Icon(Icons.animation),
            label: '动画交互',
          ),
          NavigationDestination(
            icon: Icon(Icons.extension_outlined),
            selectedIcon: Icon(Icons.extension),
            label: '原生插件',
          ),
        ],
      ),
    );
  }
}
