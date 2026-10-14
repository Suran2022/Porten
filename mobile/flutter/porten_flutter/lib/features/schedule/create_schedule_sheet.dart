/*
 * 创建/编辑日程底部弹层（100% 复刻 Web 端
 * components/schedule/CreateScheduleSheet.tsx）。
 *
 * Web 端实现：
 *   - BottomSheet 高 75vh，标题「创建我的日程」/「编辑日程」（编辑回填）；
 *   - 表单项（px-5 py-4 space-y-5）：
 *     1) 日程时间（必填）：开始/结束两个 chip，打开五栏时间选择器；
 *        结束 chip 带 × 清除；
 *     2) 日程标题（选填，placeholder「给你的旅程来个标题！」）；
 *     3) 日程详情（5 行文本域，placeholder「不知道做点什么，但至少先写下来趴！」）；
 *     4) 日程分类：7 选 chip（旅行/约会/就诊/工作/日常/学习/其他），
 *        再点一次取消选择，切换分类清空已选关联项；
 *     5) 条件关联项：旅行→关联旅程 / 约会→关联约定（搜索式单选，
 *        未搜索默认展示前 3 条），已选带 × 清除；
 *     6) 添加地点（文本输入）；
 *     7) 添加日程参与的同胞：已选头像 + @昵称（点击移除），
 *        入口打开搜索式多选；
 *   - 底部取消/创建（编辑为保存）；保存校验：开始时间必填、
 *     结束时间需晚于开始时间；toast「日程创建成功」/「日程已保存」。
 */

import 'package:flutter/material.dart';

import '../../core/components/porten_bottom_sheet.dart';
import '../../core/components/porten_toast.dart';
import '../../core/data/schedule_mock.dart';
import '../../core/design/porten_colors.dart';
import 'date_time_picker_sheet.dart';
import 'related_picker_sheet.dart';

/// 参与者昵称粉色文本（同 Web PINK_TEXT）。
const Color kPinkText = Color(0xFFE88CA8);

/// 表单时间 chip / 文本输入框 / 选择入口 chip 的细浅灰圆角 border。
const BorderSide kFormBorder = BorderSide(color: PortenColor.gray200);
const BorderSide kFormBorderFocused = BorderSide(color: PortenColor.gray300);

class CreateScheduleSheet extends StatelessWidget {
  const CreateScheduleSheet._();

