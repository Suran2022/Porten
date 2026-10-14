/*
 * 悬浮音乐转盘（100% 复刻 Web 端 components/music/FloatingMusicWidget.tsx）。
 *
 * Web 端实现要点：
 *   - 退出悦音乐全屏页后显示，点击转盘重新打开音乐页，右上角叉叉关闭并停止播放；
 *   - 56px 可拖动转盘，初始位置 (16, 120)，拖动阈值 4px（未拖动视为点击），
 *     位置限制在视口内（[8, W-56-8] × [8, H-56-8]）；
 *   - 显隐：300ms 透明度过渡（Web rendered/shown 双状态 + transitionend 卸载）；
 *   - 转盘：radial-gradient(#1a1a1a 60% → #050505) + 0 6px 16px 黑阴影，
 *     中心封面 16% inset 随播放 16s 匀速旋转，6px 中心孔；
 *   - 叉叉：-top-1.5 -right-1.5，20px 黑 80% 圆角 + shadow-md，
 *     X 图标 12px strokeWidth 2.5，active:scale-90。
 *
 * App 端承载：由 HomeView 以 OverlayEntry 插入根 Overlay（对齐 Web portal 到
 * body，位于路由之上）；visible 由 HomeView 驱动，淡出结束后经
 * onFadeOutComplete 回调移除 OverlayEntry（对齐 Web transitionend 卸载）。
 */

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/components/porten_lucide_icons.dart';
import 'music_playback_controller.dart';

/// 悬浮音乐转盘。
class FloatingMusicWidget extends ConsumerStatefulWidget {
  const FloatingMusicWidget({
    super.key,
    required this.visible,
    required this.onClick,
    required this.onClose,
    this.onFadeOutComplete,
  });

  /// 是否可见（HomeView 状态驱动）。
  final bool visible;

  /// 点击转盘重新打开音乐页。
  final VoidCallback onClick;

  /// 叉叉：关闭悬浮窗并停止播放。
  final VoidCallback onClose;

  /// 淡出动画结束（Web transitionend 后卸载）。
  final VoidCallback? onFadeOutComplete;

  @override
  ConsumerState<FloatingMusicWidget> createState() =>
      _FloatingMusicWidgetState();
}

class _FloatingMusicWidgetState extends ConsumerState<FloatingMusicWidget> {
  /// 转盘直径（Web WIDGET = 56）。
  static const double _kWidget = 56;

  /// 初始位置（Web {x: 16, y: 120}）。
  Offset _pos = const Offset(16, 120);

  /// 显隐（Web shown；插入后下一帧置 true 触发淡入）。
  bool _shown = false;

  Offset? _dragStart;
  Offset _dragOrig = Offset.zero;
  bool _moved = false;
  Size _screenSize = Size.zero;

  @override
  void initState() {
    super.initState();
    if (widget.visible) _showAfterFrame();
  }

  @override
  void didUpdateWidget(FloatingMusicWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) {
      _showAfterFrame();
    } else if (!widget.visible && oldWidget.visible) {
      setState(() => _shown = false);
    }
  }

  void _showAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.visible) setState(() => _shown = true);
    });
  }

  void _onPanStart(DragStartDetails d) {
    _dragStart = d.localPosition;
    _dragOrig = _pos;
    _moved = false;
    _screenSize = MediaQuery.sizeOf(context);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final Offset? start = _dragStart;
    if (start == null) return;
    final double dx = d.localPosition.dx - start.dx;
    final double dy = d.localPosition.dy - start.dy;
    // 拖动阈值 4px（Web |dx|>4 || |dy|>4）
    if (dx.abs() > 4 || dy.abs() > 4) _moved = true;
    // 限制在视口内（Web [8, W-56-8] × [8, H-56-8]）
    final double maxX = math.max(8, _screenSize.width - _kWidget - 8);
    final double maxY = math.max(8, _screenSize.height - _kWidget - 8);
    setState(() {
      _pos = Offset(
        (_dragOrig.dx + dx).clamp(8, maxX),
        (_dragOrig.dy + dy).clamp(8, maxY),
      );
    });
  }

  void _onPanEnd() {
    final bool moved = _moved;
    _dragStart = null;
    _moved = false;
    // 未拖动则视为点击，打开音乐页（Web handlePointerUp）
    if (!moved) widget.onClick();
  }

  @override
  Widget build(BuildContext context) {
    final bool spinning = ref.watch(musicPlayerProvider).isPlaying;
    return Positioned(
      left: _pos.dx,
      top: _pos.dy,
      child: AnimatedOpacity(
        opacity: _shown ? 1 : 0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
        onEnd: () {
          if (!_shown) widget.onFadeOutComplete?.call();
        },
        child: SizedBox(
          width: _kWidget,
          height: _kWidget,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              // 转盘：可拖动
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: (_) => _onPanEnd(),
                  onPanCancel: _onPanEnd,
                  child: _buildVinyl(spinning),
                ),
              ),
              // 右上角叉叉：-top-1.5 -right-1.5
              Positioned(
                top: -6,
                right: -6,
                child: _CloseButton(onTap: widget.onClose),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVinyl(bool spinning) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // radial-gradient(circle at 50% 50%, #1a1a1a 60%, #050505 100%)
        gradient: const RadialGradient(
          colors: <Color>[Color(0xFF1A1A1A), Color(0xFF050505)],
          stops: <double>[0.6, 1],
          radius: 0.7071,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x80000000), // rgba(0,0,0,0.5)
            offset: Offset(0, 6),
            blurRadius: 16,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.96), // inset 16%（56 × 0.16）
        child: _SpinSlow(
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
                // 中心孔 6px
                Center(
                  child: Container(
                    width: 6,
                    height: 6,
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

/// 叉叉关闭按钮（20px 黑 80% 圆角 + shadow-md + active:scale-90）。
class _CloseButton extends StatefulWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1, // active:scale-90
        duration: const Duration(milliseconds: 150),
        curve: Curves.ease,
        child: Container(
          width: 20, // w-5
          height: 20, // h-5
          decoration: BoxDecoration(
            color: const Color(0xCC000000), // bg-black/80
            shape: BoxShape.circle, // rounded-full
            boxShadow: const <BoxShadow>[
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
          child: const Center(
            child: PortenLucideIcon('x',
                size: 12, // w-3 h-3
                color: Color(0xFFFFFFFF),
                strokeWidth: 2.5),
          ),
        ),
      ),
    );
  }
}

/// 播放时 16s 匀速旋转（Web animate-spin-slow）；暂停时静止（角度归零，
/// 与 Web 移除动画类后的表现一致）。
class _SpinSlow extends StatelessWidget {
  const _SpinSlow({required this.spinning, required this.child});

  final bool spinning;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!spinning) return child;
    return _SpinSlowAnim(child: child);
  }
}

class _SpinSlowAnim extends StatefulWidget {
  const _SpinSlowAnim({required this.child});

  final Widget child;

  @override
  State<_SpinSlowAnim> createState() => _SpinSlowAnimState();
}

class _SpinSlowAnimState extends State<_SpinSlowAnim>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 16),
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
