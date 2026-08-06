package com.example.ble_plugin

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * ble_plugin 的 Android 入口。
 *
 * 职责：注册方法通道与事件通道，将方法调用转发给 [BleCentralManager]。
 * 原生端只做 BLE 底层桥接，所有业务逻辑（协议、状态机、重连等）
 * 都在 Flutter 层实现。
 */
class BlePlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {

    /** 方法通道名（与 Dart 端一致）。 */
    private val methodChannelName = "ble_plugin/methods"

    /** 事件通道名（与 Dart 端一致）。 */
    private val eventChannelName = "ble_plugin/events"

    private var centralManager: BleCentralManager? = null
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var applicationContext: Context? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        centralManager = BleCentralManager(binding.applicationContext)

        methodChannel = MethodChannel(binding.binaryMessenger, methodChannelName)
        methodChannel?.setMethodCallHandler(this)

        eventChannel = EventChannel(binding.binaryMessenger, eventChannelName)
        eventChannel?.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()

        when (call.method) {
            "configure" -> {
                centralManager?.configure(
                    restorationIdentifier = args["restorationIdentifier"] as? String,
                )
                result.success(null)
            }

            "startScan" -> {
                if (!hasScanPermission()) {
                    result.error(
                        "missingPermission",
                        "Bluetooth scan permission is not granted.",
                        null,
                    )
                    return
                }
                centralManager?.startScan(
                    serviceUuids = args["serviceUUIDs"] as? List<String>,
                    allowDuplicates = args["allowDuplicates"] as? Boolean ?: false,
                )
                result.success(null)
            }

            "stopScan" -> {
                centralManager?.stopScan()
                result.success(null)
            }

            "connect" -> {
                val deviceId = args["deviceId"] as? String
                if (deviceId == null) {
                    result.error("invalidArgs", "deviceId is required", null)
                    return
                }
                if (!hasConnectPermission()) {
                    result.error(
                        "missingPermission",
                        "Bluetooth connect permission is not granted.",
                        null,
                    )
                    return
                }
                centralManager?.connect(
                    deviceId = deviceId,
                    timeoutMs = args["timeoutMs"] as? Int ?: 8000,
                    result = result,
                )
            }

            "disconnect" -> {
                val deviceId = args["deviceId"] as? String
                if (deviceId == null) {
                    result.error("invalidArgs", "deviceId is required", null)
                    return
                }
                centralManager?.disconnect(deviceId)
                result.success(null)
            }

            "discoverServices" -> {
                val deviceId = args["deviceId"] as? String
                if (deviceId == null) {
                    result.error("invalidArgs", "deviceId is required", null)
                    return
                }
                centralManager?.discoverServices(
                    deviceId = deviceId,
                    serviceUuids = args["serviceUUIDs"] as? List<String>,
                )
                result.success(null)
            }

            "discoverCharacteristics" -> {
                val deviceId = args["deviceId"] as? String
                val serviceId = args["serviceId"] as? String
                if (deviceId == null || serviceId == null) {
                    result.error("invalidArgs", "deviceId/serviceId are required", null)
                    return
                }
                centralManager?.discoverCharacteristics(
                    deviceId = deviceId,
                    serviceId = serviceId,
                    characteristicUUIDs = args["characteristicUUIDs"] as? List<String>,
                )
                result.success(null)
            }

            "readValue" -> {
                val deviceId = args["deviceId"] as? String
                val serviceId = args["serviceId"] as? String
                val characteristicId = args["characteristicId"] as? String
                if (deviceId == null || serviceId == null || characteristicId == null) {
                    result.error(
                        "invalidArgs",
                        "deviceId/serviceId/characteristicId are required",
                        null,
                    )
                    return
                }
                if (!hasConnectPermission()) {
                    result.error(
                        "missingPermission",
                        "Bluetooth connect permission is not granted.",
                        null,
                    )
                    return
                }
                centralManager?.readValue(deviceId, serviceId, characteristicId)
                result.success(null)
            }

            "writeValue" -> {
                val deviceId = args["deviceId"] as? String
                val serviceId = args["serviceId"] as? String
                val characteristicId = args["characteristicId"] as? String
                val value = args["value"] as? ByteArray
                if (deviceId == null || serviceId == null || characteristicId == null || value == null) {
                    result.error(
                        "invalidArgs",
                        "deviceId/serviceId/characteristicId/value are required",
                        null,
                    )
                    return
                }
                if (!hasConnectPermission()) {
                    result.error(
                        "missingPermission",
                        "Bluetooth connect permission is not granted.",
                        null,
                    )
                    return
                }
                val canContinue = centralManager?.writeValue(
                    deviceId = deviceId,
                    serviceId = serviceId,
                    characteristicId = characteristicId,
                    value = value,
                    writeWithResponse = args["writeWithResponse"] as? Boolean ?: false,
                ) ?: true
                result.success(canContinue)
            }

            "setNotifyValue" -> {
                val deviceId = args["deviceId"] as? String
                val serviceId = args["serviceId"] as? String
                val characteristicId = args["characteristicId"] as? String
                if (deviceId == null || serviceId == null || characteristicId == null) {
                    result.error(
                        "invalidArgs",
                        "deviceId/serviceId/characteristicId are required",
                        null,
                    )
                    return
                }
                if (!hasConnectPermission()) {
                    result.error(
                        "missingPermission",
                        "Bluetooth connect permission is not granted.",
                        null,
                    )
                    return
                }
                centralManager?.setNotifyValue(
                    deviceId = deviceId,
                    serviceId = serviceId,
                    characteristicId = characteristicId,
                    enabled = args["enabled"] as? Boolean ?: true,
                )
                result.success(null)
            }

            "requestMtu" -> {
                val deviceId = args["deviceId"] as? String
                if (deviceId == null) {
                    result.error("invalidArgs", "deviceId is required", null)
                    return
                }
                val mtu = centralManager?.requestMtu(
                    deviceId = deviceId,
                    mtu = args["mtu"] as? Int ?: 512,
                ) ?: 0
                result.success(mtu)
            }

            "maximumWriteLength" -> {
                val deviceId = args["deviceId"] as? String
                if (deviceId == null) {
                    result.error("invalidArgs", "deviceId is required", null)
                    return
                }
                val length = centralManager?.maximumWriteLength(
                    deviceId = deviceId,
                    withResponse = args["withResponse"] as? Boolean ?: false,
                ) ?: 20
                result.success(length)
            }

            "retrieveKnownPeripherals" -> {
                if (!hasConnectPermission()) {
                    result.error(
                        "missingPermission",
                        "Bluetooth connect permission is not granted.",
                        null,
                    )
                    return
                }
                val devices = centralManager?.retrieveKnownPeripherals(
                    identifiers = args["identifiers"] as? List<String> ?: emptyList(),
                ) ?: emptyList<Map<String, Any?>>()
                result.success(devices)
            }

            "retrieveConnectedPeripherals" -> {
                if (!hasConnectPermission()) {
                    result.error(
                        "missingPermission",
                        "Bluetooth connect permission is not granted.",
                        null,
                    )
                    return
                }
                val devices = centralManager?.retrieveConnectedPeripherals(
                    serviceUuids = args["serviceUUIDs"] as? List<String> ?: emptyList(),
                ) ?: emptyList<Map<String, Any?>>()
                result.success(devices)
            }

            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        centralManager?.eventSink = events
        // 重放最近一次适配器状态，避免 Dart 层订阅晚于初始化上报导致状态丢失
        centralManager?.emitCachedState()
    }

    override fun onCancel(arguments: Any?) {
        centralManager?.eventSink = null
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        eventChannel?.setStreamHandler(null)
        eventChannel = null
        centralManager?.onDestroy()
        centralManager = null
        applicationContext = null
    }

    // MARK: - 权限检查

    /** API 31+ 需要 BLUETOOTH_SCAN；API 30- 需要 ACCESS_FINE_LOCATION。 */
    private fun hasScanPermission(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            checkPermission(Manifest.permission.BLUETOOTH_SCAN)
        } else {
            checkPermission(Manifest.permission.ACCESS_FINE_LOCATION)
        }

    /** API 31+ 需要 BLUETOOTH_CONNECT；API 30- 无需运行时权限。 */
    private fun hasConnectPermission(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            checkPermission(Manifest.permission.BLUETOOTH_CONNECT)
        } else {
            true
        }

    private fun checkPermission(permission: String): Boolean =
        applicationContext?.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED
}
