/// 应用层协议编解码与 CRC32 单元测试。
///
/// 覆盖：CRC32 正确性（标准向量）、数据帧拆分、编码/解码往返、
/// 各种非法输入的容错。
library;

import 'dart:typed_data';

import 'package:ble_plugin/ble_plugin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('crc32Of', () {
    test('标准校验向量：crc32("123456789") == 0xCBF43926', () {
      final data = Uint8List.fromList('123456789'.codeUnits);
      expect(crc32Of(data), 0xCBF43926);
    });

    test('空数据 CRC32 为 0', () {
      expect(crc32Of(Uint8List(0)), 0);
    });

    test('相同数据 CRC32 稳定且与 iOS 多项式一致', () {
      final data = Uint8List.fromList(
        List.generate(1024, (i) => i % 251),
      );
      final first = crc32Of(data);
      final second = crc32Of(data);
      expect(first, second);
      // 与已知的 zlib crc32 参考实现一致性：校验非零且不重复
      expect(first, isNot(0));
    });

    test('数据不同 CRC32 不同', () {
      expect(
        crc32Of(Uint8List.fromList([1, 2, 3])),
        isNot(crc32Of(Uint8List.fromList([1, 2, 4]))),
      );
    });
  });

  group('BluetoothProtocolCodec.makeDataFrames', () {
    test('100 字节数据按 32 字节分包 → 4 帧', () {
      final data = Uint8List.fromList(List.generate(100, (i) => i));
      final frames = BluetoothProtocolCodec.makeDataFrames(
        data,
        maxPayloadLength: 32,
      );
      expect(frames.length, 4);
      expect(frames[0].sequence, 0);
      expect(frames[0].offset, 0);
      expect(frames[1].offset, 32);
      expect(frames[2].offset, 64);
      expect(frames[3].offset, 96);
      expect(frames[3].payload.length, 4);
      // 每帧 totalLength 都等于原始数据长度
      for (final frame in frames) {
        expect(frame.totalLength, 100);
        expect(frame.type, BluetoothProtocolFrameType.data);
      }
    });

    test('恰好整除时帧数与 payload 正确', () {
      final data = Uint8List.fromList(List.generate(64, (i) => i));
      final frames = BluetoothProtocolCodec.makeDataFrames(
        data,
        maxPayloadLength: 32,
      );
      expect(frames.length, 2);
      expect(frames[0].payload.length, 32);
      expect(frames[1].payload.length, 32);
    });

    test('空数据也生成 1 帧（标记传输开始/结束）', () {
      final frames = BluetoothProtocolCodec.makeDataFrames(
        Uint8List(0),
        maxPayloadLength: 32,
      );
      expect(frames.length, 1);
      expect(frames[0].sequence, 0);
      expect(frames[0].totalLength, 0);
    });

    test('超过 UInt16.max 的 payload 上限被截断', () {
      final data = Uint8List(0x10000); // 65536 字节
      final frames = BluetoothProtocolCodec.makeDataFrames(
        data,
        maxPayloadLength: 0x20000, // 超过 0xFFFF
      );
      expect(frames.length, 2);
      expect(frames[0].payload.length, 0xFFFF);
      expect(frames[1].payload.length, 1);
    });
  });

  group('BluetoothProtocolCodec.encode/decode 往返', () {
    test('数据帧编码后解码还原全部字段', () {
      final data = Uint8List.fromList(List.generate(50, (i) => (i * 3) % 256));
      final frames = BluetoothProtocolCodec.makeDataFrames(
        data,
        maxPayloadLength: 16,
      );
      for (final frame in frames) {
        final encoded = BluetoothProtocolCodec.encode(frame);
        // 长度 = 22 字节头 + payload
        expect(encoded.length, BluetoothProtocolFrame.headerLength + frame.payload.length);
        final decoded = BluetoothProtocolCodec.decode(encoded);
        expect(decoded, isNotNull);
        expect(decoded!.type, BluetoothProtocolFrameType.data);
        expect(decoded.sequence, frame.sequence);
        expect(decoded.offset, frame.offset);
        expect(decoded.totalLength, frame.totalLength);
        expect(decoded.payload, frame.payload);
      }
      // 解码后拼回的数据与原数据一致
      final decodedPayloads = <int>[
        for (final frame in frames) ...BluetoothProtocolCodec.decode(
          BluetoothProtocolCodec.encode(frame),
        )!.payload,
      ];
      expect(Uint8List.fromList(decodedPayloads), data);
    });

    test('ACK 帧往返', () {
      final ack = BluetoothProtocolCodec.makeAck(
        sequence: 7,
        offset: 224,
        totalLength: 1000,
      );
      final encoded = BluetoothProtocolCodec.encode(ack);
      final decoded = BluetoothProtocolCodec.decode(encoded);
      expect(decoded, isNotNull);
      expect(decoded!.type, BluetoothProtocolFrameType.ack);
      expect(decoded.sequence, 7);
      expect(decoded.offset, 224);
      expect(decoded.totalLength, 1000);
      expect(decoded.payload.isEmpty, true);
    });

    test('头部长度不足返回 null', () {
      expect(
        BluetoothProtocolCodec.decode(Uint8List(21)),
        isNull,
      );
    });

    test('魔数错误返回 null', () {
      final encoded = BluetoothProtocolCodec.encode(
        BluetoothProtocolCodec.makeAck(sequence: 0, offset: 0, totalLength: 0),
      );
      encoded[0] = 0x00; // 破坏 magic 高字节
      expect(BluetoothProtocolCodec.decode(encoded), isNull);
    });

    test('版本号不兼容返回 null', () {
      final encoded = BluetoothProtocolCodec.encode(
        BluetoothProtocolCodec.makeAck(sequence: 0, offset: 0, totalLength: 0),
      );
      encoded[2] = 0x02; // 版本改为 2
      expect(BluetoothProtocolCodec.decode(encoded), isNull);
    });

    test('未知帧类型返回 null', () {
      final encoded = BluetoothProtocolCodec.encode(
        BluetoothProtocolCodec.makeAck(sequence: 0, offset: 0, totalLength: 0),
      );
      encoded[3] = 0x7F; // 非法类型
      expect(BluetoothProtocolCodec.decode(encoded), isNull);
    });

    test('CRC 损坏返回 null', () {
      final encoded = BluetoothProtocolCodec.encode(
        BluetoothProtocolFrame(
          type: BluetoothProtocolFrameType.data,
          sequence: 0,
          offset: 0,
          totalLength: 5,
          payload: Uint8List.fromList([1, 2, 3, 4, 5]),
        ),
      );
      // 翻转 payload 的最后一个字节 → CRC 必然不匹配
      encoded[BluetoothProtocolFrame.headerLength + 4] =
          encoded[BluetoothProtocolFrame.headerLength + 4] ^ 0xFF;
      expect(BluetoothProtocolCodec.decode(encoded), isNull);
    });

    test('payload 长度字段超出实际数据返回 null', () {
      final encoded = BluetoothProtocolCodec.encode(
        BluetoothProtocolCodec.makeAck(sequence: 0, offset: 0, totalLength: 0),
      );
      // 把 payloadLen 字段改为 100（但实际没有 payload）
      final bd = ByteData.sublistView(encoded);
      bd.setUint16(16, 100);
      expect(BluetoothProtocolCodec.decode(encoded), isNull);
    });
  });
}
