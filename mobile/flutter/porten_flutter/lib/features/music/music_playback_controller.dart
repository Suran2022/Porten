/*
 * 悦音乐播放状态（Riverpod，对齐 Web 端 HomePage.tsx 的全局 audio 元素
 * 与音乐状态机）。
 *
 * 行为对齐：
 *   - 未打开悦音乐前不自动播放；用户首次打开悦音乐后才开始播放
 *     （Web hasUserOpenedMusicRef + onMusicClick）；
 *   - 退出全屏音乐页显示悬浮转盘，音乐继续播放；悬浮窗叉叉停止播放；
 *   - 切歌重置进度，按当前播放状态自动播放；无音源曲目不可真实播放，
 *     进度/时长走静态数据兜底（Web audio effect 同款分支）；
 *   - 上一首可用性 = trackIndex > 0；下一首恒不可用
 *     （100% 复刻 Web canNext = trackIndex < 0 的现状）；
 *   - 播放列表仅含有音源曲目（Web tracks = filter(t => t.audioSrc)）。
 */

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/music_mock.dart';

/// 悦音乐播放状态。
class MusicPlayerState {
  const MusicPlayerState({
    this.trackIndex = 0,
    this.isPlaying = false,
    this.currentTime = 0,
    this.duration = 0,
    this.hasUserOpened = false,
  });

  /// 当前曲目索引（kMusicTracks）。
  final int trackIndex;

  /// 是否播放中。
  final bool isPlaying;

  /// 实时播放进度（秒，仅音源曲目有效）。
  final double currentTime;

  /// 实时总时长（秒，仅音源曲目有效）。
  final double duration;

  /// 用户是否已打开过悦音乐（首次打开才开始播放）。
  final bool hasUserOpened;

  MusicPlayerState copyWith({
    int? trackIndex,
    bool? isPlaying,
    double? currentTime,
    double? duration,
    bool? hasUserOpened,
  }) {
    return MusicPlayerState(
      trackIndex: trackIndex ?? this.trackIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      currentTime: currentTime ?? this.currentTime,
      duration: duration ?? this.duration,
      hasUserOpened: hasUserOpened ?? this.hasUserOpened,
    );
  }
}

/// 悦音乐播放控制器。
class MusicPlayerController extends Notifier<MusicPlayerState> {
  AudioPlayer? _player;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<void>? _completeSub;

  @override
  MusicPlayerState build() {
    ref.onDispose(_teardown);
    return const MusicPlayerState();
  }

  /// 当前曲目。
  MusicTrack get track => kMusicTracks[state.trackIndex];

  /// 上一首可用（对齐 Web canPrev = trackIndex > 0）。
  bool get canPrev => state.trackIndex > 0;

  /// 下一首恒不可用（100% 复刻 Web canNext = trackIndex < 0 现状，
  /// 数组索引恒 >= 0，故下一首永远点击无效并提示暂无更多音乐）。
  bool get canNext => false;

  /// 实时播放进度（秒）：有音源走实时值，无音源静态兜底
  /// （对齐 Web MusicView currentTime props 语义）。
  double get displayCurrentTime =>
      track.hasAudio ? state.currentTime : track.currentTime.toDouble();

  /// 实时总时长（秒）：有音源走实时值（元数据未就绪时为 0），
  /// 无音源静态兜底（对齐 Web duration props 语义）。
  double get displayDuration =>
      track.hasAudio ? state.duration : track.duration.toDouble();

  /// 可播放曲目列表（对齐 Web tracks = MUSIC_TRACKS.filter(t => t.audioSrc)）。
  List<MusicTrack> get playableTracks =>
      kMusicTracks.where((MusicTrack t) => t.hasAudio).toList();

  /// 当前曲目在可播放列表中的索引。
  int get playableIndex =>
      playableTracks.indexWhere((MusicTrack t) => t.id == track.id);

  /// 打开悦音乐：首次打开开始播放，后续打开保持当前播放状态
  /// （对齐 Web hasUserOpenedMusicRef + onMusicClick）。
  void openMusic() {
    if (state.hasUserOpened) return;
    state = state.copyWith(hasUserOpened: true, isPlaying: true);
    _playCurrent();
  }

