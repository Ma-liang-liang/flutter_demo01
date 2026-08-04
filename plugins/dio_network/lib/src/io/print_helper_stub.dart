// Web 平台无 dart:io，回退到 print（Web 端无 flutter: 前缀问题）

/// Web 平台使用 print 输出（浏览器控制台无 flutter: 前缀）
void rawPrint(String line) {
  // ignore: avoid_print
  print(line);
}
