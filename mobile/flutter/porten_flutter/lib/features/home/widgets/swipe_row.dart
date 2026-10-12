/*
 * 会话卡片左滑操作行（100% 移植 Web 端 common/SwipeRow.tsx + SwipeRow.css 本场景参数）。
 *
 * Web 侧调用参数（MessageList.tsx）：
 *   actions=[隐藏(dismiss, primary, #e5484d) / 重要(#f97316) / 置顶(#6b7280)]
 *   actionColor=#e5484d、drawerColor=#3f3f46、rowColor=#ffffff、
 *   textColor=#f5f5f5、height=72、radius=0、actionWidth=80、direction=left、
 *   snapBounce=0.2、resistance=0.55、collapseMs=200、commitAt=0.6、
 *   fullSwipe、haptic；动作图标 size 20 strokeWidth 2，标签 11px/500。
 *
 * 交互物理（与 Web 端逐条对应）：
 *   方向锁定：HYST 内不认定滑动；锁定后有效位移 = 已展开距离 ± (|travel| - HYST)，
 *     即 grab = x0 + sign·HYST（只吃 HYST，不吃锁定前已走距离）；
 *   map()：负向（右滑）与不可提交越界走 rubber 阻尼 o·W·c/(W+c·|o|)；
 *   commitPoint = max(commitAt·W, D+COMMIT_MARGIN=260)；
 *   SPREAD_LEAD=10：越过全部展开点后 primary 红块跟手铺盖其余按钮
 *     （红块几何 = Web .swipe-row__block：rail 内 left = W-A、宽 W、
 *      translateX(-shift)，shift = max(0, exposed-A)；
 *      glyph 骑红块左缘（left:0·A 槽位 + landed 补偿位移），
 *      提交动画中 landed 0→1 使 glyph 平滑回到屏幕居中）；
 *   FLICK=180：快速甩动按速度方向落位（较 Web 110 收紧，防老设备误触发）；
 *   慢速按 project(v)=v·0.35 预测（较 Web 0.499 收紧）与 D/2 比较决定开合；
 *   HYST=32：横向意图确认距离（较 Web 24 收紧，降低灵敏度）；
 *   提交：landed→1 且 exposed 滑满整行（300ms）→ collapsing（高度 72→0、
 *   淡出，200ms ease-out，ClipRect 裁剪在高度动画之内）→ onHide 回调。
 *
 * 低端设备优化：
 *   - 拖动帧用 ValueNotifier 驱动 Transform 局部重建，不 setState 整行；
 *   - 按钮/内容子树作为常量 child 缓存，不随拖动帧重建；
 *   - 行级 RepaintBoundary 隔离重绘。
 */

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../../core/components/porten_lucide_icons.dart';
import '../../../core/design/porten_colors.dart';

/// 左滑操作行。
class SwipeRow extends StatefulWidget {
  const SwipeRow({
    super.key,
    required this.child,
    required this.label,
    required this.onPin,
    required this.onImportant,
    required this.onHide,
  });

  final Widget child;

  /// 行内标签（无障碍语义）。
  final String label;

  final VoidCallback onPin;
  final VoidCallback onImportant;
  final VoidCallback onHide;

  @override
  State<SwipeRow> createState() => _SwipeRowState();
}

class _SwipeRowState extends State<SwipeRow> with TickerProviderStateMixin {
  // ---- Web 端常量 ----
  static const double _actionWidth = 80; // actionWidth
  static const int _actionCount = 3;
  static const double _totalWidth = _actionWidth * _actionCount; // D = 240
  static const double _commitMargin = 20; // COMMIT_MARGIN
  static const double _commitRatio = 0.6; // commitAt
  static const double _resistance = 0.55; // resistance
  static const double _spreadLead = 10; // SPREAD_LEAD
  static const double _flick = 180; // FLICK（收紧，防误触发）
  static const double _projectFactor = 0.35; // 惯性预测系数（收紧）
  static const double _hyst = 32; // 横向意图确认距离（收紧）
  static const int _collapseMs = 200; // collapseMs
  static const double _height = 72; // height

  static const Color _actionColor = Color(0xFFE5484D); // 隐藏
  static const Color _importantColor = Color(0xFFF97316); // 重要
  static const Color _pinColor = Color(0xFF6B7280); // 置顶
  static const Color _textColor = Color(0xFFF5F5F5);

  /// 已展开距离（≥0），拖动/动画期间只通知 Transform 局部重建。
  final ValueNotifier<double> _exposedNotifier = ValueNotifier<double>(0);

