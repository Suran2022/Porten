/*
 * 首页顶部栏（对齐 Web 端 components/home/TopBar.tsx 移动端结构）。
 *
 * 结构：固定顶部白底 px-4，内容行高 40、在顶栏内垂直居中；
 *   行内统一底对齐（items-end）：日记行底线 = 头像底 = 右侧图标底；
 *   左：头像(40) + 昵称(base/semibold gray-900) + 心情｜最新日记(xs gray-500)；
 *   右：联系人图标(24, 下移8px) + 加号图标(28, 下移6px)，
 *       点击热区 40×40，无水波纹（Web 端为 hover/active 变色）。
 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/components/porten_avatar.dart';
import '../../../core/components/porten_lucide_icons.dart';
import '../../../core/components/porten_toast.dart';
import '../../../core/components/porten_page_transitions.dart';
import '../../../core/data/home_mock.dart';
import '../contacts_page.dart';
import '../../../core/design/porten_colors.dart';
import '../../../core/design/porten_typography.dart';

/// 首页顶部栏。
class HomeTopBar extends ConsumerWidget {
  const HomeTopBar({super.key, this.onPlus, this.onAvatar});

  /// 加号按钮回调（展示 PlusMenu；缺省 Toast 占位）。
  final VoidCallback? onPlus;

  /// 头像/昵称区点击回调（打开个人资料页；缺省 Toast 占位）。
  final VoidCallback? onAvatar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: PortenColor.white,
      child: SizedBox(
        height: 60, // 顶部栏高度（较 h-16 微收，视觉更贴状态栏）
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16), // px-4
          // 内容基线：高 40 行内底对齐，整行在顶栏内垂直居中
          child: Center(
            child: SizedBox(
              height: 40,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  // 左：头像 + 昵称 + 心情｜最新日记（flex-1 min-w-0）
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onAvatar ??
                          () => PortenToast.show('个人主页功能即将上线，敬请期待'),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          const PortenFriendAvatar(
                            name: PortenCurrentUser.nickname,
                            size: 40, // w-10 h-10
                            asset: PortenCurrentUser.avatarAsset,
                          ),
                          const SizedBox(width: 12), // gap-3
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  PortenCurrentUser.nickname,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: PortenTypography.base.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: PortenColor.gray900,
                                    height: 1.25, // leading-tight
                                  ),
                                ),
                                SizedBox(
                                  height: 18, // mt-0.5 + 一行 xs
                                  child: Row(
                                    children: <Widget>[
                                      Text(
                                        PortenCurrentUser.mood,
                                        style: PortenTypography.xs.copyWith(
                                          color: PortenColor.gray500,
                                          height: 1.25,
                                        ),
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 4),
                                        child: Text(
                                          '｜',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: PortenColor.gray300,
                                            height: 1.25,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          PortenCurrentUser.latestDiary,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: PortenTypography.xs.copyWith(
                                            color: PortenColor.gray500,
                                            // r21：行高收紧 + 底对齐——省略号
                                            // 三点贴近行底而非垂直居中（对齐 Web）
                                            height: 1.1,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 右：联系人 + 加号（40×40 热区，无水波纹；图标底对齐日记行底）。
                  // r21：整体右移 6px（对齐 Web -mr-1.5），使加号图形右缘与
                  // 搜索框右缘对齐。
                  Transform.translate(
                    offset: const Offset(6, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                      _IconHitArea(
                        onTap: () => Navigator.of(context)
                            .push(PortenSlideFromLeftRoute<void>(
                          builder: (_) => const ContactsPage(),
                        )),
                        child: Transform.translate(
                          offset: const Offset(0, 8), // translate-y-2
                          child: const PortenLucideIcon(
                            'users',
                            size: 24, // w-6 h-6
                            color: PortenColor.gray600,
                            strokeWidth: 1.8,
                          ),
                        ),
                      ),
                      _IconHitArea(
                        onTap: onPlus ??
                            () => PortenToast.show('功能菜单即将上线，敬请期待'),
                        child: Transform.translate(
                          offset: const Offset(0, 6), // translate-y-1.5
                          child: const PortenLucideIcon(
                            'plus',
                            size: 28, // w-7 h-7
                            color: PortenColor.gray600,
                            strokeWidth: 1.8,
                          ),
                        ),
                      ),
                    ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 40×40 图标点击热区（无水波纹，对齐 Web 端 w-10 h-10 按钮）。
class _IconHitArea extends StatelessWidget {
  const _IconHitArea({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 40, // w-10 h-10
        height: 40,
        child: Center(child: child),
      ),
    );
  }
}
