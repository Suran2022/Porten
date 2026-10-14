/*
 * 搜索式选择底部弹层（100% 复刻 Web 端
 * components/schedule/RelatedPickerSheet.tsx）。
 *
 * Web 端实现：
 *   - 与时间选择器同一弹层范式（BottomSheet 自适应高度）；
 *   - 顶部搜索框过滤候选（与表单文本输入同族的细小浅灰圆角样式）；
 *   - 未搜索时默认只展示前 defaultLimit 条；
 *   - 单选（关联旅程/约定）：点击即确认；多选（参与同胞）：勾选后
 *     底部「取消/确定」统一确认；
 *   - 列表行：头像（可选 w-9 h-9 rounded-full bg-gray-100）+ 文本
 *     text-sm gray-800 truncate；选中行 bg-[#FBE3EA]，勾选圆
 *     w-5 h-5：选中 bg-[#F7C5D0] 白 ✓ / 未选 border-gray-200；
 *   - 无匹配结果：居中 text-sm gray-300「没有匹配的结果」。
 */

import 'package:flutter/material.dart';

import '../../core/components/porten_bottom_sheet.dart';
import '../../core/design/porten_colors.dart';

/// 选择器候选：有头像的显示头像行，否则显示纯文本行。
class PickerOption {
  const PickerOption({
    required this.id,
    required this.label,
    this.avatarAsset,
  });

  final int id;
  final String label;

  /// 本地头像资产（Web 为远程 URL，App 离线策略改本地）。
  final String? avatarAsset;
}

/// 搜索式选择底部弹层（静态入口）。
abstract final class RelatedPickerSheet {
  const RelatedPickerSheet._();

  /// 打开选择面板；确认时返回选中的 id 列表（单选恰 1 个）。
  static Future<void> show(
    BuildContext context, {
    required String title,
    String? placeholder,
    required List<PickerOption> options,
    bool multiple = false,
    List<int> selectedIds = const <int>[],
    int? defaultLimit,
    required ValueChanged<List<int>> onConfirm,
  }) {
    return PortenBottomSheet.show(
      context,
      title: title,
      content: (BuildContext ctx, VoidCallback close) => _RelatedPickerBody(
        placeholder: placeholder ?? '搜索',
        options: options,
        multiple: multiple,
        selectedIds: selectedIds,
        defaultLimit: defaultLimit,
        onClose: close,
        onConfirm: (List<int> ids) {
          onConfirm(ids);
          close();
        },
      ),
    );
  }
}

class _RelatedPickerBody extends StatefulWidget {
  const _RelatedPickerBody({
    required this.placeholder,
    required this.options,
    required this.multiple,
    required this.selectedIds,
    required this.defaultLimit,
    required this.onClose,
    required this.onConfirm,
  });

  final String placeholder;
  final List<PickerOption> options;
  final bool multiple;
  final List<int> selectedIds;
  final int? defaultLimit;
  final VoidCallback onClose;
  final ValueChanged<List<int>> onConfirm;

  @override
  State<_RelatedPickerBody> createState() => _RelatedPickerBodyState();
}

class _RelatedPickerBodyState extends State<_RelatedPickerBody> {
  late List<int> _picked;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _picked = List<int>.of(widget.selectedIds);
  }

  /// 搜索过滤；未搜索时按 defaultLimit 截断（同 Web）。
  List<PickerOption> get _visibleOptions {
    final String q = _query.trim();
    final List<PickerOption> filtered = q.isEmpty
        ? widget.options
        : widget.options
            .where((PickerOption o) =>
                o.label.toLowerCase().contains(q.toLowerCase()))
            .toList();
    if (q.isEmpty && widget.defaultLimit != null) {
      return filtered.take(widget.defaultLimit!).toList();
    }
    return filtered;
  }

  void _togglePick(int id) {
    setState(() {
      if (_picked.contains(id)) {
        _picked.remove(id);
      } else {
        _picked.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<PickerOption> visibleOptions = _visibleOptions;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // 搜索框：px-5 pt-1 pb-2，细小浅灰圆角样式
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 4, bottom: 8),
          child: _SearchInput(
            placeholder: widget.placeholder,
            onChanged: (String v) => setState(() => _query = v),
          ),
        ),
        // 候选列表：px-3 pb-2，自适应高度（超长时内部滚动）
        Flexible(
          fit: FlexFit.loose,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
            children: <Widget>[
              if (visibleOptions.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40), // py-10
                  child: Text(
                    '没有匹配的结果',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14, // text-sm
                      color: PortenColor.gray300,
                    ),
                  ),
                )
              else
                for (final PickerOption o in visibleOptions)
                  _OptionRow(
                    option: o,
                    selected: _picked.contains(o.id),
                    onTap: () {
                      if (widget.multiple) {
                        _togglePick(o.id);
                      } else {
                        widget.onConfirm(<int>[o.id]);
                      }
                    },
                  ),
            ],
          ),
        ),
        // 多选底部按钮；单选（点击即确认）不显示
        if (widget.multiple)
          PortenSheetButtonRow(
            cancelLabel: '取消',
            confirmLabel: '确定',
            onCancel: widget.onClose,
            onConfirm: () => widget.onConfirm(_picked),
          ),
      ],
    );
  }
}

/// 列表行：头像（可选）+ 文本，选中时淡粉底。
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final PickerOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4), // 行间距由列表 gap 近似
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // px-3 py-2.5
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFFBE3EA) // bg-[#FBE3EA]
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12), // rounded-xl
        ),
        child: Row(
          children: <Widget>[
            if (option.avatarAsset != null) ...<Widget>[
              ClipOval(
                child: Image.asset(
                  option.avatarAsset!,
                  width: 36, // w-9
                  height: 36, // h-9
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 36,
                    height: 36,
                    color: PortenColor.gray100, // bg-gray-100
                  ),
                ),
              ),
              const SizedBox(width: 12), // gap-3
            ],
            Expanded(
              child: Text(
                option.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14, // text-sm
                  color: PortenColor.gray800,
                ),
              ),
            ),
            const SizedBox(width: 12), // gap-3
            // 勾选圆：w-5 h-5
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFF7C5D0) : Colors.transparent, // bg-[#F7C5D0]
                shape: BoxShape.circle,
                border: selected
                    ? null
                    : Border.all(color: PortenColor.gray200), // border-gray-200
              ),
              child: selected
                  ? const Text(
                      '✓',
                      style: TextStyle(
                        fontSize: 11, // text-[11px]
                        color: PortenColor.white,
                      ),
                    )
                  : const Text(
                      '✓',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.transparent, // text-transparent
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 搜索框（与表单文本输入同族的细小浅灰圆角样式）。
class _SearchInput extends StatelessWidget {
  const _SearchInput({required this.placeholder, required this.onChanged});

  final String placeholder;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      cursorColor: PortenColor.gray800,
      style: const TextStyle(fontSize: 14, color: PortenColor.gray800),
      decoration: InputDecoration(
        hintText: placeholder,
        hintStyle: const TextStyle(fontSize: 14, color: PortenColor.gray300),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8), // rounded-lg
          borderSide: const BorderSide(color: PortenColor.gray200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: PortenColor.gray200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: PortenColor.gray300), // focus:border-gray-300
        ),
      ),
    );
  }
}
