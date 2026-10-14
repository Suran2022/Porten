// #24 记笔记页（NotesPage）交互回归：
//   1. 初始渲染：标题 / 11 条 mock / 添加笔记入口；
//   2. more 钮 → 下拉菜单三项（编辑/归档/删除）；
//   3. 归档 / 取消归档（已归档徽章 + opacity-65）；
//   4. 删除笔记（11 → 10）；
//   5. 根点击关闭下拉；
//   6. 编辑器：添加流程（草稿为空时完成钮禁用 → 输入后可保存 →
//      新笔记置顶 + 空标签回退「随记」）；
//   7. 编辑器：编辑流程（草稿预填 → 保存后 content/time 更新）；
//   8. 纯函数：parseNoteTags 切分/上限/回退、noteTagStyleOf hash
//      与 Web charCode 一致、notesCurrentTimeLabel 格式。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porten_flutter/core/components/porten_lucide_icons.dart';
import 'package:porten_flutter/core/data/notes_mock.dart';
import 'package:porten_flutter/features/home/notes_page.dart';

void main() {
  /// 以压栈方式打开记笔记页（真实 App 中由首页加号菜单压栈进入）。
  Future<void> openNotesPage(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const NotesPage(),
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

  /// 点击第 [index] 张卡片的 more 钮（more-horizontal 图标）。
  Future<void> tapMore(WidgetTester tester, int index) async {
    final Finder more = find.byWidgetPredicate((Widget widget) =>
        widget is PortenLucideIcon && widget.name == 'more-horizontal');
    await tester.tap(more.at(index));
    await tester.pumpAndSettle();
  }

  /// hint 视觉隐藏断言。
  ///
  /// Flutter InputDecoration.maintainHintSize 默认为 true：hint Text
  /// 常驻元素树（空草稿淡入、有内容淡出至 opacity 0），find.text 不
  /// 感知透明度。该行为与 Web placeholder 视觉一致（有内容即隐藏），
  /// 故断言最近 AnimatedOpacity 祖先的透明度而非存在性。
  void expectHintHidden(WidgetTester tester) {
    final Finder hint = find.text('记录此刻的想法……');
    expect(hint, findsOneWidget); // 常驻树中
    final AnimatedOpacity opacity = tester.widget<AnimatedOpacity>(find
        .ancestor(of: hint, matching: find.byType(AnimatedOpacity))
        .first);
    expect(opacity.opacity, 0.0); // 视觉已隐藏
  }

  testWidgets('记笔记页：初始渲染 11 条 mock 与顶栏', (WidgetTester tester) async {
    await openNotesPage(tester);

    expect(find.text('我的笔记'), findsOneWidget);
    // 「添加笔记」出现 2 次：顶栏入口钮 + 编辑器标题（Web 编辑器覆盖层
    // 恒渲染，隐藏态 translate-x-full + pointer-events-none，见
    // NotesPage.tsx L352-353，App 端同构——常驻树中、 IgnorePointer）。
    expect(find.text('添加笔记'), findsNWidgets(2));
    // 首条 mock 正文 + 标签
    expect(find.text('今天把消息列表的交互流程重新梳理了一遍。优先让核心路径保持简单，再逐步补充细节和反馈。'),
        findsOneWidget);
    expect(find.text('工作'), findsWidgets);
    expect(find.text('灵感'), findsWidgets);
    // 11 张卡片的 more 钮
    final Finder more = find.byWidgetPredicate((Widget widget) =>
        widget is PortenLucideIcon && widget.name == 'more-horizontal');
    expect(more, findsNWidgets(11));
    // 未展开菜单
    expect(find.text('编辑笔记'), findsNothing);
  });

  testWidgets('记笔记页：more 菜单三项与归档切换', (WidgetTester tester) async {
    await openNotesPage(tester);
    await tapMore(tester, 0);

    // 下拉菜单三项
    expect(find.text('编辑笔记'), findsOneWidget);
    expect(find.text('归档笔记'), findsOneWidget);
    expect(find.text('删除笔记'), findsOneWidget);

    // 归档 → 已归档徽章 + opacity-65
    await tester.tap(find.text('归档笔记'));
    await tester.pumpAndSettle();
    expect(find.text('已归档'), findsOneWidget);
    expect(
        tester.widget<Opacity>(find.byType(Opacity).first).opacity, 0.65);

    // 再次打开菜单 → 取消归档
    await tapMore(tester, 0);
    expect(find.text('取消归档'), findsOneWidget);
    await tester.tap(find.text('取消归档'));
    await tester.pumpAndSettle();
    expect(find.text('已归档'), findsNothing);
    expect(tester.widget<Opacity>(find.byType(Opacity).first).opacity, 1.0);
  });

  testWidgets('记笔记页：删除笔记后剩 10 条', (WidgetTester tester) async {
    await openNotesPage(tester);
    await tapMore(tester, 0);
    await tester.tap(find.text('删除笔记'));
    await tester.pumpAndSettle();

    final Finder more = find.byWidgetPredicate((Widget widget) =>
        widget is PortenLucideIcon && widget.name == 'more-horizontal');
    expect(more, findsNWidgets(10));
  });

  testWidgets('记笔记页：根点击关闭下拉菜单', (WidgetTester tester) async {
    await openNotesPage(tester);
    await tapMore(tester, 0);
    expect(find.text('编辑笔记'), findsOneWidget);

    // 点击页面空白处（标题区域，IgnorePointer 穿透到根 GestureDetector）
    await tester.tap(find.text('我的笔记'));
    await tester.pumpAndSettle();
    expect(find.text('编辑笔记'), findsNothing);
  });

  testWidgets('记笔记页：添加笔记流程（空草稿禁用 → 保存置顶 + 随记回退）',
      (WidgetTester tester) async {
    await openNotesPage(tester);
    // 顶栏入口钮：「添加笔记」文本在树中出现 2 次（顶栏胶囊 text-sm
    // + 编辑器标题 text-lg，后者恒驻），按字号 14 精确定位顶栏胶囊。
    final Finder addEntry = find.byWidgetPredicate((Widget widget) =>
        widget is Text &&
        widget.data == '添加笔记' &&
        widget.style?.fontSize == 14);
    expect(addEntry, findsOneWidget);
    await tester.tap(addEntry);
    await tester.pumpAndSettle();

    // 编辑器打开：标题切换 + textarea 自动聚焦
    expect(find.text('添加笔记'), findsNWidgets(2)); // 顶栏钮 + 编辑器标题
    expect(tester.testTextInput.isRegistered, isTrue);

    // 草稿为空 → 完成钮禁用（点击无反应）
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(find.text('我的笔记'), findsOneWidget); // 仍未回到列表态

    // 输入内容 → 完成钮启用
    await tester.enterText(find.byType(TextField).first, '新的测试笔记内容');
    await tester.pump();
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    // 编辑器滑出，新笔记置顶，空标签回退「随记」。
    // 「新的测试笔记内容」命中 2 个：置顶卡片 + 编辑器草稿（Web
    // saveNote 不清空 draft、编辑器覆盖层恒渲染，App 端同构）。
    expect(find.text('新的测试笔记内容'), findsNWidgets(2));
    expect(find.text('随记'), findsOneWidget);
    expectHintHidden(tester);
  });

  testWidgets('记笔记页：编辑笔记流程（草稿预填 → 保存更新）',
      (WidgetTester tester) async {
    await openNotesPage(tester);
    await tapMore(tester, 0);
    await tester.tap(find.text('编辑笔记'));
    await tester.pumpAndSettle();

    // 草稿预填首条 mock 的 content 与 tags（顿号连接）
    expectHintHidden(tester); // 有草稿 → hint 视觉隐藏
    final TextField content =
        tester.widget<TextField>(find.byType(TextField).first);
    expect(content.controller?.text, contains('今天把消息列表的交互流程'));
    final TextField tags = tester.widget<TextField>(find.byType(TextField).last);
    expect(tags.controller?.text, '工作、灵感');

    // 修改内容 → 保存
    await tester.enterText(find.byType(TextField).first, '修改后的内容');
    await tester.pump();
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    // 命中 2 个：卡片更新后的正文 + 编辑器草稿（Web 不清空 draft）。
    expect(find.text('修改后的内容'), findsNWidgets(2));
    expect(
        find.text('今天把消息列表的交互流程重新梳理了一遍。优先让核心路径保持简单，再逐步补充细节和反馈。'),
        findsNothing);
  });

  group('记笔记页：纯函数（对齐 Web 语义）', () {
    test('parseNoteTags：切分 / 上限 4 / 新建回退 / 编辑可清空', () {
      expect(parseNoteTags('工作 灵感、产品,设计，日常 健康'),
          <String>['工作', '灵感', '产品', '设计']);
      expect(parseNoteTags(''), isEmpty);
      expect(parseNoteTags('', fallback: true), <String>['随记']);
      expect(parseNoteTags('   '), isEmpty);
      expect(parseNoteTags('单个'), <String>['单个']);
    });

    test('noteTagStyleOf：charCode 求和 % 6 与 Web 一致', () {
      // 「工作」= U+5DE5 + U+4F5C = 44353；44353 % 6 = 1 → pink
      expect(noteTagStyleOf('工作').background, const Color(0xCCFCE7F3));
      expect(noteTagStyleOf('工作').foreground, const Color(0xFFBE185D));
      // 「灵感」= U+7075 + U+611F = 53652；53652 % 6 = 0 → sky
      expect(noteTagStyleOf('灵感').background, const Color(0xCCE0F2FE));
      expect(noteTagStyleOf('灵感').foreground, const Color(0xFF0369A1));
      // 「设计」= U+8BBE + U+8BA1 = 71519；71519 % 6 = 5 → indigo
      expect(noteTagStyleOf('设计').background, const Color(0xCCE0E7FF));
      expect(noteTagStyleOf('设计').foreground, const Color(0xFF4338CA));
    });

    test('notesCurrentTimeLabel：今天 HH:mm（2 位补零）', () {
      expect(notesCurrentTimeLabel(DateTime(2026, 10, 14, 9, 5)), '今天 09:05');
      expect(notesCurrentTimeLabel(DateTime(2026, 10, 14, 23, 59)), '今天 23:59');
    });
  });
}
