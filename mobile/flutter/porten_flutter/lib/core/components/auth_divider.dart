/*
 * 认证页分隔行（100% 对齐 Web 端 AuthDivider.tsx）。
 *
 * Web 端实现：relative 容器 py-2，.fade-divider 横贯线（transparent →
 * gray-300/30 → transparent），中央 text-xs text-gray-400 px-3 bg-white 文字。
 */

import 'package:flutter/material.dart';

import '../design/porten_colors.dart';
import '../design/porten_typography.dart';

/// 认证页分隔行。
class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32, // py-2 + 文本行高
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // .fade-divider：absolute inset-x-0
          const Positioned.fill(child: _FadeLine()),
          // relative z-10 px-3 bg-white 文字
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            color: PortenColor.white,
            child: Text(
              text,
              style: PortenTypography.xs.copyWith(color: PortenColor.gray400),
            ),
          ),
        ],
      ),
    );
  }
}

class _FadeLine extends StatelessWidget {
  const _FadeLine();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: SizedBox(
        height: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[
                PortenColor.gray300.withValues(alpha: 0),
                PortenColor.gray300.withValues(alpha: 0.3),
                PortenColor.gray300.withValues(alpha: 0),
              ],
              stops: const <double>[0.0, 0.5, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}
