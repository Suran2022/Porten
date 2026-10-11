/*
 * 圆形图标按钮 + 文字标签（100% 对齐 Web 端 IconCircleButton.tsx）。
 *
 * Web 端实现：flex-col items-center gap-2，圆形 w-12 h-12 rounded-full
 * bg-gray-100/70，内部 w-5 h-5 图标 text-gray-600，下方 text-xs text-gray-500。
 */

import 'package:flutter/material.dart';

import '../design/porten_colors.dart';
import '../design/porten_typography.dart';
import 'porten_icons.dart';

/// 圆形图标按钮。
class IconCircleButton extends StatelessWidget {
  const IconCircleButton({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
  });

  /// lucide 图标名（porten_icons.dart 内置定义）。
  final String icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
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
            alignment: Alignment.center,
            child: LucideIcon(icon, size: 20, color: PortenColor.gray600),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: PortenTypography.xs.copyWith(color: PortenColor.gray500),
          ),
        ],
      ),
    );
  }
}
