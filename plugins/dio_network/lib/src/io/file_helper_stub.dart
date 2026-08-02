// 文件操作助手（Web 平台 stub）
//
// Web 端无文件系统，且 dio 的 download 在 Web 端本身不受支持，
// 这些方法不会被真正执行，仅为保证编译通过。

/// 删除文件（Web 端空实现）
Future<void> deleteFileIfExists(String path) async {}

/// 移动文件（Web 端空实现）
Future<void> moveFile(String from, String to) async {}
