/*
 * 聊天页（对齐 Web 端 ChatPage.tsx 移动端布局）。
 *
 * 从右滑入 translate-x-full→0；bg-white；
 * 顶栏：BackIcon + 标题 text-lg font-medium + 右侧 电话/视频/更多（w-9 圆钮）；
 * 消息列表：pt-4，时间分隔 py-4 居中 text-xs gray-400；
 *   气泡 rounded-[9px] px-3 py-2：我方 = 品牌渐变(to bottom right
 *   #5BCEFA/.88 → #F5A9B8/.88) 白字；对方 = #FAFAFA + border gray-100；
 *   头像 36 圆；单聊无昵称、群聊显示 text-xs gray-400；px-4 py-2；
 *   文本 text-[15px] font-medium；语音 = 播放圆钮 + 波形条 + 时长；
 *   图片 160×200 内缩放；文件 = 白底 forceWhite 图标 + 名称/大小 + 进度条；
 * 底栏：输入框 h-10 rounded-md bg-gray-100/60 + 「传达」渐变按钮（有字展开）
 *   + 四图标行 Mic/Image/Smile/Plus（w-9 圆钮）；
 *   更多面板（两行四列功能卡）与表情面板 max-h 过渡展开（300ms）；
 *   语音面板：中央 64 渐变圆钮 + 左右波形区 + 状态文案。
 *
 * Mock 离线策略：消息为本地演示数据；发送文本即时上屏；语音录制用
 * 假录音状态机（不申请麦克风权限），波形为随机呼吸条。
 */

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/components/porten_back_icon.dart';
import '../../core/components/porten_lucide_icons.dart';
import '../../core/data/home_mock.dart';
import '../profile/profile_page.dart'
    show kGray900, kGray700, kGray600, kGray500, kGray400, kGray300, kGray100;

const Color kBrandBlue = Color(0xFF5BCEFA);
const Color kBrandPink = Color(0xFFF5A9B8);
const LinearGradient kBrandGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: <Color>[kBrandBlue, kBrandPink],
);

/// 消息类型。
enum _MsgType { text, voice, image, file, share, system }

class _ChatMsg {
  const _ChatMsg({
    required this.id,
    required this.type,
    required this.isMe,
    required this.time,
    this.content = '',
    this.duration,
    this.fileName,
    this.fileSize,
    this.progress,
    this.imageAsset,
    this.sender,
  });

  final int id;
  final _MsgType type;
  final bool isMe;
  final String time;
  final String content;
  final int? duration; // 语音秒数
  final String? fileName;
  final String? fileSize;
  final double? progress; // 文件发送进度 0-100
  final String? imageAsset; // 图片消息本地资产
  final String? sender; // 群聊消息发送者昵称
}

/// 相册 Mock（r21 #15：发送图片面板展示的本地资产，QQ 式方图）。
const List<String> kAlbumAssets = <String>[
  'assets/mock_avatars/profile_bg_fuyue.jpg',
  'assets/mock_avatars/friend_fu_juan.jpg',
  'assets/mock_avatars/camp_yunduan.jpg',
  'assets/mock_avatars/friend_li_yuexin.jpg',
  'assets/mock_avatars/camp_shiguang.jpg',
  'assets/mock_avatars/friend_chen_yutong.jpg',
  'assets/mock_avatars/camp_zhichang.jpg',
  'assets/mock_avatars/friend_lin_wanqing.jpg',
  'assets/mock_avatars/camp_kge.jpg',
  'assets/mock_avatars/friend_zhou_shihan.jpg',
  'assets/mock_avatars/friend_xu_qinghuan.jpg',
];

/// 相同时间戳的第 N 条消息（时间分隔行只在跨时间戳时出现）。
const String _kLaterTime = '14:32';
const String _kEveningTime = '20:15';

