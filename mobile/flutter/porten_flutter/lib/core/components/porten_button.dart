/*
 * 品牌渐变按钮（对齐 Web 端 GradientButton + .porten-bg-gradient）。
 *
 * Web 端实现：h-12 rounded-full 的胶囊按钮，背景 .porten-bg-gradient
 * （蓝→粉→蓝，90deg，8s 循环流光），文本白色 font-medium；
 * loading 状态显示 .spinner（白色圆环，0.8s/圈）。
 */

import 'package:flutter/material.dart';

import '../design/porten_colors.dart';
import '../design/porten_typography.dart';

/// 面渐变流光时长（对齐 Web 端 .porten-bg-gradient 的 8s）。
const Duration _kSurfaceFlowDuration = Duration(seconds: 8);

/// 加载指示器旋转一圈时长（对齐 Web 端 .spinner 的 0.8s）。
const Duration _kSpinnerDuration = Duration(milliseconds: 800);

/// 品牌渐变按钮。
///
/// [onPressed] 为 null 时进入禁用态（灰底，对齐 Web 端 disabled:bg-gray-300）。
class GradientButton extends StatefulWidget {
  const GradientButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.height = 48,
    this.fontSize = 16,
    this.enabledBackground,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final double height;
  final double fontSize;

  /// 禁用态底色（可由主题覆写）。
  final Color? enabledBackground;

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flow = AnimationController(
    vsync: this,
    duration: _kSurfaceFlowDuration,
  )..repeat();

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
      opacity: widget.onPressed == null && !widget.loading ? 0.6 : 1.0,
      child: AnimatedBuilder(
        animation: _flow,
        builder: (BuildContext context, Widget? child) {
          final double t = _flow.value;
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
                        width: widget.fontSize * 1.1,
                        height: widget.fontSize * 1.1,
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
                                backgroundColor: Colors.white.withValues(alpha: 0.3),
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
