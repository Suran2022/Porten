import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:porten_flutter/core/components/porten_pull_to_refresh.dart';

void main() {
  testWidgets('下拉刷新：在 ListView 顶部下拉应触发刷新', (WidgetTester tester) async {
    bool refreshed = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PortenPullToRefresh(
          onRefresh: () async => refreshed = true,
          child: ListView.builder(
            itemCount: 50,
            itemBuilder: (_, i) => ListTile(title: Text('item $i')),
          ),
        ),
      ),
    ));
    await tester.pump();

    final TestGesture g = await tester.startGesture(const Offset(200, 300));
    for (int i = 0; i < 30; i++) {
      await g.moveBy(const Offset(0, 8));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 2));

    expect(refreshed, true, reason: '下拉超过阈值应触发 onRefresh');
  });
}
