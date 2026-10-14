// #21 创建旅程页交互回归：
//   1. 顶栏 -ml-2 几何（返回键左缘 8px、标题严格居中）——修复 +8 符号错误；
//   2. 城市选择器两步流程（单机场即选 / 双机场进第二步树杈列表）；
//   3. 时间 / 航司选择器；四选完成后出现取消/创建旅程；
//   4. 创建旅程后 Toast 并返回。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porten_flutter/core/components/porten_back_icon.dart';
import 'package:porten_flutter/features/schedule/schedule_page.dart';
import 'package:porten_flutter/features/trip/create_trip_page.dart';

void main() {
  /// 以压栈方式打开创建旅程页（真实 App 中该页由首页加号菜单压栈进入，
  /// 根路由不可 pop，故测试也用 Navigator.push 打开）。
  Future<void> openCreateTripPage(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CreateTripPage(),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('创建旅程页：完整四选流程后创建并返回', (WidgetTester tester) async {
    await openCreateTripPage(tester);

    // 初始占位与完成前无操作按钮
    expect(find.text('创建我的行程'), findsOneWidget);
    expect(find.text('出发地'), findsOneWidget);
    expect(find.text('到达地'), findsOneWidget);
    expect(find.text('出发时间'), findsOneWidget);
    expect(find.text('承运航司'), findsOneWidget);
    expect(find.text('创建旅程'), findsNothing);

    // ① 出发地：搜索单机场城市，点击即选
    await tester.tap(find.text('出发地'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('选择出发地'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '广州');
    await tester.pump();
    await tester.tap(find.descendant(
        of: find.byType(ListView), matching: find.text('广州')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('广州'), findsOneWidget);
    expect(find.text('白云机场'), findsOneWidget);

    // ② 到达地：同流程选大连
    await tester.tap(find.text('到达地'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('选择到达地'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '大连');
    await tester.pump();
    await tester.tap(find.descendant(
        of: find.byType(ListView), matching: find.text('大连')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('大连'), findsOneWidget);
    expect(find.text('周水子机场'), findsOneWidget);

    // ③ 出发时间：三栏滚轮面板，点确定
    await tester.tap(find.text('出发时间'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('选择时间'), findsOneWidget);
    await tester.tap(find.text('确定'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('出发时间'), findsNothing);

    // ④ 承运航司：面板打开（标题与页面占位同名，以搜索框提示断言面板）
    await tester.tap(find.text('承运航司'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('搜索航司'), findsOneWidget);
    await tester.tap(find.text('四川航空'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('四川航空'), findsOneWidget);

    // 四选完成：取消旅程 / 创建旅程出现
    expect(find.text('取消旅程'), findsOneWidget);
    expect(find.text('创建旅程'), findsOneWidget);

    // 创建：Toast（测试环境 Overlay 未挂载时静默丢弃）并返回
    await tester.tap(find.text('创建旅程'));
    await tester.pumpAndSettle();
    expect(find.text('创建我的行程'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('城市选择器：双机场城市进入第二步树杈机场列表',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: CreateTripPage()));
    await tester.pump();

    await tester.tap(find.text('出发地'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), '北京');
    await tester.pump();
    await tester.tap(find.descendant(
        of: find.byType(ListView), matching: find.text('北京')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // 第二步：标题切换为「选择机场」，出现返回按钮与两个机场
    expect(find.text('选择机场'), findsOneWidget);
    expect(find.text('首都国际机场'), findsOneWidget);
    expect(find.text('大兴国际机场'), findsOneWidget);

    // 选机场后面板关闭，卡片显示城市 + 机场
    await tester.tap(find.text('首都国际机场'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('北京'), findsOneWidget);
    expect(find.text('首都国际机场'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('顶栏 -ml-2 几何：返回键左缘 8px、标题严格居中',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: CreateTripPage()));
    await tester.pump();

    // 返回图标：容器 px-4(16) + -ml-2(-8) + 40 盒内居中 28 图标
    // → 图标左缘 = 16 - 8 + (40 - 28) / 2 = 14
    final double iconDx = tester.getTopLeft(find.byType(PortenBackIcon)).dx;
    expect(iconDx, closeTo(14, 0.5));

    // 标题中心 = 屏幕中线（测试 surface 800 宽 → 400）
    final Rect titleRect = tester.getRect(find.text('创建我的行程'));
    expect(titleRect.center.dx, closeTo(400, 0.5));
  });

  testWidgets('日程页顶栏 -ml-2 几何（回归修复）', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SchedulePage()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final double iconDx = tester.getTopLeft(find.byType(PortenBackIcon)).dx;
    expect(iconDx, closeTo(14, 0.5));
    final Rect titleRect = tester.getRect(find.text('我的日程'));
    expect(titleRect.center.dx, closeTo(400, 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('返回键命中区随 -ml-2 左移（布局盒左缘之外的 8px 也可命中）',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CreateTripPage(),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('创建我的行程'), findsOneWidget);

    // Web 返回键命中盒 = 视觉盒 [8,48]×[12,52]：
    // 布局盒 [16,56] 左侧之外的 x=10 处点击也应命中并返回
    await tester.tapAt(const Offset(10, 30));
    await tester.pumpAndSettle();
    expect(find.text('创建我的行程'), findsNothing,
        reason: '返回键命中区应随 -ml-2 左移 8px');
  });
}
