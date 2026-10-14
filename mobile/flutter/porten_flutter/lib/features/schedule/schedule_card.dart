/*
 * 时间线日程卡片（100% 复刻 Web 端 components/schedule/ScheduleCard.tsx）。
 *
 * Web 端实现：
 *   - 绝对定位覆盖刻度行：SCHEDULE_CARD_LEFT=80 / RIGHT=20，
 *     top = (startMin/60)*hourPx；收起态高度 = max(hourPx, 时间跨度)，
 *     展开态高度自适应（minHeight 仍为收起高度）；
 *   - 卡片 rounded-xl px-3 py-1.5 白字 shadow-sm，展开 shadow-lg，
 *     拖拽中 ring-2 ring-white/80；配色 pink #F7C5D0 / coffee #C7A98B /
 *     blue #A9C9E8；
 *   - 首行 text-[11px] tabular-nums「HH:mm - HH:mm」；次行 text-sm
 *     font-medium 标题（缺省「快速日程」）；
 *   - 展开态追加：详情（text-xs pre-wrap）、📍地点、🔗关联、
 *     参与者（头像 28 + @昵称 text-[10px] #E88CA8）；
 *   - 单击延迟 250ms 展开/收起，双击直接打开编辑（同 Web 计时器区分）；
 *   - 底部拖拽手柄 h-2.5（白 60% 小条）：拖到目标时间线位置调整
 *     结束时间，15 分钟吸附，钳制在 [start+15min, 24:00]。
 */

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/data/schedule_mock.dart';

/// 卡片左缘：时间线容器左留白 20px + 时间文本 48px + 间距 12px（同 Web）。
const double kScheduleCardLeft = 80;

/// 卡片右缘距容器右侧留白（同 Web）。
const double kScheduleCardRight = 20;

/// 拖拽结束时间的吸附粒度（分钟，同 Web）。
const int kResizeSnapMinutes = 15;

/// 日程卡片背景色（同 Web SCHEDULE_CARD_BG）。
const Map<ScheduleColor, Color> kScheduleCardBg = <ScheduleColor, Color>{
  ScheduleColor.pink: Color(0xFFF7C5D0),
  ScheduleColor.coffee: Color(0xFFC7A98B),
  ScheduleColor.blue: Color(0xFFA9C9E8),
};

/// 参与者昵称粉色文本（同 Web PINK_TEXT）。
const Color kSchedulePinkText = Color(0xFFE88CA8);

