/*
 * 悦音乐全屏播放页（100% 复刻 Web 端 components/music/MusicView.tsx）。
 *
 * Web 端实现要点：
 *   - 从右滑入 translate-x-full → 0（300ms cubic-bezier(0.25,0.1,0.25,1)），
 *     背景取当前曲目 bgGradient（180deg 线性渐变）；
 *   - 状态栏/底部工具栏取色：topColor = 渐变首色、bottomColor = 渐变末色
 *     （Web 以 fixed 色块 + theme-color 采样实现，App 以 AnnotatedRegion
 *     + 全屏渐变背景实现，渐变背景覆盖手机状态栏区域）；
 *   - 顶栏：返回键（absolute left-4 top-3 -ml-1 p-1，BackIcon 白 28）+
 *     歌名居中（text-lg medium + 副标题 white/60 text-sm，px-12 truncate）；
 *   - 转盘/歌词点击切换：500ms 交叉淡入淡出 + scale(90↔100/110)；
 *   - 黑胶：radial-gradient(vinylColor 60% → #050505) + 外阴影 + 3 圈纹路
 *     + 中心封面 13% inset（播放时 16s 匀速旋转）+ 8px 中心孔；
 *   - 歌词：text-[15px] leading-relaxed，当前行 white medium、其余 white/40，
 *     gap-3 py-8，上下渐隐遮罩，当前行平滑滚到居中，空态「暂无歌词」；
 *   - 音乐信息：歌名 22px semibold + 副标题 18px white/70；情绪文案
 *     每 3.5s 上下顶出切换（300ms）；分享按钮（Share2 16 sw 1.8）；
 *   - 进度条：h-1 white/15 底 + white/80 填充 + 8px 白圆点头部，可拖动
 *     跳转；时间 text-[11px] white/55、品质居中 white/70；
 *   - 控制键：Repeat(24 sw1.6 white/70) / SkipBack(28 sw1.8 白) /
 *     Play-Pause(48 sw1.6 白，250ms iconSwap) / SkipForward / ListMusic；
 *     按压 active:scale-90/95；下一首恒不可用（复刻 Web canNext 恒 false），
 *     点击弹「暂无更多音乐」胶囊 toast（2s 消失）；
 *   - 播放列表弹层：底部弹层 #1c1410 rounded-t-2xl，最大 60vh，从底部
 *     滑入（300ms），当前曲目 white/15 + 「播放中」，底部「没有更多音乐啦」。
 */

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/components/porten_back_icon.dart';
import '../../../core/components/porten_lucide_icons.dart';
import '../../../core/components/porten_toast.dart';
import '../../../core/data/music_mock.dart';
import 'music_playback_controller.dart';

/// 悦音乐全屏播放页。
class MusicView extends ConsumerStatefulWidget {
  const MusicView({super.key});

  @override
  ConsumerState<MusicView> createState() => _MusicViewState();
}

