/*
 * 认证页图标库：lucide 图标的 path 级 100% 还原。
 *
 * 来源：Web 端 lucide-react（HelpCircle / Lock / MoreHorizontal / UserPlus /
 * LogIn / Mail / Phone / User / Check），官方 SVG path 数据逐条绘制；
 * 统一 viewBox 24×24、strokeWidth 1.8（与 Web 端用法一致）、圆头圆角。
 *
 * BackIcon 来自 Web 端 components/common/BackIcon.tsx 的 1024 viewBox 实心箭头。
 */

import 'package:flutter/material.dart';

import 'svg_path.dart';

/// lucide 描边图标画笔。
class LucideStrokePainter extends CustomPainter {
  LucideStrokePainter({
    required this.paths,
    required this.circles,
    required this.color,
    this.strokeWidth = 1.8,
  });

  /// SVG path 数据列表（lucide 官方 path d 属性）。
  final List<String> paths;

  /// 圆形列表 (cx, cy, r)。
  final List<List<double>> circles;

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // viewBox 24 等比缩放到实际尺寸。
    final double scale = size.width / 24;
    canvas.save();
    canvas.scale(scale, scale);

    for (final String d in paths) {
      if (d.isEmpty) continue;
      canvas.drawPath(svgPathToUiPath(d), paint);
    }
    for (final List<double> c in circles) {
      canvas.drawCircle(Offset(c[0], c[1]), c[2], paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant LucideStrokePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

/// lucide 实心/描边通用图标 Widget。
class LucideIcon extends StatelessWidget {
  const LucideIcon(
    this.name, {
    super.key,
    this.size = 20,
    this.color = const Color(0xFF4B5563),
    this.strokeWidth = 1.8,
  });

  final String name;
  final double size;
  final Color color;
  final double strokeWidth;

  static const Map<String, List<Object>> _defs = <String, List<Object>>{
    // HelpCircle：circle r10 + 问号 path + 底部点
    'help-circle': <Object>[
      <String>['M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3'],
      <List<double>>[
        <double>[12, 12, 10],
        <double>[12, 17, 0.5],
      ],
    ],
    // Lock：锁体 rect + 锁梁
    'lock': <Object>[
      <String>[
        'M7 11V7a5 5 0 0 1 10 0v4',
        'M19 21H5a2 2 0 0 1-2-2v-6a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2v6a2 2 0 0 1-2 2z',
      ],
      <List<double>>[],
    ],
    // MoreHorizontal：三个圆点
    'more-horizontal': <Object>[
      <String>[],
      <List<double>>[
        <double>[5, 12, 1],
        <double>[12, 12, 1],
        <double>[19, 12, 1],
      ],
    ],
    // UserPlus：人形 + 加号
    'user-plus': <Object>[
      <String>[
        'M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2',
        'M20 8v6',
        'M23 11h-6',
      ],
      <List<double>>[
        <double>[8.5, 7, 4],
      ],
    ],
    // LogIn：门框 + 进入箭头
    'log-in': <Object>[
      <String>[
        'M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4',
        'M10 17l5-5-5-5',
        'M15 12H3',
      ],
      <List<double>>[],
    ],
    // Mail：信封
    'mail': <Object>[
      <String>[
        'M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z',
        'M22 6l-10 7L2 6',
      ],
      <List<double>>[],
    ],
    // Phone：听筒
    'phone': <Object>[
      <String>[
        'M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z',
      ],
      <List<double>>[],
    ],
    // User：人形
    'user': <Object>[
      <String>['M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2'],
      <List<double>>[
        <double>[12, 7, 4],
      ],
    ],
    // Check：对勾（strokeWidth 3 场景由参数控制）
    'check': <Object>[
      <String>['M20 6L9 17l-5-5'],
      <List<double>>[],
    ],
  };

  @override
  Widget build(BuildContext context) {
    final List<Object> def = _defs[name]!;
    return CustomPaint(
      size: Size.square(size),
      painter: LucideStrokePainter(
        paths: (def[0] as List<String>)
            .where((String d) => d.isNotEmpty)
            .toList(),
        circles: (def[1] as List<List<double>>),
        color: color,
        strokeWidth: strokeWidth,
      ),
    );
  }
}

/// BackIcon：Web 端 common/BackIcon.tsx 的 1024 viewBox 实心左箭头。
class PortenBackIcon extends StatelessWidget {
  const PortenBackIcon({
    super.key,
    this.size = 28,
    this.color = const Color(0xFF1A1A1A),
  });

  final double size;
  final Color color;

  static const String _d =
      'M632.5248 734.9248a25.6 25.6 0 0 1-36.1984 0l-204.8-204.8a25.6 25.6 0 '
      '0 1 0-36.1984l204.8-204.8a25.6 25.6 0 0 1 36.1984 36.1984L445.7984 512l'
      '186.7264 186.6752a25.6 25.6 0 0 1 0 36.2496z';

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _FillPathPainter(d: _d, color: color),
    );
  }
}

class _FillPathPainter extends CustomPainter {
  const _FillPathPainter({required this.d, required this.color});

  final String d;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / 1024;
    canvas.save();
    canvas.scale(scale, scale);
    canvas.drawPath(svgPathToUiPath(d), Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FillPathPainter oldDelegate) =>
      oldDelegate.color != color;
}
