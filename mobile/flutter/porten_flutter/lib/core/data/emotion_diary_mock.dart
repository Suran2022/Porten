/*
 * 情绪日记 Mock 数据与本地引擎（100% 对齐 Web 端）：
 *   - types/emotionDiary.ts：MOOD_OPTIONS 10 项 / getMoodOption /
 *     isCisGender（cis_female|cis_male → 顺性别主题）；
 *   - data/mockServerData.ts：mockDiaries 2 条（id2 calm 3 天前 6 览 /
 *     id1 happy 20 小时前 12 览 is_current）+ mockDiaryViewers 3 人
 *     （小雨/Luna/苏苏，头像按项目资产就近映射）；
 *   - lib/mockEngine.ts 情绪日记路由语义：current 找 is_current；
 *     history 全量按 created_at 倒序；POST 先清空所有 is_current 再
 *     unshift 新日记（nextId 自增，初值 100000）；PATCH 更新当前
 *     日记并刷新 updated_at；DELETE 移除；viewers 固定返回 3 人；
 *     所有路由经 delay()（140~360ms 随机）模拟网络延迟。
 *
 * 头像差异说明（Mock 离线策略）：Web 用远端 avatar URL，App 改用
 * assets/mock_avatars/ 本地资产（xiaoyu/luna/susu 无对应资产，
 * 按昵称就近映射 friend_*.jpg）。
 */

import 'dart:math' as math;

/// 心情选项（Web MoodOption：左右结构 = emoji + label 水平排列）。
class MoodOption {
  const MoodOption(this.value, this.label, this.emoji);

  final String value;
  final String label;
  final String emoji;
}

/// Web 端 MOOD_OPTIONS（10 项，顺序逐项一致）。
const List<MoodOption> kMoodOptions = <MoodOption>[
  MoodOption('happy', '开心', '😊'),
  MoodOption('calm', '平静', '😌'),
  MoodOption('sad', '难过', '😢'),
  MoodOption('anxious', '焦虑', '😰'),
  MoodOption('angry', '愤怒', '😠'),
  MoodOption('tired', '疲惫', '😩'),
  MoodOption('grateful', '感恩', '🙏'),
  MoodOption('lonely', '孤独', '🥀'),
  MoodOption('hopeful', '充满希望', '🌅'),
  MoodOption('confused', '迷茫', '🌫️'),
];

/// getMoodOption：按 value 查找，找不到返回 null（Web 同款语义）。
MoodOption? moodOptionOf(String? value) {
  if (value == null) return null;
  for (final MoodOption option in kMoodOptions) {
    if (option.value == value) return option;
  }
  return null;
}

/// isCisGender：顺性别（男女）→ cis 主题；其余（跨性别/非二元）→
/// 跨性别主题（Web 同款判定）。
bool isCisGender(String? gender) {
  return gender == 'cis_female' || gender == 'cis_male';
}

