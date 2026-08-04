import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio_network/dio_network.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mock HttpClientAdapter：按 handler 返回预设响应，并记录所有请求
class MockHttpAdapter implements HttpClientAdapter {
  Future<ResponseBody> Function(RequestOptions options)? handler;

  final List<RequestOptions> requests = [];

  /// 与 [requests] 一一对应的请求体字节（无 body 时为 null）
  final List<Uint8List?> requestBodies = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (requestStream != null) {
      final builder = BytesBuilder(copy: true);
      await for (final chunk in requestStream) {
        builder.add(chunk);
      }
      requestBodies.add(builder.takeBytes());
    } else {
      requestBodies.add(null);
    }
    return handler!(options);
  }

  @override
  void close({bool force = false}) {}
}

/// 构造标准业务 JSON 响应体
ResponseBody jsonResponse(Map<String, dynamic> json, {int statusCode = 200}) {
  return ResponseBody.fromString(
    jsonEncode(json),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

void main() {
  late MockHttpAdapter adapter;

  DioNetworkConfig makeConfig({
    Map<String, dynamic> commonParams = const {},
    Map<String, dynamic> commonHeaders = const {},
    Set<int> interceptCodes = const {},
    BusinessInterceptorCallback? businessInterceptor,
    UnauthorizedCallback? onUnauthorized,
  }) {
    return DioNetworkConfig(
      baseUrl: 'https://api.test.com',
      commonParams: commonParams,
      commonHeaders: commonHeaders,
      interceptCodes: interceptCodes,
      businessInterceptor: businessInterceptor,
      onUnauthorized: onUnauthorized,
      httpClientAdapter: adapter,
    );
  }

  void initDefault() {
    // 不覆盖测试已设置的 handler
    adapter.handler ??= (options) async =>
        jsonResponse({'code': 0, 'message': 'ok', 'data': null});
    DioNetwork.instance.init(makeConfig());
  }

  setUp(() {
    adapter = MockHttpAdapter();
  });

  tearDown(() {
    DioNetwork.instance.close();
  });

  group('初始化', () {
    test('未初始化时请求抛出 ApiError', () async {
      DioNetwork.instance.close(); // 确保未初始化状态
      await expectLater(
        DioNetwork.instance.get('/a'),
        throwsA(
          isA<ApiError>().having((e) => e.type, 'type', ApiErrorType.unknown),
        ),
      );
    });

    test('未初始化时 updateCommonHeaders 抛出 ApiError 而非崩溃', () {
      DioNetwork.instance.close();
      expect(
        () => DioNetwork.instance.updateCommonHeaders({'k': 'v'}),
        throwsA(isA<ApiError>()),
      );
    });

    test('close 幂等，重复调用安全', () {
      DioNetwork.instance.close();
      expect(() => DioNetwork.instance.close(), returnsNormally);
    });

    test('重复 init 热更新配置生效，请求走新 adapter', () async {
      final oldAdapter = MockHttpAdapter();
      oldAdapter.handler =
          (options) async => jsonResponse({'code': 0, 'message': 'ok'});
      DioNetwork.instance.init(makeConfig());
      // 第一次 init 用的是字段中的 adapter，这里替换为显式 oldAdapter 验证
      DioNetwork.instance.close();
      DioNetwork.instance.init(
        DioNetworkConfig(
          baseUrl: 'https://old.test.com',
          httpClientAdapter: oldAdapter,
        ),
      );

      final newAdapter = MockHttpAdapter();
      newAdapter.handler =
          (options) async => jsonResponse({'code': 0, 'message': 'ok'});
      DioNetwork.instance.init(
        DioNetworkConfig(
          baseUrl: 'https://new.test.com',
          httpClientAdapter: newAdapter,
        ),
      );

      await DioNetwork.instance.get('/a');
      expect(newAdapter.requests.length, 1);
      expect(oldAdapter.requests.length, 0);
      expect(newAdapter.requests.first.baseUrl, 'https://new.test.com');
    });
  });

  group('参数与 Header 合并', () {
    test('公参合并到 query，独立参数同 key 覆盖公参', () async {
      adapter.handler = (options) async =>
          jsonResponse({'code': 0, 'message': 'ok'});
      DioNetwork.instance.init(makeConfig(
        commonParams: {'app': 'demo', 'v': '1'},
      ));

      await DioNetwork.instance.get('/a', queryParameters: {'v': '2', 'x': 1});

      expect(adapter.requests.single.queryParameters, {
        'app': 'demo',
        'v': '2', // 独立参数覆盖公参
        'x': 1,
      });
    });

    test('公参不会污染 POST body', () async {
      adapter.handler = (options) async =>
          jsonResponse({'code': 0, 'message': 'ok'});
      DioNetwork.instance.init(makeConfig(commonParams: {'app': 'demo'}));

      await DioNetwork.instance.post('/a', body: {'title': 't'});

      final sent = adapter.requests.single;
      expect(sent.queryParameters, {'app': 'demo'});
      expect(sent.data, {'title': 't'}); // body 中不含公参
    });

    test('公共 Header 自动携带，单请求 Header 同 key 覆盖', () async {
      adapter.handler = (options) async =>
          jsonResponse({'code': 0, 'message': 'ok'});
      DioNetwork.instance.init(makeConfig(
        commonHeaders: {'Accept': 'application/json', 'X-Env': 'prod'},
      ));

      await DioNetwork.instance.get('/a', headers: {'X-Env': 'debug'});

      final headers = adapter.requests.single.headers;
      expect(headers['Accept'], 'application/json');
      expect(headers['X-Env'], 'debug');
    });

    test('POST 请求自动携带全局 contentType', () async {
      adapter.handler = (options) async =>
          jsonResponse({'code': 0, 'message': 'ok'});
      initDefault();

      await DioNetwork.instance.post('/a', body: {'k': 'v'});

      final contentType =
          adapter.requests.single.headers[Headers.contentTypeHeader];
      expect(contentType, contains('application/json'));
    });

    test('updateCommonHeaders / updateCommonParams 动态生效', () async {
      adapter.handler = (options) async =>
          jsonResponse({'code': 0, 'message': 'ok'});
      initDefault();

      DioNetwork.instance.updateCommonHeaders({'Authorization': 'Bearer tk'});
      DioNetwork.instance.updateCommonParams({'token': 'tk'});
      await DioNetwork.instance.get('/a');

      final sent = adapter.requests.single;
      expect(sent.headers['Authorization'], 'Bearer tk');
      expect(sent.queryParameters['token'], 'tk');
    });
  });

  group('响应解析与泛型转换', () {
    test('成功响应 + converter 字典转模型', () async {
      adapter.handler = (options) async => jsonResponse({
            'code': 0,
            'message': 'ok',
            'data': {'name': 'hello', 'age': 3},
          });
      initDefault();

      final res = await DioNetwork.instance.get<String>(
        '/a',
        converter: (json) => json['name'] as String,
      );

      expect(res.code, 0);
      expect(res.data, 'hello');
      expect(res.rawJson, isNotEmpty);
    });

    test('getList 逐元素转换为模型列表', () async {
      adapter.handler = (options) async => jsonResponse({
            'code': 0,
            'message': 'ok',
            'data': [
              {'name': 'a'},
              {'name': 'b'},
            ],
          });
      initDefault();

      final res = await DioNetwork.instance.getList<String>(
        '/a',
        converter: (json) => json['name'] as String,
      );

      expect(res.data, ['a', 'b']);
    });

    test('getList 在 data 非 List 时抛 ApiError.parse', () async {
      adapter.handler = (options) async =>
          jsonResponse({'code': 0, 'message': 'ok', 'data': {'name': 'x'}});
      initDefault();

      await expectLater(
        DioNetwork.instance.getList<String>(
          '/a',
          converter: (json) => json['name'] as String,
        ),
        throwsA(
          isA<ApiError>().having((e) => e.type, 'type', ApiErrorType.parse),
        ),
      );
    });

    test('converter 解析失败抛 ApiError.parse', () async {
      adapter.handler = (options) async => jsonResponse({
            'code': 0,
            'message': 'ok',
            'data': 'not-a-map', // 非 Map，无法转模型
          });
      initDefault();

      await expectLater(
        DioNetwork.instance.get<String>(
          '/a',
          converter: (json) => json['name'] as String,
        ),
        throwsA(
          isA<ApiError>().having((e) => e.type, 'type', ApiErrorType.parse),
        ),
      );
    });

    test('requestRaw 返回原始字符串且不做业务码判断', () async {
      adapter.handler = (options) async =>
          jsonResponse({'code': 9999, 'message': 'whatever'});
      initDefault();

      final raw = await DioNetwork.instance.requestRaw('/a');

      expect(jsonDecode(raw), {'code': 9999, 'message': 'whatever'});
    });

    test('无 converter 且 T 与 data 不匹配 → 抛 ApiError.parse 而非 TypeError', () async {
      adapter.handler = (options) async => jsonResponse({
            'code': 0,
            'message': 'ok',
            'data': {'name': 'hello'},
          });
      initDefault();

      await expectLater(
        DioNetwork.instance.request<_FakeUser>('/a'),
        throwsA(
          isA<ApiError>()
              .having((e) => e.type, 'type', ApiErrorType.parse)
              .having((e) => e.message, 'message', contains('converter')),
        ),
      );
    });

    test('无 converter 且 T 与 data 兼容 → 原样返回', () async {
      adapter.handler = (options) async => jsonResponse({
            'code': 0,
            'message': 'ok',
            'data': {'name': 'hello'},
          });
      initDefault();

      final res = await DioNetwork.instance.request<Map<String, dynamic>>('/a');
      expect(res.data, {'name': 'hello'});
    });

    test('无 converter 且 data 为 null → 任何 T 都安全返回 null', () async {
      adapter.handler = (options) async =>
          jsonResponse({'code': 0, 'message': 'ok', 'data': null});
      initDefault();

      final res = await DioNetwork.instance.request<_FakeUser>('/a');
      expect(res.data, isNull);
    });

    test('无 converter 时基本类型合理强转（String→int、无损 double→int）', () async {
      adapter.handler = (options) async =>
          jsonResponse({'code': 0, 'message': 'ok', 'data': '123'});
      initDefault();
      var res = await DioNetwork.instance.request<int>('/a');
      expect(res.data, 123);

      adapter.handler = (options) async =>
          jsonResponse({'code': 0, 'message': 'ok', 'data': 3.0});
      res = await DioNetwork.instance.request<int>('/a');
      expect(res.data, 3);
    });
  });

  group('业务码处理', () {
    test('非成功码且不在拦截集合 → 直接抛 ApiError.business', () async {
      adapter.handler = (options) async =>
          jsonResponse({'code': 5001, 'message': '参数错误', 'data': null});
      initDefault();

      await expectLater(
        DioNetwork.instance.get('/a'),
        throwsA(isA<ApiError>()
            .having((e) => e.type, 'type', ApiErrorType.business)
            .having((e) => e.code, 'code', 5001)),
      );
    });

    test('拦截码触发回调，返回 false 时抛 business 错误', () async {
      var callbackCount = 0;
      adapter.handler = (options) async =>
          jsonResponse({'code': 1001, 'message': 'token 过期', 'data': null});
      DioNetwork.instance.init(makeConfig(
        interceptCodes: {1001},
        businessInterceptor: ({
          required code,
          required message,
          required data,
          required path,
        }) async {
          callbackCount++;
          return false;
        },
      ));

      await expectLater(
        DioNetwork.instance.get('/a'),
        throwsA(
          isA<ApiError>().having((e) => e.type, 'type', ApiErrorType.business),
        ),
      );
      expect(callbackCount, 1);
    });

    test('拦截回调返回 true 时自动重试原请求一次', () async {
      var requestCount = 0;
      adapter.handler = (options) async {
        requestCount++;
        if (requestCount == 1) {
          return jsonResponse({'code': 1001, 'message': 'token 过期'});
        }
        return jsonResponse({
          'code': 0,
          'message': 'ok',
          'data': {'name': 'retried'},
        });
      };
      DioNetwork.instance.init(makeConfig(
        interceptCodes: {1001},
        businessInterceptor: ({
          required code,
          required message,
          required data,
          required path,
        }) async =>
            true,
      ));

      final res = await DioNetwork.instance.get<String>(
        '/a',
        converter: (json) => json['name'] as String,
      );

      expect(res.data, 'retried');
      expect(requestCount, 2);
    });

    test('回调始终返回 true 时最多重试一次，防止无限循环', () async {
      var requestCount = 0;
      adapter.handler = (options) async {
        requestCount++;
        return jsonResponse({'code': 1001, 'message': 'token 过期'});
      };
      DioNetwork.instance.init(makeConfig(
        interceptCodes: {1001},
        businessInterceptor: ({
          required code,
          required message,
          required data,
          required path,
        }) async =>
            true,
      ));

      await expectLater(
        DioNetwork.instance.get('/a'),
        throwsA(
          isA<ApiError>().having((e) => e.type, 'type', ApiErrorType.business),
        ),
      );
      expect(requestCount, 2); // 首次 + 一次重试
    });

    test('并发请求触发同一业务码拦截时回调只执行一次（去重）', () async {
      var callbackCount = 0;
      adapter.handler = (options) async =>
          jsonResponse({'code': 1001, 'message': 'token 过期', 'data': null});
      DioNetwork.instance.init(makeConfig(
        interceptCodes: {1001},
        businessInterceptor: ({
          required code,
          required message,
          required data,
          required path,
        }) async {
          callbackCount++;
          // 模拟刷新 token 耗时，制造并发窗口
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return false;
        },
      ));

      final results = await Future.wait([
        for (var i = 0; i < 3; i++)
          DioNetwork.instance
              .get('/a')
              .then<String>((_) => 'ok')
              .onError((_, _) => 'err'),
      ]);

      expect(results, everyElement('err'));
      expect(callbackCount, 1); // 3 个并发请求只触发 1 次回调
    });

    test('拦截回调自身抛异常时仍抛出原始 business 错误', () async {
      adapter.handler = (options) async =>
          jsonResponse({'code': 1001, 'message': 'token 过期', 'data': null});
      DioNetwork.instance.init(makeConfig(
        interceptCodes: {1001},
        businessInterceptor: ({
          required code,
          required message,
          required data,
          required path,
        }) async {
          throw StateError('刷新 token 失败');
        },
      ));

      await expectLater(
        DioNetwork.instance.get('/a'),
        throwsA(isA<ApiError>()
            .having((e) => e.type, 'type', ApiErrorType.business)
            .having((e) => e.code, 'code', 1001)),
      );
    });
  });

  group('HTTP 状态码处理', () {
    test('HTTP 404 + 非 JSON 响应 → ApiError.notFound', () async {
      adapter.handler = (options) async =>
          ResponseBody.fromString('<html>Not Found</html>', 404);
      initDefault();

      await expectLater(
        DioNetwork.instance.get('/a'),
        throwsA(isA<ApiError>()
            .having((e) => e.type, 'type', ApiErrorType.notFound)
            .having((e) => e.httpStatus, 'httpStatus', 404)),
      );
    });

    test('HTTP 500 + 非 JSON 响应 → ApiError.serverError', () async {
      adapter.handler = (options) async =>
          ResponseBody.fromString('Internal Error', 500);
      initDefault();

      await expectLater(
        DioNetwork.instance.get('/a'),
        throwsA(
          isA<ApiError>().having((e) => e.type, 'type', ApiErrorType.serverError),
        ),
      );
    });

    test('HTTP 401 无回调配置 → 抛 unauthorized', () async {
      adapter.handler = (options) async =>
          ResponseBody.fromString('Unauthorized', 401);
      initDefault();

      await expectLater(
        DioNetwork.instance.get('/a'),
        throwsA(
          isA<ApiError>()
              .having((e) => e.type, 'type', ApiErrorType.unauthorized),
        ),
      );
    });

    test('HTTP 401 触发 onUnauthorized，返回 true 时重试成功', () async {
      var requestCount = 0;
      var callbackCount = 0;
      adapter.handler = (options) async {
        requestCount++;
        if (requestCount == 1) {
          return ResponseBody.fromString('Unauthorized', 401);
        }
        return jsonResponse({'code': 0, 'message': 'ok', 'data': 'done'});
      };
      DioNetwork.instance.init(makeConfig(
        onUnauthorized: () async {
          callbackCount++;
          return true;
        },
      ));

      final res = await DioNetwork.instance.get('/a');

      expect(res.data, 'done');
      expect(requestCount, 2);
      expect(callbackCount, 1);
    });

    test('onUnauthorized 返回 false 时抛 unauthorized', () async {
      adapter.handler = (options) async =>
          ResponseBody.fromString('Forbidden', 403);
      DioNetwork.instance.init(makeConfig(
        onUnauthorized: () async => false,
      ));

      await expectLater(
        DioNetwork.instance.get('/a'),
        throwsA(
          isA<ApiError>()
              .having((e) => e.type, 'type', ApiErrorType.unauthorized),
        ),
      );
    });

    test('HTTP 401 但响应是标准业务 JSON 时走业务码流程', () async {
      adapter.handler = (options) async =>
          jsonResponse({'code': 0, 'message': 'ok', 'data': 1}, statusCode: 401);
      initDefault();

      // 带 code 字段的 401 不抛 HTTP 错误，由业务码判定（code=0 → 成功）
      final res = await DioNetwork.instance.get('/a');
      expect(res.data, 1);
    });
  });

  group('异常映射', () {
    test('连接超时映射为 ApiError.connectTimeout 并保留原始异常', () async {
      adapter.handler = (options) async => throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionTimeout,
            message: 'timeout',
          );
      initDefault();

      await expectLater(
        DioNetwork.instance.get('/a'),
        throwsA(isA<ApiError>()
            .having((e) => e.type, 'type', ApiErrorType.connectTimeout)
            .having((e) => e.originalError, 'originalError', isNotNull)),
      );
    });

    test('请求取消映射为 ApiError.cancel', () async {
      adapter.handler = (options) async => throw DioException(
            requestOptions: options,
            type: DioExceptionType.cancel,
          );
      initDefault();

      await expectLater(
        DioNetwork.instance.get('/a'),
        throwsA(
          isA<ApiError>().having((e) => e.type, 'type', ApiErrorType.cancel),
        ),
      );
    });

    test('网络连接失败映射为 ApiError.network', () async {
      adapter.handler = (options) async => throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
            message: 'SocketException',
          );
      initDefault();

      await expectLater(
        DioNetwork.instance.get('/a'),
        throwsA(
          isA<ApiError>().having((e) => e.type, 'type', ApiErrorType.network),
        ),
      );
    });
  });

  group('文件上传 / 下载', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('dio_network_test');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('上传成功并转换响应模型', () async {
      adapter.handler = (options) async => jsonResponse({
            'code': 0,
            'message': 'ok',
            'data': {'url': 'https://cdn.test.com/f.txt'},
          });
      initDefault();

      final file = File('${tempDir.path}/up.txt');
      await file.writeAsString('upload-content');

      final res = await DioNetwork.instance.upload<String>(
        '/upload',
        filePath: file.path,
        converter: (json) => json['url'] as String,
      );

      expect(res.data, 'https://cdn.test.com/f.txt');
    });

    test('下载成功：2xx 写入目标路径且临时文件已清理', () async {
      adapter.handler =
          (options) async => ResponseBody.fromString('hello-file', 200);
      initDefault();

      final savePath = '${tempDir.path}/a.txt';
      await DioNetwork.instance.download('/file', savePath: savePath);

      expect(await File(savePath).readAsString(), 'hello-file');
      expect(await File('$savePath.downloading').exists(), isFalse);
    });

    test('下载 404：抛 notFound 且目标路径无文件残留', () async {
      adapter.handler =
          (options) async => ResponseBody.fromString('Not Found', 404);
      initDefault();

      final savePath = '${tempDir.path}/b.txt';
      await expectLater(
        DioNetwork.instance.download('/file', savePath: savePath),
        throwsA(
          isA<ApiError>().having((e) => e.type, 'type', ApiErrorType.notFound),
        ),
      );

      expect(await File(savePath).exists(), isFalse);
      expect(await File('$savePath.downloading').exists(), isFalse);
    });

    test('下载携带公参与独立 query 参数', () async {
      adapter.handler =
          (options) async => ResponseBody.fromString('data', 200);
      DioNetwork.instance.init(makeConfig(commonParams: {'app': 'demo'}));

      final savePath = '${tempDir.path}/c.txt';
      await DioNetwork.instance.download(
        '/file',
        savePath: savePath,
        queryParameters: {'id': 7},
      );

      expect(adapter.requests.single.queryParameters, {'app': 'demo', 'id': 7});
    });

    test('upload 内存字节文件上传', () async {
      adapter.handler = (options) async =>
          jsonResponse({'code': 0, 'message': 'ok', 'data': null});
      initDefault();

      await DioNetwork.instance.upload(
        '/upload',
        fileBytes: Uint8List.fromList(utf8.encode('img-bytes')),
        fileName: 'shot.png',
      );

      final bodyStr = latin1.decode(adapter.requestBodies.single!);
      expect(bodyStr, contains('img-bytes'));
      expect(bodyStr, contains('filename="shot.png"'));
    });

    test('fileBytes 上传未指定 fileName 抛 ArgumentError', () {
      initDefault();
      expect(
        () => DioNetwork.instance.upload(
          '/upload',
          fileBytes: Uint8List.fromList([1, 2, 3]),
        ),
        throwsArgumentError,
      );
    });

    test('filePath 与 fileBytes 同时传入抛 ArgumentError', () {
      initDefault();
      expect(
        () => DioNetwork.instance.upload(
          '/upload',
          filePath: '/tmp/a.txt',
          fileBytes: Uint8List.fromList([1]),
        ),
        throwsArgumentError,
      );
    });

    test('uploadFiles 多文件上传（本地文件 + 内存字节，不同字段名）', () async {
      adapter.handler = (options) async =>
          jsonResponse({'code': 0, 'message': 'ok', 'data': null});
      initDefault();

      final f1 = File('${tempDir.path}/a.txt')..writeAsStringSync('file1-content');
      await DioNetwork.instance.uploadFiles(
        '/upload',
        files: [
          UploadFile.fromPath(path: f1.path, fieldName: 'avatar'),
          UploadFile.fromBytes(
            bytes: Uint8List.fromList(utf8.encode('mem-bytes')),
            fileName: 'b.bin',
            fieldName: 'attach',
          ),
        ],
        formData: {'biz': 'demo'},
      );

      final bodyStr = latin1.decode(adapter.requestBodies.single!);
      expect(bodyStr, contains('name="avatar"'));
      expect(bodyStr, contains('name="attach"'));
      expect(bodyStr, contains('name="biz"'));
      expect(bodyStr, contains('file1-content'));
      expect(bodyStr, contains('mem-bytes'));
      expect(bodyStr, contains('filename="b.bin"'));
    });

    test('下载断点续传：携带 Range 头且文件正确拼接', () async {
      final full = utf8.encode('hello world download resume test');
      final part2 = full.sublist(10);
      final savePath = '${tempDir.path}/resume.bin';
      await File('$savePath.downloading').writeAsBytes(full.sublist(0, 10));

      adapter.handler = (options) async {
        expect(options.headers['range'], 'bytes=10-');
        return ResponseBody(
          Stream.value(Uint8List.fromList(part2)),
          206,
          headers: {
            'content-range': ['bytes 10-${full.length - 1}/${full.length}'],
          },
        );
      };
      initDefault();

      await DioNetwork.instance.download('/file', savePath: savePath);

      expect(await File(savePath).readAsBytes(), full);
      expect(await File('$savePath.downloading').exists(), isFalse);
    });

    test('下载续传开启但服务端忽略 Range（200）→ 从头重下', () async {
      final savePath = '${tempDir.path}/full.bin';
      // 预置残留的部分进度
      await File('$savePath.downloading').writeAsBytes([9, 9, 9]);

      adapter.handler = (options) async {
        expect(options.headers['range'], 'bytes=3-');
        return ResponseBody.fromString('full-content', 200);
      };
      initDefault();

      await DioNetwork.instance.download('/file', savePath: savePath);

      expect(await File(savePath).readAsString(), 'full-content');
    });

    test('下载中断保留进度，再次调用从断点继续', () async {
      final full = utf8.encode('0123456789ABCDEF');
      final part1 = full.sublist(0, 6);
      final part2 = full.sublist(6);
      final savePath = '${tempDir.path}/broken.bin';

      var call = 0;
      adapter.handler = (options) async {
        call++;
        if (call == 1) {
          // 第一次：发送前半后断开（模拟网络中断）
          Stream<Uint8List> brokenStream() async* {
            yield Uint8List.fromList(part1);
            throw Exception('connection reset');
          }

          return ResponseBody(
            brokenStream(),
            200,
            headers: {
              'content-length': ['${full.length}'],
            },
          );
        }
        // 第二次：验证从断点 6 继续
        expect(options.headers['range'], 'bytes=6-');
        return ResponseBody(
          Stream.value(Uint8List.fromList(part2)),
          206,
          headers: {
            'content-range': ['bytes 6-${full.length - 1}/${full.length}'],
          },
        );
      };
      initDefault();

      await expectLater(
        DioNetwork.instance.download('/file', savePath: savePath),
        throwsA(isA<ApiError>()),
      );
      // 中断后临时文件保留已下载部分
      expect(await File('$savePath.downloading').readAsBytes(), part1);

      await DioNetwork.instance.download('/file', savePath: savePath);
      expect(await File(savePath).readAsBytes(), full);
      expect(call, 2);
    });

    test('下载 416 断点失效 → 清理临时文件从头重下', () async {
      final savePath = '${tempDir.path}/stale.bin';
      await File('$savePath.downloading').writeAsBytes([1, 2, 3, 4]);

      var call = 0;
      adapter.handler = (options) async {
        call++;
        if (call == 1) {
          expect(options.headers['range'], 'bytes=4-');
          return ResponseBody.fromString('', 416);
        }
        expect(options.headers.containsKey('range'), isFalse);
        return ResponseBody.fromString('fresh-content', 200);
      };
      initDefault();

      await DioNetwork.instance.download('/file', savePath: savePath);

      expect(await File(savePath).readAsString(), 'fresh-content');
      expect(call, 2);
    });
  });

  group('ApiResponse / ApiError 基础能力', () {
    test('ApiResponse.fromJson 兼容 msg 字段与字符串 code', () {
      final res = ApiResponse.fromJson('{"code": "0", "msg": "ok", "data": 1}');
      expect(res.code, 0);
      expect(res.message, 'ok');
      expect(res.data, 1);
    });

    test('ApiError.fromHttpStatus 映射', () {
      expect(ApiError.fromHttpStatus(401).type, ApiErrorType.unauthorized);
      expect(ApiError.fromHttpStatus(403).type, ApiErrorType.unauthorized);
      expect(ApiError.fromHttpStatus(404).type, ApiErrorType.notFound);
      expect(ApiError.fromHttpStatus(500).type, ApiErrorType.serverError);
      expect(ApiError.fromHttpStatus(418).type, ApiErrorType.badResponse);
    });
  });

  group('单请求日志开关 enableLog', () {
    test('全局关闭时，单请求传 enableLog: true 能打印日志', () async {
      final logs = <String>[];
      adapter.handler = (options) async =>
          jsonResponse({'code': 0, 'message': 'ok', 'data': null});
      DioNetwork.instance.init(DioNetworkConfig(
        baseUrl: 'https://api.test.com',
        enableLog: false,
        logCallback: logs.add,
        httpClientAdapter: adapter,
      ));

      await DioNetwork.instance.get('/a', enableLog: true);

      expect(logs.any((l) => l.contains('─── #')), isTrue);
      expect(logs.any((l) => l.contains('─ Request ─')), isTrue);
      expect(logs.any((l) => l.contains('─ Response ─')), isTrue);
    });

    test('全局关闭时，不传 enableLog 则不打印', () async {
      final logs = <String>[];
      adapter.handler = (options) async =>
          jsonResponse({'code': 0, 'message': 'ok', 'data': null});
      DioNetwork.instance.init(DioNetworkConfig(
        baseUrl: 'https://api.test.com',
        enableLog: false,
        logCallback: logs.add,
        httpClientAdapter: adapter,
      ));

      await DioNetwork.instance.get('/a');

      expect(logs, isEmpty);
    });

    test('全局开启时，单请求传 enableLog: false 能抑制请求日志', () async {
      final logs = <String>[];
      adapter.handler = (options) async =>
          jsonResponse({'code': 0, 'message': 'ok', 'data': null});
      DioNetwork.instance.init(DioNetworkConfig(
        baseUrl: 'https://api.test.com',
        enableLog: true,
        logCallback: logs.add,
        httpClientAdapter: adapter,
      ));
      logs.clear(); // 清除 init 日志，只关注请求日志

      await DioNetwork.instance.get('/a', enableLog: false);

      expect(logs, isEmpty);
    });

    test('全局开启时，不传 enableLog 沿用全局开启', () async {
      final logs = <String>[];
      adapter.handler = (options) async =>
          jsonResponse({'code': 0, 'message': 'ok', 'data': null});
      DioNetwork.instance.init(DioNetworkConfig(
        baseUrl: 'https://api.test.com',
        enableLog: true,
        logCallback: logs.add,
        httpClientAdapter: adapter,
      ));

      await DioNetwork.instance.get('/a');

      expect(logs.any((l) => l.contains('─── #')), isTrue);
    });
  });
}

/// 测试用模型（验证无 converter 时 T 为具体模型的行为）
class _FakeUser {}
