// #25 情绪日记页（EmotionDiaryPage + EmotionHistoryPage + store 联动）回归：
//   1. 初始渲染：加载占位 → 日记卡（mood chip / 谁看过这条 / 观众网格 /
//      删除入口 / 修改入口）+ 跨性别主题底色；
//   2. 编辑流程：草稿预填 → 换 mood/改内容 → 保存 → 卡片更新 + toast
//      「已保存」+ currentUserDiaryProvider 同步；
//   3. 空内容保存 → error toast「请写下今天的心情」；
//   4. 删除流程：确认弹窗 → 删除 → 未发布态表单 + store 清空；
//   5. 新建流程：输入 → 保存 → 新日记卡 + store 同步 + 计数器；
//   6. 历史页：打开 → 2 张卡片 + 当前/历史徽章 + 共 N 条 → 返回关闭；
//   7. cisMode 主题：cis_female → 浅灰底 #FAFAFA；
//   8. 顶栏联动：mood tag →「emoji label」；latestDiary 为 null 时
//      分隔符与日记隐藏；
//   9. 纯函数：moodOptionOf / isCisGender / formatDiaryTime / MOOD_OPTIONS。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:porten_flutter/core/components/porten_back_icon.dart';
import 'package:porten_flutter/core/components/porten_lucide_icons.dart';
import 'package:porten_flutter/core/data/current_user_store.dart';
import 'package:porten_flutter/core/data/emotion_diary_mock.dart';
import 'package:porten_flutter/features/home/emotion_diary_page.dart';
import 'package:porten_flutter/features/home/emotion_history_page.dart';
import 'package:porten_flutter/features/home/widgets/home_top_bar.dart';
import 'package:porten_flutter/features/profile/state/profile_edit_provider.dart';

