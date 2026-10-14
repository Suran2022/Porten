/*
 * 出发时间选择底部弹窗（100% 复刻 Web 端 components/trip/TimePickerSheet.tsx）。
 *
 * Web 端实现：
 *   - BottomSheet「选择时间」，三栏（年/月/日）滚轮；
 *   - 年份范围：今年 ~ 今年+2；选项字号 text-base（16，比日程时间
 *     选择器的 text-sm 大一档，两者不复用同一字号）；
 *   - 中间浅灰圆角固定选中区域横跨三栏，选项列表上下渐隐；
 *   - 大月切小月时修正越界的日；底部取消/确定按钮（样式被创建旅程页复用）。
 */

import 'package:flutter/material.dart';

import '../../core/components/porten_bottom_sheet.dart';
import '../../core/components/porten_wheel_column.dart';

/// 出发时间选择面板（静态入口）。
abstract final class TimePickerSheet {
  const TimePickerSheet._();

  /// 打开时间选择面板；确认后通过 [onConfirm] 返回所选日期。
  static Future<void> show(
    BuildContext context, {
    required DateTime? value,
    required ValueChanged<DateTime> onConfirm,
  }) {
    return PortenBottomSheet.show(
      context,
      title: '选择时间',
      content: (BuildContext ctx, VoidCallback close) => _TimePickerBody(
        value: value,
        onClose: close,
        onConfirm: (DateTime date) {
          onConfirm(date);
          close();
        },
      ),
    );
  }
}

class _TimePickerBody extends StatefulWidget {
  const _TimePickerBody({
    required this.value,
    required this.onClose,
    required this.onConfirm,
  });

  final DateTime? value;
  final VoidCallback onClose;
  final ValueChanged<DateTime> onConfirm;

  @override
  State<_TimePickerBody> createState() => _TimePickerBodyState();
}

class _TimePickerBodyState extends State<_TimePickerBody> {
  late final DateTime _now;
  late int _yearIndex;
  late int _monthIndex;
  late int _dayIndex;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    final DateTime v = widget.value ?? _now;
    _yearIndex = (v.year - _now.year).clamp(0, 2);
    _monthIndex = v.month - 1;
    _dayIndex = v.day - 1;
  }

  /// 选中年月对应的实际天数（自动处理大小月与闰年）。
  int get _daysInMonth {
    final int yearNumber = _now.year + _yearIndex;
    return DateTime(yearNumber, _monthIndex + 2, 0).day;
  }

  void _handleConfirm() {
    widget.onConfirm(DateTime(
      _now.year + _yearIndex,
      _monthIndex + 1,
      _dayIndex + 1,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final List<String> years =
        List<String>.generate(3, (int i) => '${_now.year + i}年');
    final List<String> months =
        List<String>.generate(12, (int i) => '${i + 1}月');

    final int daysInMonth = _daysInMonth;
    // 大月切小月时修正越界的日
    if (_dayIndex > daysInMonth - 1) {
      _dayIndex = daysInMonth - 1;
    }
    final List<String> days =
        List<String>.generate(daysInMonth, (int i) => '${i + 1}日');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // 三栏滚轮 + 中间固定选中区域 + 上下渐隐
        PortenWheelFrame(
          columns: <Widget>[
            PortenWheelColumn(
              values: years,
              index: _yearIndex,
              fontSize: 16, // text-base（比日程选择器大一档）
              onChange: (int i) => setState(() => _yearIndex = i),
            ),
            PortenWheelColumn(
              values: months,
              index: _monthIndex,
              fontSize: 16,
              onChange: (int i) => setState(() => _monthIndex = i),
            ),
            PortenWheelColumn(
              values: days,
              index: _dayIndex,
              fontSize: 16,
              onChange: (int i) => setState(() => _dayIndex = i),
            ),
          ],
        ),
        // 底部按钮：取消 / 确定
        PortenSheetButtonRow(
          cancelLabel: '取消',
          confirmLabel: '确定',
          onCancel: widget.onClose,
          onConfirm: _handleConfirm,
        ),
      ],
    );
  }
}
