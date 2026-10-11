/// 设备尺寸等比缩放（对齐「100% 还原 Web 端 + 按设备等比缩放」的原始需求）。
///
/// 设计基准宽度 393px（Web 端移动视口典型值）：在任意真机上，
/// 所有标注尺寸按 ` screenWidth / 393 ` 等比缩放，clamp 到 0.85 ~ 1.15
/// 避免平板上过度拉伸、小屏上过度压缩。
library;

import 'package:flutter/widgets.dart';

/// 等比缩放系数。
class PortenScale {
  const PortenScale._();

  /// 设计基准宽度。
  static const double baseWidth = 393;

  /// 缩放下限 / 上限。
  static const double minScale = 0.85;
  static const double maxScale = 1.15;

  /// 取当前设备的缩放系数。
  static double of(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    return (width / baseWidth).clamp(minScale, maxScale);
  }
}
