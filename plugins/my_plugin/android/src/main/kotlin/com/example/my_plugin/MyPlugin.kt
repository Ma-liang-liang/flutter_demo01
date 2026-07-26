package com.example.my_plugin

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * MyPlugin —— Android 原生端实现
 *
 * 负责接收 Dart 端通过 MethodChannel 发来的方法调用，执行原生逻辑后返回结果。
 * 通道名与方法名必须和 Dart 端（lib/my_plugin.dart）完全一致。
 */
class MyPlugin : FlutterPlugin, MethodCallHandler {
    // 与 Flutter 引擎通信的方法通道引用
    private lateinit var channel: MethodChannel

    // 插件挂载到引擎时回调（相当于 iOS 的 register(with:)）
    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        // 通道名必须与 Dart 端 MethodChannel('my_plugin') 一致
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "my_plugin")
        channel.setMethodCallHandler(this)
    }

    // 处理来自 Dart 的方法调用
    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            // 获取平台版本（无参数）
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }
            // 两数相加（从 Map 中取参数）
            "add" -> {
                val a = call.argument<Int>("a") ?: 0
                val b = call.argument<Int>("b") ?: 0
                result.success(a + b)
            }
            // 打招呼（取字符串参数）
            "greet" -> {
                val name = call.argument<String>("name") ?: "朋友"
                result.success("你好，$name！这是来自 Android 的问候 👋")
            }
            // 未实现的方法要显式告知，否则 Dart 端会一直等待
            else -> {
                result.notImplemented()
            }
        }
    }

    // 插件从引擎卸载时回调，清理通道
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
