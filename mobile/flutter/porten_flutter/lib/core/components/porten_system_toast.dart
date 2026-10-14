/*
 * 系统 Toast（100% 复刻 Web 端 components/SystemToast.tsx）。
 *
 * Web 结构：
 *   - 外层 fixed inset-0 z-[80] flex items-center justify-center
 *     transition-opacity duration-300（visible: opacity-100；
 *       隐藏: opacity-0 pointer-events-none）；
 *   - 内层 flex flex-col items-center justify-center gap-3 px-6 py-5
 *     text-white bg-black/70 backdrop-blur-sm rounded-[9px]
 *     min-w-[120px] transition-transform duration-300
 *     （visible: scale-100；隐藏: scale-90）；
 *   - 图标：Loader2（loading，w-7 h-7 strokeWidth 1.5，CSS 1s 线性
 *     无限旋转）/ X（error，w-7 strokeWidth 2）/ Check（success，
 *     w-7 strokeWidth 2）；文字 text-sm font-medium whitespace-nowrap。
 *
 * Flutter 侧要点：
 *   - transition 默认计时函数即 CSS ease = cubic-bezier(0.25,0.1,0.25,1)，
 *     与页面转场同曲线；
 *   - backdrop-blur-sm = blur(4px)，用 ClipRRect + BackdropFilter 复刻
 *     （先裁剪圆角再模糊，模糊被限制在圆角矩形内）；
 *   - pointer-events-none → IgnorePointer；
 *   - 自动隐藏（1500ms）由调用方按 Web 语义控制 visible 翻转，
 *     本组件只负责进出场动画。
 */

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/components/porten_lucide_icons.dart';
import '../../core/design/porten_colors.dart';

/// Toast 类型（Web ToastType）。
enum PortenSystemToastType {
  loading,
  success,
  error,
}

/// 系统 Toast（对齐 Web SystemToast）。
class PortenSystemToast extends StatefulWidget {
  const PortenSystemToast({
    super.key,
    required this.visible,
    required this.type,
    required this.text,
  });

  final bool visible;
  final PortenSystemToastType type;
  final String text;

  @override
  State<PortenSystemToast> createState() => _PortenSystemToastState();
}

class _PortenSystemToastState extends State<PortenSystemToast>
    with TickerProviderStateMixin {
  /// 进出场：300ms（opacity + scale 同参数）。
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  /// CSS transition 默认计时 = ease = cubic-bezier(0.25,0.1,0.25,1)。
  late final Animation<double> _fade =
      CurvedAnimation(parent: _controller, curve: Curves.ease);

  /// loading 图标旋转：1s 线性无限（Web animate-spin）。
  late final AnimationController _spinController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );

  bool _spinning = false;

  @override
  void initState() {
    super.initState();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(PortenSystemToast oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  void _syncAnimation() {
    if (widget.visible) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    final bool shouldSpin =
        widget.visible && widget.type == PortenSystemToastType.loading;
    if (shouldSpin != _spinning) {
      _spinning = shouldSpin;
      if (shouldSpin) {
        _spinController.repeat();
      } else {
        _spinController.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      // 隐藏态 pointer-events-none。
      child: IgnorePointer(
        ignoring: !widget.visible,
        child: Center(
          child: AnimatedBuilder(
            animation: _fade,
            builder: (BuildContext context, Widget? child) {
              final double t = _fade.value;
              return Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: Transform.scale(
                  // scale-90 → scale-100。
                  scale: 0.9 + 0.1 * t,
                  child: child,
                ),
              );
            },
            child: _buildToastBox(),
          ),
        ),
      ),
    );
  }

  Widget _buildToastBox() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(9), // rounded-[9px]
      child: BackdropFilter(
        // backdrop-blur-sm = blur(4px)。
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Container(
          constraints: const BoxConstraints(minWidth: 120), // min-w-[120px]
          padding: const EdgeInsets.symmetric(
              horizontal: 24, vertical: 20), // px-6 py-5
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7), // bg-black/70
            borderRadius: BorderRadius.circular(9),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _buildIcon(),
              const SizedBox(height: 12), // gap-3
              Text(
                widget.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis, // whitespace-nowrap
                style: const TextStyle(
                  fontSize: 14, // text-sm
                  fontWeight: FontWeight.w500, // font-medium
                  color: PortenColor.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    switch (widget.type) {
      case PortenSystemToastType.loading:
        return RotationTransition(
          turns: _spinController,
          child: const PortenLucideIcon('loader-2',
              size: 28, color: PortenColor.white, strokeWidth: 1.5),
        );
      case PortenSystemToastType.error:
        return const PortenLucideIcon('x',
            size: 28, color: PortenColor.white, strokeWidth: 2);
      case PortenSystemToastType.success:
        return const PortenLucideIcon('check',
            size: 28, color: PortenColor.white, strokeWidth: 2);
    }
  }
}
