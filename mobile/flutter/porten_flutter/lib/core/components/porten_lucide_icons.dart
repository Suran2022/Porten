/*
 * 首页/资源/知识页 lucide 图标库：path 级 100% 还原。
 *
 * 来源：Web 端 lucide-react（BottomNav / TopBar / SearchBar / MessageCard /
 * ShareCard / ArticleCard / VideoCard / HospitalCard / OrganizationCard），
 * 官方 SVG path 数据逐条绘制；统一 viewBox 24×24、圆头圆角；
 * Web 端 lucide 组件默认 strokeWidth=2，页面显式传 1.8 时按 1.8 绘制。
 *
 * 消息列表左滑动作图标来自 @hugeicons/core-free-icons（EyeOffIcon /
 * FavouriteIcon / PinIcon，size 20 strokeWidth 2），其形态与 lucide
 * eye-off / heart / pin 基本一致，此处按 lucide path 绘制以保持笔触统一。
 */

import 'package:flutter/material.dart';

import 'svg_path.dart';

/// lucide 描边/实心图标画笔（支持 circles 与 fill 模式）。
class LucideShapePainter extends CustomPainter {
  LucideShapePainter({
    required this.paths,
    required this.circles,
    required this.color,
    this.strokeWidth = 2,
    this.fill = false,
  });

  /// SVG path 数据列表（lucide 官方 path d 属性）。
  final List<String> paths;

  /// 圆形列表 (cx, cy, r)。
  final List<List<double>> circles;

  final Color color;

  /// 描边宽度（viewBox 24 坐标系）。
  final double strokeWidth;

