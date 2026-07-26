import 'package:flutter/material.dart';
import 'package:my_plugin/my_plugin.dart';

import '../widgets/section_card.dart';

/// Tab5: 原生插件测试页面
///
/// 演示通过 MethodChannel 调用原生平台（Android / iOS）代码。
/// 插件源码位于 plugins/my_plugin 目录，包含三端实现：
/// - Dart:    plugins/my_plugin/lib/my_plugin.dart
/// - Android: plugins/my_plugin/android/.../MyPlugin.kt
/// - iOS:     plugins/my_plugin/ios/.../MyPlugin.swift
class PluginTestPage extends StatefulWidget {
  const PluginTestPage({super.key});

  @override
  State<PluginTestPage> createState() => _PluginTestPageState();
}

class _PluginTestPageState extends State<PluginTestPage> {
  String _platformVersion = '点击右侧按钮获取';
  String _addResult = '点击右侧按钮计算';
  String _greetResult = '点击右侧按钮问候';

  /// 调用插件的 getPlatformVersion（无参）
  Future<void> _getPlatformVersion() async {
    try {
      final version = await MyPlugin.getPlatformVersion();
      setState(() => _platformVersion = version ?? '获取失败');
    } catch (e) {
      setState(() => _platformVersion = '出错: $e');
    }
  }

  /// 调用插件的 add（传参 18 + 24）
  Future<void> _add() async {
    try {
      final result = await MyPlugin.add(18, 24);
      setState(() => _addResult = '18 + 24 = $result（原生计算）');
    } catch (e) {
      setState(() => _addResult = '出错: $e');
    }
  }

  /// 调用插件的 greet（传字符串参数）
  Future<void> _greet() async {
    try {
      final result = await MyPlugin.greet('Flutter 学习者');
      setState(() => _greetResult = result ?? '问候失败');
    } catch (e) {
      setState(() => _greetResult = '出错: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          title: 'MethodChannel 调用原生代码',
          subtitle: '插件源码: plugins/my_plugin',
          icon: Icons.extension,
          child: Column(
            children: [
              _PluginMethodRow(
                label: '获取平台版本',
                hint: '无参数调用',
                value: _platformVersion,
                buttonLabel: '获取',
                onPressed: _getPlatformVersion,
              ),
              const Divider(height: 24),
              _PluginMethodRow(
                label: '原生加法',
                hint: '传递 int 参数',
                value: _addResult,
                buttonLabel: '计算 18+24',
                onPressed: _add,
              ),
              const Divider(height: 24),
              _PluginMethodRow(
                label: '原生问候',
                hint: '传递 String 参数',
                value: _greetResult,
                buttonLabel: '打招呼',
                onPressed: _greet,
              ),
            ],
          ),
        ),
        SectionCard(
          title: '工作原理',
          subtitle: 'Dart ↔ 原生 通信流程',
          icon: Icons.info_outline,
          child: const Text(
            '1. Dart 端通过 MethodChannel(\'my_plugin\') 发起 invokeMethod 调用\n'
            '2. 消息经二进制信使（BinaryMessenger）传到原生端\n'
            '3. Android 的 onMethodCall / iOS 的 handle 根据方法名分发处理\n'
            '4. 原生执行完通过 result.success(...) 把结果返回给 Dart\n\n'
            '提示：切换 iOS 模拟器和 Android 模拟器分别运行，'
            '能看到"平台版本"返回不同的系统信息。',
          ),
        ),
      ],
    );
  }
}

/// 单个插件方法演示行：标题 + 结果展示 + 触发按钮
class _PluginMethodRow extends StatelessWidget {
  const _PluginMethodRow({
    required this.label,
    required this.hint,
    required this.value,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String label;
  final String hint;
  final String value;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.titleSmall),
                  Text(
                    hint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.tonal(
              onPressed: onPressed,
              child: Text(buttonLabel),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(value, style: theme.textTheme.bodyLarge),
        ),
      ],
    );
  }
}