  /// 播放/暂停切换（对齐 Web onTogglePlay；无音源曲目仅切换状态图标，
  /// 不联动音频，同 Web audio effect 对无音源分支早退）。
  Future<void> togglePlay() async {
    final bool next = !state.isPlaying;
    state = state.copyWith(isPlaying: next);
    if (next) {
      await _playCurrent();
    } else {
      await _player?.pause();
    }
  }

  /// 上一首（对齐 Web onPrev：索引递减并下限保护）。
  Future<void> prev() => _switchTo(state.trackIndex - 1);

  /// 下一首（对齐 Web onNext：索引递增并上限保护）。
  Future<void> next() => _switchTo(state.trackIndex + 1);

  /// 选择播放列表中的歌曲（索引相对可播放列表，对齐 Web onSelectTrack）。
  Future<void> selectPlayableTrack(int index) async {
    if (index < 0 || index >= playableTracks.length) return;
    final MusicTrack selected = playableTracks[index];
    final int original =
        kMusicTracks.indexWhere((MusicTrack t) => t.id == selected.id);
    if (original >= 0 && original != state.trackIndex) {
      await _switchTo(original);
    }
  }

  /// 进度跳转（供音乐页拖动进度条调用，对齐 Web handleSeek）。
  Future<void> seek(double seconds) async {
    if (!track.hasAudio) return;
    state = state.copyWith(currentTime: seconds);
    await _player
        ?.seek(Duration(milliseconds: (seconds * 1000).round()));
  }

  /// 停止播放（悬浮窗叉叉：隐藏悬浮窗并停止播放，对齐 Web onClose）。
  Future<void> stopPlayback() async {
    state = state.copyWith(isPlaying: false);
    await _player?.pause();
  }

  /// 切歌：重置进度，按当前播放状态自动播放；无音源静态兜底
  /// （逐分支复刻 Web 切歌 effect）。
  Future<void> _switchTo(int index) async {
    if (index < 0 || index >= kMusicTracks.length) return;
    if (index == state.trackIndex) return;
    final MusicTrack target = kMusicTracks[index];
    if (target.hasAudio) {
      state = MusicPlayerState(
        trackIndex: index,
        isPlaying: state.isPlaying,
        hasUserOpened: state.hasUserOpened,
      );
      if (state.isPlaying) {
        await _playCurrent();
      } else {
        await _player?.stop();
      }
    } else {
      // 无音源：停止音频，进度/时长由 display getter 静态兜底
      await _player?.stop();
      state = MusicPlayerState(
        trackIndex: index,
        isPlaying: state.isPlaying,
        hasUserOpened: state.hasUserOpened,
      );
    }
  }

  /// 播放当前曲目音源（懒创建 AudioPlayer 并绑定事件流）。
  Future<void> _playCurrent() async {
    final String? src = track.audioSrc;
    if (src == null) return;
    final AudioPlayer player = _player ??= _createPlayer();
    await player.setReleaseMode(ReleaseMode.stop);
    await player.play(AssetSource(src));
    // getDuration 兜底：个别平台 loadedmetadata 不触发时也能拿到总时长
    final Duration? d = await player.getDuration();
    if (d != null && d.inMilliseconds > 0 && track.hasAudio) {
      state = state.copyWith(duration: d.inMilliseconds / 1000);
    }
  }

  AudioPlayer _createPlayer() {
    final AudioPlayer player = AudioPlayer();
    _positionSub = player.onPositionChanged.listen((Duration p) {
      state = state.copyWith(currentTime: p.inMilliseconds / 1000);
    });
    _durationSub = player.onDurationChanged.listen((Duration d) {
      state = state.copyWith(duration: d.inMilliseconds / 1000);
    });
    _completeSub = player.onPlayerComplete.listen((_) {
      // 播放结束回到暂停态（对齐 Web audio ended → setIsPlaying(false)）
      state = state.copyWith(isPlaying: false);
    });
    return player;
  }

  void _teardown() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _completeSub?.cancel();
    _positionSub = null;
    _durationSub = null;
    _completeSub = null;
    _player?.dispose();
    _player = null;
  }
}

/// 全局悦音乐播放 Provider（app 级单例，不自动销毁）。
final NotifierProvider<MusicPlayerController, MusicPlayerState>
    musicPlayerProvider =
    NotifierProvider<MusicPlayerController, MusicPlayerState>(
        MusicPlayerController.new);