/// r21 #9：按会话生成差异化 Mock 消息——单聊/群聊、不同会话 id
/// 产出不同组合（文本/语音/图片/文件/分享/系统），复刻 Web 端消息样式。
List<_ChatMsg> _buildMockMessages(PortenConversation conv) {
  final bool group = conv.isGroup;
  final int seed = conv.id;
  // 群聊发送者轮换池
  const List<String> kGroupSenders = <String>[
    '周诗涵', '许清欢', '顾晓萌', '苏念', '夏栀',
  ];
  String senderOf(int i) => kGroupSenders[i % kGroupSenders.length];

  _ChatMsg text(int id, bool me, String t, String c, {String? sender}) =>
      _ChatMsg(id: id, type: _MsgType.text, isMe: me, time: t, content: c, sender: sender);

  // 以 id 决定消息组合（确定性，且各会话互不相同）
  final int variant = seed % 5;

  switch (variant) {
    case 0: // 符娟（单聊 · 日常关心）
      return <_ChatMsg>[
        text(1, false, '14:02', '今天的心情怎么样？'),
        text(2, true, '14:02', '挺好的！刚和朋友聊完，感觉被理解了 ✨'),
        _ChatMsg(id: 3, type: _MsgType.voice, isMe: false, time: '14:06', duration: 8),
        text(4, false, '14:08', '那就好，晚上一起吃饭吗？'),
        text(5, true, '14:08', '好呀，老地方见～'),
        _ChatMsg(
            id: 6, type: _MsgType.image, isMe: false, time: _kLaterTime,
            imageAsset: 'assets/mock_avatars/friend_fu_juan.jpg'),
        text(7, true, _kLaterTime, '拍得真好看！'),
      ];
    case 1: // 云端旅行营地（群聊 · 攻略讨论）
      return <_ChatMsg>[
        text(1, false, '14:02', '新路线的攻略已经整理好了，大家看看', sender: senderOf(0)),
        text(2, true, '14:02', '太棒了，正好下周想去！'),
        _ChatMsg(
            id: 3, type: _MsgType.image, isMe: false, time: '14:05',
            imageAsset: 'assets/mock_avatars/camp_yunduan.jpg', sender: senderOf(1)),
        text(4, false, '14:05', '这是上个月拍的海边日出 🌅', sender: senderOf(1)),
        _ChatMsg(
            id: 5, type: _MsgType.file, isMe: false, time: '14:08',
            fileName: '青岛三日游攻略.pdf', fileSize: '3.1 MB', sender: senderOf(0)),
        text(6, true, _kLaterTime, '已收藏，谢谢分享！'),
        _ChatMsg(id: 7, type: _MsgType.system, isMe: false, time: _kLaterTime,
            content: '「许清欢」加入了营地'),
      ];
    case 2: // 李月欣（单聊 · 见面 + 文件）
      return <_ChatMsg>[
        text(1, false, '14:02', '我到了，你在哪？'),
        text(2, true, '14:05', '地铁站 2 号口，马上出来'),
        _ChatMsg(id: 3, type: _MsgType.image, isMe: true, time: '14:06',
            imageAsset: 'assets/mock_avatars/friend_li_yuexin.jpg'),
        text(4, false, '14:06', '看到你啦！'),
        _ChatMsg(
            id: 5, type: _MsgType.file, isMe: true, time: _kEveningTime,
            fileName: '聚会照片打包.zip', fileSize: '18.4 MB', progress: 92),
        text(6, false, _kEveningTime, '收到啦，回家慢慢看 💕'),
      ];
    case 3: // 拾光编程营地（群聊 · 技术分享）
      return <_ChatMsg>[
        text(1, false, '14:02', 'Flutter 3.x 的新特性分享来了', sender: senderOf(2)),
        text(2, true, '14:05', '期待！Impeller 现在是默认渲染器了吗？'),
        text(3, false, '14:06', '是的，还有 WasmGC 的稳定支持', sender: senderOf(3)),
        _ChatMsg(
            id: 4, type: _MsgType.share, isMe: false, time: '14:08',
            sender: senderOf(2)),
        _ChatMsg(id: 5, type: _MsgType.voice, isMe: true, time: _kLaterTime, duration: 12),
        text(6, false, _kLaterTime, '这期分享回放会传到营地资料区', sender: senderOf(4)),
      ];
    default: // 其余会话（陈雨桐/林晚晴/周诗涵/职场/K歌/许清欢）：按 id 排列组合
      return <_ChatMsg>[
        text(1, false, '14:02', conv.lastMessage, sender: group ? conv.senderName : null),
        text(2, true, '14:05', _replyFor(seed)),
        _ChatMsg(id: 3, type: _MsgType.voice, isMe: false, time: '14:06',
            duration: 5 + seed % 20, sender: group ? senderOf(seed) : null),
        if (seed % 2 == 0)
          _ChatMsg(
              id: 4, type: _MsgType.file, isMe: true, time: '14:08',
              fileName: '周末安排.xlsx', fileSize: '0.8 MB', progress: 100)
        else
          _ChatMsg(
              id: 4, type: _MsgType.image, isMe: true, time: '14:08',
              imageAsset: kAlbumAssets[seed % kAlbumAssets.length]),
        text(5, false, _kLaterTime, group ? '收到～' : '好嘞，回聊！',
            sender: group ? senderOf(seed + 1) : null),
        if (group)
          _ChatMsg(id: 6, type: _MsgType.system, isMe: false, time: _kEveningTime,
              content: '「苏念」加入了营地'),
      ];
  }
}

