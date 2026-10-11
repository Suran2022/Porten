/*
 * 品牌流光 Logo（100% 对齐 Web 端 GradientLogo.tsx + .porten-gradient）。
 *
 * Web 端实现：text-5xl（48px）font-bold tracking-tight + porten-gradient
 * （90deg 蓝→粉→白→粉→蓝 5 停靠点，background-size 300%，16s 循环流光）
 * + background-clip:text + select-none。
 */

import 'package:flutter/material.dart';

import '../design/porten_colors.dart';

/// 流光动画时长（对齐 Web 端 .porten-gradient 的 16s）。
const Duration _kFlowDuration = Duration(seconds: 16);

/// 品牌流光 Logo。
class GradientLogo extends StatefulWidget {
  const GradientLogo({
    super.key,
    this.text = 'Porten',
    this.fontSize = 48,
    this.fontWeight = FontWeight.w700,
  });

  final String text;
  final double fontSize;
  final FontWeight fontWeight;

  @override
  State<GradientLogo> createState() => _GradientLogoState();
}

class _GradientLogoState extends State<GradientLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: _kFlowDuration)..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        // 渐变宽度恒为文本宽度 3 倍并向右扫过，
        // 等价于 Web 端 background-size:300% + background-position 循环。
        final double t = _controller.value;
        return ShaderMask(
          shaderCallback: (Rect bounds) {
            final Rect wide = Rect.fromLTWH(
              bounds.left - bounds.width * 2 * t,
              bounds.top,
              bounds.width * 3,
              bounds.height,
            );
            return LinearGradient(
              colors: PortenGradient.brandText,
              stops: PortenGradient.brandTextStops,
            ).createShader(wide);
          },
          blendMode: BlendMode.srcIn,
          child: child,
        );
      },
      child: Text(
        widget.text,
        style: TextStyle(
          inherit: false,
          fontSize: widget.fontSize,
          fontWeight: widget.fontWeight,
          height: 1.2,
          letterSpacing: -widget.fontSize * 0.025, // tracking-tight
          color: const Color(0xFF000000), // 占位色，实际由 ShaderMask 覆盖
        ),
      ),
    );
  }
}