class _MusicViewState extends ConsumerState<MusicView>
    with SingleTickerProviderStateMixin {
  // ---- 歌词 ----
  List<LyricLine> _lyrics = const <LyricLine>[];
  final Map<int, GlobalKey> _lineKeys = <int, GlobalKey>{};
  bool _showLyrics = false;
  int _lastScrolledLine = -1;

  // ---- 情绪文案轮播（每 3.5s 切换，300ms 上下顶出） ----
  int _moodIndex = 0;
  Timer? _moodTimer;

  // ---- 进度条拖动 ----
  double? _draggingProgress;
  double _lastDragDx = 0;

  // ---- 暂无更多音乐 toast（2s 消失） ----
  bool _toastVisible = false;
  Timer? _toastTimer;

  // ---- 播放列表弹层 ----
  bool _playlistRendered = false;
  late final AnimationController _playlistAnim;

  @override
  void initState() {
    super.initState();
    _playlistAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadLyrics();
    // 情绪文案轮播：页面常驻即启动（对齐 Web shouldRender 后的 interval）
    _moodTimer = Timer.periodic(
      const Duration(milliseconds: 3500),
      (_) => _onMoodTick(),
    );
  }

  @override
  void dispose() {
    _moodTimer?.cancel();
    _toastTimer?.cancel();
    _playlistAnim.dispose();
    super.dispose();
  }

  /// 加载当前曲目歌词（对齐 Web 依赖 [shouldRender, track.lrcSrc] 的 effect）。
  Future<void> _loadLyrics() async {
    final String? src = ref.read(musicPlayerProvider.notifier).track.lrcSrc;
    if (src == null) {
      setState(() => _lyrics = const <LyricLine>[]);
      return;
    }
    try {
      final String text = await rootBundle.loadString(src);
      if (!mounted) return;
      setState(() => _lyrics = parseLrc(text));
    } catch (_) {
      if (!mounted) return;
      setState(() => _lyrics = const <LyricLine>[]);
    }
  }

  void _onMoodTick() {
    if (!mounted) return;
    // 直接切换索引：AnimatedSwitcher 的旧文案向上淡出、新文案自下滑入，
    // 与 Web「先 out 300ms 再切文案 in」的两段式动画等价
    setState(() => _moodIndex = (_moodIndex + 1) % kMusicMoodTexts.length);
  }

  /// 当前歌词行索引（不超过当前播放时间的最后一行，对齐 Web activeLyricIndex）。
  int _activeLyricIndex(MusicPlayerState state) {
    if (_lyrics.isEmpty) return -1;
    final MusicPlayerController controller =
        ref.read(musicPlayerProvider.notifier);
    final double playTime = controller.displayCurrentTime;
    int idx = -1;
    for (int i = 0; i < _lyrics.length; i++) {
      if (_lyrics[i].time <= playTime) {
        idx = i;
      } else {
        break;
      }
    }
    return idx;
  }

  /// 当前行滚动到居中（对齐 Web scrollTo smooth，用 ensureVisible 实现）。
  void _scrollActiveLineIntoView(int index) {
    if (!_showLyrics || index < 0) return;
    final GlobalKey? key = _lineKeys[index];
    final BuildContext? ctx = key?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.5,
      duration: const Duration(milliseconds: 300),
      curve: Curves.ease,
    );
  }

  /// 点击转盘/歌词区切换视图（对齐 Web setShowLyrics）。
  void _toggleLyrics() {
    final bool show = !_showLyrics;
    setState(() => _showLyrics = show);
    if (!show) return;
    // 打开歌词视图：当前行滚动到居中（对齐 Web effect 依赖 showLyrics）
    final int idx = _activeLyricIndex(ref.read(musicPlayerProvider));
    _lastScrolledLine = idx;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollActiveLineIntoView(idx);
    });
  }

  void _showNoMoreToast() {
    setState(() => _toastVisible = true);
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _toastVisible = false);
    });
  }

  void _openPlaylist() {
    setState(() => _playlistRendered = true);
    _playlistAnim.forward();
  }

  void _closePlaylist() {
    _playlistAnim.reverse().then((_) {
      if (mounted) setState(() => _playlistRendered = false);
    });
  }

  Future<void> _handleShare() async {
    final String text =
        kMusicShareTexts[math.Random().nextInt(kMusicShareTexts.length)];
    // Web 端 navigator.share 唤起系统分享；App 端无 share 依赖，
    // 走 Web 的回退分支（复制链接）并Toast反馈
    await Clipboard.setData(
        ClipboardData(text: '$text https://porten.app/share/music'));
    if (!mounted) return;
    PortenToast.show('已复制分享链接');
  }

  String _formatTime(double seconds) {
    final int m = seconds ~/ 60;
    final int s = seconds.toInt() % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final MusicPlayerState musicState = ref.watch(musicPlayerProvider);
    final MusicPlayerController controller =
        ref.read(musicPlayerProvider.notifier);
    final MusicTrack track = kMusicTracks[musicState.trackIndex];

    ref.listen<MusicPlayerState>(musicPlayerProvider,
        (MusicPlayerState? prev, MusicPlayerState next) {
      if (prev != null && prev.trackIndex != next.trackIndex) {
        // 切歌：重载歌词并重置滚动基准（对齐 Web effect 依赖 track.lrcSrc）
        _loadLyrics();
        _lastScrolledLine = -1;
      }
      final int idx = _activeLyricIndex(next);
      if (idx != _lastScrolledLine) {
        _lastScrolledLine = idx;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scrollActiveLineIntoView(idx);
        });
      }
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // 状态栏取渐首色、系统导航栏取渐末色（对齐 Web topColor/bottomColor），
      // 配合全屏渐变背景实现「背景色覆盖手机状态栏」
      value: SystemUiOverlayStyle(
        statusBarColor: track.statusBarColor,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: track.bottomBarColor,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: track.statusBarColor,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(gradient: track.backgroundGradient),
          child: SafeArea(
            child: Stack(
              children: <Widget>[
                Column(
                  children: <Widget>[
                    _buildTopBar(track),
                    Expanded(child: _buildStage(track, musicState)),
                    _buildInfoSection(track),
                    _buildProgressSection(track, controller),
                    _buildControls(musicState, controller),
                  ],
                ),
                // 暂无更多音乐 toast（Web top-14：紧贴顶栏下沿）
                Positioned(
                  top: 56,
                  left: 0,
                  right: 0,
                  child: Center(child: _NoMoreToast(visible: _toastVisible)),
                ),
                if (_playlistRendered)
                  _buildPlaylistOverlay(controller),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---- 顶部栏：返回键 + 歌名居中 ----
  Widget _buildTopBar(MusicTrack track) {
    return SizedBox(
      height: 56, // pt-3(12) + 内容 36 + pb-2(8)
      child: Stack(
        children: <Widget>[
          // 返回键：left-4(16) -ml-1(-4) → 左缘 12；p-1 + 28 图标 → 命中盒 36×36
          Positioned(
            left: 12,
            top: 12,
            child: _ControlButton(
              pressedScale: 0.9,
              onTap: () => Navigator.of(context).pop(),
              child: const Padding(
                padding: EdgeInsets.all(4), // p-1
                child: PortenBackIcon(
                    size: 28, color: Color(0xFFFFFFFF)), // w-7 h-7 白
              ),
            ),
          ),
          // 歌名：px-12 py-1 居中（返回键绝对定位不占流，标题严格居中 W/2）
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 4),
              child: Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    TextSpan(
                      text: track.title,
                      style: const TextStyle(
                        fontSize: 18, // text-lg
                        height: 28 / 18,
                        fontWeight: FontWeight.w500, // font-medium
                        color: Color(0xFFFFFFFF),
                      ),
                    ),
                    if (track.subtitle != null)
                      TextSpan(
                        text: ' （${track.subtitle}）',
                        style: const TextStyle(
                          fontSize: 14, // text-sm
                          height: 20 / 14,
                          fontWeight: FontWeight.w400,
                          color: Color(0x99FFFFFF), // white/60
                        ),
                      ),
                  ],
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis, // truncate
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- 转盘/歌词切换区（flex-1，px-8 py-4，点击切换） ----
  Widget _buildStage(MusicTrack track, MusicPlayerState musicState) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleLyrics,
        child: Stack(
          children: <Widget>[
            // 黑胶唱片
            Positioned.fill(
              child: _StageFadeScale(
                visible: !_showLyrics,
                scale: _showLyrics ? 0.9 : 1.0,
                child: Center(
                  child: _VinylRecord(
                    vinylColor: track.vinylColor,
                    coverLabel: track.coverLabel,
                    spinning: musicState.isPlaying,
                  ),
                ),
              ),
            ),
            // 滚动歌词
            Positioned.fill(
              child: _StageFadeScale(
                visible: _showLyrics,
                scale: _showLyrics ? 1.0 : 1.1,
                child: _buildLyrics(musicState),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLyrics(MusicPlayerState musicState) {
    if (_lyrics.isEmpty) {
      return const Center(
        child: Text(
          '暂无歌词',
          style: TextStyle(fontSize: 14, color: Color(0x80FFFFFF)), // white/50 text-sm
        ),
      );
    }
    final int activeIndex = _activeLyricIndex(musicState);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return ShaderMask(
          // mask-lyric-fade：上/下 18% 渐隐
          shaderCallback: (Rect bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0x00000000),
              Color(0xFF000000),
              Color(0xFF000000),
              Color(0x00000000),
            ],
            stops: <double>[0, 0.18, 0.82, 1],
          ).createShader(bounds),
          blendMode: BlendMode.dstOut,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 32), // py-8
            child: ConstrainedBox(
              // min-h-full + justify-center：内容不足一屏时垂直居中
              constraints: BoxConstraints(
                  minHeight: math.max(0, constraints.maxHeight - 64)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: _buildLyricLines(activeIndex),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildLyricLines(int activeIndex) {
    final List<Widget> children = <Widget>[];
    for (int i = 0; i < _lyrics.length; i++) {
      if (i > 0) children.add(const SizedBox(height: 12)); // gap-3
      final bool active = i == activeIndex;
      children.add(
        Padding(
          key: _lineKeys[i] ??= GlobalKey(),
          padding: const EdgeInsets.symmetric(horizontal: 16), // px-4
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300), // transition-colors
            curve: Curves.ease,
            style: TextStyle(
              fontSize: 15, // text-[15px]
              height: 1.625, // leading-relaxed
              color: active
                  ? const Color(0xFFFFFFFF)
                  : const Color(0x66FFFFFF), // white / white/40
              fontWeight: active ? FontWeight.w500 : FontWeight.w400,
            ),
            child: Text(
              _lyrics[i].text,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return children;
  }

  // ---- 音乐信息：歌名 + 情绪文案轮播 + 分享 ----
  Widget _buildInfoSection(MusicTrack track) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12), // px-6 mb-3
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: track.title,
                  style: const TextStyle(
                    fontSize: 22, // text-[22px]
                    height: 1.25, // leading-tight
                    fontWeight: FontWeight.w600, // font-semibold
                    color: Color(0xFFFFFFFF),
                  ),
                ),
                if (track.subtitle != null)
                  TextSpan(
                    text: ' （${track.subtitle}）',
                    style: const TextStyle(
                      fontSize: 18, // text-[18px]
                      height: 1.25,
                      fontWeight: FontWeight.w400,
                      color: Color(0xB3FFFFFF), // white/70
                    ),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis, // truncate
          ),
          const SizedBox(height: 8), // mt-2
          SizedBox(
            height: 20, // h-5
            child: Row(
              children: <Widget>[
                // 情绪文案：flex-1 overflow-hidden 裁剪顶出动画
                Expanded(
                  child: ClipRect(
                    child: _MoodCarousel(index: _moodIndex),
                  ),
                ),
                const SizedBox(width: 8), // ml-2
                _ControlButton(
                  pressedScale: 0.9,
                  onTap: _handleShare,
                  child: const Padding(
                    padding: EdgeInsets.all(4), // p-1
                    child: PortenLucideIcon(
                      'share2',
                      size: 16, // w-4 h-4
                      color: Color(0xB3FFFFFF), // white/70
                      strokeWidth: 1.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- 进度条：细线 + 小圆点头部，可拖动跳转 ----
  Widget _buildProgressSection(MusicTrack track, MusicPlayerController controller) {
    final double playTime = controller.displayCurrentTime;
    final double totalTime = controller.displayDuration;
    final double progress =
        totalTime > 0 ? (playTime / totalTime).clamp(0.0, 1.0) : 0.0;
    final double displayProgress = _draggingProgress ?? progress;
    final double displayTime =
        _draggingProgress != null ? _draggingProgress! * totalTime : playTime;
    final bool seekable = track.hasAudio; // 对齐 Web：无音源不传 onSeek

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12), // px-6 mb-3
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 4, // h-1
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double w = constraints.maxWidth;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: seekable
                      ? (TapDownDetails d) =>
                          _onProgressDrag(d.localPosition.dx, w)
                      : null,
                  onTapUp: seekable
                      ? (_) => _onProgressDragEnd(_lastDragDx, w, totalTime)
                      : null,
                  onHorizontalDragStart: seekable
                      ? (DragStartDetails d) =>
                          _onProgressDrag(d.localPosition.dx, w)
                      : null,
                  onHorizontalDragUpdate: seekable
                      ? (DragUpdateDetails d) =>
                          _onProgressDrag(d.localPosition.dx, w)
                      : null,
                  onHorizontalDragEnd: seekable
                      ? (DragEndDetails d) =>
                          _onProgressDragEnd(_lastDragDx, w, totalTime)
                      : null,
                  child: Stack(
                    clipBehavior: Clip.none, // 圆点头部不被裁剪
                    children: <Widget>[
                      // 轨道 white/15
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0x26FFFFFF),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      // 填充 white/80
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: w * displayProgress,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xCCFFFFFF),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      // 头部小圆点：left = calc(p% - 4px)，shadow-md
                      Positioned(
                        left: w * displayProgress - 4,
                        top: -2, // top-1/2 -translate-y-1/2（4px 条 - 8px 点）
                        child: Container(
                          width: 8, // w-2
                          height: 8, // h-2
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFFFFF),
                            shape: BoxShape.circle,
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: Color(0x1A000000),
                                offset: Offset(0, 4),
                                blurRadius: 6,
                                spreadRadius: -1,
                              ),
                              BoxShadow(
                                color: Color(0x1A000000),
                                offset: Offset(0, 2),
                                blurRadius: 4,
                                spreadRadius: -2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6), // mt-1.5
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                _formatTime(displayTime),
                style: const TextStyle(
                    fontSize: 11, color: Color(0x8CFFFFFF)), // white/55
              ),
              Text(
                track.quality,
                style: const TextStyle(
                    fontSize: 11, color: Color(0xB3FFFFFF)), // white/70
              ),
              Text(
                _formatTime(totalTime),
                style: const TextStyle(
                    fontSize: 11, color: Color(0x8CFFFFFF)), // white/55
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _onProgressDrag(double dx, double width) {
    if (width <= 0) return;
    _lastDragDx = dx;
    setState(() => _draggingProgress = (dx / width).clamp(0.0, 1.0));
  }

  void _onProgressDragEnd(double dx, double width, double totalTime) {
    if (width <= 0) {
      setState(() => _draggingProgress = null);
      return;
    }
    final double p = (dx / width).clamp(0.0, 1.0);
    ref.read(musicPlayerProvider.notifier).seek(p * totalTime);
    setState(() => _draggingProgress = null);
  }

  // ---- 播放控制 ----
  Widget _buildControls(
      MusicPlayerState musicState, MusicPlayerController controller) {
    final bool playing = musicState.isPlaying;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0), // px-6 pt-2
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          // 循环模式（Web 无绑定行为，仅展示）
          _ControlButton(
            pressedScale: 0.95,
            onTap: () {},
            child: const Padding(
              padding: EdgeInsets.all(8), // p-2
              child: PortenLucideIcon('repeat',
                  size: 24, // w-6
                  color: Color(0xB3FFFFFF), // white/70
                  strokeWidth: 1.6),
            ),
          ),
          // 上一首
          _ControlButton(
            pressedScale: 0.9,
            onTap: () {
              if (controller.canPrev) {
                controller.prev();
              } else {
                _showNoMoreToast();
              }
            },
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: PortenLucideIcon('skip-back',
                  size: 28, // w-7
                  color: Color(0xFFFFFFFF),
                  strokeWidth: 1.8),
            ),
          ),
          // 播放/暂停（250ms iconSwap）
          _ControlButton(
            pressedScale: 0.9,
            onTap: () => controller.togglePlay(),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: _IconSwap(
                iconKey: playing ? 'pause' : 'play',
                icon: PortenLucideIcon(
                  playing ? 'pause' : 'play',
                  size: 48, // w-12
                  color: const Color(0xFFFFFFFF),
                  strokeWidth: 1.6,
                ),
              ),
            ),
          ),
          // 下一首（canNext 恒 false → 恒提示暂无更多音乐，复刻 Web 现状）
          _ControlButton(
            pressedScale: 0.9,
            onTap: () {
              if (controller.canNext) {
                controller.next();
              } else {
                _showNoMoreToast();
              }
            },
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: PortenLucideIcon('skip-forward',
                  size: 28, // w-7
                  color: Color(0xFFFFFFFF),
                  strokeWidth: 1.8),
            ),
          ),
          // 播放列表
          _ControlButton(
            pressedScale: 0.95,
            onTap: _openPlaylist,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: PortenLucideIcon('list-music',
                  size: 24, // w-6
                  color: Color(0xB3FFFFFF), // white/70
                  strokeWidth: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  // ---- 播放列表弹层 ----
  Widget _buildPlaylistOverlay(MusicPlayerController controller) {
    final Animation<double> curved = CurvedAnimation(
      parent: _playlistAnim,
      curve: const Cubic(0.25, 0.1, 0.25, 1),
    );
    return Stack(
      children: <Widget>[
        // 遮罩 black/50（opacity 跟随弹层动画）
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _playlistAnim,
            builder: (BuildContext context, Widget? child) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closePlaylist,
                child: Container(
                  color: Color(0xFF000000)
                      .withValues(alpha: 0.5 * _playlistAnim.value),
                ),
              );
            },
          ),
        ),
        // 弹窗主体：从底部滑入
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(curved),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.6), // 60vh
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF1C1410), // bg-[#1c1410]
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                padding: const EdgeInsets.only(bottom: 24), // pb-6
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // 拖拽指示条：pt-2 pb-1 + w-10 h-1 white/25 rounded-full
                    SizedBox(
                      height: 16,
                      child: Center(
                        child: SizedBox(
                          width: 40,
                          height: 4,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Color(0x40FFFFFF),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // 标题：px-5 py-3
                    const SizedBox(
                      height: 48,
                      child: Center(
                        child: Text(
                          '播放列表',
                          style: TextStyle(
                            fontSize: 16, // text-base
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFFFFFFF),
                          ),
                        ),
                      ),
                    ),
                    // 列表
                    Flexible(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 12), // px-3
                        children: _buildPlaylistRows(controller),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildPlaylistRows(MusicPlayerController controller) {
    final List<MusicTrack> tracks = controller.playableTracks;
    final int activeIndex = controller.playableIndex;
    final List<Widget> rows = <Widget>[];
    if (tracks.isEmpty) {
      rows.add(const SizedBox(
        height: 64, // py-8
        child: Center(
          child: Text(
            '暂无播放列表',
            style: TextStyle(fontSize: 14, color: Color(0x80FFFFFF)),
          ),
        ),
      ));
    } else {
      for (int i = 0; i < tracks.length; i++) {
        rows.add(_PlaylistRow(
          track: tracks[i],
          active: i == activeIndex,
          onTap: () {
            controller.selectPlayableTrack(i);
            _closePlaylist();
          },
        ));
      }
    }
    // 列表底部提示：没有更多音乐啦（white/35 text-xs py-4）
    rows.add(const SizedBox(
      height: 32,
      child: Center(
        child: Text(
          '没有更多音乐啦',
          style: TextStyle(fontSize: 12, color: Color(0x59FFFFFF)),
        ),
      ),
    ));
    return rows;
  }
}

/// 转盘/歌词交叉淡入淡出 + 缩放（Web transition-all duration-500
/// ease-[cubic-bezier(0.25,0.1,0.25,1)]，隐藏层 pointer-events-none）。
class _StageFadeScale extends StatelessWidget {
  const _StageFadeScale({
    required this.visible,
    required this.scale,
    required this.child,
  });

  final bool visible;
  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 500),
        curve: const Cubic(0.25, 0.1, 0.25, 1),
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 500),
          curve: const Cubic(0.25, 0.1, 0.25, 1),
          child: child,
        ),
      ),
    );
  }
}

/// 黑胶唱片（w-full max-w-[272px] aspect-square）。
class _VinylRecord extends StatelessWidget {
  const _VinylRecord({
    required this.vinylColor,
    required this.coverLabel,
    required this.spinning,
  });

  final Color vinylColor;
  final String coverLabel;
  final bool spinning;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double size = math.min(constraints.maxWidth, 272);
        return SizedBox.square(
          dimension: size,
          child: Stack(
            children: <Widget>[
              // 黑胶外圈：radial-gradient + 外阴影
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    // CSS radial-gradient(circle at 50% 50%, vinylColor 60%, #050505 100%)
                    // radius 取 √2/2（farthest-corner），stops 与 CSS 色标一致
                    gradient: RadialGradient(
                      colors: <Color>[vinylColor, const Color(0xFF050505)],
                      stops: const <double>[0.6, 1],
                      radius: 0.7071,
                    ),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x8C000000), // rgba(0,0,0,0.55)
                        offset: Offset(0, 30),
                        blurRadius: 60,
                      ),
                    ],
                  ),
                  // 内阴影微光 + 3 圈纹路
                  child: CustomPaint(
                    painter: _VinylTexturePainter(size: size),
                  ),
                ),
              ),
              // 中心封面：13% inset
              Positioned(
                left: size * 0.13,
                top: size * 0.13,
                right: size * 0.13,
                bottom: size * 0.13,
                child: _VinylCover(
                  spinning: spinning,
                  coverLabel: coverLabel,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 黑胶纹理：内阴影微光（inset 0 0 30px white/4%）+ 3 圈纹路
/// （inset 6/10/14px，border 1px white/[0.05]）。
class _VinylTexturePainter extends CustomPainter {
  _VinylTexturePainter({required this.size});

  final double size;

  @override
  void paint(Canvas canvas, Size sz) {
    final double r = size / 2;
    final Offset center = Offset(r, r);
    // 内阴影：从外缘向内 30px 渐隐的白色 4% 微光
    final double insetFrac = (30 / (0.7071 * size)).clamp(0.0, 0.5);
    final Paint glow = Paint()
      ..shader = RadialGradient(
        colors: const <Color>[Color(0x0AFFFFFF), Color(0x00FFFFFF)],
        stops: <double>[1 - insetFrac, 1],
        radius: 0.7071,
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, glow);
    // 3 圈纹路
    final Paint groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x0DFFFFFF); // white/[0.05]
    for (int i = 0; i < 3; i++) {
      final double inset = 6 + i * 4;
      canvas.drawCircle(center, r - inset - 0.5, groove);
    }
  }

  @override
  bool shouldRepaint(covariant _VinylTexturePainter oldDelegate) =>
      oldDelegate.size != size;
}

/// 中心封面：74% 直径，播放时 16s 匀速旋转；外环 2px 白 8%、
/// 内环 4px 黑 35%、中心孔 8px。
class _VinylCover extends StatelessWidget {
  const _VinylCover({required this.spinning, required this.coverLabel});

  final bool spinning;
  final String coverLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      // 0 0 0 2px rgba(255,255,255,0.08)：外缘 2px 白环
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0x14FFFFFF), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: _SpinningDisc(
          spinning: spinning,
          child: ClipOval(
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Image.asset(
                  'assets/music-cover.webp',
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                ),
                // inset 0 0 0 4px rgba(0,0,0,0.35)：内缘 4px 黑环
                Positioned.fill(
                  child: CustomPaint(painter: _CoverInnerRingPainter()),
                ),
                // 中心孔 8px
                Center(
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF000000),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 封面内缘 4px 黑环（inset 0 0 0 4px rgba(0,0,0,0.35)）。
class _CoverInnerRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = const Color(0x59000000); // rgba(0,0,0,0.35)
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      math.min(size.width, size.height) / 2 - 2,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 播放时旋转（Web animate-spin-slow：16s linear infinite）；
/// 暂停时直接返回子组件（Web 移除动画类后角度归零，与此一致）。
class _SpinningDisc extends StatelessWidget {
  const _SpinningDisc({required this.spinning, required this.child});

  final bool spinning;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!spinning) return child;
    return _SpinSlow(child: child);
  }
}

class _SpinSlow extends StatefulWidget {
  const _SpinSlow({required this.child});

  final Widget child;

  @override
  State<_SpinSlow> createState() => _SpinSlowState();
}

class _SpinSlowState extends State<_SpinSlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 16), // animate-spin-slow
  );

  @override
  void initState() {
    super.initState();
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(turns: _controller, child: widget.child);
  }
}

/// 情绪文案轮播：每 3.5s 切换，300ms 上下顶出（moodTextIn/Out）。
class _MoodCarousel extends StatelessWidget {
  const _MoodCarousel({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Text(
        kMusicMoodTexts[index],
        key: ValueKey<int>(index),
        style: const TextStyle(
          fontSize: 14, // text-sm
          color: Color(0xB3FFFFFF), // white/70
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      transitionBuilder: (Widget child, Animation<double> anim) {
        // 进入：自下滑入（translateY 100%→0）；退出：向上顶出（0→-100%）
        final bool entering = (child.key as ValueKey<int>).value == index;
        final Animation<double> curved =
            CurvedAnimation(parent: anim, curve: Curves.ease);
        return SlideTransition(
          position: Tween<Offset>(
            begin: Offset(0, entering ? 1 : 0),
            end: Offset(0, entering ? 0 : -1),
          ).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    );
  }
}

/// 播放/暂停图标切换动画（Web iconSwap 250ms ease：opacity 0→1 +
/// scale 0.6→1，key 变化重放）。
class _IconSwap extends StatefulWidget {
  const _IconSwap({required this.iconKey, required this.icon});

  final String iconKey;
  final Widget icon;

  @override
  State<_IconSwap> createState() => _IconSwapState();
}

class _IconSwapState extends State<_IconSwap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );

  late final Animation<double> _anim =
      CurvedAnimation(parent: _controller, curve: Curves.ease);

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void didUpdateWidget(_IconSwap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.iconKey != widget.iconKey) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.6, end: 1).animate(_anim),
        child: widget.icon,
      ),
    );
  }
}

/// 控制键按压动画（Web active:scale-90/95 + transition-transform 150ms）。
class _ControlButton extends StatefulWidget {
  const _ControlButton({
    required this.child,
    required this.onTap,
    this.pressedScale = 0.9,
  });

  final Widget child;
  final VoidCallback onTap;
  final double pressedScale;

  @override
  State<_ControlButton> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<_ControlButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1,
        duration: const Duration(milliseconds: 150),
        curve: Curves.ease,
        child: widget.child,
      ),
    );
  }
}

/// 播放列表行（当前曲目 white/15，按压 white/5）。
class _PlaylistRow extends StatefulWidget {
  const _PlaylistRow({
    required this.track,
    required this.active,
    required this.onTap,
  });

  final MusicTrack track;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_PlaylistRow> createState() => _PlaylistRowState();
}

class _PlaylistRowState extends State<_PlaylistRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final MusicTrack t = widget.track;
    final bool active = widget.active;
    final Color bg = active
        ? const Color(0x26FFFFFF) // white/15
        : (_pressed
            ? const Color(0x0DFFFFFF) // active:bg-white/5
            : const Color(0x00000000));
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150), // transition-colors
        curve: Curves.ease,
        margin: const EdgeInsets.only(bottom: 4), // mb-1
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), // px-3 py-3
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12), // rounded-xl
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        TextSpan(
                          text: t.title,
                          style: TextStyle(
                            fontSize: 15, // text-[15px]
                            fontWeight:
                                active ? FontWeight.w500 : FontWeight.w400,
                            color: active
                                ? const Color(0xFFFFFFFF)
                                : const Color(0xD9FFFFFF), // white/85
                          ),
                        ),
                        if (t.subtitle != null)
                          TextSpan(
                            text: ' （${t.subtitle}）',
                            style: const TextStyle(
                              fontSize: 13, // text-[13px]
                              fontWeight: FontWeight.w400,
                              color: Color(0x8CFFFFFF), // white/55
                            ),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2), // mt-0.5
                  Text(
                    t.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12, // text-[12px]
                      color: Color(0x80FFFFFF), // white/50
                    ),
                  ),
                ],
              ),
            ),
            if (active)
              const Padding(
                padding: EdgeInsets.only(left: 8), // ml-2
                child: Text(
                  '播放中',
                  style: TextStyle(
                    fontSize: 12, // text-xs
                    color: Color(0xB3FFFFFF), // white/70
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 「暂无更多音乐」胶囊 toast（Web top-14 居中，300ms 淡入上移，2s 消失）。
class _NoMoreToast extends StatelessWidget {
  const _NoMoreToast({required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: visible ? 1 : 0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.ease,
      builder: (BuildContext context, double t, Widget? child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, -8 * (1 - t)), // -translate-y-2 → 0
            child: child,
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999), // rounded-full
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4), // backdrop-blur-sm
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // px-4 py-2
            decoration: BoxDecoration(
              color: const Color(0xBF000000), // bg-black/75
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const <Widget>[
                PortenLucideIcon('music2',
                    size: 16, // w-4 h-4
                    color: Color(0xFFFFFFFF),
                    strokeWidth: 2),
                SizedBox(width: 6), // gap-1.5
                Text(
                  '暂无更多音乐',
                  style: TextStyle(fontSize: 14, color: Color(0xFFFFFFFF)), // text-sm
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
