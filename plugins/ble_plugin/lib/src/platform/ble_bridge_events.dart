/// 平台桥接事件模型。
///
/// 原生端（iOS Swift / Android Kotlin）通过 EventChannel 上报底层 BLE
/// 事件，本文件负责将其解析为类型安全的 Dart 事件对象，供
/// `BluetoothManager` 消费。原生端只做桥接，不包含任何业务逻辑。
library;

import 'dart:typed_data';

import '../ble/ble_profile.dart';

/// 原生上报的服务信息。
class BleServiceInfo {
  /// 服务 UUID。
  final String uuid;

  /// 服务下的特征列表。
  final List<BleCharacteristicInfo> characteristics;

  const BleServiceInfo({required this.uuid, required this.characteristics});

  factory BleServiceInfo.fromMap(Map<Object?, Object?> map) {
    return BleServiceInfo(
      uuid: (map['uuid'] as String?) ?? '',
      characteristics: [
        for (final item in (map['characteristics'] as List<Object?>? ?? []))
          if (item is Map<Object?, Object?>)
            BleCharacteristicInfo.fromMap(item),
      ],
    );
  }
}

/// 原生上报的特征信息。
class BleCharacteristicInfo {
  /// 特征 UUID。
  final String uuid;

  /// 特征属性列表（read / write / writeWithoutResponse / notify / indicate）。
  final Set<BluetoothCharacteristicProperty> properties;

  /// 当前是否已订阅通知。
  final bool isNotifying;

  const BleCharacteristicInfo({
    required this.uuid,
    required this.properties,
    this.isNotifying = false,
  });

  factory BleCharacteristicInfo.fromMap(Map<Object?, Object?> map) {
    final properties = <BluetoothCharacteristicProperty>{};
    for (final name in (map['properties'] as List<Object?>? ?? [])) {
      final property = BluetoothCharacteristicProperty.fromName(
        name is String ? name : null,
      );
      if (property != null) properties.add(property);
    }
    return BleCharacteristicInfo(
      uuid: (map['uuid'] as String?) ?? '',
      properties: properties,
      isNotifying: (map['isNotifying'] as bool?) ?? false,
    );
  }
}

/// 平台桥接事件（sealed class，支持模式匹配）。
sealed class BleBridgeEvent {
  const BleBridgeEvent();

  /// 从事件通道的 map 解析事件。
  ///
  /// 事件统一格式：`{event: <事件名>, ...字段}`。
  /// 解析失败返回 null（忽略未知事件，向前兼容）。
  static BleBridgeEvent? fromMap(Map<Object?, Object?> map) {
    final event = map['event'] as String?;
    switch (event) {
      case 'stateChanged':
        final code = map['state'] as int? ?? 0;
        return BleStateChangedEvent(BleAdapterState.fromCode(code));
      case 'deviceDiscovered':
        return BleDeviceDiscoveredEvent.fromMap(map);
      case 'connectionChanged':
        return BleConnectionChangedEvent.fromMap(map);
      case 'servicesDiscovered':
        return BleServicesDiscoveredEvent.fromMap(map);
      case 'characteristicValueChanged':
        return BleCharacteristicValueChangedEvent.fromMap(map);
      case 'writeCompleted':
        return BleWriteCompletedEvent.fromMap(map);
      case 'readFailed':
        return BleReadFailedEvent.fromMap(map);
      case 'readyToWrite':
        return BleReadyToWriteEvent.fromMap(map);
      case 'mtuChanged':
        return BleMtuChangedEvent.fromMap(map);
      case 'stateRestored':
        return BleStateRestoredEvent.fromMap(map);
      default:
        return null;
    }
  }
}

/// 蓝牙适配器状态变化事件。
class BleStateChangedEvent extends BleBridgeEvent {
  final BleAdapterState state;

  const BleStateChangedEvent(this.state);
}

/// 扫描发现设备事件。
class BleDeviceDiscoveredEvent extends BleBridgeEvent {
  final String deviceId;
  final String name;
  final int rssi;

  const BleDeviceDiscoveredEvent({
    required this.deviceId,
    required this.name,
    required this.rssi,
  });

  factory BleDeviceDiscoveredEvent.fromMap(Map<Object?, Object?> map) {
    return BleDeviceDiscoveredEvent(
      deviceId: (map['id'] as String?) ?? '',
      name: (map['name'] as String?) ?? 'Unknown Device',
      rssi: (map['rssi'] as int?) ?? 0,
    );
  }
}

/// 底层连接状态变化事件。
///
/// [state] 取值：connected / disconnected / failed。
class BleConnectionChangedEvent extends BleBridgeEvent {
  final String deviceId;
  final String state;
  final String? error;

  const BleConnectionChangedEvent({
    required this.deviceId,
    required this.state,
    this.error,
  });

