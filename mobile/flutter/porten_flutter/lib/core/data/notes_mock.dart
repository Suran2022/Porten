/*
 * 记笔记页 Mock 数据（100% 对齐 Web 端 components/home/NotesPage.tsx）。
 *
 * - MOCK_NOTES 11 条逐条一致（id/content/time/tags）；
 * - TAG_STYLES 6 色（bg-*-100/80 底 + text-*-700 字，Tailwind v3 精确色值）；
 * - tagStyle：charCode 求和 % 6（JS charCodeAt 与 Dart codeUnits 同语义）；
 * - currentTimeLabel：「今天 HH:mm」（2 位 24 小时制）。
 */

import 'package:flutter/material.dart';

/// 笔记条目（对齐 Web 端 NoteItem）。
class NoteItem {
  const NoteItem({
    required this.id,
    required this.content,
    required this.time,
    required this.tags,
    this.archived = false,
  });

  final int id;
  final String content;
  final String time;
  final List<String> tags;
  final bool archived;

  NoteItem copyWith({
    int? id,
    String? content,
    String? time,
    List<String>? tags,
    bool? archived,
  }) {
    return NoteItem(
      id: id ?? this.id,
      content: content ?? this.content,
      time: time ?? this.time,
      tags: tags ?? this.tags,
      archived: archived ?? this.archived,
    );
  }
}

/// Web 端 MOCK_NOTES（11 条，逐条一致）。
const List<NoteItem> kMockNotes = <NoteItem>[
  NoteItem(
    id: 1,
    content: '今天把消息列表的交互流程重新梳理了一遍。优先让核心路径保持简单，再逐步补充细节和反馈。',
    time: '今天 10:24',
    tags: <String>['工作', '灵感'],
  ),
  NoteItem(
    id: 2,
    content: '周末想去城南的植物园走走，带上相机，顺便记录春天刚长出来的新叶和傍晚的光。',
    time: '昨天 21:16',
    tags: <String>['生活', '计划'],
  ),
  NoteItem(
    id: 3,
    content: '产品细节：动画不只是装饰，它应该帮助用户理解页面之间的空间关系，进入和退出必须保持方向一致。',
    time: '7月30日 16:08',
    tags: <String>['设计', '产品'],
  ),
  NoteItem(
    id: 4,
    content: '最近循环播放的歌单很适合夜晚写东西。舒缓的节奏能让思绪慢下来，也更容易专注。',
    time: '7月28日 23:42',
    tags: <String>['音乐', '日常'],
  ),
  NoteItem(
    id: 5,
    content: '下次社区分享会可以讨论如何建立更安全的表达空间，让每个人都能被认真倾听和温柔回应。',
    time: '7月26日 14:30',
    tags: <String>['社区', '想法'],
  ),
  NoteItem(
    id: 6,
    content: '阅读摘录：真正的勇敢并不是从不害怕，而是在理解自己的害怕之后，仍然愿意向前走一步。',
    time: '7月24日 09:12',
    tags: <String>['阅读', '摘录'],
  ),
  NoteItem(
    id: 7,
    content: '体检需要准备的材料：身份证、预约单、既往检查报告。提前半小时出门，避免早高峰。',
    time: '7月22日 18:05',
    tags: <String>['健康', '待办'],
  ),
  NoteItem(
    id: 8,
    content: '新功能的颜色尽量降低饱和度，蓝色与粉色不要直接硬切，用更大的渐变半径自然融入白色背景。',
    time: '7月20日 11:47',
    tags: <String>['设计', '灵感'],
  ),
  NoteItem(
    id: 9,
    content: '给未来的自己：不需要急着证明什么，按照自己的节奏生活，每一次认真选择都算数。',
    time: '7月18日 22:19',
    tags: <String>['心情', '给自己'],
  ),
  NoteItem(
    id: 10,
    content: '会议记录：先完成移动端消息体验，再统一桌面端布局；测试阶段重点关注弱网和离线状态。',
    time: '7月16日 15:36',
    tags: <String>['工作', '会议'],
  ),
  NoteItem(
    id: 11,
    content: '想学着做一道简单的番茄炖牛腩，少放一点糖，最后加几颗烤过的小番茄增加香气。',
    time: '7月14日 12:04',
    tags: <String>['生活', '美食'],
  ),
];

/// 标签配色（Web 端 TAG_STYLES：bg-*-100/80 底 + text-*-700 字）。
class NoteTagStyle {
  const NoteTagStyle(this.background, this.foreground);

  /// 背景色（/80 透明度已折算：0xCC 前缀）。
  final Color background;

  /// 文字色。
  final Color foreground;
}

const List<NoteTagStyle> kNoteTagStyles = <NoteTagStyle>[
  NoteTagStyle(Color(0xCCE0F2FE), Color(0xFF0369A1)), // sky-100/80 + sky-700
  NoteTagStyle(Color(0xCCFCE7F3), Color(0xFFBE185D)), // pink-100/80 + pink-700
  NoteTagStyle(Color(0xCCEDE9FE), Color(0xFF6D28D9)), // violet-100/80 + violet-700
  NoteTagStyle(Color(0xCCFEF3C7), Color(0xFFB45309)), // amber-100/80 + amber-700
  NoteTagStyle(Color(0xCCD1FAE5), Color(0xFF047857)), // emerald-100/80 + emerald-700
  NoteTagStyle(Color(0xCCE0E7FF), Color(0xFF4338CA)), // indigo-100/80 + indigo-700
];