/// 情绪日记（Web EmotionDiary 的 App 侧字段）。
///
/// 未迁移字段：mood_label（Web diaryToApi 里恒等于 mood 原值，UI 不
/// 读取）、author/is_mine（当前登录用户自己的日记，UI 不展示）、
/// viewed_at（ viewers 列表不展示）。
class EmotionDiary {
  EmotionDiary({
    required this.id,
    required this.content,
    required this.mood,
    required this.isPublic,
    required this.isCurrent,
    required this.viewCount,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  String content;
  String mood;
  bool isPublic;
  bool isCurrent;
  int viewCount;
  DateTime createdAt;
  DateTime updatedAt;

  /// diaryToApi 语义：返回新对象（Web 每次响应都是浅拷贝）。
  EmotionDiary copyWith() {
    return EmotionDiary(
      id: id,
      content: content,
      mood: mood,
      isPublic: isPublic,
      isCurrent: isCurrent,
      viewCount: viewCount,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

/// 情绪日记观众（Web EmotionDiaryViewer）。
class EmotionDiaryViewer {
  const EmotionDiaryViewer({
    required this.id,
    required this.userId,
    required this.nickname,
    required this.avatarAsset,
    required this.portenId,
  });

  final int id;
  final int userId;
  final String nickname;

  /// 本地头像资产（Web 为 avatar_url；离线策略改本地资产）。
  final String avatarAsset;
  final String portenId;
}

/// Web mockDiaries：模块级可变数组，初始 [id2, id1]（history 路由
/// 内部按 created_at 倒序，与数组序无关）。时间以调用时刻为基准
/// 向前推算（Web minutesAgo(60*24*3) / minutesAgo(60*20)）。
List<EmotionDiary> _buildInitialDiaries() {
  final DateTime threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));
  final DateTime twentyHoursAgo =
      DateTime.now().subtract(const Duration(hours: 20));
  return <EmotionDiary>[
    EmotionDiary(
      id: 2,
      content: '今天和咨询师聊了最近的状态，突然意识到自己已经很久没有好好照顾情绪了。晚上给自己煮了热汤，看了半部电影。慢慢来，都会好的。',
      mood: 'calm',
      isPublic: true,
      isCurrent: false,
      viewCount: 6,
      createdAt: threeDaysAgo,
      updatedAt: threeDaysAgo,
    ),
    EmotionDiary(
      id: 1,
      content: '今天阳光很好，坐在窗边写下这些的时候，突然觉得被世界温柔地接住了。愿我们都能慢慢长成自己喜欢的样子。',
      mood: 'happy',
      isPublic: true,
      isCurrent: true,
      viewCount: 12,
      createdAt: twentyHoursAgo,
      updatedAt: twentyHoursAgo,
    ),
  ];
}

final List<EmotionDiary> _diaries = _buildInitialDiaries();

/// 测试专用：把 mock 引擎重置回模块加载时的初始状态。
///
/// Web 端每次刷新页面都会重新加载 mockEngine（内存态清零），
/// widget 测试的每个用例等价于一次全新页面加载，需要同等的
/// 状态隔离（否则前一个用例的删除/创建会污染后续用例）。
/// 仅测试代码调用，产品代码不引用。
void mockResetDiaries() {
  _diaries
    ..clear()
    ..addAll(_buildInitialDiaries());
  _nextDiaryId = 100000;
}

/// Web mockEngine nextId 初值（POST 新日记 id 从 100000 起）。
int _nextDiaryId = 100000;

/// Web mockDiaryViewers（3 人；viewers 路由固定返回，不随日记变化）。
const List<EmotionDiaryViewer> kMockDiaryViewers = <EmotionDiaryViewer>[
  EmotionDiaryViewer(
    id: 1,
    userId: 1003,
    nickname: '小雨',
    avatarAsset: 'assets/mock_avatars/friend_gu_xiaomeng.jpg',
    portenId: '107892',
  ),
  EmotionDiaryViewer(
    id: 2,
    userId: 1014,
    nickname: 'Luna',
    avatarAsset: 'assets/mock_avatars/friend_lin_wanqing.jpg',
    portenId: '126752',
  ),
  EmotionDiaryViewer(
    id: 3,
    userId: 1004,
    nickname: '苏苏',
    avatarAsset: 'assets/mock_avatars/friend_su_nian.jpg',
    portenId: '105671',
  ),
];

/// Web mockEngine.delay()：140 + random*220 ms。
Future<void> mockDiaryDelay() {
  return Future<void>.delayed(
    Duration(milliseconds: 140 + math.Random().nextInt(221)),
  );
}

/// GET /emotion-diaries/current：找 is_current，无则 null。
Future<EmotionDiary?> mockFetchCurrentDiary() async {
  await mockDiaryDelay();
  for (final EmotionDiary diary in _diaries) {
    if (diary.isCurrent) return diary.copyWith();
  }
  return null;
}

/// GET /emotion-diaries/history：全量按 created_at 倒序。
///
/// [cursor] 对应 Web fetchEmotionDiaryHistory(cursor) 的游标；
/// mock 引擎忽略游标返回全量（Web 同款语义），参数保留以对齐
/// 调用方 loadHistory 的传参形状。
Future<List<EmotionDiary>> mockFetchDiaryHistory([int? cursor]) async {
  await mockDiaryDelay();
  final List<EmotionDiary> items = List<EmotionDiary>.of(_diaries)
    ..sort((EmotionDiary a, EmotionDiary b) =>
        b.createdAt.compareTo(a.createdAt));
  return items;
}

/// POST /emotion-diaries：先清空所有 is_current，再 unshift 新日记
/// （is_current=true、view_count=0、created/updated 为当前时间）。
Future<EmotionDiary> mockCreateDiary({
  required String content,
  required String mood,
  bool isPublic = true,
}) async {
  await mockDiaryDelay();
  for (final EmotionDiary diary in _diaries) {
    diary.isCurrent = false;
  }
  final DateTime now = DateTime.now();
  final EmotionDiary diary = EmotionDiary(
    id: _nextDiaryId++,
    content: content,
    mood: mood,
    isPublic: isPublic,
    isCurrent: true,
    viewCount: 0,
    createdAt: now,
    updatedAt: now,
  );
  _diaries.insert(0, diary);
  return diary.copyWith();
}

/// PATCH /emotion-diaries/current：更新当前日记并刷新 updated_at；
/// 无当前日记时抛错（Web `throw new Error("no current diary")`）。
Future<EmotionDiary> mockUpdateCurrentDiary({
  required String content,
  required String mood,
  required bool isPublic,
}) async {
  await mockDiaryDelay();
  for (final EmotionDiary diary in _diaries) {
    if (diary.isCurrent) {
      diary.content = content;
      diary.mood = mood;
      diary.isPublic = isPublic;
      diary.updatedAt = DateTime.now();
      return diary.copyWith();
    }
  }
  throw Exception('no current diary');
}

/// DELETE /emotion-diaries/{id}：移除对应日记。
Future<void> mockDeleteDiary(int id) async {
  await mockDiaryDelay();
  _diaries.removeWhere((EmotionDiary diary) => diary.id == id);
}

/// GET /emotion-diaries/{id}/viewers：固定返回 3 人。
Future<List<EmotionDiaryViewer>> mockFetchDiaryViewers() async {
  await mockDiaryDelay();
  return List<EmotionDiaryViewer>.of(kMockDiaryViewers);
}

/// formatTime（Web EmotionDiaryPage / EmotionHistoryPage 同款）：
/// 当天 → 「今天 HH:mm」，其余 → 「yyyy-MM-dd HH:mm」。
String formatDiaryTime(DateTime date) {
  final DateTime now = DateTime.now();
  final bool sameDay = date.year == now.year &&
      date.month == now.month &&
      date.day == now.day;
  final String hh = date.hour.toString().padLeft(2, '0');
  final String mm = date.minute.toString().padLeft(2, '0');
  if (sameDay) return '今天 $hh:$mm';
  final String yyyy = date.year.toString();
  final String month = date.month.toString().padLeft(2, '0');
  final String day = date.day.toString().padLeft(2, '0');
  return '$yyyy-$month-$day $hh:$mm';
}
