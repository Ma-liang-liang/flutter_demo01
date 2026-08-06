import CoreBluetooth
import Flutter

/// BLE 桥接管理器：封装 CoreBluetooth，只做底层桥接。
///
/// 职责：
/// 1. 扫描、连接、断开、服务/特征发现
/// 2. 特征读写、通知订阅
/// 3. 底层事件上报（通过 eventSink 转发给 Flutter 层）
///
/// 不包含任何业务逻辑（应用层协议、状态机、重连策略等均在 Flutter 层）。
final class BleCentralManager: NSObject {

  /// 蓝牙操作的专用串行队列（与 iOS 参考实现保持一致）。
  private let queue = DispatchQueue(label: "com.example.ble_plugin.central")

  /// CoreBluetooth 中央管理器（延迟创建，等待 configure 传入恢复标识符）。
  private var centralManager: CBCentralManager!

  /// 事件上报通道（由 FlutterStreamHandler 注入）。
  var eventSink: FlutterEventSink?

  /// 已连接/操作中的外设表（key: peripheral identifier）。
  private var peripherals: [UUID: CBPeripheral] = [:]

  /// 外设已发现的服务表（key: peripheral identifier → serviceUUID → service）。
  private var servicesByPeripheral: [UUID: [String: CBService]] = [:]

  /// 连接超时定时器表（key: peripheral identifier）。
  private var connectTimeouts: [UUID: Timer] = [:]

  /// 状态恢复标识符（App 被系统杀掉后恢复连接）。
  private var restorationIdentifier = "com.example.ble_plugin.central.restore"

  /// 是否正在扫描。
  private var isScanning = false

  /// 最近一次适配器状态（CoreBluetooth rawValue），供 onListen 重放。
  private var lastAdapterState = 0

  // MARK: - 初始化

  override init() {
    super.init()
    // CBCentralManager 延迟创建：等待 configure() 传入恢复标识符，
    // 并探测宿主是否声明 bluetooth-central 后台模式（状态恢复前置条件）。
  }

  /// 确保中央管理器已创建（configure 传入的恢复标识符优先）。
  ///
  /// iOS 强制要求：启用状态恢复（RestoreIdentifierKey）的 App 必须在
  /// Info.plist 声明 `UIBackgroundModes: bluetooth-central`，否则
  /// CBCentralManager 初始化时直接抛异常导致 App 闪退。
  /// 这里在运行时探测宿主声明，未声明则自动降级为不启用状态恢复，
  /// 保证插件在任意宿主上都能正常运行。
  private func ensureCentralManager() {
    guard centralManager == nil else { return }
    var options: [String: Any] = [:]
    if Self.supportsBluetoothBackgroundMode() {
      options[CBCentralManagerOptionRestoreIdentifierKey] = restorationIdentifier
    }
    centralManager = CBCentralManager(delegate: self, queue: queue, options: options)
  }

