import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';

import 'models.dart';

/// 会话本地持久化（JSON 文件，无容量上限烦恼）
class ChatStore {
  static List<ChatSession> sessions = <ChatSession>[];
  static String? currentId;
  static File? _file;
  static const int _maxSessions = 200;

  static Future<void> init() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _file = File('${dir.path}/huangyou_kesong_sessions.json');
      if (await _file!.exists()) {
        final raw = await _file!.readAsString();
        final j = jsonDecode(raw) as Map<String, dynamic>;
        sessions = ((j['sessions'] ?? const []) as List)
            .map((e) => ChatSession.fromJson(e as Map<String, dynamic>))
            .toList();
        currentId = j['current']?.toString();
      }
    } catch (_) {
      sessions = <ChatSession>[];
      currentId = null;
    }
    _sort();
  }

  static void _sort() {
    sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  static Future<void> _flush() async {
    if (_file == null) return;
    try {
      if (sessions.length > _maxSessions) {
        _sort();
        sessions = sessions.sublist(0, _maxSessions);
      }
      final data = {
        'current': currentId,
        'sessions': sessions.map((e) => e.toJson()).toList(),
      };
      await _file!.writeAsString(jsonEncode(data));
    } catch (_) {}
  }

  static String _newId() {
    final r = Random();
    return '${DateTime.now().millisecondsSinceEpoch}-${r.nextInt(99999)}';
  }

  static ChatSession create() {
    final s = ChatSession(id: _newId());
    sessions.insert(0, s);
    currentId = s.id;
    _flush();
    return s;
  }

  /// 确保有一个当前会话
  static ChatSession ensureCurrent() {
    if (currentId != null) {
      for (final s in sessions) {
        if (s.id == currentId) return s;
      }
    }
    return create();
  }

  static Future<void> save(ChatSession s) async {
    s.updatedAt = DateTime.now();
    final idx = sessions.indexWhere((e) => e.id == s.id);
    if (idx < 0) {
      sessions.insert(0, s);
    }
    currentId = s.id;
    _sort();
    await _flush();
  }

  static Future<void> remove(String id) async {
    sessions.removeWhere((e) => e.id == id);
    if (currentId == id) currentId = null;
    await _flush();
  }

  static Future<void> clearAll() async {
    sessions = <ChatSession>[];
    currentId = null;
    await _flush();
  }

  /// 历史列表（按更新时间倒序，跳过完全空的会话）
  static List<ChatSession> history() {
    _sort();
    return sessions
        .where((s) => s.messages.any((m) => m.content.trim().isNotEmpty))
        .toList();
  }
}
