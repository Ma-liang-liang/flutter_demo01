/// Stream API 行为测试。
///
/// 验证 `BluetoothManager` 的响应式通知层（参考 flutter_blue_plus 风格）：
/// - 订阅即得当前值（初始状态重放）
/// - 各条流的事件推送（状态 / 扫描结果 / 连接 / 数据 / 错误 / 传输）
/// - 应用层帧剥离帧头后才推送，ACK 帧不推送
///
/// Stream 是独立事件源，不依赖 delegate；测试通过 [FakeBleBridge]
/// 注入事件，完全在内存中运行。
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:ble_plugin/ble_plugin.dart';
import 'package:flutter_test/flutter_test.dart';

/// 可注入的假桥接：记录方法调用、手动触发底层事件。
class FakeBleBridge implements BleBridge {
  final StreamController<BleBridgeEvent> _events =
      StreamController<BleBridgeEvent>.broadcast();

  /// 已调用的方法名列表（如 startScan / connect / writeValue）。
  final List<String> calls = [];

  /// 模拟的最大写入长度。
  int maxWriteLength = 512;

  /// 手动触发一个原生事件。
  void emit(BleBridgeEvent event) => _events.add(event);

  @override
  Future<void> configure({required String restorationIdentifier}) async {
    calls.add('configure');
  }

  @override
  Future<void> startScan({
    List<String>? serviceUuids,
    bool allowDuplicates = false,
  }) async {
    calls.add('startScan');
  }

  @override
  Future<void> stopScan() async {
    calls.add('stopScan');
  }

  @override
  Future<void> connect(String deviceId, {required Duration timeout}) async {
    calls.add('connect');
  }

  @override
  Future<void> disconnect(String deviceId) async {
    calls.add('disconnect');
  }

  @override
  Future<void> discoverServices(
    String deviceId, {
    List<String>? serviceUuids,
  }) async {
    calls.add('discoverServices');
  }

  @override
  Future<void> discoverCharacteristics(
    String deviceId,
    String serviceId, {
    List<String>? characteristicUuids,
  }) async {
    calls.add('discoverCharacteristics');
  }

  @override
  Future<void> readValue(
    String deviceId,
    String serviceId,
    String characteristicId,
  ) async {
    calls.add('readValue');
  }

  @override
  Future<bool> writeValue(
    String deviceId,
    String serviceId,
    String characteristicId,
    List<int> value, {
    required bool writeWithResponse,
  }) async {
    calls.add('writeValue');
    return true;
  }

  @override
  Future<void> setNotifyValue(
    String deviceId,
    String serviceId,
    String characteristicId, {
    required bool enabled,
  }) async {
    calls.add('setNotifyValue');
  }

  @override
  Future<int> requestMtu(String deviceId, int mtu) async {
    calls.add('requestMtu');
    return 512;
  }

  @override
  Future<int> maximumWriteLength(
    String deviceId, {
    required bool withResponse,
  }) async {
    return maxWriteLength;
  }

  @override
  Future<List<Map<String, Object?>>> retrieveKnownPeripherals(
    List<String> identifiers,
  ) async {
    return [];
  }

  @override
  Future<List<Map<String, Object?>>> retrieveConnectedPeripherals(
    List<String> serviceUuids,
  ) async {
    return [];
  }

  @override
  Stream<BleBridgeEvent> events() => _events.stream;
}

