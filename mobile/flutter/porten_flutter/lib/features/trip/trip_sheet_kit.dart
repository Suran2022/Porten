/*
 * 旅程弹层共用小组件（100% 复刻 Web 端 components/trip 下两个选择面板
 * 与创建旅程页的共用样式）。
 *
 * 包含：
 *   1. SheetSearchField —— 搜索框（CityPickerSheet / AirlinePickerSheet
 *      同款 input：bg-gray-100 rounded-xl px-4 py-2.5 text-sm text-gray-900
 *      text-center placeholder:text-gray-400 outline-none）；
 *   2. TripPressRow —— 按压行（Web active:bg-gray-50 rounded-lg 按压反馈，
 *      以 StatefulWidget 跟踪按压态，对应 CSS :active）；
 *   3. SheetStepIn —— 步骤/完成区入场动画（Web .sheet-step-in：
 *      opacity 0→1 + translateY 8→0，250ms cubic-bezier(0.25,0.1,0.25,1)
 *      both；内容挂载即播放，步骤切换天然重播）。
 */

import 'package:flutter/material.dart';

import '../../core/components/porten_bottom_sheet.dart'
    show kPortenSheetCurve;
import '../../core/design/porten_colors.dart';

/// 弹层搜索输入框：浅灰圆角、文本居中、聚焦无任何样式变化。
class SheetSearchField extends StatelessWidget {
  const SheetSearchField({
    super.key,
    required this.controller,
    required this.placeholder,
    required this.onChanged,
  });

  /// 搜索文本控制器（由调用方持有并负责销毁）。
  final TextEditingController controller;

  /// 提示文本（搜索出发地 / 搜索到达地 / 搜索航司）。
  final String placeholder;

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    // outline-none：三种边框态全部无边框（聚焦无样式变化）
    const OutlineInputBorder noBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)), // rounded-xl
      borderSide: BorderSide.none,
    );
    return TextField(
      controller: controller,
      onChanged: onChanged,
      cursorColor: PortenColor.gray900,
      textAlign: TextAlign.center, // text-center（占位符同样居中）
      style: const TextStyle(
        fontSize: 14, // text-sm
        color: PortenColor.gray900,
      ),
      decoration: InputDecoration(
        hintText: placeholder,
        hintStyle: const TextStyle(
          fontSize: 14, // text-sm
          color: PortenColor.gray400, // placeholder:text-gray-400
        ),
        filled: true,
        fillColor: PortenColor.gray100, // bg-gray-100
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16, // px-4
          vertical: 10, // py-2.5
        ),
        isDense: true,
        border: noBorder,
        enabledBorder: noBorder,
        focusedBorder: noBorder,
      ),
    );
  }
}

/// 按压行：按压期间浅灰底 + 圆角（Web active:bg-gray-50 rounded-lg）。
///
/// [builder] 接收当前按压态，由调用方决定底色/圆角如何叠加，
/// 与 Web 中 :active 伪类叠加在元素自身样式上的语义一致。
class TripPressRow extends StatefulWidget {
  const TripPressRow({super.key, required this.builder, this.onTap});

  final Widget Function(bool pressed) builder;

  final VoidCallback? onTap;

  @override
  State<TripPressRow> createState() => _TripPressRowState();
}

class _TripPressRowState extends State<TripPressRow> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: widget.builder(_pressed),
    );
  }
}

/// 步骤内容入场动画（Web .sheet-step-in）。
///
/// 挂载时从 opacity 0 + translateY(8px) 播到 opacity 1 + translateY(0)，
/// 250ms cubic-bezier(0.25,0.1,0.25,1)，`both` 填充模式（起始帧即
/// 隐藏态，无闪烁）。用于城市选择器两步切换、创建旅程页完成按钮区。
class SheetStepIn extends StatefulWidget {
  const SheetStepIn({super.key, required this.child});

  final Widget child;

  @override
  State<SheetStepIn> createState() => _SheetStepInState();
}

class _SheetStepInState extends State<SheetStepIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  )..forward();

  late final Animation<double> _anim = CurvedAnimation(
    parent: _controller,
    curve: kPortenSheetCurve, // cubic-bezier(0.25,0.1,0.25,1)
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (BuildContext context, _) => Opacity(
        opacity: _anim.value,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - _anim.value)),
          child: widget.child,
        ),
      ),
    );
  }
}
