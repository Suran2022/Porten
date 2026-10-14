/*
 * 底部导航（100% 对齐 Web 端 components/home/BottomNav.tsx）。
 *
 * 结构：固定底部 h-16 白底，内部 px-2 justify-around；
 *   图标 24px strokeWidth≈1.8、文字 xs（12px）；
 *   激活态：图标蓝→粉渐变 + 文字品牌渐变 medium，非激活 gray-400；
 *   消息 Tab 显示未读徽标（red-500 圆角、>99 显示 99+）；
 *   切换时图标 300ms 弹跳（animate-bounce-icon）；
 *   showMusic 开启时追加「悦音乐」入口（Music2 图标，点击不切视图，
 *   走 onMusicClick，对齐 Web）。
 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/components/porten_gradient_widgets.dart';
import '../../../core/components/porten_lucide_icons.dart';
import '../../../core/design/porten_colors.dart';
import '../../../core/design/porten_typography.dart';
import '../state/home_providers.dart';

/// 底部 Tab 定义。
class _NavTab {
  const _NavTab(this.label, this.icon, {this.isMusic = false});

  final String label;
  final String icon; // lucide 图标名

  /// 「悦音乐」入口：点击不切换视图，回调 onMusicClick（对齐 Web）。
  final bool isMusic;
}

const List<_NavTab> _kBaseTabs = <_NavTab>[
  _NavTab('消息', 'message-square'),
  _NavTab('资源', 'folder-open'),
  _NavTab('知识', 'book-open'),
];

/// 「悦音乐」入口（对齐 Web musicTab：Music2 图标）。
const _NavTab _kMusicTab = _NavTab('悦音乐', 'music2', isMusic: true);

/// 底部导航栏。
class PortenBottomNav extends ConsumerStatefulWidget {
  const PortenBottomNav({
    super.key,
    required this.activeIndex,
    required this.onChange,
    this.showMusic = false,
    this.onMusicClick,
  });

  final int activeIndex;
  final ValueChanged<int> onChange;

  /// 应用栏管理开关：开启后底部栏追加「悦音乐」入口（对齐 Web）。
  final bool showMusic;
  final VoidCallback? onMusicClick;

  @override
  ConsumerState<PortenBottomNav> createState() => _PortenBottomNavState();
}

class _PortenBottomNavState extends ConsumerState<PortenBottomNav>
    with TickerProviderStateMixin {
  final Map<int, AnimationController> _bounceControllers =
      <int, AnimationController>{};

  AnimationController? _controllerFor(int index) {
    _bounceControllers[index]?.dispose();
    final AnimationController controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _bounceControllers[index] = controller;
    return controller;
  }

  @override
  void dispose() {
    for (final AnimationController c in _bounceControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _handleTap(int index, _NavTab tab) {
    // 「悦音乐」入口：不切换视图，走 onMusicClick 回调（对齐 Web handleClick）
    if (tab.isMusic) {
      widget.onMusicClick?.call();
      final AnimationController? controller = _controllerFor(index);
      controller?.forward(from: 0);
      return;
    }
    if (index == widget.activeIndex) return;
    widget.onChange(index);
    final AnimationController? controller = _controllerFor(index);
    controller?.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final int totalUnread = ref.watch(totalUnreadProvider);
    // showMusic 开启时追加「悦音乐」入口（对齐 Web tabs 动态拼接）
    final List<_NavTab> tabs =
        widget.showMusic ? <_NavTab>[..._kBaseTabs, _kMusicTab] : _kBaseTabs;
    return Material(
      color: PortenColor.white,
      child: SizedBox(
        height: 64, // h-16
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8), // px-2
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              for (int i = 0; i < tabs.length; i++)
                _buildTab(i, tabs[i], totalUnread),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTab(int index, _NavTab tab, int totalUnread) {
    final bool isActive = index == widget.activeIndex;
    final bool showBadge = index == 0 && totalUnread > 0;
    final AnimationController? bounce = _bounceControllers[index];
    final Widget icon = AnimatedScale(
      scale: bounce != null && bounce.isAnimating ? 1.15 : 1.0,
      duration: const Duration(milliseconds: 120),
      child: isActive
          // 激活态：图标蓝→粉渐变（对齐 url(#portenIconGradient)）
          ? ShaderMask(
              shaderCallback: (Rect bounds) => const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: <Color>[PortenColor.brandBlue, PortenColor.brandPink],
              ).createShader(bounds),
              blendMode: BlendMode.srcIn,
              child: PortenLucideIcon(tab.icon, size: 24, strokeWidth: 1.8),
            )
          : PortenLucideIcon(
              tab.icon,
              size: 24, // w-6 h-6
              color: PortenColor.gray400,
              strokeWidth: 1.8,
            ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _handleTap(index, tab),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              icon,
              if (showBadge)
                Positioned(
                  top: -4, // -top-1
                  right: -8, // -right-2
                  child: _UnreadBadge(count: totalUnread),
                ),
            ],
          ),
          const SizedBox(height: 2), // gap-0.5
          // 文字：激活态品牌渐变 medium，非激活 gray-400
          if (isActive)
            PortenGradientText(
              child: Text(
                tab.label,
                style: PortenTypography.xs.copyWith(
                  fontWeight: FontWeight.w500,
                  color: PortenColor.white,
                ),
              ),
            )
          else
            Text(tab.label, style: PortenTypography.xs.copyWith(color: PortenColor.gray400)),
        ],
      ),
    );
  }
}

/// 未读徽标（min-w-4 h-4 圆角、text-[10px] medium）。
class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final String label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 16),
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: PortenColor.error,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: PortenColor.white,
          height: 1.0,
        ),
      ),
    );
  }
}
