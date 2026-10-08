import 'dart:convert';

/// 引用来源
class Citation {
  final String dataset;
  final String document;
  Citation(this.dataset, this.document);

  Map<String, dynamic> toJson() => {'d': dataset, 'f': document};
  factory Citation.fromJson(Map<String, dynamic> j) =>
      Citation((j['d'] ?? '').toString(), (j['f'] ?? '').toString());
}

/// 一条消息
class ChatMessage {
  String role; // 'user' | 'assistant'
  String content;
  List<Citation> citations;
  bool pending;
  DateTime createdAt;

  ChatMessage({
    required this.role,
    this.content = '',
    List<Citation>? citations,
    this.pending = false,
    DateTime? createdAt,
  })  : citations = citations ?? <Citation>[],
        createdAt = createdAt ?? DateTime.now();

  bool get isUser => role == 'user';

  Map<String, dynamic> toJson() => {
        'r': role,
        'c': content,
        't': createdAt.millisecondsSinceEpoch,
        if (citations.isNotEmpty) 'q': citations.map((e) => e.toJson()).toList(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        role: (j['r'] ?? 'assistant').toString(),
        content: (j['c'] ?? '').toString(),
        citations: ((j['q'] ?? const []) as List)
            .map((e) => Citation.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (j['t'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch),
      );
}

/// 一个会话
class ChatSession {
  String id;
  String conversationId; // Dify 侧的会话 id，用于多轮
  List<ChatMessage> messages;
  DateTime createdAt;
  DateTime updatedAt;

  ChatSession({
    required this.id,
    this.conversationId = '',
    List<ChatMessage>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : messages = messages ?? <ChatMessage>[],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// 标题取第一条用户提问
  String get title {
    for (final m in messages) {
      if (m.isUser && m.content.trim().isNotEmpty) {
        final t = m.content.trim().replaceAll('\n', ' ');
        return t.length > 22 ? '${t.substring(0, 22)}…' : t;
      }
    }
    return '新对话';
  }

  /// 预览：最后一条有内容的消息
  String get preview {
    for (final m in messages.reversed) {
      if (m.content.trim().isNotEmpty) {
        final t = m.content.trim().replaceAll('\n', ' ');
        return t.length > 42 ? '${t.substring(0, 42)}…' : t;
      }
    }
    return '（暂无内容）';
  }

  int get userCount => messages.where((m) => m.isUser).length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'cid': conversationId,
        'ct': createdAt.millisecondsSinceEpoch,
        'ut': updatedAt.millisecondsSinceEpoch,
        'm': messages.map((e) => e.toJson()).toList(),
      };

  factory ChatSession.fromJson(Map<String, dynamic> j) => ChatSession(
        id: (j['id'] ?? '').toString(),
        conversationId: (j['cid'] ?? '').toString(),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (j['ct'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
            (j['ut'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch),
        messages: ((j['m'] ?? const []) as List)
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  String encode() => jsonEncode(toJson());
}
