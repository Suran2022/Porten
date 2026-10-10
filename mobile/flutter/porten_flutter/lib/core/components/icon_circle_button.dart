/*
 * 圆形图标按钮 + 文字标签（对齐 Web 端 IconCircleButton）。
 *
 * Web 端实现：w-12 h-12 rounded-full bg-gray-100/70 的圆形按钮，
 * 内含 Material 风格图标，下方 text-xs 文字标签（仅 label 非空时展示）。
 */

import 'package:flutter/material.dart';

import '../design/porten_colors.dart';
import '../design/porten_typography.dart';

/// 圆形图标按钮。
class IconCircleButton extends StatelessWidget {
  const IconCircleButton({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: PortenColor.gray100.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: PortenColor.gray700),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: PortenTypography.xs.copyWith(color: PortenColor.gray600),
            ),
          ],
        ),
      ),
    );
  }
}