  /// true 时按 fill="currentColor" 绘制（如 Play 的 fill 态）。
  final bool fill;

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / 24;
    canvas.save();
    canvas.scale(scale, scale);
    if (fill) {
      final Paint fillPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      for (final String d in paths) {
        if (d.isEmpty) continue;
        canvas.drawPath(svgPathToUiPath(d), fillPaint);
      }
      for (final List<double> c in circles) {
        canvas.drawCircle(Offset(c[0], c[1]), c[2], fillPaint);
      }
    } else {
      final Paint strokePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      for (final String d in paths) {
        if (d.isEmpty) continue;
        canvas.drawPath(svgPathToUiPath(d), strokePaint);
      }
      for (final List<double> c in circles) {
        canvas.drawCircle(Offset(c[0], c[1]), c[2], strokePaint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant LucideShapePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.fill != fill;
}

/// 图标定义：[paths, circles]。
typedef _IconDef = List<Object>;

const Map<String, _IconDef> _kPortenLucideDefs = <String, _IconDef>{
  // MessageSquare（BottomNav 消息 Tab）
  'message-square': <Object>[
    <String>[
      'M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z',
    ],
    <List<double>>[],
  ],
  // FolderOpen（BottomNav 资源 Tab）
  'folder-open': <Object>[
    <String>[
      'm6 14 1.5-2.9A2 2 0 0 1 9.24 10H20a2 2 0 0 1 1.94 2.5l-1.54 6a2 2 0 0 1-1.95 1.5H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h3.9a2 2 0 0 1 1.69.9l.81 1.2a2 2 0 0 0 1.67.9H18a2 2 0 0 1 2 2v2',
    ],
    <List<double>>[],
  ],
  // BookOpen（BottomNav 知识 Tab）
  'book-open': <Object>[
    <String>[
      'M12 7v14',
      'M3 18a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1h5a4 4 0 0 1 4 4 4 4 0 0 1 4-4h5a1 1 0 0 1 1 1v13a1 1 0 0 1-1 1h-6a3 3 0 0 0-3 3 3 3 0 0 0-3-3z',
    ],
    <List<double>>[],
  ],
  // Search（首页搜索栏，w-4 h-4）
  'search': <Object>[
    <String>['m21 21-4.3-4.3'],
    <List<double>>[
      <double>[11, 11, 8],
    ],
  ],
  // ArrowDown（下拉刷新提示条）
  'arrow-down': <Object>[
    <String>['M12 5v14', 'm19 12-7 7-7-7'],
    <List<double>>[],
  ],
  // UserPlus（加号菜单：添加同胞/营地）
  'user-plus': <Object>[
    <String>['M2 21a8 8 0 0 1 13.292-6', 'M19 16v6', 'M22 19h-6'],
    <List<double>>[
      <double>[10, 8, 5],
    ],
  ],
  // CalendarCheck（加号菜单：创建约定）
  'calendar-check': <Object>[
    <String>[
      'M8 2v4',
      'M16 2v4',
      'M3 10h18',
      'M5 4h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2z',
      'm9 16 2 2 4-4',
    ],
    <List<double>>[],
  ],
  // Map（加号菜单：创建旅程）
  'map': <Object>[
    <String>[
      'M14.106 5.553a2 2 0 0 0 1.788 0l3.659-1.83A1 1 0 0 1 21 4.619v12.764a1 1 0 0 1-.553.894l-4.553 2.277a2 2 0 0 1-1.788 0l-4.212-2.106a2 2 0 0 0-1.788 0l-3.659 1.83A1 1 0 0 1 3 19.381V6.618a1 1 0 0 1 .553-.894l4.553-2.277a2 2 0 0 1 1.788 0z',
      'M15 5.764v15',
      'M9 3.236v15',
    ],
    <List<double>>[],
  ],
  // CalendarDays（加号菜单：我的日程）
  'calendar-days': <Object>[
    <String>[
      'M8 2v4',
      'M16 2v4',
      'M3 10h18',
      'M5 4h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2z',
      'M8 14h.01',
      'M12 14h.01',
      'M16 14h.01',
      'M8 18h.01',
      'M12 18h.01',
      'M16 18h.01',
    ],
    <List<double>>[],
  ],
  // Wallet（加号菜单：跨儿财务）
  'wallet': <Object>[
    <String>[
      'M21 12V7H5a2 2 0 0 1 0-4h14v4',
      'M3 5v14a2 2 0 0 0 2 2h16v-5',
      'M18 12a2 2 0 0 0 0 4h4v-4z',
    ],
    <List<double>>[],
  ],
  // Briefcase（加号菜单：跨儿职场）
  'briefcase': <Object>[
    <String>[
      'M16 20V4a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16',
      'M2 8a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2z',
    ],
    <List<double>>[],
  ],
  // ScanLine（加号菜单：扫一扫）
  'scan-line': <Object>[
    <String>[
      'M3 7V5a2 2 0 0 1 2-2h2',
      'M17 3h2a2 2 0 0 1 2 2v2',
      'M21 17v2a2 2 0 0 1-2 2h-2',
      'M7 21H5a2 2 0 0 1-2-2v-2',
      'M7 12h10',
    ],
    <List<double>>[],
  ],
  // StickyNote（加号菜单：记笔记）
  'sticky-note': <Object>[
    <String>[
      'M16 3H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h11l5-5V5a2 2 0 0 0-2-2z',
      'M15 3v4a2 2 0 0 0 2 2h4',
    ],
    <List<double>>[],
  ],
  // Users（首页顶栏联系人 + 资源页组织卡片）
  'users': <Object>[
    <String>[
      'M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2',
      'M22 21v-2a4 4 0 0 0-3-3.87',
      'M16 3.13a4 4 0 0 1 0 7.75',
    ],
    <List<double>>[
      <double>[9, 7, 4],
    ],
  ],
  // Plus（首页顶栏加号菜单，w-7 h-7）
  'plus': <Object>[
    <String>['M5 12h14', 'M12 5v14'],
    <List<double>>[],
  ],
  // Heart（资源页收藏、知识页点赞、左滑「重要」FavouriteIcon）
  'heart': <Object>[
    <String>[
      'M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 7Z',
    ],
    <List<double>>[],
  ],
  // ChevronRight（资源页流程节点 / 组织卡片）
  'chevron-right': <Object>[
    <String>['m9 18 6-6-6-6'],
    <List<double>>[],
  ],
  // Eye（知识页浏览量）
  'eye': <Object>[
    <String>[
      'M2.062 12.348a1 1 0 0 1 0-.696 10.75 10.75 0 0 1 19.876 0 1 1 0 0 1 0 .696 10.75 10.75 0 0 1-19.876 0',
    ],
    <List<double>>[
      <double>[12, 12, 3],
    ],
  ],
  // EyeOff（左滑「隐藏」EyeOffIcon）
  'eye-off': <Object>[
    <String>[
      'M10.733 5.076a10.744 10.744 0 0 1 11.205 6.575 1 1 0 0 1 0 .696 10.747 10.747 0 0 1-1.444 2.49',
      'M14.084 14.158a3 3 0 0 1-4.242-4.242',
      'M17.479 17.499a10.75 10.75 0 0 1-15.417-5.151 1 1 0 0 1 0-.696 10.75 10.75 0 0 1 4.446-5.143',
      'm2 2 20 20',
    ],
    <List<double>>[],
  ],
  // MessageCircle（知识页评论数）
  'message-circle': <Object>[
    <String>['M7.9 20A9 9 0 1 0 4 16.1L2 22Z'],
    <List<double>>[],
  ],
  // Share2（知识页分享数）
  'share-2': <Object>[
    <String>['m8.59 13.51 6.83 3.98', 'm15.41 6.51-6.82 3.98'],
    <List<double>>[
      <double>[18, 5, 3],
      <double>[6, 12, 3],
      <double>[18, 19, 3],
    ],
  ],
  // Play（视频封面播放按钮，fill="currentColor"）
  'play': <Object>[
    <String>['m6 3 14 9-14 9V3z'],
    <List<double>>[],
  ],
  // VolumeX（视频封面静音按钮）
  'volume-x': <Object>[
    <String>[
      'M11 4.702a.705.705 0 0 0-1.203-.498L6.413 7.587A1.4 1.4 0 0 1 5.416 8H3a1 1 0 0 0-1 1v6a1 1 0 0 0 1 1h2.416a1.4 1.4 0 0 1 .997.413l3.383 3.384A.705.705 0 0 0 11 19.298z',
      'm22 9-6 6',
      'm16 9 6 6',
    ],
    <List<double>>[],
  ],
  // Pin（左滑「置顶」PinIcon）
  'pin': <Object>[
    <String>[
      'M12 17v5',
      'M9 10.76a2 2 0 0 1-1.11 1.79l-1.78.9A2 2 0 0 0 5 15.24V16a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-.76a2 2 0 0 0-1.11-1.79l-1.78-.9A2 2 0 0 1 15 10.76V6h1a2 2 0 0 0 0-4H8a2 2 0 0 0 0 4h1z',
    ],
    <List<double>>[],
  ],
  // Bot（MessageCard 无头像系统账号占位）
  'bot': <Object>[
    <String>[
      'M12 8V4H8',
      'M4 8h16a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2v-8a2 2 0 0 1 2-2Z',
      'M2 14h2',
      'M20 14h2',
      'M15 13v2',
      'M9 13v2',
    ],
    <List<double>>[],
  ],

  // ===== r18-3 新页面新增（lucide 官方 path，24×24） =====

  'x': <Object>[
    <String>[
      'M18 6 6 18',
      'm6 6 12 12',
    ],
    <List<double>>[],
  ],
  'check': <Object>[
    <String>['M20 6 9 17l-5-5'],
    <List<double>>[],
  ],
  'square': <Object>[
    <String>['M5 3h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2Z'],
    <List<double>>[],
  ],
  'pause': <Object>[
    <String>[
      'M14 5a1 1 0 0 1 1-1h2a1 1 0 0 1 1 1v14a1 1 0 0 1-1 1h-2a1 1 0 0 1-1-1Z',
      'M6 5a1 1 0 0 1 1-1h2a1 1 0 0 1 1 1v14a1 1 0 0 1-1 1H7a1 1 0 0 1-1-1Z',
    ],
    <List<double>>[],
  ],
  'settings': <Object>[
    <String>[
      'M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z',
    ],
    <List<double>>[<double>[12, 12, 3]],
  ],
  'mail': <Object>[
    <String>[
      'M4 4h16a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2Z',
      'm22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7',
    ],
    <List<double>>[],
  ],
  'bell': <Object>[
    <String>[
      'M10.268 21a2 2 0 0 0 3.464 0',
      'M3.262 15.326A1 1 0 0 0 4 17h16a1 1 0 0 0 .74-1.673C19.41 13.956 18 12.499 18 8A6 6 0 0 0 6 8c0 4.499-1.411 5.956-2.738 7.326',
    ],
    <List<double>>[],
  ],
  'pencil': <Object>[
    <String>[
      'M21.174 6.812a1 1 0 0 0-3.986-3.987L3.842 16.174a2 2 0 0 0-.5.83l-1.321 4.352a.5.5 0 0 0 .623.622l4.353-1.32a2 2 0 0 0 .83-.497z',
      'm15 5 4 4',
    ],
    <List<double>>[],
  ],
  'smile-plus': <Object>[
    <String>[
      'M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z',
      'M8.5 14s1.5 2 3.5 2 3.5-2 3.5-2',
      'M19 3v4',
      'M17 5h4',
    ],
    <List<double>>[],
  ],
  'smile': <Object>[
    <String>[
      'M22 12a10 10 0 1 1-20 0 10 10 0 0 1 20 0Z',
      'M8 14s1.5 2 4 2 4-2 4-2',
      'M9 9h.01',
      'M15 9h.01',
    ],
    <List<double>>[],
  ],
  'phone': <Object>[
    <String>[
      'M13.832 16.568a1 1 0 0 0 1.213-.303l.355-.465A2 2 0 0 1 17 15h3a2 2 0 0 1 2 2v3a2 2 0 0 1-2 2A18 18 0 0 1 2 4a2 2 0 0 1 2-2h3a2 2 0 0 1 2 2v3a2 2 0 0 1-.8 1.6l-.468.351a1 1 0 0 0-.292 1.233 14 14 0 0 0 6.392 6.384',
    ],
    <List<double>>[],
  ],
  'video': <Object>[
    <String>[
      'm22 8-6 4 6 4V8Z',
      'M4 6h10a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2Z',
    ],
    <List<double>>[],
  ],
  'more-vertical': <Object>[
    <String>[],
    <List<double>>[<double>[12, 5, 1], <double>[12, 12, 1], <double>[12, 19, 1]],
  ],
  'mic': <Object>[
    <String>[
      'M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3Z',
      'M19 10v2a7 7 0 0 1-14 0v-2',
      'M12 19v3',
    ],
    <List<double>>[],
  ],
  'image': <Object>[
    <String>[
      'M5 3h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2Z',
      'm21 15-3.086-3.086a2 2 0 0 0-2.828 0L6 21',
    ],
    <List<double>>[<double>[9, 9, 2]],
  ],
  'file-text': <Object>[
    <String>[
      'M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z',
      'M14 2v4a2 2 0 0 0 2 2h4',
      'M16 13H8',
      'M16 17H8',
      'M10 9H8',
    ],
    <List<double>>[],
  ],
  'users-round': <Object>[
    <String>[
      'M18 21a8 8 0 0 0-16 0',
      'M22 20c0-3.37-2-6.5-4-8a5 5 0 0 0-.45-8.3',
    ],
    <List<double>>[<double>[10, 8, 5]],
  ],
  'tent': <Object>[
    <String>[
      'M3.5 21 14 3',
      'M20.5 21 10 3',
      'M15.5 21 10 10l-5.5 11',
      'M14 3h7v7',
      'M3 21h18',
    ],
    <List<double>>[],
  ],
  'sparkles': <Object>[
    <String>[
      'M9.937 15.5A2 2 0 0 0 8.5 14.063l-6.135-1.582a.5.5 0 0 1 0-.962L8.5 9.936A2 2 0 0 0 9.937 8.5l1.582-6.135a.5.5 0 0 1 .963 0L14.063 8.5A2 2 0 0 0 15.5 9.937l6.135 1.581a.5.5 0 0 1 0 .964L15.5 14.063a2 2 0 0 0-1.437 1.437l-1.582 6.135a.5.5 0 0 1-.963 0z',
      'M20 3v4',
      'M22 5h-4',
      'M4 17v2',
      'M5 18H3',
    ],
    <List<double>>[],
  ],
  'map-pin': <Object>[
    <String>[
      'M20 10c0 4.993-5.539 10.193-7.399 11.799a1 1 0 0 1-1.202 0C9.539 20.193 4 14.993 4 10a8 8 0 0 1 16 0',
    ],
    <List<double>>[<double>[12, 10, 3]],
  ],
  'alert-circle': <Object>[
    <String>[
      'M22 12a10 10 0 1 1-20 0 10 10 0 0 1 20 0Z',
      'M12 8v4',
      'M12 16h.01',
    ],
    <List<double>>[],
  ],
  'paperclip': <Object>[
    <String>[
      'm16 6-8.414 8.586a2 2 0 0 0 2.829 2.829l8.414-8.586a4 4 0 1 0-5.657-5.657l-8.379 8.551a6 6 0 1 0 8.485 8.485l8.379-8.551',
    ],
    <List<double>>[],
  ],
  'music2': <Object>[
    <String>['M9 18V5l12-2v13'],
    <List<double>>[<double>[6, 18, 3], <double>[18, 16, 3]],
  ],
  'star': <Object>[
    <String>[
      'M11.525 2.295a.53.53 0 0 1 .95 0l2.31 4.679a2.123 2.123 0 0 0 1.595 1.16l5.166.756a.53.53 0 0 1 .294.904l-3.736 3.638a2.123 2.123 0 0 0-.611 1.878l.882 5.14a.53.53 0 0 1-.771.56l-4.618-2.428a2.122 2.122 0 0 0-1.973 0L6.396 21.01a.53.53 0 0 1-.77-.56l.881-5.139a2.122 2.122 0 0 0-.611-1.879L2.16 9.795a.53.53 0 0 1 .294-.906l5.165-.755a2.122 2.122 0 0 0 1.597-1.16z',
    ],
    <List<double>>[],
  ],
  'contact': <Object>[
    <String>[
      'M5 3h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2Z',
      'M7 12h2',
      'M7 15h6',
    ],
    <List<double>>[],
  ],
  'building2': <Object>[
    <String>[
      'M6 22V4a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v18Z',
      'M6 12H4a2 2 0 0 0-2 2v6a2 2 0 0 0 2 2h2',
      'M18 9h2a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2h-2',
      'M10 6h4',
      'M10 10h4',
      'M10 14h4',
      'M10 18h4',
    ],
    <List<double>>[],
  ],
  'stethoscope': <Object>[
    <String>[
      'M4.8 2.3A.3.3 0 1 0 5 2H4a2 2 0 0 0-2 2v5a6 6 0 0 0 6 6a6 6 0 0 0 6-6V4a2 2 0 0 0-2-2h-1a.2.2 0 1 0 .3.3',
      'M8 15v1a6 6 0 0 0 6 6a6 6 0 0 0 6-6v-4',
    ],
    <List<double>>[<double>[20, 10, 2]],
  ],
  'graduation-cap': <Object>[
    <String>[
      'M21.42 10.922a1 1 0 0 0-.019-1.838L12.83 5.18a2 2 0 0 0-1.66 0L2.6 9.08a1 1 0 0 0 0 1.832l8.57 3.908a2 2 0 0 0 1.66 0z',
      'M22 10v6',
      'M6 12.5V16a6 3 0 0 0 12 0v-3.5',
    ],
    <List<double>>[],
  ],
  'chevron-down': <Object>[
    <String>['m6 9 6 6 6-6'],
    <List<double>>[],
  ],
};

/// lucide 图标 Widget（stroke 或 fill 模式）。
class PortenLucideIcon extends StatelessWidget {
  const PortenLucideIcon(
    this.name, {
    super.key,
    this.size = 24,
    this.color = const Color(0xFF52525B),
    this.strokeWidth = 2,
    this.fill = false,
  });

  final String name;
  final double size;
  final Color color;
  final double strokeWidth;

  /// 实心模式（Play fill="currentColor"）。
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final _IconDef? def = _kPortenLucideDefs[name];
    assert(def != null, 'PortenLucideIcon: 未注册的图标 $name');
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: LucideShapePainter(
          paths: (def![0] as List<String>).cast<String>(),
          circles: (def[1] as List<List<double>>).cast<List<double>>(),
          color: color,
          strokeWidth: strokeWidth,
          fill: fill,
        ),
      ),
    );
  }
}

