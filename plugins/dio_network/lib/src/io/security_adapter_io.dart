import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';

import '../api_error.dart';
import '../security_config.dart';

/// 配置 HTTPS 安全证书（IO 平台实现）
///
/// 通过 [IOHttpClientAdapter.createHttpClient] 注入自定义 [HttpClient]。
///
/// 注意：必须使用 `createHttpClient`（返回新实例）而非已废弃的
/// `onHttpClientCreate`（只能修改既有实例）——`SecurityContext` 只能在
/// [HttpClient] 构造时传入，事后无法替换，否则证书配置会静默失效。
void configureSecurityAdapter(
  Dio dio,
  SecurityConfig config,
  void Function(String message) log,
) {
  // Release 模式下强制忽略 allowBadCertificate，防止中间人攻击
  if (kReleaseMode && config.allowBadCertificate) {
    log('⚠️ [Security] allowBadCertificate 在 Release 模式下已被强制忽略，防止安全漏洞');
    config = SecurityConfig(
      trustedCertPath: config.trustedCertPath,
      trustedCertBytes: config.trustedCertBytes,
      clientCertPath: config.clientCertPath,
      clientCertPassword: config.clientCertPassword,
      clientCertBytes: config.clientCertBytes,
      allowBadCertificate: false,
    );
  }

  final adapter = dio.httpClientAdapter;
  if (adapter is IOHttpClientAdapter) {
    adapter.createHttpClient = () => createSecureHttpClient(config);
  } else {
    log('⚠️ 自定义 httpClientAdapter 非 IO 实现，securityConfig 未生效');
  }
}

/// 根据 [SecurityConfig] 构建配置好证书的 [HttpClient]
///
/// 证书文件不存在 / 密码错误 / 格式无效时抛 [ApiError]。
HttpClient createSecureHttpClient(SecurityConfig config) {
  try {
    return _createHttpClientUnsafe(config);
  } catch (e) {
    throw ApiError(
      type: ApiErrorType.badCertificate,
      message: '证书配置失败: $e',
      originalError: e,
    );
  }
}

HttpClient _createHttpClientUnsafe(SecurityConfig config) {
  // 有证书配置时，构建自定义 SecurityContext
  if (config.hasTrustedCert || config.isMutual) {
    final context = SecurityContext(withTrustedRoots: true);

    // 加载信任的服务端证书（单向认证）
    if (config.trustedCertPath != null) {
      context.setTrustedCertificates(config.trustedCertPath!);
    } else if (config.trustedCertBytes != null) {
      context.setTrustedCertificatesBytes(config.trustedCertBytes!);
    }

    // 加载客户端证书（双向认证）
    if (config.clientCertPath != null && config.clientCertPassword != null) {
      context.useCertificateChain(
        config.clientCertPath!,
        password: config.clientCertPassword!,
      );
    } else if (config.clientCertBytes != null &&
        config.clientCertPassword != null) {
      context.useCertificateChainBytes(
        config.clientCertBytes!,
        password: config.clientCertPassword!,
      );
    }

    final client = HttpClient(context: context);

    // 调试模式下额外信任所有证书
    if (config.allowBadCertificate) {
      client.badCertificateCallback = (cert, host, port) => true;
    }

    return client;
  }

  // 无证书配置
  final client = HttpClient();

  // 调试模式：信任所有证书
  if (config.allowBadCertificate) {
    client.badCertificateCallback = (cert, host, port) => true;
  }

  return client;
}
