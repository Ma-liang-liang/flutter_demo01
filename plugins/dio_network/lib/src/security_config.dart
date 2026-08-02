/// HTTPS 安全配置（纯数据类，平台无关）
///
/// 支持三种模式：
/// - **默认模式**：系统标准证书校验（适用于大多数 HTTPS 接口）
/// - **单向认证**：信任自签名证书 / 自定义 CA 证书（客户端校验服务端）
/// - **双向认证**：客户端同时携带证书供服务端校验（mTLS）
///
/// 注意：证书配置仅在使用 IO 网络栈的平台（Android / iOS / 桌面）生效，
/// Web 端受浏览器安全模型限制会被忽略。
///
/// 使用方式：
/// ```dart
/// DioNetworkConfig(
///   baseUrl: 'https://api.example.com',
///   securityConfig: SecurityConfig.mutual(
///     clientCertPath: 'assets/client.p12',
///     clientCertPassword: 'password',
///     trustedCertPath: 'assets/server.pem',
///   ),
/// );
/// ```
class SecurityConfig {
  const SecurityConfig({
    this.trustedCertPath,
    this.trustedCertBytes,
    this.clientCertPath,
    this.clientCertPassword,
    this.clientCertBytes,
    this.allowBadCertificate = false,
  });

  /// 信任的服务端证书文件路径（PEM / DER 格式）
  ///
  /// 适用于单向认证：客户端校验自签名服务端证书。
  final String? trustedCertPath;

  /// 信任的服务端证书字节（PEM / DER 格式）
  final List<int>? trustedCertBytes;

  /// 客户端证书文件路径（PFX / P12 格式）
  ///
  /// 适用于双向认证：客户端携带证书供服务端校验。
  final String? clientCertPath;

  /// 客户端证书字节（PFX / P12 格式）
  final List<int>? clientCertBytes;

  /// 客户端证书密码
  final String? clientCertPassword;

  /// 是否允许不安全的证书（仅用于调试）
  final bool allowBadCertificate;

  /// 是否为双向认证（mTLS）
  bool get isMutual =>
      (clientCertPath != null || clientCertBytes != null) &&
      clientCertPassword != null;

  /// 是否有自定义信任证书
  bool get hasTrustedCert =>
      trustedCertPath != null || trustedCertBytes != null;

  /// 单向认证配置（信任自签名服务端证书）
  factory SecurityConfig.trusted({
    String? certPath,
    List<int>? certBytes,
  }) {
    return SecurityConfig(
      trustedCertPath: certPath,
      trustedCertBytes: certBytes,
    );
  }

  /// 双向认证配置（mTLS）— 从文件路径加载
  factory SecurityConfig.mutual({
    required String clientCertPath,
    required String clientCertPassword,
    String? trustedCertPath,
    bool allowBadCertificate = false,
  }) {
    return SecurityConfig(
      clientCertPath: clientCertPath,
      clientCertPassword: clientCertPassword,
      trustedCertPath: trustedCertPath,
      allowBadCertificate: allowBadCertificate,
    );
  }

  /// 双向认证配置（mTLS）— 从字节流加载（适用于 assets）
  factory SecurityConfig.mutualBytes({
    required List<int> clientCertBytes,
    required String clientCertPassword,
    List<int>? trustedCertBytes,
    bool allowBadCertificate = false,
  }) {
    return SecurityConfig(
      clientCertBytes: clientCertBytes,
      clientCertPassword: clientCertPassword,
      trustedCertBytes: trustedCertBytes,
      allowBadCertificate: allowBadCertificate,
    );
  }

  /// 仅用于调试：跳过所有证书校验
  factory SecurityConfig.debug() {
    return const SecurityConfig(allowBadCertificate: true);
  }
}
