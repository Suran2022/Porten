/*
 * 系统消息页（对齐 Web 端 SystemMessagesPage.tsx 移动端布局）。
 *
 * bg-[#F5F5F5]；从右滑入；顶栏 BackIcon + 「官方系统」+ 右「全部已读」
 * （未读 gray-900 / 已读禁用 gray-400）；
 * 列表按日期分组（今天/昨天/M月D日…），组头 px-4 py-2 text-xs gray-400；
 * 白底卡片 px-4 py-4、标题 text-sm font-bold、内容 text-sm gray-600 mt-2、
 *   URL 链接化（trans 旗渐变 text + 下划线 #F5A9B8）；
 * 右侧 未读 red-500 / 已读 gray-400 text-xs；组内分隔 mx-4 h-px bg-gray-100；
 * 空态 Bell w-12 gray-200 + 暂无系统消息；点击卡片标已读；底 h-6。
 *
 * Mock 离线策略：消息数据取自 Web 端 mockServerData 同形态（版本号 + 更新文案）。
 */

import 'package:flutter/material.dart';

import '../../core/components/porten_back_icon.dart';
import '../../core/components/porten_lucide_icons.dart';
import '../profile/profile_page.dart' show kGray900, kGray400, kGray600, kGray200;

/// 日期分组工具（对齐 formatMessageDate：今天/昨天/前天/M月D日/…）。
String formatMessageDate(DateTime date) {
  final DateTime now = DateTime.now();
  final DateTime today =
      DateTime(now.year, now.month, now.day);
  final DateTime target = DateTime(date.year, date.month, date.day);
  final int diffDays = today.difference(target).inDays;
  if (diffDays == 0) return '今天';
  if (diffDays == 1) return '昨天';
  if (diffDays == 2) return '前天';
  if (date.year == now.year) return '${date.month}月${date.day}日';
  return '${date.year}年${date.month}月${date.day}日';
}

class _MockMessage {
  const _MockMessage({
    required this.id,
    required this.createdAt,
    required this.title,
    required this.content,
    this.isRead = false,
  });

  final int id;
  final DateTime createdAt;
  final String title;
  final String content;
  final bool isRead;
}

List<_MockMessage> _buildMockMessages() {
  final DateTime now = DateTime.now();
  return <_MockMessage>[
    _MockMessage(
      id: 1,
      createdAt: now.subtract(const Duration(minutes: 30)),
      title: 'v0.2.2 功能更新',
      content:
          '新增营地搜索与知识收藏功能，优化消息列表滑动体验。详情见 https://porten.app/changelog',
    ),
    _MockMessage(
      id: 2,
      createdAt: now.subtract(const Duration(minutes: 90)),
      title: 'v0.2.1 修复功能问题',
      content: '修复了分享卡片在弱网环境下封面丢失的问题，已恢复正常显示。',
      isRead: true,
    ),
    _MockMessage(
      id: 3,
      createdAt: now.subtract(const Duration(days: 1, hours: 2)),
      title: 'v0.2.0 功能更新',
      content:
          '支持跨儿时常统计与最新日记展示，欢迎访问 https://porten.app/docs 了解更多。',
    ),
    _MockMessage(
      id: 4,
      createdAt: now.subtract(const Duration(days: 3)),
      title: 'v0.1.9 功能更新',
      content: '消息列表左滑支持重要 / 置顶 / 隐藏操作，长按可快捷标记。',
      isRead: true,
    ),
  ];
}

/// URL 正则（对齐 Web URL_RE）。
final RegExp _urlRe = RegExp(
    r'https?://[A-Za-z0-9\-._~:/?#\[\]@!$&''()*+,;=%]+');

class SystemMessagesPage extends StatefulWidget {
  const SystemMessagesPage({super.key});

  @override
  State<SystemMessagesPage> createState() => _SystemMessagesPageState();
}

class _SystemMessagesPageState extends State<SystemMessagesPage> {
  late List<_MockMessage> _messages = _buildMockMessages();

  int get _unreadCount =>
      _messages.where((_MockMessage m) => !m.isRead).length;

  void _markRead(_MockMessage message) {
    if (message.isRead) return;
    setState(() {
      _messages = _messages
          .map((_MockMessage m) =>
              m.id == message.id ? _MockMessage(id: m.id, createdAt: m.createdAt, title: m.title, content: m.content, isRead: true) : m)
          .toList();
    });
  }

