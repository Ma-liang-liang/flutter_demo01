import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_error.dart';
import 'api_response.dart';
import 'dio_network_config.dart';
import 'http_method.dart';
import 'upload_file.dart';
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
/// - 文件上传（单文件/多文件/内存字节）/ 下载（断点续传 + 原子落盘，走业务码检查）
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
  /// [enableLog]       单请求日志开关（非 null 时覆盖全局 [DioNetworkConfig.enableLog]）
  ///
  /// 返回 `ApiResponse<T>`，其中 data 已转为 T。
  ///
  /// ⚠️ 未传 [converter] 时的契约：
  /// - T 为 `dynamic` / 与原始 data 兼容的类型（如 `Map<String, dynamic>`、
  ///   `List`、`String`、`int` 等）→ 原样返回；
  /// - T 与原始 data 类型不匹配（如 T 为具体模型而 data 是 Map）→
  ///   抛出 [ApiError.parse]（不会抛裸 TypeError）。
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
    bool? enableLog,
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
      enableLog: enableLog,
    );

    // 字典转模型
    if (converter != null && apiResponse.data != null) {
      try {
        final converted = _convertData<T>(apiResponse.data, converter);
        return apiResponse.withData<T>(converted);
      } catch (e) {
        _log('[DioNetwork] ❌ Parse error: $e', enableLog: enableLog);
        throw ApiError.parse('字典转模型失败: $e', originalError: e);
      }
    }

    // 无 converter 时安全转型：类型不匹配抛 ApiError.parse，契约明确
    return apiResponse.withData<T>(_castData<T>(apiResponse.data));
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
    bool? enableLog,
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
      enableLog: enableLog,
    );

    if (apiResponse.data == null) {
      return apiResponse.withData<List<E>>(null);
    }

    try {
      final converted = _convertDataList<E>(apiResponse.data, converter);
      return apiResponse.withData<List<E>>(converted);
    } catch (e) {
      _log('[DioNetwork] ❌ Parse error: $e', enableLog: enableLog);
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
    bool? enableLog,
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
        enableLog: enableLog,
      );
      return response.data?.toString() ?? '';
    }

    // 重试分支直接复用 attempt：外层仅包装一次，重试中的 401 不再触发回调
    return _withUnauthorizedRetry(
      attempt,
      attempt,
      cancelToken: cancelToken,
      enableLog: enableLog,
    );
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
    bool? enableLog,
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
      enableLog: enableLog,
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // 文件上传 / 下载
  // ────────────────────────────────────────────────────────────────────────

  /// 多文件上传（multipart/form-data）
  ///
  /// [files] 待上传文件列表，每项可为本地文件或内存字节，
  ///         并可指定独立的字段名 / 文件名（见 [UploadFile]）。
  ///         同字段名多文件会以重复字段（同名多值）形式提交。
  ///
  /// 单文件场景可使用扩展中的便捷方法 `upload`。
  Future<ApiResponse<T>> uploadFiles<T>(
    String path, {
    required List<UploadFile> files,
    Map<String, dynamic>? formData,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    JsonConverter<T>? converter,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    Duration? sendTimeout,
    Duration? receiveTimeout,
    bool? enableLog,
  }) async {
    _ensureInitialized();
    if (files.isEmpty) {
      throw ArgumentError('files 不能为空');
    }

    final apiResponse = await _withUnauthorizedRetry<ApiResponse<dynamic>>(
      () => _uploadOnce(
        path,
        files: files,
        formData: formData,
        queryParameters: queryParameters,
        headers: headers,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        sendTimeout: sendTimeout,
        receiveTimeout: receiveTimeout,
        allowBusinessRetry: true,
        enableLog: enableLog,
      ),
      () => _uploadOnce(
        path,
        files: files,
        formData: formData,
        queryParameters: queryParameters,
        headers: headers,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        sendTimeout: sendTimeout,
        receiveTimeout: receiveTimeout,
        allowBusinessRetry: false,
        enableLog: enableLog,
      ),
      cancelToken: cancelToken,
      enableLog: enableLog,
    );

    if (converter != null && apiResponse.data != null) {
      try {
        final converted = _convertData<T>(apiResponse.data, converter);
        return apiResponse.withData<T>(converted);
      } catch (e) {
        _log('[DioNetwork] ❌ Parse error: $e', enableLog: enableLog);
        throw ApiError.parse('字典转模型失败: $e', originalError: e);
      }
    }

    return apiResponse.withData<T>(_castData<T>(apiResponse.data));
  }

  /// 单次上传尝试（FormData 在每次尝试内重新构建，流只能消费一次）
  Future<ApiResponse<dynamic>> _uploadOnce(
    String path, {
    required List<UploadFile> files,
    required bool allowBusinessRetry,
    Map<String, dynamic>? formData,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    Duration? sendTimeout,
    Duration? receiveTimeout,
    bool? enableLog,
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

    final uploadLogBody = {
      'files': files.map((f) => f.describe()).toList(),
      ...?formData,
    };

    final stopwatch = Stopwatch()..start();
    try {
      // 逐文件构建 MultipartFile；同字段名多文件以 List 形式放入，
      // FormData.fromMap 会将其展开为同名的多个表单条目
      final formMap = <String, dynamic>{...?formData};
      for (final uploadFile in files) {
        final multipart = await uploadFile.toMultipart();
        final existing = formMap[uploadFile.fieldName];
        if (existing == null) {
          formMap[uploadFile.fieldName] = multipart;
        } else if (existing is List) {
          existing.add(multipart);
        } else {
          formMap[uploadFile.fieldName] = [existing, multipart];
        }
      }

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
      await _checkHttpStatus(response, path, enableLog: enableLog);

      // 请求 + 响应合并日志
      _logRequestResponse(
        method: 'UPLOAD',
        path: path,
        requestHeaders: mergedHeaders,
        query: mergedQuery,
        requestBody: uploadLogBody,
        contentType: 'multipart/form-data',
        statusCode: response.statusCode ?? 0,
        duration: stopwatch.elapsed,
        responseBody: response.data?.toString() ?? '',
        responseHeaders: _extractResponseHeaders(response),
        enableLog: enableLog,
      );

      final apiResponse = await _parseResponse(response);
      final shouldRetry = await _handleBusinessCode(
        code: apiResponse.code,
        message: apiResponse.message,
        data: apiResponse.data,
        path: path,
        allowRetry: allowBusinessRetry,
        enableLog: enableLog,
      );
      if (shouldRetry) {
        // 需要 await：确保重试中的 DioException 仍被下方 catch 转换为 ApiError
        return await _uploadOnce(
          path,
          files: files,
          formData: formData,
          queryParameters: queryParameters,
          headers: headers,
          cancelToken: cancelToken,
          onSendProgress: onSendProgress,
          sendTimeout: sendTimeout,
          receiveTimeout: receiveTimeout,
          allowBusinessRetry: false,
          enableLog: enableLog,
        );
      }
      return apiResponse;
    } on DioException catch (e) {
      stopwatch.stop();
      if (e.type == DioExceptionType.cancel) {
        throw ApiError.cancel();
      }
      _logRequestError(
        method: 'UPLOAD',
        path: path,
        requestHeaders: mergedHeaders,
        query: mergedQuery,
        requestBody: uploadLogBody,
        contentType: 'multipart/form-data',
        duration: stopwatch.elapsed,
        error: '${e.type} ${e.message}',
        enableLog: enableLog,
      );
      throw ApiError.fromDioError(e);
    } catch (e) {
      stopwatch.stop();
      if (e is ApiError) rethrow;
      _logRequestError(
        method: 'UPLOAD',
        path: path,
        requestHeaders: mergedHeaders,
        query: mergedQuery,
        requestBody: uploadLogBody,
        contentType: 'multipart/form-data',
        duration: stopwatch.elapsed,
        error: e.toString(),
        enableLog: enableLog,
      );
      throw ApiError(
        type: ApiErrorType.unknown,
        message: e.toString(),
        originalError: e,
      );
    }
  }

  /// 文件下载（支持断点续传）
  ///
  /// 先下载到临时文件（`savePath.downloading`），完整校验后再原子移动到
  /// [savePath]，避免下载中断 / 404 / 500 时在目标路径残留不完整或错误文件。
  ///
  /// [url]        完整下载地址（或相对路径）
  /// [savePath]   本地保存路径
  /// [resume]     断点续传开关（默认开）：
  ///              - 磁盘存在未完成的临时文件时，自动携带 `Range` 头从断点续传；
  ///              - 服务端忽略 Range 返回 200 时自动从头重下；
  ///              - 返回 416（断点已失效）时自动清理临时文件从头重下；
  ///              - 网络中断 / 取消时保留已下载部分，下次调用继续。
  ///              关闭后行为与旧版一致：任何失败都清理临时文件。
  /// [headers]    单 URL 独立 Header
  ///
  /// 进度回调 [onReceiveProgress] 的 count 为**累计已下载字节**（含断点前部分）。
  Future<void> download(
    String url, {
    required String savePath,
    bool resume = true,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    Duration? receiveTimeout,
    bool? enableLog,
  }) async {
    _ensureInitialized();

    await _withUnauthorizedRetry<void>(
      () => _downloadOnce(
        url,
        savePath: savePath,
        resume: resume,
        queryParameters: queryParameters,
        headers: headers,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
        receiveTimeout: receiveTimeout,
        enableLog: enableLog,
      ),
      () => _downloadOnce(
        url,
        savePath: savePath,
        resume: resume,
        queryParameters: queryParameters,
        headers: headers,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
        receiveTimeout: receiveTimeout,
        enableLog: enableLog,
      ),
      cancelToken: cancelToken,
      enableLog: enableLog,
    );
  }

  /// 单次下载尝试（流式下载 + 可选断点续传）
  Future<void> _downloadOnce(
    String url, {
    required String savePath,
    required bool resume,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    Duration? receiveTimeout,
    bool? enableLog,
  }) async {
    final mergedQuery = <String, dynamic>{}
      ..addAll(_config.commonParams)
      ..addAll(queryParameters ?? {});

    final mergedHeaders = _resolveHeaders({
      ..._config.commonHeaders,
      ...?headers,
    });

    final tempPath = '$savePath.downloading';

    // 断点探测：存在未完成的临时文件时携带 Range 头续传
    var downloaded = 0;
    if (resume) {
      downloaded = await fileLength(tempPath);
      if (downloaded > 0) {
        mergedHeaders['range'] = 'bytes=$downloaded-';
      }
    }

    final downloadLogBody = {'savePath': savePath, 'resumeFrom': downloaded};

    // 流式响应需要自行写文件（dio.download 不支持追加模式），
    // 用 fetch + ResponseType.stream 拿到原始字节流
    final requestOptions = RequestOptions(
      method: HttpMethod.get.method,
      baseUrl: _dio.options.baseUrl,
      path: url,
      queryParameters: mergedQuery,
      headers: mergedHeaders,
      responseType: ResponseType.stream,
      connectTimeout: _dio.options.connectTimeout,
      sendTimeout: _dio.options.sendTimeout,
      receiveTimeout: receiveTimeout ?? _dio.options.receiveTimeout,
      // RequestOptions 不继承 BaseOptions 的 validateStatus，
      // 需显式放开，否则 416/4xx 会先被 dio 抛成 DioException，
      // 无法走到下方的 416 断点失效恢复逻辑
      validateStatus: (_) => true,
    );

    final stopwatch = Stopwatch()..start();
    DownloadSink? sink;

    // 标记下载是否已结束（正常完成或异常退出），
    // 防止 whenCancel 回调在下载结束后延迟触发造成无意义的 cancel + failWith
    var downloadFinished = false;

    try {
      final response = await _dio.fetch<ResponseBody>(requestOptions);
      final statusCode = response.statusCode ?? 0;

      // 416 Range Not Satisfiable：断点已失效（文件变更/已完整）
      // → 清理临时文件从头重下（resume: false，不会再携带 Range，不会再次 416）
      if (statusCode == 416) {
        stopwatch.stop();
        await deleteFileIfExists(tempPath);
        _log('[DioNetwork] ⚠️ HTTP 416: 断点已失效，清理临时文件从头重新下载', enableLog: enableLog);
        return await _downloadOnce(
          url,
          savePath: savePath,
          resume: false,
          queryParameters: queryParameters,
          headers: headers,
          cancelToken: cancelToken,
          onReceiveProgress: onReceiveProgress,
          receiveTimeout: receiveTimeout,
          enableLog: enableLog,
        );
      }

      // 非 2xx：不写入任何字节，并清理旧临时文件，
      // 防止 404/500 的错误页被当作文件保存
      if (statusCode < 200 || statusCode >= 300) {
        stopwatch.stop();
        await deleteFileIfExists(tempPath);
        _logRequestError(
          method: 'DOWNLOAD',
          path: url,
          requestHeaders: mergedHeaders,
          query: mergedQuery,
          requestBody: downloadLogBody,
          duration: stopwatch.elapsed,
          error: 'HTTP $statusCode',
          enableLog: enableLog,
        );
        throw ApiError.fromHttpStatus(statusCode);
      }

      final isPartial = statusCode == 206;
      if (!isPartial) {
        // 服务端忽略了 Range（返回 200）→ 从头覆盖下载
        downloaded = 0;
      }

      // 文件总长：206 优先取 Content-Range（bytes start-end/total），
      // 其次 Content-Length；未知时为 null（进度回调 total 传 -1）
      int? total;
      if (isPartial) {
        final contentRange = response.headers.value('content-range');
        if (contentRange != null) {
          total = int.tryParse(contentRange.split('/').last);
        }
      }
      if (total == null) {
        final contentLength = response.headers.value('content-length');
        if (contentLength != null) {
          total = int.tryParse(contentLength);
        }
      }

      sink = openDownloadSink(tempPath, append: isPartial);

      var received = 0;
      final body = response.data!;
      final completer = Completer<void>();

      void failWith(Object error) {
        if (!completer.isCompleted) completer.completeError(error);
      }

      late final StreamSubscription<Uint8List> subscription;
      subscription = body.stream.listen(
        (chunk) {
          // 异步写盘期间暂停订阅，避免背压堆积
          subscription.pause();
          sink!.write(chunk).then((_) {
            received += chunk.length;
            onReceiveProgress?.call(downloaded + received, total ?? -1);
            if (cancelToken != null && cancelToken.isCancelled) {
              subscription.cancel();
              failWith(DioException(
                requestOptions: requestOptions,
                type: DioExceptionType.cancel,
              ));
            } else {
              subscription.resume();
            }
          }).catchError((Object e) {
            subscription.cancel();
            failWith(e);
          });
        },
        onError: (Object e) => failWith(e),
        onDone: completer.complete,
        cancelOnError: true,
      );

      // CancelToken 取消时中断流写入（保留已写部分供续传）
      cancelToken?.whenCancel.then((_) async {
        if (downloadFinished) return; // 下载已结束，忽略延迟的取消回调
        await subscription.cancel();
        failWith(DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.cancel,
        ));
      });

      await completer.future;
      downloadFinished = true;
      await sink.close();
      sink = null;
      stopwatch.stop();

      // 完整性校验：已知总长但未写满 → 保留临时文件报错，下次可续传
      if (total != null && downloaded + received < total) {
        _logRequestError(
          method: 'DOWNLOAD',
          path: url,
          requestHeaders: mergedHeaders,
          query: mergedQuery,
          requestBody: downloadLogBody,
          duration: stopwatch.elapsed,
          error: '下载不完整: ${downloaded + received}/$total 字节',
          enableLog: enableLog,
        );
        throw const ApiError(
          type: ApiErrorType.network,
          message: '下载中断，文件不完整，可重新调用下载以续传',
        );
      }

      await moveFile(tempPath, savePath);
      _logRequestResponse(
        method: 'DOWNLOAD',
        path: url,
        requestHeaders: mergedHeaders,
        query: mergedQuery,
        requestBody: downloadLogBody,
        statusCode: statusCode,
        duration: stopwatch.elapsed,
        responseBody: '→ $savePath (resumeFrom: $downloaded)',
        responseHeaders: _extractResponseHeaders(response),
        enableLog: enableLog,
      );
    } on DioException catch (e) {
      downloadFinished = true;
      stopwatch.stop();
      await sink?.close();
      if (e.type == DioExceptionType.cancel) {
        _log('[DioNetwork] ⚠️ 下载已取消，已保留部分进度: $tempPath', enableLog: enableLog);
        throw ApiError.cancel();
      }
      // 未开启续传时清理临时文件；开启时保留，下次调用从断点继续
      if (!resume) await deleteFileIfExists(tempPath);
      _logRequestError(
        method: 'DOWNLOAD',
        path: url,
        requestHeaders: mergedHeaders,
        query: mergedQuery,
        requestBody: downloadLogBody,
        duration: stopwatch.elapsed,
        error: '${e.type} ${e.message}',
        enableLog: enableLog,
      );
      throw ApiError.fromDioError(e);
    } catch (e) {
      downloadFinished = true;
      stopwatch.stop();
      await sink?.close();
      if (!resume) await deleteFileIfExists(tempPath);
      if (e is ApiError) {
        _logRequestError(
          method: 'DOWNLOAD',
          path: url,
          requestHeaders: mergedHeaders,
          query: mergedQuery,
          requestBody: downloadLogBody,
          duration: stopwatch.elapsed,
          error: e.message,
          enableLog: enableLog,
        );
        rethrow;
      }
      _logRequestError(
        method: 'DOWNLOAD',
        path: url,
        requestHeaders: mergedHeaders,
        query: mergedQuery,
        requestBody: downloadLogBody,
        duration: stopwatch.elapsed,
        error: e.toString(),
        enableLog: enableLog,
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
    bool? enableLog,
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
        enableLog: enableLog,
      );

      final apiResponse = await _parseResponse(response);
      final shouldRetry = await _handleBusinessCode(
        code: apiResponse.code,
        message: apiResponse.message,
        data: apiResponse.data,
        path: path,
        allowRetry: allowBusinessRetry,
        enableLog: enableLog,
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
          enableLog: enableLog,
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
        enableLog: enableLog,
      ),
      cancelToken: cancelToken,
      enableLog: enableLog,
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
    bool? enableLog,
  }) async {
    try {
      return await attempt();
    } on ApiError catch (e) {
      if (e.type != ApiErrorType.unauthorized ||
          _config.onUnauthorized == null ||
          (cancelToken != null && cancelToken.isCancelled)) {
        rethrow;
      }
      _log('[DioNetwork]   → 触发 HTTP 未授权拦截回调', enableLog: enableLog);
      var shouldRetry = false;
      try {
        shouldRetry = await _runInterceptorDedup(
          _kUnauthorizedKey,
          _config.onUnauthorized!,
          enableLog: enableLog,
        );
      } catch (err) {
        // 回调异常不破坏错误契约：记录日志，继续抛原始 unauthorized 错误
        _log('[DioNetwork] ❌ 未授权回调执行异常: $err', enableLog: enableLog);
      }
      if (!shouldRetry) rethrow;
      _log('[DioNetwork]   → 未授权处理完成，重试原请求', enableLog: enableLog);
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
    Future<bool> Function() task, {
    bool? enableLog,
  }) async {
    final pending = _pendingInterceptions[key];
    if (pending != null) {
      _log('[DioNetwork]   → 相同拦截正在处理中，复用结果 (key=$key)', enableLog: enableLog);
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
    bool? enableLog,
  }) async {
    // 1. 成功
    if (code == _config.successCode) return false;

    _log('[DioNetwork] ⚠️ Business code $code: $message', enableLog: enableLog);

    // 2. 在拦截码集合中 → 走异步回调（并发去重）
    if (_config.interceptCodes.contains(code) &&
        _config.businessInterceptor != null) {
      _log('[DioNetwork]   → 触发业务拦截回调 (code=$code)', enableLog: enableLog);
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
          enableLog: enableLog,
        );
      } catch (e) {
        // 回调异常不破坏错误契约：记录日志，继续抛业务错误
        _log('[DioNetwork] ❌ 业务拦截回调执行异常: $e', enableLog: enableLog);
      }
      if (shouldRetry && allowRetry) {
        _log('[DioNetwork]   → 拦截处理完成，重试原请求 (code=$code)', enableLog: enableLog);
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
    bool? enableLog,
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
      await _checkHttpStatus(response, path, enableLog: enableLog);

      // 请求 + 响应合并日志
      _logRequestResponse(
        method: method.method,
        path: path,
        requestHeaders: mergedHeaders,
        query: mergedQuery,
        requestBody: body,
        contentType: _config.contentType,
        statusCode: response.statusCode ?? 0,
        duration: stopwatch.elapsed,
        responseBody: response.data?.toString() ?? '',
        responseHeaders: _extractResponseHeaders(response),
        enableLog: enableLog,
      );
      return response;
    } on DioException catch (e) {
      stopwatch.stop();
      if (e.type == DioExceptionType.cancel) {
        throw ApiError.cancel();
      }
      _logRequestError(
        method: method.method,
        path: path,
        requestHeaders: mergedHeaders,
        query: mergedQuery,
        requestBody: body,
        contentType: _config.contentType,
        duration: stopwatch.elapsed,
        error: '${e.type} ${e.message}',
        enableLog: enableLog,
      );
      throw ApiError.fromDioError(e);
    } catch (e) {
      stopwatch.stop();
      if (e is ApiError) rethrow;
      _logRequestError(
        method: method.method,
        path: path,
        requestHeaders: mergedHeaders,
        query: mergedQuery,
        requestBody: body,
        contentType: _config.contentType,
        duration: stopwatch.elapsed,
        error: e.toString(),
        enableLog: enableLog,
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
  Future<void> _checkHttpStatus(Response response, String path, {bool? enableLog}) async {
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
    _log('[DioNetwork] ❌ HTTP $statusCode: $path', enableLog: enableLog);
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

  /// 无 converter 时的安全转型
  ///
  /// 替代不安全的 `data as T?` 强转：
  /// - data 为 null → 返回 null
  /// - data 已是 T（含 T 为 dynamic / Object）→ 原样返回
  /// - JSON 数字 / 字符串与 T 为 int / double / String 时做合理强转
  ///   （如服务端 `"1"` 形式返回 int 场景，double → int 需无损）
  /// - 其余类型不匹配 → 抛 [ApiError.parse]，提示传入 converter，
  ///   避免调用方收到难以定位的裸 TypeError
  T? _castData<T>(dynamic data) {
    if (data == null) return null;
    if (data is T) return data;

    if (T == int) {
      if (data is double && data == data.toInt()) {
        return data.toInt() as T;
      }
      if (data is String) {
        final parsed = int.tryParse(data);
        if (parsed != null) return parsed as T;
      }
    } else if (T == double) {
      if (data is num) return data.toDouble() as T;
      if (data is String) {
        final parsed = double.tryParse(data);
        if (parsed != null) return parsed as T;
      }
    } else if (T == String) {
      if (data is num || data is bool) return data.toString() as T;
    }

    throw ApiError.parse(
      'data 类型 ${data.runtimeType} 与 $T 不匹配，请传入 converter 完成字典转模型，'
      '或将 T 声明为 dynamic / 与 data 兼容的类型',
    );
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

  /// 单条 print 输出的最大长度
  ///
  /// iOS 调试控制台对单条超长日志会截断（显示 `<…>`），
  /// 因此默认输出通道按行拆分、超长行再分段打印。
  static const int _kPrintChunkSize = 800;

  /// 日志打印（底层输出）
  ///
  /// 受 [DioNetworkConfig.enableLog] 统一控制。
  /// 传入 [enableLog] 可在单次请求中覆盖全局开关（非 null 时优先于全局配置）。
  /// 可通过 [DioNetworkConfig.logCallback] 自定义输出方式（回调仍收到完整消息）。
  /// 默认输出通道按行拆分打印，避免 iOS 控制台截断长日志。
  /// 日志输出失败不会影响业务流程。
  void _log(String message, {bool? enableLog}) {
    final shouldLog = enableLog ?? _config.enableLog;
    if (!shouldLog) return;
    final callback = _config.logCallback;
    try {
      if (callback != null) {
        callback(message);
      } else {
        _printSafe(message);
      }
    } catch (_) {
      // 日志输出失败不影响业务流程
    }
  }

  /// 防截断打印：按行拆分，单行超过 [_kPrintChunkSize] 时分段输出
  void _printSafe(String message) {
    for (final line in message.split('\n')) {
      if (line.length <= _kPrintChunkSize) {
        // ignore: avoid_print
        print(line);
      } else {
        for (var i = 0; i < line.length; i += _kPrintChunkSize) {
          final end = i + _kPrintChunkSize > line.length
              ? line.length
              : i + _kPrintChunkSize;
          // ignore: avoid_print
          print(line.substring(i, end));
        }
      }
    }
  }

  /// 获取当前时间戳字符串（yyyy-MM-dd HH:mm:ss.SSS）
  String _timestamp() {
    final now = DateTime.now();
    final y = now.year.toString();
    final mo = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    final ms = now.millisecond.toString().padLeft(3, '0');
    return '$y-$mo-$d $h:$m:$s.$ms';
  }

  /// 已知的 CDN / 基础设施噪声 Header（小写匹配），
  /// 过滤后只保留业务相关 Header，减少日志噪声。
  static const _kNoiseHeaders = {
    'cf-ray', 'cf-cache-status', 'cf-nel',
    'report-to', 'reporting-endpoints', 'nel',
    'alt-svc', 'via', 'pragma', 'age', 'expires',
    'x-content-type-options', 'x-powered-by',
    'x-ratelimit-limit', 'x-ratelimit-remaining', 'x-ratelimit-reset',
    'access-control-allow-credentials', 'access-control-allow-origin',
    'access-control-allow-methods', 'access-control-allow-headers',
    'connection', 'transfer-encoding', 'keep-alive',
  };

  /// 过滤响应头：移除 CDN / 基础设施噪声 Header，只保留业务相关头
  Map<String, dynamic> _filterResponseHeaders(Map<String, dynamic> headers) {
    return Map.fromEntries(
      headers.entries.where(
        (e) => !_kNoiseHeaders.contains(e.key.toString().toLowerCase()),
      ),
    );
  }

  /// 构建 cURL 命令（可复制粘贴执行，方便发给后端复现）
  String _buildCurl(
    String method,
    String url,
    Map<String, dynamic> headers,
    Map<String, dynamic>? body,
  ) {
    final parts = <String>["curl -X $method '$url'"];
    for (final entry in _maskHeaders(headers).entries) {
      parts.add("-H '${entry.key}: ${entry.value}'");
    }
    if (body != null && body.isNotEmpty) {
      parts.add("-d '${jsonEncode(body)}'");
    }
    final buffer = StringBuffer('[DioNetwork] │   ${parts.first}');
    for (final p in parts.skip(1)) {
      buffer.write(' \\\n[DioNetwork] │     $p');
    }
    return buffer.toString();
  }

  /// 打印请求 + 响应合并日志（响应成功时）
  ///
  /// 一次性输出完整的请求和响应信息，避免分散输出难以关联。
  /// 包含 cURL 命令，方便直接复制发给后端复现。
  void _logRequestResponse({
    required String method,
    required String path,
    required Map<String, dynamic> requestHeaders,
    required Map<String, dynamic> query,
    Map<String, dynamic>? requestBody,
    String? contentType,
    required int statusCode,
    required Duration duration,
    required String responseBody,
    Map<String, dynamic>? responseHeaders,
    bool? enableLog,
  }) {
    final shouldLog = enableLog ?? _config.enableLog;
    if (!shouldLog) return;

    final seqId = ++_requestSeqId;
    final fullUrl = _buildFullUrl(path, query);
    final bodySize = responseBody.length;
    final sizeStr = bodySize > 1024
        ? '${(bodySize / 1024).toStringAsFixed(1)} KB'
        : '$bodySize B';

    final buffer = StringBuffer()
      ..writeln('[DioNetwork] ┌─── #$seqId ─── $method ─── $_kLogLine')
      ..writeln('[DioNetwork] │ ➤ $fullUrl')
      ..writeln('[DioNetwork] │   Time:     ${_timestamp()}')
      ..writeln('[DioNetwork] │   Duration: ${duration.inMilliseconds}ms');

    // ── Request ──
    buffer
      ..writeln('[DioNetwork] │')
      ..writeln('[DioNetwork] │ ── Request ──────────────────────────────────────────');
    if (contentType != null && contentType.isNotEmpty) {
      buffer.writeln('[DioNetwork] │   ContentType: $contentType');
    }
    if (requestHeaders.isNotEmpty) {
      buffer.writeln('[DioNetwork] │   Headers:     ${_formatMap(_maskHeaders(requestHeaders))}');
    }
    if (query.isNotEmpty) {
      buffer.writeln('[DioNetwork] │   Query:       ${_formatMap(query)}');
    }
    if (requestBody != null && requestBody.isNotEmpty) {
      buffer.writeln('[DioNetwork] │   Body:        ${_formatBody(requestBody)}');
    }

    // ── Response ──
    buffer
      ..writeln('[DioNetwork] │')
      ..writeln('[DioNetwork] │ ── Response ─────────────────────────────────────────');
    buffer.writeln('[DioNetwork] │   Status:    $statusCode');
    buffer.writeln('[DioNetwork] │   Size:      $sizeStr');
    if (responseHeaders != null && responseHeaders.isNotEmpty) {
      final filtered = _filterResponseHeaders(responseHeaders);
      if (filtered.isNotEmpty) {
        buffer.writeln('[DioNetwork] │   Headers:    ${_formatMap(filtered)}');
      }
    }
    buffer.writeln('[DioNetwork] │   Body:      ${_formatJson(responseBody)}');

    // ── cURL ──
    buffer
      ..writeln('[DioNetwork] │')
      ..writeln('[DioNetwork] │ ── cURL ──────────────────────────────────────────────');
    buffer.write(_buildCurl(method, fullUrl, requestHeaders, requestBody));

    buffer.write('\n[DioNetwork] └$_kLogLine');
    _log(buffer.toString(), enableLog: enableLog);
  }

  /// 打印请求 + 错误合并日志（请求失败时）
  ///
  /// 一次性输出完整的请求信息和错误信息，避免分散输出难以关联。
  void _logRequestError({
    required String method,
    required String path,
    required Map<String, dynamic> requestHeaders,
    required Map<String, dynamic> query,
    Map<String, dynamic>? requestBody,
    String? contentType,
    required Duration duration,
    required String error,
    bool? enableLog,
  }) {
    final shouldLog = enableLog ?? _config.enableLog;
    if (!shouldLog) return;

    final seqId = ++_requestSeqId;
    final fullUrl = _buildFullUrl(path, query);

    final buffer = StringBuffer()
      ..writeln('[DioNetwork] ┌─── #$seqId ERROR ── $method ─── $_kLogLine')
      ..writeln('[DioNetwork] │ ➤ $fullUrl')
      ..writeln('[DioNetwork] │   Time:     ${_timestamp()}')
      ..writeln('[DioNetwork] │   Duration: ${duration.inMilliseconds}ms');

    // ── Request ──
    buffer
      ..writeln('[DioNetwork] │')
      ..writeln('[DioNetwork] │ ── Request ──────────────────────────────────────────');
    if (contentType != null && contentType.isNotEmpty) {
      buffer.writeln('[DioNetwork] │   ContentType: $contentType');
    }
    if (requestHeaders.isNotEmpty) {
      buffer.writeln('[DioNetwork] │   Headers:     ${_formatMap(_maskHeaders(requestHeaders))}');
    }
    if (query.isNotEmpty) {
      buffer.writeln('[DioNetwork] │   Query:       ${_formatMap(query)}');
    }
    if (requestBody != null && requestBody.isNotEmpty) {
      buffer.writeln('[DioNetwork] │   Body:        ${_formatBody(requestBody)}');
    }

    // ── Error ──
    buffer
      ..writeln('[DioNetwork] │')
      ..writeln('[DioNetwork] │ ── Error ─────────────────────────────────────────────');
    buffer.writeln('[DioNetwork] │   Error:    $error');

    // ── cURL ──
    buffer
      ..writeln('[DioNetwork] │')
      ..writeln('[DioNetwork] │ ── cURL ──────────────────────────────────────────────');
    buffer.write(_buildCurl(method, fullUrl, requestHeaders, requestBody));

    buffer.write('\n[DioNetwork] └$_kLogLine');
    _log(buffer.toString(), enableLog: enableLog);
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
