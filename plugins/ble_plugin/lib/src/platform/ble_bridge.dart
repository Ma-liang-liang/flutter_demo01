/// 平台桥接抽象层。
///
/// 原生端（iOS Swift / Android Kotlin）只做 BLE 底层桥接，暴露最小
/// 操作集合；所有业务逻辑（协议、状态机、重连、断点续传）都在 Dart 层。
///
/// 通道约定（三端必须一致）：
/// - 方法通道：`ble_plugin/methods`
/// - 事件通道：`ble_plugin/events`
library;

import 'dart:async';

import 'package:flutter/services.dart';

import 'ble_bridge_events.dart';

/// 平台桥接异常（MethodChannel 调用失败时抛出）。
///
/// 将 Flutter SDK 的 [PlatformException] 转换为本异常，使上层
/// 可统一通过 `catch (PlatformBridgeException)` 捕获平台错误。
class PlatformBridgeException implements Exception {
  /// 错误码（如 `missingPermission`、`invalidArgs` 等）。
  final String code;

  /// 错误描述。
  final String message;

  /// 原始详情数据。
  final Object? details;

  const PlatformBridgeException(this.code, this.message, {this.details});

  /// 从 Flutter SDK 的 [PlatformException] 构造。
  factory PlatformBridgeException.fromPlatformException(PlatformException e) {
    return PlatformBridgeException(e.code, e.message ?? 'Unknown platform error',
        details: e.details);
  }

  @override
  String toString() => 'PlatformBridgeException($code): $message';
}

/// 平台桥接接口。
///
/// 通过 [BleBridge.instance] 获取实现，测试时可注入 mock。
abstract class BleBridge {
  /// 当前平台的桥接实现。
  static BleBridge instance = const MethodChannelBleBridge();

  /// 配置并初始化原生蓝牙中心管理器（iOS 传入状态恢复标识符）。
  Future<void> configure({required String restorationIdentifier});

  /// 开始扫描附近 BLE 设备。
  ///
  /// - [serviceUuids]: 过滤的 service UUID，null 表示全量扫描
  /// - [allowDuplicates]: 是否允许重复上报同一设备
  Future<void> startScan({
    List<String>? serviceUuids,
    bool allowDuplicates = false,
  });

  /// 停止扫描。
  Future<void> stopScan();

  /// 连接指定设备（原生端负责底层连接与超时取消）。
  Future<void> connect(String deviceId, {required Duration timeout});

  /// 断开连接。
  Future<void> disconnect(String deviceId);

  /// 发现指定设备上的服务。
  Future<void> discoverServices(String deviceId, {List<String>? serviceUuids});

  /// 发现指定服务下的特征。
  Future<void> discoverCharacteristics(
    String deviceId,
    String serviceId, {
    List<String>? characteristicUuids,
  });

  /// 读取特征值（结果通过 characteristicValueChanged 事件返回）。
  Future<void> readValue(
    String deviceId,
    String serviceId,
    String characteristicId,
  );

  /// 写入特征值。
  ///
  /// 返回 true 表示底层仍可继续写入（用于 iOS 的 withoutResponse 缓冲
  /// 控制；Android 始终返回 true）。
  Future<bool> writeValue(
    String deviceId,
    String serviceId,
    String characteristicId,
    List<int> value, {
    required bool writeWithResponse,
  });

  /// 订阅/取消订阅特征通知。
  Future<void> setNotifyValue(
    String deviceId,
    String serviceId,
    String characteristicId, {
    required bool enabled,
  });

  /// 请求协商 MTU（Android 生效；iOS 自动协商，返回当前值）。
  Future<int> requestMtu(String deviceId, int mtu);

  /// 查询当前最大写入长度。
  Future<int> maximumWriteLength(String deviceId, {required bool withResponse});

  /// 从系统缓存检索已知外设（之前连接过的设备）。
  Future<List<Map<String, Object?>>> retrieveKnownPeripherals(
    List<String> identifiers,
  );

  /// 检索当前已通过系统连接的外设。
  Future<List<Map<String, Object?>>> retrieveConnectedPeripherals(
    List<String> serviceUuids,
  );

  /// 原生底层事件流。
  Stream<BleBridgeEvent> events();
}

/// MethodChannel 实现，负责与原生端通信。
class MethodChannelBleBridge implements BleBridge {
  static const MethodChannel _methodChannel =
      MethodChannel('ble_plugin/methods');
  static const EventChannel _eventChannel = EventChannel('ble_plugin/events');

  /// 事件流（延迟订阅，避免重复监听）。
  static Stream<BleBridgeEvent>? _cachedStream;

  const MethodChannelBleBridge();

