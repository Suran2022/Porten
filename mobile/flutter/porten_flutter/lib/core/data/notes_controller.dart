/*
 * 记笔记控制器（Mock / Live 一键切换的分发点，对齐 Kotlin 侧
 * NoteRepository 的双通道语义）。
 *
 * 职责：
 *   1. 拉取笔记列表，按 mockModeProvider 分流：mock → 端内 NoteStore；
 *      live → porten/data 桥；
 *   2. 新建（空标签回退「随记」）/ 编辑（允许清空标签）/ 归档翻转 /
 *      删除；PATCH 语义仅传入字段覆盖；
 *   3. Live 通道异常不静默回退 Mock，经 AsyncValue.error 向上抛。
 */

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bridge/porten_data_bridge.dart';
import '../mock/mock_mode.dart';
import 'notes_mock.dart';

/// 笔记看板数据。
class NoteBoardData {
  const NoteBoardData({required this.items});

  /// 笔记列表（新到旧）。
  final List<NoteItem> items;

  static const NoteBoardData empty = NoteBoardData(items: <NoteItem>[]);

  /// 从桥返回 JSON 构造（live 通道）。
  static NoteBoardData fromApi(Map<String, Object?> board) {
    return NoteBoardData(
      items: ((board['items'] as List<Object?>?) ?? const <Object?>[])
          .map((Object? e) => noteItemFromApi(e as Map<String, Object?>))
          .toList(),
    );
  }
}

/// 笔记控制器（AsyncNotifier：首次 listen 时拉取，页面销毁即释放）。
class NotesController extends AsyncNotifier<NoteBoardData> {
  @override
  Future<NoteBoardData> build() => _fetch();

  bool get _isMock => ref.read(mockModeProvider) == PortenMockMode.mock;

  Future<NoteBoardData> _fetch() async {
    if (_isMock) {
      return NoteBoardData(items: NoteStore.items);
    }
    return NoteBoardData.fromApi(await PortenDataBridge.listNotes());
  }

  /// 重新拉取（下拉刷新 / 写操作后同步）。
  Future<void> refresh() async {
    state = const AsyncValue<NoteBoardData>.loading();
    state = await AsyncValue.guard<NoteBoardData>(_fetch);
  }

  /// 新建笔记（标签按 、 , ， 空白切分至多 4 个，空则回退「随记」）。
  Future<NoteItem> create({
    required String content,
    required String tagsText,
  }) async {
    final List<String> tags = parseNoteTags(tagsText, fallback: true);
    final NoteItem created = _isMock
        ? NoteStore.create(content: content, tagsText: tagsText)
        : noteItemFromApi(
            await PortenDataBridge.createNote(content: content, tags: tags),
          );
    await refresh();
    return created;
  }

  /// 更新笔记（PATCH 语义：[tagsText] 为 null 表示不改标签；
  /// 空串即清空标签，与 Web 编辑分支一致）。
  /// 命名避开 Riverpod AsyncNotifier 内置 update(T Function(T))。
  Future<NoteItem> updateItem(
    int id, {
    String? content,
    String? tagsText,
    bool? archived,
  }) async {
    final List<String>? tags =
        tagsText != null ? parseNoteTags(tagsText) : null;
    final NoteItem updated = _isMock
        ? NoteStore.update(id, content: content, tagsText: tagsText, archived: archived)
        : noteItemFromApi(await PortenDataBridge.updateNote(
            id,
            content: content,
            tags: tags,
            archived: archived,
          ));
    await refresh();
    return updated;
  }

  /// 归档 / 取消归档（读取当前列表翻转 archived）。
  Future<void> toggleArchive(int id) async {
    final bool archived = _archivedOf(id);
    if (_isMock) {
      NoteStore.update(id, archived: !archived);
    } else {
      await PortenDataBridge.updateNote(id, archived: !archived);
    }
    await refresh();
  }

  /// 删除笔记。
  Future<void> delete(int id) async {
    if (_isMock) {
      NoteStore.delete(id);
    } else {
      await PortenDataBridge.deleteNote(id);
    }
    await refresh();
  }

  /// 当前列表中笔记的归档态（未加载时按未归档处理）。
  bool _archivedOf(int id) {
    final List<NoteItem>? items = state.value?.items;
    if (items == null) return false;
    for (final NoteItem note in items) {
      if (note.id == id) return note.archived;
    }
    return false;
  }
}

/// 全局笔记 Provider。
final AsyncNotifierProvider<NotesController, NoteBoardData>
    notesControllerProvider =
    AsyncNotifierProvider<NotesController, NoteBoardData>(NotesController.new);