  void _markAllRead() {
    if (_unreadCount == 0) return;
    setState(() {
      _messages = _messages
          .map((_MockMessage m) => _MockMessage(
              id: m.id,
              createdAt: m.createdAt,
              title: m.title,
              content: m.content,
              isRead: true))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    // 按日期分组（保持顺序）
    final List<MapEntry<String, List<_MockMessage>>> groups =
        <MapEntry<String, List<_MockMessage>>>[];
    for (final _MockMessage m in _messages) {
      final String label = formatMessageDate(m.createdAt);
      final int idx = groups.indexWhere(
          (MapEntry<String, List<_MockMessage>> e) => e.key == label);
      if (idx >= 0) {
        groups[idx].value.add(m);
      } else {
        groups.add(MapEntry<String, List<_MockMessage>>(label, <_MockMessage>[m]));
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            // 顶栏
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: SizedBox(
                height: 40,
                child: Row(
                  children: <Widget>[
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).maybePop(),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: Center(child: const PortenBackIcon()),
                      ),
                    ),
                    const Spacer(),
                    const Text('官方系统',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: kGray900)),
                    const Spacer(),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _markAllRead,
                      child: Text('全部已读',
                          style: TextStyle(
                              fontSize: 14,
                              color: _unreadCount > 0 ? kGray900 : kGray400)),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _messages.isEmpty
                  ? _EmptyState()
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          for (final MapEntry<String, List<_MockMessage>> group
                              in groups) ...<Widget>[
                            const SizedBox(height: 16), // mt-4
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8), // px-4 py-2
                              child: Text(group.key,
                                  style: const TextStyle(
                                      fontSize: 12, color: kGray400)),
                            ),
                            Container(
                              color: Colors.white,
                              child: Column(
                                children: <Widget>[
                                  for (int i = 0;
                                      i < group.value.length;
                                      i++) ...<Widget>[
                                    if (i > 0)
                                      Container(
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 16), // mx-4
                                        height: 1,
                                        color: const Color(0xFFF3F4F6),
                                      ),
                                    _MessageCard(
                                      message: group.value[i],
                                      onTap: () => _markRead(group.value[i]),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 24), // h-6
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 消息卡片：标题 text-sm font-bold + 内容（URL 链接化渐变）+ 右侧未读/已读。
class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, required this.onTap});

  final _MockMessage message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16), // px-4 py-4
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(message.title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700, // font-bold
                          color: kGray900,
                          height: 1.35)),
                  const SizedBox(height: 8), // mt-2
                  _LinkifiedContent(text: message.content),
                ],
              ),
            ),
            const SizedBox(width: 12), // gap-3
            Padding(
              padding: const EdgeInsets.only(top: 2), // mt-0.5
              child: Text(message.isRead ? '已读' : '未读',
                  style: TextStyle(
                      fontSize: 12,
                      color: message.isRead ? kGray400 : const Color(0xFFEF4444))),
            ),
          ],
        ),
      ),
    );
  }
}

/// 内容渲染：URL 部分 trans 旗渐变文字 + 下划线（对齐 LinkifiedContent）。
class _LinkifiedContent extends StatelessWidget {
  const _LinkifiedContent({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final List<InlineSpan> spans = <InlineSpan>[];
    int last = 0;
    for (final RegExpMatch match in _urlRe.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(text: text.substring(last, match.start)));
      }
      final String url = match.group(0)!;
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: ShaderMask(
          shaderCallback: (Rect bounds) => const LinearGradient(
            colors: <Color>[
              Color(0xFF5BCEFA),
              Color(0xFFF5A9B8),
              Color(0xFF5BCEFA),
            ],
          ).createShader(bounds),
          blendMode: BlendMode.srcIn,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: Text(
              url,
              style: const TextStyle(
                fontSize: 14,
                height: 1.6,
                color: Colors.white, // 渐变载体
                decoration: TextDecoration.underline,
                decorationColor: Color(0xFFF5A9B8),
                decorationThickness: 1,
              ),
            ),
          ),
        ),
      ));
      last = match.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }

    return Text.rich(
      TextSpan(
        style: const TextStyle(
            fontSize: 14, color: kGray600, height: 1.6), // text-sm gray-600
        children: spans,
      ),
    );
  }
}

/// 空态：Bell w-12 gray-200 + 暂无系统消息。
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const SizedBox(height: 80), // py-20
        PortenLucideIcon('bell', size: 48, color: kGray200, strokeWidth: 1.5),
        const SizedBox(height: 12), // mb-3
        const Text('暂无系统消息',
            style: TextStyle(fontSize: 12, color: kGray400)),
      ],
    );
  }
}
