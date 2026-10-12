/*
 * 首页 Mock 数据（对齐 Web 端 data/mockServerData.ts + data/partnerMock.ts）。
 *
 * 时间以模块加载时刻为基准向前推算分钟数，保证「刚刚 / HH:mm / 昨天」
 * 等相对时间展示自然。
 *
 * r19：头像/昵称 Mock 优化——同胞与营地卡片重新生成（真人系昵称），
 * 头像改用项目资产 assets/mock_avatars/ 下的本地图片（离线可用）。
 */

/// 当前登录用户（昵称：抚月，头像/背景用本地资产图）。
class PortenCurrentUser {
  const PortenCurrentUser._();

  static const String nickname = '抚月';
  static const String avatarAsset = 'assets/mock_avatars/avatar_fuyue.jpg';
  static const String profileBgAsset =
      'assets/mock_avatars/profile_bg_fuyue.jpg';
  static const String mood = '😊 开心';
  static const String latestDiary =
      '今天阳光很好，坐在窗边写下这些的时候，突然觉得被世界温柔地接住了。愿我们都能慢慢长成自己喜欢的样子。';
}

/// 会话条目。
class PortenConversation {
  const PortenConversation({
    required this.id,
    required this.isGroup,
    required this.name,
    required this.lastMessage,
    required this.minutesAgo,
    required this.unreadCount,
    this.senderName,
    this.memberCount,
    this.avatarAsset,
  });

  final int id;
  final bool isGroup;
  final String name;
  final String lastMessage;
  final int minutesAgo;
  final int unreadCount;
  final String? senderName;
  final int? memberCount;

  /// 本地头像资产（为空时回退渐变圆底 + 首字）。
  final String? avatarAsset;
}

/// 会话 Mock 数据（r19 重建：同胞真人昵称 + 营地本地头像）。
const List<PortenConversation> kPortenConversations = <PortenConversation>[
  PortenConversation(
    id: 301,
    isGroup: false,
    name: '符娟',
    lastMessage: '晚上一起吃饭吗？',
    minutesAgo: 18,
    unreadCount: 2,
    senderName: '符娟',
    avatarAsset: 'assets/mock_avatars/friend_fu_juan.jpg',
  ),
  PortenConversation(
    id: 302,
    isGroup: true,
    name: '云端旅行营地',
    lastMessage: '新路线的攻略已经整理好了，大家看看',
    minutesAgo: 42,
    unreadCount: 12,
    senderName: '周诗涵',
    memberCount: 23,
    avatarAsset: 'assets/mock_avatars/camp_yunduan.jpg',
  ),
  PortenConversation(
    id: 303,
    isGroup: false,
    name: '李月欣',
    lastMessage: '我到了，你在哪？',
    minutesAgo: 180,
    unreadCount: 0,
    senderName: '李月欣',
    avatarAsset: 'assets/mock_avatars/friend_li_yuexin.jpg',
  ),
  PortenConversation(
    id: 304,
    isGroup: false,
    name: '陈雨桐',
    lastMessage: '哈哈哈这个太好笑了',
    minutesAgo: 360,
    unreadCount: 0,
    senderName: '陈雨桐',
    avatarAsset: 'assets/mock_avatars/friend_chen_yutong.jpg',
  ),
  PortenConversation(
    id: 305,
    isGroup: true,
    name: '拾光编程营地',
    lastMessage: 'Flutter 3.x 的新特性分享来了',
    minutesAgo: 60 * 26,
    unreadCount: 36,
    senderName: '许清欢',
    memberCount: 48,
    avatarAsset: 'assets/mock_avatars/camp_shiguang.jpg',
  ),
  PortenConversation(
    id: 306,
    isGroup: false,
    name: '林晚晴',
    lastMessage: '文件发你了',
    minutesAgo: 60 * 30,
    unreadCount: 0,
    senderName: '林晚晴',
    avatarAsset: 'assets/mock_avatars/friend_lin_wanqing.jpg',
  ),
  PortenConversation(
    id: 307,
    isGroup: false,
    name: '周诗涵',
    lastMessage: '收到了，谢谢',
    minutesAgo: 60 * 24,
    unreadCount: 0,
    senderName: '抚月',
    avatarAsset: 'assets/mock_avatars/friend_zhou_shihan.jpg',
  ),
  PortenConversation(
    id: 308,
    isGroup: true,
    name: '职场互助营地',
    lastMessage: '明天上午的分享别忘了哦',
    minutesAgo: 60 * 24 * 2,
    unreadCount: 0,
    senderName: '顾晓萌',
    memberCount: 32,
    avatarAsset: 'assets/mock_avatars/camp_zhichang.jpg',
  ),
  PortenConversation(
    id: 309,
    isGroup: true,
    name: 'K歌之家营地',
    lastMessage: '周五晚上的歌单投票开始啦',
    minutesAgo: 60 * 24 * 3,
    unreadCount: 5,
    senderName: '符娟',
    memberCount: 18,
    avatarAsset: 'assets/mock_avatars/camp_kge.jpg',
  ),
  PortenConversation(
    id: 310,
    isGroup: false,
    name: '许清欢',
    lastMessage: '欢迎新加入的姐妹，先做个自我介绍吧～',
    minutesAgo: 60 * 24 * 4,
    unreadCount: 0,
    senderName: '许清欢',
    avatarAsset: 'assets/mock_avatars/friend_xu_qinghuan.jpg',
  ),
];

/// Porten 伙伴入口（对齐 partnerMock + mockAssistants 第一条）。
const String kPartnerName = 'Porten 伙伴';
const String kFirstAssistantName = 'Porten 小助手';
const int kPartnerUnread = 2;

/// 「我的旅程」入口卡片常量（对齐 TripAssistantCard）。
const int kTripMessageCount = 1;
const String kTripLastMessage = '您有一条在2天后前往大连的旅程';

/// 相对时间格式化（对齐 Web 端 formatMessageTime 的展示语义）。
String formatMessageTime(int minutesAgo) {
  if (minutesAgo < 1) return '刚刚';
  final DateTime now = DateTime.now();
  final DateTime time = now.subtract(Duration(minutes: minutesAgo));
  final bool sameDay =
      time.year == now.year && time.month == now.month && time.day == now.day;
  if (sameDay) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
  final DateTime yesterday = now.subtract(const Duration(days: 1));
  final bool isYesterday = time.year == yesterday.year &&
      time.month == yesterday.month &&
      time.day == yesterday.day;
  if (isYesterday) return '昨天';
  return '${time.month}月${time.day}日';
}
