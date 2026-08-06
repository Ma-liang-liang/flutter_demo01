## 0.1.0

- Initial release.
- Architecture: all business logic in Dart, native side only bridges CoreBluetooth / BluetoothGatt.
- Application-layer protocol: 22-byte frame header (magic + version + type + sequence + offset + totalLength + payloadLen + CRC32).
- Reliable transfer: ACK window, timeout retry, fire-and-forget vs applicationAck modes.
- Auto-reconnect with exponential backoff and equal jitter.
- Breakpoint resume: saves context on disconnect, auto-resumes on reconnect.
- iOS state restoration with defensive degradation (auto-disables if host app lacks bluetooth-central background mode).
- Android serial write queue with 100ms fallback timer for withoutResponse.
- 37 unit tests covering protocol codec, CRC32, transfer logic, and resume.