  factory BleConnectionChangedEvent.fromMap(Map<Object?, Object?> map) {
    return BleConnectionChangedEvent(
      deviceId: (map['deviceId'] as String?) ?? '',
      state: (map['state'] as String?) ?? 'disconnected',
      error: map['error'] as String?,
    );
  }
}

/// 服务（及特征）发现完成事件。
///
/// 原生端在特征发现完成后上报该服务的信息（含特征列表）。
class BleServicesDiscoveredEvent extends BleBridgeEvent {
  final String deviceId;
  final BleServiceInfo service;

  const BleServicesDiscoveredEvent({
    required this.deviceId,
    required this.service,
  });

  factory BleServicesDiscoveredEvent.fromMap(Map<Object?, Object?> map) {
    final serviceMap = map['service'];
    return BleServicesDiscoveredEvent(
      deviceId: (map['deviceId'] as String?) ?? '',
      service: serviceMap is Map<Object?, Object?>
          ? BleServiceInfo.fromMap(serviceMap)
          : const BleServiceInfo(uuid: '', characteristics: []),
    );
  }
}

/// 特征值更新事件（notify 推送 / read 响应均触发）。
class BleCharacteristicValueChangedEvent extends BleBridgeEvent {
  final String deviceId;
  final String serviceId;
  final String characteristicId;
  final Uint8List value;

  const BleCharacteristicValueChangedEvent({
    required this.deviceId,
    required this.serviceId,
    required this.characteristicId,
    required this.value,
  });

  factory BleCharacteristicValueChangedEvent.fromMap(
    Map<Object?, Object?> map,
  ) {
    final value = map['value'];
    return BleCharacteristicValueChangedEvent(
      deviceId: (map['deviceId'] as String?) ?? '',
      serviceId: (map['serviceId'] as String?) ?? '',
      characteristicId: (map['characteristicId'] as String?) ?? '',
      value: value is Uint8List
          ? value
          : (value is List<Object?>
              ? Uint8List.fromList(value.cast<int>())
              : Uint8List(0)),
    );
  }
}

/// 写入完成事件（仅 withResponse 模式触发；iOS 的 withoutResponse 失败也会上报）。
class BleWriteCompletedEvent extends BleBridgeEvent {
  final String deviceId;
  final String serviceId;
  final String characteristicId;
  final String? error;

  const BleWriteCompletedEvent({
    required this.deviceId,
    required this.serviceId,
    required this.characteristicId,
    this.error,
  });

  factory BleWriteCompletedEvent.fromMap(Map<Object?, Object?> map) {
    return BleWriteCompletedEvent(
      deviceId: (map['deviceId'] as String?) ?? '',
      serviceId: (map['serviceId'] as String?) ?? '',
      characteristicId: (map['characteristicId'] as String?) ?? '',
      error: map['error'] as String?,
    );
  }
}

/// 读操作失败事件（readCharacteristic 失败或 didUpdateValueFor 带错误时触发）。
///
/// 与 [BleWriteCompletedEvent] 区分：读操作错误不应干扰写入传输队列。
class BleReadFailedEvent extends BleBridgeEvent {
  final String deviceId;
  final String serviceId;
  final String characteristicId;
  final String? error;

  const BleReadFailedEvent({
    required this.deviceId,
    required this.serviceId,
    required this.characteristicId,
    this.error,
  });

  factory BleReadFailedEvent.fromMap(Map<Object?, Object?> map) {
    return BleReadFailedEvent(
      deviceId: (map['deviceId'] as String?) ?? '',
      serviceId: (map['serviceId'] as String?) ?? '',
      characteristicId: (map['characteristicId'] as String?) ?? '',
      error: map['error'] as String?,
    );
  }
}

/// 外设可以再次接受 withoutResponse 写入事件。
class BleReadyToWriteEvent extends BleBridgeEvent {
  final String deviceId;

  const BleReadyToWriteEvent(this.deviceId);

  factory BleReadyToWriteEvent.fromMap(Map<Object?, Object?> map) {
    return BleReadyToWriteEvent((map['deviceId'] as String?) ?? '');
  }
}

/// MTU 变化事件（Android 的 requestMtu 响应）。
class BleMtuChangedEvent extends BleBridgeEvent {
  final String deviceId;
  final int mtu;

  const BleMtuChangedEvent({required this.deviceId, required this.mtu});

  factory BleMtuChangedEvent.fromMap(Map<Object?, Object?> map) {
    return BleMtuChangedEvent(
      deviceId: (map['deviceId'] as String?) ?? '',
      mtu: (map['mtu'] as int?) ?? 0,
    );
  }
}

/// iOS 状态恢复事件（App 被系统杀掉后重新启动时恢复之前的连接）。
class BleStateRestoredEvent extends BleBridgeEvent {
  final String deviceId;

  const BleStateRestoredEvent(this.deviceId);

  factory BleStateRestoredEvent.fromMap(Map<Object?, Object?> map) {
    return BleStateRestoredEvent((map['deviceId'] as String?) ?? '');
  }
}
