import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'api_error.dart';
import 'api_response.dart';
import 'dio_network.dart';
import 'http_method.dart';
import 'upload_file.dart';

/// [DioNetwork] 便捷方法扩展
///
/// 基于核心方法（[DioNetwork.request] / [DioNetwork.requestList] /
/// [DioNetwork.uploadFiles]）封装的糖衣方法，仅为简化调用而存在，
/// 不引入任何新逻辑。核心请求流程请见主类。
extension DioNetworkConvenience on DioNetwork {
  // ────────────────────────────────────────────────────────────────────────
  // HTTP 动词便捷方法
  // ────────────────────────────────────────────────────────────────────────

  /// GET 请求
  ///
  /// 便捷方法，等价于 `request(path, method: HttpMethod.get, ...)`。
  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    JsonConverter<T>? converter,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    Duration? connectTimeout,
    Duration? receiveTimeout,
    bool? enableLog,
  }) {
    return request<T>(
      path,
      method: HttpMethod.get,
      queryParameters: queryParameters,
      headers: headers,
      converter: converter,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
      enableLog: enableLog,
    );
  }

  /// GET 请求并将 data（JSON 数组）转为模型列表
  Future<ApiResponse<List<E>>> getList<E>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    required JsonConverter<E> converter,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    Duration? connectTimeout,
    Duration? receiveTimeout,
    bool? enableLog,
  }) {
    return requestList<E>(
      path,
      method: HttpMethod.get,
      queryParameters: queryParameters,
      headers: headers,
      converter: converter,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
      enableLog: enableLog,
    );
  }

  /// POST 请求
  ///
  /// 便捷方法，等价于 `request(path, method: HttpMethod.post, ...)`。
  Future<ApiResponse<T>> post<T>(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    JsonConverter<T>? converter,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    Duration? connectTimeout,
    Duration? sendTimeout,
    Duration? receiveTimeout,
    bool? enableLog,
  }) {
    return request<T>(
      path,
      method: HttpMethod.post,
      body: body,
      queryParameters: queryParameters,
      headers: headers,
      converter: converter,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
      connectTimeout: connectTimeout,
      sendTimeout: sendTimeout,
      receiveTimeout: receiveTimeout,
      enableLog: enableLog,
    );
  }

  /// POST 请求并将 data（JSON 数组）转为模型列表
  Future<ApiResponse<List<E>>> postList<E>(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    required JsonConverter<E> converter,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    Duration? connectTimeout,
    Duration? sendTimeout,
    Duration? receiveTimeout,
    bool? enableLog,
  }) {
    return requestList<E>(
      path,
      method: HttpMethod.post,
      body: body,
      queryParameters: queryParameters,
      headers: headers,
      converter: converter,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
      connectTimeout: connectTimeout,
      sendTimeout: sendTimeout,
      receiveTimeout: receiveTimeout,
      enableLog: enableLog,
    );
  }

  /// PUT 请求
  ///
  /// 便捷方法，等价于 `request(path, method: HttpMethod.put, ...)`。
  Future<ApiResponse<T>> put<T>(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    JsonConverter<T>? converter,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    Duration? connectTimeout,
    Duration? sendTimeout,
    Duration? receiveTimeout,
    bool? enableLog,
  }) {
    return request<T>(
      path,
      method: HttpMethod.put,
      body: body,
      queryParameters: queryParameters,
      headers: headers,
      converter: converter,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
      connectTimeout: connectTimeout,
      sendTimeout: sendTimeout,
      receiveTimeout: receiveTimeout,
      enableLog: enableLog,
    );
  }

  /// DELETE 请求
  ///
  /// 便捷方法，等价于 `request(path, method: HttpMethod.delete, ...)`。
  Future<ApiResponse<T>> delete<T>(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    JsonConverter<T>? converter,
    CancelToken? cancelToken,
    Duration? connectTimeout,
    Duration? receiveTimeout,
    bool? enableLog,
  }) {
    return request<T>(
      path,
      method: HttpMethod.delete,
      body: body,
      queryParameters: queryParameters,
      headers: headers,
      converter: converter,
      cancelToken: cancelToken,
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
      enableLog: enableLog,
    );
  }

  /// PATCH 请求
  ///
  /// 便捷方法，等价于 `request(path, method: HttpMethod.patch, ...)`。
  Future<ApiResponse<T>> patch<T>(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    JsonConverter<T>? converter,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    Duration? connectTimeout,
    Duration? sendTimeout,
    Duration? receiveTimeout,
    bool? enableLog,
  }) {
    return request<T>(
      path,
      method: HttpMethod.patch,
      body: body,
      queryParameters: queryParameters,
      headers: headers,
      converter: converter,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
      connectTimeout: connectTimeout,
      sendTimeout: sendTimeout,
      receiveTimeout: receiveTimeout,
      enableLog: enableLog,
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // 单文件上传
  // ────────────────────────────────────────────────────────────────────────

  /// 文件上传（multipart/form-data，单文件）
  ///
  /// 支持两种来源（二选一，同时传入抛 [ArgumentError]）：
  /// - [filePath]   本地文件路径
  /// - [fileBytes]  内存字节数据（如截图、压缩后的图片字节），
  ///                传入时必须同时指定 [fileName]
  ///
  /// 多文件上传请使用 [DioNetwork.uploadFiles]。
  ///
  /// [fieldName]  服务端接收的字段名
  /// [formData]   额外的表单字段
  /// [headers]    单 URL 独立 Header
  /// [converter]  可选，将上传响应的 data 转为 T；
  ///              未传时 data 类型与 T 不匹配会抛 [ApiError.parse]
  ///              （同 [DioNetwork.request]）
  Future<ApiResponse<T>> upload<T>(
    String path, {
    String? filePath,
    Uint8List? fileBytes,
    String? fileName,
    String fieldName = 'file',
    Map<String, dynamic>? formData,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    JsonConverter<T>? converter,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    Duration? sendTimeout,
    Duration? receiveTimeout,
    bool? enableLog,
  }) {
    final UploadFile file;
    if (filePath != null && fileBytes != null) {
      throw ArgumentError('filePath 与 fileBytes 不能同时传入');
    }
    if (filePath != null) {
      file = UploadFile.fromPath(
        path: filePath,
        fieldName: fieldName,
        fileName: fileName,
      );
    } else if (fileBytes != null) {
      if (fileName == null || fileName.isEmpty) {
        throw ArgumentError('fileBytes 上传时必须指定 fileName');
      }
      file = UploadFile.fromBytes(
        bytes: fileBytes,
        fileName: fileName,
        fieldName: fieldName,
      );
    } else {
      throw ArgumentError('必须传入 filePath 或 fileBytes 之一');
    }

    return uploadFiles<T>(
      path,
      files: [file],
      formData: formData,
      queryParameters: queryParameters,
      headers: headers,
      converter: converter,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      sendTimeout: sendTimeout,
      receiveTimeout: receiveTimeout,
      enableLog: enableLog,
    );
  }
}
