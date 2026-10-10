/*
 * 全局 Toast（对齐 Web 端 toastStore + ToastHost）。
 *
 * Web 端实现：页面顶部浮现的黑底白字圆角条，2.5s 自动消失，
 * 多条 Toast 纵向堆叠；Flutter 实现为 Overlay 顶部插入 + 渐隐动画。
 */

import 'dart:async';

import 'package:flutter/material.dart';

import '../design/porten_colors.dart';
import '../design/porten_typography.dart';

/// 全局 Toast 入口（无需 BuildContext）。
abstract final class PortenToast {
  static OverlayEntry? _entry;
  static Timer? _timer;
  static final List<String> _queue = <String>[];

  /// 展示一条 Toast，默认 2.5s 后消失。
  static void show(String message, {Duration duration = const Duration(milliseconds: 2500)}) {
    if (message.isEmpty) return;
    _queue.add(message);
    if (_entry != null) return; // 已有 Toast 在展示，等它消失后接续队列
    _present(duration);
  }

  static void _present(Duration duration) {
    if (_queue.isEmpty) return;
    final String message = _queue.removeAt(0);
    final OverlayState? overlay = _overlayKey.currentState;
    if (overlay == null) return; // Overlay 未挂载（冷启动极早期），静默丢弃
    _entry = OverlayEntry(
      builder: (BuildContext context) => _ToastWidget(
        message: message,
        onDismissed: () {
          _removeEntry();
          if (_queue.isNotEmpty) _present(duration);
        },
      ),
    );
    overlay.insert(_entry!);
  }

  static void _removeEntry() {
    _entry?.remove();
    _entry = null;
  }

  /// 由应用根部注册 Overlay，使 Toast 可脱离 Navigator 使用。
  static final GlobalKey<OverlayState> _overlayKey = GlobalKey<OverlayState>();
  static GlobalKey<OverlayState> get overlayKey => _overlayKey;

  /// 测试/热重载兜底清理。
  static void clear() {
    _timer?.cancel();
    _queue.clear();
    _removeEntry();
  }
}

class _ToastWidget extends StatefulWidget {
  const _ToastWidget({required this.message, required this.onDismissed});

  final String message;
  final VoidCallback onDismissed;

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
    Future<void>.delayed(const Duration(milliseconds: 2500), () async {
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

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 24,
      left: 24,
      right: 24,
      child: FadeTransition(
        opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.5),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut)),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              constraints: const BoxConstraints(maxWidth: 320),
              decoration: BoxDecoration(
                color: PortenColor.gray900.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                widget.message,
                textAlign: TextAlign.center,
                style: PortenTypography.sm.copyWith(color: PortenColor.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
