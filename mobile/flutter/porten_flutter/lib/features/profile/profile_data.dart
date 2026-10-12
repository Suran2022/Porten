/*
 * 个人资料页 Mock 数据（对齐 Web 端 data/profileMock.ts）。
 *
 * 差异说明（Mock 离线策略）：r19 起背景图与头像改用项目本地资产
 * assets/mock_avatars/（背景 BBE77103 风景图），其余文案/数值保持一致。
 */

/// 本地资产路径（与 home_mock.dart 中 PortenCurrentUser 同源）。
class PortenProfileAssets {
  const PortenProfileAssets._();

  static const String avatarAsset = 'assets/mock_avatars/avatar_fuyue.jpg';
  static const String profileBgAsset =
      'assets/mock_avatars/profile_bg_fuyue.jpg';
}

/// Web 端 UserProfile + currentProfile + mySharePost（sharePosts[0]）。
class PortenProfileData {
  static const String nickname = '抚月';
  static const String portenId = '20240701';
  static const int friendCount = 128;
  static const String genderLabel = '跨性别女生';
  static const int transDays = 386;
  static const String moodLabel = '开心';
  static const String latestDiary =
      '今天和咨询师聊了很多，关于「被看见」这件事。也许真正的勇敢不是不害怕，而是即使害怕也选择站在光里。';

  // mySharePost = sharePosts[0]
  static const String shareContent =
      '今天终于鼓起勇气，向最好的几个朋友坦白了自己的身份。没想到她们第一时间抱住了我，说「你就是你，我们爱的就是那个你」。那一刻哭得停不下来，原来被接纳的感觉这么好。希望还在犹豫的姐妹们也能早日遇到愿意理解你们的人。';
  static const String shareCommentAuthor = '阿宁';
  static const String shareCommentContent = '替你开心！有这样的朋友真的太幸运了。';
  static const int shareViews = 1240;
  static const int shareComments = 38;
  static const int shareLikes = 156;
}

/// formatCount：>=10000 → w 保留 1 位；>=1000 → k 保留 1 位（对齐 Web）。
String portenFormatCount(int count) {
  if (count >= 10000) {
    return '${(count / 10000).toStringAsFixed(1)}w';
  }
  if (count >= 1000) {
    return '${(count / 1000).toStringAsFixed(1)}k';
  }
  return count.toString();
}

/// truncateText（对齐 Web MyShareCard.truncateText）。
String portenTruncate(String text, int maxLength) {
  if (text.length <= maxLength) return text;
  return '${text.substring(0, maxLength)}…';
}
