import 'package:dio/dio.dart';

import 'security_config.dart';

/// 业务拦截回调类型（异步）
///
/// 当服务端返回的业务码在 [DioNetworkConfig.interceptCodes] 集合中时触发。
///
/// - [code]    业务码
/// - [message] 业务提示消息
/// - [data]    原始 data 字段
/// - [path]    请求路径
///
/// 返回值含义：
/// - `true`  → 拦截方已完成处理（如 token 刷新成功），框架自动重试原请求（仅一次）
/// - `false` → 不重试，框架继续向上抛出 `ApiError.business`
///
/// 并发去重：同一业务码的多个并发请求只触发一次回调，共享同一处理结果，
/// 避免并发刷新 token 等问题。
typedef BusinessInterceptorCallback = Future<bool> Function({
  required int code,
  required String message,
  required dynamic data,
  required String path,
});

/// 未授权回调类型（异步）
///
/// 当 HTTP 状态码为 401 / 403（且响应不是带 `code` 字段的标准业务 JSON）时触发。
///
/// 返回值含义：
/// - `true`  → 已完成处理（如刷新 token 成功），框架自动重试原请求（仅一次）
/// - `false` → 不重试，框架继续抛出 `ApiErrorType.unauthorized` 错误
///
/// 并发去重：多个请求同时遇到 401 时只触发一次回调。
typedef UnauthorizedCallback = Future<bool> Function();

/// 日志回调类型
///
/// 当 [DioNetworkConfig.enableLog] 为 true 时，所有日志通过此回调输出。
/// 默认使用 `print`，可替换为写文件、发遥测等。
typedef LogCallback = void Function(String message);

/// 网络组件统一配置
///
/// 在 `main()` 中通过 `DioNetwork.instance.init()` 注入，全局生效。
/// 使用 [copyWith] 可便捷地派生新配置，避免手工逐字段复制。
class DioNetworkConfig {
  DioNetworkConfig({
    required this.baseUrl,
    this.connectTimeout = const Duration(seconds: 15),
    this.receiveTimeout = const Duration(seconds: 15),
    this.sendTimeout = const Duration(seconds: 15),
    this.commonParams = const {},
    this.commonHeaders = const {},
    this.enableLog = false,
    this.logCallback,
    this.successCode = 0,
    this.interceptCodes = const {},
    this.businessInterceptor,
    this.onUnauthorized,
    this.securityConfig,
    this.contentType = Headers.jsonContentType,
    this.extraInterceptors = const [],
    this.sensitiveHeaders = const {},
    this.httpClientAdapter,
    this.backgroundDecodeThreshold = 256 * 1024,
  });

  /// 基础 URL
  final String baseUrl;

  /// 连接超时
  final Duration connectTimeout;

  /// 接收超时
  final Duration receiveTimeout;

  /// 发送超时
  final Duration sendTimeout;

  /// 全局公共参数（自动合并到每次请求的 query 中）
  ///
  /// 注意：仅合并到 query，不会合并到 POST / PUT 的 body，
  /// 避免污染业务请求体。body 如需公共字段请在调用处显式传入。
  final Map<String, dynamic> commonParams;

  /// 全局公共 Header（每次请求自动合并）
  final Map<String, dynamic> commonHeaders;

  /// 是否开启日志打印（统一开关）
  final bool enableLog;

  /// 自定义日志输出回调
  ///
  /// 仅当 [enableLog] 为 true 时调用。
  /// 默认为 null，使用 `print` 输出。
  final LogCallback? logCallback;

  /// 业务成功码，用于判断 `ApiResponse.code` 是否成功
  final int successCode;

  /// 需要业务拦截的业务码集合
  ///
  /// 当 `response.code` 在此集合中时，触发 [businessInterceptor] 回调。
  /// 其他非成功码（既不等于 successCode 也不在 interceptCodes 中）直接抛
  /// `ApiError.business`，不触发回调。
  ///
  /// 例：`interceptCodes: {1001, 1002, 9000}`
  /// - 1001 → token 过期，回调中刷新 token 并返回 true 自动重试原请求
  /// - 9000 → 系统维护，回调中弹窗并返回 false
  /// - 其他非 0 码 → 直接抛错，调用方自行 catch
  final Set<int> interceptCodes;