  /// 打开创建/编辑弹层。
  ///
  /// [editing] 非空为编辑模式（回填）；[defaultStart] 为创建模式默认
  /// 开始时间（时间线快捷定位传入），缺省当前时刻。
  static Future<void> show(
    BuildContext context, {
    ScheduleItem? editing,
    DateTime? defaultStart,
    required VoidCallback onSaved,
  }) {
    final double height = MediaQuery.sizeOf(context).height * 0.75; // h-[75vh]
    return PortenBottomSheet.show(
      context,
      title: editing != null ? '编辑日程' : '创建我的日程',
      height: height,
      content: (BuildContext ctx, VoidCallback close) => _CreateScheduleBody(
        editing: editing,
        defaultStart: defaultStart,
        onClose: close,
        onSaved: onSaved,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _CreateScheduleBody extends StatefulWidget {
  const _CreateScheduleBody({
    required this.editing,
    required this.defaultStart,
    required this.onClose,
    required this.onSaved,
  });

  final ScheduleItem? editing;
  final DateTime? defaultStart;
  final VoidCallback onClose;
  final VoidCallback onSaved;

  @override
  State<_CreateScheduleBody> createState() => _CreateScheduleBodyState();
}

class _CreateScheduleBodyState extends State<_CreateScheduleBody> {
  late DateTime? _start;
  late DateTime? _end;
  late String _title;
  late String _detail;
  ScheduleCategory? _category;
  int? _relatedId;
  late String _place;
  late List<int> _participantIds;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final ScheduleItem? editing = widget.editing;
    if (editing != null) {
      // 编辑模式回填
      _start = _parseItemDate(editing.date, editing.startTime);
      _end =
          editing.endTime != null ? _parseItemDate(editing.date, editing.endTime!) : null;
      _title = editing.title ?? '';
      _detail = editing.detail ?? '';
      _category = editing.category;
      _relatedId = editing.relatedId;
      _place = editing.place ?? '';
      _participantIds = List<int>.of(editing.participantIds);
    } else {
      // 创建模式：默认当日当前时间（精确到分钟）
      final DateTime now = DateTime.now();
      _start = widget.defaultStart ??
          DateTime(now.year, now.month, now.day, now.hour, now.minute);
      _end = null;
      _title = '';
      _detail = '';
      _category = null;
      _relatedId = null;
      _place = '';
      _participantIds = <int>[];
    }
  }

  /// 由日程条目的日期与 HH:mm 构造 Date（用于编辑回填）。
  static DateTime _parseItemDate(String date, String hhmm) {
    final List<String> d = date.split('-');
    final List<String> t = hhmm.split(':');
    return DateTime(
      int.parse(d[0]),
      int.parse(d[1]) - 1,
      int.parse(d[2]),
      int.parse(t[0]),
      int.parse(t[1]),
    );
  }

  /// 当前分类对应的关联候选（旅行→旅程 / 约会→约定）。
  List<ScheduleRelatedItem> get _relatedItems {
    switch (_category) {
      case ScheduleCategory.travel:
        return kMockTrips;
      case ScheduleCategory.date:
        return kMockAgreements;
      default:
        return const <ScheduleRelatedItem>[];
    }
  }

  ScheduleRelatedItem? get _selectedRelated {
    if (_relatedId == null) return null;
    for (final ScheduleRelatedItem r in _relatedItems) {
      if (r.id == _relatedId) return r;
    }
    return null;
  }

  List<ScheduleComrade> get _selectedParticipants => kMockComrades
      .where((ScheduleComrade c) => _participantIds.contains(c.id))
      .toList();

  void _handleCategoryChange(ScheduleCategory value) {
    setState(() {
      // 再点一次取消选择；切换分类时清空已选关联项
      _category = _category == value ? null : value;
      _relatedId = null;
    });
  }

  Future<void> _handleSave() async {
    final DateTime? start = _start;
    if (start == null) {
      PortenToast.show('请选择日程开始时间', icon: ToastIcon.error);
      return;
    }
    if (_end != null && !_end!.isAfter(start)) {
      PortenToast.show('结束时间需晚于开始时间', icon: ToastIcon.error);
      return;
    }
    final ScheduleRelatedType? relatedType =
        _category == ScheduleCategory.travel && _relatedId != null
            ? ScheduleRelatedType.trip
            : _category == ScheduleCategory.date && _relatedId != null
                ? ScheduleRelatedType.agreement
                : null;
    final ScheduleItem draft = ScheduleItem(
      id: widget.editing?.id ?? 0,
      date: _toDateKey(start),
      startTime: _formatHHmm(start),
      endTime: _end != null ? _formatHHmm(_end!) : null,
      title: _title.trim().isEmpty ? null : _title.trim(),
      detail: _detail.trim().isEmpty ? null : _detail.trim(),
      category: _category,
      relatedType: relatedType,
      relatedId: relatedType != null ? _relatedId : null,
      place: _place.trim().isEmpty ? null : _place.trim(),
      participantIds: _participantIds,
      color: ScheduleColor.pink, // create 时由 Store 随机覆盖
      source: widget.editing?.source ?? ScheduleSource.form,
    );
    setState(() => _saving = true);
    try {
      final ScheduleItem? editing = widget.editing;
      if (editing != null) {
        ScheduleStore.update(editing.id, draft);
        PortenToast.show('日程已保存', icon: ToastIcon.success);
      } else {
        ScheduleStore.create(draft);
        PortenToast.show('日程创建成功', icon: ToastIcon.success);
      }
      widget.onSaved();
      widget.onClose();
    } catch (err) {
      PortenToast.show('保存失败', icon: ToastIcon.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // 表单区：flex-1 滚动，px-5 py-4 space-y-5
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _buildTimeSection(),
                const SizedBox(height: 20), // space-y-5
                _buildLabeledField(
                  label: '日程标题',
                  child: _FormTextField(
                    value: _title,
                    placeholder: '给你的旅程来个标题！',
                    onChanged: (String v) => setState(() => _title = v),
                  ),
                ),
                const SizedBox(height: 20),
                _buildLabeledField(
                  label: '日程详情',
                  child: _FormTextField(
                    value: _detail,
                    placeholder: '不知道做点什么，但至少先写下来趴！',
                    maxLines: 5,
                    leadingRelaxed: true,
                    onChanged: (String v) => setState(() => _detail = v),
                  ),
                ),
                const SizedBox(height: 20),
                _buildCategorySection(),
                if (_category == ScheduleCategory.travel ||
                    _category == ScheduleCategory.date) ...<Widget>[
                  const SizedBox(height: 20),
                  _buildRelatedSection(),
                ],
                const SizedBox(height: 20),
                _buildLabeledField(
                  label: '添加地点',
                  child: _FormTextField(
                    value: _place,
                    placeholder: '添加地点',
                    onChanged: (String v) => setState(() => _place = v),
                  ),
                ),
                const SizedBox(height: 20),
                _buildParticipantsSection(),
              ],
            ),
          ),
        ),
        // 底部按钮：取消 / 创建（编辑模式为保存）
        IgnorePointer(
          ignoring: _saving,
          child: AnimatedOpacity(
            opacity: _saving ? 0.6 : 1,
            duration: const Duration(milliseconds: 150),
            child: PortenSheetButtonRow(
              cancelLabel: '取消',
              confirmLabel: widget.editing != null ? '保存' : '创建',
              onCancel: widget.onClose,
              onConfirm: _handleSave,
            ),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------- 表单分区

  Widget _buildTimeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Text(
              '日程时间',
              style: TextStyle(
                fontSize: 14, // text-sm
                fontWeight: FontWeight.w500, // font-medium
                color: PortenColor.gray700,
              ),
            ),
            const Text(
              ' *',
              style: TextStyle(fontSize: 14, color: Color(0xFFEF4444)), // text-red-500
            ),
          ],
        ),
        const SizedBox(height: 8), // mt-2
        Row(
          children: <Widget>[
            Expanded(
              child: _TimeChip(
                text: _start != null ? _formatDateTimeCn(_start!) : null,
                placeholder: '开始时间',
                onTap: () async {
                  final DateTime? picked = await _pickDateTime(_start);
                  if (picked != null) setState(() => _start = picked);
                },
              ),
            ),
            const SizedBox(width: 8), // gap-2
            Expanded(
              child: _TimeChip(
                text: _end != null ? _formatDateTimeCn(_end!) : null,
                placeholder: '结束时间（选填）',
                trailingClear: _end != null
                    ? () => setState(() => _end = null)
                    : null,
                onTap: () async {
                  final DateTime? picked = await _pickDateTime(_end);
                  if (picked != null) setState(() => _end = picked);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<DateTime?> _pickDateTime(DateTime? value) async {
    DateTime? result;
    await DateTimePickerSheet.show(
      context,
      value: value,
      onConfirm: (DateTime d) => result = d,
    );
    return result;
  }

  Widget _buildLabeledField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: PortenColor.gray700,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Text(
          '日程分类',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: PortenColor.gray700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, // gap-2
          runSpacing: 8,
          children: <Widget>[
            for (final (ScheduleCategory, String) c in kScheduleCategories)
              _CategoryChip(
                label: c.$2,
                active: _category == c.$1,
                onTap: () => _handleCategoryChange(c.$1),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildRelatedSection() {
    final bool isTravel = _category == ScheduleCategory.travel;
    final ScheduleRelatedItem? selected = _selectedRelated;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          isTravel ? '关联旅程' : '关联约定',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: PortenColor.gray700,
          ),
        ),
        const SizedBox(height: 8),
        _PickTrigger(
          text: selected?.label,
          placeholder: isTravel ? '选择关联旅程' : '选择关联约定',
          trailingClear: selected != null
              ? () => setState(() => _relatedId = null)
              : null,
          onTap: () async {
            final List<int>? ids = await _pickRelated(
              title: isTravel ? '选择关联旅程' : '选择关联约定',
              placeholder: isTravel ? '搜索旅程' : '搜索约定',
              options: _relatedItems
                  .map((ScheduleRelatedItem r) => PickerOption(id: r.id, label: r.label))
                  .toList(),
            );
            if (ids != null && ids.isNotEmpty) {
              setState(() => _relatedId = ids.first);
            }
          },
        ),
      ],
    );
  }

  Future<List<int>?> _pickRelated({
    required String title,
    required String placeholder,
    required List<PickerOption> options,
  }) async {
    List<int>? result;
    await RelatedPickerSheet.show(
      context,
      title: title,
      placeholder: placeholder,
      options: options,
      defaultLimit: 3,
      onConfirm: (List<int> ids) => result = ids,
    );
    return result;
  }

  Widget _buildParticipantsSection() {
    final List<ScheduleComrade> selected = _selectedParticipants;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Text(
          '添加日程参与的同胞',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: PortenColor.gray700,
          ),
        ),
        if (selected.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10), // mt-2.5
          Wrap(
            spacing: 12, // gap-x-3
            runSpacing: 8, // gap-y-2
            children: <Widget>[
              for (final ScheduleComrade p in selected)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() =>
                      _participantIds = _participantIds.where((int x) => x != p.id).toList()),
                  child: SizedBox(
                    width: 56, // w-14
                    child: Column(
                      children: <Widget>[
                        ClipOval(
                          child: Image.asset(
                            p.avatarAsset,
                            width: 40, // w-10
                            height: 40, // h-10
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 40,
                              height: 40,
                              color: PortenColor.gray100, // bg-gray-100
                            ),
                          ),
                        ),
                        const SizedBox(height: 4), // mt-1
                        Text(
                          '@${p.nickname}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12, // text-xs
                            color: kPinkText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        _PickTrigger(
          text: null,
          placeholder: selected.isNotEmpty ? '继续添加参与的同胞' : '选择参与的同胞',
          placeholderColor: selected.isNotEmpty ? PortenColor.gray400 : null,
          onTap: () async {
            final List<int>? ids = await _pickComrades();
            if (ids != null) setState(() => _participantIds = ids);
          },
        ),
      ],
    );
  }

  Future<List<int>?> _pickComrades() async {
    List<int>? result;
    await RelatedPickerSheet.show(
      context,
      title: '选择参与的同胞',
      placeholder: '搜索昵称',
      options: kMockComrades
          .map((ScheduleComrade c) =>
              PickerOption(id: c.id, label: c.nickname, avatarAsset: c.avatarAsset))
          .toList(),
      multiple: true,
      selectedIds: _participantIds,
      onConfirm: (List<int> ids) => result = ids,
    );
    return result;
  }

  // -------------------------------------------------------------- 工具

  static String _formatHHmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  /// Date 转中文日期时间展示：2026年10月4日 14:30（同 Web formatDateTimeCn）。
  static String _formatDateTimeCn(DateTime d) =>
      '${d.year}年${d.month}月${d.day}日 ${_formatHHmm(d)}';

  /// Date 转 YYYY-MM-DD（同 Web toDateKey）。
  static String _toDateKey(DateTime d) {
    final String m = d.month.toString().padLeft(2, '0');
    final String day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }
}

/// 表单时间 chip：细小浅灰色圆角 border，可带右侧 × 清除。
class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.text,
    required this.placeholder,
    required this.onTap,
    this.trailingClear,
  });

  final String? text;
  final String placeholder;
  final VoidCallback onTap;
  final VoidCallback? trailingClear;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // px-3 py-2
        decoration: BoxDecoration(
          border: Border.all(color: PortenColor.gray200),
          borderRadius: BorderRadius.circular(8), // rounded-lg
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                text ?? placeholder,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14, // text-sm
                  color: text != null ? PortenColor.gray800 : PortenColor.gray400,
                ),
              ),
            ),
            if (trailingClear != null)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: trailingClear,
                child: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Text(
                    '×',
                    style: TextStyle(fontSize: 14, color: PortenColor.gray300),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 文本输入框：与时间 chip 同族的细小浅灰圆角 border。
///
/// 控制器仅以初始值创建一次，后续文本由输入框内部维护（表单打开期间
/// 无外部重置需求），避免受控重建导致光标跳动。
class _FormTextField extends StatefulWidget {
  const _FormTextField({
    required this.value,
    required this.placeholder,
    required this.onChanged,
    this.maxLines = 1,
    this.leadingRelaxed = false,
  });

  final String value;
  final String placeholder;
  final ValueChanged<String> onChanged;
  final int maxLines;
  final bool leadingRelaxed;

  @override
  State<_FormTextField> createState() => _FormTextFieldState();
}

class _FormTextFieldState extends State<_FormTextField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value);

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
      cursorColor: PortenColor.gray800,
      style: TextStyle(
        fontSize: 14, // text-sm
        height: widget.leadingRelaxed ? 1.625 : null, // leading-relaxed
        color: PortenColor.gray800,
      ),
      decoration: InputDecoration(
        hintText: widget.placeholder,
        hintStyle: const TextStyle(fontSize: 14, color: PortenColor.gray300),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: kFormBorder,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: kFormBorder,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: kFormBorderFocused,
        ),
      ),
    );
  }
}

