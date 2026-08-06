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

// 2. 监听事件
manager.addDelegate(myDelegate);

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

// 可靠传输（返回传输 ID）
final transferId = await manager.sendReliableData(data);

// 取消传输（不断开连接）
await manager.cancelTransfer();
```

## 主要 API

| 方法 | 说明 |
|------|------|
| `BluetoothManager.shared.init()` | 初始化原生端并订阅事件流 |
| `startScan()` | 扫描附近 BLE 设备 |
| `connect(device)` | 连接设备，开启自动重连 |
| `disconnect()` | 断开连接（不触发自动重连） |
| `sendRaw(data)` | 裸数据写入（调试用） |
| `sendReliableData(data)` | 可靠传输（帧头 + CRC + ACK），返回传输 ID |
| `readValue()` | 读取特征值（结果通过 `onDataReceived` 回调） |
| `cancelTransfer()` | 取消当前传输（不断开连接） |
| `addDelegate(delegate)` | 添加事件监听者（弱引用持有） |

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

覆盖 CRC32 正确性、帧拆分、编解码往返、ACK 窗口、重试去重、断点续传、超时定时器清理。