  /// 铺盖进度（Web 端 spread motion value：spring duration 0.3 bounce 0，
  /// 越过 D+SPREAD_LEAD 平滑涨到 1、回落时平滑缩回 0，红块吸附式铺盖/退回）。
  late final AnimationController _spreadAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  final ValueNotifier<double> _spreadNotifier = ValueNotifier<double>(0);

  /// 提交时 glyph 居中重定位进度（Web 端 landed motion value，0/1）。
  final ValueNotifier<double> _landedNotifier = ValueNotifier<double>(0);

  /// rail 重绘监听源（三个 notifier 合并）。
  late final Listenable _railListenable = Listenable.merge(<Listenable>[
    _exposedNotifier,
    _spreadNotifier,
    _landedNotifier,
  ]);

  double _width = 0; // 行宽（LayoutBuilder 缓存）
  bool _collapsing = false; // 收合动画进行中
  double _dragAccum = 0; // 本次手势指针横向位移（右为正）
  double _lockExposed = 0; // 锁定瞬间的已展开距离
  bool _locked = false;

  double get _exposed => _exposedNotifier.value;
  double get _widthOr360 => _width <= 0 ? 360 : _width;

  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  /// 回弹/落位控制器（无界，驱动 SpringSimulation）：
  /// 对齐 Web settle() 的 spring——普通落位 duration 0.3 / bounce 0
  /// （临界阻尼），快速甩动 duration 0.4 / bounce 0.2（欠阻尼过冲回摆），
  /// 并携带松手初速度，杜绝"秒恢复"的生硬感。
  late final AnimationController _settleCtrl =
      AnimationController.unbounded(vsync: this);
  static final SpringDescription _springCritical =
      SpringDescription.withDampingRatio(
          mass: 1, stiffness: (2 * 3.14159 / 0.3) * (2 * 3.14159 / 0.3), ratio: 1);
  static final SpringDescription _springSnap =
      SpringDescription.withDampingRatio(mass: 1, stiffness: _springCritical.stiffness, ratio: 0.8);
  late final AnimationController _collapseAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _collapseMs),
  );
  late final AnimationController _landedAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  double _animFrom = 0;
  double _animTo = 0;
  Curve _curve = Curves.easeOutCubic;
  bool _hideOnComplete = false;

  // ---- 常量按钮子树（不随拖动帧重建）----
  late final Widget _importantButton = _actionButton(
    icon: const PortenLucideIcon('heart',
        size: 20, color: _textColor, strokeWidth: 2),
    label: '重要',
    background: _importantColor,
    onTap: () {
      widget.onImportant();
      _settleTo(0);
    },
  );
  late final Widget _pinButton = _actionButton(
    icon: const PortenLucideIcon('pin',
        size: 20, color: _textColor, strokeWidth: 2),
    label: '置顶',
    background: _pinColor,
    onTap: () {
      widget.onPin();
      _settleTo(0);
    },
  );
  late final Widget _hideButtonContent = _actionContent(
    icon: const PortenLucideIcon('eye-off',
        size: 20, color: _textColor, strokeWidth: 2),
    label: '隐藏',
  );

  @override
  void initState() {
    super.initState();
    _settleCtrl.addListener(() {
      // 允许轻微负向过冲（视觉上卡片轻微右弹回摆，与 Web bounce 一致）
      _exposedNotifier.value = _settleCtrl.value.clamp(-40.0, double.infinity);
    });
    _spreadAnim.addListener(() {
      _spreadNotifier.value =
          Curves.easeOutCubic.transform(_spreadAnim.value);
    });
    _anim.addListener(() {
      final double t = _curve.transform(_anim.value);
      _exposedNotifier.value =
          (_animFrom + (_animTo - _animFrom) * t).clamp(0.0, double.infinity);
      if (_hideOnComplete) {
        // 提交滑满过程中铺盖红块（对齐 Web setSpread(true)）
        if (_spreadAnim.value < 1) _spreadAnim.forward(from: _spreadAnim.value);
      }
    });
    _anim.addStatusListener((AnimationStatus status) {
      if (status != AnimationStatus.completed || !_hideOnComplete) return;
      _hideOnComplete = false;
      setState(() => _collapsing = true);
      _collapseAnim.forward(from: 0).whenComplete(widget.onHide);
    });
  }

  @override
  void dispose() {
    _exposedNotifier.dispose();
    _settleCtrl.dispose();
    _spreadNotifier.dispose();
    _spreadAnim.dispose();
    _landedNotifier.dispose();
    _anim.dispose();
    _collapseAnim.dispose();
    _landedAnim.dispose();
    super.dispose();
  }

  // ---- 物理映射（对齐 Web 端 map/rubber/project）----

  double _rubber(double o) =>
      (o * _widthOr360 * _resistance) / (_widthOr360 + _resistance * o.abs());

  double get _commitPoint =>
      (_commitRatio * _widthOr360).clamp(_totalWidth + _commitMargin, 1e9);

  /// 原始拖拽距离（左滑为正）→ 已展开距离。
  double _map(double raw) {
    if (raw < 0) return _rubber(raw);
    if (raw <= _totalWidth) return raw;
    final double c = _commitPoint;
    final double knee = _totalWidth + (c - _totalWidth) / _resistance;
    if (raw <= knee) return _totalWidth + _resistance * (raw - _totalWidth);
    return c + _rubber(raw - knee);
  }

  /// project(v)：速度惯性预测距离。
  static double _project(double v) => v * _projectFactor;

  // ---- 动画 ----

  void _animateTo(double target,
      {required int durationMs, required Curve curve}) {
    _animFrom = _exposed;
    _animTo = target;
    _curve = curve;
    _anim.duration = Duration(milliseconds: durationMs);
    _anim.forward(from: 0);
  }

  /// 落位（对齐 Web settle）：spring 带初速度——普通落位临界阻尼（0.3s、
  /// bounce 0），快速甩动欠阻尼（0.4s、bounce 0.2 过冲回摆），松手处
  /// 速度连续，杜绝"秒恢复"的生硬感。
  void _settleTo(double target, {bool flick = false, double velocity = 0}) {
    _settleCtrl.stop();
    _settleCtrl.animateWith(
      SpringSimulation(
        flick ? _springSnap : _springCritical,
        _exposed,
        target,
        velocity,
      ),
    );
  }

  /// 提交隐藏（对齐 Web 端 commit()）：landed→1、滑满整行 → 收合 → onHide。
  void _commitHide() {
    if (_collapsing) return;
    _hideOnComplete = true;
    _landedAnim.forward(from: 0); // glyph 居中重定位
    _animateTo(_widthOr360, durationMs: 300, curve: Curves.easeOutCubic);
  }

  // ---- 手势 ----

  void _onDragStart(DragStartDetails details) {
    if (_collapsing) return;
    _anim.stop();
    _settleCtrl.stop();
    _dragAccum = 0;
    _locked = false;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_collapsing) return;
    _dragAccum += details.delta.dx; // 右为正
    if (!_locked) {
      if (_dragAccum.abs() < _hyst) return; // HYST：灵敏度确认
      // 对齐 Web grab = x0 + sign·HYST：只消耗 HYST，锁定瞬间位移连续
      _lockExposed = _exposed;
      _locked = true;
    }
    final double travel = -_dragAccum; // 左滑为正
    // 锁定后有效位移 = 锁定时已展开距离 ± (|travel| - HYST)：
    // 左滑（travel>0）展开量递增；右滑（travel<0）展开量平滑递减
    // （r20 修复：此前右滑误把 -(_lockExposed+dist) 传入 _map，
    //  经 rubber 映射后 clamp 归零导致卡片瞬间复原无动画）
    final double travelAbs = travel.abs();
    final double ex = _map(
      travel >= 0
          ? _lockExposed + (travelAbs - _hyst)
          : _lockExposed - (travelAbs - _hyst),
    ).clamp(0.0, double.infinity);
    _exposedNotifier.value = ex; // 局部重建，不 setState 整行
    // 越过全部展开点即让 primary 跟手铺盖（Web setSpread，带 spring 动画）
    final bool shouldSpread = ex >= _totalWidth + _spreadLead;
    _setSpread(shouldSpread);
  }

  /// 铺盖开关（对齐 Web setSpread：spring duration 0.3 bounce 0）。
  void _setSpread(bool on) {
    if (_hideOnComplete && !on) return; // 提交滑满过程中红块不回退
    if (on) {
      if (_spreadAnim.value >= 1 && !_spreadAnim.isAnimating) return;
      _spreadAnim.forward(from: _spreadAnim.value);
    } else {
      if (_spreadAnim.value <= 0 && !_spreadAnim.isAnimating) return;
      _spreadAnim.reverse(from: _spreadAnim.value);
    }
  }

  void _onDragEnd(DragEndDetails details) {
    if (_collapsing) return;
    final double v = -details.velocity.pixelsPerSecond.dx; // 左滑为正
    if (!_locked) {
      if (_exposed > 0) _settleTo(0); // 点击未拖动：Web up(!moved) 收合已开行
      return;
    }
    final double ex = _exposed;
    if (ex >= _commitPoint) {
      _commitHide();
      return;
    }
    double target;
    if (v.abs() >= _flick) {
      target = v > 0 ? _totalWidth : 0;
    } else {
      target = ex + _project(v) > _totalWidth / 2 ? _totalWidth : 0;
    }
    _setSpread(false); // setSpread(false)：红块平滑退回右缘 80px
    _settleTo(target, flick: v.abs() >= _flick, velocity: v);
  }

  // ---- 构建 ----

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.label,
      child: RepaintBoundary(
        // ClipRect 必须在高度动画之内：收合时裁剪子内容，避免溢出
        child: ClipRect(
          child: AnimatedBuilder(
            animation: _collapseAnim,
            builder: (BuildContext context, Widget? child) {
              final double t = Curves.easeOut.transform(_collapseAnim.value);
              return Opacity(
                opacity: _collapsing ? 1 - t : 1,
                child: SizedBox(
                  height: _collapsing ? _height * (1 - t) : _height,
                  // Stack 硬裁剪：收合高度缩小时内容按 72 顶部对齐绘制并被裁剪
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: <Widget>[
                      Positioned(
                        left: 0,
                        top: 0,
                        right: 0,
                        height: _height,
                        child: child!,
                      ),
                    ],
                  ),
                ),
              );
            },
            child: SizedBox(
              height: _height,
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  _width = constraints.maxWidth;
                  return Stack(
                    children: <Widget>[
                      // 抽屉轨道（rail）：translate max(0, D - e)
                      AnimatedBuilder(
                        animation: _railListenable,
                        builder: (BuildContext context, _) {
                          return Transform.translate(
                            offset: Offset(
                                (_totalWidth - _exposed)
                                    .clamp(0.0, double.infinity),
                                0),
                            child: _buildRail(),
                          );
                        },
                      ),
                      // 内容行（surface）：translate -e；白底随内容位移
                      ValueListenableBuilder<double>(
                        valueListenable: _exposedNotifier,
                        // 白底容器作为常量 child 缓存，拖动帧零重建
                        child: Container(
                          color: PortenColor.white, // rowColor
                          child: widget.child,
                        ),
                        builder: (BuildContext context, double e, Widget? c) {
                          return Transform.translate(
                            offset: Offset(-e, 0),
                            child: c,
                          );
                        },
                      ),
                      // 手势层（透明，仅捕获拖拽，点击穿透到卡片）
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onHorizontalDragStart: _onDragStart,
                          onHorizontalDragUpdate: _onDragUpdate,
                          onHorizontalDragEnd: _onDragEnd,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 抽屉轨道（对齐 Web 端 SwipeRow.tsx 结构）：
  /// - 次要按钮（重要/置顶）：rail 内 right:(i+1)·A 锚定，随 rail 平移移入；
  /// - primary 红块（隐藏）：rail 内 left = W-A、宽 W（.swipe-row__block），
  ///   translateX(-shift)，shift = max(0, e-A)，铺盖时向左淹没其余按钮；
  /// - glyph 槽位在红块左缘 left:0·A（.swipe-row__action--commit），
  ///   叠加 landed·(shift-(W-A)/2) 补偿位移：拖动期 glyph 骑红块左缘，
  ///   提交动画中 landed→1 使 glyph 平滑回到屏幕水平居中。
  Widget _buildRail() {
    final double e = _exposed;
    final double shift =
        _spreadNotifier.value * (e - _actionWidth).clamp(0.0, double.infinity);
    final double landedComp =
        _landedNotifier.value * (shift - (_widthOr360 - _actionWidth) / 2);
    return Stack(
      children: <Widget>[
        Positioned(
          right: _actionWidth * 2, // 置顶（slice(1)[1]：right:2A）
          top: 0,
          bottom: 0,
          width: _actionWidth,
          child: _pinButton,
        ),
        Positioned(
          right: _actionWidth, // 重要（slice(1)[0]：right:A）
          top: 0,
          bottom: 0,
          width: _actionWidth,
          child: _importantButton,
        ),
        // primary 红块：left = W-A，宽 W，translateX(-shift)
        Positioned(
          left: _widthOr360 - _actionWidth,
          top: 0,
          bottom: 0,
          width: _widthOr360,
          child: Transform.translate(
            offset: Offset(-shift, 0),
            child: Container(
              color: _actionColor,
              // glyph 槽位：红块左缘 80px（commit 按钮 left:0）
              child: Stack(
                children: <Widget>[
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: _actionWidth,
                    child: Transform.translate(
                      offset: Offset(landedComp, 0),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _commitHide,
                        child: _hideButtonContent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionButton({
    required Widget icon,
    required String label,
    required Color background,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        color: background,
        alignment: Alignment.center,
        child: _actionContent(icon: icon, label: label),
      ),
    );
  }

  Widget _actionContent({required Widget icon, required String label}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        icon,
        const SizedBox(height: 4), // glyph gap 4px
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.01,
            color: _textColor,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}
