// r22：我的行程页布局防回归——中间虚线航程段曾因无界宽度约束
// 在 release 下布局炸裂（灰色大块、文字竖排）。
// 说明：布局异常会经默认 FlutterError.onError 自然使测试失败。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porten_flutter/features/trip/trip_page.dart';

void main() {
  testWidgets('行程页构建无布局异常，三张行程卡完整渲染', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: TripPage())));
    // 不用 pumpAndSettle：PullToRefresh 组件含持续动画会永不 settle
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('我的行程'), findsOneWidget);
    expect(find.text('2天后将前往大连'), findsOneWidget);
    expect(find.text('广州'), findsOneWidget);
    expect(find.text('7天后将前往东京'), findsOneWidget);
    expect(find.text('旧金山'), findsOneWidget);
    expect(find.text('四川航空'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: '不应存在布局异常');
  });
}
