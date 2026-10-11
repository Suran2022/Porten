/*
 * 品牌渐变按钮（100% 对齐 Web 端 GradientButton.tsx + .porten-bg-gradient）。
 *
 * Web 端实现：h-12 w-full rounded-full 胶囊按钮，背景 .porten-bg-gradient
 * （蓝→粉→蓝，90deg，8s 流光），文本白色 text-base font-medium；
 * loading 时文本替换为 .spinner（白色圆环 20px，0.8s/圈）；
 * disabled 时 opacity-50。
 */

import 'package:flutter/material.dart';

import '../design/porten_colors.dart';
import '../design/porten_typography.dart';

/// 面渐变流光时长（对齐 Web 端 .porten-bg-gradient 的 8s）。
const Duration _kSurfaceFlowDuration = Duration(seconds: 8);

/// 加载指示器旋转一圈时长（对齐 Web 端 .spinner 的 0.8s）。
const Duration _kSpinnerDuration = Duration(milliseconds: 800);

/// 品牌渐变按钮。
class GradientButton extends StatefulWidget {
  const GradientButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.height = 48,
    this.fontSize = 16,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final double height;
  final double fontSize;

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton>
    with SingleTickerProviderStateMixin {
  // Web 端 .porten-bg-gradient：8s ease-in-out，background-position 0%→100%→0%
  // 往返（pingpong）。用 8s repeat(reverse: true) + easeInOut 曲线等价还原。
  late final AnimationController _flow = AnimationController(
    vsync: this,
    duration: _kSurfaceFlowDuration,
  )..repeat(reverse: true);

  late final Animation<double> _flowP = CurvedAnimation(
    parent: _flow,
    curve: Curves.easeInOut,
  );

  late final AnimationController _spinner = AnimationController(
    vsync: this,
    duration: _kSpinnerDuration,
  );

  @override
  void didUpdateWidget(GradientButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.loading && !_spinner.isAnimating) {
      _spinner.repeat();
    } else if (!widget.loading && _spinner.isAnimating) {
      _spinner.stop();
    }
  }

  @override
  void dispose() {
    _flow.dispose();
    _spinner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool disabled = widget.onPressed == null || widget.loading;
    return Opacity(
      opacity: disabled ? 0.85 : 1.0,
      child: AnimatedBuilder(
        animation: _flow,
        builder: (BuildContext context, Widget? child) {
          final double t = _flowP.value;
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.height / 2),
              gradient: LinearGradient(
                begin: Alignment(-2 + 4 * t, 0),
                end: Alignment(0 + 4 * t, 0),
                colors: PortenGradient.brandSurface,
                stops: PortenGradient.brandSurfaceStops,
              ),
            ),
            child: child,
          );
        },
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(widget.height / 2),
            onTap: disabled ? null : widget.onPressed,
            child: SizedBox(
              height: widget.height,
              child: Center(
                child: widget.loading
                    ? SizedBox(
                        width: 20, // .spinner 20px
                        height: 20,
                        child: AnimatedBuilder(
                          animation: _spinner,
                          builder: (BuildContext context, _) {
                            return Transform.rotate(
                              angle: _spinner.value * 2 * 3.14159265,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  PortenColor.white,
                                ),
                                backgroundColor:
                                    PortenColor.white.withValues(alpha: 0.3),
                              ),
                            );
                          },
                        ),
                      )
                    : Text(
                        widget.label,
                        style: TextStyle(
                          inherit: false,
                          fontFamily: PortenTypography.base.fontFamily,
                          fontSize: widget.fontSize,
                          fontWeight: FontWeight.w500,
                          color: PortenColor.white,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