  /// 宿主 App 是否声明了 bluetooth-central 后台模式。
  private static func supportsBluetoothBackgroundMode() -> Bool {
    guard let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] else {
      return false
    }
    return modes.contains("bluetooth-central")
  }

  // MARK: - 方法通道实现

  func configure(restorationIdentifier: String?) {
    if let identifier = restorationIdentifier, !identifier.isEmpty {
      self.restorationIdentifier = identifier
    }
    ensureCentralManager()
  }

  func startScan(serviceUUIDs: [String]?, allowDuplicates: Bool) {
    ensureCentralManager()
    guard centralManager.state == .poweredOn else {
      // 状态未就绪，先不扫描；状态恢复后由 Dart 层重新发起
      return
    }
    isScanning = true
    let uuids = serviceUUIDs?.compactMap { CBUUID(string: $0) }
    centralManager.scanForPeripherals(
      withServices: uuids,
      options: [CBCentralManagerScanOptionAllowDuplicatesKey: allowDuplicates]
    )
  }

  func stopScan() {
    ensureCentralManager()
    centralManager.stopScan()
    isScanning = false
  }

  func connect(deviceId: String, timeout: TimeInterval, result: @escaping FlutterResult) {
    ensureCentralManager()
    guard let uuid = UUID(uuidString: deviceId) else {
      result(FlutterError(code: "invalidArgs",
                          message: "Invalid device identifier.",
                          details: deviceId))
      return
    }
    // 依次尝试：系统缓存 → 已发现列表 → 再次检索
    let peripheral = centralManager.retrievePeripherals(withIdentifiers: [uuid]).first
      ?? peripherals[uuid]
      ?? findPeripheral(uuid: uuid)
    guard let peripheral else {
      result(FlutterError(code: "peripheralNotFound",
                          message: "Bluetooth peripheral was not found.",
                          details: deviceId))
      return
    }
    peripherals[uuid] = peripheral
    connectPeripheral(peripheral, timeout: timeout)
    result(nil)
  }

  /// 从扫描结果中查找外设，找不到则通过 UUID 构造占位对象。
  private func findPeripheral(uuid: UUID) -> CBPeripheral? {
    // CoreBluetooth 没有从 UUID 直接构造外设的公开 API，
    // 使用 retrievePeripherals 再次尝试（系统缓存中可能保留）。
    return centralManager.retrievePeripherals(withIdentifiers: [uuid]).first
  }

  private func connectPeripheral(_ peripheral: CBPeripheral, timeout: TimeInterval) {
    centralManager.stopScan()
    isScanning = false
    connectTimeouts[peripheral.identifier]?.invalidate()
    peripheral.delegate = self
    centralManager.connect(peripheral, options: [
      CBConnectPeripheralOptionNotifyOnConnectionKey: true,
      CBConnectPeripheralOptionNotifyOnDisconnectionKey: true,
      CBConnectPeripheralOptionNotifyOnNotificationKey: true
    ])
    // 连接超时：超时后取消连接并上报失败
    let timer = Timer(timeInterval: timeout, repeats: false) { [weak self] _ in
      guard let self = self else { return }
      guard peripheral.state == .connecting else { return }
      self.centralManager.cancelPeripheralConnection(peripheral)
      self.emit(event: "connectionChanged", data: [
        "deviceId": peripheral.identifier.uuidString,
        "state": "failed",
        "error": "Bluetooth connection timed out."
      ])
    }
    connectTimeouts[peripheral.identifier] = timer
    RunLoop.main.add(timer, forMode: .common)
  }

  func disconnect(deviceId: String) {
    ensureCentralManager()
    guard let uuid = UUID(uuidString: deviceId),
          let peripheral = peripherals[uuid] else { return }
    connectTimeouts[uuid]?.invalidate()
    centralManager.cancelPeripheralConnection(peripheral)
  }

  func discoverServices(deviceId: String, serviceUUIDs: [String]?) {
    ensureCentralManager()
    guard let uuid = UUID(uuidString: deviceId),
          let peripheral = peripherals[uuid] else { return }
    peripheral.delegate = self
    let uuids = serviceUUIDs?.compactMap { CBUUID(string: $0) }
    peripheral.discoverServices(uuids)
  }

  func discoverCharacteristics(deviceId: String, serviceId: String, characteristicUUIDs: [String]?) {
    ensureCentralManager()
    guard let uuid = UUID(uuidString: deviceId),
          let peripheral = peripherals[uuid],
          let service = findService(deviceId: uuid, serviceId: serviceId) else { return }
    let uuids = characteristicUUIDs?.compactMap { CBUUID(string: $0) }
    peripheral.discoverCharacteristics(uuids, for: service)
  }

  func readValue(deviceId: String, serviceId: String, characteristicId: String) {
    ensureCentralManager()
    guard let characteristic = findCharacteristic(
      deviceId: deviceId, serviceId: serviceId, characteristicId: characteristicId
    ) else { return }
    characteristic.service?.peripheral?.readValue(for: characteristic)
  }

  /// 写入特征值。
  ///
  /// - Returns: withoutResponse 模式下返回底层是否仍可继续写入；
  ///   withResponse 模式始终返回 true。
  func writeValue(
    deviceId: String,
    serviceId: String,
    characteristicId: String,
    value: Data,
    writeWithResponse: Bool,
    result: @escaping FlutterResult
  ) {
    ensureCentralManager()
    guard let characteristic = findCharacteristic(
      deviceId: deviceId, serviceId: serviceId, characteristicId: characteristicId
    ) else {
      result(FlutterError(code: "characteristicNotFound",
                          message: "Characteristic was not found.", details: nil))
      return
    }
    let peripheral = characteristic.service?.peripheral
    let type: CBCharacteristicWriteType = writeWithResponse ? .withResponse : .withoutResponse
    peripheral?.writeValue(value, for: characteristic, type: type)
    if writeWithResponse {
      result(true)
    } else {
      result(peripheral?.canSendWriteWithoutResponse ?? true)
    }
  }

  func setNotifyValue(deviceId: String, serviceId: String, characteristicId: String, enabled: Bool) {
    ensureCentralManager()
    guard let characteristic = findCharacteristic(
      deviceId: deviceId, serviceId: serviceId, characteristicId: characteristicId
    ) else { return }
    characteristic.service?.peripheral?.setNotifyValue(enabled, for: characteristic)
  }

  /// iOS 上 MTU 由系统自动协商，返回当前实际值（maximumWriteLength + 3）。
  func currentMtuApprox(deviceId: String) -> Int {
    maximumWriteLength(deviceId: deviceId, withResponse: false) + 3
  }

  func maximumWriteLength(deviceId: String, withResponse: Bool) -> Int {
    ensureCentralManager()
    guard let uuid = UUID(uuidString: deviceId),
          let peripheral = peripherals[uuid] else { return 20 }
    return peripheral.maximumWriteValueLength(for: withResponse ? .withResponse : .withoutResponse)
  }

  func retrieveKnownPeripherals(identifiers: [UUID]) -> [[String: Any]] {
    ensureCentralManager()
    let peripherals = centralManager.retrievePeripherals(withIdentifiers: identifiers)
    return peripherals.map { peripheral in
      self.peripherals[peripheral.identifier] = peripheral
      return [
        "id": peripheral.identifier.uuidString,
        "name": peripheral.name ?? "Cached Device",
        "rssi": 0
      ]
    }
  }

  func retrieveConnectedPeripherals(serviceUUIDs: [CBUUID]) -> [[String: Any]] {
    ensureCentralManager()
    let peripherals = centralManager.retrieveConnectedPeripherals(withServices: serviceUUIDs)
    return peripherals.map { peripheral in
      self.peripherals[peripheral.identifier] = peripheral
      return [
        "id": peripheral.identifier.uuidString,
        "name": peripheral.name ?? "Connected Device",
        "rssi": 0
      ]
    }
  }

  // MARK: - 查找工具

  private func findService(deviceId: UUID, serviceId: String) -> CBService? {
    let serviceUuid = CBUUID(string: serviceId)
    if let service = servicesByPeripheral[deviceId]?[serviceUuid.uuidString] {
      return service
    }
    // 兼容大小写/格式差异
    return peripherals[deviceId]?.services?.first { $0.uuid.uuidString.lowercased() == serviceId.lowercased() }
  }

  private func findCharacteristic(
    deviceId: String, serviceId: String, characteristicId: String
  ) -> CBCharacteristic? {
    guard let uuid = UUID(uuidString: deviceId),
          let service = findService(deviceId: uuid, serviceId: serviceId) else { return nil }
    return service.characteristics?.first {
      $0.uuid.uuidString.lowercased() == characteristicId.lowercased()
    }
  }

  /// 特征属性 → 字符串数组。
  private func propertiesStrings(_ properties: CBCharacteristicProperties) -> [String] {
    var names: [String] = []
    if properties.contains(.read) { names.append("read") }
    if properties.contains(.write) { names.append("write") }
    if properties.contains(.writeWithoutResponse) { names.append("writeWithoutResponse") }
    if properties.contains(.notify) { names.append("notify") }
    if properties.contains(.indicate) { names.append("indicate") }
    return names
  }

  // MARK: - 事件上报

  /// 事件通道订阅建立后重放最近一次适配器状态。
  ///
  /// Dart 层在 configure 之后才订阅事件流，而状态上报发生在
  /// configure（manager 创建）时，会早于订阅导致初始状态丢失；
  /// 这里在 onListen 时补发一次，保证 Dart 层能拿到准确状态。
  func emitCachedState() {
    emit(event: "stateChanged", data: ["state": lastAdapterState])
  }

  private func emit(event: String, data: [String: Any]) {
    var payload = data
    payload["event"] = event
    eventSink?(payload)
  }

  /// 设备模型字典（用于检索接口返回）。
  private func deviceMap(_ peripheral: CBPeripheral, name: String, rssi: Int) -> [String: Any] {
    [
      "id": peripheral.identifier.uuidString,
      "name": name,
      "rssi": rssi
    ]
  }

  /// 服务信息字典（无特征）。
  private func serviceMap(_ service: CBService, withCharacteristics: Bool) -> [String: Any] {
    if withCharacteristics {
      return [
        "uuid": service.uuid.uuidString,
        "characteristics": service.characteristics?.map { characteristic -> [String: Any] in
          [
            "uuid": characteristic.uuid.uuidString,
            "properties": propertiesStrings(characteristic.properties),
            "isNotifying": characteristic.isNotifying
          ]
        } ?? []
      ]
    }
    return [
      "uuid": service.uuid.uuidString,
      "characteristics": []
    ]
  }
}

