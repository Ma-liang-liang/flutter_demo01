import 'dart:typed_data';

import 'package:dio/dio.dart';

/// 上传文件描述
///
/// 支持两种来源：
/// - 本地文件路径：[UploadFile.fromPath]
/// - 内存字节数据：[UploadFile.fromBytes]（如截图、压缩后的图片字节）
///
/// 配合 [DioNetwork.uploadFiles] 可一次上传多个文件，
/// 每个文件可指定独立的 [fieldName]（服务端接收字段名）与 [fileName]。
class UploadFile {
  UploadFile._({
    this.path,
    this.bytes,
    required this.fieldName,
    this.fileName,
  });

  /// 从本地文件路径构造
  ///
  /// [fieldName] 服务端接收的字段名，默认 `file`
  /// [fileName]  传给服务端的文件名，默认取路径中的文件名
  UploadFile.fromPath({
    required String path,
    String fieldName = 'file',
    String? fileName,
  }) : this._(path: path, fieldName: fieldName, fileName: fileName);

  /// 从内存字节构造
  ///
  /// [fileName] 必填（multipart 表单需要携带文件名，否则部分服务端无法识别）
  UploadFile.fromBytes({
    required Uint8List bytes,
    required String fileName,
    String fieldName = 'file',
  }) : this._(bytes: bytes, fieldName: fieldName, fileName: fileName);

  /// 本地文件路径（与 [bytes] 二选一）
  final String? path;

  /// 内存字节数据（与 [path] 二选一）
  final Uint8List? bytes;

  /// 服务端接收的字段名
  final String fieldName;

  /// 传给服务端的文件名
  final String? fileName;

  /// 是否为内存字节来源
  bool get isBytes => bytes != null;

  /// 构建 [MultipartFile]
  ///
  /// 注意：必须在每次上传尝试内重新调用（FormData 流只能消费一次），
  /// 不可跨重试复用同一实例。
  Future<MultipartFile> toMultipart() {
    if (bytes != null) {
      return Future.value(MultipartFile.fromBytes(bytes!, filename: fileName));
    }
    return MultipartFile.fromFile(path!, filename: fileName);
  }

  /// 日志描述（不输出字节内容，避免日志膨胀）
  String describe() {
    final source = isBytes ? 'bytes(${bytes!.length}B)' : path;
    return '$fieldName: $source${fileName != null ? ' → $fileName' : ''}';
  }
}
