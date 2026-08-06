package com.example.ble_plugin

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

/**
 * BLE 桥接管理器：封装 Android BluetoothAdapter / BluetoothGatt，只做底层桥接。
 *
 * 职责：
 * 1. 扫描、连接、断开、服务/特征发现
 * 2. 特征读写（串行写入队列，避免缓冲区溢出）、通知订阅
 * 3. 底层事件上报（通过 eventSink 转发给 Flutter 层）
 *
 * 不包含任何业务逻辑（应用层协议、状态机、重连策略等均在 Flutter 层）。
 * 事件格式与 iOS 端保持完全一致：
 * `{"event": <事件名>, ...字段}`。
 */
class BleCentralManager(private val context: Context) {

    /** 主线程 Handler：串行化 GATT 操作与队列管理。 */
    private val handler = Handler(Looper.getMainLooper())

    private val bluetoothManager: BluetoothManager? =
        context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager

    private val adapter: BluetoothAdapter? = bluetoothManager?.adapter

    /** 事件上报通道（由 FlutterStreamHandler 注入）。 */
    var eventSink: EventChannel.EventSink? = null

    /** 已连接的 GATT 表（key: 设备地址）。 */
    private val gattByDevice = mutableMapOf<String, BluetoothGatt>()

    /** 连接超时任务表（key: 设备地址）。 */
    private val connectTimeouts = mutableMapOf<String, Runnable>()

    /** 已协商 MTU 表（key: 设备地址 → MTU，默认 23）。 */
    private val mtuByDevice = mutableMapOf<String, Int>()

    /** 是否正在扫描。 */
    @Volatile
    private var isScanning = false

    /** CCCD 描述符 UUID（通知开关）。 */
    private val cccdUuid = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")

