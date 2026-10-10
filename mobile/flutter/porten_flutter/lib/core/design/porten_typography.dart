/*
 * Porten 字阶令牌。
 *
 * 取值来源：Web 端 Tailwind 字号（xs=12, sm=14, base=16, lg=18, xl=20, 2xl=24, 3xl=30），
 * 另补齐 Web 端内联使用过的 10 / 11 / 13 / 15 / 17 / 22 / 28。
 * 行高一律为字号的 1.5 倍（与 Web 端 `:root { line-height: 1.5 }` 一致）。
 *
 * 字体族：Web 端使用系统字体栈，移动端同样沿用系统默认，避免引入第三方字体的体积与合规成本。
 * 与 Kotlin 侧 core/design/.../PortenTypography.kt 严格一一对应。
 */

import 'package:flutter/widgets.dart';

/// Porten 字阶：14 档，字号 × 1.5 行高。
abstract final class PortenTypography {
  /// 与 Web 端一致的基准行高倍数。
  static const double _lineHeightRatio = 1.5;

  /// Web 端使用系统字体栈，移动端沿用系统默认字体。
  static const String _systemFamily = '.SF UI Text';

  static const TextStyle mini = TextStyle(
      fontFamily: _systemFamily, fontWeight: FontWeight.w400, fontSize: 10, height: _lineHeightRatio);
  static const TextStyle micro = TextStyle(
      fontFamily: _systemFamily, fontWeight: FontWeight.w400, fontSize: 11, height: _lineHeightRatio);
  static const TextStyle xs = TextStyle(
      fontFamily: _systemFamily, fontWeight: FontWeight.w400, fontSize: 12, height: _lineHeightRatio);
  static const TextStyle body13 = TextStyle(
      fontFamily: _systemFamily, fontWeight: FontWeight.w400, fontSize: 13, height: _lineHeightRatio);
  static const TextStyle sm = TextStyle(
      fontFamily: _systemFamily, fontWeight: FontWeight.w400, fontSize: 14, height: _lineHeightRatio);
  static const TextStyle body15 = TextStyle(
      fontFamily: _systemFamily, fontWeight: FontWeight.w400, fontSize: 15, height: _lineHeightRatio);
  static const TextStyle base = TextStyle(
      fontFamily: _systemFamily, fontWeight: FontWeight.w400, fontSize: 16, height: _lineHeightRatio);
  static const TextStyle title17 = TextStyle(
      fontFamily: _systemFamily, fontWeight: FontWeight.w500, fontSize: 17, height: _lineHeightRatio);
  static const TextStyle lg = TextStyle(
      fontFamily: _systemFamily, fontWeight: FontWeight.w500, fontSize: 18, height: _lineHeightRatio);
  static const TextStyle xl = TextStyle(
      fontFamily: _systemFamily, fontWeight: FontWeight.w500, fontSize: 20, height: _lineHeightRatio);
  static const TextStyle hero22 = TextStyle(
      fontFamily: _systemFamily, fontWeight: FontWeight.w600, fontSize: 22, height: _lineHeightRatio);
  static const TextStyle x2l = TextStyle(
      fontFamily: _systemFamily, fontWeight: FontWeight.w600, fontSize: 24, height: _lineHeightRatio);
  static const TextStyle big28 = TextStyle(
      fontFamily: _systemFamily, fontWeight: FontWeight.w600, fontSize: 28, height: _lineHeightRatio);
  static const TextStyle x3l = TextStyle(
      fontFamily: _systemFamily, fontWeight: FontWeight.w600, fontSize: 30, height: _lineHeightRatio);
}
