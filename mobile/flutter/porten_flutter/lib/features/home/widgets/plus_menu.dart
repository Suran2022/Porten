/*
 * 加号菜单（100% 移植 Web 端 home/PlusMenu.tsx）。
 *
 * 结构与动效逐条对应：
 *   - 灰色透明遮罩：fixed 全屏 z-60 bg-gray-100/60，opacity 0→1
 *     （250ms ease-out）；点击遮罩收起；遮罩后绘制故覆盖底部导航
 *     （Web 端 BottomNav 为 z-50，同样被遮罩盖住）；
 *   - 菜单弹层：锚定顶栏加号按钮组下方（absolute top-full right-0
 *     mt-2，w-max 自适应内容），bg-black rounded-2xl py-2.5，
 *     transform-origin(top right)；
 *     展开：scale 0→1 + opacity 0→1，250ms cubic-bezier(0.16,1,0.3,1)
 *     （快出缓停，Web transition-all 对 transform/opacity 同曲线）；
 *     收起：scale 1→0 + opacity 1→0，250ms cubic-bezier(0.55,0,0.85,0.36)
 *     （先慢后快缩回加号位置）；
 *     收起动效完成后 260ms 再真正移除（对齐 Web closeTimer）；
 *   - 三角指针：12×12 bg-black rotate-45，top -6，right 14（对齐加号中心）；
 *   - 菜单项：px-5 py-3 gap-3.5，图标 w-5 h-5 strokeWidth 1.8，
 *     文本 text-base white/90；
 *     菜单容器 IntrinsicWidth 等效 Web w-max（取最宽菜单项内容宽），
 *     Column(stretch) + 菜单项 Row(mainAxisSize.min) 等效 w-full 撑满；
 *     首项 rounded-t-2xl、末项 rounded-b-2xl；
 *   - 菜单项（10 项与 Web 完全一致），点击后先执行回调再 onClose()。
 */

import 'package:flutter/material.dart';

import '../../../core/components/porten_lucide_icons.dart';
import '../../../core/design/porten_colors.dart';

/// 菜单项定义。
class _PlusMenuItem {
  const _PlusMenuItem(this.key, this.label, this.icon);

  final String key;
  final String label;
  final String icon;
}

const List<_PlusMenuItem> _kMenuItems = <_PlusMenuItem>[
  _PlusMenuItem('add', '添加同胞/营地', 'user-plus'),
  _PlusMenuItem('create', '创建营地', 'users'),
  _PlusMenuItem('agreement', '创建约定', 'calendar-check'),
  _PlusMenuItem('journey', '创建旅程', 'map'),
  _PlusMenuItem('schedule', '我的日程', 'calendar-days'),
  _PlusMenuItem('finance', '跨儿财务', 'wallet'),
  _PlusMenuItem('workplace', '跨儿职场', 'briefcase'),
  _PlusMenuItem('scan', '扫一扫', 'scan-line'),
  _PlusMenuItem('note', '记笔记', 'sticky-note'),
  _PlusMenuItem('mood', '情绪日记', 'heart'),
];

/// 加号菜单。
class PortenPlusMenu extends StatefulWidget {
  const PortenPlusMenu({
    super.key,
    required this.open,
    required this.onClose,
    required this.menuTop,
    this.onItem,
  });

  final bool open;
  final VoidCallback onClose;

  /// 弹层顶坐标（屏幕坐标）：消息顶栏内按钮组底 + mt-2。
  final double menuTop;

  /// 菜单项回调（携带 item.key 与标签），执行后自动收起。
  final void Function(String key, String label)? onItem;

  @override
  State<PortenPlusMenu> createState() => _PortenPlusMenuState();
}

