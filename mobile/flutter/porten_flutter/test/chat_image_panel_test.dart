// bug2：聊天页相册图片面板展开后应可滑动查看全部可发送图片
// （r21 面板高度恒 236 + GridView 禁滚动导致第 3 行被裁且不可达；
//  r23 改为 GridView 内部滚动，全部相册图片可达）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:porten_flutter/core/components/porten_lucide_icons.dart';
import 'package:porten_flutter/core/data/home_mock.dart';
import 'package:porten_flutter/features/chat/chat_page.dart';

const PortenConversation _kConv = PortenConversation(
  id: 1,
  isGroup: false,
  name: '抚月',
  lastMessage: '在吗？',
  minutesAgo: 3,
  unreadCount: 0,
);

void main() {
  testWidgets('bug2：相册面板 GridView 可滚动，11 张图片全部可达',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    await tester.pumpWidget(
        const MaterialApp(home: ChatPage(conversation: _kConv)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // 点击输入面板四图标行中的「图片」图标展开相册面板
    final Finder imageIcon = find.byWidgetPredicate(
        (Widget w) => w is PortenLucideIcon && w.name == 'image');
    expect(imageIcon, findsOneWidget);
    await tester.tap(imageIcon);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 以相册资产路径定位面板内图片，反查其所属 GridView（区别于表情/更多面板）
    final Finder albumImg = find.byWidgetPredicate((Widget w) =>
        w is Image &&
        w.image is AssetImage &&
        (w.image as AssetImage).assetName ==
            'assets/mock_avatars/camp_kge.jpg');
    expect(albumImg, findsOneWidget, reason: '相册面板应渲染相册图片');
    final Finder panelGrid = find.ancestor(
        of: albumImg, matching: find.byType(GridView));
    expect(panelGrid, findsOneWidget);

    // 相册面板应渲染全部 11 张可发送图片
    expect(find.descendant(of: panelGrid, matching: find.byType(Image)),
        findsNWidgets(11),
        reason: '相册面板应渲染全部 11 张可发送图片');

    // GridView 应可纵向滚动（面板高度 236 只放得下两行）
    final ScrollableState scrollable = tester.state<ScrollableState>(
        find.descendant(
            of: panelGrid, matching: find.byType(Scrollable)));
    final double maxExtent = scrollable.position.maxScrollExtent;
    debugPrint('相册面板 maxScrollExtent = $maxExtent');
    expect(maxExtent, greaterThan(0), reason: '相册面板应可滚动查看第 3 行');

    // 上滑滚到底部，最后一张图片应进入可视区域
    await tester.drag(panelGrid, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, greaterThan(maxExtent - 1));
  });
}
