/// ActiveTransfer 传输逻辑单元测试。
///
/// 覆盖：分包计数、懒加载取包、ACK 窗口限制、响应槽位限制、
/// 确认/重试/去重、断点续传、超时定时器清理。
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:ble_plugin/ble_plugin.dart';
import 'package:flutter_test/flutter_test.dart';

BluetoothTransferOptions _options({
  BluetoothTransferReliability reliability =
      BluetoothTransferReliability.applicationAck,
  int ackWindow = 6,
  int maxRetries = 3,
  BleWriteType? writeType,
}) {
  return BluetoothTransferOptions(
    reliability: reliability,
    ackWindow: ackWindow,
    maxRetries: maxRetries,
    writeType: writeType,
  );
}

ActiveTransfer _makeTransfer(
  int dataLength, {
  int maxPayloadLength = 32,
  BluetoothTransferOptions? options,
  int resumeOffset = 0,
}) {
  return ActiveTransfer(
    data: Uint8List.fromList(List.generate(dataLength, (i) => i % 256)),
    maxPayloadLength: maxPayloadLength,
    options: options ?? _options(),
    resumeOffset: resumeOffset,
  );
}

void main() {
  group('ActiveTransfer 分包与懒加载', () {
    test('100 字节 / 32 → 4 帧，totalFrameCount 正确', () {
      final transfer = _makeTransfer(100);
      expect(transfer.totalFrameCount, 4);
      expect(transfer.totalPayloadBytes, 100);
      expect(transfer.isComplete, false);
      expect(transfer.ackedPayloadBytes, 0);
    });

    test('空数据 → 1 帧', () {
      final transfer = _makeTransfer(0);
      expect(transfer.totalFrameCount, 1);
      expect(transfer.totalPayloadBytes, 0);
      // 空数据立即完成
      expect(transfer.isComplete, true);
    });

    test('makePacket 按索引生成正确 payload（含应用层帧头）', () {
      final transfer = _makeTransfer(100);
      final packet = transfer.makePacket(1);
      expect(packet.sequence, 1);
      expect(packet.payloadSize, 32);
      // 应用层帧：长度 = 22 头 + 32 payload
      expect(packet.data.length, BluetoothProtocolFrame.headerLength + 32);
      final frame = BluetoothProtocolCodec.decode(packet.data);
      expect(frame, isNotNull);
      expect(frame!.offset, 32);
      expect(frame.totalLength, 100);
      // payload 内容 = 原始数据 [32, 64)
      expect(frame.payload, Uint8List.fromList(List.generate(32, (i) => (i + 32) % 256)));
    });

    test('useApplicationFrame=false 时裸数据包', () {
      final transfer = ActiveTransfer(
        data: Uint8List.fromList([1, 2, 3, 4, 5]),
        maxPayloadLength: 3,
        options: BluetoothTransferOptions(
          reliability: BluetoothTransferReliability.fireAndForget,
          useApplicationFrame: false,
        ),
      );
      // 第 1 块 [1,2,3]，第 2 块 [4,5]
      expect(transfer.makePacket(0).data, [1, 2, 3]);
      final packet = transfer.makePacket(1);
      expect(packet.data, [4, 5]);
      expect(packet.payloadSize, 2);
    });
  });

  group('ActiveTransfer ACK 窗口', () {
    test('窗口=2 时最多在途 2 个包', () {
      final transfer = _makeTransfer(100, options: _options(ackWindow: 2));
      expect(transfer.canSendNext, true);
      transfer.nextPacket(); // seq 0
      expect(transfer.canSendNext, true);
      transfer.nextPacket(); // seq 1
      // 窗口已满
      expect(transfer.canSendNext, false);
      // ACK 后恢复
      transfer.markAcked(0);
      expect(transfer.canSendNext, true);
      final packet = transfer.nextPacket(); // seq 2
      expect(packet!.sequence, 2);
    });

    test('窗口满时重试队列中的包仍可发送（重试优先）', () {
      final transfer = _makeTransfer(200, options: _options(ackWindow: 2));
      transfer.nextPacket(); // seq 0
      transfer.nextPacket(); // seq 1
      expect(transfer.canSendNext, false);
      // seq 0 超时重试：进入重试队列后应可立即重发
      expect(transfer.retry(0), true);
      expect(transfer.canSendNext, true);
      final retried = transfer.nextPacket();
      expect(retried!.sequence, 0);
    });

    test('fireAndForget 模式不受 ACK 窗口限制', () {
      final transfer = _makeTransfer(
        100,
        options: _options(reliability: BluetoothTransferReliability.fireAndForget),
      );
      for (var i = 0; i < 4; i++) {
        expect(transfer.canSendNext, true);
        transfer.nextPacket();
      }
      expect(transfer.canSendNext, false);
    });
  });

  group('ActiveTransfer 确认与完成', () {
    test('全部确认后 isComplete 为 true', () {
      final transfer = _makeTransfer(100);
      transfer.nextPacket();
      transfer.nextPacket();
      transfer.nextPacket();
      transfer.nextPacket();
      expect(transfer.isComplete, false);
      transfer.markAcked(0);
      expect(transfer.ackedPayloadBytes, 32);
      transfer.markAcked(1);
      transfer.markAcked(2);
      expect(transfer.isComplete, false);
      transfer.markAcked(3);
      expect(transfer.ackedPayloadBytes, 100);
      expect(transfer.isComplete, true);
    });

    test('重复 ACK 去重，不重复累加字节数', () {
      final transfer = _makeTransfer(64);
      transfer.nextPacket();
      transfer.nextPacket();
      transfer.markAcked(0);
      transfer.markAcked(0);
      transfer.markAcked(0);
      expect(transfer.ackedPayloadBytes, 32);
    });

    test('乱序确认也能正确累计', () {
      final transfer = _makeTransfer(96);
      for (var i = 0; i < 3; i++) {
        transfer.nextPacket();
      }
      transfer.markAcked(2);
      transfer.markAcked(0);
      expect(transfer.ackedPayloadBytes, 64);
      transfer.markAcked(1);
      expect(transfer.isComplete, true);
    });
  });

  group('ActiveTransfer 重试', () {
    test('重试计数递增，超过 maxRetries 返回 false', () {
      final transfer = _makeTransfer(64, options: _options(maxRetries: 2));
      transfer.nextPacket(); // seq 0
      expect(transfer.retry(0), true); // 第 1 次
      transfer.nextPacket();
      expect(transfer.retry(0), true); // 第 2 次
      transfer.nextPacket();
      expect(transfer.retry(0), false); // 第 3 次超限
    });

    test('已确认的包不能再重试（返回 true 且无副作用）', () {
      final transfer = _makeTransfer(64);
      transfer.nextPacket();
      transfer.markAcked(0);
      expect(transfer.retry(0), true);
      expect(transfer.ackedPayloadBytes, 32);
    });

    test('重试后仍可标记确认', () {
      final transfer = _makeTransfer(32);
      transfer.nextPacket();
      transfer.retry(0);
      final packet = transfer.nextPacket();
      expect(packet!.sequence, 0);
      transfer.markAcked(0);
      expect(transfer.isComplete, true);
    });
  });

  group('ActiveTransfer withResponse 响应槽位', () {
    test('响应槽位独立限制在途 withResponse 写入数', () {
      // fireAndForget 不受应用层 ACK 窗口限制，可单独验证响应槽位
      final transfer = _makeTransfer(
        100,
        options: _options(
          reliability: BluetoothTransferReliability.fireAndForget,
          writeType: BleWriteType.withResponse,
          ackWindow: 2,
        ),
      );
      transfer.nextPacket(); // 槽位 1
      transfer.nextPacket(); // 槽位 2
      expect(transfer.canSendNext, false);
      // 释放一个槽位（模拟 writeCompleted 事件）
      transfer.releaseWriteResponseSlot();
      expect(transfer.canSendNext, true);
    });
  });

  group('ActiveTransfer 断点续传', () {
    test('resumeOffset 恢复后从断点继续发送', () {
      final transfer = _makeTransfer(
        100,
        maxPayloadLength: 32,
        resumeOffset: 64,
      );
      // 已确认 64 字节（seq 0、1）
      expect(transfer.ackedPayloadBytes, 64);
      expect(transfer.isComplete, false);
      final packet = transfer.nextPacket();
      expect(packet!.sequence, 2);
      expect(packet.data.length, BluetoothProtocolFrame.headerLength + 32);
      // 发送最后两块（seq 2、3）并确认后完成
      transfer.markAcked(2);
      expect(transfer.isComplete, false);
      final last = transfer.nextPacket();
      expect(last!.sequence, 3);
      transfer.markAcked(3);
      expect(transfer.isComplete, true);
    });

    test('resumeOffset 非整数倍时从整帧边界继续（偏移计数保持 resumeOffset）', () {
      // 真实场景中 resumeOffset 恒为 maxPayloadLength 整数倍（累加值），
      // 此处仅验证实现不会越界：从边界帧继续发送并最终完成。
      final transfer = _makeTransfer(
        100,
        maxPayloadLength: 32,
        resumeOffset: 70, // 70 ~/ 32 = 2
      );
      expect(transfer.ackedPayloadBytes, 70);
      final packet = transfer.nextPacket();
      expect(packet!.sequence, 2);
      transfer.markAcked(2);
      transfer.markAcked(3);
      expect(transfer.isComplete, true);
    });

    test('resumeOffset 达到末尾时直接完成', () {
      final transfer = _makeTransfer(
        100,
        maxPayloadLength: 32,
        resumeOffset: 100,
      );
      expect(transfer.ackedPayloadBytes, 100);
      expect(transfer.isComplete, true);
      expect(transfer.nextPacket(), isNull);
    });
  });

  group('ActiveTransfer 超时定时器', () {
    test('registerTimeout 后 cancelTimeouts 全部取消', () async {
      final transfer = _makeTransfer(64);
      var fired = 0;
      transfer.registerTimeout(Timer(const Duration(milliseconds: 10), () {
        fired += 1;
      }), 0);
      transfer.registerTimeout(Timer(const Duration(milliseconds: 10), () {
        fired += 1;
      }), 1);
      transfer.cancelTimeouts();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(fired, 0);
    });

    test('markAcked 会取消该包的超时定时器', () async {
      final transfer = _makeTransfer(32);
      transfer.nextPacket();
      var fired = 0;
      transfer.registerTimeout(Timer(const Duration(milliseconds: 10), () {
        fired += 1;
      }), 0);
      transfer.markAcked(0);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(fired, 0);
    });
  });

  group('ActiveTransfer ID', () {
    test('自动生成的 ID 唯一且包含时间戳', () {
      final a = _makeTransfer(10);
      final b = _makeTransfer(10);
      expect(a.id, isNot(b.id));
      expect(a.id.split('-').length, 2);
    });

    test('可显式指定 ID（断点续传场景）', () {
      final transfer = _makeTransfer(10, resumeOffset: 0);
      final resumed = ActiveTransfer(
        data: transfer.sourceData,
        maxPayloadLength: transfer.maxPayloadLength,
        options: transfer.options,
        resumeOffset: transfer.ackedOffset,
        id: transfer.id,
      );
      expect(resumed.id, transfer.id);
    });
  });
}