/// 变体回复语（按会话 id 确定，互不相同）。
String _replyFor(int seed) {
  const List<String> kReplies = <String>[
    '哈哈哈这个太好笑了 😂',
    '文件发你了，记得查收',
    '收到了，谢谢～',
    '明天上午的分享别忘了哦',
    '周五晚上的歌单投票开始啦 🎤',
    '欢迎新加入的姐妹，先做个自我介绍吧～',
  ];
  return kReplies[seed % kReplies.length];
}

/// 最近使用表情（Mock：固定 8 个；持久化由后续接入）。
const List<String> kRecentEmojis = <String>['🌈', '✨', '❤️'];

const List<String> kEmojiList = <String>[
  '😀', '😄', '😁', '🤣', '😂', '🙂', '😉', '😊',
  '😍', '🥰', '😘', '😗', '🤗', '🤭', '🤔', '😏',
  '😌', '😴', '🥺', '😢', '😭', '😤', '😠', '🤯',
  '😳', '🥵', '🥶', '😱', '😨', '😰', '😥', '😞',
  '👍', '👎', '👏', '🙏', '🤝', '💪', '✌️', '🤞',
  '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍',
  '🌈', '✨', '🎉', '🎊', '🎁', '🌸', '🌻', '🌹',
];

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.conversation});

  /// 所属会话（r21：提供名称/单聊群聊/群人数/头像，消息 Mock 按会话差异化）。
  final PortenConversation conversation;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late final List<_ChatMsg> _messages = _buildMockMessages(widget.conversation);
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _voicePanelOpen = false;
  bool _morePanelOpen = false;
  bool _emojiPanelOpen = false;
  bool _imagePanelOpen = false;
  int _nextId = 100;

  // Mock 录音状态机：idle → recording → recorded
  _VoiceState _voiceState = _VoiceState.idle;
  int _recordSeconds = 0;

  @override
  void initState() {
    super.initState();
    // r21 #13：进入聊天页平滑定位到最新消息（无 jump 卡顿）。
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(
      _scrollCtrl.position.maxScrollExtent,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _send() {
    final String text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_ChatMsg(
        id: _nextId++,
        type: _MsgType.text,
        isMe: true,
        time: _nowLabel(),
        content: text,
      ));
      _inputCtrl.clear();
    });
    // r21 #12：发送后必须平滑定位到刚发送的最新消息。
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  /// 从相册面板发送图片消息（r21 #15）。
  void _sendImage(String asset) {
    setState(() {
      _messages.add(_ChatMsg(
        id: _nextId++,
        type: _MsgType.image,
        isMe: true,
        time: _nowLabel(),
        imageAsset: asset,
      ));
      _imagePanelOpen = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _togglePanels({bool? voice, bool? more, bool? emoji, bool? image}) {
    setState(() {
      _voicePanelOpen = voice ?? false;
      _morePanelOpen = more ?? false;
      _emojiPanelOpen = emoji ?? false;
      _imagePanelOpen = image ?? false;
    });
  }

  String _nowLabel() {
    final DateTime now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  String formatDuration(int seconds) {
    if (seconds < 60) return '$seconds"';
    final int m = seconds ~/ 60;
    final int s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
            children: <Widget>[
            _TopBar(conversation: widget.conversation),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _togglePanels(),
                child: _MessageList(
                  messages: _messages,
                  conversation: widget.conversation,
                  scrollCtrl: _scrollCtrl,
                  voiceState: _voiceState,
                  recordSeconds: _recordSeconds,
                ),
              ),
            ),
            _BottomBar(
              inputCtrl: _inputCtrl,
              onSend: _send,
              voicePanelOpen: _voicePanelOpen,
              morePanelOpen: _morePanelOpen,
              emojiPanelOpen: _emojiPanelOpen,
              imagePanelOpen: _imagePanelOpen,
              onToggleVoice: () =>
                  _togglePanels(voice: !_voicePanelOpen),
              onToggleMore: () => _togglePanels(more: !_morePanelOpen),
              onToggleEmoji: () => _togglePanels(emoji: !_emojiPanelOpen),
              onToggleImage: () => _togglePanels(image: !_imagePanelOpen),
              onPickAlbumImage: _sendImage,
              voiceState: _voiceState,
              onVoiceClick: _handleVoiceClick,
              onPickEmoji: (String emoji) {
                final String next = (_inputCtrl.text + emoji);
                _inputCtrl.text = next.length > 500 ? next.substring(0, 500) : next;
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  void _handleVoiceClick() {
    switch (_voiceState) {
      case _VoiceState.recording:
        setState(() {
          _voiceState = _VoiceState.recorded;
          if (_recordSeconds < 1) _recordSeconds = 1;
        });
      case _VoiceState.recorded:
        // 发送语音（Mock：作为语音消息上屏）
        setState(() {
          _messages.add(_ChatMsg(
            id: _nextId++,
            type: _MsgType.voice,
            isMe: true,
            time: _nowLabel(),
            duration: _recordSeconds,
          ));
          _voiceState = _VoiceState.idle;
          _recordSeconds = 0;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      case _VoiceState.idle:
        // Mock：1 秒后自动进入录音中并每秒累计
        setState(() => _voiceState = _VoiceState.recording);
        Future<void>.delayed(const Duration(milliseconds: 600), () {
          if (mounted && _voiceState == _VoiceState.recording) {
            setState(() => _recordSeconds = 1);
          }
        });
    }
  }
}

enum _VoiceState { idle, recording, recorded }

/// 顶栏：BackIcon + 标题（群聊追加灰色人数）+ 电话/视频/更多。
/// r21 #10：左侧返回钮贴左 8px（对齐 Web -ml-2）、返回图标与标题基线对齐；
/// 右侧图标组 w-9 gap-1 贴右，与 Web 端一致。
class _TopBar extends StatelessWidget {
  const _TopBar({required this.conversation});

  final PortenConversation conversation;

  @override
  Widget build(BuildContext context) {
    final bool isGroup = conversation.isGroup;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 12), // px-4 + -ml-2 → 左 8
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
            const SizedBox(width: 4), // gap-1
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  Flexible(
                    child: Text(conversation.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: kGray900)),
                  ),
                  // 群聊：标题后灰色人数（对齐 Web 端 (memberCount)）
                  if (isGroup && conversation.memberCount != null) ...<Widget>[
                    const SizedBox(width: 4),
                    Text('(${conversation.memberCount})',
                        maxLines: 1,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: kGray400)),
                  ],
                ],
              ),
            ),
            if (!isGroup) ...<Widget>[
              _CircleIcon(icon: 'phone', onTap: () {}),
              _CircleIcon(icon: 'video', onTap: () {}),
            ],
            _CircleIcon(icon: 'more-vertical', onTap: () {}),
          ],
        ),
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({required this.icon, required this.onTap});

  final String icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, // w-9 h-9
        height: 36,
        decoration: const BoxDecoration(shape: BoxShape.circle),
        child: Center(
          child: PortenLucideIcon(icon, size: 20, color: kGray700, strokeWidth: 1.5),
        ),
      ),
    );
  }
}