/// 构造一个含特征的服务发现事件（用于角色匹配与就绪）。
BleServicesDiscoveredEvent serviceWithCharacteristic({
  required String deviceId,
  String serviceId = 'FFF0',
  String characteristicId = 'FFF1',
  List<String> properties = const ['writeWithoutResponse', 'notify'],
}) {
  return BleServicesDiscoveredEvent(
    deviceId: deviceId,
    service: BleServiceInfo(
      uuid: serviceId,
      characteristics: [
        BleCharacteristicInfo(
          uuid: characteristicId,
          properties: {
            for (final p in properties)
              if (BluetoothCharacteristicProperty.fromName(p) != null)
                BluetoothCharacteristicProperty.fromName(p)!,
          },
        ),
      ],
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final manager = BluetoothManager.shared;
  late FakeBleBridge bridge;

  // 顶层 setUpAll：先于所有测试，注入 FakeBleBridge 并初始化管理器
  //（注意 setUpAll 先于每个 group 的测试执行，且先于 setUp）
  setUpAll(() async {
    bridge = FakeBleBridge();
    BluetoothManager.bridge = bridge;
    await manager.init();
  });

  tearDownAll(() async {
    await manager.dispose();
  });

  group('订阅即得当前值（初始状态重放）', () {
    test('adapterState / connectionState / scanResults 初始值', () async {
      final adapterStates = <BleAdapterState>[];
      final connectionStates = <BluetoothConnectionState>[];
      final scanResults = <List<BluetoothDevice>>[];

      final sub1 = manager.adapterStateStream.listen(adapterStates.add);
      final sub2 = manager.connectionStateStream.listen(connectionStates.add);
      final sub3 = manager.scanResultsStream.listen(scanResults.add);

      await pumpEventQueue();

      expect(adapterStates, [BleAdapterState.unknown]);
      expect(connectionStates, [isA<IdleState>()]);
      expect(scanResults, [isEmpty]);

      await sub1.cancel();
      await sub2.cancel();
      await sub3.cancel();
    });
  });

  group('事件流推送（init 后）', () {
    test('adapterStateStream 收到 poweredOn', () async {
      final states = <BleAdapterState>[];
      final sub = manager.adapterStateStream.listen(states.add);

      bridge.emit(const BleStateChangedEvent(BleAdapterState.poweredOn));
      await pumpEventQueue();

      expect(states.last, BleAdapterState.poweredOn);
      await sub.cancel();
    });

    test('scanResultsStream 收到发现设备且按 RSSI 排序', () async {
      final results = <List<BluetoothDevice>>[];
      final sub = manager.scanResultsStream.listen(results.add);

      bridge.emit(const BleDeviceDiscoveredEvent(
        deviceId: 'D1',
        name: 'Device A',
        rssi: -50,
      ));
      bridge.emit(const BleDeviceDiscoveredEvent(
        deviceId: 'D2',
        name: 'Device B',
        rssi: -70,
      ));
      await pumpEventQueue();

      final latest = results.last;
      expect(latest.map((d) => d.identifier), ['D1', 'D2']);
      expect(latest.first.rssi, -50);
      await sub.cancel();
    });

    test('连接流程推送 connectionStateStream / currentDeviceStream', () async {
      final connectionStates = <BluetoothConnectionState>[];
      final currentDevices = <BluetoothDevice?>[];
      final sub1 = manager.connectionStateStream.listen(connectionStates.add);
      final sub2 = manager.currentDeviceStream.listen(currentDevices.add);

      await manager.connect(const BluetoothDevice(
        identifier: 'D1',
        name: 'Device A',
      ));
      // connected 事件 → 服务发现 → 特征就绪
      bridge.emit(const BleConnectionChangedEvent(
        deviceId: 'D1',
        state: 'connected',
      ));
      await pumpEventQueue();
      bridge.emit(serviceWithCharacteristic(deviceId: 'D1'));
      await pumpEventQueue();

      expect(connectionStates, contains(isA<ReadyState>()));
      expect(currentDevices.last?.identifier, 'D1');

      // 主动断开 → 推送 null
      await manager.disconnect();
      bridge.emit(const BleConnectionChangedEvent(
        deviceId: 'D1',
        state: 'disconnected',
      ));
      await pumpEventQueue();

      expect(currentDevices.last, isNull);
      expect(connectionStates.last, isA<DisconnectedState>());
      await sub1.cancel();
      await sub2.cancel();
    });

    test('dataStream 剥离应用层帧头，ACK 帧不推送', () async {
      final received = <BluetoothDataReceived>[];
      final sub = manager.dataStream.listen(received.add);

      // 1. 裸数据（非协议帧）原样推送
      bridge.emit(BleCharacteristicValueChangedEvent(
        deviceId: 'D1',
        serviceId: 'FFF0',
        characteristicId: 'FFF1',
        value: Uint8List.fromList([0x01, 0x02, 0x03]),
      ));
      await pumpEventQueue();
      expect(received.length, 1);
      expect(received.first.data, [0x01, 0x02, 0x03]);

      // 2. 应用层数据帧：推送剥离帧头后的 payload
      final frame = BluetoothProtocolCodec.makeDataFrames(
        Uint8List.fromList([0xAA, 0xBB]),
        maxPayloadLength: 10,
      ).first;
      bridge.emit(BleCharacteristicValueChangedEvent(
        deviceId: 'D1',
        serviceId: 'FFF0',
        characteristicId: 'FFF1',
        value: BluetoothProtocolCodec.encode(frame),
      ));
      await pumpEventQueue();
      expect(received.last.data, [0xAA, 0xBB]);

      // 3. ACK 帧：被传输层消费，不推送 dataStream
      final ack = BluetoothProtocolCodec.encode(
        BluetoothProtocolCodec.makeAck(
          sequence: 0,
          offset: 0,
          totalLength: 2,
        ),
      );
      bridge.emit(BleCharacteristicValueChangedEvent(
        deviceId: 'D1',
        serviceId: 'FFF0',
        characteristicId: 'FFF1',
        value: ack,
      ));
      await pumpEventQueue();
      expect(received.length, 2); // 仍只有前两条

      await sub.cancel();
    });

    test('errorStream 收到错误事件', () async {
      final errors = <BluetoothError>[];
      final sub = manager.errorStream.listen(errors.add);

      bridge.emit(BleCharacteristicValueChangedEvent(
        deviceId: 'D1',
        serviceId: 'FFF0',
        characteristicId: 'FFF1',
        value: Uint8List(0),
      ));
      // 触发一个适配器未开启的错误：先置为 poweredOff，再尝试扫描
      bridge.emit(const BleStateChangedEvent(BleAdapterState.poweredOff));
      await pumpEventQueue();
      BluetoothManager.bridge = bridge;
      await manager.startScan(); // adapter 非 poweredOn → 错误
      await pumpEventQueue();

      expect(errors, isNotEmpty);
      expect(errors.last.type, BluetoothErrorType.adapterPoweredOff);
      await sub.cancel();
    });

    test('transferEventsStream 收到传输完成（完整小传输 + ACK）', () async {
      final transferEvents = <BluetoothTransferEvent>[];
      final sub = manager.transferEventsStream.listen(transferEvents.add);

      // 重新建立连接与特征就绪（保证角色可用）
      await manager.connect(const BluetoothDevice(
        identifier: 'D2',
        name: 'Device B',
      ));
      bridge.emit(const BleConnectionChangedEvent(
        deviceId: 'D2',
        state: 'connected',
      ));
      await pumpEventQueue();
      bridge.emit(serviceWithCharacteristic(
        deviceId: 'D2',
        serviceId: 'FFF0',
        characteristicId: 'FFF1',
      ));
      await pumpEventQueue();

      // 发送 10 字节数据（单帧），随后外设回 ACK
      final data = Uint8List.fromList(List.generate(10, (i) => i));
      final transferId = await manager.sendReliableData(data);
      expect(transferId, isNotNull);

      final ack = BluetoothProtocolCodec.encode(
        BluetoothProtocolCodec.makeAck(
          sequence: 0,
          offset: 0,
          totalLength: data.length,
        ),
      );
      bridge.emit(BleCharacteristicValueChangedEvent(
        deviceId: 'D2',
        serviceId: 'FFF0',
        characteristicId: 'FFF1',
        value: ack,
      ));
      await pumpEventQueue();

      expect(transferEvents, isNotEmpty);
      expect(transferEvents.last, isA<BluetoothTransferCompleted>());
      expect(transferEvents.last.transferId, transferId);

      // 断开清理，避免影响后续测试
      await manager.disconnect();
      bridge.emit(const BleConnectionChangedEvent(
        deviceId: 'D2',
        state: 'disconnected',
      ));
      await pumpEventQueue();
      await sub.cancel();
    });
    test('metricsStream 收到 MTU 更新', () async {
      final metricsList = <BluetoothMetricSnapshot>[];
      final sub = manager.metricsStream.listen(metricsList.add);

      bridge.emit(const BleMtuChangedEvent(deviceId: 'D1', mtu: 247));
      await pumpEventQueue();

      expect(metricsList, isNotEmpty);
      expect(metricsList.last.maximumWriteLength, 244); // mtu - 3
      await sub.cancel();
    });

    test('dispose 后订阅：收到最近值后正常关闭，不抛错', () async {
      final states = <BleAdapterState>[];
      var done = false;
      final sub = manager.adapterStateStream.listen(
        states.add,
        onDone: () => done = true,
      );

      await manager.dispose();
      await pumpEventQueue();

      // 收到 dispose 前的最近值，流正常结束而非抛错
      expect(states, isNotEmpty);
      expect(done, isTrue);
      await sub.cancel();
    });
  });
}
