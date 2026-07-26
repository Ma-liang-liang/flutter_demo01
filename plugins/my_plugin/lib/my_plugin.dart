import 'package:flutter/services.dart';

/// 一个简单的 Flutter 插件示例
///
/// 通过 MethodChannel 与原生平台代码（Android / iOS）通信。
///
/// 三端通过「通道名 + 方法名」约定接口：
/// - 通道名: 'my_plugin'（三端必须完全一致）
/// - Dart 端: 本文件（发起调用）
/// - Android: android/src/main/kotlin/com/example/my_plugin/MyPlugin.kt
/// - iOS:     ios/my_plugin/Sources/my_plugin/MyPlugin.swift
class MyPlugin {
  /// 方法通道：Dart 与原生代码互相调用的"桥梁"
  static const MethodChannel _channel = MethodChannel('my_plugin');

  /// 获取平台版本（无参数的方法调用）
  static Future<String?> getPlatformVersion() async {
    final version = await _channel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  /// 两数相加（带参数的方法调用，参数以 Map 传递）
  static Future<int?> add(int a, int b) async {
    final result = await _channel.invokeMethod<int>('add', {'a': a, 'b': b});
    return result;
  }

  /// 打招呼（传递字符串参数）
  static Future<String?> greet(String name) async {
    final result = await _channel.invokeMethod<String>('greet', {'name': name});
    return result;
  }
}