/// 消息列表。
class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.messages,
    required this.conversation,
    required this.scrollCtrl,
    required this.voiceState,
    required this.recordSeconds,
  });

  final List<_ChatMsg> messages;
  final PortenConversation conversation;
  final ScrollController scrollCtrl;
  final _VoiceState voiceState;
  final int recordSeconds;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const Center(
        child: Text('暂无消息', style: TextStyle(fontSize: 12, color: kGray400)),
      );
    }
    // r21 #4/#14：ListView.builder 懒构建 + AlwaysScrollable——消息不足一屏
    // 也允许滑出顶部/底部（overscroll 回弹），滚动性能与流畅度提升。
    return ListView.builder(
      controller: scrollCtrl,
      padding: const EdgeInsets.only(top: 16, bottom: 20),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: messages.length,
      itemBuilder: (BuildContext context, int index) {
        final _ChatMsg msg = messages[index];
        return Column(
          children: <Widget>[
            if (index == 0 || messages[index].time != messages[index - 1].time)
              _TimeDivider(time: msg.time),
            RepaintBoundary(
              child: _MessageItem(
                  msg: msg,
                  conversation: conversation,
                  voiceState: voiceState,
                  recordSeconds: recordSeconds),
            ),
          ],
        );
      },
    );
  }
}

