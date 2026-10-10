/*
 * 品牌流光 Logo（对齐 Web 端 GradientLogo + .porten-gradient）。
 *
 * Web 端实现：text-5xl font-bold 文本叠加 .porten-gradient 背景 + background-clip:text，
 * 渐变 5 停靠点（蓝→粉→白→粉→蓝）以 16s 循环平移，产生流光扫过效果。
 *
 * Flutter 实现：ShaderMask + AnimationController 驱动渐变起止锚点平移，
 * 视觉等价于 background-position 动画。
 */

import 'package:flutter/material.dart';

import '../design/porten_colors.dart';
import '../design/porten_typography.dart';

/// 流光扫过动画时长（对齐 Web 端 .porten-gradient 的 16s）。
const Duration _kFlowDuration = Duration(seconds: 16);

/// 品牌流光 Logo。
///
/// [text] 默认 'Porten'；[fontSize] 默认 48（对齐 Web 端 text-5xl）。
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
        // 让渐变宽度始终为文本宽度的 3 倍并向左扫过，
        // 等价于 Web 端 background-size:300% + background-position 循环。
        final double t = _controller.value;
        return ShaderMask(
          shaderCallback: (Rect bounds) {
            final Rect wide = Rect.fromLTWH(
              bounds.left - bounds.width * 2 * (1 - t),
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
          fontFamily: PortenTypography.base.fontFamily,
          fontSize: widget.fontSize,
          fontWeight: widget.fontWeight,
          height: 1.2,
          color: const Color(0xFF000000), // 仅占位，实际被 ShaderMask 覆盖
        ),
      ),
    );
  }
}
