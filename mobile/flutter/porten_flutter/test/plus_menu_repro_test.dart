import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:porten_flutter/features/home/home_view.dart';
import 'package:porten_flutter/features/home/widgets/plus_menu.dart';

/// bug1 验收：加号菜单与 Web 端行为一致。
void main() {
  testWidgets('bug1：菜单宽度自适应内容（w-max），不再满屏拉伸',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: HomeView()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 点击加号按钮（右上角 40×40 热区）
    await tester.tapAt(const Offset(370, 30));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('添加同胞/营地'), findsOneWidget,
        reason: '点击加号后菜单应展开');

    // 菜单宽度：Web 端 w-max 自适应内容（约 150~220）
    final RenderBox itemBox = tester.renderObject<RenderBox>(
        find.ancestor(
          of: find.text('扫一扫'),
          matching: find.byType(Row),
        ));
    debugPrint('菜单项行宽 = ${itemBox.size.width}');
    expect(itemBox.size.width, lessThan(240),
        reason: '菜单宽度应自适应内容（w-max），不得被拉宽');
    expect(itemBox.size.width, greaterThan(120),
        reason: '菜单宽度应容纳最宽菜单项内容');
  });

  testWidgets('bug1：遮罩覆盖全屏，点击菜单外区域收起；切视图同步收起',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: HomeView()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 打开菜单
    await tester.tapAt(const Offset(370, 30));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('扫一扫'), findsOneWidget);

    // 遮罩应覆盖底部导航区域（Web：z-[60] > BottomNav z-50）
    final RenderBox overlayBox = tester.renderObject<RenderBox>(
        find
            .descendant(
              of: find.byType(PortenPlusMenu),
              matching: find.byType(ColoredBox),
            )
            .first);
    debugPrint('遮罩尺寸 = ${overlayBox.size}');
    expect(overlayBox.size.height, greaterThan(700),
        reason: '遮罩应覆盖含底部导航的内容区全屏');

    // 点击菜单外（屏幕左侧中部）→ 遮罩命中 → 收起
    await tester.tapAt(const Offset(40, 400));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('扫一扫'), findsNothing, reason: '点击遮罩后菜单应收起');

    // 再次打开，然后切换底部导航到「资源」视图 → 菜单同步收起
    await tester.tapAt(const Offset(370, 30));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('扫一扫'), findsOneWidget);

    await tester.tapAt(const Offset(133, 760)); // 底部导航「资源」Tab
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('扫一扫'), findsNothing,
        reason: '切换视图后菜单不得残留（对齐 Web 顶栏卸载）');
  });

  testWidgets('bug2 回归：点击加号后展开动画完整播放，菜单真正可见',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: HomeView()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 读取菜单弹层的实际缩放/透明度（find.text 不感知透明度，
    // 动画若卡在 scale 0 存量断言全部误过——必须直接读动画值）。
    double readScale() => tester
        .widget<Transform>(find.descendant(
          of: find.byType(PortenPlusMenu),
          matching: find.byWidgetPredicate((Widget w) =>
              w is Transform && w.alignment == Alignment.topRight),
        ))
        .transform
        .storage[0];
    double readOpacity() => tester
        .widget<Opacity>(find.descendant(
          of: find.byType(PortenPlusMenu),
          matching: find.byType(Opacity),
        ))
        .opacity;

    await tester.tapAt(const Offset(370, 30));
    await tester.pump(); // 帧N：菜单挂载（双 rAF 第一层），收起态 scale 0
    expect(readScale(), 0.0, reason: '挂载首帧应为收起态（scale 0）');

    // 设备上引擎每 vsync 连续产帧，双 rAF 第二层与动画逐帧推进；
    // 测试环境 pump() 仅在 hasScheduledFrame 时画帧，双击后无脏标记，
    // 需 scheduleForcedFrame 强制画帧来模拟设备连续帧节奏。
    tester.binding.scheduleForcedFrame();
    await tester.pump(); // 帧N+1：cb2 执行（_entering=true + forward）
    for (int i = 0; i < 18; i++) {
      // 250ms 动画 @ ~16ms/帧，泵 18 帧至稳定
      tester.binding.scheduleForcedFrame();
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(readScale(), greaterThan(0.99),
        reason: '动画结束后菜单应完全展开（scale→1），不得卡在起点');
    expect(readOpacity(), greaterThan(0.99),
        reason: '动画结束后菜单应完全不透明（opacity→1）');

    // 菜单文本应落在屏幕内（真实可见，而非布局存在但透明/缩放为 0）
    final Offset scanCenter = tester.getCenter(find.text('扫一扫'));
    expect(scanCenter.dx, greaterThan(0));
    expect(scanCenter.dx, lessThan(400));
    expect(scanCenter.dy, greaterThan(0));
    expect(scanCenter.dy, lessThan(800));
  });
}
