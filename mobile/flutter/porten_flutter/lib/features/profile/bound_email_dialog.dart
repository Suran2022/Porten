/*
 * 绑定邮箱弹窗（100% 移植 Web 端 components/profile/BoundEmailDialog.tsx）。
 *
 * 结构：px-6 pt-6 pb-2；标题 text-base font-semibold 居中「绑定的邮箱」；
 *   mt-4 px-4 py-5 bg-gray-50 rounded-xl 卡片（maskEmail 脱敏邮箱
 *   text-lg font-medium tracking-wide + mt-2 text-xs gray-400 提示）；
 * 底部 PortenDialogFooter（取消 / 换绑邮箱）。
 */

import 'package:flutter/material.dart';

import '../../core/components/porten_center_dialog.dart';
import '../../core/utils/porten_email.dart';

class BoundEmailDialog extends StatelessWidget {
  const BoundEmailDialog({
    super.key,
    required this.visible,
    required this.email,
    required this.onClose,
    required this.onChangeEmail,
  });

  final bool visible;
  final String email;
  final VoidCallback onClose;
  final VoidCallback onChangeEmail;

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
                const Text(
                  '绑定的邮箱',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16, // text-base
                    fontWeight: FontWeight.w600, // font-semibold
                    color: Color(0xFF111827), // gray-900
                  ),
                ),
                const SizedBox(height: 16), // mt-4
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20), // px-4 py-5
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB), // gray-50
                    borderRadius: BorderRadius.circular(12), // rounded-xl
                  ),
                  child: Column(
                    children: <Widget>[
                      Text(
                        maskEmail(email),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18, // text-lg
                          fontWeight: FontWeight.w500, // font-medium
                          letterSpacing: 0.45, // tracking-wide
                          color: Color(0xFF111827), // gray-900
                        ),
                      ),
                      const SizedBox(height: 8), // mt-2
                      const Text(
                        '为保障账号安全，已对邮箱进行脱敏展示',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12, // text-xs
                          color: Color(0xFF9CA3AF), // gray-400
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          PortenDialogFooter(
            cancelLabel: '取消',
            onCancel: onClose,
            confirmLabel: '换绑邮箱',
            onConfirm: onChangeEmail,
          ),
        ],
      ),
    );
  }
}
