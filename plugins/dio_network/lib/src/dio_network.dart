import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_error.dart';
import 'api_response.dart';
import 'dio_network_config.dart';
import 'http_method.dart';
import 'io/file_helper_stub.dart'
    if (dart.library.io) 'io/file_helper_io.dart';
import 'io/security_adapter_stub.dart'
    if (dart.library.io) 'io/security_adapter_io.dart';

/// 泛型转换器：将 JSON Map 转为目标模型 T
///
/// 调用方传入 `converter: (json) => User.fromJson(json)`，
/// 框架内部自动完成字典转模型。
typedef JsonConverter<T> = T Function(Map<String, dynamic> json);

/// Dio 业务层网络封装
///
/// 核心能力：
/// - 统一 baseUrl / 公参 / 公共 Header / Content-Type
/// - 单 URL 独立添加参数 / Header
/// - 指定业务码集合走异步拦截回调（并发去重 + 支持自动重试原请求）
/// - HTTP 401/403 未授权统一回调（并发去重 + 支持自动重试原请求）
/// - 统一错误类型 [ApiError]（基于 DioExceptionType 枚举）
/// - 泛型字典转模型（对象用 [request]，列表用 [requestList]，类型安全）
/// - 返回原始 JSON 字符串接口
/// - 日志统一开关 + 敏感 Header 脱敏 + 可自定义日志回调
/// - HTTPS 单向 / 双向认证（仅 IO 平台）
/// - 文件上传 / 下载（走业务码检查，下载原子落盘）
/// - 单请求超时覆盖
/// - 大响应体后台 Isolate 解析 JSON，避免卡顿 UI 线程
class DioNetwork {
  DioNetwork._internal();

  /// 全局单例
  static final DioNetwork instance = DioNetwork._internal();

  late Dio _dio;
  late DioNetworkConfig _config;
  bool _initialized = false;

  /// 正在进行中的拦截回调（key 为业务码，或 [_kUnauthorizedKey]）
  ///
  /// 并发去重：多个请求同时触发同一拦截（如 token 过期）时，
  /// 只执行一次回调，其余请求共享同一 Future 结果。
  final Map<Object, Future<bool>> _pendingInterceptions = {};

  /// 请求序号计数器（日志用，自增标识每一次请求）
  int _requestSeqId = 0;

  /// 全局取消令牌（用于一键取消所有未指定独立 CancelToken 的请求）
  CancelToken _globalCancelToken = CancelToken();

  /// HTTP 401/403 拦截回调的去重 key
  static const Object _kUnauthorizedKey = Object();

  /// 是否已初始化
  bool get isInitialized => _initialized;

  /// 当前配置（只读）
  DioNetworkConfig get config {
    _ensureInitialized();
    return _config;
  }

