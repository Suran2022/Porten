/*
 * 首页容器（对齐 Web 端 pages/HomePage.tsx 移动端布局）。
 *
 * 结构：body Stack 三层（内容 / 底部导航 / 加号菜单）
 *   + 三视图 IndexedStack（消息 / 资源 / 知识，状态保持）。
 * 与 Web 端一致：
 *   - 内容层限定在「状态栏下 → 底部导航上」（Web main: top-16 bottom-16），
 *     三个视图各自自带固定顶部栏（TopBar / ResourceTopBar /
 *     KnowledgeTopBar，均为 top-0 白底），容器不再额外垫顶栏；
 *   - 底部导航位于内容之上（Web fixed bottom-0 z-50）；
 *   - 加号菜单（遮罩 z-[60] + 弹层 z-[80]）位于最上层，遮罩覆盖含
 *     底部导航的全屏，点击遮罩/菜单项/再次点加号收起，切视图同步关闭
 *     （Web 中 TopBar 仅 activeView===0 渲染，菜单不跨视图残留）。
 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/components/porten_pull_to_refresh.dart';
import '../../../core/components/porten_toast.dart';
import '../../../core/data/home_mock.dart';
import '../../../core/design/porten_colors.dart';
import '../chat/chat_page.dart';
import '../knowledge/knowledge_page.dart';
import '../music/floating_music_widget.dart';
import '../music/music_playback_controller.dart';
import '../music/music_view.dart';
import '../profile/profile_page.dart';
import '../../core/components/porten_page_transitions.dart';
import '../resource/resource_page.dart';
import '../schedule/schedule_page.dart';
import '../trip/create_trip_page.dart';
import 'add_friend_page.dart';
import 'create_group_page.dart';
import 'emotion_diary_page.dart';
import 'notes_page.dart';
import 'search_page.dart';
import 'state/app_bar_config_provider.dart';
import 'widgets/bottom_nav.dart';
import 'widgets/home_message_list.dart';
import 'widgets/home_top_bar.dart';
import 'widgets/plus_menu.dart';
import 'workplace_page.dart';

/// 首页容器。
class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> {
  int _activeView = 0;
  bool _plusMenuOpen = false;

  /// 悬浮音乐转盘显隐（对齐 Web floatingWidgetVisible：退出悦音乐后显示）。
  bool _floatingWidgetVisible = false;

  /// 悬浮转盘 OverlayEntry（对齐 Web portal 到 body，位于路由之上）。
  OverlayEntry? _floatingEntry;

  /// 「悦音乐」入口点击：首次打开开始播放，后续打开保持当前状态
  /// （对齐 Web hasUserOpenedMusicRef + onMusicClick），并打开全屏音乐页。
  void _handleMusicClick() {
    ref.read(musicPlayerProvider.notifier).openMusic();
    _openMusicView();
  }

  /// 打开全屏音乐页（从右滑入，对齐 Web MusicView translate-x-full → 0）。
  void _openMusicView() {
    Navigator.of(context).push(PortenSlideFromRightRoute<void>(
      builder: (_) => const MusicView(),
    )).then((_) {
      // 退出悦音乐：显示悬浮窗，音乐继续播放（对齐 Web MusicView onClose）
      if (!mounted) return;
      _setFloatingWidgetVisible(true);
    });
  }

  void _setFloatingWidgetVisible(bool visible) {
    if (!mounted) return;
    setState(() => _floatingWidgetVisible = visible);
    if (visible) {
      _floatingEntry ??= OverlayEntry(
        builder: (_) => FloatingMusicWidget(
          visible: _floatingWidgetVisible,
          onClick: () {
            // 点击转盘重新打开音乐页（对齐 Web onClick）
            _setFloatingWidgetVisible(false);
            _openMusicView();
          },
          onClose: () {
            // 叉叉：关闭悬浮窗并停止播放（对齐 Web onClose）
            _setFloatingWidgetVisible(false);
            ref.read(musicPlayerProvider.notifier).stopPlayback();
          },
          onFadeOutComplete: () {
            // 淡出结束卸载 OverlayEntry（对齐 Web transitionend 后卸载）
            _floatingEntry?.remove();
            _floatingEntry = null;
          },
        ),
      );
      Overlay.of(context).insert(_floatingEntry!);
    }
  }

  void _handlePlusItem(String key, String label) {
    // 添加同胞/营地、创建营地 → 独立页面（均从左滑入，对齐 Web -translate-x-full）
    if (key == 'add') {
      Navigator.of(context).push(PortenSlideFromLeftRoute<void>(
        builder: (_) => const AddFriendPage(),
      ));
      return;
    }
    if (key == 'create') {
      Navigator.of(context).push(PortenSlideFromLeftRoute<void>(
        builder: (_) => const CreateGroupPage(),
      ));
      return;
    }
    // 我的日程 / 跨儿职场 → 独立页面（从右滑入，对齐 Web translate-x-full）
    if (key == 'schedule') {
      Navigator.of(context).push(PortenSlideFromRightRoute<void>(
        builder: (_) => const SchedulePage(),
      ));
      return;
    }
    if (key == 'workplace') {
      Navigator.of(context).push(PortenSlideFromRightRoute<void>(
        builder: (_) => const WorkplacePage(),
      ));
      return;
    }
    // 创建旅程 → 独立页面（从右滑入，对齐 Web translate-x-full）
    if (key == 'journey') {
      Navigator.of(context).push(PortenSlideFromRightRoute<void>(
        builder: (_) => const CreateTripPage(),
      ));
      return;
    }
    // 记笔记 → 独立页面（从右滑入，对齐 Web NotesPage translate-x-full）
    if (key == 'note') {
      Navigator.of(context).push(PortenSlideFromRightRoute<void>(
        builder: (_) => const NotesPage(),
      ));
      return;
    }
    // 情绪日记 → 独立页面（从右滑入，对齐 Web EmotionDiaryPage
    // translate-x-full；历史页为页内覆盖层 z-[78]）
    if (key == 'mood') {
      Navigator.of(context).push(PortenSlideFromRightRoute<void>(
        builder: (_) => const EmotionDiaryPage(),
      ));
      return;
    }
    PortenToast.show('$label功能即将上线，敬请期待');
  }

  void _openProfile() {
    Navigator.of(context).push(PortenSlideFromLeftRoute<void>(
      builder: (_) => const ProfilePage(),
    ));
  }

  void _openSearch() {
    Navigator.of(context).push(PortenSlideFromRightRoute<void>(
      builder: (_) => const SearchPage(),
    ));
  }

  void _openChat(PortenConversation conversation) {
    Navigator.of(context).push(PortenSlideFromRightRoute<void>(
      builder: (_) => ChatPage(conversation: conversation),
    ));
  }

  /// 底部导航切换：同步关闭加号菜单（对齐 Web——TopBar 仅
  /// activeView===0 时渲染，切视图即随顶栏卸载，菜单不跨视图残留）。
  void _handleNavChange(int index) {
    setState(() {
      _activeView = index;
      _plusMenuOpen = false;
    });
  }

  @override
  void dispose() {
    _floatingEntry?.remove();
    _floatingEntry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 手动避开状态栏/底部安全区（原 bottomNavigationBar 槽位改入 body Stack，
    // 使加号菜单遮罩可覆盖含底部导航的全屏，对齐 Web z-[60] > z-50）
    final double padTop = MediaQuery.paddingOf(context).top;
    final double navTotal = 64 + MediaQuery.paddingOf(context).bottom; // h-16 + 安全区

    return Scaffold(
      backgroundColor: PortenColor.white,
      body: Stack(
        children: <Widget>[
          // 内容层：状态栏下 → 底部导航上（对齐 Web main: top-16 bottom-16）
          Positioned(
            top: padTop,
            left: 0,
            right: 0,
            bottom: navTotal,
            child: IndexedStack(
              index: _activeView,
              children: <Widget>[
                // 消息视图：TopBar（h-16）+ 搜索栏 + 消息列表（max-w-md 居中限宽）
                Column(
                  children: <Widget>[
                    HomeTopBar(
                      onPlus: () =>
                          setState(() => _plusMenuOpen = !_plusMenuOpen),
                      onAvatar: _openProfile,
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints:
                              const BoxConstraints(maxWidth: 448), // max-w-md
                          child: PortenPullToRefresh(
                            onRefresh: () async {
                              // Mock 数据源：模拟刷新耗时（对齐 Web minDuration 600ms）
                              await Future<void>.delayed(
                                  const Duration(milliseconds: 400));
                            },
                            child: SingleChildScrollView(
                              child: Column(
                                children: <Widget>[
                                  HomeSearchBar(onTap: _openSearch),
                                  HomeMessageList(
                                    onOpenChat: _openChat,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // 资源视图（自带 ResourceTopBar）
                const ResourcePage(),
                // 知识视图（自带 KnowledgeTopBar）
                const KnowledgePage(),
              ],
            ),
          ),
          // 底部导航（fixed bottom-0 z-50；内容之上、菜单遮罩之下）
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: PortenBottomNav(
                activeIndex: _activeView,
                onChange: _handleNavChange,
                // 应用栏管理开关控制「悦音乐」入口显隐（对齐 Web HomePage）
                showMusic: ref.watch(appBarConfigProvider).showMusic,
                onMusicClick: _handleMusicClick,
              ),
            ),
          ),
          // 加号菜单（遮罩全屏含状态栏与底部导航；弹层锚定加号按钮组下方）
          if (_plusMenuOpen)
            PortenPlusMenu(
              open: _plusMenuOpen,
              // 消息顶栏(60)内按钮组底(50) + mt-2(8)
              menuTop: padTop + 58,
              onClose: () => setState(() => _plusMenuOpen = false),
              onItem: _handlePlusItem,
            ),
        ],
      ),
    );
  }
}
