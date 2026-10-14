/*
 * 滚轮选择列（100% 复刻 Web 端 schedule/DateTimePickerSheet.tsx 与
 * trip/TimePickerSheet.tsx 共用的 WheelColumn）。
 *
 * Web 端实现：
 *   - 固定高 WHEEL_HEIGHT = ITEM_HEIGHT*5 = 200（可见 5 行），
 *     上下各 WHEEL_PADDING = 80（2 行）内边距使选中项居中；
 *   - scroll-snap 逐项对齐；滚动停止 120ms 后取 round(scrollTop/40)
 *     同步选中值；选项数量变化且索引越界时校正滚动位置；
 *   - 选中项 text-gray-900 font-medium，其余 text-gray-400；
 *   - 上下渐隐遮罩由父层用 CSS maskImage 实现（透明 12% → 黑 38%
 *     → 黑 62% → 透明 88%），本组件只负责滚动与对齐。
 *
 * App 侧用 ListView（itemExtent 40 + 上下 padding 80）+ 滚动停止
 * 120ms 防抖对齐还原：CSS scroll-snap 的自动吸附由滚动停止后
 * animateTo 到最近刻度实现。
 */

import 'dart:async';

import 'package:flutter/material.dart';

/// 单行高度（Web ITEM_HEIGHT）。
const double kPortenWheelItemHeight = 40;

/// 滚轮可见高度（Web WHEEL_HEIGHT = 5 行）。
const double kPortenWheelHeight = kPortenWheelItemHeight * 5;

/// 上下留白（Web WHEEL_PADDING = 2 行，使选中项居中）。
const double kPortenWheelPadding = kPortenWheelItemHeight * 2;

/// 滚动停止同步选中值的防抖时长（Web 120ms）。
const Duration kPortenWheelDebounce = Duration(milliseconds: 120);

/// 单列滚轮。
class PortenWheelColumn extends StatefulWidget {
  const PortenWheelColumn({
    super.key,
    required this.values,
    required this.index,
    required this.onChange,
    this.fontSize = 14,
  });

  /// 候选项文本（如 "2026年" / "10月" / "14时"）。
  final List<String> values;

  /// 当前选中索引。
  final int index;

  /// 选中索引变化（滚动停止对齐后触发）。
  final ValueChanged<int> onChange;

  /// 选项字号（Web text-sm=14 / text-base=16）。
  final double fontSize;

  @override
  State<PortenWheelColumn> createState() => _PortenWheelColumnState();
}

class _PortenWheelColumnState extends State<PortenWheelColumn> {
  final ScrollController _controller = ScrollController();
  Timer? _debounce;
  int _lastLength = 0;

  @override
  void initState() {
    super.initState();
    _lastLength = widget.values.length;
    // 挂载时定位到当前选中项（面板每次打开重新挂载，同 Web）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.jumpTo(widget.index * kPortenWheelItemHeight);
    });
    _controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(PortenWheelColumn oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 选项数量变化（如大月切小月）且当前索引越界时校正滚动位置
    if (_lastLength != widget.values.length) {
      _lastLength = widget.values.length;
      if (widget.index >= widget.values.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _controller.jumpTo(
              (widget.values.length - 1) * kPortenWheelItemHeight);
        });
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    // 滚动停止 120ms 后对齐到最近刻度并同步选中值（同 Web 防抖）
    _debounce?.cancel();
    _debounce = Timer(kPortenWheelDebounce, _settle);
  }

  void _settle() {
    if (!mounted || !_controller.hasClients) return;
    final double offset = _controller.offset;
    final int target = (offset / kPortenWheelItemHeight)
        .round()
        .clamp(0, widget.values.length - 1);
    if (target != widget.index) {
      widget.onChange(target);
    }
    // CSS scroll-snap 的自动吸附：滚动停止后回到最近刻度
    final double targetOffset = target * kPortenWheelItemHeight;
    if ((offset - targetOffset).abs() > 0.5) {
      _controller.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ListView.builder(
        controller: _controller,
        itemExtent: kPortenWheelItemHeight,
        padding: const EdgeInsets.symmetric(vertical: kPortenWheelPadding),
        itemCount: widget.values.length,
        itemBuilder: (BuildContext context, int i) {
          final bool selected = i == widget.index;
          return Container(
            alignment: Alignment.center,
            child: Text(
              widget.values[i],
              maxLines: 1,
              style: TextStyle(
                fontSize: widget.fontSize,
                fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                color: selected
                    ? const Color(0xFF111827) // text-gray-900
                    : const Color(0xFF9CA3AF), // text-gray-400
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 滚轮区外框：中间浅灰圆角固定选中区域 + 上下渐隐遮罩。
///
/// [columns] 为各滚轮列（父级 Row/Expanded 结构由调用方组织）；
/// 选中区域横跨全部列（Web absolute left-5 right-5 h-10 bg-gray-100
/// rounded-xl，pointer-events-none 不挡滚动）。
class PortenWheelFrame extends StatelessWidget {
  const PortenWheelFrame({super.key, required this.columns});

  final List<Widget> columns;

  /// 渐隐遮罩渐变（Web FADE_MASK：透明 12% → 黑 38% → 黑 62% → 透明 88%）。
  static const List<double> _fadeStops = <double>[0.12, 0.38, 0.62, 0.88];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8), // px-2 pb-2
      child: SizedBox(
        height: kPortenWheelHeight,
        child: Stack(
          children: <Widget>[
            // 浅灰圆角固定选中区域（横跨全部列）
            Positioned(
              left: 20, // left-5（相对 px-2 容器）
              right: 20,
              top: (kPortenWheelHeight - 40) / 2, // top-1/2 居中
              height: 40, // h-10
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6), // bg-gray-100
                    borderRadius: BorderRadius.circular(12), // rounded-xl
                  ),
                ),
              ),
            ),
            // 渐隐遮罩 + 滚轮列
            ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (Rect rect) => LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: const <Color>[
                  Color(0x00000000), // transparent 12%
                  Color(0xFF000000), // black 38%
                  Color(0xFF000000), // black 62%
                  Color(0x00000000), // transparent 88%
                ],
                stops: _fadeStops,
              ).createShader(rect),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: columns,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
