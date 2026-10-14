/*
 * 通用下拉刷新区域（100% 移植 Web 端 common/PullToRefresh.tsx +
 * hooks/usePullToRefresh.ts + index.css .ptr-loader）。
 *
 * Web 物理逐条对应：
 *   - 触发阈值 threshold=70、跟手上限 maxPull=150；
 *   - 跟手曲线 rubber：阈值内 1:1，超出部分 ×0.25 阻尼；
 *   - 启动门槛 PULL_START_DY=24（低于不认为是下拉）；
 *   - 提示条高 INDICATOR_HEIGHT=56（刷新中主内容整体下移 56）；
 *   - 提示内容垂直居中于"下拉露出的可视区域"，随露出高度渐显（offset/48）；
 *   - 箭头 ArrowDown：release 态 rotate 180°（300ms）；
 *     文案：下拉刷新 / 松开刷新 / 刷新中（text-sm text-gray-400）；
 *   - 松手未达阈值 → 320ms cubic-bezier(0.32,0.72,0,1) 回弹复位；
 *   - 达到阈值 → 主内容定在 56px，刷新动效最短 600ms，完成后
 *     Toast「刷新成功」（居中），提示条上滑隐藏、主内容回落（340ms 后静默）。
 *   - 三圆点 loader：20px 盒内三枚 9px 圆环按 1.5s 关键帧在四角轮转
 *     （每段 ease 缓动，与 CSS background-position 动画一致）。
 */

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/porten_colors.dart';
import 'porten_lucide_icons.dart';
import 'porten_toast.dart';

/// 下拉刷新阶段。
enum _PullPhase { idle, pulling, refreshing, done }

/// 通用下拉刷新区域。
class PortenPullToRefresh extends StatefulWidget {
  const PortenPullToRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.indicatorOffset = 0,
    this.contentPaddingTop = 0,
    this.refreshingText = '刷新中',
  });

  /// 刷新回调（异步；最短展示 600ms）。
  final Future<void> Function() onRefresh;

  /// 滚动内容（滚动容器由调用方提供，本组件经 NotificationListener 监听）。
  final Widget child;

  /// 提示条顶部基准偏移（吸附式分类栏让位高度）。
  final double indicatorOffset;

  /// 滚动容器顶部内边距（用于提示内容居中对称计算）。
  final double contentPaddingTop;

  final String refreshingText;

  @override
  State<PortenPullToRefresh> createState() => _PortenPullToRefreshState();
}