/// tagStyle：charCode 求和 % 6（与 Web 端一致）。
NoteTagStyle noteTagStyleOf(String tag) {
  int hash = 0;
  for (final int codeUnit in tag.codeUnits) {
    hash += codeUnit;
  }
  return kNoteTagStyles[hash % kNoteTagStyles.length];
}

/// currentTimeLabel：「今天 HH:mm」（2 位 24 小时制，对齐 Web）。
String notesCurrentTimeLabel([DateTime? now]) {
  final DateTime date = now ?? DateTime.now();
  final String hh = date.hour.toString().padLeft(2, '0');
  final String mm = date.minute.toString().padLeft(2, '0');
  return '今天 $hh:$mm';
}

/// saveNote 的标签分割：按 、 , ， 与空白切分（对齐 Web /[、,，\s]+/），
/// 过滤空串并最多取 4 个。
/// [fallback] 为 true 时为空回退 ["随记"]——仅 Web 端新建分支有此回退，
/// 编辑分支允许清空标签（与 Web 行为逐分支一致）。
List<String> parseNoteTags(String draftTags, {bool fallback = false}) {
  final List<String> tags = draftTags
      .split(RegExp(r'[、,，\s]+'))
      .map((String tag) => tag.trim())
      .where((String tag) => tag.isNotEmpty)
      .take(4)
      .toList();
  if (fallback && tags.isEmpty) return <String>['随记'];
  return tags;
}

// ------------------------------------------------------------ API 序列化
//
// 字段硬约束（与后端 /api/v1/notes 系列、Kotlin 侧 NoteItem 逐字段对齐，
// 一个不多一个不少）：id/content/time/tags/archived。
// time 为服务端派生的展示标签（今天 / 昨天 / M月D日 HH:mm），端上不解析。

/// 业务数据桥返回 JSON → [NoteItem]。
NoteItem noteItemFromApi(Map<String, dynamic> json) {
  return NoteItem(
    id: (json['id'] as num).toInt(),
    content: json['content'] as String,
    time: json['time'] as String,
    tags: (json['tags'] as List<dynamic>?)
            ?.map((dynamic e) => e as String)
            .toList() ??
        const <String>[],
    archived: json['archived'] as bool? ?? false,
  );
}

/// 创建 / 更新载荷（POST/PATCH /notes 的 payload，PATCH 语义：
/// 仅传入字段覆盖，null 表示不修改；标签为空数组即清空）。
Map<String, Object?> noteUpsertPayloadOf({
  String? content,
  List<String>? tags,
  bool? archived,
}) {
  return <String, Object?>{
    'content': ?content,
    'tags': ?tags,
    'archived': ?archived,
  };
}

/// 笔记内存存储（对齐 Kotlin NoteMockEngine 与 Web 端笔记交互）：
/// GET 返回当前列表；POST 新建回退「随记」并 unshift；
/// PATCH 按 id 就地更新（仅传入字段，含清空标签）；
/// 删除按 id 移除。
class NoteStore {
  NoteStore._();

  static final List<NoteItem> _items = List<NoteItem>.of(kMockNotes);
  static int _nextId = 12;

  /// 当前全部笔记（返回副本，新到旧）。
  static List<NoteItem> get items => List<NoteItem>.of(_items);

  /// 新建：标签切分（空则回退「随记」）后插入列表头部。
  static NoteItem create({
    required String content,
    required String tagsText,
  }) {
    final NoteItem item = NoteItem(
      id: _nextId++,
      content: content,
      time: noteTimeLabelNow(),
      tags: parseNoteTags(tagsText, fallback: true),
    );
    _items.insert(0, item);
    return item;
  }

  /// 更新：显式传入的字段覆盖（[tagsText] 为 null 表示不改标签；
  /// 编辑分支允许清空标签，与 Web 行为一致）。
  static NoteItem update(
    int id, {
    String? content,
    String? tagsText,
    bool? archived,
  }) {
    final int index = _items.indexWhere((NoteItem it) => it.id == id);
    if (index < 0) {
      throw StateError('note not found');
    }
    final NoteItem current = _items[index];
    final NoteItem updated = NoteItem(
      id: id,
      content: content ?? current.content,
      time: noteTimeLabelNow(),
      tags: tagsText != null ? parseNoteTags(tagsText) : current.tags,
      archived: archived ?? current.archived,
    );
    _items[index] = updated;
    return updated;
  }

  /// 删除。
  static void delete(int id) {
    _items.removeWhere((NoteItem it) => it.id == id);
  }

  /// 重置为初始种子（仅测试使用：mock Store 为进程内单例，
  /// 写操作跨测试用例泄漏，需在用例前复位）。
  @visibleForTesting
  static void resetForTest() {
    _items
      ..clear()
      ..addAll(kMockNotes);
    _nextId = 12;
  }
}

/// 当前时刻的笔记时间标签：今天 HH:mm / 昨天 HH:mm / M月D日 HH:mm
/// （对齐 Kotlin NoteMockEngine.currentTimeLabel）。
String noteTimeLabelNow([DateTime? now]) {
  final DateTime date = now ?? DateTime.now();
  final String hm =
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  final DateTime today = DateTime(date.year, date.month, date.day);
  final DateTime yesterday = today.subtract(const Duration(days: 1));
  final DateTime day = DateTime(date.year, date.month, date.day);
  if (day == today) return '今天 $hm';
  if (day == yesterday) return '昨天 $hm';
  return '${date.month}月${date.day}日 $hm';
}
