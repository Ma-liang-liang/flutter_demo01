import 'package:dio/dio.dart';

/// 统一网络错误类型
///
/// 整个网络组件对外抛出的异常均为 [ApiError]，通过 [type] 区分错误来源，
/// 调用方可用 `switch (error.type)` 做差异化处理。
class ApiError implements Exception {
  const ApiError({
    required this.type,
    this.code,
    this.message = '',
    this.data,
    this.stackTrace,
    this.httpStatus,
    this.originalError,
  });

  /// 错误类型
  final ApiErrorType type;

  /// 业务码（仅 [ApiErrorType.business] 时有值）
  final int? code;

  /// 错误描述
  final String message;

  /// 原始 data（业务拦截时可能携带）
  final dynamic data;

  /// 原始堆栈
  final StackTrace? stackTrace;

  /// HTTP 状态码（网络层异常时可能有值）
  final int? httpStatus;

  /// 原始异常对象（如 [DioException]），便于线上排查定位
  final Object? originalError;

  /// 从 DioException 精确构造（用枚举，不用字符串匹配）
  factory ApiError.fromDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return ApiError(
          type: ApiErrorType.connectTimeout,
          message: '连接超时',
          httpStatus: e.response?.statusCode,
          originalError: e,
          stackTrace: e.stackTrace,
        );
      case DioExceptionType.sendTimeout:
        return ApiError(
          type: ApiErrorType.sendTimeout,
          message: '发送超时',
          httpStatus: e.response?.statusCode,
          originalError: e,
          stackTrace: e.stackTrace,
        );
      case DioExceptionType.receiveTimeout:
        return ApiError(
          type: ApiErrorType.receiveTimeout,
          message: '接收超时',
          httpStatus: e.response?.statusCode,
          originalError: e,
          stackTrace: e.stackTrace,
        );
      case DioExceptionType.transformTimeout:
        return ApiError(
          type: ApiErrorType.receiveTimeout,
          message: '转换超时',
          httpStatus: e.response?.statusCode,
          originalError: e,
          stackTrace: e.stackTrace,
        );
      case DioExceptionType.badCertificate:
        return ApiError(
          type: ApiErrorType.badCertificate,
          message: '证书校验失败',
          httpStatus: e.response?.statusCode,
          originalError: e,
          stackTrace: e.stackTrace,
        );
      case DioExceptionType.connectionError:
        return ApiError(
          type: ApiErrorType.network,
          message: '网络连接失败: ${e.message}',
          originalError: e,
          stackTrace: e.stackTrace,
        );
      case DioExceptionType.cancel:
        return ApiError(
          type: ApiErrorType.cancel,
          message: '请求已取消',
          originalError: e,
          stackTrace: e.stackTrace,
        );
      case DioExceptionType.badResponse:
        return _fromBadResponse(e);
      case DioExceptionType.unknown:
        return ApiError(
          type: ApiErrorType.unknown,
          message: e.message ?? '未知错误',
          httpStatus: e.response?.statusCode,
          originalError: e,
          stackTrace: e.stackTrace,
        );
    }
  }

  /// 按 HTTP 状态码构造错误
  ///
  /// 用于 `validateStatus` 放开后的手动校验场景（如文件下载、
  /// 非标准 JSON 响应的 4xx / 5xx）。
  factory ApiError.fromHttpStatus(int statusCode, {String? detail}) {
    if (statusCode == 401 || statusCode == 403) {
      return ApiError(
        type: ApiErrorType.unauthorized,
        message: detail ?? '未授权或认证过期',
        httpStatus: statusCode,
      );
    }
    if (statusCode == 404) {
      return ApiError(
        type: ApiErrorType.notFound,
        message: detail ?? '接口不存在',
        httpStatus: statusCode,
      );
    }
    if (statusCode >= 500) {
      return ApiError(
        type: ApiErrorType.serverError,
        message: detail ?? '服务器异常 ($statusCode)',
        httpStatus: statusCode,
      );
    }
    return ApiError(
      type: ApiErrorType.badResponse,
      message: detail ?? 'HTTP $statusCode',
      httpStatus: statusCode,
    );
  }

  /// 从 HTTP 状态码构造对应的错误类型（保留原始 DioException）
  static ApiError _fromBadResponse(DioException e) {
    final statusCode = e.response?.statusCode ?? 0;
    final base = ApiError.fromHttpStatus(
      statusCode,
      detail: statusCode == 401 || statusCode == 403 || statusCode == 404
          ? null
          : 'HTTP $statusCode: ${e.message}',
    );
    return ApiError(
      type: base.type,
      message: base.message,
      httpStatus: base.httpStatus,
      originalError: e,
      stackTrace: e.stackTrace,
    );
  }

  /// 构造业务码错误
  factory ApiError.business({
    required int code,
    String message = '',
    dynamic data,
  }) {
    return ApiError(
      type: ApiErrorType.business,
      code: code,
      message: message,
      data: data,
    );
  }

  /// 构造 JSON 解析错误
  factory ApiError.parse(String message, {Object? originalError}) {
    return ApiError(
      type: ApiErrorType.parse,
      message: message,
      originalError: originalError,
    );
  }

  /// 构造取消请求错误
  factory ApiError.cancel() {
    return const ApiError(type: ApiErrorType.cancel, message: '请求已取消');
  }

  @override
  String toString() {
    if (type == ApiErrorType.business && code != null) {
      return 'ApiError(type: $type, code: $code, message: $message)';
    }
    if (httpStatus != null) {
      return 'ApiError(type: $type, httpStatus: $httpStatus, message: $message)';
    }
    return 'ApiError(type: $type, message: $message)';
  }
}

/// 错误类型枚举
enum ApiErrorType {
  /// 连接超时
  connectTimeout,

  /// 发送超时
  sendTimeout,

  /// 接收超时
  receiveTimeout,

  /// 网络连接失败（无网络 / DNS 失败等）
  network,

  /// 证书校验失败
  badCertificate,

  /// HTTP 状态码异常（4xx / 5xx，但非 401/403/404/5xx 的特殊情况）
  badResponse,

  /// 接口不存在（404）
  notFound,

  /// 未授权 / 认证过期（401 / 403）
  unauthorized,

  /// 服务器异常（5xx）
  serverError,

  /// 业务码错误（服务端返回的 code 在 interceptCodes 中或非 successCode）
  business,

  /// JSON 解析 / 字典转模型失败
  parse,

  /// 请求被取消
  cancel,

  /// 其他未知错误
  unknown,
}