void main() {
  /// 压栈方式打开情绪日记页（真实 App 中由首页加号菜单压栈进入）。
  ///
  /// 先重置 mock 引擎（等价 Web 每次刷新页面重新加载 mockEngine），
  /// 避免同一文件内前一个用例的删除/创建污染后续用例。
  Future<void> pumpDiaryPage(
      WidgetTester tester, ProviderContainer container) async {
    mockResetDiaries();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: EmotionDiaryPage()),
      ),
    );
    // 首帧渲染未发布态表单（Web useEffect 首帧后才触发加载），
    // post-frame 回调同步置 loading → 本帧起显示加载占位。
    await tester.pump();
  }

  /// 推进 mock 引擎延迟与后续 setState。
  ///
  /// loadCurrent 的 finally 在 loadViewers 之后才翻 loading（Web 同款
  /// 语义），首屏最坏需 360+360=720ms；pumpAndSettle 的单步时长取
  /// 900ms 覆盖整条延迟链——步长小于链长时，定时器挂起中但暂无
  /// 待构建帧，pumpAndSettle 会提前退出导致日记卡未渲染（偶发失败）。
  Future<void> settleMockDelay(WidgetTester tester) async {
    await tester.pumpAndSettle(const Duration(milliseconds: 900));
  }

  /// toast 出现断言：覆盖 mock 延迟后 toast 应可见（自动隐藏 1500ms
  /// 尚未触发）。SystemToast 常驻树中（退场后仅 opacity=0），故消失
  /// 断言用 [expectToastHidden]。
  Future<void> expectToastShown(WidgetTester tester, String text) async {
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.text(text), findsOneWidget);
  }

  /// toast 视觉消失断言：1500ms 自动隐藏 + 300ms 退场动画后 opacity=0。
  void expectToastHidden(WidgetTester tester, String text) {
    final Opacity opacity = tester.widget<Opacity>(find
        .ancestor(of: find.text(text), matching: find.byType(Opacity))
        .first);
    expect(opacity.opacity, 0.0);
  }

  /// 点击顶栏历史钮（history 图标）。
  Future<void> tapHistoryButton(WidgetTester tester) async {
    final Finder history = find.byWidgetPredicate((Widget widget) =>
        widget is PortenLucideIcon && widget.name == 'history');
    await tester.tap(history);
    await tester.pumpAndSettle();
  }

  ProviderContainer newContainer() {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  group('情绪日记页：初始渲染', () {
    testWidgets('加载占位 → 日记卡（跨性别默认主题）', (WidgetTester tester) async {
      final ProviderContainer container = newContainer();
      await pumpDiaryPage(tester, container);

      // 加载占位（Web loading 态）
      expect(find.text('加载中...'), findsOneWidget);

      await settleMockDelay(tester);

      // 日记卡：mood chip / 正文 / 观众区 / 删除入口
      expect(find.text('现在 开心'), findsOneWidget);
      expect(
        find.text('今天阳光很好，坐在窗边写下这些的时候，突然觉得被世界温柔地接住了。愿我们都能慢慢长成自己喜欢的样子。'),
        findsOneWidget);
      expect(find.text('谁看过这条'), findsOneWidget);
      expect(find.text('3 人'), findsOneWidget);
      expect(find.text('小雨'), findsOneWidget);
      expect(find.text('Luna'), findsOneWidget);
      expect(find.text('苏苏'), findsOneWidget);
      expect(find.text('删除这条日记'), findsOneWidget);
      // 铅笔 + 底部两个「修改」入口
      expect(find.text('修改'), findsOneWidget);
      // 未展开编辑表单
      expect(find.text('现在感觉…'), findsNothing);
      // 跨性别默认主题（profileEditProvider 默认 trans_female）
      final Scaffold scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, const Color(0xFFF7F7F7));
    });

    testWidgets('cisMode 主题：cis_female → 浅灰底 #FAFAFA',
        (WidgetTester tester) async {
      final ProviderContainer container = newContainer();
      container.read(profileEditProvider.notifier).setGender('cis_female');
      await pumpDiaryPage(tester, container);
      await settleMockDelay(tester);

      final Scaffold scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, const Color(0xFFFAFAFA));
    });
  });

  group('情绪日记页：编辑 / 保存', () {
    testWidgets('编辑流程：草稿预填 → 换 mood → 保存 → 卡片更新 + store 同步',
        (WidgetTester tester) async {
      final ProviderContainer container = newContainer();
      await pumpDiaryPage(tester, container);
      await settleMockDelay(tester);

      // 底部「修改」进入编辑态
      await tester.tap(find.text('修改'));
      await tester.pumpAndSettle();

      // 表单：草稿预填 + 「保存修改」文案 + 计数器
      expect(find.text('现在感觉…'), findsOneWidget);
      expect(find.text('保存修改'), findsOneWidget);
      final TextField field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller?.text, contains('今天阳光很好'));
      expect(find.text('50/4000'), findsOneWidget); // 首条 mock 正文字数

      // 换 mood → 焦虑 + 改内容
      await tester.tap(find.text('焦虑'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '修改后的心情记录');
      await tester.pump();
      expect(find.text('8/4000'), findsOneWidget);

      // 保存 → mock 延迟 → 卡片更新 + toast + store 同步
      // （按钮行在 600px 测试视口折叠线下，先滚动入视口再点）
      await tester.ensureVisible(find.text('保存修改'));
      await tester.pump();
      await tester.tap(find.text('保存修改'));
      await expectToastShown(tester, '已保存');

      expect(find.text('现在 焦虑'), findsOneWidget);
      expect(find.text('修改后的心情记录'), findsOneWidget);
      expect(find.text('保存修改'), findsNothing); // 回到已发布态

      final CurrentUserDiaryState state =
          container.read(currentUserDiaryProvider);
      expect(state.mood, 'anxious');
      expect(state.latestDiary, '修改后的心情记录');

      // 1500ms 自动隐藏 + 300ms 退场后视觉消失
      // （隐藏定时器与退场动画分两段推进：定时器触发只翻 visible，
      //   Opacity 归零需再走完 300ms reverse 动画）
      await tester.pump(const Duration(milliseconds: 1800));
      await tester.pump(const Duration(milliseconds: 400));
      expectToastHidden(tester, '已保存');
    });

    testWidgets('空内容保存 → error toast「请写下今天的心情」',
        (WidgetTester tester) async {
      final ProviderContainer container = newContainer();
      await pumpDiaryPage(tester, container);
      await settleMockDelay(tester);

      // 删除进入未发布态后直接点保存（空草稿）
      await tester.tap(find.text('删除这条日记'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除')); // 确认弹窗
      await settleMockDelay(tester);
      expect(find.text('已删除'), findsOneWidget);

      await tester.ensureVisible(find.text('保存')); // isFirstTime 文案
      await tester.pump();
      await tester.tap(find.text('保存'));
      await expectToastShown(tester, '请写下今天的心情');
      // 仍未退出编辑态
      expect(find.text('现在感觉…'), findsOneWidget);
    });
  });

  group('情绪日记页：删除 / 新建', () {
    testWidgets('删除流程：确认弹窗 → 未发布态 + store 清空',
        (WidgetTester tester) async {
      final ProviderContainer container = newContainer();
      await pumpDiaryPage(tester, container);
      await settleMockDelay(tester);

      await tester.tap(find.text('删除这条日记'));
      await tester.pumpAndSettle();
      // 确认弹窗（Web window.confirm 原生等价）
      expect(find.text('确定删除这条情绪日记？'), findsOneWidget);
      await tester.tap(find.text('删除'));
      await expectToastShown(tester, '已删除');

      // 回到未发布态编辑表单（isFirstTime → 「保存」文案）
      expect(find.text('现在感觉…'), findsOneWidget);
      expect(find.text('保存'), findsOneWidget);
      expect(find.text('谁看过这条'), findsNothing);

      final CurrentUserDiaryState state =
          container.read(currentUserDiaryProvider);
      expect(state.mood, null);
      expect(state.latestDiary, null);
    });

    testWidgets('取消确认弹窗不删除', (WidgetTester tester) async {
      final ProviderContainer container = newContainer();
      await pumpDiaryPage(tester, container);
      await settleMockDelay(tester);

      await tester.tap(find.text('删除这条日记'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      // 仍在已发布态
      expect(find.text('谁看过这条'), findsOneWidget);
      expect(
        container.read(currentUserDiaryProvider).latestDiary,
        isNotNull,
      );
    });

    testWidgets('新建流程：输入 → 保存 → 新日记卡 + store 同步',
        (WidgetTester tester) async {
      final ProviderContainer container = newContainer();
      await pumpDiaryPage(tester, container);
      await settleMockDelay(tester);

      // 先删除旧日记进入未发布态
      await tester.tap(find.text('删除这条日记'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await settleMockDelay(tester);

      // 选 mood（平静）+ 输入内容
      await tester.tap(find.text('平静'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '全新的一天');
      await tester.pump();

      await tester.ensureVisible(find.text('保存'));
      await tester.pump();
      await tester.tap(find.text('保存'));
      await expectToastShown(tester, '已保存');

      // 新日记卡：mood chip + 正文 + 观众区
      expect(find.text('现在 平静'), findsOneWidget);
      expect(find.text('全新的一天'), findsOneWidget);
      expect(find.text('谁看过这条'), findsOneWidget);

      final CurrentUserDiaryState state =
          container.read(currentUserDiaryProvider);
      expect(state.mood, 'calm');
      expect(state.latestDiary, '全新的一天');

      // 收尾：保存后会再加载 viewers（Future.delayed 裸定时器，无法
      // 取消），推 900ms 排空，避免 testWidgets 结束时定时器仍挂起
      // 触发 !timersPending 断言。
      await tester.pump(const Duration(milliseconds: 900));
    });
  });

  group('情绪日记页：历史情绪页', () {
    testWidgets('打开历史页：2 张卡片 + 徽章 + 总数 → 返回关闭',
        (WidgetTester tester) async {
      final ProviderContainer container = newContainer();
      await pumpDiaryPage(tester, container);
      await settleMockDelay(tester);

      await tapHistoryButton(tester);
      await settleMockDelay(tester);

      // 历史页标题 + 徽章 + 尾注
      expect(find.text('历史情绪'), findsOneWidget);
      expect(find.text('当前'), findsOneWidget);
      expect(find.text('历史'), findsOneWidget);
      expect(find.text('共 2 条记录'), findsOneWidget);
      expect(find.text('加载更多'), findsNothing); // hasMore=false
      // id1 正文同时出现在日记卡与历史卡（共 2 处）；id2 仅历史卡
      expect(
        find.text('今天阳光很好，坐在窗边写下这些的时候，突然觉得被世界温柔地接住了。愿我们都能慢慢长成自己喜欢的样子。'),
        findsNWidgets(2));
      expect(
        find.text('今天和咨询师聊了最近的状态，突然意识到自己已经很久没有好好照顾情绪了。晚上给自己煮了热汤，看了半部电影。慢慢来，都会好的。'),
        findsOneWidget);

      // 返回关闭（覆盖层常驻树中，visible 翻转为 false）
      final Finder backIcon = find.byWidgetPredicate(
          (Widget widget) => widget is PortenBackIcon && widget.size == 28);
      // 历史页返回钮（日记页返回钮同为 28，取最后一个 = 历史页）
      await tester.tap(backIcon.last);
      await tester.pumpAndSettle();
      final EmotionHistoryPage historyPage =
          tester.widget(find.byType(EmotionHistoryPage));
      expect(historyPage.visible, false);
    });
  });

  group('首页顶栏联动（currentUserDiaryProvider）', () {
    testWidgets('mood tag →「emoji label」；latestDiary 为 null 时隐藏日记行',
        (WidgetTester tester) async {
      final ProviderContainer container = newContainer();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: HomeTopBar())),
        ),
      );

      // 初始：mood='happy' →「😊 开心」+ 日记摘要
      expect(find.text('😊 开心'), findsOneWidget);
      expect(find.textContaining('今天阳光很好'), findsOneWidget);

      // store 更新 → 顶栏跟随（Web authStore.updateUser 语义）
      container
          .read(currentUserDiaryProvider.notifier)
          .updateFromDiary(mood: 'anxious', content: '顶栏联动验证');
      await tester.pump();
      expect(find.text('😰 焦虑'), findsOneWidget);
      expect(find.text('顶栏联动验证'), findsOneWidget);

      // store 清空 → mood 回退静态默认 + 分隔符/日记隐藏
      container.read(currentUserDiaryProvider.notifier).clear();
      await tester.pump();
      expect(find.text('😊 开心'), findsOneWidget);
      expect(find.textContaining('顶栏联动验证'), findsNothing);
      expect(find.text('｜'), findsNothing);
    });
  });

  group('情绪日记：纯函数（对齐 Web 语义）', () {
    test('MOOD_OPTIONS：10 项、顺序与首项', () {
      expect(kMoodOptions.length, 10);
      expect(kMoodOptions.first.value, 'happy');
      expect(kMoodOptions.first.label, '开心');
      expect(kMoodOptions.first.emoji, '😊');
      // 长短标签分布：短标签 9 项（3 列网格）、长标签 1 项（充满希望）
      expect(
        kMoodOptions.where((MoodOption o) => o.label.length <= 2).length, 9);
      expect(
        kMoodOptions.where((MoodOption o) => o.label.length > 2).length, 1);
    });

    test('moodOptionOf：命中返回选项，未命中/null 返回 null', () {
      expect(moodOptionOf('happy')?.label, '开心');
      expect(moodOptionOf('hopeful')?.label, '充满希望');
      expect(moodOptionOf('not-a-mood'), null);
      expect(moodOptionOf(null), null);
    });

    test('isCisGender：cis_female/cis_male → true，其余 → false', () {
      expect(isCisGender('cis_female'), true);
      expect(isCisGender('cis_male'), true);
      expect(isCisGender('trans_female'), false);
      expect(isCisGender('non_binary'), false);
      expect(isCisGender(null), false);
    });

    test('formatDiaryTime：今天 HH:mm / yyyy-MM-dd HH:mm', () {
      final DateTime now = DateTime.now();
      final String today = formatDiaryTime(
        DateTime(now.year, now.month, now.day, 9, 5),
      );
      expect(today, '今天 09:05');
      // 固定远古日期，避开「测试运行日」歧义
      expect(
        formatDiaryTime(DateTime(2020, 1, 2, 3, 4)),
        '2020-01-02 03:04',
      );
    });
  });
}
