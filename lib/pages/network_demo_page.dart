import 'dart:convert';

import 'package:dio/dio.dart' show Headers;
import 'package:dio_network/dio_network.dart';
import 'package:flutter/material.dart';

import '../widgets/section_card.dart';

/// 网络组件演示页面
///
/// 演示 `dio_network` package 的核心能力：
/// - 统一 baseUrl / 公参 / 公共 Header / Content-Type
/// - 指定业务码集合走异步拦截回调
/// - 泛型字典转模型
/// - 返回原始 JSON 字符串
/// - 日志统一开关 + 结构化日志（请求序号 / 时间戳 / 响应头）
/// - 敏感 Header 脱敏（可配置）
/// - 全局取消 cancelAll()
/// - HTTPS 单向 / 双向认证
/// - 文件上传 / 下载
class NetworkDemoPage extends StatefulWidget {
  const NetworkDemoPage({super.key});

  @override
  State<NetworkDemoPage> createState() => _NetworkDemoPageState();
}

class _NetworkDemoPageState extends State<NetworkDemoPage> {
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _initNetwork();
  }

  /// 初始化 DioNetwork
  void _initNetwork() {
    DioNetwork.instance.init(
      DioNetworkConfig(
        // 使用 httpbin.org 作为测试 API（HTTPS）
        baseUrl: 'https://httpbin.org',
        // 公共参数
        commonParams: {
          'appVersion': '1.0.0',
          'platform': 'flutter',
        },
        // 公共 Header
        commonHeaders: {
          'Accept': 'application/json',
        },
        // 默认 Content-Type: application/json
        contentType: Headers.jsonContentType,
        // 开启日志
        enableLog: true,
        // 敏感 Header 脱敏（默认不脱敏，按需配置）
        sensitiveHeaders: {'authorization', 'cookie'},
        // 业务成功码
        successCode: 0,
        // 指定需要业务拦截的业务码集合
        // 只有这些码才走 businessInterceptor 回调
        interceptCodes: {1001, 1002, 9000},
        // 业务拦截回调（异步，同一业务码的并发请求只触发一次）
        // 返回 true → 框架自动重试原请求一次（如 token 刷新成功后）
        // 返回 false → 不重试，继续抛 ApiError.business
        businessInterceptor: ({
          required int code,
          required String message,
          required dynamic data,
          required String path,
        }) async {
          _addLog('🔔 业务拦截回调触发:');
          _addLog('   path=$path');
          _addLog('   code=$code, msg=$message');
          if (code == 1001) {
            _addLog('   → 模拟: token 过期，跳转登录页（不重试）');
          } else if (code == 9000) {
            _addLog('   → 模拟: 系统维护，弹窗提示（不重试）');
          }
          return false;
        },
        // HTTP 401/403 未授权统一回调（并发去重，返回 true 自动重试原请求）
        onUnauthorized: () async {
          _addLog('🔔 HTTP 401/403 未授权回调触发');
          _addLog('   → 模拟: 跳转登录页（不重试）');
          return false;
        },
        // HTTPS 配置（演示用调试模式，实际开发请配置真实证书）
        // securityConfig: SecurityConfig.debug(),
      ),
    );
    _addLog('✅ DioNetwork 已初始化');
    _addLog('   baseUrl: ${DioNetwork.instance.config.baseUrl}');
    _addLog('   公参: ${DioNetwork.instance.config.commonParams}');
    _addLog('   公共Header: ${DioNetwork.instance.config.commonHeaders}');
    _addLog('   contentType: ${DioNetwork.instance.config.contentType}');
    _addLog('   拦截业务码: ${DioNetwork.instance.config.interceptCodes}');
    _addLog('   脱敏Header: ${DioNetwork.instance.config.sensitiveHeaders}');
  }

  void _addLog(String msg) {
    final now = DateTime.now().toIso8601String().substring(11, 19);
    setState(() => _logs.insert(0, '[$now] $msg'));
  }

  void _clearLogs() {
    setState(() => _logs.clear());
  }

  // ────────────────────────────────────────────────────────────────────────
  // 演示 1: GET 请求 + 返回原始 JSON 字符串
  // ────────────────────────────────────────────────────────────────────────
  Future<void> _demoGetRawJson() async {
    _addLog('━━━ 演示1: GET 请求 → 原始 JSON 字符串 ━━━');
    try {
      final jsonStr = await DioNetwork.instance.requestRaw(
        '/get',
        method: HttpMethod.get,
        queryParameters: {'userId': 12345},
      );
      _addLog('✅ 返回 JSON 字符串（长度 ${jsonStr.length}）');

      final decoded = jsonDecode(jsonStr);
      if (decoded is Map) {
        // ignore: avoid_dynamic_calls
        final args = decoded['args'];
        _addLog('   服务端收到的 query 参数: $args');
      }
    } on ApiError catch (e) {
      _addLog('❌ ${e.type}: ${e.message}');
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // 演示 2: POST 请求 + 独立 Header + async/await
  // ────────────────────────────────────────────────────────────────────────
  Future<void> _demoPostWithHeader() async {
    _addLog('━━━ 演示2: POST + 独立 Header (async/await) ━━━');
    try {
      final jsonStr = await DioNetwork.instance.requestRaw(
        '/post',
        method: HttpMethod.post,
        body: {'title': 'Hello', 'content': 'DioNetwork 测试'},
        headers: {'X-Custom-Token': 'abc123xyz'},
      );
      _addLog('✅ POST 成功，返回长度 ${jsonStr.length}');

      final decoded = jsonDecode(jsonStr);
      if (decoded is Map) {
        // ignore: avoid_dynamic_calls
        final headers = decoded['headers'];
        _addLog('   服务端收到的 Header: $headers');
      }
    } on ApiError catch (e) {
      _addLog('❌ ${e.type}: ${e.message}');
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // 演示 3: 泛型字典转模型
  // ────────────────────────────────────────────────────────────────────────
  Future<void> _demoGenericModel() async {
    _addLog('━━━ 演示3: 泛型字典转模型 ━━━');
    try {
      final jsonStr = await DioNetwork.instance.requestRaw(
        '/get',
        method: HttpMethod.get,
        queryParameters: {'name': '张三', 'age': 28},
      );

      final decoded = jsonDecode(jsonStr);
      if (decoded is Map) {
        // ignore: avoid_dynamic_calls
        final args = decoded['args'] as Map;
        final user = _DemoUser(
          name: args['name']?.toString() ?? '',
          age: int.tryParse(args['age']?.toString() ?? '') ?? 0,
        );
        _addLog('✅ 字典转模型成功: $user');
      }
    } on ApiError catch (e) {
      _addLog('❌ ${e.type}: ${e.message}');
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // 演示 4: 指定业务码拦截
  // ────────────────────────────────────────────────────────────────────────
  Future<void> _demoBusinessIntercept() async {
    _addLog('━━━ 演示4: 指定业务码拦截 ━━━');
    _addLog('   interceptCodes = {1001, 1002, 9000}');

    // 模拟 code=1001（token 过期）— 在 interceptCodes 中，触发回调
    _addLog('');
    _addLog('场景A: code=1001（在 interceptCodes 中）');
    final jsonA = jsonEncode({'code': 1001, 'message': 'Token 已过期', 'data': null});
    final respA = ApiResponse.fromJson(jsonA);
    if (respA.code != DioNetwork.instance.config.successCode) {
      if (DioNetwork.instance.config.interceptCodes.contains(respA.code)) {
        final shouldRetry =
            await DioNetwork.instance.config.businessInterceptor?.call(
              code: respA.code,
              message: respA.message,
              data: respA.data,
              path: '/simulated/login-check',
            ) ??
            false;
        _addLog(
          shouldRetry
              ? '   → 回调要求重试：框架自动重发原请求一次'
              : '   → 回调执行完毕（不重试），抛出 ApiError.business',
        );
      } else {
        _addLog('   → 不在拦截码中，直接抛错');
      }
    }

    // 模拟 code=5001（不在 interceptCodes 中）— 不触发回调，直接抛错
    _addLog('');
    _addLog('场景B: code=5001（不在 interceptCodes 中）');
    final jsonB = jsonEncode({'code': 5001, 'message': '参数错误', 'data': null});
    final respB = ApiResponse.fromJson(jsonB);
    if (respB.code != DioNetwork.instance.config.successCode) {
      if (DioNetwork.instance.config.interceptCodes.contains(respB.code)) {
        _addLog('   → 在拦截码中（不该出现）');
      } else {
        _addLog('   → 不在 interceptCodes 中，直接抛 ApiError.business');
        _addLog('   → 调用方 catch 自行处理');
      }
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // 演示 5: 统一错误类型展示
  // ────────────────────────────────────────────────────────────────────────
  Future<void> _demoErrorTypes() async {
    _addLog('━━━ 演示5: 统一错误类型 ━━━');

    final errors = [
      ApiError(type: ApiErrorType.connectTimeout, message: '连接超时'),
      ApiError(type: ApiErrorType.network, message: '网络连接失败'),
      ApiError(type: ApiErrorType.badCertificate, message: '证书校验失败'),
      ApiError.business(code: 1002, message: '权限不足'),
      ApiError(type: ApiErrorType.serverError, message: '服务器异常', httpStatus: 500),
      ApiError.parse('JSON 解析失败'),
      ApiError.cancel(),
    ];

    for (final e in errors) {
      _addLog('   ${e.type}: ${e.message}');
    }
    _addLog('✅ 所有错误均为统一 ApiError 类型，通过 type 区分');
  }

  // ────────────────────────────────────────────────────────────────────────
  // 演示 6: 全局取消 cancelAll()
  // ────────────────────────────────────────────────────────────────────────
  Future<void> _demoCancelAll() async {
    _addLog('━━━ 演示6: 全局取消 cancelAll() ━━━');
    _addLog('   发起一个慢请求（/delay/3），然后立即 cancelAll...');

    // 发起一个 3 秒延迟的请求（不指定独立 cancelToken，走全局令牌）
    final future = DioNetwork.instance.requestRaw('/delay/3').then(
      (_) => _addLog('✅ 请求完成（不应出现）'),
    ).catchError((Object e) {
      if (e is ApiError && e.type == ApiErrorType.cancel) {
        _addLog('✅ 请求已被 cancelAll() 取消: ${e.message}');
      } else {
        _addLog('❌ 其他错误: $e');
      }
    });

    // 等待一小段时间后取消
    await Future.delayed(const Duration(milliseconds: 300));
    DioNetwork.instance.cancelAll('用户退出登录');
    _addLog('   → 已调用 cancelAll(reason: "用户退出登录")');

    await future;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('网络组件演示'),
        actions: [
          IconButton(
            onPressed: _clearLogs,
            icon: const Icon(Icons.delete_outline),
            tooltip: '清空日志',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: 'dio_network 核心能力',
            subtitle: '统一配置 / 公参 / 业务拦截 / 泛型转模型 / HTTPS / 日志',
            icon: Icons.cloud,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FeatureChip('统一 baseUrl 配置'),
                _FeatureChip('全局公共参数 (commonParams)'),
                _FeatureChip('全局公共 Header (commonHeaders)'),
                _FeatureChip('默认 Content-Type 可配置'),
                _FeatureChip('单 URL 独立参数/Header'),
                _FeatureChip('指定业务码集合 → 异步拦截回调'),
                _FeatureChip('拦截回调并发去重（防并发刷新 token）'),
                _FeatureChip('拦截后可自动重试原请求（仅一次）'),
                _FeatureChip('HTTP 401/403 统一未授权回调'),
                _FeatureChip('统一错误类型 ApiError (DioExceptionType)'),
                _FeatureChip('泛型字典转模型'),
                _FeatureChip('返回原始 JSON 字符串'),
                _FeatureChip('全方法 async/await 支持'),
                _FeatureChip('全局取消 cancelAll()'),
                _FeatureChip('单请求超时覆盖 (connect/send/receive)'),
                _FeatureChip('结构化日志 (序号/时间戳/响应头/体大小)'),
                _FeatureChip('敏感 Header 脱敏（可配置）'),
                _FeatureChip('HTTPS 单向认证 (自定义 CA)'),
                _FeatureChip('HTTPS 双向认证 (mTLS)'),
                _FeatureChip('Release 模式强制忽略 allowBadCertificate'),
                _FeatureChip('文件上传 (multipart/form-data)'),
                _FeatureChip('文件下载 (状态码校验 + 原子落盘)'),
                _FeatureChip('大响应体后台 Isolate 解析（阈值可配）'),
              ],
            ),
          ),

          SectionCard(
            title: '功能演示',
            subtitle: '点击按钮查看效果',
            icon: Icons.play_circle,
            child: Column(
              children: [
                _DemoButton(
                  label: 'GET 请求 → 原始 JSON',
                  hint: '演示 requestRaw + 单 URL 参数',
                  onPressed: _demoGetRawJson,
                  color: theme.colorScheme.primaryContainer,
                ),
                _DemoButton(
                  label: 'POST + 独立 Header',
                  hint: '演示 async/await + POST body + 单 URL Header',
                  onPressed: _demoPostWithHeader,
                  color: theme.colorScheme.secondaryContainer,
                ),
                _DemoButton(
                  label: '泛型字典转模型',
                  hint: '演示 JSON → Model 转换',
                  onPressed: _demoGenericModel,
                  color: theme.colorScheme.tertiaryContainer,
                ),
                _DemoButton(
                  label: '指定业务码拦截',
                  hint: '演示 interceptCodes 集合 + 异步回调',
                  onPressed: _demoBusinessIntercept,
                  color: theme.colorScheme.errorContainer,
                ),
                _DemoButton(
                  label: '统一错误类型',
                  hint: '展示 ApiError 各类型',
                  onPressed: _demoErrorTypes,
                  color: theme.colorScheme.surfaceContainerHighest,
                ),
                _DemoButton(
                  label: '全局取消 cancelAll()',
                  hint: '演示一键取消所有进行中请求',
                  onPressed: _demoCancelAll,
                  color: theme.colorScheme.primaryContainer,
                ),
              ],
            ),
          ),

          SectionCard(
            title: '运行日志',
            subtitle: '日志开关: ${DioNetwork.instance.config.enableLog ? "已开启" : "已关闭"}',
            icon: Icons.terminal,
            child: Container(
              constraints: const BoxConstraints(minHeight: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: _logs.isEmpty
                  ? const Center(
                      child: Text(
                        '点击上方按钮开始演示',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            _logs[index],
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),

          SectionCard(
            title: '使用说明',
            subtitle: 'package 源码: plugins/dio_network',
            icon: Icons.code,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('初始化（在 main() 中调用一次）:', style: theme.textTheme.titleSmall),
                _CodeBlock('''DioNetwork.instance.init(
  DioNetworkConfig(
    baseUrl: 'https://api.example.com',
    commonParams: {'appVersion': '1.0.0'},
    commonHeaders: {'Authorization': 'Bearer xxx'},
    contentType: Headers.jsonContentType,
    enableLog: true,
    // 敏感 Header 脱敏（默认不脱敏，按需配置）
    sensitiveHeaders: {'authorization', 'cookie'},
    successCode: 0,
    // 指定哪些业务码走拦截回调
    interceptCodes: {1001, 1002, 9000},
    // 异步业务拦截回调：返回 true 自动重试原请求一次
    businessInterceptor: ({code, message, data, path}) async {
      if (code == 1001) {
        final refreshed = await refreshToken();
        return refreshed;
      }
      return false;
    },
    // HTTP 401/403 未授权统一回调（并发去重）
    onUnauthorized: () async {
      await goToLogin();
      return false;
    },
    // 大响应体 Isolate 解析阈值（默认 256KB）
    backgroundDecodeThreshold: 256 * 1024,
  ),
);'''),
                const SizedBox(height: 12),
                Text('泛型请求 → 模型:', style: theme.textTheme.titleSmall),
                _CodeBlock('''final res = await DioNetwork.instance.get<User>(
  '/user/info',
  converter: (json) => User.fromJson(json),
  receiveTimeout: Duration(seconds: 5), // 单请求超时覆盖
);
// res.data 类型为 User'''),
                const SizedBox(height: 12),
                Text('返回原始 JSON 字符串:', style: theme.textTheme.titleSmall),
                _CodeBlock('''final jsonStr = await DioNetwork.instance.requestRaw(
  '/user/list',
  method: HttpMethod.post,
  body: {'page': 1},
  headers: {'X-Token': 'xxx'},
  sendTimeout: Duration(seconds: 10),
);'''),
                const SizedBox(height: 12),
                Text('全局取消（退出登录时）:', style: theme.textTheme.titleSmall),
                _CodeBlock('''// 一键取消所有未指定独立 CancelToken 的请求
DioNetwork.instance.cancelAll('用户退出登录');
// 调用后自动重建全局令牌，后续新请求不受影响'''),
                const SizedBox(height: 12),
                Text('文件上传:', style: theme.textTheme.titleSmall),
                _CodeBlock(r'''await DioNetwork.instance.upload(
  '/avatar/upload',
  filePath: '/path/to/image.jpg',
  fieldName: 'avatar',
  onSendProgress: (sent, total) {
    print('上传进度: ${(sent/total*100).toStringAsFixed(1)}%');
  },
);'''),
                const SizedBox(height: 12),
                Text('文件下载:', style: theme.textTheme.titleSmall),
                _CodeBlock(r'''await DioNetwork.instance.download(
  '/files/report.pdf',
  savePath: '/path/to/report.pdf',
  onReceiveProgress: (received, total) {
    print('下载进度: ${(received/total*100).toStringAsFixed(1)}%');
  },
);'''),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// 辅助组件
// ────────────────────────────────────────────────────────────────────────────

class _FeatureChip extends StatelessWidget {
  const _FeatureChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(label, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _DemoButton extends StatelessWidget {
  const _DemoButton({
    required this.label,
    required this.hint,
    required this.onPressed,
    required this.color,
  });

  final String label;
  final String hint;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.titleSmall),
                Text(
                  hint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.tonal(
            onPressed: onPressed,
            style: FilledButton.styleFrom(backgroundColor: color),
            child: const Text('执行'),
          ),
        ],
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock(this.code);
  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        code,
        style: const TextStyle(
          color: Colors.greenAccent,
          fontSize: 12,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

/// 演示用模型
class _DemoUser {
  const _DemoUser({required this.name, required this.age});
  final String name;
  final int age;

  @override
  String toString() => '_DemoUser(name: $name, age: $age)';
}
