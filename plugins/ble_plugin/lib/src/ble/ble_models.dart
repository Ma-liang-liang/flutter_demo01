/// 蓝牙数据模型定义。
///
/// 对应 iOS 参考实现中的 `BluetoothDevice`、`BluetoothTransferConfiguration`、
/// `BluetoothMetricSnapshot`、`BluetoothPacketProgress`，采用纯 Dart 实现，
/// 不依赖任何平台对象（原生端通过 deviceId 字符串标识设备）。
library;

import 'ble_profile.dart';

/// 扫描发现的或已连接的蓝牙设备模型。
class BluetoothDevice {
  /// 系统分配的唯一标识符（iOS: UUID 字符串，Android: MAC 地址）。
  final String identifier;

  /// 设备名称。
  final String name;

  /// 信号强度（dBm），值越接近 0 信号越强。
  final int rssi;

  const BluetoothDevice({
    required this.identifier,
    required this.name,
    this.rssi = 0,
  });

  /// 只通过 identifier 判等，避免同一设备因 RSSI 变化而重复。
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BluetoothDevice && other.identifier == identifier;

  @override
  int get hashCode => identifier.hashCode;

  @override
  String toString() => 'BluetoothDevice(identifier: $identifier, name: $name, rssi: $rssi)';

  /// 从平台事件字典解析设备模型。
  factory BluetoothDevice.fromMap(Map<Object?, Object?> map) {
    return BluetoothDevice(
      identifier: map['id'] as String,
      name: (map['name'] as String?) ?? 'Unknown Device',
      rssi: (map['rssi'] as int?) ?? 0,
    );
  }
}

/// 蓝牙传输全局配置。
class BluetoothTransferConfiguration {
  /// 设备协议画像（扫描过滤 UUID、服务/特征定义等）。
  final BluetoothDeviceProfile profile;

  /// 扫描超时时间（秒），超时后自动停止扫描。
  final double scanTimeout;

  /// 连接超时时间（秒），超时后取消连接并报错。
  final double connectTimeout;

  /// 最大重连次数。
  final int reconnectMaxAttempts;

  /// 重连基础延迟（秒），实际延迟按指数退避：baseDelay × 2^(attempt-1)。
  final double reconnectBaseDelay;

  /// 状态恢复标识符，用于 iOS 上 App 被系统杀掉后恢复蓝牙连接。
  final String restorationIdentifier;

  /// 传输进度回调节流间隔（毫秒），避免高频回调卡顿主线程。
  /// 设为 0 则禁用节流（每次 ACK 都回调）。
  final int progressThrottleMs;

  /// 是否输出插件调试日志（默认关闭，零输出）。
  ///
  /// 线上包默认无任何日志（debugPrint 在 release 构建下本身也是 no-op）；
  /// 排查问题时临时置为 true，可在控制台看到关键节点日志。
  final bool enableLogging;

  const BluetoothTransferConfiguration({
    this.profile = BluetoothDeviceProfile.genericDemo,
    this.scanTimeout = 10,
    this.connectTimeout = 8,
    this.reconnectMaxAttempts = 5,
    this.reconnectBaseDelay = 1,
    this.restorationIdentifier = 'com.example.ble_plugin.central.restore',
    this.progressThrottleMs = 100,
    this.enableLogging = false,
  });

  /// 复制当前配置并替换指定字段。
  BluetoothTransferConfiguration copyWith({
    BluetoothDeviceProfile? profile,
    double? scanTimeout,
    double? connectTimeout,
    int? reconnectMaxAttempts,
    double? reconnectBaseDelay,
    String? restorationIdentifier,
    int? progressThrottleMs,
    bool? enableLogging,
  }) {
    return BluetoothTransferConfiguration(
      profile: profile ?? this.profile,
      scanTimeout: scanTimeout ?? this.scanTimeout,
      connectTimeout: connectTimeout ?? this.connectTimeout,
      reconnectMaxAttempts: reconnectMaxAttempts ?? this.reconnectMaxAttempts,
      reconnectBaseDelay: reconnectBaseDelay ?? this.reconnectBaseDelay,
      restorationIdentifier:
          restorationIdentifier ?? this.restorationIdentifier,
      progressThrottleMs: progressThrottleMs ?? this.progressThrottleMs,
      enableLogging: enableLogging ?? this.enableLogging,
    );
  }
}

/// 传输进度模型，记录已发送和总字节数。
class BluetoothPacketProgress {
  /// 已确认发送（ACK）的字节数。
  final int sentBytes;

  /// 本次传输的总字节数。
  final int totalBytes;

  const BluetoothPacketProgress({
    required this.sentBytes,
    required this.totalBytes,
  });

  /// 传输完成比例 [0, 1]。
  double get ratio => totalBytes > 0 ? sentBytes / totalBytes : 0;

  @override
  String toString() => 'BluetoothPacketProgress($sentBytes/$totalBytes)';
}

/// 蓝牙连接与传输的运行时指标快照，用于 UI 展示和性能分析。
class BluetoothMetricSnapshot {
  /// 连接开始的时间戳。
  final DateTime? connectStartedAt;

  /// 特征就绪（可传输）的时间戳。
  final DateTime? readyAt;

  /// 已尝试重连的次数。
  final int reconnectAttempts;

  /// 已发送的字节数。
  final int transmittedBytes;

  /// 已接收的字节数。
  final int receivedBytes;

  /// 最近一次扫描到的 RSSI 信号强度。
  final int? lastRSSI;

  /// 当前外设支持的最大写入长度。
  final int maximumWriteLength;

  const BluetoothMetricSnapshot({
    this.connectStartedAt,
    this.readyAt,
    this.reconnectAttempts = 0,
    this.transmittedBytes = 0,
    this.receivedBytes = 0,
    this.lastRSSI,
    this.maximumWriteLength = 20,
  });

  /// 从开始连接到特征就绪的耗时（毫秒），用于评估连接性能。
  Duration? get connectionCost {
    final start = connectStartedAt;
    final ready = readyAt;
    if (start == null || ready == null) return null;
    return ready.difference(start);
  }

  /// 复制当前快照并替换指定字段。
  BluetoothMetricSnapshot copyWith({
    DateTime? connectStartedAt,
    DateTime? readyAt,
    int? reconnectAttempts,
    int? transmittedBytes,
    int? receivedBytes,
    int? lastRSSI,
    int? maximumWriteLength,
    bool clearReadyAt = false,
  }) {
    return BluetoothMetricSnapshot(
      connectStartedAt: connectStartedAt ?? this.connectStartedAt,
      readyAt: clearReadyAt ? null : (readyAt ?? this.readyAt),
      reconnectAttempts: reconnectAttempts ?? this.reconnectAttempts,
      transmittedBytes: transmittedBytes ?? this.transmittedBytes,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      lastRSSI: lastRSSI ?? this.lastRSSI,
      maximumWriteLength: maximumWriteLength ?? this.maximumWriteLength,
    );
  }

  @override
  String toString() =>
      'BluetoothMetricSnapshot(tx: $transmittedBytes, rx: $receivedBytes, '
      'reconnects: $reconnectAttempts, rssi: $lastRSSI, mtu: $maximumWriteLength)';
}
