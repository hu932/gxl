import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';

import 'models.dart';

/// Dify 服务配置（行测知识库）
///
/// 多端点自动切换（4 条线路，任一可用即可）：
///   0) http://38.175.194.43:8080   直连 Dify
///   1) http://38.175.194.43/dify   80 端口 nginx 反代
///   2) http://38.175.194.43:2038   备用线路
///   3) http://38.175.194.43:31058  备用线路
///
/// 部分网络会间歇性阻断某些端口（表现为 `No route to host, errno=65`），
/// 此时自动换下一条。**可用的线路会被记住**，下次启动直接从它开始。
class DifyConfig {
  static const endpoints = <String>[
    'http://38.175.194.43:8080',
    'http://38.175.194.43/dify',
    'http://38.175.194.43:2038',
    'http://38.175.194.43:31058',
  ];

  static const labels = <String>[
    '8080 直连',
    '80 反代',
    '2038 备用',
    '31058 备用',
  ];

  static const apiKey = 'app-ZuI2yGKf1UxE6Rj9nJf0quRQ';
  static const user = 'ios-user-001';

  static int _idx = 0;
  static File? _store;

  static String get baseUrl => endpoints[_idx];
  static String get activeLabel => labels[_idx];

  // ---------- 端点记忆 ----------
  static Future<void> _load() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _store = File('${dir.path}/huangyou_endpoint.txt');
      if (await _store!.exists()) {
        final i = int.tryParse((await _store!.readAsString()).trim());
        if (i != null && i >= 0 && i < endpoints.length) _idx = i;
      }
    } catch (_) {}
  }

  static Future<void> _save() async {
    try {
      await _store?.writeAsString('$_idx');
    } catch (_) {}
  }

  // ---------- 探测 ----------
  static Future<bool> _alive(String base) async {
    try {
      final r = await http
          .get(Uri.parse('$base/console/api/setup'))
          .timeout(const Duration(seconds: 3));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// 启动时调用：**并行**探测所有端点，优先沿用上次成功的那个
  static Future<void> resolve() async {
    await _load();
    final futures = <Future<bool>>[];
    for (final e in endpoints) {
      futures.add(_alive(e));
    }
    final res = await Future.wait(futures);
    final alive = <int>[];
    for (var i = 0; i < res.length; i++) {
      if (res[i]) alive.add(i);
    }
    if (alive.isEmpty) return; // 全不通就保持现状，发消息时再逐个重试
    if (alive.contains(_idx)) return; // 记住的那个还能用
    _idx = alive.first;
    await _save();
  }

  /// 换到下一个端点（并记住）
  static Future<void> nextEndpoint() async {
    _idx = (_idx + 1) % endpoints.length;
    await _save();
  }
}

/// 一段流式数据
class DifyChunk {
  final String answerDelta;
  final String? conversationId;
  final bool isEnd;
  final List<Citation> citations;
  DifyChunk({
    this.answerDelta = '',
    this.conversationId,
    this.isEnd = false,
    this.citations = const [],
  });
}

/// 引用来源 Citation 统一由 models.dart 提供（避免同名类重复定义造成 import 歧义）

class DifyApi {
  /// 判断是否为「连不上」类错误（这类才值得换端点重试）
  static bool isConnError(Object e) {
    if (e is SocketException || e is TimeoutException) return true;
    final s = e.toString().toLowerCase();
    return s.contains('socketexception') ||
        s.contains('clientexception') ||
        s.contains('no route to host') ||
        s.contains('connection refused') ||
        s.contains('connection failed') ||
        s.contains('connection reset') ||
        s.contains('timed out') ||
        s.contains('timeout') ||
        s.contains('network is unreachable');
  }

  /// 全部端点都失败时给出的提示
  static String allFailedMessage(Object e) =>
      '⚠️ 请求失败\n\n所有线路都连不上（${DifyConfig.labels.join(' / ')}）。\n'
      '请检查手机网络，或稍后重试。\n\n技术信息：$e';

  /// 根据扩展名推断 MIME。**必须显式指定**：http 的 MultipartFile 默认发
  /// application/octet-stream，Dify 的视觉模型会因识别不出格式而报
  /// "unsupported image"。
  static MediaType _mimeOf(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'png':
        return MediaType('image', 'png');
      case 'webp':
        return MediaType('image', 'webp');
      case 'gif':
        return MediaType('image', 'gif');
      default:
        return MediaType('image', 'jpeg');
    }
  }

  /// 视觉模型只认 webp / png / jpeg / gif，其它一律按 jpeg 命名上传
  static String _uploadName(String path) {
    final ext = path.split('.').last.toLowerCase();
    if (ext == 'png' || ext == 'webp' || ext == 'gif') return 'question.$ext';
    return 'question.jpg';
  }

  /// 上传图片：逐个端点尝试，返回 file_id
  static Future<String> uploadImage(File file) async {
    Object? lastErr;
    for (var a = 0; a < DifyConfig.endpoints.length; a++) {
      try {
        return await _uploadOnce(file);
      } catch (e) {
        lastErr = e;
        if (!isConnError(e)) rethrow;
        await DifyConfig.nextEndpoint();
      }
    }
    throw Exception(allFailedMessage(lastErr ?? '未知错误'));
  }

  static Future<String> _uploadOnce(File file) async {
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('${DifyConfig.baseUrl}/v1/files/upload'),
    );
    req.headers['Authorization'] = 'Bearer ${DifyConfig.apiKey}';
    req.files.add(await http.MultipartFile.fromPath(
      'file',
      file.path,
      filename: _uploadName(file.path),
      contentType: _mimeOf(file.path),
    ));
    req.fields['user'] = DifyConfig.user;
    req.fields['type'] = 'image';

    final resp = await req.send();
    final body = await resp.stream.bytesToString();
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      final map = jsonDecode(body) as Map<String, dynamic>;
      final id = map['id'] as String?;
      if (id != null && id.isNotEmpty) return id;
      throw Exception('上传成功但未返回文件 ID');
    }
    throw Exception('图片上传失败(${resp.statusCode})：${_friendly(body)}');
  }

  /// 把 Dify 返回的一大串 JSON 错误压缩成人话
  static String _friendly(String raw) {
    try {
      final j = jsonDecode(raw);
      if (j is Map) {
        final msg = j['message'] ?? j['error'] ?? j['description'];
        if (msg is String) {
          final m = RegExp(r'\{"error".*?\}\}').firstMatch(msg);
          if (m != null) {
            try {
              final k = jsonDecode(m.group(0)!);
              final m2 = (k['error'] as Map?)?['message'];
              if (m2 is String) return _clip(m2);
            } catch (_) {}
          }
          return _clip(msg);
        }
      }
    } catch (_) {}
    return _clip(raw);
  }

  static String _clip(String s) =>
      s.length > 240 ? '${s.substring(0, 240)}…' : s;

  /// 流式对话（SSE）：**依次尝试所有端点**，任一成功即返回
  static Stream<DifyChunk> chat({
    required String query,
    String conversationId = '',
    List<Map<String, String>> files = const [],
  }) async* {
    Object? lastErr;
    for (var a = 0; a < DifyConfig.endpoints.length; a++) {
      var got = false;
      try {
        await for (final c in _chatOnce(query, conversationId, files)) {
          got = true;
          yield c;
        }
        return; // 成功
      } catch (e) {
        lastErr = e;
        // 已开始输出内容就不重试（避免重复），非连接错误也不重试
        if (got || !isConnError(e)) rethrow;
        await DifyConfig.nextEndpoint();
      }
    }
    throw Exception(allFailedMessage(lastErr ?? '未知错误'));
  }

  static Stream<DifyChunk> _chatOnce(
    String query,
    String conversationId,
    List<Map<String, String>> files,
  ) async* {
    final client = http.Client();
    final req = http.Request(
      'POST',
      Uri.parse('${DifyConfig.baseUrl}/v1/chat-messages'),
    );
    req.headers['Authorization'] = 'Bearer ${DifyConfig.apiKey}';
    req.headers['Content-Type'] = 'application/json';
    req.body = jsonEncode({
      'inputs': const {},
      'query': query,
      'response_mode': 'streaming',
      'user': DifyConfig.user,
      'conversation_id': conversationId,
      'files': files,
    });

    try {
      final resp = await client.send(req);
      if (resp.statusCode != 200) {
        final b = await resp.stream.bytesToString();
        throw Exception('服务返回 ${resp.statusCode}：${_friendly(b)}');
      }
      // 手动按行切分，避免依赖不同 Dart 版本的 LineSplitter 行为
      var buffer = '';
      await for (final chunk in utf8.decoder.bind(resp.stream)) {
        buffer += chunk;
        while (true) {
          final idx = buffer.indexOf('\n');
          if (idx < 0) break;
          final line = buffer.substring(0, idx).trimRight();
          buffer = buffer.substring(idx + 1);
          if (!line.startsWith('data:')) continue;
          final data = line.substring(5).trim();
          if (data.isEmpty || data == '[DONE]') continue;
          final Map<String, dynamic> j;
          try {
            j = jsonDecode(data) as Map<String, dynamic>;
          } catch (_) {
            continue;
          }
          final event = j['event'] as String?;
          final cid = j['conversation_id']?.toString();
          if (event == 'message') {
            yield DifyChunk(
              answerDelta: (j['answer'] ?? '').toString(),
              conversationId: cid,
            );
          } else if (event == 'message_end') {
            final meta = (j['metadata'] ?? const {}) as Map<String, dynamic>;
            final res = (meta['retriever_resources'] ?? const []) as List;
            final citations = res.map<Citation>((e) {
              final m = e as Map<String, dynamic>;
              return Citation(
                (m['dataset_name'] ?? '').toString(),
                (m['document_name'] ?? '').toString(),
              );
            }).toList();
            yield DifyChunk(
              conversationId: cid,
              isEnd: true,
              citations: citations,
            );
          } else if (event == 'error') {
            throw Exception(_friendly(jsonEncode(j)));
          }
        }
      }
    } finally {
      client.close();
    }
  }
}
