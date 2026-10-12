/*
 * 品牌渐变渲染组件：文字渐变与图标渐变。
 *
 * 来源：Web 端 `.porten-gradient`（蓝→粉→白→粉→蓝 文字渐变）、
 * BottomNav 激活图标渐变（90deg #5BCEFA→#F5A9B8）、
 * 组件内联 gradient text（90deg #5BCEFA→#F5A9B8→#5BCEFA）。
 * 颜色一律取自 PortenGradient / PortenColor 令牌，禁止硬编码。
 */

import 'package:flutter/material.dart';

import '../design/porten_colors.dart';

/// 品牌文字渐变（Web 端 .porten-gradient）。
class PortenGradientText extends StatelessWidget {
  const PortenGradientText({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (Rect bounds) => PortenGradient.text().createShader(bounds),
      child: child,
    );
  }
}

/// 三段式强调渐变文字（Web 端「阅读全文 / 分享 / 联系组织」内联渐变）。
class PortenAccentGradientText extends StatelessWidget {
  const PortenAccentGradientText({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (Rect bounds) => PortenGradient.surface().createShader(bounds),
      child: child,
    );
  }
}

/// 品牌渐变图标（Web 端 BottomNav 激活图标：90deg 蓝→粉）。
class PortenGradientIcon extends StatelessWidget {
  const PortenGradientIcon({
    super.key,
    required this.icon,
    required this.size,
  });

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (Rect bounds) => const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: <Color>[PortenColor.brandBlue, PortenColor.brandPink],
      ).createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Icon(icon, size: size, color: PortenColor.white),
    );
  }
}
