/// Porten 颜色令牌（Flutter 侧）。
///
/// 数据来源：`../../../design/tokens/porten_design_tokens_v1.json`
/// 与原生 Kotlin 侧 `jys.porten.core.design.tokens.PortenColor` 严格一一对应，
/// 由 `scripts/verify_design_tokens.py` 做一致性校验。
///
/// 硬性规范：
///   1. 业务代码禁止硬编码颜色，一律引用本文件；
///   2. 修改任一取值必须同步 JSON 与 Kotlin 侧，否则算还原事故；
///   3. 颜色统一以 ARGB packed 形式书写（0xFF + RGB），便于全局检索。
library;

import 'package:flutter/material.dart';

/// Porten 颜色令牌集合。
class PortenColor {
  const PortenColor._();

  // ---------------------------------------------------------------------------
  // 品牌色：跨性别旗帜色系（Porten 核心视觉资产，任何场合不得改写）
  // ---------------------------------------------------------------------------
  static const Color brandBlue = Color(0xFF5BCEFA);
  static const Color brandPink = Color(0xFFF5A9B8);
  static const Color brandWhite = Color(0xFFFFFFFF);

  /// 品牌蓝按压态（Web 端用于按钮按下 / 激活态）。
  static const Color brandBluePressed = Color(0xFF3BB5E5);

  /// 品牌粉浅色（Web 端用于描边、弱填充）。
  static const Color brandPinkLight = Color(0xFFF7C5D0);

  // ---------------------------------------------------------------------------
  // 中性灰阶：对齐 Tailwind gray-50 ~ gray-900
  // ---------------------------------------------------------------------------
  static const Color gray50 = Color(0xFFF9FAFB);
  static const Color gray100 = Color(0xFFF3F4F6);
  static const Color gray200 = Color(0xFFE5E7EB);
  static const Color gray300 = Color(0xFFD1D5DB);
  static const Color gray400 = Color(0xFF9CA3AF);
  static const Color gray500 = Color(0xFF6B7280);
  static const Color gray600 = Color(0xFF4B5563);
  static const Color gray700 = Color(0xFF374151);
  static const Color gray800 = Color(0xFF1F2937);
  static const Color gray900 = Color(0xFF111827);
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);

  /// Web 端零散使用的浅底：#FAFAFA / #F7F7F7 / #F5F5F5，统一收敛为三档。
  static const Color wash50 = Color(0xFFFAFAFA);
  static const Color washLight = Color(0xFFF7F7F7);
  static const Color washGray = Color(0xFFF5F5F5);

  // ---------------------------------------------------------------------------
  // 行程（Trip）模块专用色：Web 端行程页的米棕色系
  // ---------------------------------------------------------------------------
  static const Color tripSandLight = Color(0xFFFDF3E6);
  static const Color tripSandBase = Color(0xFFF7E9D2);
  static const Color tripSandDeep = Color(0xFFF2DDBC);
  static const Color tripInkDeep = Color(0xFF1C1410);
  static const Color tripInkSoft = Color(0xFF1A1108);

  // ---------------------------------------------------------------------------
  // 语义色
  // ---------------------------------------------------------------------------
  static const Color error = Color(0xFFEF4444);
  static const Color errorSoft = Color(0xFFF87171);
  static const Color danger = Color(0xFFE5484D);
  static const Color success = Color(0xFF16A34A);
  static const Color info = Color(0xFF3B82F6);
  static const Color disabled = Color(0xFFB6BDCC);

  // ---------------------------------------------------------------------------
  // 透明度
  // ---------------------------------------------------------------------------
  static const double scrimStrongAlpha = 0.6;
  static const double scrimMediumAlpha = 0.55;
  static const double scrimSoftAlpha = 0.35;
  static const double scrimFaintAlpha = 0.25;
  static const double handleAlpha = 0.5;
  static const double dividerEdgeAlpha = 0.3;
  static const double dividerCoreAlpha = 0.8;

  // ---------------------------------------------------------------------------
  // 语义映射：UI 组件只引用语义名，换肤时只需改映射
  // ---------------------------------------------------------------------------

  /// 主文本：对齐 Web 端 text-gray-900（172 次，最高频）。
  static const Color textPrimary = gray900;

  /// 次要文本 / 默认图标色：对齐 Web 端 text-gray-400（192 次）。
  static const Color textSecondary = gray400;

  /// 三级文本：对齐 text-gray-500。
  static const Color textTertiary = gray500;

  /// 品牌容器上的文本：始终为白。
  static const Color textOnBrand = white;

  /// 页面底色。
  static const Color background = white;

  /// 卡片/面板底色：对齐 bg-gray-100（111 次）。
  static const Color surface = gray100;

  /// 更浅的凹陷底色：对齐 bg-gray-50。
  static const Color surfaceSunken = gray50;

  /// 分隔线：对齐 border-gray-200。
  static const Color divider = gray200;

  /// 默认图标色。
  static const Color iconDefault = gray400;

  /// 激活（选中）态图标与文字。
  static const Color iconActive = gray900;
}

/// Porten 渐变令牌（与 Kotlin 侧 PortenGradient 对应）。
class PortenGradient {
  const PortenGradient._();

  /// 品牌文字渐变（Web 端 .porten-gradient）：蓝 → 粉 → 白 → 粉 → 蓝。
  static const List<Color> brandText = <Color>[
    PortenColor.brandBlue,
    PortenColor.brandPink,
    PortenColor.brandWhite,
    PortenColor.brandPink,
    PortenColor.brandBlue,
  ];

  /// 品牌文字渐变的位置停靠点。
  static const List<double> brandTextStops = <double>[0.0, 0.3, 0.5, 0.7, 1.0];

  /// 品牌面渐变（Web 端 .porten-bg-gradient）：蓝 → 粉 → 蓝。
  static const List<Color> brandSurface = <Color>[
    PortenColor.brandBlue,
    PortenColor.brandPink,
    PortenColor.brandBlue,
  ];

  /// 品牌面渐变的位置停靠点。
  static const List<double> brandSurfaceStops = <double>[0.0, 0.5, 1.0];

  /// 流光动画时长（与 Kotlin 侧 PortenGradient.Spec.flowDurationMs 一致）。
  static const Duration brandTextFlowDuration = Duration(seconds: 16);
  static const Duration brandSurfaceFlowDuration = Duration(seconds: 8);

  /// 创建品牌文字渐变。
  static Gradient text({
    AlignmentGeometry begin = Alignment.centerLeft,
    AlignmentGeometry end = Alignment.centerRight,
  }) =>
      LinearGradient(
        begin: begin,
        end: end,
        colors: brandText,
        stops: brandTextStops,
      );

  /// 创建品牌面渐变。
  static Gradient surface({
    AlignmentGeometry begin = Alignment.centerLeft,
    AlignmentGeometry end = Alignment.centerRight,
  }) =>
      LinearGradient(
        begin: begin,
        end: end,
        colors: brandSurface,
        stops: brandSurfaceStops,
      );
}
