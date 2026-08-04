// 文件操作助手（Web 平台 stub）
//
// Web 端无文件系统，且 dio 的 download 在 Web 端本身不受支持，
// 这些方法不会被真正执行，仅为保证编译通过。

/// 获取文件长度（Web 端空实现，返回 0）
Future<int> fileLength(String path) async => 0;

/// 删除文件（Web 端空实现）
Future<void> deleteFileIfExists(String path) async {}

/// 移动文件（Web 端空实现）
Future<void> moveFile(String from, String to) async {}

/// 下载写入目标（Web 端 stub）
abstract class DownloadSink {
  /// 写入一块数据
  Future<void> write(List<int> bytes);

  /// 关闭
  Future<void> close();
}

/// 打开下载写入目标（Web 端不支持文件下载，写入时抛 [UnsupportedError]）
DownloadSink openDownloadSink(String path, {required bool append}) =>
    _StubDownloadSink();

class _StubDownloadSink implements DownloadSink {
  @override
  Future<void> write(List<int> bytes) async =>
      throw UnsupportedError('Web 平台不支持文件下载');

  @override
  Future<void> close() async {}
}