class _PortenPullToRefreshState extends State<PortenPullToRefresh>
    with TickerProviderStateMixin {
  static const double _indicatorHeight = 56;
  static const double _threshold = 70;
  static const double _maxPull = 150;
  static const double _pullStartDy = 24;
  static const int _minDurationMs = 600;
  static const int _resetMs = 340;

  final ValueNotifier<double> _offsetNotifier = ValueNotifier<double>(0);
  _PullPhase _phase = _PullPhase.idle;
  bool _releaseLabel = false; // false=下拉刷新 true=松开刷新
  double _raw = 0; // 本次手势累计原始下拉位移

  /// 注入子滚动容器的 ScrollBehavior（见 [_PtrScrollBehavior]）。
  /// 在 didChangeDependencies 中捕获外层 behavior 后保持单例，
  /// 避免每次 rebuild 触发 ScrollConfiguration 更新导致滚动位置重建。
  _PtrScrollBehavior? _scrollBehavior;

  late final AnimationController _snapCtrl =
      AnimationController.unbounded(vsync: this);
  late final AnimationController _loaderCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  /// 是否处于跟手下拉态（决定子滚动容器是否冻结 pixels）。
  bool get _isPulling => _phase == _PullPhase.pulling;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 捕获外层 ScrollBehavior：边界物理 / 越界指示器 / 滚动条原样委托，
    // 仅把 getScrollPhysics 包一层下拉冻结物理（见 [_PtrFreezePhysics]）。
    final ScrollBehavior ancestor = ScrollConfiguration.of(context);
    if (_scrollBehavior == null ||
        !identical(_scrollBehavior!.ancestor, ancestor)) {
      _scrollBehavior = _PtrScrollBehavior(ancestor, () => _isPulling);
    }
  }

  @override
  void initState() {
    super.initState();
    _snapCtrl.addListener(() => _offsetNotifier.value = _snapCtrl.value);
  }

  @override
  void dispose() {
    _offsetNotifier.dispose();
    _snapCtrl.dispose();
    _loaderCtrl.dispose();
    super.dispose();
  }

  /// 跟手位移曲线：阈值内 1:1，超出 ×0.25，封顶 maxPull。
  static double _rubber(double raw) {
    if (raw <= _threshold) return raw;
    final double extra = raw - _threshold;
    return math.min(_maxPull, _threshold + extra * 0.25);
  }

  void _applyRaw() {
    _offsetNotifier.value = _rubber(_raw);
    final bool release = _rubber(_raw) >= _threshold;
    if (release != _releaseLabel) setState(() => _releaseLabel = release);
  }

  void _snapTo(double target) {
    _snapCtrl.stop();
    _snapCtrl.animateWith(_SnapSimulation(_offsetNotifier.value, target));
  }

  Future<void> _startRefresh() async {
    _snapCtrl.stop();
    _phase = _PullPhase.refreshing;
    setState(() => _releaseLabel = false);
    _snapTo(_indicatorHeight);
    _loaderCtrl.repeat();

    final DateTime start = DateTime.now();
    try {
      await widget.onRefresh();
    } catch (_) {}
    final int elapsed =
        DateTime.now().difference(start).inMilliseconds;
    if (elapsed < _minDurationMs) {
      await Future<void>.delayed(
          Duration(milliseconds: _minDurationMs - elapsed));
    }
    if (!mounted || _phase != _PullPhase.refreshing) return;

    PortenToast.show('刷新成功', icon: ToastIcon.success); // 居中提示
    _phase = _PullPhase.done;
    _loaderCtrl.stop();
    _snapTo(0);
    Future<void>.delayed(const Duration(milliseconds: _resetMs), () {
      if (mounted && _phase == _PullPhase.done) {
        // setState 让提示条按 idle 态重建：offset 已归零 → opacity 0
        // 完全隐藏、文案回「下拉刷新」。若无本次重建，最后一次 done
        // 态绘制（opacity 1 + translateY(-28)）会残留半截在列表顶部。
        setState(() => _phase = _PullPhase.idle);
      }
    });
  }

  void _cancelGesture() {
    _phase = _PullPhase.idle;
    setState(() => _releaseLabel = false);
    _snapTo(0);
    _raw = 0;
  }

  bool _handleNotification(ScrollNotification n) {
    if (_phase == _PullPhase.refreshing || _phase == _PullPhase.done) {
      return false;
    }
    // 新手势起点：清零累计位移（对齐 Web touchstart 记录 startY，
    // 防止上一次未达门槛的残余位移污染本次手势）
    if (n is ScrollStartNotification) {
      if (n.dragDetails != null) _raw = 0;
      return false;
    }
    double? delta; // 本次滚动产生的顶部越界量（向下为正）
    if (n is OverscrollNotification) {
      // Flutter 语义：overscroll 正值 = 向 maxExtent（底部）越界。
      // 顶部下拉时 pixels 冻结于 minExtent、overscroll 为负 → 取负得下拉量；
      // 手动上滑恢复时 overscroll 为正 → delta 为负，累计位移随之减小，
      // 提示条跟手回落（对齐 Web dy<=0 → cancelGesture 的整体回弹）。
      delta = -n.overscroll;
    } else if (n is ScrollUpdateNotification &&
        n.metrics.pixels < 0 &&
        n.scrollDelta != null) {
      // BouncingScrollPhysics（iOS）：顶部继续下拉时 metrics 变负
      delta = -(n.scrollDelta!);
    }
    if (delta != null) {
      if (delta <= 0 && _phase != _PullPhase.pulling) {
        // 非下拉态的反向越界（如底部回弹发光）：忽略
        return false;
      }
      if (_phase != _PullPhase.pulling) {
        if (n.metrics.pixels > 0) return false; // 列表未在顶部：不计入下拉
        _raw += delta;
        if (_raw <= _pullStartDy) return false; // 启动门槛
        setState(() => _phase = _PullPhase.pulling);
      } else {
        _raw += delta; // 跟手中：回滑使 raw 减小，offset 随手指回落
      }
      if (_raw <= 0) {
        // 手指拖回起点以上：整体回弹复位（对齐 Web dy<=0 → cancelGesture）
        _cancelGesture();
        return false;
      }
      _snapCtrl.stop();
      _applyRaw();
      return false;
    }
    if (n is ScrollEndNotification && _phase == _PullPhase.pulling) {
      final bool refresh = _offsetNotifier.value >= _threshold;
      _raw = 0;
      if (refresh) {
        _startRefresh();
      } else {
        _cancelGesture();
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        children: <Widget>[
          // 主内容：下拉/刷新中整体下移（滚动越界通知在此监听）
          ValueListenableBuilder<double>(
            valueListenable: _offsetNotifier,
            child: NotificationListener<ScrollNotification>(
              onNotification: _handleNotification,
              // 下拉手势期间冻结子滚动容器 pixels：全部手指位移以带符号
              // OverscrollNotification 透传，回滑才能被本组件感知并跟手回落
              // （对齐 Web：下拉期间 scrollTop 恒 0，位移全部由 transform 表达）
              child: ScrollConfiguration(
                behavior: _scrollBehavior!,
                child: widget.child,
              ),
            ),
            builder: (BuildContext context, double offset, Widget? child) {
              return Transform.translate(
                offset: Offset(0, offset.clamp(0.0, _maxPull)),
                child: child,
              );
            },
          ),
          // 提示条：垂直居中于下拉露出的可视区域，随露出高度渐显
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: _indicatorHeight,
            child: IgnorePointer(
              child: ValueListenableBuilder<double>(
                valueListenable: _offsetNotifier,
                builder: (BuildContext context, double offset, _) {
                  final bool refreshing =
                      _phase == _PullPhase.refreshing ||
                          _phase == _PullPhase.done;
                  final double visibleH = math.max(
                      0, widget.contentPaddingTop + offset - widget.indicatorOffset);
                  final double centerY = widget.indicatorOffset +
                      visibleH / 2 -
                      _indicatorHeight / 2;
                  return Opacity(
                    // 对齐 Web applyOffset：opacity 只随露出高度变化
                    // （offset/48），刷新中 offset 恒 56 → 1；刷新完成
                    // （done）后 offset 回落 → 提示条随之渐隐。旧实现
                    // done 阶段恒为 1：回弹 320ms 内转圈与「刷新中」
                    // 仍全不透明滞留，且复位后残留半截提示条压在列表上。
                    opacity: (offset / 48).clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, centerY),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          if (refreshing)
                            const _PtrLoader()
                          else
                            AnimatedRotation(
                              turns: _releaseLabel ? 0.5 : 0,
                              duration: const Duration(milliseconds: 300),
                              child: const PortenLucideIcon(
                                'arrow-down',
                                size: 20,
                                color: PortenColor.gray400,
                                strokeWidth: 2,
                              ),
                            ),
                          const SizedBox(width: 8), // gap-2
                          Text(
                            refreshing
                                ? widget.refreshingText
                                : _releaseLabel
                                    ? '松开刷新'
                                    : '下拉刷新',
                            style: const TextStyle(
                              fontSize: 14,
                              height: 20 / 14,
                              color: PortenColor.gray400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 下拉手势期间的滚动物理：把子滚动容器的 pixels 冻结在原位，
/// 全部手指位移以带符号 OverscrollNotification 透传给 [_PortenPullToRefreshState]。
///
/// 为什么需要它（bug3 根因）：
/// Android 默认 ClampingScrollPhysics 只在"越过边界的方向"冻结 pixels——
/// 下拉时 pixels 冻结于 minExtent 并发出负 overscroll（下拉可被感知），
/// 但手动上滑恢复时 value 回到界内，pixels 立即解冻并真实滚动，
/// 不再发出任何通知 → 提示条 offset 冻结不肯回落，一半卡在顶部栏与
/// 消息列表之间；松手时 ScrollEndNotification 又可能误触发刷新。
/// 本物理在手势进行中对任意方向的位移都返回 `value - pixels`：
/// pixels 全程冻结（对齐 Web 下拉期间 scrollTop 恒 0），
/// 每帧手指位移以带符号越界量完整交还监听方，回滑随之跟手。
class _PtrFreezePhysics extends ScrollPhysics {
  const _PtrFreezePhysics({required this.isPulling, super.parent});

  /// 是否处于跟手下拉态（由 PTR 状态机驱动）。
  final bool Function() isPulling;

  @override
  _PtrFreezePhysics applyTo(ScrollPhysics? ancestor) =>
      _PtrFreezePhysics(isPulling: isPulling, parent: buildParent(ancestor));

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    // 仅拦纵轴：横滑容器（卡片轮播等）不受影响
    if (isPulling() && position.axis == Axis.vertical) {
      return value - position.pixels;
    }
    return super.applyBoundaryConditions(position, value);
  }
}

/// 经 ScrollConfiguration 注入 [_PtrFreezePhysics] 的 ScrollBehavior。
/// 其余行为（边界物理、越界发光指示器、滚动条）原样委托给外层
/// behavior，保证与页面默认滚动手感完全一致。
class _PtrScrollBehavior extends ScrollBehavior {
  const _PtrScrollBehavior(this.ancestor, this.isPulling);

  final ScrollBehavior ancestor;
  final bool Function() isPulling;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => _PtrFreezePhysics(
        parent: ancestor.getScrollPhysics(context),
        isPulling: isPulling,
      );

  @override
  Widget buildOverscrollIndicator(
          BuildContext context, Widget child, ScrollableDetails details) =>
      ancestor.buildOverscrollIndicator(context, child, details);

  @override
  Widget buildScrollbar(
          BuildContext context, Widget child, ScrollableDetails details) =>
      ancestor.buildScrollbar(context, child, details);

  @override
  bool shouldNotify(_PtrScrollBehavior oldDelegate) =>
      oldDelegate.ancestor != ancestor;
}

/// 松手回弹/复位模拟：transform 320ms cubic-bezier(0.32,0.72,0,1) 的
/// 时间参数化位移（值域线性、时间按曲线推进）。
class _SnapSimulation extends Simulation {
  _SnapSimulation(this._from, this._to)
      : _curve = const Cubic(0.32, 0.72, 0, 1);

  final double _from;
  final double _to;
  final Cubic _curve;

  static const double _durationSec = 0.32;

  @override
  double x(double time) {
    final double t = _curve.transform((time / _durationSec).clamp(0.0, 1.0));
    return _from + (_to - _from) * t;
  }

  @override
  double dx(double time) => 0;

  @override
  bool isDone(double time) => time >= _durationSec;
}

/// 三圆点 loader（对齐 index.css .ptr-loader）：20px 盒内三枚 9px 圆环
/// 按关键帧在四角轮转（1.5s 循环，每段 ease 缓动）。
class _PtrLoader extends StatefulWidget {
  const _PtrLoader();

  @override
  State<_PtrLoader> createState() => _PtrLoaderState();
}

class _PtrLoaderState extends State<_PtrLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  @override
  void initState() {
    super.initState();
    _ctrl.repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (BuildContext context, _) => CustomPaint(
        size: const Size.square(20),
        painter: _PtrLoaderPainter(_ctrl.value),
      ),
    );
  }
}

/// 关键帧位置（20px 盒内圆环中心，9px 环）：
/// CSS background-position 0/0、0/100%、100%/100% → 环中心在
/// (4.5,4.5)、(4.5,15.5)、(15.5,15.5)，动画在四角间轮转。
class _PtrLoaderPainter extends CustomPainter {
  _PtrLoaderPainter(this.t);

  final double t;

  // 四角中心
  static const Offset _tl = Offset(4.5, 4.5);
  static const Offset _tr = Offset(15.5, 4.5);
  static const Offset _br = Offset(15.5, 15.5);
  static const Offset _bl = Offset(4.5, 15.5);

  /// 关键帧段插值：segs = [(起点, 终点)]，段内 ease 缓动。
  static Offset _keyframed(double t, List<List<Offset>> segs) {
    final int n = segs.length; // 4 段
    final double scaled = t * n;
    final int i = (scaled.floor()).clamp(0, n - 1);
    final double f = Curves.ease.transform(scaled - i);
    return Offset.lerp(segs[i][0], segs[i][1], f)!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF9CA3AF); // gray-400

    // dot1：TL→TR→TR→TR→BR
    final Offset d1 = _keyframed(t, <List<Offset>>[
      <Offset>[_tl, _tr],
      <Offset>[_tr, _tr],
      <Offset>[_tr, _tr],
      <Offset>[_tr, _br],
    ]);
    // dot2：BL→BL→TL→TL→BL
    final Offset d2 = _keyframed(t, <List<Offset>>[
      <Offset>[_bl, _bl],
      <Offset>[_bl, _tl],
      <Offset>[_tl, _tl],
      <Offset>[_tl, _bl],
    ]);
    // dot3：BR→BR→BR→BL→BL
    final Offset d3 = _keyframed(t, <List<Offset>>[
      <Offset>[_br, _br],
      <Offset>[_br, _br],
      <Offset>[_br, _bl],
      <Offset>[_bl, _bl],
    ]);

    for (final Offset c in <Offset>[d1, d2, d3]) {
      canvas.drawCircle(c, 4.5, paint);
    }
  }

  @override
  bool shouldRepaint(_PtrLoaderPainter oldDelegate) =>
      oldDelegate.t != t;
}