  /// 初始化
  ///
  /// 在 `main()` 中调用一次，传入全局配置。
  /// 可重复调用以热更新配置（如 baseUrl 切换环境），
  /// 重复调用时会先释放旧的 Dio 实例，避免连接泄漏。
  ///
  /// ❗ 注意：热更新会取消所有进行中的请求，请确保无 in-flight 请求时再调用。
  void init(DioNetworkConfig config) {
    // 热更新前先释放旧实例
    if (_initialized) {
      _log('[DioNetwork] ⚠️ Re-initializing: 旧 Dio 实例将被释放，进行中的请求会被取消');
      _dio.close();
      _pendingInterceptions.clear();
      _requestSeqId = 0;
    }

    _config = config;
    _dio = Dio(BaseOptions(
      baseUrl: config.baseUrl,
      connectTimeout: config.connectTimeout,
      receiveTimeout: config.receiveTimeout,
      sendTimeout: config.sendTimeout,
      headers: _resolveHeaders(config.commonHeaders),
      contentType: config.contentType,
      responseType: ResponseType.plain,
      validateStatus: (_) => true,
    ));

    // 自定义 Adapter（单元测试 mock / 替换底层网络栈）
    if (config.httpClientAdapter != null) {
      _dio.httpClientAdapter = config.httpClientAdapter!;
    }

    // HTTPS 证书配置（仅 IO 平台生效，Web 端忽略并输出提示日志）
    if (config.securityConfig != null) {
      configureSecurityAdapter(_dio, config.securityConfig!, _log);
    }

    _dio.interceptors.addAll(config.extraInterceptors);

    _initialized = true;
    _log('[DioNetwork] ✅ Initialized: ${config.baseUrl}');
    if (config.securityConfig != null) {
      _log(
        '[DioNetwork]    HTTPS: ${config.securityConfig!.isMutual ? "双向认证" : config.securityConfig!.hasTrustedCert ? "单向认证" : "自定义"}',
      );
    }
    if (config.interceptCodes.isNotEmpty) {
      _log('[DioNetwork]    拦截业务码: ${config.interceptCodes}');
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // 核心请求方法
  // ────────────────────────────────────────────────────────────────────────

  /// 请求并返回泛型模型
  ///
  /// [path]           接口路径
  /// [method]         请求方法
  /// [queryParameters] 该请求独立的 query 参数（会与公参合并，同 key 覆盖公参）
  /// [body]           POST / PUT 请求体（公参只合并到 query，不会污染 body）
  /// [headers]        该请求独立的 Header（与公共 Header 合并，同 key 覆盖）
  /// [converter]      字典转模型函数，将 data 转为 T（data 为 List 时请用 [requestList]）
  /// [connectTimeout]  单请求连接超时（覆盖全局）
  /// [sendTimeout]     单请求发送超时（覆盖全局）
  /// [receiveTimeout]  单请求接收超时（覆盖全局）
  ///
  /// 返回 `ApiResponse<T>`，其中 data 已转为 T。
  Future<ApiResponse<T>> request<T>(
    String path, {
    HttpMethod method = HttpMethod.get,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? body,
    Map<String, dynamic>? headers,
    JsonConverter<T>? converter,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    Duration? connectTimeout,
    Duration? sendTimeout,
    Duration? receiveTimeout,
  }) async {
    final apiResponse = await _requestWithPolicy(
      path: path,
      method: method,
      queryParameters: queryParameters,
      body: body,
      headers: headers,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
      connectTimeout: connectTimeout,
      sendTimeout: sendTimeout,
      receiveTimeout: receiveTimeout,
    );

    // 字典转模型
    if (converter != null && apiResponse.data != null) {
      try {
        final converted = _convertData<T>(apiResponse.data, converter);
        return apiResponse.withData<T>(converted);
      } catch (e) {
        _log('[DioNetwork] ❌ Parse error: $e');
        throw ApiError.parse('字典转模型失败: $e', originalError: e);
      }
    }

    // 无 converter 时，原样返回（T 为 dynamic）
    return apiResponse.withData<T>(apiResponse.data as T?);
  }

  /// 请求并将 data（JSON 数组）逐元素转为模型列表
  ///
  /// 列表场景的类型安全入口：`converter` 负责单个元素的转换，
  /// 返回 `ApiResponse<List<E>>`。
  Future<ApiResponse<List<E>>> requestList<E>(
    String path, {
    HttpMethod method = HttpMethod.get,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? body,
    Map<String, dynamic>? headers,
    required JsonConverter<E> converter,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    Duration? connectTimeout,
    Duration? sendTimeout,
    Duration? receiveTimeout,
  }) async {
    final apiResponse = await _requestWithPolicy(
      path: path,
      method: method,
      queryParameters: queryParameters,
      body: body,
      headers: headers,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
      connectTimeout: connectTimeout,
      sendTimeout: sendTimeout,
      receiveTimeout: receiveTimeout,
    );

    if (apiResponse.data == null) {
      return apiResponse.withData<List<E>>(null);
    }

    try {
      final converted = _convertDataList<E>(apiResponse.data, converter);
      return apiResponse.withData<List<E>>(converted);
    } catch (e) {
      _log('[DioNetwork] ❌ Parse error: $e');
      throw ApiError.parse('字典转模型失败: $e', originalError: e);
    }
  }

  /// 请求并返回原始 JSON 字符串
  ///
  /// 不做业务码判断、不做字典转模型，直接把 response body 作为字符串返回，
  /// 调用方可自由自行解析。（HTTP 401/403 仍会走统一回调）
  Future<String> requestRaw(
    String path, {
    HttpMethod method = HttpMethod.get,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? body,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    Duration? connectTimeout,
    Duration? sendTimeout,
    Duration? receiveTimeout,
  }) {
    _ensureInitialized();

    Future<String> attempt() async {
      final response = await _doRequest(
        path: path,
        method: method,
        queryParameters: queryParameters,
        body: body,
        headers: headers,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
        connectTimeout: connectTimeout,
        sendTimeout: sendTimeout,
        receiveTimeout: receiveTimeout,
      );
      return response.data?.toString() ?? '';
    }

    // 重试分支直接复用 attempt：外层仅包装一次，重试中的 401 不再触发回调
    return _withUnauthorizedRetry(attempt, attempt, cancelToken: cancelToken);
  }

  /// 请求并返回 `ApiResponse`（不做字典转模型，但做业务码判断）
  Future<ApiResponse<dynamic>> requestResponse({
    required String path,
    HttpMethod method = HttpMethod.get,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? body,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    Duration? connectTimeout,
    Duration? sendTimeout,
    Duration? receiveTimeout,
  }) {
    return _requestWithPolicy(
      path: path,
      method: method,
      queryParameters: queryParameters,
      body: body,
      headers: headers,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
      connectTimeout: connectTimeout,
      sendTimeout: sendTimeout,
      receiveTimeout: receiveTimeout,
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // 便捷方法
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
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // 文件上传 / 下载
  // ────────────────────────────────────────────────────────────────────────

  /// 文件上传（multipart/form-data）
  ///
  /// [filePath]   本地文件路径
  /// [fieldName]  服务端接收的字段名
  /// [formData]   额外的表单字段
  /// [headers]    单 URL 独立 Header
  /// [converter]  可选，将上传响应的 data 转为 T
  Future<ApiResponse<T>> upload<T>(
    String path, {
    required String filePath,
    String fieldName = 'file',
    Map<String, dynamic>? formData,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    JsonConverter<T>? converter,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    Duration? sendTimeout,
    Duration? receiveTimeout,
  }) async {
    _ensureInitialized();

    final apiResponse = await _withUnauthorizedRetry<ApiResponse<dynamic>>(
      () => _uploadOnce(
        path,
        filePath: filePath,
        fieldName: fieldName,
        formData: formData,
        queryParameters: queryParameters,
        headers: headers,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        sendTimeout: sendTimeout,
        receiveTimeout: receiveTimeout,
        allowBusinessRetry: true,
      ),
      () => _uploadOnce(
        path,
        filePath: filePath,
        fieldName: fieldName,
        formData: formData,
        queryParameters: queryParameters,
        headers: headers,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        sendTimeout: sendTimeout,
        receiveTimeout: receiveTimeout,
        allowBusinessRetry: false,
      ),
      cancelToken: cancelToken,
    );

    if (converter != null && apiResponse.data != null) {
      try {
        final converted = _convertData<T>(apiResponse.data, converter);
        return apiResponse.withData<T>(converted);
      } catch (e) {
        _log('[DioNetwork] ❌ Parse error: $e');
        throw ApiError.parse('字典转模型失败: $e', originalError: e);
      }
    }

    return apiResponse.withData<T>(apiResponse.data as T?);
  }

  /// 单次上传尝试（FormData 在每次尝试内重新构建，流只能消费一次）
  Future<ApiResponse<dynamic>> _uploadOnce(
    String path, {
    required String filePath,
    required String fieldName,
    required bool allowBusinessRetry,
    Map<String, dynamic>? formData,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    Duration? sendTimeout,
    Duration? receiveTimeout,
  }) async {
    final mergedQuery = <String, dynamic>{}
      ..addAll(_config.commonParams)
      ..addAll(queryParameters ?? {});

    // 注意：不要手动设置 Content-Type 为 multipart/form-data，
    // FormData 会自动生成带 boundary 的完整 Content-Type，
    // 手动写死（缺 boundary）会导致服务端无法解析表单。
    final mergedHeaders = _resolveHeaders({
      ..._config.commonHeaders,
      ...?headers,
    });

    final seqId = _logRequest(
      method: 'UPLOAD',
      path: path,
      headers: mergedHeaders,
      query: mergedQuery,
      body: {'file': filePath, 'field': fieldName, ...?formData},
      contentType: 'multipart/form-data',
    );

    final stopwatch = Stopwatch()..start();
    try {
      final formMap = <String, dynamic>{
        ...?formData,
        fieldName: await MultipartFile.fromFile(filePath),
      };

      final response = await _dio.post(
        path,
        data: FormData.fromMap(formMap),
        queryParameters: mergedQuery,
        options: Options(
          headers: mergedHeaders,
          responseType: ResponseType.plain,
          sendTimeout: sendTimeout,
          receiveTimeout: receiveTimeout,
        ),
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
      );
      stopwatch.stop();

      // validateStatus 已放开，手动校验 HTTP 状态码
      await _checkHttpStatus(response, path);

      _logResponse(
        seqId: seqId,
        method: 'UPLOAD',
        path: path,
        statusCode: response.statusCode ?? 0,
        duration: stopwatch.elapsed,
        body: response.data?.toString() ?? '',
        responseHeaders: _extractResponseHeaders(response),
      );

      final apiResponse = await _parseResponse(response);
      final shouldRetry = await _handleBusinessCode(
        code: apiResponse.code,
        message: apiResponse.message,
        data: apiResponse.data,
        path: path,
        allowRetry: allowBusinessRetry,
      );
      if (shouldRetry) {
        // 需要 await：确保重试中的 DioException 仍被下方 catch 转换为 ApiError
        return await _uploadOnce(
          path,
          filePath: filePath,
          fieldName: fieldName,
          formData: formData,
          queryParameters: queryParameters,
          headers: headers,
          cancelToken: cancelToken,
          onSendProgress: onSendProgress,
          sendTimeout: sendTimeout,
          receiveTimeout: receiveTimeout,
          allowBusinessRetry: false,
        );
      }
      return apiResponse;
    } on DioException catch (e) {
      stopwatch.stop();
      if (e.type == DioExceptionType.cancel) {
        throw ApiError.cancel();
      }
      _logError(
        seqId: seqId,
        method: 'UPLOAD',
        path: path,
        duration: stopwatch.elapsed,
        error: '${e.type} ${e.message}',
      );
      throw ApiError.fromDioError(e);
    }
  }

  /// 文件下载
  ///
  /// 先下载到临时文件，成功校验状态码后再移动到 [savePath]，
  /// 避免下载中断 / 404 / 500 时在目标路径残留不完整或错误的文件。
  ///
  /// [url]        完整下载地址（或相对路径）
  /// [savePath]   本地保存路径
  /// [headers]    单 URL 独立 Header
  Future<void> download(
    String url, {
    required String savePath,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    Duration? receiveTimeout,
  }) async {
    _ensureInitialized();

    await _withUnauthorizedRetry<void>(
      () => _downloadOnce(
        url,
        savePath: savePath,
        queryParameters: queryParameters,
        headers: headers,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
        receiveTimeout: receiveTimeout,
      ),
      () => _downloadOnce(
        url,
        savePath: savePath,
        queryParameters: queryParameters,
        headers: headers,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
        receiveTimeout: receiveTimeout,
      ),
      cancelToken: cancelToken,
    );
  }

  /// 单次下载尝试
  Future<void> _downloadOnce(
    String url, {
    required String savePath,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    Duration? receiveTimeout,
  }) async {
    final mergedQuery = <String, dynamic>{}
      ..addAll(_config.commonParams)
      ..addAll(queryParameters ?? {});

    final mergedHeaders = _resolveHeaders({
      ..._config.commonHeaders,
      ...?headers,
    });

    final tempPath = '$savePath.downloading';

    final seqId = _logRequest(
      method: 'DOWNLOAD',
      path: url,
      headers: mergedHeaders,
      query: mergedQuery,
      body: {'savePath': savePath},
    );

    final stopwatch = Stopwatch()..start();
    try {
      final response = await _dio.download(
        url,
        tempPath,
        queryParameters: mergedQuery,
        options: Options(
          headers: mergedHeaders,
          receiveTimeout: receiveTimeout,
        ),
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
      stopwatch.stop();

      // validateStatus 已放开，手动校验状态码，
      // 防止 404/500 的错误页被当作文件保存
      final statusCode = response.statusCode ?? 0;
      if (statusCode < 200 || statusCode >= 300) {
        await deleteFileIfExists(tempPath);
        _logError(
          seqId: seqId,
          method: 'DOWNLOAD',
          path: url,
          duration: stopwatch.elapsed,
          error: 'HTTP $statusCode',
        );
        throw ApiError.fromHttpStatus(statusCode);
      }

      await moveFile(tempPath, savePath);
      _logResponse(
        seqId: seqId,
        method: 'DOWNLOAD',
        path: url,
        statusCode: statusCode,
        duration: stopwatch.elapsed,
        body: '→ $savePath',
        responseHeaders: _extractResponseHeaders(response),
      );
    } on DioException catch (e) {
      stopwatch.stop();
      await deleteFileIfExists(tempPath);
      if (e.type == DioExceptionType.cancel) {
        throw ApiError.cancel();
      }
      _logError(
        seqId: seqId,
        method: 'DOWNLOAD',
        path: url,
        duration: stopwatch.elapsed,
        error: '${e.type} ${e.message}',
      );
      throw ApiError.fromDioError(e);
    } catch (e) {
      stopwatch.stop();
      await deleteFileIfExists(tempPath);
      if (e is ApiError) rethrow;
      _logError(
        seqId: seqId,
        method: 'DOWNLOAD',
        path: url,
        duration: stopwatch.elapsed,
        error: e.toString(),
      );
      throw ApiError(
        type: ApiErrorType.unknown,
        message: e.toString(),
        originalError: e,
      );
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // 内部实现
  // ────────────────────────────────────────────────────────────────────────

  void _ensureInitialized() {
    if (!_initialized) {
      throw const ApiError(
        type: ApiErrorType.unknown,
        message: 'DioNetwork 尚未初始化，请先调用 DioNetwork.instance.init()',
      );
    }
  }

  /// 带完整策略的请求流程：业务码拦截（可重试）+ 401/403 拦截（可重试）
  Future<ApiResponse<dynamic>> _requestWithPolicy({
    required String path,
    required HttpMethod method,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? body,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    Duration? connectTimeout,
    Duration? sendTimeout,
    Duration? receiveTimeout,
    bool allowUnauthorizedRetry = true,
    bool allowBusinessRetry = true,
  }) {
    Future<ApiResponse<dynamic>> attempt() async {
      final response = await _doRequest(
        path: path,
        method: method,
        queryParameters: queryParameters,
        body: body,
        headers: headers,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
        connectTimeout: connectTimeout,
        sendTimeout: sendTimeout,
        receiveTimeout: receiveTimeout,
      );

      final apiResponse = await _parseResponse(response);
      final shouldRetry = await _handleBusinessCode(
        code: apiResponse.code,
        message: apiResponse.message,
        data: apiResponse.data,
        path: path,
        allowRetry: allowBusinessRetry,
      );
      if (shouldRetry) {
        // 拦截方已处理（如 token 刷新成功）→ 重发一次，之后不再任何重试
        return _requestWithPolicy(
          path: path,
          method: method,
          queryParameters: queryParameters,
          body: body,
          headers: headers,
          cancelToken: cancelToken,
          onSendProgress: onSendProgress,
          onReceiveProgress: onReceiveProgress,
          connectTimeout: connectTimeout,
          sendTimeout: sendTimeout,
          receiveTimeout: receiveTimeout,
          allowUnauthorizedRetry: false,
          allowBusinessRetry: false,
        );
      }
      return apiResponse;
    }

    if (!allowUnauthorizedRetry) {
      return attempt();
    }

    return _withUnauthorizedRetry(
      attempt,
      () => _requestWithPolicy(
        path: path,
        method: method,
        queryParameters: queryParameters,
        body: body,
        headers: headers,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
        connectTimeout: connectTimeout,
        sendTimeout: sendTimeout,
        receiveTimeout: receiveTimeout,
        allowUnauthorizedRetry: false,
        allowBusinessRetry: false,
      ),
      cancelToken: cancelToken,
    );
  }

  /// HTTP 401/403 统一处理
  ///
  /// [attempt] 首次尝试；当抛出 [ApiErrorType.unauthorized] 且配置了
  /// [DioNetworkConfig.onUnauthorized] 时触发回调，回调返回 true 则
  /// 通过 [retry] 重发一次原请求（重试中的 401 不再触发回调，防止循环）。
  Future<R> _withUnauthorizedRetry<R>(
    Future<R> Function() attempt,
    Future<R> Function() retry, {
    CancelToken? cancelToken,
  }) async {
    try {
      return await attempt();
    } on ApiError catch (e) {
      if (e.type != ApiErrorType.unauthorized ||
          _config.onUnauthorized == null ||
          (cancelToken != null && cancelToken.isCancelled)) {
        rethrow;
      }
      _log('[DioNetwork]   → 触发 HTTP 未授权拦截回调');
      var shouldRetry = false;
      try {
        shouldRetry = await _runInterceptorDedup(
          _kUnauthorizedKey,
          _config.onUnauthorized!,
        );
      } catch (err) {
        // 回调异常不破坏错误契约：记录日志，继续抛原始 unauthorized 错误
        _log('[DioNetwork] ❌ 未授权回调执行异常: $err');
      }
      if (!shouldRetry) rethrow;
      _log('[DioNetwork]   → 未授权处理完成，重试原请求');
      // 重试中的异常（含再次 401）直接向外传播，不再触发回调，防止循环
      return await retry();
    }
  }

  /// 拦截回调去重执行
  ///
  /// 同一 key（业务码 / 401 标记）的回调同一时间只执行一次，
  /// 并发请求共享结果。典型场景：多个请求同时遇到 token 过期，
  /// 只刷新一次 token。
  Future<bool> _runInterceptorDedup(
    Object key,
    Future<bool> Function() task,
  ) async {
    final pending = _pendingInterceptions[key];
    if (pending != null) {
      _log('[DioNetwork]   → 相同拦截正在处理中，复用结果 (key=$key)');
      return pending;
    }
    try {
      final future = task();
      _pendingInterceptions[key] = future;
      return await future;
    } finally {
      _pendingInterceptions.remove(key);
    }
  }

  /// 业务码处理
  ///
  /// - code == successCode → 返回 false（成功，无需重试）
  /// - code 在 interceptCodes 中 → 触发去重后的异步拦截回调；
  ///   回调返回 true 且 [allowRetry] 为 true 时返回 true（调用方应重试）
  /// - 其余情况 → 抛 [ApiError.business]
  Future<bool> _handleBusinessCode({
    required int code,
    required String message,
    required dynamic data,
    required String path,
    required bool allowRetry,
  }) async {
    // 1. 成功
    if (code == _config.successCode) return false;

    _log('[DioNetwork] ⚠️ Business code $code: $message');

    // 2. 在拦截码集合中 → 走异步回调（并发去重）
    if (_config.interceptCodes.contains(code) &&
        _config.businessInterceptor != null) {
      _log('[DioNetwork]   → 触发业务拦截回调 (code=$code)');
      var shouldRetry = false;
      try {
        shouldRetry = await _runInterceptorDedup(
          code,
          () => _config.businessInterceptor!.call(
            code: code,
            message: message,
            data: data,
            path: path,
          ),
        );
      } catch (e) {
        // 回调异常不破坏错误契约：记录日志，继续抛业务错误
        _log('[DioNetwork] ❌ 业务拦截回调执行异常: $e');
      }
      if (shouldRetry && allowRetry) {
        _log('[DioNetwork]   → 拦截处理完成，重试原请求 (code=$code)');
        return true;
      }
    }

    // 3. 非成功码且未（或不再）重试 → 抛出业务错误
    throw ApiError.business(
      code: code,
      message: message,
      data: data,
    );
  }

  /// 执行 Dio 请求
  Future<Response> _doRequest({
    required String path,
    required HttpMethod method,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? body,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    Duration? connectTimeout,
    Duration? sendTimeout,
    Duration? receiveTimeout,
  }) async {
    _ensureInitialized();

    // 合并公参 + 独立参数（公参只进 query，不污染 body）
    final mergedQuery = <String, dynamic>{}
      ..addAll(_config.commonParams)
      ..addAll(queryParameters ?? {});

    // 合并公共 Header + 独立 Header
    final mergedHeaders = _resolveHeaders({
      ..._config.commonHeaders,
      ...?headers,
    });

    // 取消令牌：用户未指定时使用全局令牌，支持 cancelAll() 一键取消
    final effectiveToken = cancelToken ?? _globalCancelToken;

    final seqId = _logRequest(
      method: method.method,
      path: path,
      headers: mergedHeaders,
      query: mergedQuery,
      body: body,
      contentType: _config.contentType,
    );

    final stopwatch = Stopwatch()..start();
    try {
      // 走 dio.request 而非手动构造 RequestOptions + fetch，
      // 确保 BaseOptions（contentType 等）被完整合并
      final response = await _dio.request(
        path,
        data: body,
        queryParameters: mergedQuery,
        options: Options(
          method: method.method,
          headers: mergedHeaders,
          responseType: ResponseType.plain,
          connectTimeout: connectTimeout,
          sendTimeout: sendTimeout,
          receiveTimeout: receiveTimeout,
        ),
        cancelToken: effectiveToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      stopwatch.stop();

      // HTTP 状态码异常检查
      await _checkHttpStatus(response, path);

      _logResponse(
        seqId: seqId,
        method: method.method,
        path: path,
        statusCode: response.statusCode ?? 0,
        duration: stopwatch.elapsed,
        body: response.data?.toString() ?? '',
        responseHeaders: _extractResponseHeaders(response),
      );
      return response;
    } on DioException catch (e) {
      stopwatch.stop();
      if (e.type == DioExceptionType.cancel) {
        throw ApiError.cancel();
      }
      _logError(
        seqId: seqId,
        method: method.method,
        path: path,
        duration: stopwatch.elapsed,
        error: '${e.type} ${e.message}',
      );
      throw ApiError.fromDioError(e);
    } catch (e) {
      stopwatch.stop();
      if (e is ApiError) rethrow;
      _logError(
        seqId: seqId,
        method: method.method,
        path: path,
        duration: stopwatch.elapsed,
        error: e.toString(),
      );
      throw ApiError(
        type: ApiErrorType.unknown,
        message: e.toString(),
        originalError: e,
      );
    }
  }

  /// 检查 HTTP 状态码
  ///
  /// 由于 `validateStatus: (_) => true`，Dio 不会自动抛 HTTP 错误。
  /// 这里手动检查状态码，非 2xx 且响应不是标准 JSON 结构时抛对应错误。
  Future<void> _checkHttpStatus(Response response, String path) async {
    final statusCode = response.statusCode ?? 200;
    if (statusCode >= 200 && statusCode < 300) return; // 2xx 成功

    final rawStr = response.data?.toString() ?? '';

    // 尝试解析为标准 JSON 结构
    Map<String, dynamic>? jsonMap;
    try {
      final decoded = await _decodeJson(rawStr);
      if (decoded is Map<String, dynamic>) {
        jsonMap = decoded;
      } else if (decoded is Map) {
        jsonMap = decoded.cast<String, dynamic>();
      }
    } catch (_) {
      // 不是 JSON
    }

    // 如果是标准 JSON 结构（有 code 字段），交给业务码处理流程
    if (jsonMap != null && jsonMap.containsKey('code')) return;

    // 非 JSON 或非标准结构 → 按 HTTP 状态码抛错
    _log('[DioNetwork] ❌ HTTP $statusCode: $path');
    throw ApiError.fromHttpStatus(statusCode);
  }

  /// 解析 Response 为 ApiResponse
  Future<ApiResponse<dynamic>> _parseResponse(Response response) async {
    final rawStr = response.data?.toString() ?? '';

    try {
      final decoded = await _decodeJson(rawStr);
      if (decoded is Map) {
        final map = <String, dynamic>{};
        decoded.forEach((key, value) {
          map[key.toString()] = value;
        });
        return ApiResponse.fromMap(map, rawJson: rawStr);
      }
      // 非 Map 类型 — 当作纯 data 返回（视为成功）
      return ApiResponse(
        code: _config.successCode,
        message: '',
        data: decoded,
        rawJson: rawStr,
      );
    } catch (e) {
      // JSON 解析失败，当作纯字符串
      return ApiResponse(
        code: _config.successCode,
        message: '',
        data: rawStr,
        rawJson: rawStr,
      );
    }
  }

  /// JSON 解码：大响应体在后台 Isolate 中解析，避免阻塞 UI 线程
  Future<dynamic> _decodeJson(String raw) {
    if (raw.length >= _config.backgroundDecodeThreshold) {
      return compute(jsonDecode, raw);
    }
    return Future.value(jsonDecode(raw));
  }

  /// 泛型字典转模型
  T? _convertData<T>(dynamic data, JsonConverter<T> converter) {
    if (data == null) return null;

    if (data is Map<String, dynamic>) {
      return converter(data);
    }
    if (data is Map) {
      return converter(data.cast<String, dynamic>());
    }

    throw ArgumentError('无法转换为模型: data 类型为 ${data.runtimeType}');
  }

  /// 泛型列表转模型（逐元素转换）
  List<E> _convertDataList<E>(dynamic data, JsonConverter<E> converter) {
    if (data is! List) {
      throw ArgumentError('data 不是 List: ${data.runtimeType}');
    }
    return data.map((item) {
      if (item is Map<String, dynamic>) {
        return converter(item);
      }
      if (item is Map) {
        return converter(item.cast<String, dynamic>());
      }
      throw ArgumentError('列表元素不是 Map: ${item.runtimeType}');
    }).toList();
  }

  /// 将 `Map<String, dynamic>` Header 转为 Dio 所需的 `Map<String, dynamic>`
  Map<String, dynamic> _resolveHeaders(Map<String, dynamic>? headers) {
    if (headers == null || headers.isEmpty) return {};
    return Map<String, dynamic>.from(headers);
  }

  /// 敏感 Header 脱敏（如 `Authorization: Bear***oken`），防止日志泄露 token
  Map<String, dynamic> _maskHeaders(Map<String, dynamic> headers) {
    final sensitive = _config.sensitiveHeaders;
    if (sensitive.isEmpty) return headers;
    final masked = Map<String, dynamic>.from(headers);
    for (final key in masked.keys) {
      if (sensitive.contains(key.toLowerCase())) {
        final value = masked[key]?.toString() ?? '';
        masked[key] = value.length <= 8
            ? '***'
            : '${value.substring(0, 4)}***${value.substring(value.length - 4)}';
      }
    }
    return masked;
  }

  /// 从 Dio [Response] 中提取响应头，转为可打印的 Map
  ///
  /// 多值 Header 会用 ", " 拼接（如 Set-Cookie 多个）。
  Map<String, dynamic> _extractResponseHeaders(Response response) {
    final map = <String, dynamic>{};
    response.headers.forEach((name, values) {
      map[name] = values.length == 1 ? values.first : values.join(', ');
    });
    return map;
  }

  // ────────────────────────────────────────────────────────────────────────
  // 结构化日志
  // ────────────────────────────────────────────────────────────────────────

  static const String _kLogLine =
      '──────────────────────────────────────────────────────';

  /// 日志打印（底层输出）
  ///
  /// 受 [DioNetworkConfig.enableLog] 统一控制。
  /// 可通过 [DioNetworkConfig.logCallback] 自定义输出方式。
  /// 日志输出失败不会影响业务流程。
  void _log(String message) {
    if (!_config.enableLog) return;
    final callback = _config.logCallback;
    try {
      if (callback != null) {
        callback(message);
      } else {
        // ignore: avoid_print
        print(message);
      }
    } catch (_) {
      // 日志输出失败不影响业务流程
    }
  }

  /// 获取当前时间戳字符串（HH:mm:ss.SSS）
  String _timestamp() {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    final ms = now.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  /// 打印结构化请求日志
  ///
  /// 输出完整 URL、Method、Headers（脱敏）、Query、Body、Content-Type，
  /// 以块状格式呈现，方便开发者在控制台中快速定位。
  /// 返回本次请求的序号 ID，供响应/错误日志关联使用。
  int _logRequest({
    required String method,
    required String path,
    required Map<String, dynamic> headers,
    required Map<String, dynamic> query,
    Map<String, dynamic>? body,
    String? contentType,
  }) {
    if (!_config.enableLog) return ++_requestSeqId;

    final seqId = ++_requestSeqId;
    final fullUrl = _buildFullUrl(path, query);
    final buffer = StringBuffer()
      ..writeln('[DioNetwork] ┌─── Request #$seqId $_kLogLine')
      ..writeln('[DioNetwork] │ ➤ $method  $path')
      ..writeln('[DioNetwork] │   Time:        ${_timestamp()}')
      ..writeln('[DioNetwork] │   URL:         $fullUrl')
      ..writeln('[DioNetwork] │   Method:      $method')
      ..writeln('[DioNetwork] │   Path:        $path');

    if (contentType != null && contentType.isNotEmpty) {
      buffer.writeln('[DioNetwork] │   ContentType: $contentType');
    }
    if (headers.isNotEmpty) {
      buffer.writeln('[DioNetwork] │   Headers:     ${_formatMap(_maskHeaders(headers))}');
    }
    if (query.isNotEmpty) {
      buffer.writeln('[DioNetwork] │   Query:       ${_formatMap(query)}');
    }
    if (body != null && body.isNotEmpty) {
      buffer.writeln('[DioNetwork] │   Body:        ${_formatBody(body)}');
    }

    buffer.write('[DioNetwork] └$_kLogLine');
    _log(buffer.toString());
    return seqId;
  }

  /// 打印结构化响应日志
  ///
  /// 输出状态码、耗时、响应头、响应体大小、格式化后的响应体（JSON 美化）。
  void _logResponse({
    required int seqId,
    required String method,
    required String path,
    required int statusCode,
    required Duration duration,
    required String body,
    Map<String, dynamic>? responseHeaders,
  }) {
    if (!_config.enableLog) return;

    final fullUrl = _buildFullUrl(path, {});
    final bodySize = body.length;
    final sizeStr = bodySize > 1024
        ? '${(bodySize / 1024).toStringAsFixed(1)} KB'
        : '$bodySize B';

    final buffer = StringBuffer()
      ..writeln('[DioNetwork] ┌─── Response #$seqId $_kLogLine')
      ..writeln('[DioNetwork] │ ➤ $method  $path')
      ..writeln('[DioNetwork] │   Time:     ${_timestamp()}')
      ..writeln('[DioNetwork] │   URL:      $fullUrl')
      ..writeln('[DioNetwork] │   Status:   $statusCode')
      ..writeln('[DioNetwork] │   Duration: ${duration.inMilliseconds}ms')
      ..writeln('[DioNetwork] │   Size:     $sizeStr');

    if (responseHeaders != null && responseHeaders.isNotEmpty) {
      buffer.writeln('[DioNetwork] │   RespHeaders: ${_formatMap(responseHeaders)}');
    }

    buffer.writeln('[DioNetwork] │   Body:     ${_formatJson(body)}');
    buffer.write('[DioNetwork] └$_kLogLine');
    _log(buffer.toString());
  }

  /// 打印结构化错误日志
  void _logError({
    required int seqId,
    required String method,
    required String path,
    required Duration duration,
    required String error,
  }) {
    if (!_config.enableLog) return;

    final fullUrl = _buildFullUrl(path, {});
    final buffer = StringBuffer()
      ..writeln('[DioNetwork] ┌─── Error #$seqId $_kLogLine')
      ..writeln('[DioNetwork] │ ➤ $method  $path')
      ..writeln('[DioNetwork] │   Time:     ${_timestamp()}')
      ..writeln('[DioNetwork] │   URL:      $fullUrl')
      ..writeln('[DioNetwork] │   Duration: ${duration.inMilliseconds}ms')
      ..writeln('[DioNetwork] │   Error:    $error');

    buffer.write('[DioNetwork] └$_kLogLine');
    _log(buffer.toString());
  }

  /// 拼接完整 URL（baseUrl + path + query string）
  ///
  /// 若 [path] 已是绝对 URL（以 http:// 或 https:// 开头），则不拼接 baseUrl。
  String _buildFullUrl(String path, Map<String, dynamic> query) {
    String url;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      url = path;
    } else {
      final base = _config.baseUrl.endsWith('/')
          ? _config.baseUrl.substring(0, _config.baseUrl.length - 1)
          : _config.baseUrl;
      final normalizedPath = path.startsWith('/') ? path : '/$path';
      url = '$base$normalizedPath';
    }
    if (query.isEmpty) return url;
    final qs = query.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}')
        .join('&');
    return '$url?$qs';
  }

  /// 格式化 Map 为可读字符串
  String _formatMap(Map<String, dynamic> map) {
    if (map.isEmpty) return '{}';
    final entries = map.entries
        .map((e) => '    ${e.key}: ${e.value}')
        .join('\n[DioNetwork] │     ');
    return '{\n[DioNetwork] │     $entries\n[DioNetwork] │   }';
  }

  /// 格式化请求体（JSON 美化 + 缩进对齐）
  String _formatBody(Map<String, dynamic> body) {
    try {
      final encoded = const JsonEncoder.withIndent('  ').convert(body);
      return _prettyJson(encoded);
    } catch (_) {
      return _truncate(body.toString());
    }
  }

  /// 格式化响应体 JSON（美化 + 截断）
  String _formatJson(String raw) {
    if (raw.isEmpty) return '(empty)';
    try {
      final decoded = jsonDecode(raw);
      return _prettyJson(const JsonEncoder.withIndent('  ').convert(decoded));
    } catch (_) {
      // 非 JSON，直接截断输出
      return _truncate(raw);
    }
  }

  /// JSON 美化输出（带日志前缀缩进）
  String _prettyJson(String json) {
    final lines = json.split('\n');
    if (lines.length <= 1) return json;
    // 多行 JSON：首行直接输出，后续行加日志前缀对齐
    final buffer = StringBuffer(lines.first);
    for (var i = 1; i < lines.length; i++) {
      buffer.write('\n[DioNetwork] │     ${lines[i]}');
    }
    return buffer.toString();
  }

  /// 截断过长日志
  String _truncate(String str, [int maxLen = 500]) {
    if (str.length <= maxLen) return str;
    return '${str.substring(0, maxLen)}... (${str.length} chars)';
  }

  /// 动态更新公共 Header（如登录后注入 token）
  void updateCommonHeaders(Map<String, dynamic> headers) {
    _ensureInitialized();
    _config = _config.copyWith(
      commonHeaders: {..._config.commonHeaders, ...headers},
    );
    _dio.options.headers.addAll(headers);
  }

  /// 动态更新公共参数
  void updateCommonParams(Map<String, dynamic> params) {
    _ensureInitialized();
    _config = _config.copyWith(
      commonParams: {..._config.commonParams, ...params},
    );
  }

  /// 获取底层 Dio 实例（高级用法，如需自定义拦截器等）
  Dio get dio {
    _ensureInitialized();
    return _dio;
  }

  /// 取消所有进行中的请求
  ///
  /// 典型场景：用户退出登录时一键取消所有 pending 请求，
  /// 避免回调到已销毁的页面。
  ///
  /// 注意：仅影响未指定独立 [CancelToken] 的请求。
  /// 若请求传入了自定义 cancelToken，则由调用方自行管理。
  /// 调用后自动重建全局令牌，后续新请求不受影响。
  void cancelAll([String reason = 'cancelAll']) {
    if (!_globalCancelToken.isCancelled) {
      _globalCancelToken.cancel(reason);
    }
    _globalCancelToken = CancelToken();
    _log('[DioNetwork] ⚠️ cancelAll: 已取消所有进行中的请求 (reason: $reason)');
  }

  /// 关闭并释放资源（幂等，未初始化时调用安全）
  void close() {
    if (!_initialized) return;
    if (!_globalCancelToken.isCancelled) {
      _globalCancelToken.cancel('DioNetwork closed');
    }
    _globalCancelToken = CancelToken();
    _dio.close();
    _pendingInterceptions.clear();
    _requestSeqId = 0;
    _initialized = false;
  }
}
