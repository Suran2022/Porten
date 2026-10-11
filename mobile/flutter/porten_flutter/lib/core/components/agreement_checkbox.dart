/*
 * 协议勾选组件（100% 对齐 Web 端 AgreementCheckbox.tsx）。
 *
 * Web 端实现：
 *   - 容器 flex items-start gap-1.5 mt-4；
 *   - 圆点 w-3 h-3（12px）rounded-full border-[1.5px] mt-[3px]，
 *     选中时 border-transparent + .agreement-gradient（135deg 蓝粉蓝流光 3s），
 *     内嵌白色对勾 polyline（strokeWidth 2.5，p-[1px]）；
 *   - 文案 text-xs text-gray-500：《协议》链接为纯内联 <a>（#F5A9B8 下划线），
 *     与普通文本同一排版流，无额外盒模型空隙，随行自然换行。
 *
 * Flutter 侧：链接用 TextSpan + TapGestureRecognizer（纯内联），禁用
 * WidgetSpan——盒模型 span 会引入多余空隙与异常换行点。
 */

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../design/porten_colors.dart';
import '../design/porten_typography.dart';
import 'svg_path.dart';

/// 协议勾选行。
class AgreementCheckbox extends StatefulWidget {
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

  @override
  State<AgreementCheckbox> createState() => _AgreementCheckboxState();
}

class _AgreementCheckboxState extends State<AgreementCheckbox> {
  final Map<String, TapGestureRecognizer> _recognizers =
      <String, TapGestureRecognizer>{};

  /// 链接样式（#F5A9B8 下划线，对齐 Web 端 .agreement-link）。
  static const TextStyle _linkStyle = TextStyle(
    color: Color(0xFFF5A9B8),
    decoration: TextDecoration.underline,
    decorationColor: Color(0xFFF5A9B8),
    decorationStyle: TextDecorationStyle.solid,
  );

  TapGestureRecognizer _recognizerFor(String id) {
    return _recognizers.putIfAbsent(id, () {
      final TapGestureRecognizer recognizer = TapGestureRecognizer();
      recognizer.onTap = () => widget.onOpenAgreement(context, id);
      return recognizer;
    });
  }

  @override
  void dispose() {
    for (final TapGestureRecognizer recognizer in _recognizers.values) {
      recognizer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 链接文字沿用正文 xs 字号，仅颜色与下划线不同（对齐 Web 端继承关系）。
    final TextStyle linkStyle = PortenTypography.xs.merge(_linkStyle);

    return Padding(
      padding: const EdgeInsets.only(top: 16), // mt-4
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: _AgreementDot(
              checked: widget.checked,
              onTap: () => widget.onChanged(!widget.checked),
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
                  TextSpan(
                    text: '《用户协议》',
                    style: linkStyle,
                    recognizer: _recognizerFor('user'),
                  ),
                  const TextSpan(text: '，'),
                  TextSpan(
                    text: '《跨性别资源》',
                    style: linkStyle,
                    recognizer: _recognizerFor('trans'),
                  ),
                  const TextSpan(text: '，'),
                  TextSpan(
                    text: '《信息收集》',
                    style: linkStyle,
                    recognizer: _recognizerFor('privacy'),
                  ),
                  const TextSpan(text: '继续使用'),
                ],
              ),
            ),
          ),
        ],
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
  // Web 端 .agreement-gradient：135deg 蓝粉蓝三色，background-size 200% 200%，
  // 3s ease-in-out 流光（position 0%→100%→0% 往返）。
  // 用 3s repeat(reverse: true) + easeInOut 曲线等价还原。
  late final AnimationController _flow = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

  late final Animation<double> _flowP = CurvedAnimation(
    parent: _flow,
    curve: Curves.easeInOut,
  );

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
        animation: _flowP,
        builder: (BuildContext context, _) {
          // 135deg 方向固定，沿对角线平移渐变（对齐 Web background-position 动画）
          final double d = -1.0 + 2.0 * _flowP.value;
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.checked ? null : PortenColor.white,
              gradient: widget.checked
                  ? LinearGradient(
                      begin: Alignment(-0.7 + d, -0.7 + d), // 135deg
                      end: Alignment(0.7 + d, 0.7 + d),
                      colors: const <Color>[
                        PortenColor.brandBlue,
                        PortenColor.brandPink,
                        PortenColor.brandBlue,
                      ],
                      stops: const <double>[0.0, 0.5, 1.0],
                    )
                  : null,
              border: Border.all(
                color:
                    widget.checked ? Colors.transparent : PortenColor.gray300,
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
