// #13 验收：应用栏管理页 + 情绪音乐馆开关 + 底部栏「悦音乐」入口
// （对齐 Web 端 PortenAppBarPage / HomePage showMusic 持久化 / BottomNav）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:porten_flutter/core/components/porten_brand_switch.dart';
import 'package:porten_flutter/features/home/state/app_bar_config_provider.dart';
import 'package:porten_flutter/features/home/widgets/bottom_nav.dart';
import 'package:porten_flutter/features/profile/porten_app_bar_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // 隔离每个用例的本地配置（对齐 Web localStorage 初始空）
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('应用栏管理页渲染：标题 / 说明 / 情绪音乐馆行', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: PortenAppBarPage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('应用栏管理'), findsOneWidget);
    expect(find.text('开启后，底部菜单栏会展示对应入口'), findsOneWidget);
    expect(find.text('情绪音乐馆'), findsOneWidget);
    expect(find.text('在底部栏展示「悦音乐」入口'), findsOneWidget);
    // 开关存在
    expect(find.byType(PortenBrandSwitch), findsOneWidget);
  });

  testWidgets('开关切换：滑块位移 + 持久化写入', (WidgetTester tester) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PortenAppBarPage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    // 初始关（本地无配置）
    expect(container.read(appBarConfigProvider).showMusic, false);
    AnimatedPositioned thumb = tester.widget<AnimatedPositioned>(
      find.descendant(
        of: find.byType(PortenBrandSwitch),
        matching: find.byType(AnimatedPositioned),
      ),
    );
    expect(thumb.left, 2);

    // 点击开关 → provider 状态 + 滑块滑动到 left=24（200ms 过渡）
    await tester.tap(find.byType(PortenBrandSwitch));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(container.read(appBarConfigProvider).showMusic, true);
    thumb = tester.widget<AnimatedPositioned>(
      find.descendant(
        of: find.byType(PortenBrandSwitch),
        matching: find.byType(AnimatedPositioned),
      ),
    );
    expect(thumb.left, 24);

    // 持久化：JSON {"showMusic":true}（对齐 Web APP_BAR_CONFIG_KEY）。
    // 注意：prefs 读写走 platform channel，须在 runAsync（真实事件循环）中
    // 验证——fakeAsync 下裸 await 非 guarded future 会永久挂起（瓶颈 22 同源）。
    await tester.runAsync(() async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('porten_app_bar_config'), '{"showMusic":true}');
    });

    // 再次点击关闭
    await tester.tap(find.byType(PortenBrandSwitch));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(container.read(appBarConfigProvider).showMusic, false);
    await tester.runAsync(() async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('porten_app_bar_config'), '{"showMusic":false}');
    });
  });

  testWidgets('底部导航：showMusic 控制「悦音乐」入口显隐与点击回调',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: PortenBottomNav(activeIndex: 0, onChange: _onChange),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    // 关闭态：3 个 Tab，无「悦音乐」
    expect(find.text('悦音乐'), findsNothing);
    expect(find.text('消息'), findsOneWidget);
    expect(find.text('资源'), findsOneWidget);
    expect(find.text('知识'), findsOneWidget);

    // 开启态：追加「悦音乐」
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: PortenBottomNav(
              activeIndex: 0,
              onChange: _onChange,
              showMusic: true,
              onMusicClick: _onMusicClick,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('悦音乐'), findsOneWidget);

    // 点击「悦音乐」：触发 onMusicClick，不切换视图
    await tester.tap(find.text('悦音乐'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(_musicClicked, true);
    expect(_viewChanged, false);
  });
}

// 静态回调状态（仅本文件用例使用）。
bool _viewChanged = false;
bool _musicClicked = false;

void _onChange(int _) {
  _viewChanged = true;
}

void _onMusicClick() {
  _musicClicked = true;
}