/// HH:mm 转分钟数（同 Web hmmToMinutes）。
int hmmToMinutes(String hhmm) {
  final List<String> parts = hhmm.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

/// 分钟数转 HH:mm；>= 1440 显示 24:00（同 Web minutesToHHmm）。
String minutesToHHmm(int minutes) {
  if (minutes >= 24 * 60) return '24:00';
  final int h = minutes ~/ 60;
  final int m = minutes % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

class ScheduleCard extends StatefulWidget {
  const ScheduleCard({
    super.key,
    required this.item,
    required this.expanded,
    required this.hourPx,
    required this.relatedLabel,
    required this.participants,
    required this.onToggleExpand,
    required this.onOpenEdit,
    required this.onEndTimeChange,
  });

  final ScheduleItem item;

  /// 是否展开（展示详情）。
  final bool expanded;

  /// 单小时高度（px），与时间线刻度行一致。
  final double hourPx;

  /// 已解析的关联项名称（关联旅程 / 关联约定），展开时显示。
  final String? relatedLabel;

  /// 已选参与同胞（含头像），展开时显示。
  final List<ScheduleComrade> participants;

  final ValueChanged<int> onToggleExpand;
  final ValueChanged<ScheduleItem> onOpenEdit;

  /// 拖拽结束后提交新的结束时间（HH:mm）。
  final void Function(int id, String endTime) onEndTimeChange;

  @override
  State<ScheduleCard> createState() => _ScheduleCardState();
}

class _ScheduleCardState extends State<ScheduleCard> {
  /// 拖拽预览的结束时间（分钟）；null 表示未在拖拽。
  int? _previewEndMin;
  bool _dragging = false;

  /// 拖拽起点 Y 与基准结束时间。
  double? _dragStartY;
  int _dragBaseEnd = 0;

  /// 单击/双击区分：单击延迟 250ms 触发展开收起，双击直接打开编辑。
  Timer? _clickTimer;

  @override
  void dispose() {
    _clickTimer?.cancel();
    super.dispose();
  }

  int get _startMin => hmmToMinutes(widget.item.startTime);
  int get _baseEndMin => widget.item.endTime != null
      ? hmmToMinutes(widget.item.endTime!)
      : _startMin + 60;

  /// 收起态高度跟随时间跨度（拖拽中实时预览），无结束时间默认 1 小时。
  double get _collapsedHeight {
    final int displayEndMin = _previewEndMin ?? _baseEndMin;
    final double span = ((displayEndMin - _startMin) / 60) * widget.hourPx;
    return span > widget.hourPx ? span : widget.hourPx;
  }

  void _handleTap() {
    if (_clickTimer != null) {
      _clickTimer!.cancel();
      _clickTimer = null;
      return;
    }
    _clickTimer = Timer(const Duration(milliseconds: 250), () {
      _clickTimer = null;
      widget.onToggleExpand(widget.item.id);
    });
  }

  void _handleDoubleTap() {
    _clickTimer?.cancel();
    _clickTimer = null;
    widget.onOpenEdit(widget.item);
  }

  void _onDragStart(DragStartDetails details) {
    _dragStartY = details.globalPosition.dy;
    _dragBaseEnd = _baseEndMin;
    setState(() => _dragging = true);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final double? startY = _dragStartY;
    if (startY == null) return;
    final double deltaMin = (details.globalPosition.dy - startY) /
        (widget.hourPx / 60); // 每像素对应分钟数
    final int snapped =
        ((_dragBaseEnd + deltaMin) / kResizeSnapMinutes).round() * kResizeSnapMinutes;
    final int clamped =
        snapped.clamp(_startMin + kResizeSnapMinutes, 24 * 60);
    setState(() => _previewEndMin = clamped);
  }

  void _onDragEnd(DragEndDetails details) {
    final int? preview = _previewEndMin;
    _dragStartY = null;
    setState(() {
      _dragging = false;
      _previewEndMin = null;
    });
    if (preview != null) {
      widget.onEndTimeChange(widget.item.id, minutesToHHmm(preview));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScheduleItem item = widget.item;
    final bool expanded = widget.expanded;
    final Color bg = kScheduleCardBg[item.color] ?? kScheduleCardBg[ScheduleColor.pink]!;

    return Positioned(
      left: kScheduleCardLeft,
      right: kScheduleCardRight,
      top: (_startMin / 60) * widget.hourPx,
      // 展开态高度自适应：不设 height，仅约束 minHeight（同 Web）
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: _collapsedHeight),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _handleTap,
          onDoubleTap: _handleDoubleTap,
          child: Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12), // rounded-xl
              border: _dragging
                  ? Border.all(
                      color: const Color(0xFFFFFFFF).withValues(alpha: 0.8), // ring-white/80
                      width: 2, // ring-2
                    )
                  : null,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: const Color(0xFF000000)
                      .withValues(alpha: expanded ? 0.10 : 0.05), // shadow-lg / shadow-sm
                  blurRadius: expanded ? 12 : 2,
                  offset: expanded ? const Offset(0, 6) : const Offset(0, 1),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // px-3 py-1.5
            child: Stack(
              children: <Widget>[
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // 首行：HH:mm - HH:mm
                    Text(
                      '${item.startTime}${item.endTime != null ? ' - ${item.endTime}' : ''}',
                      style: TextStyle(
                        fontSize: 11, // text-[11px]
                        height: 1.25, // leading-tight
                        color: const Color(0xFFFFFFFF).withValues(alpha: 0.9), // opacity-90
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures(), // tabular-nums
                        ],
                      ),
                    ),
                    // 次行：标题（缺省「快速日程」）
                    Text(
                      item.title ?? '快速日程',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14, // text-sm
                        height: 1.375, // leading-snug
                        fontWeight: FontWeight.w500, // font-medium
                        color: Color(0xFFFFFFFF),
                      ),
                    ),
                    // 展开态：详情
                    if (expanded && item.detail != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4), // mt-1
                        child: Text(
                          item.detail!,
                          style: TextStyle(
                            fontSize: 12, // text-xs
                            height: 1.625, // leading-relaxed
                            color: const Color(0xFFFFFFFF)
                                .withValues(alpha: 0.95), // opacity-95
                          ),
                        ),
                      ),
                    // 展开态：地点
                    if (expanded && item.place != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2), // mt-0.5
                        child: Text(
                          '📍 ${item.place}',
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFFFFFFFF)
                                .withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    // 展开态：关联项
                    if (expanded && widget.relatedLabel != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '🔗 ${item.relatedType == ScheduleRelatedType.trip ? '旅程' : '约定'} · ${widget.relatedLabel}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFFFFFFFF)
                                .withValues(alpha: 0.95),
                          ),
                        ),
                      ),
                    // 展开态：参与者
                    if (expanded && widget.participants.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6), // mt-1.5
                        child: Wrap(
                          spacing: 10, // gap-x-2.5
                          runSpacing: 4, // gap-y-1
                          children: <Widget>[
                            for (final ScheduleComrade p
                                in widget.participants)
                              SizedBox(
                                width: 44, // w-11
                                child: Column(
                                  children: <Widget>[
                                    ClipOval(
                                      child: Image.asset(
                                        p.avatarAsset,
                                        width: 28, // w-7
                                        height: 28, // h-7
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => Container(
                                          width: 28,
                                          height: 28,
                                          color: const Color(0xFFFFFFFF)
                                              .withValues(alpha: 0.4), // bg-white/40
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 2), // mt-0.5
                                    Text(
                                      '@${p.nickname}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 10, // text-[10px]
                                        height: 1.25, // leading-tight
                                        fontWeight: FontWeight.w500,
                                        color: kSchedulePinkText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
                // 底部拖拽手柄：h-2.5，白 60% 小条
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 10, // h-2.5
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragStart: _onDragStart,
                    onVerticalDragUpdate: _onDragUpdate,
                    onVerticalDragEnd: _onDragEnd,
                    child: Center(
                      child: Container(
                        width: 32, // w-8
                        height: 4, // h-1
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFFFF)
                              .withValues(alpha: 0.6), // bg-white/60
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