class _PortenPlusMenuState extends State<PortenPlusMenu>
    with SingleTickerProviderStateMixin {
  bool _visible = false;
  bool _entering = false;

  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );

  @override
  void initState() {
    super.initState();
    _ctrl.addStatusListener((AnimationStatus status) {
      if (status != AnimationStatus.dismissed) return;
      // 收起动效完成后再真正移除（对齐 Web closeTimer 260ms）
      Future<void>.delayed(const Duration(milliseconds: 260), () {
        if (!mounted || widget.open) return;
        setState(() => _visible = false);
      });
    });
    // 组件可能以 open=true 首次插入（外层条件构建），initState 也要走展开逻辑
    if (widget.open) _handleOpen();
  }

  void _handleOpen() {
    setState(() => _visible = true);
    // 双帧后进入展开态（对齐 Web requestAnimationFrame ×2）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _entering = true);
        _ctrl.forward(from: 0);
      });
    });
  }

  @override
  void didUpdateWidget(PortenPlusMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open == oldWidget.open) return;
    if (widget.open) {
      _handleOpen();
    } else {
      setState(() {
        _entering = false;
      });
      _ctrl.reverse(from: _ctrl.value);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    // 动画控制器逐 tick 必须驱动重建：AnimationController 不是隐式动画，
    // 不会自行 setState。若仅在 build 里裸读 _ctrl.value，控制器后续 tick
    // 不触发重建，菜单将永远停在展开前的 scale 0 / opacity 0（完全不可见）。
    // AnimatedBuilder 监听 _ctrl，每次 tick 重建弹层（菜单子树不依赖动画值，
    // 作为静态 child 传入，避免逐帧重建 10 个菜单项）。
    return AnimatedBuilder(
      animation: _ctrl,
      child: _buildMenu(),
      builder: (BuildContext context, Widget? child) {
        final double t = _ctrl.value;
        final bool expanding = _entering;
        // Web transition-all：transform 与 opacity 共用同一 timing function。
        // 展开 cubic-bezier(0.16,1,0.3,1)（快出缓停）；
        // 收起 cubic-bezier(0.55,0,0.85,0.36)（先慢后快，缩回加号位置）。
        // 收起时 _ctrl.value 1→0，曲线对 value 直接取值：1→1、0→0。
        final double eased = (expanding
                ? const Cubic(0.16, 1, 0.3, 1).transform(t)
                : const Cubic(0.55, 0, 0.85, 0.36).transform(t))
            .clamp(0.0, 1.0);
        // 遮罩独立过渡：opacity 250ms ease-out（展开收起同曲线）
        final double overlayOpacity = Curves.easeOut.transform(t).clamp(0.0, 1.0);

        return Stack(
          children: <Widget>[
            // 灰色遮罩（fixed inset-0 z-[60] bg-gray-100/60，点击关闭）
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onClose,
                child: ColoredBox(
                  color: PortenColor.gray100.withValues(alpha: 0.6 * overlayOpacity),
                ),
              ),
            ),
            // 菜单弹层（absolute top-full right-0 mt-2，z-[80]）
            Positioned(
              top: widget.menuTop,
              right: 10, // 按钮组 -mr-1.5：16 - 6 = 屏幕右缘 10px
              child: Transform.scale(
                scale: eased,
                alignment: Alignment.topRight, // transform-origin: top right
                child: Opacity(
                  opacity: eased,
                  child: child,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMenu() {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        // IntrinsicWidth 等效 Web w-max：容器宽 = 最宽菜单项的内容宽
        IntrinsicWidth(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16), // rounded-2xl
            ),
            padding: const EdgeInsets.symmetric(vertical: 10), // py-2.5
            child: Column(
              mainAxisSize: MainAxisSize.min,
              // stretch + 菜单项 Row(min) 等效 Web「w-max 容器 + w-full 项」
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (int i = 0; i < _kMenuItems.length; i++)
                  _menuItem(_kMenuItems[i], i),
              ],
            ),
          ),
        ),
        // 三角指针（对齐加号按钮中心）
        Positioned(
          top: -6,
          right: 14,
          child: Transform.rotate(
            angle: 3.14159 / 4,
            child: Container(width: 12, height: 12, color: Colors.black),
          ),
        ),
      ],
    );
  }

  Widget _menuItem(_PlusMenuItem item, int index) {
    final bool first = index == 0;
    final bool last = index == _kMenuItems.length - 1;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        widget.onItem?.call(item.key, item.label);
        widget.onClose();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.vertical(
            top: first ? const Radius.circular(16) : Radius.zero,
            bottom: last ? const Radius.circular(16) : Radius.zero,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            PortenLucideIcon(
              item.icon,
              size: 20, // w-5 h-5
              color: Colors.white.withValues(alpha: 0.9), // text-white/90
              strokeWidth: 1.8,
            ),
            const SizedBox(width: 14), // gap-3.5
            Text(
              item.label,
              style: TextStyle(
                fontSize: 16, // text-base
                height: 1.0,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