// MARK: - CBCentralManagerDelegate

extension BleCentralManager: CBCentralManagerDelegate {

  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    lastAdapterState = central.state.rawValue
    emit(event: "stateChanged", data: ["state": central.state.rawValue])
    // 状态恢复为 poweredOn 且此前在扫描，恢复扫描
    if central.state == .poweredOn, isScanning {
      central.scanForPeripherals(withServices: nil, options: nil)
    }
  }

  /// 状态恢复：App 被系统杀掉后重新启动时恢复之前的连接。
  func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
    let restored = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] ?? []
    for peripheral in restored {
      peripheral.delegate = self
      peripherals[peripheral.identifier] = peripheral
      emit(event: "stateRestored", data: ["deviceId": peripheral.identifier.uuidString])
    }
  }

  func centralManager(
    _ central: CBCentralManager,
    didDiscover peripheral: CBPeripheral,
    advertisementData: [String: Any],
    rssi RSSI: NSNumber
  ) {
    let name = peripheral.name
      ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String
      ?? "Unknown Device"
    peripherals[peripheral.identifier] = peripheral
    emit(event: "deviceDiscovered", data: deviceMap(peripheral, name: name, rssi: RSSI.intValue))
  }

  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    connectTimeouts[peripheral.identifier]?.invalidate()
    connectTimeouts[peripheral.identifier] = nil
    peripheral.delegate = self
    emit(event: "connectionChanged", data: [
      "deviceId": peripheral.identifier.uuidString,
      "state": "connected"
    ])
  }

  func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
    connectTimeouts[peripheral.identifier]?.invalidate()
    connectTimeouts[peripheral.identifier] = nil
    emit(event: "connectionChanged", data: [
      "deviceId": peripheral.identifier.uuidString,
      "state": "failed",
      "error": error?.localizedDescription ?? "Connection failed."
    ])
  }

  func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
    connectTimeouts[peripheral.identifier]?.invalidate()
    connectTimeouts[peripheral.identifier] = nil
    servicesByPeripheral[peripheral.identifier] = nil
    emit(event: "connectionChanged", data: [
      "deviceId": peripheral.identifier.uuidString,
      "state": "disconnected",
      "error": error?.localizedDescription
    ])
  }
}

