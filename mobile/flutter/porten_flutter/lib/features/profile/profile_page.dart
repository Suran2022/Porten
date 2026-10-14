/*
 * 个人资料页（对齐 Web 端 components/profile/ProfilePage.tsx 移动端布局）。
 *
 * 结构：fixed overlay 从左滑入 translateX(-100%)→0，300ms；
 *   背景：顶部 380px 背景图 + blur 过渡层 + 渐变到白（Mock 离线：淡渐变占位）；
 *   ProfileTopBar：X 圆钮（bg-black/20）+ 心情胶囊 + 编辑资料胶囊（bg-black/10）；
 *   ProfileCard：p-5、头像 80 圆、昵称 text-xl semibold、Porten 账号 text-sm gray-500、
 *     三列统计 grid-cols-3 gap-3 mt-5、最新日记 text-xs gray-400、接收同胞通知按钮；
 *   MyShareCard：bg-white rounded-2xl p-4、内容圆角 10 border-gray-200、
 *     最新评论 bg-gray-100/80、三统计 Eye/MessageCircle/Heart w-3.5；
 *   ProfileFunctionList：白底 rounded-2xl、三项 px-4 py-3.5 ChevronRight；
 *   ProfileBottomBar：h-[4.6875rem] border-t、设置/系统消息（Mail + 未读红点 w-2）。
 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/components/porten_lucide_icons.dart';
import '../../core/components/porten_page_transitions.dart';
import '../../core/data/current_user_store.dart';
import '../../core/data/emotion_diary_mock.dart';

import 'edit_profile_page.dart';
import 'profile_data.dart';
import 'settings_page.dart';
import 'state/profile_edit_provider.dart';
import '../home/system_messages_page.dart';

/// gray-700 / gray-500 / gray-400 / gray-900 等色值统一来源。
const Color kGray900 = Color(0xFF111827);
const Color kGray800 = Color(0xFF1F2937);
const Color kGray700 = Color(0xFF374151);
const Color kGray600 = Color(0xFF4B5563);
const Color kGray500 = Color(0xFF6B7280);
const Color kGray400 = Color(0xFF9CA3AF);
const Color kGray300 = Color(0xFFD1D5DB);
const Color kGray200 = Color(0xFFE5E7EB);
const Color kGray100 = Color(0xFFF3F4F6);
const Color kGray50 = Color(0xFFF9FAFB);

/// 个人资料页（从左滑入）。
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(PortenSlideFromRightRoute<void>(
      builder: (_) => const SettingsPage(),
    ));
  }

  void _openSystemMessages(BuildContext context) {
    Navigator.of(context).push(PortenSlideFromRightRoute<void>(
      builder: (_) => const SystemMessagesPage(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  // 背景：顶部 380px 背景图（r19：BBE77103 本地资产；
                  // r21：RepaintBoundary 隔离重绘，滚动/进出页更流畅）
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: 380,
                    child: RepaintBoundary(
                      child: IgnorePointer(
                        child: Image.asset(
                          PortenProfileAssets.profileBgAsset,
                          width: double.infinity,
                          height: 380,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          gaplessPlayback: true,
                        ),
                      ),
                    ),
                  ),
                  // 背景到白渐变过渡层（对齐 Web from-white/0 via-white/30 via-60% to-white）
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: 380,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const <double>[0.0, 0.6, 1.0],
                            colors: <Color>[
                              Colors.white.withValues(alpha: 0.0),
                              Colors.white.withValues(alpha: 0.3),
                              Colors.white,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 前景内容
                  Column(
                    children: <Widget>[
                      const _ProfileTopBar(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const _ProfileCard(),
                            const SizedBox(height: 16),
                            const _MyShareCard(),
                            const SizedBox(height: 16),
                            const _ProfileFunctionList(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          _ProfileBottomBar(
            onSettingsClick: () => _openSettings(context),
            onSystemMessagesClick: () => _openSystemMessages(context),
          ),
        ],
      ),
    );
  }
}

/// 顶栏：X 圆钮（bg-black/20 32px）+ 心情/编辑资料胶囊（bg-black/10 h-8）。
class _ProfileTopBar extends StatelessWidget {
  const _ProfileTopBar();

  @override
  Widget build(BuildContext context) {
    // r21 #1：edge-to-edge 后顶栏需自行避让状态栏（对齐 Web
    // pt-[max(0.75rem,env(safe-area-inset-top))]）；背景图仍在底层铺满状态栏。
    final double topInset = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12 + topInset, 16, 12), // px-4 pt-3 pb-3
      child: Row(
        children: <Widget>[
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.2),
              ),
              child: const Center(
                child: PortenLucideIcon('x', size: 20, color: Colors.white, strokeWidth: 1.8),
              ),
            ),
          ),
          const Spacer(),
          // 心情胶囊：mood tag → 中文标签（Web ProfileTopBar
          // MOOD_LABELS 映射，未映射时回退原值）；mood 为 null 时
          // 整胶囊不渲染（Web moodLabel ? … : null）。
          Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? child) {
              final MoodOption? moodOption =
                  moodOptionOf(ref.watch(currentUserDiaryProvider).mood);
              if (moodOption == null) return const SizedBox.shrink();
              return Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const PortenLucideIcon('smile-plus',
                        size: 16, color: Colors.white, strokeWidth: 1.8),
                    const SizedBox(width: 6),
                    Text(moodOption.label,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white)),
                  ],
                ),
              );
            },
          ),
          // 编辑资料胶囊（点击进入编辑资料页，从左滑入）
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).push(PortenSlideFromLeftRoute<void>(
              builder: (_) => const EditProfilePage(),
            )),
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  PortenLucideIcon('pencil', size: 16, color: Colors.white, strokeWidth: 1.8),
                  SizedBox(width: 6),
                  Text('编辑资料',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 资料卡（对齐 ProfileCard.tsx）；昵称/性别实时读 profileEditProvider
/// （编辑资料页修改后同步回显，对齐 Web authStore.updateUser 全量回显）。
class _ProfileCard extends ConsumerWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ProfileEditState editState = ref.watch(profileEditProvider);
    return Padding(
      padding: const EdgeInsets.all(20), // p-5
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // 头像 80 圆（r19：本地资产图）
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: kGray100,
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  PortenProfileAssets.avatarAsset,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4), // pt-1
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(editState.nickname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: kGray900,
                              height: 1.3)),
                      const SizedBox(height: 4),
                      Text('Porten 账号：${PortenProfileData.portenId}',
                          style: const TextStyle(fontSize: 14, color: kGray500)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20), // mt-5
          // 三列统计 grid-cols-3 gap-3
          Row(
            children: <Widget>[
              for (int i = 0; i < 3; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: <Widget>[
                      Text(<String>[
                        '${PortenProfileData.friendCount}',
                        editState.genderLabel,
                        '${PortenProfileData.transDays}天',
                      ][i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: kGray900)),
                      const SizedBox(height: 2),
                      Text(<String>['同胞数', '性别', '跨儿时常'][i],
                          style: const TextStyle(fontSize: 12, color: kGray500)),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          const Text('最新日记', style: TextStyle(fontSize: 12, color: kGray400)),
          const SizedBox(height: 6),
          // 最新日记跟随后端数据（Web ProfileCard：latestDiary 为空 →
          // 「还没有记录过情绪哦」；情绪日记页保存/删除会同步 store）。
          Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? child) {
              final String? latestDiary =
                  ref.watch(currentUserDiaryProvider).latestDiary;
              if (latestDiary == null) {
                return const Text('还没有记录过情绪哦',
                    style: TextStyle(
                        fontSize: 14, color: kGray400, height: 1.6));
              }
              return Text(latestDiary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: kGray700, height: 1.6));
            },
          ),
          const SizedBox(height: 20),
          // 接收同胞通知按钮：h-10 rounded-full border-gray-700
          SizedBox(
            width: double.infinity,
            height: 40,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: kGray700),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  PortenLucideIcon('bell', size: 16, color: kGray700, strokeWidth: 1.8),
                  SizedBox(width: 8),
                  Text('接收同胞通知',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500, color: kGray700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 我的分享卡（对齐 MyShareCard.tsx）。
class _MyShareCard extends StatelessWidget {
  const _MyShareCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16), // p-4
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16), // rounded-2xl
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('我的分享',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, color: kGray900)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kGray200),
            ),
            padding: const EdgeInsets.all(12), // px-3 py-3
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  portenTruncate(PortenProfileData.shareContent, 140),
                  style: const TextStyle(
                      fontSize: 14, color: kGray700, height: 1.6),
                ),
                const SizedBox(height: 8),
                // 最新评论 bg-gray-100/80 px-3 py-2 rounded-lg
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: kGray100.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text.rich(
                    TextSpan(
                      style: const TextStyle(
                          fontSize: 12, color: kGray600, height: 1.6),
                      children: <InlineSpan>[
                        TextSpan(
                          text: PortenProfileData.shareCommentAuthor,
                          style: const TextStyle(
                              fontWeight: FontWeight.w500, color: kGray800),
                        ),
                        const TextSpan(text: ' · '),
                        TextSpan(
                            text: portenTruncate(
                                PortenProfileData.shareCommentContent, 70)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10), // mt-2.5
                Row(
                  children: <Widget>[
                    _Stat(icon: 'eye', value: portenFormatCount(PortenProfileData.shareViews)),
                    const SizedBox(width: 16),
                    _Stat(icon: 'message-circle', value: portenFormatCount(PortenProfileData.shareComments)),
                    const SizedBox(width: 16),
                    _Stat(icon: 'heart', value: portenFormatCount(PortenProfileData.shareLikes)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value});

  final String icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        PortenLucideIcon(icon, size: 14, color: kGray500, strokeWidth: 1.8),
        const SizedBox(width: 4),
        Text(value, style: const TextStyle(fontSize: 12, color: kGray500)),
      ],
    );
  }
}

/// 功能列表（对齐 ProfileFunctionList.tsx）。
class _ProfileFunctionList extends StatelessWidget {
  const _ProfileFunctionList();

  @override
  Widget build(BuildContext context) {
    const List<String> items = <String>['跨儿日记', '我的文件', '知识收藏'];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: items
            .map((String label) => InkWell(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14), // px-4 py-3.5
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(label,
                            style:
                                const TextStyle(fontSize: 16, color: kGray900)),
                        const PortenLucideIcon('chevron-right',
                            size: 16, color: kGray400, strokeWidth: 1.5),
                      ],
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

/// 底部栏（对齐 ProfileBottomBar.tsx）：h-[4.6875rem] border-t，设置/系统消息。
class _ProfileBottomBar extends StatelessWidget {
  const _ProfileBottomBar({
    required this.onSettingsClick,
    required this.onSystemMessagesClick,
  });

  final VoidCallback onSettingsClick;
  final VoidCallback onSystemMessagesClick;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 75, // h-[4.6875rem]
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF3F4F6))), // border-gray-100
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: <Widget>[
          const SizedBox(width: 5), // ml-[5px]
          _BarItem(
            icon: 'settings',
            label: '设置',
            onTap: onSettingsClick,
          ),
          const SizedBox(width: 36), // ml-9
          _BarItem(
            icon: 'mail',
            label: '系统消息',
            showDot: true, // Mock：存在未读
            onTap: onSystemMessagesClick,
          ),
        ],
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  const _BarItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.showDot = false,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          SizedBox(
            width: 24,
            height: 24,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Center(
                  child: PortenLucideIcon(icon,
                      size: 20, color: kGray500, strokeWidth: 1.6),
                ),
                if (showDot)
                  Positioned(
                    top: -2,
                    right: -4,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFEF4444), // red-500
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: kGray500)),
        ],
      ),
    );
  }
}
