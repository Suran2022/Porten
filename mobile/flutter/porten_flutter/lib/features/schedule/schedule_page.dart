/*
 * 我的日程独立页面（100% 复刻 Web 端 pages/SchedulePage.tsx 移动端形态）。
 *
 * Web 端实现：
 *   - 白底，从右滑入 translate-x-full → 0（300ms cubic-bezier(0.25,0.1,0.25,1)）；
 *   - 顶部栏：返回图标 + 居中「我的日程」+ 右 w-8 占位；
 *   - 年月行：grid-cols-3，左对齐年份 + 居中月份，跟随日期条可视区域
 *     第一周（跨月周取周四所在月）；
 *   - 星期标头：星期一~星期日，text-xs font-semibold gray-400；
 *   - 日期条：以今天为中心向前 16 周、向后 20 周的周网格，按周 snap
 *     横滑；日期卡 h-14 rounded-xl：选中 bg #F7C5D0 白字 / 未选
 *     bg gray-500/10 gray-800；数字 absolute top-2，节日名 bottom-1.5
 *     （rose-400 / 选中 white/90），有日程右上角 emerald-300 小绿点；
 *   - 时间线：0-23 点刻度（HOUR_PX=36，内容高 24*36+160），单击空白
 *     刻度行原位快捷创建（标题选填 + 详情必填）；日程卡片层绝对定位；
 *   - 右下悬浮加号（56 圆、bg #F7C5D0）打开完整创建弹层；
 *   - 卡片交互：单击 250ms 延迟展开/收起、双击打开编辑、底部手柄
 *     拖拽调整结束时间（15 分钟吸附）。
 */

import 'package:flutter/material.dart';

import '../../core/components/porten_back_icon.dart';
import '../../core/components/porten_lucide_icons.dart';
import '../../core/components/porten_toast.dart';
import '../../core/data/schedule_mock.dart';
import '../../core/design/porten_colors.dart';
import 'create_schedule_sheet.dart';
import 'schedule_card.dart';

/// 选中日期与创建按钮的淡粉色不饱和底色（同 Web SCHEDULE_PINK）。
const Color kSchedulePink = Color(0xFFF7C5D0);

/// 日期网格范围：以今天为中心，向前 16 周、向后 20 周（同 Web）。
const int kWeeksBefore = 16;
const int kWeeksAfter = 20;

/// 星期标头（周一起始，与周网格顺序一致，同 Web）。
const List<String> kWeekdayLabels = <String>[
  '星期一',
  '星期二',
  '星期三',
  '星期四',
  '星期五',
  '星期六',
  '星期日',
];

/// 时间线单小时高度（px），刻度行与日程卡片共用（同 Web HOUR_PX）。
const double kHourPx = 36;

/// 时间线内容高度：24 小时刻度 + 底部预留（同 Web TIMELINE_HEIGHT）。
const double kTimelineHeight = 24 * kHourPx + 160;

/// 节日名文本色（Web text-rose-400）。
const Color kRose400 = Color(0xFFFB7185);

/// 有日程绿点（Web bg-emerald-300）。
const Color kEmerald300 = Color(0xFF6EE7B7);

/// Date 转 YYYY-MM-DD（同 Web toDateKey）。
String toDateKey(DateTime date) {
  final String m = date.month.toString().padLeft(2, '0');
  final String day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$m-$day';
}

/// 取周一作为一周起点（当天 0 点，同 Web startOfWeek）。
DateTime startOfWeek(DateTime date) {
  final int day = date.weekday - 1; // 周一=0 … 周日=6
  return DateTime(date.year, date.month, date.day - day);
}

