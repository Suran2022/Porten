/*
 * 性别选择底部弹窗（100% 移植 Web 端 components/profile/GenderPickerSheet.tsx）。
 *
 * 结构：fixed inset-0 z-[60] flex flex-col justify-end；
 *   遮罩 absolute inset-0 bg-black/40 transition-opacity duration-300；
 *    sheet relative bg-white rounded-t-2xl max-h-[70vh] transition-transform
 *      duration-300 ease-[cubic-bezier(0.25,0.1,0.25,1)]
 *      （isEntering ? translate-y-0 : translate-y-full）；
 *   拖拽把手 w-9 h-1 rounded-full bg-gray-300（pt-3 pb-2）；
 *   标题 px-5 pb-3「选择性别」text-base w500 gray-900；
 *   选项区 overflow-y-auto px-3 pb-6 space-y-1：
 *     px-4 py-3.5 rounded-xl，选中态 bg-gradient-to-r
 *     from-[#5BCEFA]/10 to-[#F5A9B8]/10 + 文字 gray-900 w500 +
 *     Check w-5 h-5 #F5A9B8 strokeWidth 2；未选 gray-700 + hover/active 灰底。
 *
 * 动画时序（对齐 Web renderVisible + isEntering 双 rAF）：
 *   进场：可见即渲染初始态（遮罩 opacity 0、sheet 平移到底部之外），
 *     连续两帧后切进入态触发 300ms 过渡；
 *   离场：立即切退出态（过渡 300ms），300ms 后卸载。
 */

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/components/porten_lucide_icons.dart';
import 'gender_options.dart';
import 'profile_page.dart' show kGray900, kGray700, kGray300, kGray50;

/// 品牌粉（对齐 PortenColor.brandPink，此处就近取色避免跨层 import）。
const Color _kBrandPink = Color(0xFFF5A9B8);

/// 性别选择底部弹窗。
class GenderPickerSheet extends StatefulWidget {
  const GenderPickerSheet({
    super.key,
    required this.visible,
    required this.selected,
    required this.onSelect,
    required this.onClose,
  });

  final bool visible;

  /// 当前选中的性别 value（null = 未设置）。
  final String? selected;

  /// 选中某项（对齐 Web handleSelect：onSelect 后立即 onClose）。
  final ValueChanged<String> onSelect;

  /// 关闭弹窗（点击遮罩或选中后）。
  final VoidCallback onClose;

  @override
  State<GenderPickerSheet> createState() => _GenderPickerSheetState();
}

class _GenderPickerSheetState extends State<GenderPickerSheet> {
  /// 是否处于渲染树中（对齐 Web renderVisible：离场动画期间保持渲染）。
  bool _renderVisible = false;

  /// 是否处于「进入态」（对齐 Web isEntering：驱动遮罩透明度与 sheet 平移）。
  bool _isEntering = false;

  /// 离场 300ms 卸载定时器（对齐 Web setTimeout(300)）。
  Timer? _exitTimer;

  @override
  void initState() {
    super.initState();
    if (widget.visible) {
      _renderVisible = true;
      _scheduleEnter();
    }
  }

  /// 进场：先渲染初始态一帧，再连续一帧后切进入态
  /// （对齐 Web 双 requestAnimationFrame）。
  void _scheduleEnter() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _isEntering = true);
      });
    });
  }

  @override
  void didUpdateWidget(GenderPickerSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) {
      // 重新打开：取消离场定时，回到初始态再播进场动画。
      _exitTimer?.cancel();
      _exitTimer = null;
      setState(() {
        _renderVisible = true;
        _isEntering = false;
      });
      _scheduleEnter();
    } else if (!widget.visible && oldWidget.visible && _renderVisible) {
      // 关闭：播离场动画，300ms 后卸载。
      setState(() => _isEntering = false);
      _exitTimer?.cancel();
      _exitTimer = Timer(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        setState(() => _renderVisible = false);
      });
    }
  }

  @override
  void dispose() {
    _exitTimer?.cancel();
    super.dispose();
  }

  void _handleSelect(String value) {
    widget.onSelect(value);
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    // 对齐 Web `if (!renderVisible) return null;`
    if (!_renderVisible) return const SizedBox.shrink();

    final double maxSheetHeight = MediaQuery.sizeOf(context).height * 0.7; // max-h-[70vh]

    return SizedBox.expand(
      child: Stack(
        children: <Widget>[
          // 遮罩：bg-black/40，opacity 0→1（300ms）
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onClose,
              child: AnimatedOpacity(
                opacity: _isEntering ? 1 : 0,
                duration: const Duration(milliseconds: 300),
                child: const ColoredBox(color: Color(0x66000000)), // black/40
              ),
            ),
          ),
          // sheet：底部对齐，translate-y-full → translate-y-0（300ms）
          Positioned.fill(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                AnimatedSlide(
                  offset: _isEntering ? Offset.zero : const Offset(0, 1),
                  duration: const Duration(milliseconds: 300),
                  curve: const Cubic(0.25, 0.1, 0.25, 1),
                  child: Container(
                    width: double.infinity,
                    constraints: BoxConstraints(maxHeight: maxSheetHeight),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)), // rounded-t-2xl
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        // 拖拽把手：pt-3 pb-2 + w-9 h-1 rounded-full bg-gray-300
                        const Padding(
                          padding: EdgeInsets.only(top: 12, bottom: 8),
                          child: Center(
                            child: SizedBox(
                              width: 36,
                              height: 4,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: kGray300,
                                  borderRadius: BorderRadius.all(Radius.circular(999)),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // 标题：px-5 pb-3「选择性别」
                        const Padding(
                          padding: EdgeInsets.only(left: 20, right: 20, bottom: 12),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '选择性别',
                              style: TextStyle(
                                fontSize: 16, // text-base
                                fontWeight: FontWeight.w500,
                                color: kGray900,
                              ),
                            ),
                          ),
                        ),
                        // 选项区：px-3 pb-6 space-y-1
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.only(left: 12, right: 12, bottom: 24),
                            child: Column(
                              children: <Widget>[
                                for (int i = 0; i < kGenderOptions.length; i++) ...[
                                  if (i > 0) const SizedBox(height: 4), // space-y-1
                                  _GenderOptionRow(
                                    label: kGenderOptions[i].label,
                                    selected: kGenderOptions[i].value == widget.selected,
                                    onTap: () => _handleSelect(kGenderOptions[i].value),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 性别选项行（px-4 py-3.5 rounded-xl；选中态品牌渐变 + Check，未选按压灰底）。
class _GenderOptionRow extends StatefulWidget {
  const _GenderOptionRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_GenderOptionRow> createState() => _GenderOptionRowState();
}

class _GenderOptionRowState extends State<_GenderOptionRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), // px-4 py-3.5
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12), // rounded-xl
          // 选中态：bg-gradient-to-r from-[#5BCEFA]/10 to-[#F5A9B8]/10；
          // 未选按压：active:bg-gray-100（hover 态在触屏端无意义，仅实现按压）。
          gradient: widget.selected
              ? const LinearGradient(
                  colors: <Color>[Color(0x1A5BCEFA), Color(0x1AF5A9B8)],
                )
              : null,
          color: !widget.selected && _pressed ? kGray50 : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 16, // text-base
                fontWeight: widget.selected ? FontWeight.w500 : FontWeight.w400,
                color: widget.selected ? kGray900 : kGray700,
              ),
            ),
            if (widget.selected)
              const PortenLucideIcon('check',
                  size: 20, color: _kBrandPink, strokeWidth: 2),
          ],
        ),
      ),
    );
  }
}
