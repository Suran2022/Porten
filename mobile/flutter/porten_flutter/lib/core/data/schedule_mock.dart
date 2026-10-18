/*
 * 我的日程 Mock 数据（100% 对齐 Web 端 data/mockServerData.ts 日程段 +
 * data/holidays.ts + lib/mockEngine.ts 的 /schedules 系列接口）。
 *
 * 与 Web 一致：
 *   - mockSchedules 6 条，日期相对今天动态生成（-3 ~ +9 天），
 *     保证任意时间打开页面都有日程演示；
 *   - 关联候选：可关联旅程 3 条 / 可关联约定 3 条；
 *   - 参与同胞候选 4 人（Web 用 dicebear 远程头像，App 侧按离线策略
 *     改用 assets/mock_avatars/ 本地资产）；
 *   - 创建时随机分配 pink / coffee / blue 三色之一（同 Web mockEngine）；
 *   - 节假日表内置 2025~2027 主要节日（日期条节日名展示用）。
 */

import 'dart:math';

/// 日程卡片配色（创建时随机三选一）。
enum ScheduleColor { pink, coffee, blue }

/// 配色池（mock 引擎随机分配用，同 Web SCHEDULE_COLOR_POOL）。
const List<ScheduleColor> kScheduleColorPool = <ScheduleColor>[
  ScheduleColor.pink,
  ScheduleColor.coffee,
  ScheduleColor.blue,
];

/// 日程分类。
enum ScheduleCategory {
  travel,
  date,
  visit,
  work,
  daily,
  study,
  other,
}

/// 日程分类选项（值 + 中文标签，同 Web SCHEDULE_CATEGORIES）。
const List<(ScheduleCategory, String)> kScheduleCategories =
    <(ScheduleCategory, String)>[
  (ScheduleCategory.travel, '旅行'),
  (ScheduleCategory.date, '约会'),
  (ScheduleCategory.visit, '就诊'),
  (ScheduleCategory.work, '工作'),
  (ScheduleCategory.daily, '日常'),
  (ScheduleCategory.study, '学习'),
  (ScheduleCategory.other, '其他'),
];

/// 关联对象类型：旅行分类关联旅程 / 约会分类关联约定。
enum ScheduleRelatedType { trip, agreement }

/// 日程创建来源：完整表单 / 时间线快捷创建。
enum ScheduleSource { form, quick }

/// 日程条目（字段与 Web ScheduleItem 一致）。
class ScheduleItem {
  const ScheduleItem({
    required this.id,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.title,
    required this.detail,
    required this.category,
    required this.relatedType,
    required this.relatedId,
    required this.place,
    required this.participantIds,
    required this.color,
    required this.source,
  });

  final int id;

  /// 日程日期，格式 YYYY-MM-DD
  final String date;

  /// 开始时间，格式 HH:mm
  final String startTime;

  /// 结束时间，格式 HH:mm；选填
  final String? endTime;

  /// 日程标题，选填
  final String? title;

  /// 日程详情，选填
  final String? detail;

  /// 日程分类，选填
  final ScheduleCategory? category;

  /// 关联对象类型，选填
  final ScheduleRelatedType? relatedType;

  /// 关联对象 id，选填
  final int? relatedId;

  /// 地点，选填
  final String? place;

  /// 参与同胞的用户 id 列表
  final List<int> participantIds;

  /// 卡片配色（创建时随机分配）
  final ScheduleColor color;

  /// 创建来源
  final ScheduleSource source;

  ScheduleItem copyWith({
    int? id,
    String? date,
    String? startTime,
    String? endTime,
    String? title,
    String? detail,
    ScheduleCategory? category,
    ScheduleRelatedType? relatedType,
    int? relatedId,
    String? place,
    List<int>? participantIds,
    ScheduleColor? color,
    ScheduleSource? source,
  }) {
    return ScheduleItem(
      id: id ?? this.id,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      title: title ?? this.title,
      detail: detail ?? this.detail,
      category: category ?? this.category,
      relatedType: relatedType ?? this.relatedType,
      relatedId: relatedId ?? this.relatedId,
      place: place ?? this.place,
      participantIds: participantIds ?? this.participantIds,
      color: color ?? this.color,
      source: source ?? this.source,
    );
  }
}

