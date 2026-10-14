// bug3：下拉刷新提示条必须完全跟随手势——
//   - 手动上滑恢复时提示条跟手回落，不能一半卡在顶部栏与消息列表之间
//     （根因：Android ClampingScrollPhysics 只冻结"越界方向"的 pixels，
//      回滑时 pixels 解冻真实滚动、不再发通知 → offset 冻结；
//      修复：_PtrFreezePhysics 手势期间冻结 pixels，位移以带符号
//      OverscrollNotification 透传，回滑被感知并跟手）
//   - 刷新成功后提示条隐藏、主内容复位，不能残留在顶部栏与消息列表之间
// bug4（刷新交互动画不隐藏/重叠列表，r23 回归）：
//   - 刷新完成（done）后提示条必须随 offset 回落渐隐（对齐 Web applyOffset：
//     opacity = offset/48，done 时过渡到 0）；旧实现 done 阶段 opacity 恒 1，
//     回弹 320ms 内转圈与「刷新中」全不透明滞留 →「没有立刻隐藏」
//   - done→idle 必须 setState 重建；旧实现静默改 phase，最后一次 done 态
//     绘制（opacity 1 + translateY(-28)）残留半截提示条压在列表顶部 →
//     「手动滑动查看列表时重叠在消息列表上」
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:porten_flutter/core/components/porten_pull_to_refresh.dart';

