// 旅程卡徽标几何回归测试：徽标必须贴卡片右缘且收缩为小圆点（防回归）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porten_flutter/features/home/widgets/home_message_list.dart';

void main() {
  testWidgets('旅程卡：徽标贴右缘、宽度为小胶囊（不撑满整行）', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[PortenTripCard()],
            ),
          ),
        ),
      ),
    );
    // 旅程控制器为 AsyncNotifier：首帧 build 的 future 在微任务后完成，
    // 需再导帧（mock 通道同步返回，无网络等待）。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // 卡片宽 = 测试面宽，px-4 右内边距 16 → 徽标右缘应位于 x = 卡宽 - 16
    final Size screen = tester.getSize(find.byType(PortenTripCard));
    final Rect count = tester.getRect(find
        .ancestor(of: find.text('3'), matching: find.byType(Container))
        .first);

    // 徽标应为小胶囊：宽度 < 40（不撑满整行）
    expect(count.width, lessThan(40));
    // 徽标右缘 = 卡片右缘 - 16px 右内边距（容 1px 误差）
    expect((screen.width - 16 - count.right).abs(), lessThan(1.0));
  });
}
