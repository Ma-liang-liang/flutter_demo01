import 'dart:io';

/// 文件操作助手（IO 平台实现），供下载流程使用。

/// 删除文件（不存在则忽略，删除失败也忽略——仅用于清理临时文件）
Future<void> deleteFileIfExists(String path) async {
  try {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  } catch (_) {
    // 清理失败不影响主流程
  }
}

/// 移动文件：先删除已存在的目标文件，再重命名
///
/// 用于下载完成后的原子落盘：调用方先下载到临时文件，
/// 再通过本方法移动到目标路径，避免中断残留不完整文件。
///
/// 当 rename 失败时（如跨文件系统/分区），自动 fallback 为 copy + delete。
Future<void> moveFile(String from, String to) async {
  final dest = File(to);
  if (await dest.exists()) {
    await dest.delete();
  }
  try {
    await File(from).rename(to);
  } on FileSystemException {
    // 跨文件系统 rename 会失败，fallback 为 copy + delete
    await File(from).copy(to);
    await File(from).delete();
  }
}