/// 关联选择项（旅程/约定）。
class ScheduleRelatedItem {
  const ScheduleRelatedItem({required this.id, required this.label});

  final int id;
  final String label;
}

/// 参与同胞候选。
class ScheduleComrade {
  const ScheduleComrade({
    required this.id,
    required this.nickname,
    required this.avatarAsset,
  });

  final int id;
  final String nickname;

  /// 本地头像资产（Web 为 dicebear 远程 URL，App 离线策略改本地）。
  final String avatarAsset;
}

/// 生成相对今天偏移 n 天的 YYYY-MM-DD 日期串（同 Web dateKeyFromToday）。
String dateKeyFromToday(int dayOffset) {
  final DateTime now = DateTime.now();
  final DateTime d = DateTime(now.year, now.month, now.day + dayOffset);
  final String m = d.month.toString().padLeft(2, '0');
  final String day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

/// mock 日程数据：日期相对今天动态生成。
final List<ScheduleItem> kMockSchedules = <ScheduleItem>[
  ScheduleItem(
    id: 1,
    date: dateKeyFromToday(0),
    startTime: '14:00',
    endTime: '15:30',
    title: '下午茶之约',
    detail: '和老朋友约在常去的那家店，聊聊最近的状态。',
    category: ScheduleCategory.date,
    relatedType: ScheduleRelatedType.agreement,
    relatedId: 1,
    place: '甜遇·社区茶店',
    participantIds: const <int>[1003],
    color: ScheduleColor.pink,
    source: ScheduleSource.form,
  ),
  ScheduleItem(
    id: 2,
    date: dateKeyFromToday(0),
    startTime: '19:00',
    endTime: null,
    title: null,
    detail: '沿着江边慢跑，顺便试试新买的运动手环。',
    category: ScheduleCategory.daily,
    relatedType: null,
    relatedId: null,
    place: null,
    participantIds: const <int>[],
    color: ScheduleColor.blue,
    source: ScheduleSource.quick,
  ),
  ScheduleItem(
    id: 3,
    date: dateKeyFromToday(2),
    startTime: '09:30',
    endTime: '10:30',
    title: '心理咨询',
    detail: null,
    category: ScheduleCategory.visit,
    relatedType: null,
    relatedId: null,
    place: '北岸心理诊所',
    participantIds: const <int>[],
    color: ScheduleColor.coffee,
    source: ScheduleSource.form,
  ),
  ScheduleItem(
    id: 4,
    date: dateKeyFromToday(5),
    startTime: '18:30',
    endTime: '21:00',
    title: '和同胞看电影',
    detail: '一起看新上映的音乐纪录片，散场后吃宵夜。',
    category: ScheduleCategory.date,
    relatedType: null,
    relatedId: null,
    place: '城南光影影城',
    participantIds: const <int>[1014, 1005],
    color: ScheduleColor.pink,
    source: ScheduleSource.form,
  ),
  ScheduleItem(
    id: 5,
    date: dateKeyFromToday(9),
    startTime: '10:00',
    endTime: '11:00',
    title: '激素复查',
    detail: '记得空腹，带上上次的检查单。',
    category: ScheduleCategory.visit,
    relatedType: null,
    relatedId: null,
    place: '市第三人民医院',
    participantIds: const <int>[],
    color: ScheduleColor.coffee,
    source: ScheduleSource.form,
  ),
  ScheduleItem(
    id: 6,
    date: dateKeyFromToday(-3),
    startTime: '20:00',
    endTime: '21:30',
    title: '小组分享会',
    detail: null,
    category: ScheduleCategory.other,
    relatedType: null,
    relatedId: null,
    place: null,
    participantIds: const <int>[],
    color: ScheduleColor.blue,
    source: ScheduleSource.form,
  ),
];

/// 可关联旅程（mock）：对应加号菜单「创建旅程」产生的旅程。
const List<ScheduleRelatedItem> kMockTrips = <ScheduleRelatedItem>[
  ScheduleRelatedItem(id: 1, label: '上海 → 北京 · 10月12日'),
  ScheduleRelatedItem(id: 2, label: '广州 → 成都 · 11月3日'),
  ScheduleRelatedItem(id: 3, label: '杭州 → 厦门 · 12月20日'),
];

/// 可关联约定（mock）：对应加号菜单「创建约定」产生的约定项。
const List<ScheduleRelatedItem> kMockAgreements = <ScheduleRelatedItem>[
  ScheduleRelatedItem(id: 1, label: '每周三线上互助会'),
  ScheduleRelatedItem(id: 2, label: '一起坚持晨间记录 21 天'),
  ScheduleRelatedItem(id: 3, label: '月末同城聚会筹备'),
];

/// 可参与同胞候选（mock；头像为本地资产）。
const List<ScheduleComrade> kMockComrades = <ScheduleComrade>[
  ScheduleComrade(
    id: 1003,
    nickname: '小雨',
    avatarAsset: 'assets/mock_avatars/friend_lin_wanqing.jpg',
  ),
  ScheduleComrade(
    id: 1005,
    nickname: '陈默',
    avatarAsset: 'assets/mock_avatars/friend_chen_yutong.jpg',
  ),
  ScheduleComrade(
    id: 1011,
    nickname: '领队',
    avatarAsset: 'assets/mock_avatars/friend_fu_juan.jpg',
  ),
  ScheduleComrade(
    id: 1014,
    nickname: 'Luna',
    avatarAsset: 'assets/mock_avatars/friend_zhou_shihan.jpg',
  ),
];

/// 节假日数据：内置 2025~2027 主要节日映射（YYYY-MM-DD → 节日名）。
/// 同日多节重叠时以表中后写入者为准（如 2025-10-06 中秋覆盖国庆）。
const Map<String, String> kHolidays = <String, String>{
  // ---- 2025 ----
  '2025-01-01': '元旦',
  '2025-01-28': '除夕',
  '2025-01-29': '春节',
  '2025-01-30': '春节',
  '2025-01-31': '春节',
  '2025-02-01': '春节',
  '2025-02-02': '春节',
  '2025-02-03': '春节',
  '2025-02-12': '元宵',
  '2025-04-04': '清明',
  '2025-05-01': '劳动节',
  '2025-05-02': '劳动节',
  '2025-05-03': '劳动节',
  '2025-05-04': '劳动节',
  '2025-05-05': '劳动节',
  '2025-05-31': '端午',
  '2025-08-29': '七夕',
  '2025-10-01': '国庆',
  '2025-10-02': '国庆',
  '2025-10-03': '国庆',
  '2025-10-04': '国庆',
  '2025-10-05': '国庆',
  '2025-10-06': '中秋',
  '2025-10-07': '国庆',

  // ---- 2026 ----
  '2026-01-01': '元旦',
  '2026-02-16': '除夕',
  '2026-02-17': '春节',
  '2026-02-18': '春节',
  '2026-02-19': '春节',
  '2026-02-20': '春节',
  '2026-02-21': '春节',
  '2026-02-22': '春节',
  '2026-03-03': '元宵',
  '2026-04-05': '清明',
  '2026-05-01': '劳动节',
  '2026-05-02': '劳动节',
  '2026-05-03': '劳动节',
  '2026-05-04': '劳动节',
  '2026-05-05': '劳动节',
  '2026-06-19': '端午',
  '2026-08-19': '七夕',
  '2026-09-25': '中秋',
  '2026-10-01': '国庆',
  '2026-10-02': '国庆',
  '2026-10-03': '国庆',
  '2026-10-04': '国庆',
  '2026-10-05': '国庆',
  '2026-10-06': '国庆',
  '2026-10-07': '国庆',

  // ---- 2027 ----
  '2027-01-01': '元旦',
  '2027-02-05': '除夕',
  '2027-02-06': '春节',
  '2027-02-07': '春节',
  '2027-02-08': '春节',
  '2027-02-09': '春节',
  '2027-02-10': '春节',
  '2027-02-11': '春节',
  '2027-02-20': '元宵',
  '2027-04-05': '清明',
  '2027-05-01': '劳动节',
  '2027-05-02': '劳动节',
  '2027-05-03': '劳动节',
  '2027-05-04': '劳动节',
  '2027-05-05': '劳动节',
  '2027-06-09': '端午',
  '2027-08-08': '七夕',
  '2027-09-15': '中秋',
  '2027-10-01': '国庆',
  '2027-10-02': '国庆',
  '2027-10-03': '国庆',
  '2027-10-04': '国庆',
  '2027-10-05': '国庆',
  '2027-10-06': '国庆',
  '2027-10-07': '国庆',
};

/// 返回指定日期（YYYY-MM-DD）的节日名，非节日返回 null。
String? getHolidayName(String dateKey) => kHolidays[dateKey];

/// 日程内存存储（对齐 Web mockEngine 的 /schedules 系列接口行为）：
/// GET 返回当前列表；POST 随机配色追加并返回新条目；
/// PATCH 按 id 就地更新（仅更新传入字段）。
class ScheduleStore {
  ScheduleStore._();

  static final List<ScheduleItem> _items = List<ScheduleItem>.of(kMockSchedules);
  static int _nextId = 7;
  static final Random _random = Random();

  /// 当前全部日程（返回副本，避免外部直接改内部列表）。
  static List<ScheduleItem> get items => List<ScheduleItem>.of(_items);

  /// 创建日程：随机三色之一，追加进列表。
  static ScheduleItem create(ScheduleItem draft) {
    final ScheduleItem item = draft.copyWith(
      id: _nextId++,
      color: kScheduleColorPool[_random.nextInt(kScheduleColorPool.length)],
    );
    _items.add(item);
    return item;
  }

  /// 仅更新结束时间（卡片拖拽手柄的局部 PATCH，同 Web 行为）。
  static ScheduleItem updateEndTime(int id, String endTime) {
    final int index = _items.indexWhere((ScheduleItem it) => it.id == id);
    if (index < 0) {
      throw StateError('schedule not found');
    }
    final ScheduleItem updated = _items[index].copyWith(endTime: endTime);
    _items[index] = updated;
    return updated;
  }

  /// 更新日程：显式传入的字段整体覆盖（含置空，同 Web PATCH 的
  /// 「字段存在即覆盖」语义；编辑表单总是提交全量状态）。
  static ScheduleItem update(int id, ScheduleItem draft) {
    final int index = _items.indexWhere((ScheduleItem it) => it.id == id);
    if (index < 0) {
      throw StateError('schedule not found');
    }
    final ScheduleItem updated = ScheduleItem(
      id: id,
      date: draft.date,
      startTime: draft.startTime,
      endTime: draft.endTime,
      title: draft.title,
      detail: draft.detail,
      category: draft.category,
      relatedType: draft.relatedType,
      relatedId: draft.relatedId,
      place: draft.place,
      participantIds: draft.participantIds,
      color: _items[index].color,
      source: _items[index].source,
    );
    _items[index] = updated;
    return updated;
  }
}

// ------------------------------------------------------------ API 序列化
//
// 字段硬约束（与后端 /api/v1/schedules 系列、Kotlin 侧 ScheduleItem 逐字段
// 对齐，一个不多一个不少）：id/date/start_time/end_time/title/detail/
// category/related_type/related_id/place/participant_ids/color/source。
// JSON 为 snake_case；枚举以 name 传输（travel/date/visit/work/daily/
// study/other、trip/agreement、pink/coffee/blue、form/quick）。

/// 按 name 匹配枚举；未知值返回 null（防御：后端新增分类时端上不崩）。
ScheduleCategory? parseScheduleCategory(String? raw) {
  if (raw == null) return null;
  for (final ScheduleCategory value in ScheduleCategory.values) {
    if (value.name == raw) return value;
  }
  return null;
}

/// 按 name 匹配关联类型。
ScheduleRelatedType? parseScheduleRelatedType(String? raw) {
  if (raw == null) return null;
  for (final ScheduleRelatedType value in ScheduleRelatedType.values) {
    if (value.name == raw) return value;
  }
  return null;
}

/// 按 name 匹配配色；未知值回退 pink（防御：与后端默认色一致）。
ScheduleColor parseScheduleColor(String? raw) {
  if (raw == null) return ScheduleColor.pink;
  for (final ScheduleColor value in ScheduleColor.values) {
    if (value.name == raw) return value;
  }
  return ScheduleColor.pink;
}

/// 按 name 匹配创建来源；未知值回退 form。
ScheduleSource parseScheduleSource(String? raw) {
  if (raw == null) return ScheduleSource.form;
  for (final ScheduleSource value in ScheduleSource.values) {
    if (value.name == raw) return value;
  }
  return ScheduleSource.form;
}

/// 关联候选集合（对齐后端 GET /schedules/related 的 data 段）。
class ScheduleRelatedData {
  const ScheduleRelatedData({
    this.trips = const <ScheduleRelatedItem>[],
    this.agreements = const <ScheduleRelatedItem>[],
    this.comrades = const <ScheduleComrade>[],
  });

  /// 可关联旅程（旅行分类）。
  final List<ScheduleRelatedItem> trips;

  /// 可关联约定（约会分类）。
  final List<ScheduleRelatedItem> agreements;

  /// 可参与同胞候选。
  final List<ScheduleComrade> comrades;
}

/// 业务数据桥返回 JSON → [ScheduleItem]（字段与 mock 模型一一对应）。
ScheduleItem scheduleItemFromApi(Map<String, dynamic> json) {
  return ScheduleItem(
    id: (json['id'] as num).toInt(),
    date: json['date'] as String,
    startTime: json['start_time'] as String,
    endTime: json['end_time'] as String?,
    title: json['title'] as String?,
    detail: json['detail'] as String?,
    category: parseScheduleCategory(json['category'] as String?),
    relatedType: parseScheduleRelatedType(json['related_type'] as String?),
    relatedId: (json['related_id'] as num?)?.toInt(),
    place: json['place'] as String?,
    participantIds: (json['participant_ids'] as List<dynamic>?)
            ?.map((dynamic e) => (e as num).toInt())
            .toList() ??
        const <int>[],
    color: parseScheduleColor(json['color'] as String?),
    source: parseScheduleSource(json['source'] as String?),
  );
}

/// 业务数据桥返回 JSON → [ScheduleRelatedItem]。
ScheduleRelatedItem scheduleRelatedItemFromApi(Map<String, dynamic> json) {
  return ScheduleRelatedItem(
    id: (json['id'] as num).toInt(),
    label: json['label'] as String,
  );
}

/// 业务数据桥返回 JSON → [ScheduleComrade]（桥侧字段为 avatar）。
ScheduleComrade scheduleComradeFromApi(Map<String, dynamic> json) {
  return ScheduleComrade(
    id: (json['id'] as num).toInt(),
    nickname: json['nickname'] as String,
    avatarAsset: json['avatar'] as String? ?? '',
  );
}

/// 业务数据桥返回 JSON → [ScheduleRelatedData]。
ScheduleRelatedData scheduleRelatedDataFromApi(Map<String, dynamic> json) {
  return ScheduleRelatedData(
    trips: (json['trips'] as List<dynamic>?)
            ?.map((dynamic e) =>
                scheduleRelatedItemFromApi(e as Map<String, dynamic>))
            .toList() ??
        const <ScheduleRelatedItem>[],
    agreements: (json['agreements'] as List<dynamic>?)
            ?.map((dynamic e) =>
                scheduleRelatedItemFromApi(e as Map<String, dynamic>))
            .toList() ??
        const <ScheduleRelatedItem>[],
    comrades: (json['comrades'] as List<dynamic>?)
            ?.map((dynamic e) => scheduleComradeFromApi(e as Map<String, dynamic>))
            .toList() ??
        const <ScheduleComrade>[],
  );
}

/// 创建载荷（POST /schedules 的 payload，snake_case；不含 id/color——
/// id 服务端分配，color 服务端随机分配）。
Map<String, Object?> scheduleCreatePayloadOf(ScheduleItem item) {
  return <String, Object?>{
    'date': item.date,
    'start_time': item.startTime,
    'end_time': item.endTime,
    'title': item.title,
    'detail': item.detail,
    'category': item.category?.name,
    'related_type': item.relatedType?.name,
    'related_id': item.relatedId,
    'place': item.place,
    'participant_ids': item.participantIds,
    'source': item.source.name,
  };
}

/// 更新载荷（PATCH /schedules/{id} 的 payload，snake_case）。
///
/// 编辑表单总是提交全量状态（含置空字段），与 Dart mock 的
/// 「字段存在即覆盖」语义一致；不含 id/color（颜色创建时定，不可改）。
Map<String, Object?> scheduleUpdatePayloadOf(ScheduleItem item) {
  return scheduleCreatePayloadOf(item);
}
