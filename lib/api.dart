import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// Dify 服务配置（行测知识库）
/// 走服务器 nginx 的 80 端口反向代理（/dify/ -> 127.0.0.1:8080），
/// 因为 8080 端口会被部分运营商/防火墙拦截（表现为 No route to host）。
class DifyConfig {
  static const baseUrl = 'http://38.175.194.43/dify';
  static const apiKey = 'app-ZuI2yGKf1UxE6Rj9nJf0quRQ';
  static const user = 'ios-user-001';
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

/// 引用来源
class Citation {
  final String dataset;
  final String document;
  Citation(this.dataset, this.document);
}

class DifyApi {
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
        // jpg / jpeg / heic / heif 一律按 jpeg 处理
        return MediaType('image', 'jpeg');
    }
  }

  /// 视觉模型只认 webp / png / jpeg / gif，其它一律按 jpeg 命名上传
  static String _uploadName(String path) {
    final ext = path.split('.').last.toLowerCase();
    if (ext == 'png' || ext == 'webp' || ext == 'gif') return 'question.$ext';
    return 'question.jpg';
  }

  /// 上传图片，返回 file_id；失败时抛出带可读原因的异常
  static Future<String> uploadImage(File file) async {
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
          // 有些错误信息里还嵌着一层 JSON
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

  /// 流式对话（SSE）
  static Stream<DifyChunk> chat({
    required String query,
    String conversationId = '',
    List<Map<String, String>> files = const [],
  }) async* {
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
