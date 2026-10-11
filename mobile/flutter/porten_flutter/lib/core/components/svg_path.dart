/*
 * SVG path → ui.Path 转换工具（基于 path_parsing，与 flutter_svg 同源解析器）。
 *
 * 用途：lucide 图标与 BackIcon 的官方 path 数据在 Flutter 侧逐条重建，
 * 保证图标 100% 还原 Web 端。
 */

import 'dart:ui' as ui;

import 'package:path_parsing/path_parsing.dart';

/// PathProxy 实现：把 SVG 命令写入 ui.Path（弧线由解析器归一化为贝塞尔）。
class _UiPathProxy extends PathProxy {
  _UiPathProxy(this.path);

  final ui.Path path;

  @override
  void moveTo(double x, double y) => path.moveTo(x, y);

  @override
  void lineTo(double x, double y) => path.lineTo(x, y);

  @override
  void cubicTo(double x1, double y1, double x2, double y2, double x3, double y3) =>
      path.cubicTo(x1, y1, x2, y2, x3, y3);

  @override
  void close() => path.close();
}

/// 解析 SVG path 数据（d 属性）为 ui.Path。
ui.Path svgPathToUiPath(String d) {
  final ui.Path path = ui.Path();
  writeSvgPathDataToPath(d, _UiPathProxy(path));
  return path;
}
