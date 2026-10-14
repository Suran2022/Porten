// #14 验收：编辑资料页 + 修改昵称页 + 性别选择弹窗 + 资料页接线回显
// （对齐 Web 端 EditProfilePage / EditNicknamePage / GenderPickerSheet 链路）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:porten_flutter/core/components/porten_toast.dart';
import 'package:porten_flutter/features/profile/edit_profile_page.dart';
import 'package:porten_flutter/features/profile/state/profile_edit_provider.dart';

/// 打开编辑资料页（可注入外部 container 便于断言 provider 状态；
/// withToastOverlay 复刻 app.dart 的全局 Toast Overlay 注册）。
Future<void> _pumpEditProfilePage(
  WidgetTester tester, {
  ProviderContainer? container,
  bool withToastOverlay = false,
}) async {
  // Riverpod 3：外部 container 需经 UncontrolledProviderScope 注入。
  final Widget scope = container == null
      ? ProviderScope(child: _editProfileApp(withToastOverlay))
      : UncontrolledProviderScope(
          container: container,
          child: _editProfileApp(withToastOverlay),
        );
  await tester.pumpWidget(scope);
  await tester.pump(const Duration(milliseconds: 300));
}

/// 编辑资料页应用壳（withToastOverlay 复刻 app.dart 的全局 Toast Overlay 注册）。
Widget _editProfileApp(bool withToastOverlay) {
  return MaterialApp(
    home: const EditProfilePage(),
    builder: withToastOverlay
        ? (BuildContext context, Widget? child) => Stack(
              children: <Widget>[
                child ?? const SizedBox.shrink(),
                Overlay(key: PortenToast.overlayKey),
              ],
            )
        : null,
  );
}

void main() {
  testWidgets('编辑资料页渲染：顶栏 + 三选项 + 性别回显', (WidgetTester tester) async {
    await _pumpEditProfilePage(tester);

    // 顶栏
    expect(find.text('编辑资料'), findsOneWidget);
    expect(find.text('保存'), findsOneWidget);

    // 三个选项（顺序对齐 Web）
    expect(find.text('修改昵称'), findsOneWidget);
    expect(find.text('设置性别'), findsOneWidget);
    expect(find.text('设置背景图'), findsOneWidget);

    // 性别行右侧回显初始值（provider 初始 trans_female → 跨性别女生）
    expect(find.text('跨性别女生'), findsOneWidget);

    // 性别弹窗未打开时不渲染
    expect(find.text('选择性别'), findsNothing);
  });

  testWidgets('性别选择弹窗：14 选项 + 选中回填 + 离场卸载', (WidgetTester tester) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    await _pumpEditProfilePage(tester, container: container);

    // 打开弹窗：tap 不画帧；进场需两帧完成双 rAF（帧1 挂载初始态、
    // 帧2 后置 isEntering=true 注册动画）；注意 pump(duration) 只画一帧，
    // 动画在序列最后一帧才启动，必须 pumpAndSettle 逐帧推进至稳定。
    await tester.tap(find.text('设置性别'));
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    // 弹窗标题 + 14 个选项（顺序对齐 Web GENDER_OPTIONS）
    expect(find.text('选择性别'), findsOneWidget);
    for (final String label in <String>[
      '跨性别女生', '跨性别男生', '女生', '男生', '非二元性别', '性别酷儿',
      '性别流动', '无性别', '双性别', '泛性别', '探索中', '间性人',
      '不愿透露', '其他',
    ]) {
      expect(find.text(label), findsWidgets, reason: '缺少性别选项：$label');
    }
    // 「跨性别女生」同时出现在性别行右侧与弹窗选中行
    expect(find.text('跨性别女生'), findsNWidgets(2));

    // 选中「非二元性别」：onSelect + onClose 一并回调；
    // pumpAndSettle 一并排空 300ms 离场动画与卸载定时器
    await tester.tap(find.text('非二元性别'));
    await tester.pumpAndSettle();

    // 弹窗离场卸载
    expect(find.text('选择性别'), findsNothing);
    expect(find.text('跨性别女生'), findsNothing);

    // 性别行右侧回填新值 + provider 状态同步
    expect(find.text('非二元性别'), findsOneWidget);
    expect(container.read(profileEditProvider).genderValue, 'non_binary');
  });

  testWidgets('修改昵称链路：进入子页 → trim 保存 → provider 回填', (WidgetTester tester) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    await _pumpEditProfilePage(tester, container: container);

    // 进入修改昵称页（push 左滑转场 300ms）
    await tester.tap(find.text('修改昵称'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // 子页标题 + 输入卡（路由 opaque：下层编辑页不在树中，「修改昵称」仅子页标题一处）
    expect(find.text('修改昵称'), findsOneWidget);
    expect(find.text('新昵称'), findsOneWidget);
    expect(find.text('请输入新昵称'), findsOneWidget);

    // 空文本/全空白时「修改」禁用（gray-400）；enterText 仅 idle 不画帧，需 pump 触发重建
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(tester.widget<Text>(find.text('修改')).style?.color,
        const Color(0xFF9CA3AF));

    // 输入新昵称 → 保存 → pop 回编辑页
    // （enterText 仅 idle 不画帧：tap 前必须 pump，否则按钮仍是禁用态、
    //   GestureDetector 未注册 recognizer，tap 无法触发保存）
    await tester.enterText(find.byType(TextField), '  新月  ');
    await tester.pump();
    await tester.tap(find.text('修改'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('编辑资料'), findsOneWidget);
    expect(container.read(profileEditProvider).nickname, '新月'); // trim 后回填
  });

  testWidgets('设置背景图占位：Toast 提示（App 无选图能力降级）', (WidgetTester tester) async {
    await _pumpEditProfilePage(tester, withToastOverlay: true);

    await tester.tap(find.text('设置背景图'));
    await tester.pump(); // 帧：Toast 插入 Overlay
    await tester.pump(const Duration(milliseconds: 300)); // Toast 淡入 300ms

    expect(find.text('背景图设置即将上线，敬请期待'), findsOneWidget);

    // 排空 Toast 生命周期（2.5s 展示 + 300ms 淡出），避免遗留定时器
    await tester.pump(const Duration(milliseconds: 3000));
    await tester.pump(const Duration(milliseconds: 300));
  });
}