/// 知识顶栏「分享」入口图标（Web 端 KnowledgeTopBar.tsx 内联 SVG，1024 viewBox 实心）。
class PortenShareGlyph extends StatelessWidget {
  const PortenShareGlyph({super.key, this.size = 16, this.color = const Color(0xFF1A1A1A)});

  final double size;
  final Color color;

  static const List<String> _paths = <String>[
    'M173.9264 670.8736v-307.2a179.2 179.2 0 0 1 179.2-179.2h153.6a25.6 25.6 0 0 1 0 51.2h-153.6a128 128 0 0 0-128 128v307.2a128 128 0 0 0 128 128h307.2a128 128 0 0 0 128-128v-153.6a25.6 25.6 0 0 1 51.2 0v153.6a179.2 179.2 0 0 1-179.2 179.2h-307.2a179.2 179.2 0 0 1-179.2-179.2z',
    'M660.3264 645.2736a25.6 25.6 0 0 1 0 51.2h-307.2a25.6 25.6 0 0 1 0-51.2h307.2zM795.4432 192.3584a25.6 25.6 0 0 1 36.864 35.4816l-307.1488 319.6416a25.6 25.6 0 0 1-36.864-35.4816l307.1488-319.6416z',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ShareGlyphPainter(color: color),
      ),
    );
  }
}

class _ShareGlyphPainter extends CustomPainter {
  _ShareGlyphPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / 1024;
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.save();
    canvas.scale(scale, scale);
    for (final String d in PortenShareGlyph._paths) {
      canvas.drawPath(svgPathToUiPath(d), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ShareGlyphPainter oldDelegate) =>
      oldDelegate.color != color;
}
