# ble_plugin

跨平台 BLE 蓝牙插件：所有业务逻辑在 Dart 层实现（应用层协议、可靠传输、断点续传、自动重连、指标统计），原生端（iOS Swift / Android Kotlin）只做底层桥接。

## 架构

```
┌─────────────────────────────────────────────────────┐
│                   Flutter (Dart)                     │
│  ┌───────────────┐  ┌──────────────┐  ┌───────────┐ │
│  │ BluetoothManager│ │ ProtocolCodec │ │ ActiveTransfer│ │
│  │  (状态机/重连)  │  │ (帧/CRC32)   │  │ (ACK窗口) │ │
│  └───────┬───────┘  └──────────────┘  └───────────┘ │
│          │ BleBridge (抽象接口, 可注入 mock)            │
├──────────┼──────────────────────────────────────────┤
│    MethodChannel          EventChannel               │
│  ble_plugin/methods    ble_plugin/events             │
├──────────┼──────────────────────────────────────────┤
│          ▼                                          │
│  ┌──────────────┐         ┌──────────────────┐      │
│  │  iOS Swift   │         │  Android Kotlin   │     │
│  │ CoreBluetooth│         │ BluetoothGatt     │     │
│  └──────────────┘         └──────────────────┘      │
└─────────────────────────────────────────────────────┘
```

## 快速开始

```dart
import 'package:ble_plugin/ble_plugin.dart';

// 1. 初始化
final manager = BluetoothManager.shared;
await manager.init();

// 2. 监听事件（Stream 订阅即得当前值，流永不主动关闭）
manager.connectionStateStream.listen((state) { ... });
manager.scanResultsStream.listen((devices) { ... });
manager.dataStream.listen((data) { ... });
manager.errorStream.listen((error) { ... });
manager.transferEventsStream.listen((event) { ... });

// 3. 配置设备协议画像
await manager.updateConfiguration(BluetoothTransferConfiguration(
  profile: BluetoothDeviceProfile(
    name: 'My Device',
    scanServiceUuids: ['FFF0'],
    serviceUuids: ['FFF0'],
    characteristics: [
      BluetoothCharacteristicProfile(
        role: BluetoothCharacteristicRole.commandWrite,
        serviceUuid: 'FFF0',
        characteristicUuid: 'FFF1',
      ),
      BluetoothCharacteristicProfile(
        role: BluetoothCharacteristicRole.notify,
        serviceUuid: 'FFF0',
        characteristicUuid: 'FFF2',
        enableNotify: true,
      ),
    ],
  ),
));

// 4. 扫描 → 连接 → 传输
await manager.startScan();
await manager.connect(device);

// 可靠传输（字符串直传，UTF-8 编码；返回传输 ID）
final transferId = await manager.sendReliableString('hello device');
// 或传原始字节
// final transferId = await manager.sendReliableData(bytes);

// 取消传输（不断开连接）
await manager.cancelTransfer();
```

## Stream API

所有状态与事件均通过响应式 Stream 对外通知（参考 flutter_blue_plus 风格）：

| 流 | 说明 |
|------|------|
| `adapterStateStream` | 蓝牙适配器状态 |
| `connectionStateStream` | 连接状态机（scanning / connecting / ready ...） |
| `scanResultsStream` | 扫描结果快照（按 RSSI 降序） |
| `currentDeviceStream` | 当前连接设备（断开后推送 null） |
| `characteristicRolesStream` | 已就绪的特征角色集合 |
| `dataStream` | 收到外设数据（应用层帧已剥离帧头） |
| `errorStream` | 错误通知 |
| `metricsStream` | 运行时指标（收发字节 / RSSI / MTU / 重连次数） |
| `progressStream` | 传输进度（节流频率可配置） |
| `transferEventsStream` | 传输生命周期（completed / paused / resumed） |

订阅即得当前值（BehaviorSubject 语义），页面重建后不丢状态；`dispose()` 后订阅会收到最近值并正常结束。

## 主要 API

| 方法 | 说明 |
|------|------|
| `BluetoothManager.shared.init()` | 初始化原生端并订阅事件流 |
| `startScan()` | 扫描附近 BLE 设备 |
| `connect(device)` | 连接设备，开启自动重连 |
| `disconnect()` | 断开连接（不触发自动重连） |
| `sendRaw(data)` | 裸数据写入（调试用，兼容 Uint8List） |
| `sendRawString(text)` | 裸数据写入（字符串直传，UTF-8 编码） |
| `sendReliableData(data)` | 可靠传输（帧头 + CRC + ACK），返回传输 ID |
| `sendReliableString(text)` | 可靠传输（字符串直传），返回传输 ID |
| `readValue()` | 读取特征值（结果通过 `dataStream` 推送） |
| `cancelTransfer()` | 取消当前传输（不断开连接） |

大数据自动分包：按 MTU 切帧（每包带序号 + CRC32）、ACK 窗口限速、失败仅重发对应包、断点续传从已确认偏移恢复。

## 应用层协议

帧布局（大端序）：

```
| magic(2B) | version(1B) | type(1B) | sequence(4B) | offset(4B) | totalLength(4B) | payloadLen(2B) | crc32(4B) | payload(NB) |
| 0xA55A    | 0x01        |          |              |            |                 |               |          |             |
```

- 头部固定 22 字节，payload 长度可变
- CRC32 使用多项式 `0xEDB88320`（IEEE 802.3 标准）
- 帧类型：data / ack / complete / resumeRequest

## 平台要求

### iOS
- iOS 13.0+
- `Info.plist` 需声明 `NSBluetoothAlwaysUsageDescription`
- 启用状态恢复需在 `Info.plist` 声明 `UIBackgroundModes: [bluetooth-central]`
  （插件会自动探测宿主声明，未声明时降级为不启用状态恢复）

### Android
- minSdk 24, compileSdk 36
- 运行时权限由宿主 App 负责申请：
  - API 31+：`BLUETOOTH_SCAN`、`BLUETOOTH_CONNECT`
  - API ≤30：`ACCESS_FINE_LOCATION`

## 测试

```bash
cd plugins/ble_plugin
flutter test
```

覆盖 CRC32 正确性、帧拆分、编解码往返、ACK 窗口、重试去重、断点续传、超时定时器清理、Stream 行为（初始值重放 / 各流推送 / 帧头剥离 / dispose 后订阅）。
