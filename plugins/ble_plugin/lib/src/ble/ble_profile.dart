/// 蓝牙通信的"协议画像"体系与连接状态机。
///
/// 对应 iOS 参考实现中的 `BluetoothProfile.swift`：
/// 1. `BluetoothCharacteristicRole` —— 用业务角色代替裸 UUID，降低耦合
/// 2. `BluetoothCharacteristicProfile` —— 单个特征在设备协议中的完整定义
/// 3. `BluetoothDeviceProfile` —— 一类硬件设备的蓝牙协议画像
/// 4. `BluetoothConnectionState` —— 连接状态机（sealed class，模式匹配友好）
library;

/// 特征的业务角色。
///
/// 线上项目不要直接到处传 characteristic UUID，而是通过角色表达
/// "这条通道用来干什么"，后续换硬件协议时 App 层更稳。
enum BluetoothCharacteristicRole {
  /// 命令写入通道，用于发送简短指令（如 PING、开关灯等）。
  commandWrite,

  /// 数据写入通道，用于发送大块数据（如文件、OTA 固件包等）。
  dataWrite,

  /// 通知监听通道，外设通过此通道主动推送数据给 App。
  notify,

  /// 只读通道，App 主动读取外设的值。
  read;

  /// 从平台字符串解析角色。
  static BluetoothCharacteristicRole? fromName(String? name) {
    switch (name) {
      case 'commandWrite':
        return BluetoothCharacteristicRole.commandWrite;
      case 'dataWrite':
        return BluetoothCharacteristicRole.dataWrite;
      case 'notify':
        return BluetoothCharacteristicRole.notify;
      case 'read':
        return BluetoothCharacteristicRole.read;
      default:
        return null;
    }
  }
}

/// 特征属性集合，描述一个特征支持的操作能力。
enum BluetoothCharacteristicProperty {
  /// 可读。
  read,

  /// 可写（withResponse）。
  write,

  /// 可写（withoutResponse）。
  writeWithoutResponse,

  /// 支持通知。
  notify,

  /// 支持指示。
  indicate;

  /// 从平台字符串解析属性。
  static BluetoothCharacteristicProperty? fromName(String? name) {
    switch (name) {
      case 'read':
        return BluetoothCharacteristicProperty.read;
      case 'write':
        return BluetoothCharacteristicProperty.write;
      case 'writeWithoutResponse':
        return BluetoothCharacteristicProperty.writeWithoutResponse;
      case 'notify':
        return BluetoothCharacteristicProperty.notify;
      case 'indicate':
        return BluetoothCharacteristicProperty.indicate;
      default:
        return null;
    }
  }
}

/// 写入方式。
enum BleWriteType {
  /// 需要外设确认，更可靠，吞吐较低。
  withResponse,

  /// 无需外设确认，更快，适合高频数据。
  withoutResponse;

  /// 平台通道传输用的字符串。
  String get wireName => name;
}

/// 单个特征在设备协议中的定义。
///
/// 描述了某个特征的 UUID、所属服务、是否需要订阅通知以及偏好写入方式。
class BluetoothCharacteristicProfile {
  /// 该特征的业务角色。
  final BluetoothCharacteristicRole role;

  /// 所属服务的 UUID。
  final String serviceUuid;

  /// 特征自身的 UUID。
  final String characteristicUuid;

  /// 是否需要订阅 notify/indicate。
  final bool enableNotify;

  /// 偏好的写入方式（withResponse 更可靠，withoutResponse 更快）。
  final BleWriteType? preferredWriteType;

  const BluetoothCharacteristicProfile({
    required this.role,
    required this.serviceUuid,
    required this.characteristicUuid,
    this.enableNotify = false,
    this.preferredWriteType,
  });
}

/// 一类硬件设备的蓝牙协议画像。
///
/// 生产中建议每类设备都配置明确的 service/characteristic，而不是
/// 全量发现。这样可以：减少扫描耗电、加快连接速度、避免发现无关特征。
class BluetoothDeviceProfile {
  /// 画像名称，用于日志和调试。
  final String name;

  /// 扫描时过滤的 service UUID，null 表示全量扫描。
  final List<String>? scanServiceUuids;

  /// 连接后需要发现的服务列表，null 表示发现全部服务。
  final List<String>? serviceUuids;

  /// 该设备画像包含的所有特征定义。
  final List<BluetoothCharacteristicProfile> characteristics;

  const BluetoothDeviceProfile({
    required this.name,
    this.scanServiceUuids,
    this.serviceUuids,
    this.characteristics = const [],
  });

  /// 根据角色查找对应的特征画像。
  BluetoothCharacteristicProfile? characteristicFor(
    BluetoothCharacteristicRole role,
  ) {
    for (final c in characteristics) {
      if (c.role == role) return c;
    }
    return null;
  }

  /// 获取某个服务下所有需要发现的特征 UUID。
  /// 该服务下没有定义特征时返回 null（表示发现全部）。
  List<String>? characteristicUuidsFor(String serviceUuid) {
    final uuids = characteristics
        .where((c) => c.serviceUuid.toLowerCase() == serviceUuid.toLowerCase())
        .map((c) => c.characteristicUuid)
        .toList();
    return uuids.isEmpty ? null : uuids;
  }

