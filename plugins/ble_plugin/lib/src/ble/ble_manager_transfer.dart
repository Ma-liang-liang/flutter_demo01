/// `BluetoothManager` 的传输逻辑拆分（part of ble_manager.dart）。
///
/// 包含：sendRaw / sendReliableData / readValue 三种数据接口、
/// 传输队列刷新（ACK 窗口控制）、ACK 超时重试、应用层帧处理、
/// 传输完成/取消、断点续传恢复。
///
/// **实现方式：** 以库级顶层函数实现（part 与宿主同 library，可直接访问
/// 宿主类的私有成员），宿主 [BluetoothManager] 提供同名薄壳方法。
part of 'ble_manager.dart';

// MARK: - 数据写入

/// 原始写入接口，适合临时调试或外设协议不支持 App 层包头的情况。
/// 生产中的文件/OTA/关键命令建议优先使用 sendReliableData。
Future<void> _sendRawImpl(
  BluetoothManager m,
  List<int> data, {
  BluetoothCharacteristicRole role = BluetoothCharacteristicRole.commandWrite,
  BleWriteType? writeType,
}) async {
  await m._enqueue(() async {
    // 不允许并发传输
    if (m._activeTransfer != null) {
      m._notifyFailure(const BluetoothError.transferInProgress());
      return;
    }
    final target = m._characteristicsByRole[role];
    if (target == null) {
      m._notifyFailure(BluetoothError.characteristicNotReady(role));
      return;
    }
    final type = _bestWriteTypeImpl(target.properties, preferred: writeType);
    if (type == null) {
      m._notifyFailure(const BluetoothError.unsupportedWriteType());
      return;
    }
    final maxLength = await _queryMaximumWriteLengthImpl(m, type, fallback: 20);
    // 构建传输对象（fireAndForget 模式，不加应用层帧）
    m._activeTransfer = ActiveTransfer(
      data: Uint8List.fromList(data),
      maxPayloadLength: maxLength > 1 ? maxLength : 1,
      options: BluetoothTransferOptions(
        role: role,
        reliability: BluetoothTransferReliability.fireAndForget,
        writeType: type,
        useApplicationFrame: false,
      ),
    );
    await _flushActiveTransferImpl(m);
  });
}

/// 可靠传输接口：App 层包头 + CRC + ACK 窗口 + 超时重试。
///
/// 注意：外设固件需要按 [BluetoothProtocolCodec] 的格式回 ACK，
/// 否则会触发超时重试。
///
/// 返回传输 ID，调用方可据此关联回调。传输前置条件不满足时返回 null。
Future<String?> _sendReliableDataImpl(
  BluetoothManager m,
  List<int> data, {
  BluetoothTransferOptions options = const BluetoothTransferOptions(),
}) {
  return m._enqueue(() async {
    // 不允许并发传输
    if (m._activeTransfer != null) {
      m._notifyFailure(const BluetoothError.transferInProgress());
      return null;
    }
    final target = m._characteristicsByRole[options.role];
    if (target == null) {
      m._notifyFailure(BluetoothError.characteristicNotReady(options.role));
      return null;
    }
    final type = _bestWriteTypeImpl(target.properties, preferred: options.writeType);
    if (type == null) {
      m._notifyFailure(const BluetoothError.unsupportedWriteType());
      return null;
    }
    // 计算 MTU 和 payload 长度
    final maximumWriteLength =
        await _queryMaximumWriteLengthImpl(m, type, fallback: 20);
    final headerLength =
        options.useApplicationFrame ? BluetoothProtocolFrame.headerLength : 0;
    // MTU 必须能容纳头部
    if (maximumWriteLength <= headerLength) {
      m._notifyFailure(BluetoothError.mtuTooSmall(maximumWriteLength));
      return null;
    }
    // payload 长度 = min(配置值, MTU - 头部)
    final payloadLength = _clampPositive(
      options.maxPayloadLength ?? maximumWriteLength - headerLength,
      maximumWriteLength - headerLength,
    );

    // 更新配置中的实际写入方式和 payload 长度
    final resolvedOptions = options.copyWith(
      writeType: type,
      maxPayloadLength: payloadLength,
    );

    // ActiveTransfer 内部懒加载帧，不会一次性创建全部帧对象
    m._activeTransfer = ActiveTransfer(
      data: Uint8List.fromList(data),
      maxPayloadLength: payloadLength,
      options: resolvedOptions,
    );
    // 先保存 ID，刷新队列时可能已完成并清空 _activeTransfer
    final transferId = m._activeTransfer!.id;
    await _flushActiveTransferImpl(m);
    return transferId;
  });
}

