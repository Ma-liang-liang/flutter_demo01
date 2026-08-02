/// dio_network - 基于 Dio 的业务层网络封装
///
/// 统一配置 baseUrl / 公参 / 公共 Header，
/// 支持业务码拦截、泛型字典转模型、日志开关、HTTPS 双向认证、文件上传/下载。
library;

// 核心管理类
export 'src/dio_network.dart';

// 配置（含 BusinessInterceptorCallback、LogCallback typedef）
export 'src/dio_network_config.dart';

// HTTPS 安全配置
export 'src/security_config.dart';

// 基础类型
export 'src/http_method.dart';
export 'src/api_response.dart';
export 'src/api_error.dart';
