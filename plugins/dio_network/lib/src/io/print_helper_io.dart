import 'dart:io';

/// 直接写入 stdout，绕过 Flutter 的 Zone print 拦截，
/// 避免控制台输出中出现 `flutter: ` 前缀。
void rawPrint(String line) {
  stdout.writeln(line);
}
