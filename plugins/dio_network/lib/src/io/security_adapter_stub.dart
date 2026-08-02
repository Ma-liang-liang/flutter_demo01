import 'package:dio/dio.dart';

import '../security_config.dart';

/// 配置 HTTPS 安全证书（Web 平台 stub）
///
/// Web 端受浏览器安全模型限制，不支持自定义证书校验，配置被忽略。
void configureSecurityAdapter(
  Dio dio,
  SecurityConfig config,
  void Function(String message) log,
) {
  log('⚠️ 当前平台不支持自定义 HTTPS 证书配置，securityConfig 已忽略');
}