  /// 根据实际发现的 service/characteristic UUID 反查业务角色。
  BluetoothCharacteristicRole? roleFor({
    required String serviceUuid,
    required String characteristicUuid,
  }) {
    for (final c in characteristics) {
      if (c.serviceUuid.toLowerCase() == serviceUuid.toLowerCase() &&
          c.characteristicUuid.toLowerCase() == characteristicUuid.toLowerCase()) {
        return c.role;
      }
    }
    return null;
  }

  /// 通用演示模式：允许全量扫描和自动选择第一个可用特征。
  /// 这只适合 Demo/调试；线上业务应替换成明确 UUID 的 profile。
  static const genericDemo = BluetoothDeviceProfile(
    name: 'Generic BLE Demo',
    scanServiceUuids: null,
    serviceUuids: null,
    characteristics: [],
  );
}

/// 蓝牙适配器（系统级）状态。
enum BleAdapterState {
  /// 状态未知。
  unknown,

  /// 正在重置。
  resetting,

  /// 当前平台不支持蓝牙。
  unsupported,

  /// 未授权使用蓝牙。
  unauthorized,

  /// 蓝牙已关闭。
  poweredOff,

  /// 蓝牙已开启，可正常使用。
  poweredOn;

  /// 从平台状态码解析（两端约定的 int 码）。
  static BleAdapterState fromCode(int code) {
    switch (code) {
      case 0:
        return BleAdapterState.unknown;
      case 1:
        return BleAdapterState.resetting;
      case 2:
        return BleAdapterState.unsupported;
      case 3:
        return BleAdapterState.unauthorized;
      case 4:
        return BleAdapterState.poweredOff;
      case 5:
        return BleAdapterState.poweredOn;
      default:
        return BleAdapterState.unknown;
    }
  }
}

/// 蓝牙连接的状态机，贯穿整个连接生命周期。
///
/// 状态流转：
/// ```text
/// idle → scanning → connecting → discovering → ready → disconnecting → disconnected
/// ```
/// 异常路径：任意状态 → `FailedState` / `ReconnectingState`
sealed class BluetoothConnectionState {
  const BluetoothConnectionState();

  /// 空闲，未开始任何操作。
  const factory BluetoothConnectionState.idle() = IdleState;

  /// 正在扫描附近设备。
  const factory BluetoothConnectionState.scanning() = ScanningState;

  /// 正在连接指定设备（参数为设备标识符）。
  const factory BluetoothConnectionState.connecting(String deviceId) =
      ConnectingState;

  /// 已连接，正在发现服务和特征。
  const factory BluetoothConnectionState.discovering(String deviceId) =
      DiscoveringState;

  /// 服务和特征已就绪，可以开始数据传输。
  const factory BluetoothConnectionState.ready(String deviceId) = ReadyState;

  /// 正在断开连接。
  const factory BluetoothConnectionState.disconnecting(String deviceId) =
      DisconnectingState;

  /// 已断开连接（参数可能为 null 表示无记录的设备）。
  const factory BluetoothConnectionState.disconnected([String? deviceId]) =
      DisconnectedState;

  /// 正在重连（设备标识符和当前重试次数）。
  const factory BluetoothConnectionState.reconnecting(
    String deviceId,
    int attempt,
  ) = ReconnectingState;

  /// 连接失败（错误描述）。
  const factory BluetoothConnectionState.failed(String message) = FailedState;
}

/// 空闲状态。
class IdleState extends BluetoothConnectionState {
  const IdleState();

  @override
  String toString() => 'BluetoothConnectionState.idle';
}

/// 扫描中状态。
class ScanningState extends BluetoothConnectionState {
  const ScanningState();

  @override
  String toString() => 'BluetoothConnectionState.scanning';
}

/// 连接中状态。
class ConnectingState extends BluetoothConnectionState {
  final String deviceId;

  const ConnectingState(this.deviceId);

  @override
  String toString() => 'BluetoothConnectionState.connecting($deviceId)';
}

/// 服务发现中状态。
class DiscoveringState extends BluetoothConnectionState {
  final String deviceId;

  const DiscoveringState(this.deviceId);

  @override
  String toString() => 'BluetoothConnectionState.discovering($deviceId)';
}

/// 就绪状态（可传输）。
class ReadyState extends BluetoothConnectionState {
  final String deviceId;

  const ReadyState(this.deviceId);

  @override
  String toString() => 'BluetoothConnectionState.ready($deviceId)';
}

/// 断开中状态。
class DisconnectingState extends BluetoothConnectionState {
  final String deviceId;

  const DisconnectingState(this.deviceId);

  @override
  String toString() => 'BluetoothConnectionState.disconnecting($deviceId)';
}

/// 已断开状态。
class DisconnectedState extends BluetoothConnectionState {
  final String? deviceId;

  const DisconnectedState([this.deviceId]);

  @override
  String toString() => 'BluetoothConnectionState.disconnected($deviceId)';
}

/// 重连中状态。
class ReconnectingState extends BluetoothConnectionState {
  final String deviceId;
  final int attempt;

  const ReconnectingState(this.deviceId, this.attempt);

  @override
  String toString() =>
      'BluetoothConnectionState.reconnecting($deviceId, attempt: $attempt)';
}

/// 失败状态。
class FailedState extends BluetoothConnectionState {
  final String message;

  const FailedState(this.message);

  @override
  String toString() => 'BluetoothConnectionState.failed($message)';
}
