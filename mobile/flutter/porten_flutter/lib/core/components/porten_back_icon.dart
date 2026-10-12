/*
 * 通用返回图标（对齐 Web 端 components/common/BackIcon.tsx）：
 * 1024 viewBox 实心左箭头，填充 #1A1A1A。
 */

import 'package:flutter/material.dart';

import 'svg_path.dart';

class PortenBackIcon extends StatelessWidget {
  const PortenBackIcon({super.key, this.size = 28, this.color = const Color(0xFF1A1A1A)});

  final double size;
  final Color color;

  static const List<String> _paths = <String>[
    // 与 Web 端 BackIcon.tsx path 严格一致（左向 chevron）
    'M632.5248 734.9248a25.6 25.6 0 0 1-36.1984 0l-204.8-204.8a25.6 25.6 0 0 1 0-36.1984l204.8-204.8a25.6 25.6 0 0 1 36.1984 36.1984L445.7984 512l186.7264 186.6752a25.6 25.6 0 0 1 0 36.2496z',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _BackIconPainter(color)),
    );
  }
}

class _BackIconPainter extends CustomPainter {
  _BackIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / 1024;
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.save();
    canvas.scale(scale, scale);
    for (final String d in PortenBackIcon._paths) {
      canvas.drawPath(svgPathToUiPath(d), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BackIconPainter oldDelegate) =>
      oldDelegate.color != color;
}