class _TimeDivider extends StatelessWidget {
  const _TimeDivider({required this.time});

  final String time;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16), // py-4
      child: Text(time, style: const TextStyle(fontSize: 12, color: kGray400)),
    );
  }
}

class _MessageItem extends StatelessWidget {
  const _MessageItem({
    required this.msg,
    required this.conversation,
    required this.voiceState,
    required this.recordSeconds,
  });

  final _ChatMsg msg;
  final PortenConversation conversation;
  final _VoiceState voiceState;
  final int recordSeconds;

  @override
  Widget build(BuildContext context) {
    final Widget content = switch (msg.type) {
      _MsgType.text => _TextContent(content: msg.content, isMe: msg.isMe),
      _MsgType.voice => _VoiceContent(duration: msg.duration ?? 0, isMe: msg.isMe),
      _MsgType.image => _ImageContent(isMe: msg.isMe, imageAsset: msg.imageAsset),
      _MsgType.file => _FileContent(msg: msg),
      _MsgType.share => _ShareContent(),
      _MsgType.system => _SystemContent(content: msg.content),
    };

    if (msg.type == _MsgType.system) {
      return content;
    }

    final Widget bubble = msg.type == _MsgType.image
        ? content
        : Container(
            constraints: const BoxConstraints(maxWidth: 260),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              gradient: msg.isMe
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        Color(0xE05BCEFA), // rgba(91,206,250,.88)
                        Color(0xE0F5A9B8), // rgba(245,169,184,.88)
                      ],
                    )
                  : null,
              color: msg.type == _MsgType.file
                  ? Colors.white
                  : msg.isMe
                      ? null
                      : const Color(0xFFFAFAFA),
              border: msg.isMe
                  ? null
                  : Border.all(color: const Color(0xFFF3F4F6)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: content,
          );

    // r21：头像按会话资产（当前账号固定抚月）；群聊显示发送者昵称。
    final String? peerAsset = conversation.avatarAsset;
    final Widget avatar = Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: kGray100,
      ),
      clipBehavior: Clip.antiAlias,
      child: msg.isMe
          ? Image.asset('assets/mock_avatars/avatar_fuyue.jpg',
              width: 36, height: 36, fit: BoxFit.cover, gaplessPlayback: true)
          : (peerAsset != null
              ? Image.asset(peerAsset,
                  width: 36, height: 36, fit: BoxFit.cover, gaplessPlayback: true)
              : const PortenLucideIcon('user', size: 18, color: kGray400)),
    );

    final Widget row = msg.isMe
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                Flexible(child: bubble),
                const SizedBox(width: 8),
                avatar,
              ],
            ),
          )
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                avatar,
                const SizedBox(width: 8),
                Flexible(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // 群聊显示发送者昵称（单聊隐藏，对齐 Web 端）
                    if (conversation.isGroup && msg.sender != null) ...<Widget>[
                      Text(msg.sender!,
                          style: const TextStyle(
                              fontSize: 12, color: kGray400)),
                      const SizedBox(height: 4),
                    ],
                    bubble,
                  ],
                )),
              ],
            ),
          );
    return row;
  }
}

class _TextContent extends StatelessWidget {
  const _TextContent({required this.content, required this.isMe});

  final String content;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Text(content,
        style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: isMe ? Colors.white : kGray900,
            height: 1.6));
  }
}

/// 语音气泡内容：播放圆钮 + 波形 + 时长（宽度 92 + 1px/s，上限 260）。
class _VoiceContent extends StatefulWidget {
  const _VoiceContent({required this.duration, required this.isMe});

  final int duration;
  final bool isMe;

  @override
  State<_VoiceContent> createState() => _VoiceContentState();
}

class _VoiceContentState extends State<_VoiceContent> {
  bool _playing = false;
  late final List<double> _bars = List<double>.generate(
      18, (int i) => 22 + math.Random(widget.duration * 31 + i).nextDouble() * 54);

