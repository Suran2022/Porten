/*
 * 首页搜索栏 + 消息列表（100% 对齐 Web 端 SearchBar.tsx / MessageList.tsx /
 * MessageCard.tsx / PortenPartnerCard.tsx / TripAssistantCard.tsx）。
 *
 * 消息列表结构：
 *   会话卡片（px-4 py-3，头像48 + 名称/未读徽标 + 最后消息/时间）
 *   → Porten伙伴入口卡片（始终展示）
 *   → 我的旅程入口卡片（始终展示）；
 *   会话卡片支持左滑操作（隐藏 / 重要 / 置顶，80px/项，隐藏支持全滑提交）。
 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/components/porten_avatar.dart';
import '../../../core/components/porten_page_transitions.dart';
import '../../../core/components/porten_lucide_icons.dart';
import '../../../core/components/porten_toast.dart';
import '../../../core/data/home_mock.dart';
import '../../../core/data/trip_controller.dart';
import '../../../core/data/trip_store.dart';
import '../../../core/design/porten_colors.dart';
import '../../../core/design/porten_typography.dart';
import '../state/home_providers.dart';
import '../../trip/trip_page.dart';
import 'swipe_row.dart';


/// 可按压容器：按住时显示浅背景（对齐 Web 端 active:bg-gray-50 变色，
/// 非 Material 水波纹）；支持点击与长按。
class _Pressable extends StatefulWidget {
  const _Pressable({
    required this.child,
    required this.onTap,
    this.pressedColor,
    this.onLongPress,
  });

  final Widget child;
  final VoidCallback onTap;

  /// 按压态背景色（Web 端 active:bg-*）。
  final Color? pressedColor;
  final VoidCallback? onLongPress;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onLongPressEnd: (_) => setState(() => _pressed = false),
      onLongPressCancel: () => setState(() => _pressed = false),
      child: Container(
        color: _pressed
            ? (widget.pressedColor ??
                PortenColor.gray50.withValues(alpha: 0.5))
            : null,
        child: widget.child,
      ),
    );
  }
}

/// 首页搜索栏（对齐 SearchBar.tsx）。
class HomeSearchBar extends StatelessWidget {
  const HomeSearchBar({super.key, this.onTap});

  /// 点击搜索栏回调（打开搜索页）。
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12), // px-4 py-3
      child: GestureDetector(
        onTap: onTap ?? () => PortenToast.show('搜索功能即将上线，敬请期待'),
        child: Container(
          height: 40, // h-10
          padding: const EdgeInsets.symmetric(horizontal: 12), // px-3
          decoration: BoxDecoration(
            color: PortenColor.gray100.withValues(alpha: 0.6), // gray-100/60
            borderRadius: BorderRadius.circular(6), // rounded-md
          ),
          child: Row(
            children: <Widget>[
              const PortenLucideIcon('search',
                  size: 16, color: PortenColor.gray400, strokeWidth: 1.8),
              const SizedBox(width: 8), // gap-2
              Text(
                '搜索同胞/营地/图片…',
                style: PortenTypography.sm.copyWith(color: PortenColor.gray400),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 首页消息列表（对齐 MessageList.tsx）。
class HomeMessageList extends ConsumerWidget {
  const HomeMessageList({super.key, this.onOpenChat});

  /// 会话点击回调（打开聊天页，携带完整会话）。
  final void Function(PortenConversation conversation)? onOpenChat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final HomeConversationsState state = ref.watch(homeConversationsProvider);
    final HomeConversationsController controller =
        ref.read(homeConversationsProvider.notifier);

    // 会话 + 固定入口（Porten伙伴 / 我的旅程），隐藏过滤 + 置顶优先 + 时间倒序
    final List<PortenConversation> items = state.conversations
        .where((PortenConversation c) => !state.hiddenIds.contains(c.id))
        .toList()
      ..sort((PortenConversation a, PortenConversation b) {
        final bool aPinned = state.isPinned(a.id);
        final bool bPinned = state.isPinned(b.id);
        if (aPinned != bPinned) return aPinned ? -1 : 1;
        return a.minutesAgo.compareTo(b.minutesAgo);
      });

    return Column(
      children: <Widget>[
        const PortenPartnerCard(),
        const PortenTripCard(),
        for (final PortenConversation item in items)
          SwipeRow(
            key: ValueKey<int>(item.id),
            label: item.name,
            onPin: () => controller.togglePin(item.id),
            onImportant: () => controller.toggleImportant(item.id),
            onHide: () => controller.hide(item.id),
            child: MessageCard(
              item: item,
              onTap: () => (onOpenChat ?? (_) {})(item),
            ),
          ),
      ],
    );
  }
}

/// 会话卡片（对齐 MessageCard.tsx）。
class MessageCard extends StatelessWidget {
  const MessageCard({super.key, required this.item, this.onTap});

  final PortenConversation item;

  /// 点击打开聊天页回调。
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool isGroup = item.isGroup;
    final bool hasSender = isGroup &&
        item.senderName != null &&
        item.senderName != PortenCurrentUser.nickname;
    final String lastMessage = hasSender
        ? '${item.senderName}: ${item.lastMessage}'
        : item.lastMessage;

    return _Pressable(
      onTap: onTap ?? () => PortenToast.show('聊天功能即将上线，敬请期待'),
      onLongPress: onTap ?? () => PortenToast.show('聊天功能即将上线，敬请期待'),
      pressedColor: PortenColor.gray50.withValues(alpha: 0.5), // active:bg-gray-50/50
      child: Container(
      color: PortenColor.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // px-4 py-3
      child: Row(
        children: <Widget>[
          // 头像（48）
          isGroup
              ? PortenCampAvatar(size: 48, asset: item.avatarAsset)
              : PortenFriendAvatar(
                  name: item.name, size: 48, asset: item.avatarAsset),
          const SizedBox(width: 12), // gap-3
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // 名称 + 未读徽标
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PortenTypography.base.copyWith(
                          fontWeight: FontWeight.w500,
                          color: PortenColor.gray900,
                        ),
                      ),
                    ),
                    if (item.unreadCount > 0)
                      _UnreadBadge(count: item.unreadCount),
                  ],
                ),
                const SizedBox(height: 2), // mt-0.5
                // 最后消息 + 时间
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PortenTypography.sm.copyWith(
                          color: PortenColor.gray500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8), // gap-2
                    Text(
                      formatMessageTime(item.minutesAgo),
                      style: PortenTypography.xs.copyWith(
                        color: PortenColor.gray400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

/// 未读徽标（min-w-5 h-5 rounded-full red-500 text-xs medium）。
class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final String label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      margin: const EdgeInsets.only(left: 8), // gap-2
      decoration: BoxDecoration(
        color: PortenColor.error,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: PortenColor.white,
          height: 1.0,
        ),
      ),
    );
  }
}

/// Porten 伙伴入口卡片（对齐 PortenPartnerCard.tsx 回退态）。
class PortenPartnerCard extends StatelessWidget {
  const PortenPartnerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: () => PortenToast.show('Porten伙伴功能即将上线，敬请期待'),
      pressedColor: PortenColor.gray50, // active:bg-gray-50
      child: Container(
        color: PortenColor.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: <Widget>[
            const PortenPartnerAvatar(name: kPartnerName, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          kPartnerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PortenTypography.base.copyWith(
                            fontWeight: FontWeight.w500,
                            color: PortenColor.gray900,
                          ),
                        ),
                      ),
                      if (kPartnerUnread > 0) _UnreadBadge(count: kPartnerUnread),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    kFirstAssistantName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PortenTypography.xs.copyWith(
                      color: PortenColor.gray400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 「我的旅程」入口卡片（对齐 TripAssistantCard.tsx）。
///
/// 数据源：旅程控制器（mock 读 TripStore.assistantCard / live 走
/// porten/data 桥）——创建旅程后 count 与摘要实时同步（与行程页
/// 共享同一控制器）。
class PortenTripCard extends ConsumerWidget {
  const PortenTripCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TripAssistantCard? assistant =
        ref.watch(tripControllerProvider).value?.assistant;
    final int tripCount = assistant?.count ?? 0;
    final String lastMessage = assistant?.lastMessage ?? '';
    return _Pressable(
      onTap: () => Navigator.of(context).push(PortenSlideFromRightRoute<void>(
        builder: (_) => const TripPage(),
      )),
      pressedColor: PortenColor.gray50, // active:bg-gray-50
      child: Container(
        color: PortenColor.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: <Widget>[
            // 头像：米色圆底 + 行程图标（对齐 bg-[#FDF3E6] + trip-icon）
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: PortenColor.tripSandLight,
              ),
              child: SvgPicture.asset(
                'assets/icons/porten_trip_icon.svg', // Web 端 trip-icon.svg
                width: 40, // w-10 h-10 object-contain
                height: 40,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                  // 对齐 Web 端 [标题][标签]···spacer···[徽标]：
                  // 中段（标题+标签）整体占一个紧 Expanded（标题在其内部
                  // 用 loose Flexible 截断，多余空间滞留中段末尾不可见），
                  // 徽标作为行尾不可伸缩子项，结构上必然贴右缘
                  Expanded(
                    child: Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            '我的旅程',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: PortenTypography.base.copyWith(
                              fontWeight: FontWeight.w500,
                              color: PortenColor.gray900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8), // gap-2
                        // 「行程安全」标签（rounded-md bg-green-500 text-white text-xs）
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: PortenColor.successBright,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '行程安全',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: PortenColor.white,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (tripCount > 0) ...<Widget>[
                    const SizedBox(width: 8),
                    _TripBadge(count: tripCount),
                  ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '[行程助手]：$lastMessage',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PortenTypography.sm.copyWith(
                      color: PortenColor.gray500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 行程消息徽标（对齐 TripAssistantCard：h-[18px] px-1.5 min-w-[18px] text-[11px]）。
class _TripBadge extends StatelessWidget {
  const _TripBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final String label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 6), // px-1.5
      // 不用 Container.alignment（有界约束下会撑满整行），
      // Center(widthFactor) 使容器收缩到内容宽度，仅受 minWidth 下限
      decoration: BoxDecoration(
        color: PortenColor.error,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Center(
        widthFactor: 1.0,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: PortenColor.white,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}
