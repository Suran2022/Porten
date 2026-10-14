/*
 * 换绑冷却提示弹窗（100% 移植 Web 端
 * components/profile/ChangeEmailCooldownDialog.tsx）。
 *
 * 结构：px-6 pt-6 pb-2；居中 w-12 h-12 rounded-full bg-amber-50 圆 +
 *   CalendarClock w-6 h-6 amber-500 strokeWidth 1.5；
 *   标题 mt-3 text-base font-semibold「365 天之内只能换绑一次邮箱」；
 *   正文 mt-3 text-sm gray-500 leading-6 居中（「365 天」gray-900
 *   font-medium），三段换行文本；
 * 底部 PortenDialogFooter（取消 / 继续换绑）。
 */

import 'package:flutter/material.dart';

import '../../core/components/porten_center_dialog.dart';
import '../../core/components/porten_lucide_icons.dart';

class ChangeEmailCooldownDialog extends StatelessWidget {
  const ChangeEmailCooldownDialog({
    super.key,
    required this.visible,
    this.remainingDays = 365,
    required this.onClose,
    required this.onContinue,
  });

  final bool visible;

  /// 距下次可换绑的剩余天数（Web 端透传用于文案扩展，当前固定 365）。
  final int remainingDays;

  final VoidCallback onClose;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return PortenCenterDialog(
      visible: visible,
      onClose: onClose,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 8), // px-6 pt-6 pb-2
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 48, // w-12
                    height: 48, // h-12
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFFBEB), // amber-50
                      shape: BoxShape.circle, // rounded-full
                    ),
                    alignment: Alignment.center,
                    child: const PortenLucideIcon(
                      'calendar-clock',
                      size: 24, // w-6 h-6
                      color: Color(0xFFF59E0B), // amber-500
                      strokeWidth: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12), // mt-3
                const Text(
                  '365 天之内只能换绑一次邮箱',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16, // text-base
                    fontWeight: FontWeight.w600, // font-semibold
                    color: Color(0xFF111827), // gray-900
                  ),
                ),
                const SizedBox(height: 12), // mt-3
                Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      const TextSpan(text: '为保障账号安全，每次换绑后'),
                      // 「365 天」为 gray-900 font-medium（含前后空格）
                      const TextSpan(
                        text: ' 365 天 ',
                        style: TextStyle(
                          color: Color(0xFF111827),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const TextSpan(text: '内仅可再次换绑一次。'),
                      const TextSpan(
                          text: '\n换绑周期仅从本次实际换绑操作时间起算，不包含账号首次注册时间。'),
                      const TextSpan(text: '\n是否仍要继续换绑？'),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14, // text-sm
                    height: 24 / 14, // leading-6
                    color: Color(0xFF6B7280), // gray-500
                  ),
                ),
              ],
            ),
          ),
          PortenDialogFooter(
            cancelLabel: '取消',
            onCancel: onClose,
            confirmLabel: '继续换绑',
            onConfirm: onContinue,
          ),
        ],
      ),
    );
  }
}
