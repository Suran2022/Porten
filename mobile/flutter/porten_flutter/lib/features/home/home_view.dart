/*
 * 首页容器（对齐 Web 端 pages/HomePage.tsx 移动端布局）。
 *
 * 结构：三视图 IndexedStack（消息 / 资源 / 知识，状态保持）
 *   + 底部导航（BottomNav，fixed bottom-0 h-16）。
 * 与 Web 端一致：三个视图各自自带固定顶部栏（TopBar / ResourceTopBar /
 * KnowledgeTopBar，均为 top-0 h-16 白底），容器不再额外垫顶栏。
 */

import 'package:flutter/material.dart';

import '../../../core/components/porten_pull_to_refresh.dart';
import '../../../core/components/porten_toast.dart';
import '../../../core/data/home_mock.dart';
import '../../../core/design/porten_colors.dart';
import '../chat/chat_page.dart';
import '../knowledge/knowledge_page.dart';
import '../profile/profile_page.dart';
import '../../core/components/porten_page_transitions.dart';
import '../resource/resource_page.dart';
import 'add_friend_page.dart';
import 'create_group_page.dart';
import 'search_page.dart';
import 'widgets/bottom_nav.dart';
import 'widgets/home_message_list.dart';
import 'widgets/home_top_bar.dart';
import 'widgets/plus_menu.dart';

/// 首页容器。
class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  int _activeView = 0;
  bool _plusMenuOpen = false;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PortenColor.white,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: <Widget>[
            IndexedStack(
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
            // 加号菜单（遮罩 + 黑色弹层，锚定顶栏下方）
            if (_plusMenuOpen)
              Positioned(
                top: 60 + 8, // 顶栏底 + mt-2
                left: 0,
                right: 0,
                bottom: 0,
                child: PortenPlusMenu(
                  open: _plusMenuOpen,
                  onClose: () => setState(() => _plusMenuOpen = false),
                  onItem: _handlePlusItem,
                ),
              ),
          ],
        ),
      ),
      // 底部导航（含底部安全区）
      bottomNavigationBar: SafeArea(
        top: false,
        child: PortenBottomNav(
          activeIndex: _activeView,
          onChange: (int index) => setState(() => _activeView = index),
        ),
      ),
    );
  }
}
