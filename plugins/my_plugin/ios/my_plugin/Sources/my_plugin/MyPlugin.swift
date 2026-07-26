import Flutter
import UIKit

/// MyPlugin —— iOS 原生端实现
///
/// 负责接收 Dart 端通过 MethodChannel 发来的方法调用，执行原生逻辑后返回结果。
/// 通道名与方法名必须和 Dart 端（lib/my_plugin.dart）完全一致。
public class MyPlugin: NSObject, FlutterPlugin {
  /// 注册入口：App 启动时由 GeneratedPluginRegistrant 自动调用（无需手动调用）
  public static func register(with registrar: FlutterPluginRegistrar) {
    // 通道名必须与 Dart 端 MethodChannel('my_plugin') 一致
    let channel = FlutterMethodChannel(name: "my_plugin", binaryMessenger: registrar.messenger())
    let instance = MyPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  /// 处理来自 Dart 的方法调用
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    // 获取平台版本（无参数）
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)

    // 两数相加（从字典中取参数）
    case "add":
      let args = call.arguments as? [String: Int] ?? [:]
      let a = args["a"] ?? 0
      let b = args["b"] ?? 0
      result(a + b)

    // 打招呼（取字符串参数）
    case "greet":
      let args = call.arguments as? [String: String] ?? [:]
      let name = args["name"] ?? "朋友"
      result("你好，\(name)！这是来自 iOS 的问候 👋")

    // 未实现的方法要显式告知，否则 Dart 端会一直等待
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
