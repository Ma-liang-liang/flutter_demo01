/// 蓝牙操作可能产生的错误。
///
/// 对应 iOS 参考实现中的 `BluetoothError`，纯 Dart 实现。
library;

import 'ble_profile.dart';

/// 蓝牙操作可能产生的错误。
enum BluetoothErrorType {
  /// 蓝牙不可用（如关闭、未授权等）。
  bluetoothUnavailable,

  /// 找不到指定外设。
  peripheralNotFound,

  /// 指定角色的特征尚未就绪。
  characteristicNotReady,

  /// 已有传输正在进行，无法同时发起第二个。
  transferInProgress,

  /// 连接超时。
  connectTimeout,

  /// 数据包 ACK 超时。
  ackTimeout,

  /// 特征不支持任何写入方式。
  unsupportedWriteType,

  /// 当前 MTU 太小，无法容纳应用层帧头。
  mtuTooSmall,

  /// 平台层错误（原生桥接返回的错误）。
  platformError,

  /// 蓝牙适配器未开启（扫描/连接前检查）。
  adapterPoweredOff,
}

/// 蓝牙错误，携带类型与描述信息。
class BluetoothError implements Exception {
  /// 错误类型。
  final BluetoothErrorType type;

  /// 错误描述。
  final String message;

  /// 关联的上下文（如 ACK 超时的序号、特征角色等）。
  final Map<String, Object>? details;

  const BluetoothError._(this.type, this.message, {this.details});

  factory BluetoothError.bluetoothUnavailable(BleAdapterState state) =>
      BluetoothError._(
        BluetoothErrorType.bluetoothUnavailable,
        'Bluetooth is unavailable: $state',
      );

  factory BluetoothError.adapterPoweredOff() => BluetoothError._(
        BluetoothErrorType.adapterPoweredOff,
        'Bluetooth adapter is powered off.',
      );

  const BluetoothError.peripheralNotFound()
      : this._(BluetoothErrorType.peripheralNotFound,
            'Bluetooth peripheral was not found.');

  factory BluetoothError.characteristicNotReady(
    BluetoothCharacteristicRole role,
  ) =>
      BluetoothError._(
        BluetoothErrorType.characteristicNotReady,
        'Bluetooth characteristic is not ready: ${role.name}',
        details: {'role': role.name},
      );

  const BluetoothError.transferInProgress()
      : this._(BluetoothErrorType.transferInProgress,
            'Another Bluetooth transfer is still running.');

  const BluetoothError.connectTimeout()
      : this._(BluetoothErrorType.connectTimeout,
            'Bluetooth connection timed out.');

  factory BluetoothError.ackTimeout(int sequence) => BluetoothError._(
        BluetoothErrorType.ackTimeout,
        'Bluetooth packet ACK timed out: $sequence',
        details: {'sequence': sequence},
      );

  const BluetoothError.unsupportedWriteType()
      : this._(BluetoothErrorType.unsupportedWriteType,
            'Characteristic does not support a valid write type.');

  factory BluetoothError.mtuTooSmall(int maximumWriteLength) =>
      BluetoothError._(
        BluetoothErrorType.mtuTooSmall,
        'Current BLE MTU is too small for application frame: '
            '$maximumWriteLength',
        details: {'maximumWriteLength': maximumWriteLength},
      );

  /// 平台层错误（原生桥接返回的错误）。
  factory BluetoothError.platformError(String message, [Object? details]) =>
      BluetoothError._(
        BluetoothErrorType.platformError,
        'Platform error: $message',
        details: details is Map<String, Object>
            ? details
            : (details == null ? null : {'detail': details}),
      );

  /// 从平台返回的 map 解析错误（原生端 errors 返回值格式约定）。
  factory BluetoothError.fromPlatformMap(Map<Object?, Object?> map) {
    final message = (map['message'] as String?) ?? 'Unknown platform error';
    final code = (map['code'] as String?) ?? 'platformError';
    if (code == 'connectTimeout') return const BluetoothError.connectTimeout();
    if (code == 'peripheralNotFound') {
      return const BluetoothError.peripheralNotFound();
    }
    return BluetoothError.platformError(message, map);
  }

  @override
  String toString() => 'BluetoothError(${type.name}): $message';
}
