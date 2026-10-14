/*
 * 日程时间选择底部弹窗（100% 复刻 Web 端
 * components/schedule/DateTimePickerSheet.tsx）。
 *
 * Web 端实现：
 *   - BottomSheet「选择时间」，五栏（年/月/日/时/分）滚轮，精确到分钟；
 *   - 年份范围：今年 ~ 今年+2（label 带「年」），月 1-12「月」、
 *     日按大小月/闰年「日」、时 0-23「时」、分 0-59「分」；
 *   - 选项字号 text-sm（14，比旅程出发时间选择器的 text-base 小一档）；
 *   - 大月切小月时修正越界的日；
 *   - 底部取消/确定按钮（全站底部弹层统一样式）。
 */

import 'package:flutter/material.dart';

import '../../core/components/porten_bottom_sheet.dart';
import '../../core/components/porten_wheel_column.dart';

/// 日程时间选择底部弹窗（静态入口，同 PortenToast 范式）。
abstract final class DateTimePickerSheet {
  const DateTimePickerSheet._();

  /// 打开时间选择面板；确认后通过 [onConfirm] 返回所选时间。
  static Future<void> show(
    BuildContext context, {
    required DateTime? value,
    required ValueChanged<DateTime> onConfirm,
  }) {
    return PortenBottomSheet.show(
      context,
      title: '选择时间',
      content: (BuildContext ctx, VoidCallback close) => _DateTimePickerBody(
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

class _DateTimePickerBody extends StatefulWidget {
  const _DateTimePickerBody({
    required this.value,
    required this.onClose,
    required this.onConfirm,
  });

  final DateTime? value;
  final VoidCallback onClose;
  final ValueChanged<DateTime> onConfirm;

  @override
  State<_DateTimePickerBody> createState() => _DateTimePickerBodyState();
}

class _DateTimePickerBodyState extends State<_DateTimePickerBody> {
  late final DateTime _now;
  late int _yearIndex;
  late int _monthIndex;
  late int _dayIndex;
  late int _hourIndex;
  late int _minuteIndex;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    final DateTime v = widget.value ?? _now;
    _yearIndex = (v.year - _now.year).clamp(0, 2);
    _monthIndex = v.month - 1;
    _dayIndex = v.day - 1;
    _hourIndex = v.hour;
    _minuteIndex = v.minute;
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
      _hourIndex,
      _minuteIndex,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final List<String> years = List<String>.generate(
        3, (int i) => '${_now.year + i}年');
    final List<String> months =
        List<String>.generate(12, (int i) => '${i + 1}月');
    final List<String> hours =
        List<String>.generate(24, (int i) => '${_pad2(i)}时');
    final List<String> minutes =
        List<String>.generate(60, (int i) => '${_pad2(i)}分');

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
        // 五栏滚轮 + 中间固定选中区域 + 上下渐隐
        PortenWheelFrame(
          columns: <Widget>[
            PortenWheelColumn(
              values: years,
              index: _yearIndex,
              fontSize: 14, // text-sm
              onChange: (int i) => setState(() => _yearIndex = i),
            ),
            PortenWheelColumn(
              values: months,
              index: _monthIndex,
              fontSize: 14,
              onChange: (int i) => setState(() => _monthIndex = i),
            ),
            PortenWheelColumn(
              values: days,
              index: _dayIndex,
              fontSize: 14,
              onChange: (int i) => setState(() => _dayIndex = i),
            ),
            PortenWheelColumn(
              values: hours,
              index: _hourIndex,
              fontSize: 14,
              onChange: (int i) => setState(() => _hourIndex = i),
            ),
            PortenWheelColumn(
              values: minutes,
              index: _minuteIndex,
              fontSize: 14,
              onChange: (int i) => setState(() => _minuteIndex = i),
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

  static String _pad2(int v) => v.toString().padLeft(2, '0');
}
