/*
 * 品牌渐变开关（100% 移植 Web 端 PortenAppBarPage.tsx 内联 switch，
 * 对应 CSS：w-[52px] h-[30px] rounded-full；on 态 porten-bg-gradient
 * 品牌面渐变 + 8s ease-in-out 流光（porten-flow）；off 态 bg-gray-300；
 * 滑块 top-[2px] left-[2px] w-[26px] h-[26px] bg-white rounded-full
 * shadow，on 时 translate-x-[22px]；transition 200ms）。
 */

import 'package:flutter/material.dart';

import '../design/porten_colors.dart';

class PortenBrandSwitch extends StatefulWidget {
  const PortenBrandSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  State<PortenBrandSwitch> createState() => _PortenBrandSwitchState();
}

class _PortenBrandSwitchState extends State<PortenBrandSwitch>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flowController = AnimationController(
    vsync: this,
    duration: PortenGradient.brandSurfaceFlowDuration, // 8s（对齐 porten-flow）
  );

  @override
  void initState() {
    super.initState();
    if (widget.value) _flowController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant PortenBrandSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value && !_flowController.isAnimating) {
      _flowController.repeat(reverse: true);
    } else if (!widget.value && _flowController.isAnimating) {
      _flowController.stop();
    }
  }

  @override
  void dispose() {
    _flowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onChanged(!widget.value),
      // 流光渐变需随 flowController 逐帧重建（AnimatedContainer 无法插值 Gradient）
      child: AnimatedBuilder(
        animation: _flowController,
        builder: (BuildContext context, Widget? child) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200), // transition duration-200
            width: 52, // w-[52px]
            height: 30, // h-[30px]
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999), // rounded-full
              color: widget.value ? null : PortenColor.gray300, // bg-gray-300
              gradient: widget.value
                  // 品牌面渐变（background-size 200% + position 流动近似：
                  // 蓝→粉→蓝 三段色重复铺满 2 倍宽，begin/end 平移）
                  ? LinearGradient(
                      begin: Alignment(-1 + 2 * _flowController.value, 0),
                      end: Alignment(1 + 2 * _flowController.value, 0),
                      colors: const <Color>[
                        PortenColor.brandBlue,
                        PortenColor.brandPink,
                        PortenColor.brandBlue,
                        PortenColor.brandPink,
                        PortenColor.brandBlue,
                      ],
                      stops: const <double>[0.0, 0.25, 0.5, 0.75, 1.0],
                    )
                  : null,
            ),
            child: child,
          );
        },
        child: Stack(
          children: <Widget>[
            // 滑块：top-2 left-2 w-26 h-26 bg-white rounded-full shadow，
            // on 时 translate-x-[22px]（transition-transform 200ms）
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              left: widget.value ? 24 : 2, // 2 + translate-x-22
              top: 2,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: PortenColor.white,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: const <BoxShadow>[
                    // shadow：0 1px 3px rgb(0 0 0/0.1), 0 1px 2px -1px rgb(0 0 0/0.1)
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 2,
                      spreadRadius: -1,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
