/*
 * 协议勾选组件（100% 对齐 Web 端 AgreementCheckbox.tsx）。
 *
 * Web 端实现：
 *   - 容器 flex items-start gap-1.5 mt-4；
 *   - 圆点 w-3 h-3（12px）rounded-full border-[1.5px] mt-[3px]，
 *     选中时 border-transparent + .agreement-gradient（135deg 蓝粉白粉蓝流光 3s），
 *     内嵌白色对勾 polyline（strokeWidth 2.5，p-[1px]）；
 *   - 文案 text-xs text-gray-500：「我已阅读并遵守《用户协议》，《跨性别资源》，
 *     《信息收集》继续使用」，链接 #F5A9B8 underline underline-offset-2。
 */

import 'package:flutter/material.dart';

import '../design/porten_colors.dart';
import '../design/porten_typography.dart';
import 'svg_path.dart';

/// 协议勾选行。
class AgreementCheckbox extends StatelessWidget {
  const AgreementCheckbox({
    super.key,
    required this.checked,
    required this.onChanged,
    required this.onOpenAgreement,
  });

  final bool checked;
  final ValueChanged<bool> onChanged;

  /// 打开协议全文（id：user / trans / privacy），由页面注入（对齐 Web 端
  /// onOpenAgreement 回调架构）。
  final void Function(BuildContext context, String agreementId) onOpenAgreement;

  static const Map<String, String> _links = <String, String>{
    '《用户协议》': 'user',
    '《跨性别资源》': 'trans',
    '《信息收集》': 'privacy',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16), // mt-4
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: _AgreementDot(
              checked: checked,
              onTap: () => onChanged(!checked),
            ),
          ),
          const SizedBox(width: 6), // gap-1.5
          Expanded(
            child: Text.rich(
              TextSpan(
                style: PortenTypography.xs
                    .copyWith(color: PortenColor.gray500, height: 1.625),
                children: <InlineSpan>[
                  const TextSpan(text: '我已阅读并遵守'),
                  ..._buildLinks(),
                  const TextSpan(text: '继续使用'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<InlineSpan> _buildLinks() {
    final List<InlineSpan> spans = <InlineSpan>[];
    final List<String> keys = _links.keys.toList();
    for (int i = 0; i < keys.length; i++) {
      final String label = keys[i];
      final String id = _links[label]!;
      spans.add(_AgreementLinkSpan(
        label: label,
        id: id,
        onOpen: onOpenAgreement,
      ));
      // Web 端链接之间是中文逗号「，」
      if (i < keys.length - 1) {
        spans.add(const TextSpan(text: '，'));
      }
    }
    return spans;
  }
}

/// 协议链接（#F5A9B8 下划线，点击打开全文查看器）。
class _AgreementLinkSpan extends WidgetSpan {
  _AgreementLinkSpan({
    required String label,
    required String id,
    required void Function(BuildContext, String) onOpen,
  }) : super(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: _AgreementLinkText(label: label, id: id, onOpen: onOpen),
        );
}

class _AgreementLinkText extends StatelessWidget {
  const _AgreementLinkText({
    required this.label,
    required this.id,
    required this.onOpen,
  });

  final String label;
  final String id;
  final void Function(BuildContext, String) onOpen;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onOpen(context, id),
      child: Text(
        label,
        style: PortenTypography.xs.copyWith(
          color: const Color(0xFFF5A9B8),
          decoration: TextDecoration.underline,
          decorationColor: const Color(0xFFF5A9B8),
          decorationStyle: TextDecorationStyle.solid,
        ),
      ),
    );
  }
}

/// 圆形勾选点：w-3 h-3，选中时 135deg 流光渐变 + 白色对勾。
class _AgreementDot extends StatefulWidget {
  const _AgreementDot({required this.checked, required this.onTap});

  final bool checked;
  final VoidCallback onTap;

  @override
  State<_AgreementDot> createState() => _AgreementDotState();
}

class _AgreementDotState extends State<_AgreementDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flow = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double size = 12; // w-3 h-3
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _flow,
        builder: (BuildContext context, _) {
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.checked ? null : PortenColor.white,
              gradient: widget.checked
                  ? LinearGradient(
                      begin: Alignment(-0.7, -0.7), // 135deg
                      end: const Alignment(0.7, 0.7),
                      colors: PortenGradient.brandText,
                      stops: PortenGradient.brandTextStops,
                      transform: GradientRotation(_flow.value * 2 * 3.14159265),
                    )
                  : null,
              border: Border.all(
                color: widget.checked ? Colors.transparent : PortenColor.gray300,
                width: 1.5, // border-[1.5px]
              ),
            ),
            child: widget.checked
                ? Padding(
                    padding: const EdgeInsets.all(1), // p-[1px]
                    child: CustomPaint(
                      painter: _CheckPainter(),
                    ),
                  )
                : null,
          );
        },
      ),
    );
  }
}

/// 白色对勾（polyline 20 6 9 17 4 12，viewBox 24，strokeWidth 2.5）。
class _CheckPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / 24;
    canvas.save();
    canvas.scale(scale, scale);
    final Paint paint = Paint()
      ..color = PortenColor.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(svgPathToUiPath('M20 6L9 17l-5-5'), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CheckPainter oldDelegate) => false;
}