/// 读取指定角色的特征值（异步操作，结果通过
/// [BluetoothManagerDelegate.onDataReceived] 回调返回）。
Future<void> _readValueImpl(
  BluetoothManager m, {
  BluetoothCharacteristicRole role = BluetoothCharacteristicRole.read,
}) async {
  await m._enqueue(() async {
    final target = m._characteristicsByRole[role];
    if (target == null) {
      m._notifyFailure(BluetoothError.characteristicNotReady(role));
      return;
    }
    final deviceId = m._connectedPeripheralId;
    if (deviceId == null) return;
    await BluetoothManager.bridge.readValue(
      deviceId,
      target.serviceId,
      target.characteristicId,
    );
  });
}

// MARK: - 内部：传输流程

/// 刷新传输队列：尽可能多地发送待发数据包。
Future<void> _flushActiveTransferImpl(BluetoothManager m) async {
  final transfer = m._activeTransfer;
  if (transfer == null) return;
  final deviceId = m._connectedPeripheralId;
  final target = m._characteristicsByRole[transfer.options.role];
  final writeType = transfer.options.writeType;
  if (deviceId == null || target == null || writeType == null) {
    m._notifyFailure(
      BluetoothError.characteristicNotReady(transfer.options.role),
    );
    return;
  }

  // 在窗口和队列限制内，尽可能多地写入数据包
  while (transfer.canSendNext) {
    final packet = transfer.nextPacket();
    if (packet == null) break;

    final canContinue = await BluetoothManager.bridge.writeValue(
      deviceId,
      target.serviceId,
      target.characteristicId,
      packet.data,
      writeWithResponse: writeType == BleWriteType.withResponse,
    );
    // 更新指标
    m._metrics = m._metrics.copyWith(
      transmittedBytes: m._metrics.transmittedBytes + packet.payloadSize,
    );
    m._notifyProgress();
    m._notifyMetrics();

    if (transfer.options.reliability ==
        BluetoothTransferReliability.applicationAck) {
      // 可靠传输：等待 ACK，设置超时
      _scheduleAckTimeoutImpl(m,
          sequence: packet.sequence, transferId: transfer.id);
    } else {
      // fireAndForget：直接标记为已确认
      transfer.markAcked(packet.sequence);
    }

    // 平台缓冲已满（iOS withoutResponse），等待 readyToWrite 事件再继续
    if (writeType == BleWriteType.withoutResponse && !canContinue) {
      return;
    }
  }

  // 检查是否所有包都已确认，传输完成
  _completeTransferIfNeededImpl(m);
}

/// 设置 ACK 超时定时器。
void _scheduleAckTimeoutImpl(
  BluetoothManager m, {
  required int sequence,
  required String transferId,
}) {
  final transfer = m._activeTransfer;
  if (transfer == null) return;
  final timer = Timer(
    Duration(milliseconds: (transfer.options.ackTimeout * 1000).round()),
    () {
      m._enqueue(() async {
        _handleAckTimeoutImpl(m, sequence: sequence, transferId: transferId);
      });
    },
  );
  transfer.registerTimeout(timer, sequence);
}

/// 处理 ACK 超时：重试或报错。
void _handleAckTimeoutImpl(
  BluetoothManager m, {
  required int sequence,
  required String transferId,
}) {
  final transfer = m._activeTransfer;
  if (transfer == null || transfer.id != transferId) return;
  // 尝试重试该数据包
  if (!transfer.retry(sequence)) {
    // 超过最大重试次数，取消传输并报错
    _cancelActiveTransferImpl(m);
    m._notifyFailure(BluetoothError.ackTimeout(sequence));
    return;
  }
  // 重新刷新传输队列
  _flushActiveTransferImpl(m);
}