  @override
  Widget build(BuildContext context) {
    final int d = widget.duration;
    double width = 92.0 + (d > 10 ? 10 : d);
    if (d > 10) {
      width += (d - 10) * ((260.0 - width) / 70.0);
    }
    width = width.clamp(92.0, 260.0);

    return GestureDetector(
      onTap: () => setState(() => _playing = !_playing),
      child: SizedBox(
        width: width,
        child: Row(
          children: <Widget>[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: widget.isMe ? Colors.white : kGray900),
              ),
              child: Center(
                child: PortenLucideIcon(
                  _playing ? 'pause' : 'play',
                  size: 14,
                  color: widget.isMe ? Colors.white : kGray900,
                  strokeWidth: 1.8,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SizedBox(
                  height: 20,
                  child: Row(
                    children: <Widget>[
                      for (int i = 0; i < _bars.length; i++)
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1.5),
                            decoration: BoxDecoration(
                              color: widget.isMe
                                  ? Colors.white
                                  : kGray900,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            height: _bars[i] / 100 * 20,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Text(formatDuration2(d),
                style: TextStyle(
                    fontSize: 12,
                    color: widget.isMe
                        ? Colors.white.withValues(alpha: 0.8)
                        : kGray900.withValues(alpha: 0.8))),
          ],
        ),
      ),
    );
  }

  static String formatDuration2(int seconds) {
    if (seconds < 60) return '$seconds"';
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}

/// 图片消息：方图资产（Mock 无资产时回退品牌渐变占位）。
class _ImageContent extends StatelessWidget {
  const _ImageContent({required this.isMe, this.imageAsset});

  final bool isMe;
  final String? imageAsset;

  @override
  Widget build(BuildContext context) {
    final String? asset = imageAsset;
    return Container(
      width: 160,
      height: 160, // r21：QQ 式正方形图
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(9)),
      ),
      clipBehavior: Clip.antiAlias,
      child: asset != null
          ? Image.asset(asset, width: 160, height: 160,
              fit: BoxFit.cover, gaplessPlayback: true)
          : const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[Color(0x145BCEFA), Color(0x14F5A9B8)],
                ),
              ),
            ),
    );
  }
}

/// 文件消息（白底 forceWhite）：图标 + 名称/大小 + 发送中进度条。
class _FileContent extends StatelessWidget {
  const _FileContent({required this.msg});

  final _ChatMsg msg;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const PortenLucideIcon('file-text', size: 36, color: kBrandBlue, strokeWidth: 1.5),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(msg.fileName ?? '文件',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500, color: kGray900)),
                const SizedBox(height: 2),
                Text('${msg.fileSize ?? ''}/发送中',
                    style: const TextStyle(fontSize: 12, color: kGray500)),
                if (msg.progress != null) ...<Widget>[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: SizedBox(
                      height: 8,
                      child: Stack(
                        children: <Widget>[
                          // 流动渐变轨道
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: <Color>[kBrandBlue, kBrandPink],
                              ),
                            ),
                          ),
                          // 灰色遮罩从右收起
                          Align(
                            alignment: Alignment.centerRight,
                            child: FractionallySizedBox(
                              widthFactor: (100 - msg.progress!) / 100,
                              child: Container(color: kGray100),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 分享卡片消息。
class _ShareContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kGray300.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            height: 96,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[Color(0x1A5BCEFA), Color(0x1AF5A9B8)],
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text('如何向朋友出柜',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: kGray900)),
          const SizedBox(height: 4),
          const Text('希望还在犹豫的姐妹们也能早日遇到愿意理解你们的人。',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: kGray500, height: 1.4)),
        ],
      ),
    );
  }
}

/// 系统消息（居中）。
class _SystemContent extends StatelessWidget {
  const _SystemContent({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const SizedBox(height: 8),
        Text(content,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: kGray500)),
      ],
    );
  }
}

/// 底栏：输入行 + 四图标行 + 四个展开面板。
class _BottomBar extends StatefulWidget {
  const _BottomBar({
    required this.inputCtrl,
    required this.onSend,
    required this.voicePanelOpen,
    required this.morePanelOpen,
    required this.emojiPanelOpen,
    required this.imagePanelOpen,
    required this.onToggleVoice,
    required this.onToggleMore,
    required this.onToggleEmoji,
    required this.onToggleImage,
    required this.onPickAlbumImage,
    required this.voiceState,
    required this.onVoiceClick,
    required this.onPickEmoji,
  });

