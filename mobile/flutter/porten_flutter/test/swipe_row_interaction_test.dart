// SwipeRow 交互回归测试：验证左滑交互与 Web 端 SwipeRow.tsx 行为一致。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porten_flutter/features/home/widgets/swipe_row.dart';

Widget _host(WidgetBuilderProbe probe) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 360,
            child: SwipeRow(
              label: 'row',
              onPin: () => probe.pinCalls++,
              onImportant: () => probe.importantCalls++,
              onHide: () => probe.hideCalls++,
              child: const SizedBox(height: 72),
            ),
          ),
        ),
      ),
    );

class WidgetBuilderProbe {
  int pinCalls = 0;
  int importantCalls = 0;
  int hideCalls = 0;
}

void main() {
  testWidgets('左滑 240px 松手后保持展开，三个按钮全部可见', (tester) async {
    final probe = WidgetBuilderProbe();
    await tester.pumpWidget(_host(probe));

    // 从行中心向左拖 240px（HYST=32 后锁定）
    final gesture = await tester.startGesture(const Offset(300, 300));
    await gesture.moveBy(const Offset(-40, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-200, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('隐藏'), findsOneWidget);
    expect(find.text('重要'), findsOneWidget);
    expect(find.text('置顶'), findsOneWidget);
  });

  testWidgets('展开后点「隐藏」→ 触发 onHide（滑动隐藏交互）', (tester) async {
    final probe = WidgetBuilderProbe();
    await tester.pumpWidget(_host(probe));

    final gesture = await tester.startGesture(const Offset(300, 300));
    await gesture.moveBy(const Offset(-40, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-200, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    await tester.tap(find.text('隐藏'));
    await tester.pumpAndSettle();
    expect(probe.hideCalls, 1);
  });

  testWidgets('全量左滑越过提交点松手 → 直接触发 onHide', (tester) async {
    final probe = WidgetBuilderProbe();
    await tester.pumpWidget(_host(probe));

    final gesture = await tester.startGesture(const Offset(360, 300));
    await gesture.moveBy(const Offset(-40, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-320, 0)); // 有效位移 ≈288 > 提交点 260
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(probe.hideCalls, 1);
  });

  testWidgets('展开后点「重要」/「置顶」→ 回调并收合', (tester) async {
    final probe = WidgetBuilderProbe();
    await tester.pumpWidget(_host(probe));

    final gesture = await tester.startGesture(const Offset(300, 300));
    await gesture.moveBy(const Offset(-40, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-200, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    await tester.tap(find.text('重要'));
    await tester.pumpAndSettle();
    expect(probe.importantCalls, 1);

    // 再次滑开，点置顶
    final g2 = await tester.startGesture(const Offset(300, 300));
    await g2.moveBy(const Offset(-40, 0));
    await tester.pump();
    await g2.moveBy(const Offset(-220, 0));
    await tester.pump();
    await g2.up();
    await tester.pumpAndSettle();
    await tester.tap(find.text('置顶'));
    await tester.pumpAndSettle();
    expect(probe.pinCalls, 1);
  });
}
