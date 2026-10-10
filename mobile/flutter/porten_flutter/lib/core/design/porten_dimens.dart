/*
 * Porten 尺寸令牌：间距 / 圆角 / 触摸目标 / 屏幕适配基准。
 *
 * 全部取值来自 design/tokens/porten_design_tokens_v1.json，
 * 与 Kotlin 侧 core/design/.../PortenDimens.kt 严格一一对应；
 * 任何一侧调整必须同步，并由 scripts/verify_design_tokens.py 校验一致性。
 *
 * 命名遵循 Dart 官方风格：lowerCamelCase 常量、与 Kotlin 侧 PascalCase 名称一一映射。
 */

import 'package:flutter/widgets.dart';

/// 间距令牌：以 4dp 栅格为主，补齐 Web 端实际用到的 2/6/12/20。
abstract final class PortenDimens {
  // ------------------------------ 间距 ------------------------------
  static const double spaceXXXS = 2;
  static const double spaceXXS = 4;
  static const double spaceXS = 6;
  static const double spaceSM = 8;
  static const double spaceMD = 12;
  static const double spaceLG = 16;
  static const double spaceXL = 20;
  static const double space2XL = 24;
  static const double space3XL = 32;
  static const double space4XL = 48;

  // ------------------------------ 圆角 ------------------------------
  static const double radiusBase = 4;
  static const double radiusSM = 6;
  static const double radiusMD = 8;
  static const double radiusLG = 12;
  static const double radiusXL = 16;

  /// 胶囊形（Web 端 rounded-full 使用频率最高，共 170 次）。
  static const double radiusPill = 9999;

  // ------------------------------ 触摸目标 ------------------------------
  /// 遵循 Material 3 无障碍规范的最小可点击区域。
  static const double touchTargetMin = 48;
  static const double touchTargetRecommended = 56;

  // ------------------------------ 控件尺寸 ------------------------------
  /// 底部导航高度：对齐 Web 端 64px 视觉，移动端取 Material 推荐值。
  static const double bottomNavHeight = 56;

  /// 顶部应用栏高度。
  static const double topBarHeight = 56;

  /// 下拉刷新指示球（Web 端 .ptr-loader 为 20px，与 text-sm 行框等高）。
  static const double pullToRefreshIndicatorSize = 20;

  /// 抽屉/面板拖拽指示器：Web 端 36x4，圆角 2。
  static const double sheetHandleWidth = 36;
  static const double sheetHandleHeight = 4;
  static const double sheetHandleRadius = 2;

  /// 分隔线厚度：Web 端 .fade-divider 为 1px。
  static const double dividerThickness = 1;

  /// 认证页顶部分割进度条厚度（Web 端 .auth-progress 为 1.5px）。
  static const double authProgressThickness = 1.5;
}

/// 屏幕适配基准：等比缩放常量。
///
/// 背景：React Web 端是**流式响应式布局**，不存在「设计稿宽度」；
/// 而 App 窗口尺寸随设备千差万别，要实现「布局不变、整体等比缩放」，必须人为固定一个基准。
///
/// 策略（width-first）：以 [designWidthDp] 为基准，按屏幕宽度计算缩放系数，
/// 并对超大屏/超小屏做上下限约束，避免平板被拉爆、小屏被压垮。
abstract final class PortenScaling {
  /// 设计基准宽度（逻辑像素）。取值需与 Kotlin 侧保持一致。
  static const double designWidthDp = 375;

  /// 设计基准高度（逻辑像素），仅用于推算宽高比，不参与缩放系数计算。
  static const double designHeightDp = 812;

  /// 缩放系数上下限：防止极端屏幕出现畸形布局。
  static const double minScale = 0.8;
  static const double maxScale = 1.35;

  /// 文本是否跟随宽度等比缩放。
  ///
  /// 默认 false：文字保持语义字号（跟随用户系统字体设置），
  /// 只有间距/控件尺寸做等比缩放——这是 IM 类产品的通行做法。
  static const bool scaleText = false;

  /// 允许用户系统字体缩放影响的最大倍数（超出则截断，避免布局溢出）。
  static const double fontScaleMax = 1.3;

  /// 依据屏幕宽度计算缩放系数，结果始终落在 [minScale] ~ [maxScale] 区间。
  static double scaleFor(double screenWidthDp) {
    if (screenWidthDp <= 0) return 1;
    final double raw = screenWidthDp / designWidthDp;
    return raw.clamp(minScale, maxScale);
  }
}

/// InheritedWidget：向子树下发当前缩放系数，供业务组件按需取用。
///
/// 用法：在应用根部由 PortenApp 包裹；业务侧通过 [PortenScale.of(context)]
/// 获取系数后对间距/尺寸做乘法，例如 `16 * PortenScale.of(context)`。
class PortenScale extends InheritedWidget {
  const PortenScale({
    super.key,
    required this.scale,
    required super.child,
  });

  /// 当前有效缩放系数（已做上下限截断）。
  final double scale;

  /// 便捷构造：根据 MediaQuery 的逻辑宽度自动计算。
  factory PortenScale.fromMediaQuery({
    required BuildContext context,
    required Widget child,
  }) {
    final double width =
        MediaQuery.sizeOf(context).width;
    return PortenScale(
      scale: PortenScaling.scaleFor(width),
      child: child,
    );
  }

  /// 取当前子树的缩放系数；若未包裹则安全降级为 1.0（防御性编程）。
  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PortenScale>()?.scale ?? 1.0;

  @override
  bool updateShouldNotify(PortenScale oldWidget) => oldWidget.scale != scale;
}

/// 缩放便捷扩展：`16.s` 表示「16 逻辑像素 × 当前缩放系数」。
extension PortenScaleNumExt on num {
  /// 按当前缩放系数缩放的尺寸值。
  double s(BuildContext context) => toDouble() * PortenScale.of(context);
}
