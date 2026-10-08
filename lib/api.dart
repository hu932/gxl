import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

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
  /// 上传图片，返回 file_id
  static Future<String?> uploadImage(File file) async {
    try {
      final req = http.MultipartRequest(
        'POST',
        Uri.parse('${DifyConfig.baseUrl}/v1/files/upload'),
      );
      req.headers['Authorization'] = 'Bearer ${DifyConfig.apiKey}';
      req.files.add(await http.MultipartFile.fromPath(
        'file',
        file.path,
        filename: 'question.jpg',
      ));
      req.fields['user'] = DifyConfig.user;
      req.fields['type'] = 'image';
      final resp = await req.send();
      final body = await resp.stream.bytesToString();
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final map = jsonDecode(body) as Map<String, dynamic>;
        return map['id'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

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
        throw Exception('HTTP ${resp.statusCode}: $b');
      }
      final lines = resp.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      await for (final line in lines) {
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
          throw Exception((j['message'] ?? '服务出错').toString());
        }
      }
    } finally {
      client.close();
    }
  }
}