// MARK: - CBPeripheralDelegate

extension BleCentralManager: CBPeripheralDelegate {

  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    if let error {
      emit(event: "connectionChanged", data: [
        "deviceId": peripheral.identifier.uuidString,
        "state": "failed",
        "error": error.localizedDescription
      ])
      return
    }
    // 逐服务上报（无特征），Dart 层据此发起特征发现
    for service in peripheral.services ?? [] {
      var table = servicesByPeripheral[peripheral.identifier] ?? [:]
      table[service.uuid.uuidString] = service
      servicesByPeripheral[peripheral.identifier] = table
      emit(event: "servicesDiscovered", data: [
        "deviceId": peripheral.identifier.uuidString,
        "service": serviceMap(service, withCharacteristics: false)
      ])
    }
  }

  func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
    if let error {
      emit(event: "connectionChanged", data: [
        "deviceId": peripheral.identifier.uuidString,
        "state": "failed",
        "error": error.localizedDescription
      ])
      return
    }
    // 上报该服务（含特征），Dart 层据此匹配角色
    emit(event: "servicesDiscovered", data: [
      "deviceId": peripheral.identifier.uuidString,
      "service": serviceMap(service, withCharacteristics: true)
    ])
  }

  func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
    if let error {
      // 读操作失败使用独立事件 readFailed，避免与 writeCompleted 混淆
      emit(event: "readFailed", data: [
        "deviceId": peripheral.identifier.uuidString,
        "serviceId": characteristic.service?.uuid.uuidString ?? "",
        "characteristicId": characteristic.uuid.uuidString,
        "error": error.localizedDescription
      ])
      return
    }
    emit(event: "characteristicValueChanged", data: [
      "deviceId": peripheral.identifier.uuidString,
      "serviceId": characteristic.service?.uuid.uuidString ?? "",
      "characteristicId": characteristic.uuid.uuidString,
      "value": FlutterStandardTypedData(bytes: characteristic.value ?? Data())
    ])
  }

  func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
    emit(event: "writeCompleted", data: [
      "deviceId": peripheral.identifier.uuidString,
      "serviceId": characteristic.service?.uuid.uuidString ?? "",
      "characteristicId": characteristic.uuid.uuidString,
      "error": error?.localizedDescription
    ])
  }

  func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
    emit(event: "readyToWrite", data: ["deviceId": peripheral.identifier.uuidString])
  }
}
