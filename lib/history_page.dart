import 'package:flutter/material.dart';

import 'models.dart';
import 'store.dart';
import 'theme.dart';

/// 提问记录（历史会话列表）
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late List<ChatSession> _list;

  @override
  void initState() {
    super.initState();
    _list = ChatStore.history();
  }

  void _reload() => setState(() => _list = ChatStore.history());

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return '刚刚';
    if (d.inMinutes < 60) return '${d.inMinutes} 分钟前';
    if (d.inHours < 24) return '${d.inHours} 小时前';
    if (d.inDays < 30) return '${d.inDays} 天前';
    return '${t.year}/${t.month}/${t.day}';
  }

  Future<void> _confirmDelete(ChatSession s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('删除这条记录？'),
        content: Text(s.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ChatStore.remove(s.id);
      _reload();
    }
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('清空全部提问记录？'),
        content: const Text('此操作不可恢复'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('清空', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ChatStore.clearAll();
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final sub = dark ? const Color(0xFFA89279) : ButterColors.brownLight;

    return Scaffold(
      appBar: AppBar(
        title: const Text('提问记录', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        actions: [
          if (_list.isNotEmpty)
            IconButton(
              tooltip: '清空',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: _confirmClear,
            ),
        ],
      ),
      body: _list.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_rounded, size: 54, color: sub),
                  const SizedBox(height: 14),
                  Text('还没有提问记录', style: TextStyle(color: sub, fontSize: 15)),
                  const SizedBox(height: 6),
                  Text('回到对话页问点什么吧 🥐',
                      style: TextStyle(color: sub, fontSize: 13)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
              itemCount: _list.length,
              itemBuilder: (context, i) {
                final s = _list[i];
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 10),
                  color: dark ? const Color(0xFF2A241C) : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: dark ? const Color(0xFF3A3226) : ButterColors.bubbleBotBorder,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.pop(context, s),
                    onLongPress: () => _confirmDelete(s),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  s.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 15, fontWeight: FontWeight.w700),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(_ago(s.updatedAt),
                                  style: TextStyle(fontSize: 11.5, color: sub)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            s.preview,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, height: 1.45, color: sub),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.chat_bubble_outline_rounded, size: 13, color: sub),
                              const SizedBox(width: 4),
                              Text('${s.userCount} 次提问',
                                  style: TextStyle(fontSize: 11.5, color: sub)),
                              const Spacer(),
                              Icon(Icons.chevron_right_rounded, size: 18, color: sub),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
