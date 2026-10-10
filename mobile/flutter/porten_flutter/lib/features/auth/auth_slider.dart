/*
 * 认证滑块容器（对齐 Web 端 AuthSlider）。
 *
 * Web 端实现：200% 宽度容器内并排放置登录页与注册页，
 * 通过 translateX(±50%) 切换，过渡 500ms cubic-bezier(0.25,0.1,0.25,1)；
 * 支持在页面空白处左右滑动手势切换。
 *
 * Flutter 实现：水平位移动画 + GestureDetector 横滑（阈值 80dp）。
 */

import 'package:flutter/material.dart';

/// 认证滑块当前页。
enum AuthSlide { login, register }

class AuthSlider extends StatefulWidget {
  const AuthSlider({
    super.key,
    required this.loginPage,
    required this.registerPage,
  });

  final Widget loginPage;
  final Widget registerPage;

  @override
  State<AuthSlider> createState() => AuthSliderState();
}

class AuthSliderState extends State<AuthSlider>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  static const Curve _curve = Cubic(0.25, 0.1, 0.25, 1);

  AuthSlide _current = AuthSlide.login;

  /// 外部（如页面内按钮）切换到注册页。
  void goToRegister() {
    if (_current == AuthSlide.register) return;
    setState(() => _current = AuthSlide.register);
    _controller.forward();
  }

  /// 外部切换回登录页。
  void goToLogin() {
    if (_current == AuthSlide.login) return;
    setState(() => _current = AuthSlide.login);
    _controller.reverse();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final double vx = details.velocity.pixelsPerSecond.dx;
    if (_current == AuthSlide.login && vx < -300) {
      goToRegister();
    } else if (_current == AuthSlide.register && vx > 300) {
      goToLogin();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, _) {
          final double t = _curve.transform(_controller.value);
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              // 登录页：静止；注册页从右侧滑入覆盖（translateX 等价实现）。
              widget.loginPage,
              if (t > 0)
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: MediaQuery.sizeOf(context).width * (1 - t),
                  width: MediaQuery.sizeOf(context).width,
                  child: widget.registerPage,
                ),
            ],
          );
        },
      ),
    );
  }
}
