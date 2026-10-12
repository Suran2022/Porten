/*
 * 首页状态（Riverpod）。
 *
 * 对齐 Web 端 chatStore 的 pinned / important / hidden 会话管理能力，
 * 数据源为 Mock（core/data/home_mock.dart），后续接入真实 Repository 时
 * 仅替换数据来源，UI 状态结构保持不变。
 */

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/home_mock.dart';

/// 首页会话状态：列表 + 置顶 / 重要 / 隐藏集合。
class HomeConversationsState {
  const HomeConversationsState({
    required this.conversations,
    this.pinnedIds = const <int>{},
    this.importantIds = const <int>{},
    this.hiddenIds = const <int>{},
  });

  final List<PortenConversation> conversations;
  final Set<int> pinnedIds;
  final Set<int> importantIds;
  final Set<int> hiddenIds;

  bool isPinned(int id) => pinnedIds.contains(id);

  HomeConversationsState copyWith({
    List<PortenConversation>? conversations,
    Set<int>? pinnedIds,
    Set<int>? importantIds,
    Set<int>? hiddenIds,
  }) {
    return HomeConversationsState(
      conversations: conversations ?? this.conversations,
      pinnedIds: pinnedIds ?? this.pinnedIds,
      importantIds: importantIds ?? this.importantIds,
      hiddenIds: hiddenIds ?? this.hiddenIds,
    );
  }
}

/// 会话状态控制器。
class HomeConversationsController extends Notifier<HomeConversationsState> {
  @override
  HomeConversationsState build() {
    return HomeConversationsState(conversations: kPortenConversations);
  }

  /// 置顶切换（对齐 togglePin）。
  void togglePin(int id) {
    final Set<int> next = Set<int>.of(state.pinnedIds);
    if (!next.add(id)) next.remove(id);
    state = state.copyWith(pinnedIds: next);
  }

  /// 重要标记切换（对齐 toggleImportant）。
  void toggleImportant(int id) {
    final Set<int> next = Set<int>.of(state.importantIds);
    if (!next.add(id)) next.remove(id);
    state = state.copyWith(importantIds: next);
  }

  /// 隐藏会话（对齐 hideConversation）。
  void hide(int id) {
    final Set<int> next = Set<int>.of(state.hiddenIds)..add(id);
    state = state.copyWith(hiddenIds: next);
  }
}

/// 会话状态 Provider。
final NotifierProvider<HomeConversationsController, HomeConversationsState>
    homeConversationsProvider =
    NotifierProvider<HomeConversationsController, HomeConversationsState>(
        HomeConversationsController.new);

/// 未读总数（BottomNav 消息徽标，对齐 totalUnread）。
final Provider<int> totalUnreadProvider = Provider<int>((Ref ref) {
  return ref
      .watch(homeConversationsProvider)
      .conversations
      .fold(0, (int sum, PortenConversation c) => sum + c.unreadCount);
});
