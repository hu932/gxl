import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';

import 'api.dart';
import 'history_page.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late ChatSession _session;
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final ImagePicker _picker = ImagePicker();

  StreamSubscription<DifyChunk>? _sub;
  bool _busy = false;
  File? _pendingImage;

  List<ChatMessage> get _messages => _session.messages;

  static const _quickQs = [
    '花生十三：415假设分配法怎么用？',
    '花生十三：归因论证怎么质疑？',
    '郭熙：逻辑填空的搭配怎么学？',
    '比重差公式怎么用？',
  ];

  @override
  void initState() {
    super.initState();
    _session = ChatStore.ensureCurrent();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  Color get _subColor => _dark ? ButterColors.darkSub : ButterColors.brownLight;
  Color get _botBg => _dark ? ButterColors.darkCard : ButterColors.bubbleBot;
  Color get _botText => _dark ? ButterColors.darkText : ButterColors.bubbleBotText;
  Color get _botBorder => _dark ? ButterColors.darkBorder : ButterColors.bubbleBotBorder;

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(milliseconds: 1400),
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ---------- 图片 ----------
  Future<void> _pick(ImageSource src) async {
    try {
      final f = await _picker.pickImage(
        source: src,
        maxWidth: 1600,
        imageQuality: 88,
      );
      if (f != null) setState(() => _pendingImage = File(f.path));
    } catch (e) {
      _toast('打开图片失败：$e');
    }
  }

  // ---------- 会话 ----------
  void _newChat() {
    _sub?.cancel();
    setState(() {
      _session = ChatStore.create();
      _busy = false;
      _pendingImage = null;
    });
  }

  Future<void> _openHistory() async {
    final picked = await Navigator.push<ChatSession>(
      context,
      MaterialPageRoute(builder: (_) => const HistoryPage()),
    );
    if (picked != null && mounted) {
      _sub?.cancel();
      setState(() {
        _session = picked;
        _busy = false;
        _pendingImage = null;
      });
      ChatStore.save(_session);
      _scrollToBottom();
    }
  }

  // ---------- 发送 ----------
  Future<void> _send(String text) async {
    final query = text.trim();
    if (query.isEmpty && _pendingImage == null) return;
    if (_busy) return;

    _input.clear();
    setState(() {
      _messages.add(ChatMessage(role: 'user', content: query));
      _messages.add(ChatMessage(role: 'assistant', pending: true));
      _busy = true;
    });
    _scrollToBottom();

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
          _messages.last.content = '⚠️ 图片上传失败\n\n$e';
          _messages.last.pending = false;
          _busy = false;
          _pendingImage = null;
        });
        await ChatStore.save(_session);
        return;
      }
    }
    setState(() => _pendingImage = null);

    await _stream(query.isEmpty ? '请看看这道题怎么做？' : query, files);
  }

  Future<void> _stream(String query, List<Map<String, String>> files) async {
    final done = Completer<void>();
    _sub = DifyApi.chat(
      query: query,
      conversationId: _session.conversationId,
      files: files,
    ).listen(
      (chunk) {
        if (!mounted) return;
        setState(() {
          final last = _messages.last;
          if (chunk.answerDelta.isNotEmpty) last.content += chunk.answerDelta;
          if (chunk.conversationId != null &&
              chunk.conversationId!.isNotEmpty) {
            _session.conversationId = chunk.conversationId!;
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
        if (mounted) {
          setState(() {
            final last = _messages.last;
            last.content = '⚠️ 请求失败\n\n$e';
            last.pending = false;
            _busy = false;
          });
        }
        if (!done.isCompleted) done.complete();
      },
      onDone: () {
        if (mounted) {
          setState(() {
            _messages.last.pending = false;
            _busy = false;
          });
        }
        if (!done.isCompleted) done.complete();
      },
      cancelOnError: true,
    );
    await done.future;
    await ChatStore.save(_session);
  }

  void _stop() {
    _sub?.cancel();
    setState(() {
      if (_messages.isNotEmpty && _messages.last.pending) {
        _messages.last.pending = false;
        if (_messages.last.content.trim().isEmpty) {
          _messages.last.content = '（已停止）';
        }
      }
      _busy = false;
    });
    ChatStore.save(_session);
  }

  /// 重新生成最后一条回答
  Future<void> _regenerate() async {
    if (_busy) return;
    int ui = -1;
    for (int i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].isUser) {
        ui = i;
        break;
      }
    }
    if (ui < 0) return;
    final q = _messages[ui].content;
    setState(() {
      _messages.removeRange(ui + 1, _messages.length);
      _messages.add(ChatMessage(role: 'assistant', pending: true));
      _busy = true;
    });
    _session.conversationId = ''; // 重生成开新上下文，避免 Dify 侧错乱
    _scrollToBottom();
    await _stream(q, const []);
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    _toast('已复制');
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ---------- 界面 ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appBar(),
      body: Column(
        children: [
          Expanded(child: _messages.isEmpty ? _welcome() : _list()),
          _inputBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _appBar() {
    return AppBar(
      title: const Row(
        children: [
          Text('🥐', style: TextStyle(fontSize: 21)),
          SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('黄油可颂',
                  style: TextStyle(fontSize: 17.5, fontWeight: FontWeight.w700)),
              Text('花生十三 × 郭熙 · 行测智能体',
                  style: TextStyle(fontSize: 10.5, color: Colors.white70)),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: '提问记录',
          icon: const Icon(Icons.history_rounded),
          onPressed: _openHistory,
        ),
        IconButton(
          tooltip: '新对话',
          icon: const Icon(Icons.add_comment_outlined),
          onPressed: _newChat,
        ),
      ],
    );
  }

  Widget _welcome() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 36),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Image.asset('assets/icon.png',
                width: 94, height: 94, fit: BoxFit.cover),
          ),
          const SizedBox(height: 20),
          Text('你好，我是黄油可颂 🥐',
              style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: _dark ? ButterColors.darkText : ButterColors.brown)),
          const SizedBox(height: 8),
          Text(
            '两位行测名师课程蒸馏成的知识库，随时问我任何考点、方法、口诀。\n也可以拍照上传题目。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, height: 1.6, color: _subColor),
          ),
          const SizedBox(height: 14),
          _connStatus(),
          const SizedBox(height: 26),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('试试这样问',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _subColor)),
          ),
          const SizedBox(height: 10),
          ..._quickQs.map(_chip),
        ],
      ),
    );
  }

  /// 显示当前线路，点一下可重新探测
  Widget _connStatus() {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () async {
        _toast('正在检测线路…');
        await DifyConfig.resolve();
        if (!mounted) return;
        setState(() {});
        _toast('当前线路：${DifyConfig.activeLabel}');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: _dark ? const Color(0xFF332C22) : ButterColors.creamDeep,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_tethering_rounded, size: 13, color: _subColor),
            const SizedBox(width: 5),
            Text('线路：${DifyConfig.activeLabel} · 点击重测',
                style: TextStyle(fontSize: 11, color: _subColor)),
          ],
        ),
      ),
    );
  }

  Widget _chip(String q) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: _botBg,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: _busy ? null : () => _send(q),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome,
                    size: 15, color: ButterColors.butter),
                const SizedBox(width: 9),
                Expanded(
                  child:
                      Text(q, style: TextStyle(fontSize: 13.5, color: _botText)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _list() {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
      itemCount: _messages.length,
      itemBuilder: (context, i) => _bubble(_messages[i], i),
    );
  }

  Widget _bubble(ChatMessage m, int index) {
    final isUser = m.isUser;
    final isLast = index == _messages.length - 1;

    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 322),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      decoration: BoxDecoration(
        color: isUser ? ButterColors.butter : _botBg,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(19),
          topRight: const Radius.circular(19),
          bottomLeft: Radius.circular(isUser ? 19 : 6),
          bottomRight: Radius.circular(isUser ? 6 : 19),
        ),
        border: isUser ? null : Border.all(color: _botBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isUser)
            SelectableText(m.content,
                style: const TextStyle(
                    fontSize: 15, color: Colors.white, height: 1.45))
          else
            MarkdownBody(
              data: m.content.isEmpty
                  ? (m.pending ? '' : '（空回复）')
                  : m.content,
              selectable: true,
              styleSheet: _mdStyle(),
            ),
          if (m.pending) const _TypingIndicator(),
          if (m.citations.isNotEmpty) ...[
            const SizedBox(height: 8),
            Divider(height: 1, color: _botBorder),
            const SizedBox(height: 7),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: m.citations.take(4).map((c) {
                final name = c.document.split('.').first;
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color:
                        _dark ? const Color(0xFF332C22) : ButterColors.creamDeep,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('📖 $name',
                      style: TextStyle(fontSize: 10.5, color: _subColor)),
                );
              }).toList(),
            ),
          ],
          if (!isUser && !m.pending && m.content.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                _miniBtn(Icons.copy_rounded, '复制', () => _copy(m.content)),
                if (isLast) ...[
                  const SizedBox(width: 4),
                  _miniBtn(Icons.refresh_rounded, '重新生成', () {
                    if (!_busy) _regenerate();
                  }),
                ],
              ],
            ),
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            const CircleAvatar(
              radius: 15,
              backgroundColor: ButterColors.butter,
              child: Text('🥐', style: TextStyle(fontSize: 15)),
            ),
            const SizedBox(width: 7),
          ],
          Flexible(child: bubble),
          if (isUser) ...[
            const SizedBox(width: 7),
            const CircleAvatar(
              radius: 15,
              backgroundColor: ButterColors.caramel,
              child: Text('蕾',
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniBtn(IconData icon, String tip, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 14, color: _subColor),
            const SizedBox(width: 3),
            Text(tip, style: TextStyle(fontSize: 11, color: _subColor)),
          ],
        ),
      ),
    );
  }

  MarkdownStyleSheet _mdStyle() {
    final head = _dark ? ButterColors.butter : ButterColors.brown;
    return MarkdownStyleSheet(
      p: TextStyle(fontSize: 15, color: _botText, height: 1.55),
      h1: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: head),
      h2: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: head),
      h3: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: head),
      strong: const TextStyle(
          fontWeight: FontWeight.w700, color: ButterColors.caramel),
      em: TextStyle(color: _botText, fontStyle: FontStyle.italic),
      code: TextStyle(
          backgroundColor:
              _dark ? const Color(0xFF332C22) : ButterColors.creamDeep,
          color: ButterColors.caramel,
          fontFamily: 'monospace'),
      blockquoteDecoration: BoxDecoration(
        color: _dark ? const Color(0xFF332C22) : ButterColors.creamDeep,
        borderRadius: BorderRadius.circular(8),
      ),
      listBullet: TextStyle(color: _botText, fontSize: 15),
      tableBorder: TableBorder.all(color: _botBorder, width: 0.5),
    );
  }

  Widget _inputBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        decoration: BoxDecoration(
          color: _dark ? ButterColors.darkCard : Colors.white,
          boxShadow: const [
            BoxShadow(
                color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, -2)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_pendingImage != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8, left: 4),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_pendingImage!,
                            width: 62, height: 62, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: -7,
                        right: -7,
                        child: GestureDetector(
                          onTap: () => setState(() => _pendingImage = null),
                          child: const CircleAvatar(
                            radius: 10,
                            backgroundColor: Colors.black54,
                            child:
                                Icon(Icons.close, size: 13, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: '拍照提问',
                  icon: const Icon(Icons.camera_alt_outlined,
                      color: ButterColors.caramel),
                  onPressed: _busy ? null : () => _pick(ImageSource.camera),
                ),
                IconButton(
                  tooltip: '选择图片',
                  icon: const Icon(Icons.image_outlined,
                      color: ButterColors.caramel),
                  onPressed: _busy ? null : () => _pick(ImageSource.gallery),
                ),
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(_input.text),
                    decoration: const InputDecoration(
                        hintText: '输入问题…', isDense: true),
                  ),
                ),
                const SizedBox(width: 7),
                GestureDetector(
                  onTap: _busy ? _stop : () => _send(_input.text),
                  child: Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      color: _busy
                          ? ButterColors.brownLight
                          : ButterColors.butter,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _busy ? Icons.stop_rounded : Icons.arrow_upward_rounded,
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
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final t = (_c.value * 3 + i) % 3;
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