  /// 业务拦截回调（异步）
  ///
  /// 仅当业务码在 [interceptCodes] 中时触发。
  /// 返回 true 表示已处理完毕（如 token 已刷新），框架自动重试原请求一次；
  /// 返回 false 则继续抛 `ApiError.business`。
  final BusinessInterceptorCallback? businessInterceptor;

  /// HTTP 401 / 403 未授权回调（异步）
  ///
  /// 适用于网关层鉴权失败（无业务码）的场景，如统一跳转登录、刷新 token。
  /// 返回 true 自动重试原请求一次；返回 false 则抛 `ApiErrorType.unauthorized`。
  final UnauthorizedCallback? onUnauthorized;

  /// HTTPS 安全配置（单向认证 / 双向认证，仅 Android / iOS / 桌面端生效）
  final SecurityConfig? securityConfig;

  /// 默认 Content-Type
  ///
  /// 默认 `application/json`，可改为 `application/x-www-form-urlencoded` 等。
  final String contentType;

  /// 额外拦截器（如自定义鉴权拦截器等）
  final List<Interceptor> extraInterceptors;

  /// 日志中需要脱敏的 Header 名（不区分大小写）
  ///
  /// 打印请求日志时，这些 Header 的值会被打码（如 `Bear***oken`），
  /// 防止 token 等敏感信息泄露到控制台 / 日志文件。
  ///
  /// 默认为空集（不脱敏），开发者按需配置：
  /// ```dart
  /// sensitiveHeaders: {'authorization', 'cookie'},
  /// ```
  final Set<String> sensitiveHeaders;

  /// 自定义 [HttpClientAdapter]
  ///
  /// 典型用途：单元测试注入 mock adapter、替换底层网络栈。
  /// 注意：设置后 [securityConfig] 仅在 adapter 为 IO 实现时生效。
  final HttpClientAdapter? httpClientAdapter;

  /// 响应体超过该长度时在后台 Isolate 中解析 JSON（避免阻塞 UI 线程）
  ///
  /// 默认 256KB。对于移动端，Isolate spawn 开销约 10~50ms，
  /// 过低的阈值反而影响性能，可根据业务场景调整。
  final int backgroundDecodeThreshold;

  /// 派生新配置，仅覆盖传入的字段
  ///
  /// 避免手工逐字段复制，新增字段时只需在此方法中添加一行。
  DioNetworkConfig copyWith({
    String? baseUrl,
    Duration? connectTimeout,
    Duration? receiveTimeout,
    Duration? sendTimeout,
    Map<String, dynamic>? commonParams,
    Map<String, dynamic>? commonHeaders,
    bool? enableLog,
    LogCallback? logCallback,
    int? successCode,
    Set<int>? interceptCodes,
    BusinessInterceptorCallback? businessInterceptor,
    UnauthorizedCallback? onUnauthorized,
    SecurityConfig? securityConfig,
    String? contentType,
    List<Interceptor>? extraInterceptors,
    Set<String>? sensitiveHeaders,
    HttpClientAdapter? httpClientAdapter,
    int? backgroundDecodeThreshold,
  }) {
    return DioNetworkConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      connectTimeout: connectTimeout ?? this.connectTimeout,
      receiveTimeout: receiveTimeout ?? this.receiveTimeout,
      sendTimeout: sendTimeout ?? this.sendTimeout,
      commonParams: commonParams ?? this.commonParams,
      commonHeaders: commonHeaders ?? this.commonHeaders,
      enableLog: enableLog ?? this.enableLog,
      logCallback: logCallback ?? this.logCallback,
      successCode: successCode ?? this.successCode,
      interceptCodes: interceptCodes ?? this.interceptCodes,
      businessInterceptor: businessInterceptor ?? this.businessInterceptor,
      onUnauthorized: onUnauthorized ?? this.onUnauthorized,
      securityConfig: securityConfig ?? this.securityConfig,
      contentType: contentType ?? this.contentType,
      extraInterceptors: extraInterceptors ?? this.extraInterceptors,
      sensitiveHeaders: sensitiveHeaders ?? this.sensitiveHeaders,
      httpClientAdapter: httpClientAdapter ?? this.httpClientAdapter,
      backgroundDecodeThreshold:
          backgroundDecodeThreshold ?? this.backgroundDecodeThreshold,
    );
  }
}
