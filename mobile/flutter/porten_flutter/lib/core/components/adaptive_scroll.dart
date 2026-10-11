/*
 * 自适应滚动容器：内容不超出可视区时锁定不滚动（对齐 Web 端单屏
 * overflow-hidden 行为），超出时才允许滚动兜底。
 *
 * 实现：LayoutBuilder 拿视口高度 + postFrameCallback 测量内容高度，
 * 动态切换 physics（NeverScrollable / Clamping）。内容高度随键盘、
 * 状态切换变化时自动重测。
 */

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// 内容不超高即锁定的滚动容器。
class AdaptiveScroll extends StatefulWidget {
  const AdaptiveScroll({
    super.key,
    required this.child,
    this.alignment = MainAxisAlignment.start,
  });

  final Widget child;

  /// 内容不满一屏时的纵向分布（认证页用 spaceBetween 铺满单屏）。
  final MainAxisAlignment alignment;

  @override
  State<AdaptiveScroll> createState() => _AdaptiveScrollState();
}

class _AdaptiveScrollState extends State<AdaptiveScroll> {
  double? _contentHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints cons) {
        final double viewport = cons.maxHeight;
        // 内容高度未知（首帧）或不超过视口 → 锁定不滚动
        final bool canScroll =
            _contentHeight != null && _contentHeight! > viewport + 0.5;
        return SingleChildScrollView(
          physics: canScroll
              ? const ClampingScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          child: MeasureSize(
            onChange: (double h) {
              if ((h - (_contentHeight ?? 0)).abs() > 0.5) {
                setState(() => _contentHeight = h);
              }
            },
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: viewport),
              child: Column(
                mainAxisAlignment: widget.alignment,
                children: <Widget>[widget.child],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 测量子内容高度的透明包装（postFrameCallback）。
class MeasureSize extends SingleChildRenderObjectWidget {
  const MeasureSize({
    super.key,
    required this.onChange,
    required super.child,
  });

  final ValueChanged<double> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _MeasureSizeRenderObject(onChange);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) {
    (renderObject as _MeasureSizeRenderObject).onChange = onChange;
  }
}

class _MeasureSizeRenderObject extends RenderProxyBox {
  _MeasureSizeRenderObject(this.onChange);

  ValueChanged<double> onChange;
  Size? _lastSize;

  @override
  void performLayout() {
    super.performLayout();
    if (size != _lastSize) {
      _lastSize = size;
      // 布局期不可触发 setState，延后到帧末
      final double h = size.height;
      SchedulerBinding.instance.addPostFrameCallback((_) => onChange(h));
    }
  }
}