  final TextEditingController inputCtrl;
  final VoidCallback onSend;
  final bool voicePanelOpen;
  final bool morePanelOpen;
  final bool emojiPanelOpen;
  final bool imagePanelOpen;
  final VoidCallback onToggleVoice;
  final VoidCallback onToggleMore;
  final VoidCallback onToggleEmoji;
  final VoidCallback onToggleImage;
  final ValueChanged<String> onPickAlbumImage;
  final _VoiceState voiceState;
  final VoidCallback onVoiceClick;
  final ValueChanged<String> onPickEmoji;

  @override
  State<_BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends State<_BottomBar> {
  @override
  void initState() {
    super.initState();
    widget.inputCtrl.addListener(_onInputChanged);
  }

  void _onInputChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.inputCtrl.removeListener(_onInputChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasText = widget.inputCtrl.text.trim().isNotEmpty;

    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(context).bottom), // r21：底部安全区
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // 输入行
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: TextField(
                      controller: widget.inputCtrl,
                      onChanged: (_) {},
                      onSubmitted: (_) => widget.onSend(),
                      style: const TextStyle(fontSize: 14, color: kGray900),
                      decoration: const InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: '说点什么…',
                        hintStyle: TextStyle(fontSize: 14, color: kGray400),
                      ),
                    ),
                  ),
                ),
                // 「传达」渐变按钮：有字展开（max-w 过渡），无字收起
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  height: 40,
                  width: hasText ? 88 : 0,
                  margin: EdgeInsets.only(left: hasText ? 8 : 0),
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: kBrandGradient,
                  ),
                  child: GestureDetector(
                    onTap: hasText ? widget.onSend : null,
                    child: const Center(
                      child: Text('传达',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 四图标行（r21 #2：两端均布 spaceBetween，对齐 Web justify-between；
          // 图标按钮 w-9 h-9，行内 px-1）
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                _PanelIcon(
                    icon: 'mic',
                    active: widget.voicePanelOpen,
                    onTap: widget.onToggleVoice),
                _PanelIcon(
                    icon: 'image',
                    active: widget.imagePanelOpen,
                    onTap: widget.onToggleImage),
                _PanelIcon(
                    icon: 'smile',
                    active: widget.emojiPanelOpen,
                    onTap: widget.onToggleEmoji),
                _PanelIcon(
                    icon: 'plus',
                    size: 24,
                    active: widget.morePanelOpen,
                    onTap: widget.onToggleMore),
              ],
            ),
          ),
          // 相册图片面板（r21 #15：QQ 式方图、左对齐，展开于图标行下方）
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: const Cubic(0.25, 0.1, 0.25, 1),
            height: widget.imagePanelOpen ? 236 : 0,
            clipBehavior: Clip.hardEdge,
            decoration: const BoxDecoration(),
            child: _ImagePanel(onPick: widget.onPickAlbumImage),
          ),
          // 更多功能面板（max-h 过渡；r21 #3：高度按内容实算 250，
          // 修复第二行被截断）
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: const Cubic(0.25, 0.1, 0.25, 1),
            height: widget.morePanelOpen ? 250 : 0,
            clipBehavior: Clip.hardEdge,
            decoration: const BoxDecoration(),
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: _MorePanel(),
            ),
          ),
          // 表情面板
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: const Cubic(0.25, 0.1, 0.25, 1),
            height: widget.emojiPanelOpen ? 256 : 0, // max-h-64/80
            clipBehavior: Clip.hardEdge,
            decoration: const BoxDecoration(),
            child: SingleChildScrollView(
              child: _EmojiPanel(onPick: widget.onPickEmoji),
            ),
          ),
          // 语音面板
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: const Cubic(0.25, 0.1, 0.25, 1),
            height: widget.voicePanelOpen ? 210 : 0,
            clipBehavior: Clip.hardEdge,
            decoration: const BoxDecoration(),
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: _VoicePanel(
                state: widget.voiceState,
                onClick: widget.onVoiceClick,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelIcon extends StatelessWidget {
  const _PanelIcon({
    required this.icon,
    required this.onTap,
    this.active = false,
    this.size = 20,
  });

  final String icon;
  final VoidCallback onTap;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? kGray100 : Colors.transparent,
        ),
        child: Center(
          child: PortenLucideIcon(icon, size: size, color: kGray600, strokeWidth: 1.5),
        ),
      ),
    );
  }
}