/// 处理收到的应用层帧（如 ACK）。
///
/// 返回 true 表示已处理（是 ACK 帧），false 表示是普通数据帧，交给上层。
bool _handleApplicationFrameImpl(BluetoothManager m, BluetoothProtocolFrame frame) {
  switch (frame.type) {
    case BluetoothProtocolFrameType.ack:
      // 收到 ACK：标记对应序号的包为已确认
      m._activeTransfer?.markAcked(frame.sequence);
      // 继续发送后续包
      _flushActiveTransferImpl(m);
      // 检查是否完成
      _completeTransferIfNeededImpl(m);
      return true;
    case BluetoothProtocolFrameType.data:
    case BluetoothProtocolFrameType.complete:
    case BluetoothProtocolFrameType.resumeRequest:
      // 非 ACK 帧，不在此处理
      return false;
  }
}

/// 检查传输是否完成，完成则通知 delegate。
void _completeTransferIfNeededImpl(BluetoothManager m) {
  final transfer = m._activeTransfer;
  if (transfer == null || !transfer.isComplete) return;
  final id = transfer.id;
  m._activeTransfer = null;
  m._transferEventsStreamCtrl.add(
    BluetoothTransferCompleted(transferId: id),
  );
  for (final delegate in m._liveDelegates) {
    delegate.onTransferCompleted(id);
  }
}

/// 取消当前传输，清理所有超时定时器。
void _cancelActiveTransferImpl(BluetoothManager m) {
  m._activeTransfer?.cancelTimeouts();
  m._activeTransfer = null;
}

/// 查询当前最大写入长度。
Future<int> _queryMaximumWriteLengthImpl(
  BluetoothManager m,
  BleWriteType writeType, {
  required int fallback,
}) async {
  final deviceId = m._connectedPeripheralId;
  if (deviceId == null) return fallback;
  try {
    final length = await BluetoothManager.bridge.maximumWriteLength(
      deviceId,
      withResponse: writeType == BleWriteType.withResponse,
    );
    return length > 1 ? length : fallback;
  } on PlatformBridgeException {
    return fallback;
  }
}

/// 根据特征属性和偏好选择最佳写入方式。
/// 优先级：偏好 → 特征属性自动选择。
BleWriteType? _bestWriteTypeImpl(
  Set<BluetoothCharacteristicProperty> properties, {
  BleWriteType? preferred,
}) {
  // 如果偏好 withoutResponse 且特征支持
  if (preferred == BleWriteType.withoutResponse &&
      properties.contains(BluetoothCharacteristicProperty.writeWithoutResponse)) {
    return BleWriteType.withoutResponse;
  }
  // 如果偏好 withResponse 且特征支持
  if (preferred == BleWriteType.withResponse &&
      properties.contains(BluetoothCharacteristicProperty.write)) {
    return BleWriteType.withResponse;
  }
  // 没有偏好时自动选择：优先 withoutResponse（更快）
  if (properties.contains(BluetoothCharacteristicProperty.writeWithoutResponse)) {
    return BleWriteType.withoutResponse;
  }
  // 回退到 withResponse
  if (properties.contains(BluetoothCharacteristicProperty.write)) {
    return BleWriteType.withResponse;
  }
  return null;
}

/// 检查是否有待恢复的断点续传，有则自动恢复。
void _resumePendingTransferIfNeededImpl(BluetoothManager m) {
  final ctx = m._pendingResume;
  if (ctx == null) return;
  if (!m._characteristicsByRole.containsKey(ctx.options.role)) return;
  if (m._activeTransfer != null) return;

  // 从断点创建新的传输
  m._activeTransfer = ActiveTransfer(
    data: ctx.data,
    maxPayloadLength: ctx.maxPayloadLength,
    options: ctx.options,
    resumeOffset: ctx.ackedOffset,
    id: ctx.transferId,
  );
  final resumedId = ctx.transferId;
  final resumedOffset = ctx.ackedOffset;
  m._pendingResume = null;
  _flushActiveTransferImpl(m);
  m._transferEventsStreamCtrl.add(
    BluetoothTransferResumed(
      transferId: resumedId,
      fromOffset: resumedOffset,
    ),
  );
  for (final delegate in m._liveDelegates) {
    delegate.onTransferResumed(resumedId, resumedOffset);
  }
}

/// 限制 payload 长度为正且不超过上限。
int _clampPositive(int value, int upperBound) {
  var result = value < upperBound ? value : upperBound;
  if (result < 1) result = 1;
  return result;
}
