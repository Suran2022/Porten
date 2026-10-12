/*
 * 页面级转场（对齐 Web 端 fixed overlay + translateX 滑入模式）：
 * 300ms cubic-bezier(0.25, 0.1, 0.25, 1)。
 *
 * Web 端各页面进场方向：
 *   个人资料 translateX(-100%)（从左）；
 *   设置 / 系统消息 / 搜索 / 聊天 translate-x-full（从右）；
 *   添加同胞/营地、组建营地 -translate-x-full（从左）。
 * 离场即反向滑出，与 Web 一致。
 */

import 'package:flutter/material.dart';

const Duration kPortenPageTransitionDuration = Duration(milliseconds: 300);
const Cubic kPortenPageTransitionCurve = Cubic(0.25, 0.1, 0.25, 1);

/// 从左滑入（个人资料 / 添加同胞 / 组建营地）。
class PortenSlideFromLeftRoute<T> extends PageRouteBuilder<T> {
  PortenSlideFromLeftRoute({required WidgetBuilder builder})
      : super(
          opaque: true,
          transitionDuration: kPortenPageTransitionDuration,
          reverseTransitionDuration: kPortenPageTransitionDuration,
          pageBuilder: (BuildContext context, _, _) =>
              Scaffold(backgroundColor: Colors.white, body: builder(context)),
          transitionsBuilder: (BuildContext context, Animation<double> anim,
              Animation<double> _, Widget child) {
            final Animation<double> curved = CurvedAnimation(
                parent: anim, curve: kPortenPageTransitionCurve);
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(-1, 0),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            );
          },
        );
}

/// 从右滑入（设置 / 系统消息 / 搜索 / 聊天）。
class PortenSlideFromRightRoute<T> extends PageRouteBuilder<T> {
  PortenSlideFromRightRoute({required WidgetBuilder builder})
      : super(
          opaque: true,
          transitionDuration: kPortenPageTransitionDuration,
          reverseTransitionDuration: kPortenPageTransitionDuration,
          pageBuilder: (BuildContext context, _, _) =>
              Scaffold(backgroundColor: Colors.white, body: builder(context)),
          transitionsBuilder: (BuildContext context, Animation<double> anim,
              Animation<double> _, Widget child) {
            final Animation<double> curved = CurvedAnimation(
                parent: anim, curve: kPortenPageTransitionCurve);
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            );
          },
        );
}
