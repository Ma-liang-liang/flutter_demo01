import CoreBluetooth
import Flutter
import UIKit

/// ble_plugin 的 iOS 入口。
///
/// 职责：注册方法通道与事件通道，将方法调用转发给 [BleCentralManager]。
/// 原生端只做 BLE 底层桥接，所有业务逻辑（协议、状态机、重连等）
/// 都在 Flutter 层实现。
public class BlePlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  /// 方法通道名（与 Dart 端一致）。
  static let methodChannelName = "ble_plugin/methods"

  /// 事件通道名（与 Dart 端一致）。
  static let eventChannelName = "ble_plugin/events"

  /// BLE 桥接管理器（CoreBluetooth 封装）。
  private let centralManager = BleCentralManager()

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = BlePlugin()

    let methodChannel = FlutterMethodChannel(
      name: methodChannelName,
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(instance, channel: methodChannel)

    let eventChannel = FlutterEventChannel(
      name: eventChannelName,
      binaryMessenger: registrar.messenger()
    )
    eventChannel.setStreamHandler(instance)
  }

  // MARK: - FlutterMethodCallHandler

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]

    switch call.method {
    case "configure":
      centralManager.configure(
        restorationIdentifier: args["restorationIdentifier"] as? String
      )
      result(nil)

    case "startScan":
      centralManager.startScan(
        serviceUUIDs: args["serviceUUIDs"] as? [String],
        allowDuplicates: args["allowDuplicates"] as? Bool ?? false
      )
      result(nil)

    case "stopScan":
      centralManager.stopScan()
      result(nil)

    case "connect":
      guard let deviceId = args["deviceId"] as? String else {
        result(FlutterError(code: "invalidArgs", message: "deviceId is required", details: nil))
        return
      }
      let timeoutMs = args["timeoutMs"] as? Int ?? 8000
      centralManager.connect(
        deviceId: deviceId,
        timeout: TimeInterval(timeoutMs) / 1000.0,
        result: result
      )

    case "disconnect":
      guard let deviceId = args["deviceId"] as? String else {
        result(FlutterError(code: "invalidArgs", message: "deviceId is required", details: nil))
        return
      }
      centralManager.disconnect(deviceId: deviceId)
      result(nil)

    case "discoverServices":
      guard let deviceId = args["deviceId"] as? String else {
        result(FlutterError(code: "invalidArgs", message: "deviceId is required", details: nil))
        return
      }
      centralManager.discoverServices(
        deviceId: deviceId,
        serviceUUIDs: args["serviceUUIDs"] as? [String]
      )
      result(nil)

    case "discoverCharacteristics":
      guard let deviceId = args["deviceId"] as? String,
            let serviceId = args["serviceId"] as? String else {
        result(FlutterError(code: "invalidArgs", message: "deviceId/serviceId are required", details: nil))
        return
      }
      centralManager.discoverCharacteristics(
        deviceId: deviceId,
        serviceId: serviceId,
        characteristicUUIDs: args["characteristicUUIDs"] as? [String]
      )
      result(nil)

    case "readValue":
      guard let deviceId = args["deviceId"] as? String,
            let serviceId = args["serviceId"] as? String,
            let characteristicId = args["characteristicId"] as? String else {
        result(FlutterError(code: "invalidArgs", message: "deviceId/serviceId/characteristicId are required", details: nil))
        return
      }
      centralManager.readValue(
        deviceId: deviceId,
        serviceId: serviceId,
        characteristicId: characteristicId
      )
      result(nil)

    case "writeValue":
      guard let deviceId = args["deviceId"] as? String,
            let serviceId = args["serviceId"] as? String,
            let characteristicId = args["characteristicId"] as? String,
            let value = args["value"] as? FlutterStandardTypedData else {
        result(FlutterError(code: "invalidArgs", message: "deviceId/serviceId/characteristicId/value are required", details: nil))
        return
      }
      let writeWithResponse = args["writeWithResponse"] as? Bool ?? false
      centralManager.writeValue(
        deviceId: deviceId,
        serviceId: serviceId,
        characteristicId: characteristicId,
        value: value.data,
        writeWithResponse: writeWithResponse,
        result: result
      )

    case "setNotifyValue":
      guard let deviceId = args["deviceId"] as? String,
            let serviceId = args["serviceId"] as? String,
            let characteristicId = args["characteristicId"] as? String else {
        result(FlutterError(code: "invalidArgs", message: "deviceId/serviceId/characteristicId are required", details: nil))
        return
      }
      centralManager.setNotifyValue(
        deviceId: deviceId,
        serviceId: serviceId,
        characteristicId: characteristicId,
        enabled: args["enabled"] as? Bool ?? true
      )
      result(nil)

    case "requestMtu":
      guard let deviceId = args["deviceId"] as? String else {
        result(FlutterError(code: "invalidArgs", message: "deviceId is required", details: nil))
        return
      }
      // iOS 上 CoreBluetooth 自动协商 MTU，无主动请求 API，
      // 返回当前实际最大写入长度对应的 MTU 近似值。
      result(centralManager.currentMtuApprox(deviceId: deviceId))

    case "maximumWriteLength":
      guard let deviceId = args["deviceId"] as? String else {
        result(FlutterError(code: "invalidArgs", message: "deviceId is required", details: nil))
        return
      }
      let withResponse = args["withResponse"] as? Bool ?? false
      result(centralManager.maximumWriteLength(deviceId: deviceId, withResponse: withResponse))

    case "retrieveKnownPeripherals":
      let identifiers = (args["identifiers"] as? [String] ?? []).compactMap { UUID(uuidString: $0) }
      result(centralManager.retrieveKnownPeripherals(identifiers: identifiers))

    case "retrieveConnectedPeripherals":
      let serviceUUIDs = (args["serviceUUIDs"] as? [String] ?? []).compactMap { CBUUID(string: $0) }
      result(centralManager.retrieveConnectedPeripherals(serviceUUIDs: serviceUUIDs))

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - FlutterStreamHandler

  public func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    centralManager.eventSink = events
    // 重放最近一次适配器状态，避免 Dart 层订阅晚于初始化上报导致状态丢失
    centralManager.emitCachedState()
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    centralManager.eventSink = nil
    return nil
  }
}