    /** 蓝牙开关状态广播接收器。 */
    private val stateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action != BluetoothAdapter.ACTION_STATE_CHANGED) return
            val state = intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, BluetoothAdapter.ERROR)
            lastAdapterState = state
            emit("stateChanged", mapOf("state" to mapAdapterState(state)))
        }
    }

    /** 最近一次适配器状态（原始 Android 状态码），供 onListen 重放。 */
    @Volatile
    private var lastAdapterState = BluetoothAdapter.STATE_OFF

    // MARK: - 初始化与销毁

    init {
        // 监听蓝牙开关状态广播
        val filter = IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(stateReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            context.registerReceiver(stateReceiver, filter)
        }
        // 记录并主动上报一次当前状态（Dart 层据此初始化状态机）
        lastAdapterState = adapter?.state ?: BluetoothAdapter.STATE_OFF
        emit("stateChanged", mapOf("state" to mapAdapterState(lastAdapterState)))
    }

    /**
     * 事件通道订阅建立后重放最近一次适配器状态。
     *
     * Dart 层在 configure 之后才订阅事件流，而状态上报发生在
     * configure（本对象创建）时，会早于订阅导致初始状态丢失；
     * 这里在 onListen 时补发一次，保证 Dart 层能拿到准确状态。
     */
    fun emitCachedState() {
        emit("stateChanged", mapOf("state" to mapAdapterState(lastAdapterState)))
    }

    fun onDestroy() {
        try {
            context.unregisterReceiver(stateReceiver)
        } catch (_: IllegalArgumentException) {
            // 已注销，忽略
        }
        for (gatt in gattByDevice.values) {
            runCatching {
                gatt.disconnect()
                gatt.close()
            }
        }
        gattByDevice.clear()
        mtuByDevice.clear()
        connectTimeouts.clear()
        isScanning = false
    }

    // MARK: - 蓝牙状态

    /** 将 Android 状态码映射为三端约定的状态码（与 CoreBluetooth rawValue 对齐）。 */
    private fun mapAdapterState(state: Int): Int = when (state) {
        BluetoothAdapter.STATE_ON -> 5          // poweredOn
        BluetoothAdapter.STATE_OFF -> 4         // poweredOff
        BluetoothAdapter.STATE_TURNING_ON -> 1  // resetting（过渡态）
        BluetoothAdapter.STATE_TURNING_OFF -> 1 // resetting（过渡态）
        else -> 0                               // unknown
    }

    // MARK: - 扫描

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            val device = result.device ?: return
            emit(
                "deviceDiscovered",
                mapOf(
                    "id" to device.address,
                    "name" to (device.name ?: "Unknown Device"),
                    "rssi" to result.rssi,
                ),
            )
        }

        override fun onScanFailed(errorCode: Int) {
            isScanning = false
        }
    }

    fun startScan(serviceUuids: List<String>?, allowDuplicates: Boolean) {
        val scanner = adapter?.bluetoothLeScanner ?: return
        isScanning = true
        val filters = serviceUuids?.map { serviceUuid ->
            ScanFilter.Builder().setServiceUuid(ParcelUuid.fromString(serviceUuid)).build()
        }
        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()
        // allowDuplicates：Android 底层默认重复上报，此处忽略该参数（与 iOS 差异）。
        scanner.startScan(filters, settings, scanCallback)
    }

    fun stopScan() {
        adapter?.bluetoothLeScanner?.stopScan(scanCallback)
        isScanning = false
    }

    // MARK: - 连接与断开

    fun configure(restorationIdentifier: String?) {
        // Android 无系统级状态恢复能力，此方法仅保持通道协议兼容。
    }

    fun connect(deviceId: String, timeoutMs: Int, result: MethodChannel.Result) {
        val adapter = adapter
        if (adapter == null) {
            result.error("bluetoothUnavailable", "Bluetooth is not available.", null)
            return
        }
        if (gattByDevice.containsKey(deviceId)) {
            // 已在连接/已连接，幂等返回
            result.success(null)
            return
        }
        val device = try {
            adapter.getRemoteDevice(deviceId)
        } catch (e: IllegalArgumentException) {
            result.error("peripheralNotFound", "Bluetooth peripheral was not found.", deviceId)
            return
        }
        val gatt = device.connectGatt(context, false, gattCallback, BluetoothDevice.TRANSPORT_LE)
        gattByDevice[deviceId] = gatt

        // 连接超时：超时后断开并上报失败（与 iOS 行为一致）
        val timeoutRunnable = Runnable {
            synchronized(this@BleCentralManager) {
                val current = gattByDevice[deviceId]
                if (current == null || current !== gatt) return@Runnable
                if (!isConnected(gatt)) {
                    gatt.disconnect()
                    gatt.close()
                    gattByDevice.remove(deviceId)
                    connectTimeouts.remove(deviceId)
                    emit(
                        "connectionChanged",
                        mapOf(
                            "deviceId" to deviceId,
                            "state" to "failed",
                            "error" to "Bluetooth connection timed out.",
                        ),
                    )
                }
            }
        }
        connectTimeouts[deviceId] = timeoutRunnable
        handler.postDelayed(timeoutRunnable, timeoutMs.toLong())
        result.success(null)
    }

    fun disconnect(deviceId: String) {
        connectTimeouts.remove(deviceId)?.let(handler::removeCallbacks)
        // 主动断开会触发 onConnectionStateChange(DISCONNECTED) → 上报 disconnected
        gattByDevice[deviceId]?.disconnect()
    }

    private fun isConnected(gatt: BluetoothGatt): Boolean = try {
        bluetoothManager?.getConnectionState(
            gatt.device,
            BluetoothProfile.GATT,
        ) == BluetoothProfile.STATE_CONNECTED
    } catch (_: SecurityException) {
        false
    }

    // MARK: - 服务与特征发现

    fun discoverServices(deviceId: String, serviceUuids: List<String>?) {
        gattByDevice[deviceId]?.discoverServices()
    }

    fun discoverCharacteristics(deviceId: String, serviceId: String, characteristicUUIDs: List<String>?) {
        // Android 无单服务特征发现 API：重新全量发现即可
        // （onServicesDiscovered 回调会全量上报，Dart 层幂等处理）
        gattByDevice[deviceId]?.discoverServices()
    }

    // MARK: - 读写与通知

    fun readValue(deviceId: String, serviceId: String, characteristicId: String) {
        val gatt = gattByDevice[deviceId] ?: return
        val characteristic = findCharacteristic(deviceId, serviceId, characteristicId) ?: return
        gatt.readCharacteristic(characteristic)
    }

    /**
     * 写入特征值（进入串行写入队列）。
     *
     * - Returns: Android 无 withoutResponse 缓冲反馈，始终返回 true。
     */
    @Synchronized
    fun writeValue(
        deviceId: String,
        serviceId: String,
        characteristicId: String,
        value: ByteArray,
        writeWithResponse: Boolean,
    ): Boolean {
        val gatt = gattByDevice[deviceId] ?: return true
        val characteristic = findCharacteristic(deviceId, serviceId, characteristicId) ?: return true
        writeQueue.addLast(WriteRequest(gatt, characteristic, value, writeWithResponse))
        driveWriteQueue()
        return true
    }

    fun setNotifyValue(deviceId: String, serviceId: String, characteristicId: String, enabled: Boolean) {
        val gatt = gattByDevice[deviceId] ?: return
        val characteristic = findCharacteristic(deviceId, serviceId, characteristicId) ?: return
        gatt.setCharacteristicNotification(characteristic, enabled)
        // 写 CCCD 描述符启用/禁用通知
        val descriptor = characteristic.getDescriptor(cccdUuid) ?: return
        val value = when {
            !enabled -> byteArrayOf(0x00, 0x00)
            characteristic.properties and BluetoothGattCharacteristic.PROPERTY_INDICATE != 0 ->
                byteArrayOf(0x02, 0x00)
            else -> byteArrayOf(0x01, 0x00)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            // API 33+：使用新签名 writeDescriptor(descriptor, value)
            gatt.writeDescriptor(descriptor, value)
        } else {
            // API ≤ 32：使用已废弃的赋值方式（无替代方案）
            @Suppress("DEPRECATION")
            descriptor.value = value
            @Suppress("DEPRECATION")
            gatt.writeDescriptor(descriptor)
        }
    }

    fun requestMtu(deviceId: String, mtu: Int): Int {
        val gatt = gattByDevice[deviceId] ?: return 23
        gatt.requestMtu(mtu)
        // 立即返回当前已知 MTU（协商结果通过 mtuChanged 事件上报）
        return mtuByDevice[deviceId] ?: 23
    }

    /** 最大应用负载长度 = MTU - 3（ATT 头 3 字节）。 */
    fun maximumWriteLength(deviceId: String, withResponse: Boolean): Int {
        val mtu = mtuByDevice[deviceId] ?: 23
        return (mtu - 3).coerceAtLeast(1)
    }

    // MARK: - 设备检索

    fun retrieveKnownPeripherals(identifiers: List<String>): List<Map<String, Any?>> {
        val adapter = adapter ?: return emptyList()
        return identifiers.mapNotNull { id ->
            try {
                val device = adapter.getRemoteDevice(id)
                deviceMap(device, "Cached Device")
            } catch (_: IllegalArgumentException) {
                null
            }
        }
    }

    fun retrieveConnectedPeripherals(serviceUuids: List<String>): List<Map<String, Any?>> {
        val manager = bluetoothManager ?: return emptyList()
        return manager.getConnectedDevices(BluetoothProfile.GATT).map { device ->
            deviceMap(device, "Connected Device")
        }
    }

    // MARK: - 写入串行队列
    //
    // Android 上连续快速写入会溢出底层缓冲区（尤其 withoutResponse 模式），
    // 因此所有写入进入队列，等待上一个写入回调完成后才发送下一个。
    // withoutResponse 在部分旧设备上不会回调 onCharacteristicWrite，
    // 用 100ms 兜底定时器驱动队列，避免卡死。

    private data class WriteRequest(
        val gatt: BluetoothGatt,
        val characteristic: BluetoothGattCharacteristic,
        val value: ByteArray,
        val withResponse: Boolean,
    )

    private val writeQueue = ArrayDeque<WriteRequest>()

    /** 当前正在写入的请求（null 表示空闲）。 */
    private var currentWrite: WriteRequest? = null

    /** withoutResponse 兜底定时器表。 */
    private val writeFallbacks = mutableMapOf<WriteRequest, Runnable>()

    @Synchronized
    private fun driveWriteQueue() {
        if (currentWrite != null) return
        val request = writeQueue.removeFirstOrNull() ?: return
        currentWrite = request
        val type = if (request.withResponse) {
            BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
        } else {
            BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
        }
        // API 33+ 返回状态码：0 = 成功（BluetoothStatusCodes.SUCCESS）
        val status = request.gatt.writeCharacteristic(
            request.characteristic,
            request.value,
            type,
        )
        if (status != 0) {
            // 底层拒绝写入（如已断开连接）
            currentWrite = null
            emitWriteCompleted(request, "Write rejected by the platform (status=$status).")
            driveWriteQueue()
            return
        }
        if (!request.withResponse) {
            // 部分旧设备 withoutResponse 无回调：短延时兜底驱动队列
            val fallback = Runnable {
                synchronized(this@BleCentralManager) {
                    if (currentWrite === request) {
                        currentWrite = null
                        writeFallbacks.remove(request)
                        emitWriteCompleted(request, null)
                        driveWriteQueue()
                    }
                }
            }
            writeFallbacks[request] = fallback
            handler.postDelayed(fallback, 100)
        }
    }

    /** 写入完成（由 onCharacteristicWrite 或兜底定时器调用）。 */
    @Synchronized
    private fun finishWrite(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, error: String?) {
        val request = currentWrite
        if (request == null || request.gatt !== gatt || request.characteristic !== characteristic) {
            // 不是当前写入的响应（如 withoutResponse 的延迟回调），忽略
            return
        }
        currentWrite = null
        writeFallbacks.remove(request)?.let(handler::removeCallbacks)
        emitWriteCompleted(request, error)
        driveWriteQueue()
    }

    private fun emitWriteCompleted(request: WriteRequest, error: String?) {
        emit(
            "writeCompleted",
            mapOf(
                "deviceId" to request.gatt.device.address,
                "serviceId" to request.characteristic.service.uuid.toString(),
                "characteristicId" to request.characteristic.uuid.toString(),
                "error" to error,
            ),
        )
    }

    // MARK: - GATT 回调

    private val gattCallback = object : BluetoothGattCallback() {

        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            val deviceId = gatt.device.address
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                connectTimeouts.remove(deviceId)?.let(handler::removeCallbacks)
                emit(
                    "connectionChanged",
                    mapOf("deviceId" to deviceId, "state" to "connected"),
                )
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                connectTimeouts.remove(deviceId)?.let(handler::removeCallbacks)
                mtuByDevice.remove(deviceId)
                if (gattByDevice[deviceId] === gatt) {
                    gatt.close()
                    gattByDevice.remove(deviceId)
                }
                val error = if (status != BluetoothGatt.GATT_SUCCESS) {
                    "Connection lost (status=$status)."
                } else {
                    null
                }
                emit(
                    "connectionChanged",
                    mapOf(
                        "deviceId" to deviceId,
                        "state" to "disconnected",
                        "error" to error,
                    ),
                )
            }
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            val deviceId = gatt.device.address
            if (status != BluetoothGatt.GATT_SUCCESS) {
                emit(
                    "connectionChanged",
                    mapOf(
                        "deviceId" to deviceId,
                        "state" to "failed",
                        "error" to "Service discovery failed (status=$status).",
                    ),
                )
                return
            }
            // 全量上报（含特征），Dart 层据此匹配角色
            for (service in gatt.services) {
                emit(
                    "servicesDiscovered",
                    mapOf("deviceId" to deviceId, "service" to serviceMap(service)),
                )
            }
        }

        // API 33+：4 参数版，value 通过参数传入（避免废弃 API）
        override fun onCharacteristicRead(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            value: ByteArray,
            status: Int,
        ) {
            if (status != BluetoothGatt.GATT_SUCCESS) {
                emit(
                    "readFailed",
                    mapOf(
                        "deviceId" to gatt.device.address,
                        "serviceId" to characteristic.service.uuid.toString(),
                        "characteristicId" to characteristic.uuid.toString(),
                        "error" to "Read failed (status=$status).",
                    ),
                )
                return
            }
            emit(
                "characteristicValueChanged",
                mapOf(
                    "deviceId" to gatt.device.address,
                    "serviceId" to characteristic.service.uuid.toString(),
                    "characteristicId" to characteristic.uuid.toString(),
                    "value" to value,
                ),
            )
        }

        // API ≤ 32：3 参数版（已废弃），value 需从 characteristic.value 获取
        @Deprecated("Deprecated in API 33", ReplaceWith("onCharacteristicRead(gatt, characteristic, value, status)"))
        override fun onCharacteristicRead(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            status: Int,
        ) {
            @Suppress("DEPRECATION")
            val value = characteristic.value
            onCharacteristicRead(gatt, characteristic, value, status)
        }

        override fun onCharacteristicWrite(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            status: Int,
        ) {
            val error = if (status != BluetoothGatt.GATT_SUCCESS) {
                "Write failed (status=$status)."
            } else {
                null
            }
            finishWrite(gatt, characteristic, error)
        }

        override fun onMtuChanged(gatt: BluetoothGatt, mtu: Int, status: Int) {
            val deviceId = gatt.device.address
            if (status == BluetoothGatt.GATT_SUCCESS) {
                mtuByDevice[deviceId] = mtu
                emit("mtuChanged", mapOf("deviceId" to deviceId, "mtu" to mtu))
            }
        }
    }

    // MARK: - 查找工具

    private fun findService(deviceId: String, serviceId: String): android.bluetooth.BluetoothGattService? {
        val gatt = gattByDevice[deviceId] ?: return null
        return gatt.services.firstOrNull { it.uuid.toString().equals(serviceId, ignoreCase = true) }
    }

    private fun findCharacteristic(
        deviceId: String,
        serviceId: String,
        characteristicId: String,
    ): BluetoothGattCharacteristic? {
        val service = findService(deviceId, serviceId) ?: return null
        return service.characteristics.firstOrNull {
            it.uuid.toString().equals(characteristicId, ignoreCase = true)
        }
    }

    /** 特征属性 → 字符串数组（与 iOS 端命名一致）。 */
    private fun propertiesStrings(properties: Int): List<String> {
        val names = mutableListOf<String>()
        if (properties and BluetoothGattCharacteristic.PROPERTY_READ != 0) names.add("read")
        if (properties and BluetoothGattCharacteristic.PROPERTY_WRITE != 0) names.add("write")
        if (properties and BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE != 0) {
            names.add("writeWithoutResponse")
        }
        if (properties and BluetoothGattCharacteristic.PROPERTY_NOTIFY != 0) names.add("notify")
        if (properties and BluetoothGattCharacteristic.PROPERTY_INDICATE != 0) names.add("indicate")
        return names
    }

    private fun serviceMap(service: android.bluetooth.BluetoothGattService): Map<String, Any?> = mapOf(
        "uuid" to service.uuid.toString(),
        "characteristics" to service.characteristics.map { characteristic ->
            val descriptor = characteristic.getDescriptor(cccdUuid)
            @Suppress("DEPRECATION")
            val isNotifying = descriptor?.value?.isNotEmpty() == true
            mapOf(
                "uuid" to characteristic.uuid.toString(),
                "properties" to propertiesStrings(characteristic.properties),
                "isNotifying" to isNotifying,
            )
        },
    )

    private fun deviceMap(device: BluetoothDevice, fallbackName: String): Map<String, Any?> = mapOf(
        "id" to device.address,
        "name" to (device.name ?: fallbackName),
        "rssi" to 0,
    )

    // MARK: - 事件上报

    private fun emit(event: String, data: Map<String, Any?>) {
        val payload = data.toMutableMap()
        payload["event"] = event
        eventSink?.success(payload)
    }
}
