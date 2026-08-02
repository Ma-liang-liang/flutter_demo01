/// HTTP 请求方法枚举
///
/// 使用增强枚举，[method] 字段直接提供 Dio 所需的大写方法名，
/// 避免脆弱的 `toString().split('.')` 方式。
enum HttpMethod {
  get('GET'),
  post('POST'),
  put('PUT'),
  delete('DELETE'),
  patch('PATCH'),
  head('HEAD');

  const HttpMethod(this.method);

  /// Dio 所需的字符串方法名（大写）
  final String method;
}