  /// 调用方法通道，将 [PlatformException] 转换为 [PlatformBridgeException]。
  Future<T?> _invoke<T>(String method, [Map<String, dynamic>? arguments]) async {
    try {
      return await _methodChannel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (e) {
      throw PlatformBridgeException.fromPlatformException(e);
    }
  }

  /// 调用方法通道（返回 List），将 [PlatformException] 转换为 [PlatformBridgeException]。
  Future<List<T>> _invokeList<T>(String method, [Map<String, dynamic>? arguments]) async {
    try {
      return await _methodChannel.invokeListMethod<T>(method, arguments) ?? [];
    } on PlatformException catch (e) {
      throw PlatformBridgeException.fromPlatformException(e);
    }
  }

  @override
  Future<void> configure({required String restorationIdentifier}) async {
    await _invoke<void>('configure', {
      'restorationIdentifier': restorationIdentifier,
    });
  }

  @override
  Future<void> startScan({
    List<String>? serviceUuids,
    bool allowDuplicates = false,
  }) async {
    await _invoke<void>('startScan', {
      'serviceUUIDs': serviceUuids,
      'allowDuplicates': allowDuplicates,
    });
  }

  @override
  Future<void> stopScan() async {
    await _invoke<void>('stopScan');
  }

  @override
  Future<void> connect(String deviceId, {required Duration timeout}) async {
    await _invoke<void>('connect', {
      'deviceId': deviceId,
      'timeoutMs': timeout.inMilliseconds,
    });
  }

  @override
  Future<void> disconnect(String deviceId) async {
    await _invoke<void>('disconnect', {
      'deviceId': deviceId,
    });
  }

  @override
  Future<void> discoverServices(
    String deviceId, {
    List<String>? serviceUuids,
  }) async {
    await _invoke<void>('discoverServices', {
      'deviceId': deviceId,
      'serviceUUIDs': serviceUuids,
    });
  }

  @override
  Future<void> discoverCharacteristics(
    String deviceId,
    String serviceId, {
    List<String>? characteristicUuids,
  }) async {
    await _invoke<void>('discoverCharacteristics', {
      'deviceId': deviceId,
      'serviceId': serviceId,
      'characteristicUUIDs': characteristicUuids,
    });
  }

  @override
  Future<void> readValue(
    String deviceId,
    String serviceId,
    String characteristicId,
  ) async {
    await _invoke<void>('readValue', {
      'deviceId': deviceId,
      'serviceId': serviceId,
      'characteristicId': characteristicId,
    });
  }

  @override
  Future<bool> writeValue(
    String deviceId,
    String serviceId,
    String characteristicId,
    List<int> value, {
    required bool writeWithResponse,
  }) async {
    final result = await _invoke<bool>('writeValue', {
      'deviceId': deviceId,
      'serviceId': serviceId,
      'characteristicId': characteristicId,
      'value': value,
      'writeWithResponse': writeWithResponse,
    });
    return result ?? true;
  }

  @override
  Future<void> setNotifyValue(
    String deviceId,
    String serviceId,
    String characteristicId, {
    required bool enabled,
  }) async {
    await _invoke<void>('setNotifyValue', {
      'deviceId': deviceId,
      'serviceId': serviceId,
      'characteristicId': characteristicId,
      'enabled': enabled,
    });
  }

  @override
  Future<int> requestMtu(String deviceId, int mtu) async {
    final result = await _invoke<int>('requestMtu', {
      'deviceId': deviceId,
      'mtu': mtu,
    });
    return result ?? 0;
  }

  @override
  Future<int> maximumWriteLength(
    String deviceId, {
    required bool withResponse,
  }) async {
    final result = await _invoke<int>(
      'maximumWriteLength',
      {
        'deviceId': deviceId,
        'withResponse': withResponse,
      },
    );
    return result ?? 20;
  }

  @override
  Future<List<Map<String, Object?>>> retrieveKnownPeripherals(
    List<String> identifiers,
  ) async {
    final result = await _invokeList<Map<Object?, Object?>>(
      'retrieveKnownPeripherals',
      {'identifiers': identifiers},
    );
    return [
      for (final item in result)
        Map<String, Object?>.from(item),
    ];
  }

  @override
  Future<List<Map<String, Object?>>> retrieveConnectedPeripherals(
    List<String> serviceUuids,
  ) async {
    final result = await _invokeList<Map<Object?, Object?>>(
      'retrieveConnectedPeripherals',
      {'serviceUUIDs': serviceUuids},
    );
    return [
      for (final item in result)
        Map<String, Object?>.from(item),
    ];
  }

  @override
  Stream<BleBridgeEvent> events() {
    return _cachedStream ??= _eventChannel
        .receiveBroadcastStream()
        .where((event) => event is Map<Object?, Object?>)
        .map((event) => BleBridgeEvent.fromMap(event as Map<Object?, Object?>))
        .where((event) => event != null)
        .cast<BleBridgeEvent>()
        .handleError((Object error) {
      // 原生端事件流出错时重置缓存，允许后续重新订阅。
      _cachedStream = null;
    });
  }
}
