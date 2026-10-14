/*
 * 悦音乐页面测试（MusicView + LRC 解析 + 播放控制器状态机）。
 *
 * 音频走 audioplayers 平台通道，测试环境不可用：
 *   - UI 用例以 _FakeMusicPlayerController 覆写 musicPlayerProvider，
 *     隔离真实播放；
 *   - 状态机用例用真实控制器，但只驱动「无音源/暂停态」分支
 *     （_player 为 null 时 stop 空转，不触达平台通道）。
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porten_flutter/core/components/porten_back_icon.dart';
import 'package:porten_flutter/core/components/porten_lucide_icons.dart';
import 'package:porten_flutter/core/data/music_mock.dart';
import 'package:porten_flutter/features/music/music_playback_controller.dart';
import 'package:porten_flutter/features/music/music_view.dart';

/// 假播放控制器：覆写所有触及 AudioPlayer 的方法，不触达平台通道。
class _FakeMusicPlayerController extends MusicPlayerController {
  @override
  MusicPlayerState build() => const MusicPlayerState();

  @override
  void openMusic() {}

  @override
  Future<void> togglePlay() async {}

  @override
  Future<void> prev() async {}

  @override
  Future<void> next() async {}

  @override
  Future<void> selectPlayableTrack(int index) async {}

  @override
  Future<void> seek(double seconds) async {}

  @override
  Future<void> stopPlayback() async {}
}

/// 假播放控制器（无音源曲目）：索引 1（深海），走静态兜底进度。
class _FakeNoAudioPlayerController extends MusicPlayerController {
  @override
  MusicPlayerState build() => const MusicPlayerState(trackIndex: 1);

  @override
  void openMusic() {}

  @override
  Future<void> togglePlay() async {}

  @override
  Future<void> prev() async {}

  @override
  Future<void> next() async {}

  @override
  Future<void> selectPlayableTrack(int index) async {}

  @override
  Future<void> seek(double seconds) async {}

  @override
  Future<void> stopPlayback() async {}
}

/// 以路由方式打开 MusicView（根路由不可 pop，须压栈打开）。
Future<void> _openMusicView(
  WidgetTester tester, {
  MusicPlayerController Function()? controller,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        musicPlayerProvider
            .overrideWith(controller ?? _FakeMusicPlayerController.new),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const MusicView(),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  // lrc 走真实 I/O（rootBundle.loadString）：须在真实事件循环中等候 Future 完成，
  // 否则首次断言时歌词行尚未入树（pumpAndSettle 的假时钟不推进真实 I/O）。
  // 轮询等待歌词渲染（无 lrc 的曲目不受影响，空转后继续）。
  for (int i = 0; i < 20; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    if (find.text('翻唱：锦零').evaluate().isNotEmpty) break;
  }
  await tester.pumpAndSettle();
}

void main() {
  // flutter/flutter#96123：rootBundle（PlatformAssetBundle extends
  // CachingAssetBundle）会把 loadString 的 Future 存入进程级缓存；首个用例
  // 在该 Future 完成于本用例 Zone 后一切正常，但后续用例（各自独立 FakeAsync
  // Zone）await 同一个缓存 Future 会永久挂起（lrc 歌词永远加载不出来）。
  // 每个用例后驱逐该资产，使下个用例重新走平台消息加载（首个用例已验证可用）。
  tearDown(() => rootBundle.evict('assets/musice-back1.lrc'));

  group('parseLrc', () {
    test('双格式解析：JSON 行 + [mm:ss.ss] 标准行，按时间排序', () {
      const String content = '''
{"t":0,"c":[{"tx":"作词: "},{"tx":"陆菱纱"}]}
{"t":1000,"c":[{"tx":"作曲: "},{"tx":"生命树"}]}
[00:14.84]翻唱：锦零
[00:25.21]是不是
[01:02.34]盼你归来后对酌
''';
      final List<LyricLine> lines = parseLrc(content);
      expect(lines.length, 5);
      // JSON 行：毫秒转秒 + 多段 tx 拼接
      expect(lines[0].time, 0);
      expect(lines[0].text, '作词: 陆菱纱');
      expect(lines[1].time, 1.0);
      expect(lines[1].text, '作曲: 生命树');
      // 标准行：mm*60 + ss
      expect(lines[2].time, closeTo(14.84, 0.001));
      expect(lines[2].text, '翻唱：锦零');
      expect(lines[3].time, closeTo(25.21, 0.001));
      expect(lines[4].time, closeTo(62.34, 0.001));
    });

    test('输入乱序时按时间升序输出', () {
      final List<LyricLine> lines =
          parseLrc('[00:30.00]后出现的早行\n[00:10.00]先出现的晚行');
      expect(lines.length, 2);
      expect(lines[0].text, '先出现的晚行');
      expect(lines[1].text, '后出现的早行');
    });

    test('一行多时间戳：每个时间戳各产出一行', () {
      final List<LyricLine> lines = parseLrc('[00:10.00][00:40.00]重复句');
      expect(lines.length, 2);
      expect(lines[0].time, closeTo(10, 0.001));
      expect(lines[1].time, closeTo(40, 0.001));
      expect(lines[0].text, '重复句');
      expect(lines[1].text, '重复句');
    });

    test('空文本与解析失败行被剔除', () {
      final List<LyricLine> lines =
          parseLrc('\n[00:01.00]\n{bad json}\n[xx]无时间戳\n');
      // 复刻 Web parseLrc：JSON 行剔除空文本/解析失败行（if (text) + catch）；
      // 标准 [mm:ss] 行无该判断 → [00:01.00] 保留为空文本行
      expect(lines.length, 1);
      expect(lines.single.time, closeTo(1.0, 0.001));
      expect(lines.single.text, '');
    });
  });

  group('MusicView', () {
    testWidgets('顶栏：歌名 + 副标题 + 返回键几何（icon 左缘 16px）',
        (WidgetTester tester) async {
      await _openMusicView(tester);
      // Text.rich 的 find.text 匹配整段拼接文本：顶栏标题 + 信息区歌名各一处
      expect(find.text('眉间雪 （Cover 晴愔）'), findsNWidgets(2));
      expect(find.text('情绪音乐馆：来自网易云'), findsOneWidget);
      // 返回键：left-4(16) -ml-1(-4) + p-1(4) → 图标左缘 16
      expect(
          tester.getTopLeft(find.byType(PortenBackIcon)).dx, closeTo(16, 0.5));
    });

    testWidgets('点击舞台切换歌词视图（转盘 ↔ 歌词交叉淡入）',
        (WidgetTester tester) async {
      await _openMusicView(tester);
      // 初始：歌词层透明度 0（常驻树中但不可见，对齐 Web 双叠层）
      expect(_stageOpacity(tester, '翻唱：锦零'), 0);
      // 点击舞台区（flex-1 中央）切换
      await tester.tapAt(const Offset(400, 330));
      await tester.pumpAndSettle();
      // 歌词视图：lrc 资产加载后渲染歌词行，透明度 1
      expect(find.text('翻唱：锦零'), findsOneWidget);
      expect(_stageOpacity(tester, '翻唱：锦零'), 1);
      // 再次点击切回转盘
      await tester.tapAt(const Offset(400, 330));
      await tester.pumpAndSettle();
      expect(_stageOpacity(tester, '翻唱：锦零'), 0);
    });

    testWidgets('下一首恒不可用：点击弹「暂无更多音乐」toast，2s 后隐藏',
        (WidgetTester tester) async {
      await _openMusicView(tester);
      expect(_toastOpacity(tester), 0);
      await tester.tap(find.byWidgetPredicate(
          (Widget w) => w is PortenLucideIcon && w.name == 'skip-forward'));
      await tester.pumpAndSettle();
      expect(find.text('暂无更多音乐'), findsOneWidget);
      // 显示态：Opacity 为 1
      expect(_toastOpacity(tester), 1);
      // 2s 后自动隐藏（+ 300ms 淡出动画）
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 300));
      expect(_toastOpacity(tester), 0);
    });

    testWidgets('播放列表弹层：滑入、当前曲目「播放中」、点遮罩关闭',
        (WidgetTester tester) async {
      await _openMusicView(tester);
      await tester.tap(find.byWidgetPredicate(
          (Widget w) => w is PortenLucideIcon && w.name == 'list-music'));
      await tester.pumpAndSettle();
      expect(find.text('播放列表'), findsOneWidget);
      expect(find.text('播放中'), findsOneWidget);
      expect(find.text('没有更多音乐啦'), findsOneWidget);
      // 点击遮罩关闭
      await tester.tapAt(const Offset(400, 60));
      await tester.pumpAndSettle();
      expect(find.text('播放列表'), findsNothing);
    });

    testWidgets('进度条：音源曲目实时值未就绪时 00:00（对齐 Web 初始态）',
        (WidgetTester tester) async {
      await _openMusicView(tester);
      // 曲目 1 有音源 → 走实时值；播放未开始/元数据未加载时为 0
      expect(find.text('00:00'), findsNWidgets(2)); // 当前进度 + 总时长
      expect(find.text('极高音质'), findsOneWidget);
    });

    testWidgets('进度条：无音源曲目静态兜底 01:20 / 03:45',
        (WidgetTester tester) async {
      // 曲目 2（深海，无音源）：track.currentTime=80 / duration=225 兜底
      await _openMusicView(
        tester,
        controller: _FakeNoAudioPlayerController.new,
      );
      expect(find.text('深海 （Original Mix）'), findsNWidgets(2));
      expect(find.text('01:20'), findsOneWidget);
      expect(find.text('03:45'), findsOneWidget);
      expect(find.text('无损'), findsOneWidget);
    });

    testWidgets('返回键 pop 音乐页', (WidgetTester tester) async {
      await _openMusicView(tester);
      expect(find.byType(MusicView), findsOneWidget);
      await tester.tap(find.byType(PortenBackIcon));
      await tester.pumpAndSettle();
      expect(find.byType(MusicView), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });
  });

  group('MusicPlayerController', () {
    test('默认状态与派生 getter（canNext 恒 false、可播放列表仅含音源曲目）', () {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          musicPlayerProvider.overrideWith(_FakeMusicPlayerController.new),
        ],
      );
      addTearDown(container.dispose);
      final MusicPlayerController c =
          container.read(musicPlayerProvider.notifier);
      final MusicPlayerState s = container.read(musicPlayerProvider);
      expect(s.trackIndex, 0);
      expect(s.isPlaying, false);
      expect(s.hasUserOpened, false);
      expect(c.canPrev, false);
      expect(c.canNext, false); // 100% 复刻 Web 恒 false 现状
      expect(c.playableTracks.length, 1);
      expect(c.playableTracks.single.id, '1');
      expect(c.playableIndex, 0);
      // 曲目 1 有音源 → 走实时值；未播放/元数据未就绪时为 0（对齐 Web 初始态）
      expect(c.displayCurrentTime, 0);
      expect(c.displayDuration, 0);
      expect(c.track.title, '眉间雪');
    });

    test('真实控制器：切歌重置进度，无音源曲目静态兜底', () async {
      // 不覆写 provider：走真实控制器；isPlaying 恒 false，
      // _player 为 null，stop 空转不触达平台通道
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);
      final MusicPlayerController c =
          container.read(musicPlayerProvider.notifier);
      // 下一首 → 索引 1（深海，无音源）
      await c.next();
      expect(c.state.trackIndex, 1);
      expect(c.state.isPlaying, false);
      // 无音源：进度/时长走静态兜底
      expect(c.displayCurrentTime, 80);
      expect(c.displayDuration, 225);
      // 上限保护：继续 next 到最后一首后不再越界
      await c.next();
      await c.next();
      expect(c.state.trackIndex, 3);
      await c.next();
      expect(c.state.trackIndex, 3);
      // 播放列表选择（仅含音源的曲目 1）→ 回到索引 0
      await c.selectPlayableTrack(0);
      expect(c.state.trackIndex, 0);
    });
  });
}

/// 读取 toast 的 Opacity 透明度（可见性断言）。
double _toastOpacity(WidgetTester tester) {
  final Opacity opacity = tester.widget<Opacity>(find.ancestor(
    of: find.text('暂无更多音乐'),
    matching: find.byType(Opacity),
  ));
  return opacity.opacity;
}

/// 读取转盘/歌词叠层的 AnimatedOpacity 透明度（可见性断言）。
double _stageOpacity(WidgetTester tester, String lyricText) {
  final AnimatedOpacity opacity = tester.widget<AnimatedOpacity>(find
      .ancestor(
        of: find.text(lyricText),
        matching: find.byType(AnimatedOpacity),
      )
      .first);
  return opacity.opacity;
}
