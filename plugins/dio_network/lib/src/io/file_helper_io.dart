import 'dart:io';

/// 文件操作助手（IO 平台实现），供下载流程使用。

/// 获取文件长度（不存在或读取失败返回 0），用于断点续传探测已有进度
Future<int> fileLength(String path) async {
  try {
    final file = File(path);
    if (await file.exists()) {
      return await file.length();
    }
  } catch (_) {
    // 探测失败按无进度处理
  }
  return 0;
}

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

/// 下载写入目标：封装 [RandomAccessFile]，支持追加（断点续传）/ 覆盖模式
abstract class DownloadSink {
  /// 写入一块数据
  Future<void> write(List<int> bytes);

  /// 关闭并刷盘
  Future<void> close();
}

/// 打开下载写入目标，[append] 为 true 时以追加模式打开（断点续传）
DownloadSink openDownloadSink(String path, {required bool append}) =>
    _IoDownloadSink(path, append);

class _IoDownloadSink implements DownloadSink {
  _IoDownloadSink(this._path, this._append);

  final String _path;
  final bool _append;
  RandomAccessFile? _raf;

  Future<RandomAccessFile> _file() async {
    return _raf ??= await File(_path).open(
      mode: _append ? FileMode.append : FileMode.write,
    );
  }

  @override
  Future<void> write(List<int> bytes) async {
    await (await _file()).writeFrom(bytes);
  }

  @override
  Future<void> close() async {
    await _raf?.close();
    _raf = null;
  }
}
