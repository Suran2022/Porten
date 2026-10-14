// #11 验收：Porten 安全中心页面 + 绑定的邮箱弹窗 + 365 天冷却弹窗 +
// 换绑流程入口（对齐 Web 端 PortenSecurityPage / BoundEmailDialog /
// ChangeEmailCooldownDialog / ChangeEmailPage 链路）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:porten_flutter/features/profile/porten_security_page.dart';

/// 打开安全中心页（Mock 会话为空 → currentEmail 取兜底常量 user@example.com，
/// maskEmail 脱敏为 us***@example.com）。
Future<void> _pumpSecurityPage(WidgetTester tester) async {
  await tester.pumpWidget(
    const ProviderScope(
      child: MaterialApp(
        home: PortenSecurityPage(),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('安全中心渲染：标题 / 7 个选项 / 盾牌文案', (WidgetTester tester) async {
    await _pumpSecurityPage(tester);

    // 顶栏标题
    expect(find.text('Porten安全中心'), findsOneWidget);
    expect(find.text('反馈进度'), findsOneWidget);

    // 盾牌区文案
    expect(find.text('账号安全 由 Porten 守护'), findsOneWidget);

    // 7 个安全选项（顺序对齐 Web securityOptions）
    for (final String label in <String>[
      '绑定的邮箱',
      '修改登录密码',
      '设备管理',
      '违规相关',
      '历史查询',
      '安全紧急冻结',
      '账号安全设置',
    ]) {
      expect(find.text(label), findsOneWidget, reason: '缺少选项：$label');
    }
  });

  testWidgets('绑定的邮箱弹窗：脱敏展示 + 取消卸载', (WidgetTester tester) async {
    await _pumpSecurityPage(tester);

    await tester.tap(find.text('绑定的邮箱'));
    await tester.pump(const Duration(milliseconds: 300)); // 弹窗进场 200ms

    // 弹窗标题 + 选项行文案同时存在
    expect(find.text('绑定的邮箱'), findsNWidgets(2));
    // 脱敏邮箱（maskEmail：前 2 位 + ***）
    expect(find.text('us***@example.com'), findsOneWidget);
    expect(find.text('为保障账号安全，已对邮箱进行脱敏展示'), findsOneWidget);
    expect(find.text('换绑邮箱'), findsOneWidget);

    // 取消：pump 一帧触发 rebuild（注册 200ms 卸载定时器），再等过渡结束
    await tester.tap(find.text('取消'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('绑定的邮箱'), findsOneWidget); // 仅剩选项行
    expect(find.text('us***@example.com'), findsNothing);
  });

  testWidgets('冷却弹窗：365 天文案 + 继续换绑进入换绑流程页', (WidgetTester tester) async {
    await _pumpSecurityPage(tester);

    await tester.tap(find.text('绑定的邮箱'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('换绑邮箱'));
    await tester.pump(); // 帧：bound 弹窗注册卸载定时器 / cooldown 弹窗进场
    await tester.pump(const Duration(milliseconds: 250));

    // 冷却弹窗
    expect(find.text('365 天之内只能换绑一次邮箱'), findsOneWidget);
    expect(find.text('继续换绑'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);

    // 继续换绑 → push 换绑流程页（300ms 右滑转场）
    await tester.tap(find.text('继续换绑'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 300));

    // 换绑页顶栏标题 + 步骤 1 标题/副标题
    expect(find.text('换绑邮箱'), findsOneWidget);
    expect(find.text('验证原邮箱'), findsOneWidget);
    expect(find.text('请输入原邮箱脱敏部分以验证账号所有权'), findsOneWidget);
    // 步骤 1 原邮箱脱敏展示：u**r@example.com（local user：首尾保留、中间 2 个 *）
    expect(find.text('u**r@example.com'), findsOneWidget);
    expect(find.text('请输入 * 标记的脱敏部分'), findsOneWidget);
  });

  testWidgets('反馈进度占位：可点击但无业务', (WidgetTester tester) async {
    await _pumpSecurityPage(tester);

    // 点击不抛异常、不跳转（仍停留在安全中心）
    await tester.tap(find.text('反馈进度'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Porten安全中心'), findsOneWidget);
    expect(find.text('绑定的邮箱'), findsOneWidget);
  });
}