/// 可选项 chip：未选中浅灰描边 / 选中淡粉色不饱和底。
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150), // transition-colors
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), // px-3.5 py-1.5
        decoration: BoxDecoration(
          color: active ? const Color(0xFFF7C5D0) : Colors.transparent, // bg-[#F7C5D0]
          borderRadius: BorderRadius.circular(999), // rounded-full
          border: active
              ? null
              : Border.all(color: PortenColor.gray200), // border-gray-200
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14, // text-sm
            color: active ? PortenColor.white : PortenColor.gray600,
          ),
        ),
      ),
    );
  }
}

/// 选择入口 chip：与时间 chip 同族，占满一行，可带右侧 × 清除。
class _PickTrigger extends StatelessWidget {
  const _PickTrigger({
    required this.text,
    required this.placeholder,
    required this.onTap,
    this.placeholderColor,
    this.trailingClear,
  });

  final String? text;
  final String placeholder;
  final VoidCallback onTap;
  final Color? placeholderColor;
  final VoidCallback? trailingClear;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: PortenColor.gray200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                text ?? placeholder,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: text != null
                      ? PortenColor.gray800
                      : (placeholderColor ?? PortenColor.gray400),
                ),
              ),
            ),
            if (trailingClear != null)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: trailingClear,
                child: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Text(
                    '×',
                    style: TextStyle(fontSize: 14, color: PortenColor.gray300),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