Widget _buildSubject({
  required Future<void> Function() onRefresh,
  ScrollController? controller,
}) {
  return ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: PortenPullToRefresh(
          onRefresh: onRefresh,
          child: ListView.builder(
            controller: controller,
            itemCount: 40,
            itemBuilder: (BuildContext context, int index) =>
                SizedBox(height: 60, child: Text('item $index')),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('bug3-1 上滑恢复：提示条跟手回落，滚动位置全程冻结在顶部',
      (WidgetTester tester) async {
    final ScrollController controller = ScrollController();
    await tester.pumpWidget(
        _buildSubject(onRefresh: () async {}, controller: controller));

    final Finder listFinder = find.byType(ListView);
    final double listTop = tester.getTopLeft(listFinder).dy;
    expect(controller.position.pixels, 0);

    final TestGesture gesture =
        await tester.startGesture(tester.getCenter(listFinder));
    await gesture.moveBy(const Offset(0, 60));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();

    // 下拉累计 80 → offset = 70 + 10×0.25 = 72.5，主内容整体下移
    final double pulledOffset = tester.getTopLeft(listFinder).dy - listTop;
    expect(pulledOffset, greaterThan(50));
    // 下拉全程滚动位置冻结在顶部（对齐 Web 下拉期间 scrollTop 恒 0）
    expect(controller.position.pixels, 0);

    // 手动上滑恢复 40 → offset 必须跟手回落（修复前冻结在 72.5 不动）
    await gesture.moveBy(const Offset(0, -40));
    await tester.pump();
    final double restoredOffset = tester.getTopLeft(listFinder).dy - listTop;
    expect(restoredOffset, lessThan(pulledOffset * 0.9));
    expect(restoredOffset, greaterThan(10)); // 是跟手回落而非直接归零
    expect(controller.position.pixels, 0); // 仍未解冻滚动

    // 松手（未达阈值）→ 320ms 回弹复位，提示条完全隐藏
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.getTopLeft(listFinder).dy, closeTo(listTop, 0.51));
    expect(controller.position.pixels, 0);
  });

  testWidgets('bug3-2 刷新成功后提示条隐藏、主内容复位',
      (WidgetTester tester) async {
    final ScrollController controller = ScrollController();
    await tester.pumpWidget(
        _buildSubject(onRefresh: () async {}, controller: controller));

    final Finder listFinder = find.byType(ListView);
    final double listTop = tester.getTopLeft(listFinder).dy;

    final TestGesture gesture =
        await tester.startGesture(tester.getCenter(listFinder));
    await gesture.moveBy(const Offset(0, 100));
    await tester.pump();
    // 下拉 100 → offset = 77.5 ≥ 阈值 70 → 松手进入刷新
    expect(tester.getTopLeft(listFinder).dy - listTop, greaterThan(70));
    await gesture.up();
    await tester.pump();

    // 刷新中：主内容定在 56px，提示条常驻显示
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.getTopLeft(listFinder).dy, closeTo(listTop + 56, 0.51));
    expect(find.text('刷新中'), findsOneWidget);

    // 刷新完成（最短 600ms + 复位 320ms + 重置 340ms）后回到静默态。
    // 小步进泵帧：让回弹动画逐帧推进（对齐真机 60fps 行为）
    for (int i = 0; i < 24; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.getTopLeft(listFinder).dy, closeTo(listTop, 0.51));
    expect(find.text('下拉刷新'), findsOneWidget);
    final Opacity indicator = tester.widget<Opacity>(find
        .ancestor(of: find.text('下拉刷新'), matching: find.byType(Opacity))
        .first);
    expect(indicator.opacity, 0.0); // 提示条完全隐藏，不残留
    expect(controller.position.pixels, 0);
  });

  /// 当前提示条文案（ idle=下拉刷新 / pulling 松开刷新 / refreshing+done=刷新中 ）。
  Finder indicatorText() {
    for (final String t in const <String>['刷新中', '松开刷新', '下拉刷新']) {
      if (find.text(t).evaluate().isNotEmpty) return find.text(t).first;
    }
    return find.text('下拉刷新');
  }

  /// 提示条根 Opacity（包裹文案的最近 Opacity 祖先）。
  double indicatorOpacity(WidgetTester tester) => tester
      .widget<Opacity>(find
          .ancestor(of: indicatorText(), matching: find.byType(Opacity))
          .first)
      .opacity;

  testWidgets('bug4-1 刷新完成后提示条随主内容回落渐隐，不得滞留全不透明',
      (WidgetTester tester) async {
    await tester.pumpWidget(_buildSubject(onRefresh: () async {}));
    await tester.pump();

    final Finder listFinder = find.byType(ListView);
    final double listTop = tester.getTopLeft(listFinder).dy;
    double contentOffset() => tester.getTopLeft(listFinder).dy - listTop;

    final TestGesture gesture =
        await tester.startGesture(tester.getCenter(listFinder));
    await gesture.moveBy(const Offset(0, 100));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    // 刷新中：主内容定在 56px，提示条常驻不透明
    await tester.pump(const Duration(milliseconds: 400));
    expect(contentOffset(), closeTo(56, 0.51));
    expect(indicatorOpacity(tester), greaterThan(0.99));

    // 等刷新完成（onRefresh 立即返回 + 最短展示 600ms）：
    // done 阶段开始 → offset 从 56 回落（小步进泵帧驱动 snap 动画）
    bool doneStarted = false;
    for (int i = 0; i < 30 && !doneStarted; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (contentOffset() < 55) doneStarted = true;
    }
    expect(doneStarted, true, reason: '刷新完成后主内容应回落进入 done 阶段');

    // done 阶段中：提示条必须已开始渐隐（对齐 Web opacity 过渡到 0）。
    // 旧实现此处恒为 1.0（转圈与「刷新中」全不透明滞留）。
    await tester.pump(const Duration(milliseconds: 100));
    expect(indicatorOpacity(tester), lessThan(0.9),
        reason: '刷新完成后提示条应立即渐隐，不得滞留全不透明');

    // 完全静默：提示条彻底隐藏、文案回 idle
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(contentOffset(), closeTo(0, 0.51));
    expect(indicatorOpacity(tester), 0.0, reason: '静默后提示条必须完全隐藏');
    expect(find.text('下拉刷新'), findsOneWidget);
  });

  testWidgets('bug4-2 刷新完成静默后提示条无残留，手动滑列表不重叠',
      (WidgetTester tester) async {
    final ScrollController controller = ScrollController();
    await tester.pumpWidget(
        _buildSubject(onRefresh: () async {}, controller: controller));
    await tester.pump();

    final Finder listFinder = find.byType(ListView);
    final double listTop = tester.getTopLeft(listFinder).dy;

    final TestGesture gesture =
        await tester.startGesture(tester.getCenter(listFinder));
    await gesture.moveBy(const Offset(0, 100));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    // 刷新完成 + 回弹 + 重置（最短 600 + snap 320 + reset 340）。
    // 20ms 细步进：对齐真机 60fps 节奏——snap 在 320ms 先于 340ms 的
    // reset 定时器完成，最后一次绘制停留在 done 态（旧实现即在此残留）
    for (int i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(tester.getTopLeft(listFinder).dy, closeTo(listTop, 0.51));

    // 残留检查：提示条必须完全透明（旧实现残留 done 态绘制：
    // opacity 1 + translateY(-28)，底部半截转圈/文案压在列表顶部）
    expect(indicatorOpacity(tester), 0.0,
        reason: '刷新完成后提示条不得残留（半截压在消息列表上）');
    final Transform indicatorTransform = tester.widget<Transform>(find
        .ancestor(of: indicatorText(), matching: find.byType(Transform))
        .first);
    // Transform.translate 的位移烘焙在矩阵中：storage[13] = translateY
    expect(indicatorTransform.transform.storage[13], lessThanOrEqualTo(-28),
        reason: '静默态提示条应整体移出可视区');

    // 手动上滑查看列表：滚动正常，提示条不得重新出现
    final TestGesture scroll =
        await tester.startGesture(tester.getCenter(listFinder));
    for (int i = 0; i < 10; i++) {
      await scroll.moveBy(const Offset(0, -20));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await scroll.up();
    await tester.pump();
    expect(controller.position.pixels, greaterThan(100), reason: '列表应正常滚动');
    expect(indicatorOpacity(tester), 0.0,
        reason: '手动滑动查看列表时提示条不得重叠在消息列表上');

    // 滑回顶部（末段位移落在顶部越界区 → 进入下拉态但未达阈值）→ 松手回弹
    final TestGesture back =
        await tester.startGesture(tester.getCenter(listFinder));
    for (int i = 0; i < 12; i++) {
      await back.moveBy(const Offset(0, 20));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await back.up();
    await tester.pump();
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(tester.getTopLeft(listFinder).dy, closeTo(listTop, 0.51),
        reason: '滑回顶部松手后主内容应回弹复位');
    expect(indicatorOpacity(tester), 0.0, reason: '回弹后提示条完全隐藏');
  });
}
