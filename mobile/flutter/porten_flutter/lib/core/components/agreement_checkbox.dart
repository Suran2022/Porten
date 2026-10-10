/*
 * 协议勾选组件（对齐 Web 端 AgreementCheckbox + .agreement-gradient）。
 *
 * Web 端实现：
 *   - 圆形勾选点 w-3 h-3，未选中时 1px gray-300 描边，选中时填充
 *     .agreement-gradient（135deg 蓝→粉→白→粉→蓝，3s 流光）+ 白色对勾；
 *   - 后缀文案含三个链接（《用户协议》《跨性别资源》《信息收集》），
 *     链接色 #F5A9B8 带下划线，点击打开协议全文查看器。
 */

import 'package:flutter/material.dart';

import '../design/porten_colors.dart';
import '../design/porten_typography.dart';
import 'agreement_viewer.dart';

/// 协议条目。
enum PortenAgreement {
  userAgreement('用户协议'),
  resource('跨性别资源'),
  dataCollection('信息收集');

  const PortenAgreement(this.title);
  final String title;
}

/// 协议勾选行。
class AgreementCheckbox extends StatelessWidget {
  const AgreementCheckbox({
    super.key,
    required this.checked,
    required this.onChanged,
    this.errorText,
  });

  final bool checked;
  final ValueChanged<bool> onChanged;

  /// 非空时在行下方展示红色提示（对齐 Web 端 agreementError）。
  final String? errorText;

  Future<void> _openViewer(BuildContext context, PortenAgreement item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (_) => AgreementViewer(title: item.title),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: _AgreementDot(
                checked: checked,
                onTap: () => onChanged(!checked),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: PortenTypography.xs.copyWith(color: PortenColor.gray500),
                  children: <InlineSpan>[
                    const TextSpan(text: '我已阅读并同意 '),
                    ..._linkSpans(context),
                    const TextSpan(text: '，并知晓平台仅面向成年用户。'),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (errorText != null && errorText!.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Text(
              errorText!,
              style: PortenTypography.xs.copyWith(color: PortenColor.error),
            ),
          ),
        ],
      ],
    );
  }

  List<InlineSpan> _linkSpans(BuildContext context) {
    final List<InlineSpan> spans = <InlineSpan>[];
    final List<PortenAgreement> items = PortenAgreement.values;
    for (int i = 0; i < items.length; i++) {
      spans.add(TextSpan(
        text: '《${items[i].title}》',
        style: PortenTypography.xs.copyWith(
          color: PortenColor.brandPink,
          decoration: TextDecoration.underline,
          decorationColor: PortenColor.brandPink,
        ),
        recognizer: null,
      ));
      if (i < items.length - 1) {
        spans.add(const TextSpan(text: ' '));
      }
    }
    // 用 WidgetSpan 承载点击手势（TapGestureRecognizer 需手动释放，
    // WidgetSpan + GestureDetector 由组件生命周期管理，更防泄漏）。
    return spans
        .map((InlineSpan span) =>
            span is TextSpan && span.text!.startsWith('《')
                ? WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: GestureDetector(
                      onTap: () => _openViewer(
                        context,
                        PortenAgreement.values.firstWhere(
                          (PortenAgreement e) => '《${e.title}》' == span.text,
                        ),
                      ),
                      child: Text(
                        span.text!,
                        style: span.style,
                      ),
                    ),
                  )
                : span)
        .toList();
  }
}

/// 圆形勾选点：选中时填充流光渐变 + 白色对勾。
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
    final double size = 14; // Web 端 w-3.5 视觉（w-3 过小，移动端适度放大保证可点）。
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.checked ? null : Colors.transparent,
          gradient: widget.checked
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: PortenGradient.brandText,
                  stops: PortenGradient.brandTextStops,
                )
              : null,
          border: Border.all(
            color: widget.checked ? Colors.transparent : PortenColor.gray300,
            width: 1,
          ),
        ),
        child: widget.checked
            ? const Icon(Icons.check, size: 10, color: PortenColor.white)
            : null,
      ),
    );
  }
}