/// 生成周网格：每行一周（7 天，周一起始，同 Web buildWeeks）。
List<List<DateTime>> buildWeeks() {
  final DateTime now = DateTime.now();
  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime first = startOfWeek(today).subtract(Duration(days: 7 * kWeeksBefore));
  return List<List<DateTime>>.generate(
    kWeeksBefore + kWeeksAfter + 1,
    (int w) => List<DateTime>.generate(
      7,
      (int i) => DateTime(first.year, first.month, first.day + w * 7 + i),
    ),
  );
}

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  final List<List<DateTime>> _weeks = buildWeeks();
  final ScrollController _stripController = ScrollController();

  /// 日程列表（mock 引擎内存态）与有日程的日期集合（驱动绿点）。
  List<ScheduleItem> _items = ScheduleStore.items;

  /// 选中日期（默认今天）与年月行显示（跟随日期条可视区域第一周）。
  late String _selected;
  late int _viewYear;
  late int _viewMonth;
  int _visibleWeekIndex = 0;

  /// 时间线交互：展开的日程卡 / 双击编辑的日程 / 完整创建弹层 / 快捷创建草稿。
  int? _expandedId;
  int? _quickDraftHour;
  String _draftTitle = '';
  String _draftDetail = '';

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    _selected = toDateKey(now);
    _viewYear = now.year;
    _viewMonth = now.month;
    _stripController.addListener(_onStripScroll);
    // 初始定位到选中日期所在周（同 Web：scrollLeft = index * clientWidth）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final double width = MediaQuery.sizeOf(context).width;
      _stripController.jumpTo(_visibleWeekIndex * width);
    });
  }

  @override
  void dispose() {
    _stripController.removeListener(_onStripScroll);
    _stripController.dispose();
    super.dispose();
  }

  /// 年月行跟随日期条可视区域第一周（每次滑动对齐一整周）；
  /// 跨月周取周中点（周四）所在月，与该周多数天一致（同 Web）。
  void _onStripScroll() {
    if (!_stripController.hasClients) return;
    final double width = _stripController.position.viewportDimension;
    if (width <= 0) return;
    final int index =
        (_stripController.offset / width).round().clamp(0, _weeks.length - 1);
    if (index == _visibleWeekIndex) return;
    _visibleWeekIndex = index;
    final DateTime mid = _weeks[index][3];
    setState(() {
      _viewYear = mid.year;
      _viewMonth = mid.month;
    });
  }

  void _reload() {
    setState(() => _items = ScheduleStore.items);
  }

  Set<String> get _scheduleDates =>
      _items.map((ScheduleItem it) => it.date).toSet();

  List<ScheduleItem> get _dayItems =>
      _items.where((ScheduleItem it) => it.date == _selected).toList();

  // ------------------------------------------------------------ 时间线交互

  /// 单击空白刻度行 → 原位快捷创建（标题选填 + 详情）。
  void _handleTimelineClick(int hour) {
    setState(() {
      _quickDraftHour = hour;
      _draftTitle = '';
      _draftDetail = '';
    });
  }

  void _handleQuickCancel() {
    setState(() {
      _quickDraftHour = null;
      _draftTitle = '';
      _draftDetail = '';
    });
  }

  void _handleQuickSave() {
    final int? hour = _quickDraftHour;
    if (hour == null) return;
    if (_draftDetail.trim().isEmpty) {
      PortenToast.show('写点什么再保存吧', icon: ToastIcon.error);
      return;
    }
    ScheduleStore.create(ScheduleItem(
      id: 0, // Store 内部分配
      date: _selected,
      startTime: '${hour.toString().padLeft(2, '0')}:00',
      endTime: hour < 23
          ? '${(hour + 1).toString().padLeft(2, '0')}:00'
          : '24:00',
      title: _draftTitle.trim().isEmpty ? null : _draftTitle.trim(),
      detail: _draftDetail.trim(),
      category: null,
      relatedType: null,
      relatedId: null,
      place: null,
      participantIds: const <int>[],
      color: ScheduleColor.pink, // Store 创建时随机覆盖
      source: ScheduleSource.quick,
    ));
    _handleQuickCancel();
    _reload();
    PortenToast.show('日程已创建', icon: ToastIcon.success);
  }

  /// 拖拽调整结束时间：乐观更新 + 同步 mock 引擎（同 Web）。
  void _handleEndTimeChange(int id, String endTime) {
    setState(() => _items = _items
        .map((ScheduleItem it) =>
            it.id == id ? it.copyWith(endTime: endTime) : it)
        .toList());
    try {
      ScheduleStore.updateEndTime(id, endTime);
    } catch (_) {
      // 乐观更新，失败不回滚演示数据（同 Web）
    }
  }

  void _handleToggleExpand(int id) {
    setState(() => _expandedId = _expandedId == id ? null : id);
  }

  /// 双击打开完整编辑弹层（同 Web onOpenEdit）。
  void _handleOpenEdit(ScheduleItem item) {
    CreateScheduleSheet.show(context, editing: item, onSaved: _reload);
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final Set<String> scheduleDates = _scheduleDates;
    final List<ScheduleItem> dayItems = _dayItems;

    return Scaffold(
      backgroundColor: PortenColor.white,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: <Widget>[
            Column(
              children: <Widget>[
                _buildTopBar(),
                _buildYearMonthRow(),
                _buildWeekdayHeader(),
                _buildDateStrip(screenWidth, scheduleDates),
                _buildTimeline(dayItems),
              ],
            ),
            // 悬浮创建按钮：右下角常规位置，打开完整创建弹层
            Positioned(
              right: 20, // right-5
              bottom: 24, // bottom-6
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => CreateScheduleSheet.show(
                  context,
                  onSaved: _reload,
                ),
                child: Container(
                  width: 56, // w-14
                  height: 56, // h-14
                  decoration: BoxDecoration(
                    color: kSchedulePink,
                    borderRadius: BorderRadius.circular(28), // rounded-full
                    boxShadow: <BoxShadow>[
                      // shadow-md
                      BoxShadow(
                        color: const Color(0xFF000000).withValues(alpha: 0.10),
                        blurRadius: 6,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: const Color(0xFF000000).withValues(alpha: 0.10),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: PortenLucideIcon('plus',
                        size: 24, color: PortenColor.white, strokeWidth: 2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------ 顶部区域

  Widget _buildTopBar() {
    return Padding(
      // px-4 + -ml-2 → 左 8：返回键盒 [8,48]，与 Web margin 盒逐像素一致。
      // （Flutter Padding 断言拒绝负内边距、Transform 不外扩命中区，
      // 故以收窄左内距等价实现负外距；同 chat_page 顶栏范式）
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
      child: SizedBox(
        height: 40, // w-10 h-10
        child: Row(
          children: <Widget>[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
              child: const SizedBox(
                width: 40, // w-10
                height: 40, // h-10
                child: Center(child: PortenBackIcon(size: 28)), // w-7 h-7
              ),
            ),
            const Expanded(
              child: Text(
                '我的日程',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18, // text-lg
                  fontWeight: FontWeight.w500, // font-medium
                  color: PortenColor.gray900,
                ),
              ),
            ),
            const SizedBox(width: 32), // w-8
          ],
        ),
      ),
    );
  }

  Widget _buildYearMonthRow() {
    final TextStyle style = const TextStyle(
      fontSize: 16, // text-base
      fontWeight: FontWeight.w600, // font-semibold
      color: PortenColor.gray900,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8), // px-5 pt-1 pb-2
      child: Row(
        children: <Widget>[
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft, // justify-self-start
              child: Text('$_viewYear年', style: style),
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.center, // justify-self-center
              child: Text('$_viewMonth月', style: style),
            ),
          ),
          const Expanded(child: SizedBox.shrink()),
        ],
      ),
    );
  }

  Widget _buildWeekdayHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4), // px-2 pt-2 pb-1
      child: Row(
        children: <Widget>[
          for (int i = 0; i < kWeekdayLabels.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 4), // gap-1
            Expanded(
              child: Text(
                kWeekdayLabels[i],
                textAlign: TextAlign.center,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 12, // text-xs
                  fontWeight: FontWeight.w600, // font-semibold
                  height: 1, // leading-none
                  color: PortenColor.gray400,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDateStrip(double screenWidth, Set<String> scheduleDates) {
    return SizedBox(
      height: 56, // h-14
      child: ListView.builder(
        controller: _stripController,
        scrollDirection: Axis.horizontal,
        itemExtent: screenWidth, // 每周一屏，snap 按周对齐
        physics: const PageScrollPhysics(), // snap-x snap-mandatory
        itemCount: _weeks.length,
        itemBuilder: (BuildContext context, int weekIndex) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8), // px-2
            child: Row(
              children: <Widget>[
                for (int i = 0; i < 7; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: 4), // gap-1
                  Expanded(
                    child: _DateCell(
                      date: _weeks[weekIndex][i],
                      selected: toDateKey(_weeks[weekIndex][i]) == _selected,
                      holiday: getHolidayName(toDateKey(_weeks[weekIndex][i])),
                      hasSchedule:
                          scheduleDates.contains(toDateKey(_weeks[weekIndex][i])),
                      onTap: () => setState(() =>
                          _selected = toDateKey(_weeks[weekIndex][i])),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------ 时间线

  Widget _buildTimeline(List<ScheduleItem> dayItems) {
    // 关联项 id → 名称（"trip-1" / "agreement-2"）
    final Map<String, String> relatedLabelMap = <String, String>{
      for (final ScheduleRelatedItem t in kMockTrips) 'trip-${t.id}': t.label,
      for (final ScheduleRelatedItem a in kMockAgreements)
        'agreement-${a.id}': a.label,
    };
    // 参与者 id → 完整信息（头像/昵称）
    final Map<int, ScheduleComrade> comradeMap = <int, ScheduleComrade>{
      for (final ScheduleComrade c in kMockComrades) c.id: c,
    };

    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 16), // mt-4
        child: SizedBox(
          height: kTimelineHeight,
          child: Stack(
            children: <Widget>[
              // 刻度行铺底（单击空白处快捷创建）
              for (int hour = 0; hour < 24; hour++)
                Positioned(
                  left: 20, // left-5
                  right: 20, // right-5
                  top: hour * kHourPx,
                  height: kHourPx,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _handleTimelineClick(hour),
                    child: Row(
                      children: <Widget>[
                        SizedBox(
                          width: 48, // w-12
                          child: Text(
                            '${hour.toString().padLeft(2, '0')}:00',
                            style: const TextStyle(
                              fontSize: 14, // text-sm
                              fontWeight: FontWeight.w700, // font-bold
                              color: PortenColor.gray700,
                              fontFeatures: <FontFeature>[
                                FontFeature.tabularFigures(), // tabular-nums
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12), // ml-3
                        Expanded(
                          child: Container(
                            height: 1, // border-t
                            color: PortenColor.gray200,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // 日程卡片层
              for (final ScheduleItem item in dayItems)
                ScheduleCard(
                  key: ValueKey<int>(item.id),
                  item: item,
                  expanded: _expandedId == item.id,
                  hourPx: kHourPx,
                  relatedLabel: item.relatedType != null && item.relatedId != null
                      ? relatedLabelMap[
                          '${item.relatedType == ScheduleRelatedType.trip ? 'trip' : 'agreement'}-${item.relatedId}']
                      : null,
                  participants: item.participantIds
                      .map((int id) => comradeMap[id])
                      .whereType<ScheduleComrade>()
                      .toList(),
                  onToggleExpand: _handleToggleExpand,
                  onOpenEdit: _handleOpenEdit,
                  onEndTimeChange: _handleEndTimeChange,
                ),

              // 快捷创建内联卡：标题选填 + 详情，保存后落入时间线
              if (_quickDraftHour != null)
                Positioned(
                  left: kScheduleCardLeft,
                  right: kScheduleCardRight,
                  top: _quickDraftHour! * kHourPx,
                  child: _QuickDraftCard(
                    title: _draftTitle,
                    detail: _draftDetail,
                    onTitleChanged: (String v) =>
                        setState(() => _draftTitle = v),
                    onDetailChanged: (String v) =>
                        setState(() => _draftDetail = v),
                    onCancel: _handleQuickCancel,
                    onSave: _handleQuickSave,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 日期卡：h-14 rounded-xl，选中淡粉底白字 / 未选浅灰底；
/// 数字固定 top-2 锚点，节日名 bottom-1.5，有日程右上角小绿点。
class _DateCell extends StatelessWidget {
  const _DateCell({
    required this.date,
    required this.selected,
    required this.holiday,
    required this.hasSchedule,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final String? holiday;
  final bool hasSchedule;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150), // transition-colors
        height: 56, // h-14
        decoration: BoxDecoration(
          color: selected
              ? kSchedulePink // bg #F7C5D0
              : PortenColor.gray500.withValues(alpha: 0.10), // bg-gray-500/10
          borderRadius: BorderRadius.circular(12), // rounded-xl
        ),
        child: Stack(
          children: <Widget>[
            // 数字固定锚点：不随节日名有无上下浮动，保证逐卡对齐
            Positioned(
              top: 8, // top-2
              left: 0,
              right: 0,
              child: Text(
                '${date.day}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14, // text-sm
                  fontWeight: FontWeight.w500, // font-medium
                  height: 1, // leading-none
                  color: selected
                      ? PortenColor.white
                      : const Color(0xFF1F2937), // text-gray-800
                ),
              ),
            ),
            if (holiday != null)
              Positioned(
                bottom: 6, // bottom-1.5
                left: 0,
                right: 0,
                child: Text(
                  holiday!,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 10, // text-[10px]
                    height: 1, // leading-none
                    color: selected
                        ? PortenColor.white.withValues(alpha: 0.9) // white/90
                        : kRose400, // text-rose-400
                  ),
                ),
              ),
            // 有日程：右上角浅绿色小圆点（留出边距，不贴卡缘）
            if (hasSchedule)
              Positioned(
                top: 6, // top-1.5
                right: 6, // right-1.5
                child: Container(
                  width: 6, // w-1.5
                  height: 6, // h-1.5
                  decoration: const BoxDecoration(
                    color: kEmerald300, // bg-emerald-300
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 快捷创建内联卡：absolute z-30 rounded-xl border #F7C5D0 bg-white
/// shadow-lg p-2.5；标题选填 + 详情必填 + 取消/保存。
class _QuickDraftCard extends StatelessWidget {
  const _QuickDraftCard({
    required this.title,
    required this.detail,
    required this.onTitleChanged,
    required this.onDetailChanged,
    required this.onCancel,
    required this.onSave,
  });

  final String title;
  final String detail;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<String> onDetailChanged;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PortenColor.white,
        border: Border.all(color: kSchedulePink), // border-[#F7C5D0]
        borderRadius: BorderRadius.circular(12), // rounded-xl
        boxShadow: <BoxShadow>[
          // shadow-lg
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.10),
            blurRadius: 15,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(10), // p-2.5
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _DraftField(
            initialValue: title,
            placeholder: '标题（选填）',
            fontSize: 14, // text-sm
            onChanged: onTitleChanged,
          ),
          const SizedBox(height: 4), // mt-1
          _DraftField(
            initialValue: detail,
            placeholder: '写点什么…（必填）',
            fontSize: 12, // text-xs
            maxLines: 2,
            onChanged: onDetailChanged,
          ),
          const SizedBox(height: 6), // mt-1.5
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              _DraftButton(
                label: '取消',
                background: PortenColor.gray100, // bg-gray-100
                foreground: PortenColor.gray500, // text-gray-500
                onTap: onCancel,
              ),
              const SizedBox(width: 8), // gap-2
              _DraftButton(
                label: '保存',
                background: kSchedulePink, // bg-[#F7C5D0]
                foreground: PortenColor.white,
                onTap: onSave,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 快捷创建内联输入框（无边框，与 Web input/textarea 一致）。
class _DraftField extends StatefulWidget {
  const _DraftField({
    required this.initialValue,
    required this.placeholder,
    required this.fontSize,
    required this.onChanged,
    this.maxLines = 1,
  });

  final String initialValue;
  final String placeholder;
  final double fontSize;
  final ValueChanged<String> onChanged;
  final int maxLines;

  @override
  State<_DraftField> createState() => _DraftFieldState();
}

class _DraftFieldState extends State<_DraftField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      maxLines: widget.maxLines,
      cursorColor: const Color(0xFF1F2937), // gray-800
      style: TextStyle(
        fontSize: widget.fontSize,
        color: const Color(0xFF1F2937), // text-gray-800 / gray-700
      ),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.zero,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        hintText: widget.placeholder,
        hintStyle: TextStyle(
          fontSize: widget.fontSize,
          color: PortenColor.gray300, // placeholder:text-gray-300
        ),
      ),
    );
  }
}

/// 快捷创建小按钮：px-3 py-1 rounded-lg text-xs。
class _DraftButton extends StatelessWidget {
  const _DraftButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), // px-3 py-1
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8), // rounded-lg
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12, color: foreground), // text-xs
        ),
      ),
    );
  }
}
