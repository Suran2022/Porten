/*
 * 当前用户「心情 + 最新日记」状态（Riverpod，Mock 阶段本地可变）。
 *
 * 对齐 Web 端：
 *   - TopBar.tsx：mood = getMoodOption(user.mood) ?
 *     `${emoji} ${label}` : currentUser.mood；latestDiary =
 *     user.latestDiary ?? null（null 时不渲染分隔符与日记）；
 *   - ProfileCard.tsx：latestDiary 为空 → 「还没有记录过情绪哦」；
 *   - mockEngine.ts：POST/PATCH 情绪日记后 me.latest_diary/me.mood
 *     同步为新值，DELETE 后清空；EmotionDiaryPage 保存/删除后
 *     额外 updateUser 同步 authStore（App 侧由本 store 承担）。
 *
 * 初始值对齐 Web authStore 的 me（id 1001）：mood='happy' +
 * mockDiaries 中 is_current（id 1）的正文。
 */

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 当前用户心情状态。
class CurrentUserDiaryState {
  const CurrentUserDiaryState({this.mood, this.latestDiary});

  /// 心情 tag（happy/calm/...），null = 未设置（Web user.mood）。
  final String? mood;

  /// 最新日记正文，null = 未写过（Web user.latestDiary）。
  final String? latestDiary;
}

/// 当前用户心情控制器。
class CurrentUserDiaryController extends Notifier<CurrentUserDiaryState> {
  @override
  CurrentUserDiaryState build() {
    // 初始值：Web me.mood='happy'，latest_diary = mockDiaries id1 正文。
    return const CurrentUserDiaryState(
      mood: 'happy',
      latestDiary: '今天阳光很好，坐在窗边写下这些的时候，突然觉得被世界温柔地接住了。愿我们都能慢慢长成自己喜欢的样子。',
    );
  }

  /// 保存/更新日记后同步（Web EmotionDiaryPage.handleSave → updateUser）。
  void updateFromDiary({required String mood, required String content}) {
    state = CurrentUserDiaryState(mood: mood, latestDiary: content);
  }

  /// 删除日记后清空（Web handleDelete → updateUser({latestDiary:null, mood:null})）。
  void clear() {
    state = const CurrentUserDiaryState();
  }
}

/// 全局当前用户心情 Provider。
final NotifierProvider<CurrentUserDiaryController, CurrentUserDiaryState>
    currentUserDiaryProvider =
    NotifierProvider<CurrentUserDiaryController, CurrentUserDiaryState>(
        CurrentUserDiaryController.new);