/// 相册图片面板（r21 #15，对齐 QQ 做法）：功能图标下方展开，
/// 相册图片正方形、左对齐流式排布，点击即发送该图片。
class _ImagePanel extends StatelessWidget {
  const _ImagePanel({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1, // 正方形
          children: <Widget>[
            for (final String asset in kAlbumAssets)
              GestureDetector(
                onTap: () => onPick(asset),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(asset,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      gaplessPlayback: true),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 更多功能面板：两行四列（第 8 格空）。
class _MorePanel extends StatelessWidget {
  static const List<(String, String)> _items = <(String, String)>[
    ('文件', 'paperclip'),
    ('音乐', 'music2'),
    ('收藏', 'star'),
    ('名片', 'contact'),
    ('约定', 'calendar-check'),
    ('旅程', 'map'),
    ('位置', 'map-pin'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 56 / 76,
          children: <Widget>[
            for (final (String, String) item in _items)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: PortenLucideIcon(item.$2,
                          size: 24, color: kGray600, strokeWidth: 1.5),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(item.$1,
                      style:
                          const TextStyle(fontSize: 12, color: kGray600)),
                ],
              ),
            const SizedBox(), // 第 8 格空
          ],
        ),
      ),
    );
  }
}

/// 表情面板：最近使用 → 超级表情（空）→ emoji。
class _EmojiPanel extends StatelessWidget {
  const _EmojiPanel({required this.onPick});

  final ValueChanged<String> onPick;

  Widget _emojiGrid(List<String> emojis) {
    return GridView.count(
      crossAxisCount: 8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.0,
      children: <Widget>[
        for (final String e in emojis)
          GestureDetector(
            onTap: () => onPick(e),
            child: Center(
              child: Text(e, style: const TextStyle(fontSize: 24)),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('最近使用',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: kGray500)),
          const SizedBox(height: 8),
          _emojiGrid(kRecentEmojis),
          const SizedBox(height: 16),
          const Text('超级表情',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: kGray500)),
          const SizedBox(height: 16),
          const Text('emoji 表情',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: kGray500)),
          const SizedBox(height: 8),
          _emojiGrid(kEmojiList),
        ],
      ),
    );
  }
}

/// 语音面板：中央渐变圆钮 + 左右波形区 + 状态文案。
class _VoicePanel extends StatelessWidget {
  const _VoicePanel({required this.state, required this.onClick});

  final _VoiceState state;
  final VoidCallback onClick;

  @override
  Widget build(BuildContext context) {
    final String statusText = switch (state) {
      _VoiceState.recording => '正在录制 · 1"',
      _VoiceState.recorded => '点击发送语音',
      _VoiceState.idle => '点击录制语音',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Column(
        children: <Widget>[
          const Text('语音消息',
              style: TextStyle(fontSize: 14, color: kGray500)),
          const SizedBox(height: 16),
          SizedBox(
            height: 80,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: state == _VoiceState.recording
                      ? const _StaticWave()
                      : const SizedBox(),
                ),
                GestureDetector(
                  onTap: onClick,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: kBrandGradient,
                    ),
                    child: Center(
                      child: PortenLucideIcon(
                        state == _VoiceState.recording
                            ? 'square'
                            : state == _VoiceState.recorded
                                ? 'check'
                                : 'mic',
                        size: 28,
                        color: Colors.white,
                        strokeWidth: 1.8,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: state == _VoiceState.recording
                      ? const _StaticWave()
                      : const SizedBox(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 16,
            child: Text(statusText,
                style: TextStyle(
                    fontSize: 12,
                    color: state == _VoiceState.idle ? kGray400 : kGray600)),
          ),
        ],
      ),
    );
  }
}

/// 录音波形（Mock：静态呼吸条）。
class _StaticWave extends StatelessWidget {
  const _StaticWave();

  @override
  Widget build(BuildContext context) {
    final math.Random rand = math.Random(42);
    return Row(
      children: <Widget>[
        for (int i = 0; i < 18; i++)
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              height: (20 + rand.nextDouble() * 40) / 100 * 32,
              decoration: BoxDecoration(
                color: kGray300,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
      ],
    );
  }
}
