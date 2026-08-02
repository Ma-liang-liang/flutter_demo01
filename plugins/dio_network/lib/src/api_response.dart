import 'dart:convert';

/// 统一响应包装
///
/// 标准服务端 JSON 结构约定：
/// ```json
/// {
///   "code": 0,
///   "message": "success",
///   "data": { ... }
/// }
/// ```
///
/// 使用泛型 [T] 时，[data] 已通过 converter 转为目标模型。
/// 不需要泛型时可用 `ApiResponse` （T 为 dynamic）。
class ApiResponse<T> {
  ApiResponse({
    required this.code,
    required this.message,
    this.data,
    this.rawJson,
  });

  /// 业务码
  final int code;

  /// 业务消息
  final String message;

  /// data 字段（Map / List / 基本类型 / 泛型模型 T）
  final T? data;

  /// 原始 JSON 字符串（方便外部自行解析）
  final String? rawJson;

  /// 从 Map 构造（泛型版本）
  ///
  /// [data] 保持原始 dynamic 类型，由 [DioNetwork.request] 中的
  /// converter 负责泛型转换，避免此处不安全转型。
  factory ApiResponse.fromMap(Map<String, dynamic> map, {String? rawJson}) {
    return ApiResponse<T>(
      code: _parseInt(map['code']),
      message: map['message'] as String? ?? map['msg'] as String? ?? '',
      data: _safeCast<T>(map['data']),
      rawJson: rawJson,
    );
  }

  /// 从 JSON 字符串构造
  factory ApiResponse.fromJson(String jsonStr) {
    final map = _parseJson(jsonStr);
    return ApiResponse<T>.fromMap(map ?? {}, rawJson: jsonStr);
  }

  /// 是否业务成功（由外部 config 的 successCode 判断）
  bool isSuccess(int successCode) => code == successCode;

  /// 将当前 ApiResponse 的 code/message/rawJson 保留，
  /// 替换 data 为已转换的泛型模型。
  ApiResponse<R> withData<R>(R? newData) {
    return ApiResponse<R>(
      code: code,
      message: message,
      data: newData,
      rawJson: rawJson,
    );
  }

  @override
  String toString() =>
      'ApiResponse<$T>(code: $code, message: $message, data: $data)';
}

/// 兼容 int / String / double 的 code 字段
int _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value) ?? -1;
  if (value is double) return value.toInt();
  return -1;
}

/// 安全转型：类型不匹配时返回 null 而非抛 TypeError
T? _safeCast<T>(dynamic value) {
  if (value == null) return null;
  if (value is T) return value;
  return null;
}

/// 从 JSON 字符串解析为 Map
///
/// 解析失败返回 null。
Map<String, dynamic>? _parseJson(String jsonStr) {
  try {
    final decoded = jsonDecode(jsonStr);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.cast<String, dynamic>();
    }
    return null;
  } catch (_) {
    return null;
  }
}
