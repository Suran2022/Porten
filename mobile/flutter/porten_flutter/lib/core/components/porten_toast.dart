/*
 * 全局 Toast（100% 对齐 Web 端 Toast.tsx + toastStore）。
 *
 * Web 端实现：顶部居中胶囊（fixed top-3.5 left-1/2），rounded-full，
 * bg-black/75 毛玻璃，px-4 py-2，内含 lucide 图标（w-4 h-4 strokeWidth 2）
 * + text-sm 白色文字，gap-1.5；2s 后淡出（App 端保持 2.5s 队列节奏）。
 * 图标类型：info=Info / success=Check / error=X（对齐 Web 端 ICON_MAP）。
 */

import 'dart:async';

import 'package:flutter/material.dart';

import '../design/porten_colors.dart';
import '../design/porten_typography.dart';
import 'porten_icons.dart';

/// Toast 图标类型（对齐 Web 端 ToastIcon）。
enum ToastIcon { info, success, error }

/// 全局 Toast 入口（无需 BuildContext）。
abstract final class PortenToast {
  static OverlayEntry? _entry;
  static final List<_ToastPayload> _queue = <_ToastPayload>[];

  /// 展示一条 Toast，默认 2.5s 后消失。
  static void show(
    String message, {
    ToastIcon icon = ToastIcon.info,
    Duration duration = const Duration(milliseconds: 2500),
  }) {
    if (message.isEmpty) return;
    _queue.add(_ToastPayload(message: message, icon: icon, duration: duration));
    if (_entry != null) return; // 已有 Toast 在展示，等它消失后接续队列
    _present();
  }

  static void _present() {
    if (_queue.isEmpty) return;
    final _ToastPayload payload = _queue.removeAt(0);
    final OverlayState? overlay = _overlayKey.currentState;
    if (overlay == null) return; // Overlay 未挂载（冷启动极早期），静默丢弃
    _entry = OverlayEntry(
      builder: (BuildContext context) => _ToastWidget(
        message: payload.message,
        icon: payload.icon,
        duration: payload.duration,
        onDismissed: () {
          _entry?.remove();
          _entry = null;
          if (_queue.isNotEmpty) _present();
        },
      ),
    );
    overlay.insert(_entry!);
  }

  /// 由应用根部注册 Overlay，使 Toast 可脱离 Navigator 使用。
  static final GlobalKey<OverlayState> _overlayKey = GlobalKey<OverlayState>();
  static GlobalKey<OverlayState> get overlayKey => _overlayKey;

  /// 测试/热重载兜底清理。
  static void clear() {
    _queue.clear();
    _entry?.remove();
    _entry = null;
  }
}

class _ToastPayload {
  const _ToastPayload({
    required this.message,
    required this.icon,
    required this.duration,
  });

  final String message;
  final ToastIcon icon;
  final Duration duration;
}

class _ToastWidget extends StatefulWidget {
  const _ToastWidget({
    required this.message,
    required this.icon,
    required this.duration,
    required this.onDismissed,
  });

  final String message;
  final ToastIcon icon;
  final Duration duration;
  final VoidCallback onDismissed;

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
    Future<void>.delayed(widget.duration, () async {
      if (!mounted) return;
      await _controller.reverse();
      widget.onDismissed();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _iconName => switch (widget.icon) {
        ToastIcon.success => 'check',
        ToastIcon.error => 'x',
        ToastIcon.info => 'info',
      };

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 14, // top-3.5
      left: 0,
      right: 0,
      child: FadeTransition(
        opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.5),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut)),
          child: Center(
            // 【关键】Toast 挂在 MaterialApp.builder 的 Overlay 里，
            // 位于 Navigator/Material 之外——Text 没有 DefaultTextStyle 祖先时
            // Flutter 引擎会强制绘制黄色双下划线（上轮"双黄线"的真正根因）。
            // 包一层透明 Material 提供 DefaultTextStyle，彻底根治。
            child: Material(
              type: MaterialType.transparency,
              child: Container(
              // 胶囊：px-4 py-2 rounded-full bg-black/75
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF000000).withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  LucideIcon(
                    _iconName,
                    size: 16, // w-4 h-4
                    strokeWidth: 2,
                    color: PortenColor.white,
                  ),
                  const SizedBox(width: 6), // gap-1.5
                  Text(
                    widget.message,
                    style: PortenTypography.sm.copyWith(
                      color: PortenColor.white,
                    ),
                  ),
                ],
              ),
            ),
            ),
          ),
        ),
      ),
    );
  }
}
