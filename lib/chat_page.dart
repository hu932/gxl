import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';

import 'api.dart';
import 'theme.dart';

class ChatMessage {
  final String role; // 'user' | 'assistant'
  String content; // 流式追加，必须可变
  List<Citation> citations; // 结束时回填引用，必须可变
  bool pending; // 是否还在生成
  ChatMessage(String this.role, this.content,
      {this.citations = const [], this.pending = false});
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  String _conversationId = '';
  bool _busy = false;
  StreamSubscription<DifyChunk>? _sub;
  File? _pendingImage;
  final ImagePicker _picker = ImagePicker();

  static const _quickQs = [
    '花生十三：415假设分配法怎么用？',
    '花生十三：归因论证怎么质疑？',
    '郭熙：逻辑填空的搭配怎么学？',
    '比重差公式怎么用？',
  ];

  @override
  void dispose() {
    _sub?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      imageQuality: 88,
    );
    if (file != null) {
      setState(() => _pendingImage = File(file.path));
    }
  }

  Future<void> _pickGallery() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 88,
    );
    if (file != null) {
      setState(() => _pendingImage = File(file.path));
    }
  }

  Future<void> _send(String text) async {
    final query = text.trim();
    if (query.isEmpty && _pendingImage == null) return;
    if (_busy) return;

    _input.clear();
    setState(() {
      _messages.add(ChatMessage('user', query));
      _messages.add(ChatMessage('assistant', '', pending: true));
      _busy = true;
    });
    _scrollToBottom();

    try {
      final files = <Map<String, String>>[];
      if (_pendingImage != null) {
        try {
          final id = await DifyApi.uploadImage(_pendingImage!);
          files.add({
            'type': 'image',
            'transfer_method': 'local_file',
            'upload_file_id': id,
          });
        } catch (e) {
          setState(() {
            final last = _messages.lastWhere((m) => m.role == 'assistant');
            last.content = '⚠️ 图片上传失败\n\n$e';
            last.pending = false;
            _busy = false;
          });
          return;
        }
      }
      final q = query.isEmpty ? '请看看这道题怎么做？' : query;

      _sub = DifyApi.chat(
        query: q,
        conversationId: _conversationId,
        files: files,
      ).listen(
        (chunk) {
          setState(() {
            final last = _messages.lastWhere((m) => m.role == 'assistant');
            if (chunk.answerDelta.isNotEmpty) {
              last.content += chunk.answerDelta;
            }
            if (chunk.conversationId != null &&
                chunk.conversationId!.isNotEmpty) {
              _conversationId = chunk.conversationId!;
            }
            if (chunk.isEnd) {
              last.pending = false;
              last.citations = chunk.citations;
              _busy = false;
            }
          });
          _scrollToBottom();
        },
        onError: (e) {
          setState(() {
            final last = _messages.lastWhere((m) => m.role == 'assistant');
            last.content = '⚠️ 请求失败：$e\n\n请检查网络或稍后重试。';
            last.pending = false;
            _busy = false;
          });
        },
        onDone: () {
          setState(() {
            final last = _messages.lastWhere((m) => m.role == 'assistant');
            last.pending = false;
            _busy = false;
          });
        },
      );
    } catch (e) {
      setState(() {
        final last = _messages.lastWhere((m) => m.role == 'assistant');
        last.content = '⚠️ 请求失败：$e';
        last.pending = false;
        _busy = false;
      });
    } finally {
      _pendingImage = null;
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty ? _buildWelcome() : _buildList(),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Row(
        children: [
          Text('🥐', style: TextStyle(fontSize: 22)),
          SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('黄油可颂',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              Text('花生十三 × 郭熙 · 行测智能体',
                  style: TextStyle(fontSize: 11, color: Colors.white70)),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: '新对话',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _busy
              ? null
              : () {
                  _sub?.cancel();
                  setState(() {
                    _messages.clear();
                    _conversationId = '';
                    _busy = false;
                  });
                },
        ),
      ],
    );
  }

  Widget _buildWelcome() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 40),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Image.asset('assets/icon.png',
                width: 92, height: 92, fit: BoxFit.cover),
          ),
          const SizedBox(height: 22),
          const Text(
            '你好，我是黄油可颂 🥐',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: ButterColors.brown),
          ),
          const SizedBox(height: 8),
          const Text(
            '两位行测名师课程蒸馏成的知识库，随时问我任何考点、方法、口诀。\n也可以拍照上传题目。',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14, height: 1.6, color: ButterColors.brownLight),
          ),
          const SizedBox(height: 30),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('试试这样问',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ButterColors.brownLight)),
          ),
          const SizedBox(height: 12),
          ..._quickQs.map((q) => _chip(q)),
        ],
      ),
    );
  }

  Widget _chip(String q) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _busy ? null : () => _send(q),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Text(
              q,
              style: const TextStyle(fontSize: 14, color: ButterColors.brown),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      itemCount: _messages.length,
      itemBuilder: (context, i) => _bubble(_messages[i]),
    );
  }

  Widget _bubble(ChatMessage m) {
    final isUser = m.role == 'user';
    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isUser ? ButterColors.bubbleUser : ButterColors.bubbleBot,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(isUser ? 20 : 6),
          bottomRight: Radius.circular(isUser ? 6 : 20),
        ),
        border: isUser
            ? null
            : Border.all(color: ButterColors.bubbleBotBorder, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isUser)
            Text(m.content,
                style:
                    const TextStyle(fontSize: 15.5, color: Colors.white, height: 1.5))
          else
            MarkdownBody(
              data: m.content.isEmpty ? (_busy ? '' : '（空回复）') : m.content,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(
                    fontSize: 15.5,
                    color: ButterColors.bubbleBotText,
                    height: 1.55),
                h1: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: ButterColors.brown),
                h2: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: ButterColors.brown),
                h3: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ButterColors.brown),
                strong: const TextStyle(
                    fontWeight: FontWeight.w700, color: ButterColors.caramel),
                code: TextStyle(
                    backgroundColor: ButterColors.creamDeep,
                    color: ButterColors.caramel,
                    fontFamily: 'monospace'),
                blockquoteDecoration: BoxDecoration(
                  color: ButterColors.creamDeep,
                  borderRadius: BorderRadius.circular(8),
                ),
                tableBorder: TableBorder.all(
                    color: ButterColors.bubbleBotBorder, width: 0.5),
              ),
            ),
          if (m.pending) const _TypingIndicator(),
          if (m.citations.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(height: 1, color: ButterColors.bubbleBotBorder),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: m.citations
                  .take(3)
                  .map((c) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: ButterColors.creamDeep,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '📖 ${c.document.split('.').first}',
                          style: const TextStyle(
                              fontSize: 10.5, color: ButterColors.brownLight),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            const CircleAvatar(
              radius: 16,
              backgroundColor: ButterColors.butter,
              child: Text('🥐', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(child: bubble),
          if (isUser) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 16,
              backgroundColor: ButterColors.caramel,
              child: Text('我', style: TextStyle(fontSize: 12, color: Colors.white)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, -2)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_pendingImage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(_pendingImage!,
                              width: 64, height: 64, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: -6,
                          right: -6,
                          child: GestureDetector(
                            onTap: () => setState(() => _pendingImage = null),
                            child: const CircleAvatar(
                              radius: 10,
                              backgroundColor: Colors.black54,
                              child: Icon(Icons.close,
                                  size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: '拍照提问',
                  icon: const Icon(Icons.camera_alt_outlined,
                      color: ButterColors.caramel),
                  onPressed: _busy ? null : _pickImage,
                ),
                IconButton(
                  tooltip: '选择图片',
                  icon: const Icon(Icons.image_outlined,
                      color: ButterColors.caramel),
                  onPressed: _busy ? null : _pickGallery,
                ),
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(_input.text),
                    decoration: const InputDecoration(
                      hintText: '输入问题…',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _busy ? null : () => _send(_input.text),
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: _busy ? ButterColors.butterDark : ButterColors.butter,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _busy ? Icons.hourglass_top : Icons.arrow_upward_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final t = (_controller.value * 3 + i) % 3;
              final o = t < 1 ? 0.25 + 0.75 * t : 0.25 + 0.75 * (2 - t);
              return Opacity(
                opacity: o.clamp(0.25, 1.0).toDouble(),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: ButterColors.butter,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
