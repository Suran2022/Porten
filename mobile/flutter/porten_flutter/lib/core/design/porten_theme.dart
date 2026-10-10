/*
 * Porten Flutter 主题。
 *
 * 核心约束（与 React Web 端 100% 对齐 + 与 Kotlin 侧 PortenTheme 一致）：
 *   1. Material 3 色彩体系，品牌色来自 design tokens（与 Kotlin 端同一 JSON 数据源）；
 *   2. **全局禁用点击水波纹**：Web 端自定义按压反馈（透明度/缩放），
 *      Flutter 侧通过 Theme 无 splash / highlight 实现同等效果；
 *   3. 文本主题来自 PortenTypography（14 档字阶）。
 */

import 'package:flutter/material.dart';

import 'porten_colors.dart';
import 'porten_typography.dart';

/// Porten 主题容器：包一层 Material App 之外的根级 Theme。
class PortenTheme extends StatelessWidget {
  const PortenTheme({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: PortenColor.brandBlue,
      primary: PortenColor.brandBlue,
      secondary: PortenColor.brandPink,
      surface: PortenColor.white,
      error: PortenColor.error,
    );

    return Theme(
      data: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        textTheme: const TextTheme(
          displayLarge: PortenTypography.x3l,
          displayMedium: PortenTypography.big28,
          displaySmall: PortenTypography.x2l,
          headlineLarge: PortenTypography.hero22,
          headlineMedium: PortenTypography.xl,
          headlineSmall: PortenTypography.lg,
          titleLarge: PortenTypography.title17,
          titleMedium: PortenTypography.base,
          titleSmall: PortenTypography.body15,
          bodyLarge: PortenTypography.base,
          bodyMedium: PortenTypography.sm,
          bodySmall: PortenTypography.xs,
          labelLarge: PortenTypography.body15,
          labelMedium: PortenTypography.sm,
          labelSmall: PortenTypography.xs,
        ),
        // ---------------- 关闭默认水波纹（对齐 Web 端交互） ----------------
        splashFactory: NoSplash.splashFactory,
        splashColor: const Color(0x00000000),
        highlightColor: const Color(0x00000000),
        hoverColor: const Color(0x00000000),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        // 分隔线与分割色对齐 Web 端 gray-100 / gray-200
        dividerColor: PortenColor.gray200,
      ),
      child: child,
    );
  }
}
