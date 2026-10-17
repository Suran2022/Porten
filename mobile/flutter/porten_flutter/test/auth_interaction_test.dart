// 认证页交互回归测试：验证按钮/协议点可点击、状态切换、动画推进。
//
// 注意：页面含无限 repeat 的流光动画，禁止使用 pumpAndSettle（永不静止），
// 全部用固定步进 pump。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porten_flutter/app.dart';
import 'package:porten_flutter/core/components/login_method_sheet.dart'
    show LoginMethod;
import 'package:porten_flutter/core/components/porten_button.dart';
import 'package:porten_flutter/core/components/porten_capsule_input.dart';
import 'package:porten_flutter/features/auth/state/auth_controller.dart';

void main() {
  testWidgets('登录页：协议点可切换、按钮可触发发送、动画持续推进', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: PortenApp()));

    // 跳过开屏：3s 停留 + 400ms 淡出
    await tester.pump(const Duration(seconds: 3, milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // 1. 登录页已呈现（账号 / 密码 / 验证码三个输入框同页渲染）
    expect(find.text('登录'), findsWidgets);
    expect(find.byType(GradientButton), findsOneWidget);
    expect(find.byType(CapsuleInput), findsWidgets);

    // 2. 输入账号（账号 / 密码 / 验证码三个输入框同页渲染，取账号框）
    await tester.enterText(find.byType(CapsuleInput).first, 'test@example.com');
    await tester.pump();
    final BuildContext context = tester.element(find.byType(GradientButton));

    // 3. 点击协议圆点（文本左侧行首 12px 圆点；协议文案为 Text.rich 富文本）
    final Finder agreementText =
        find.textContaining('我已阅读并遵守', findRichText: true);
    expect(agreementText, findsOneWidget);
    await tester.tapAt(tester.getTopLeft(agreementText) + const Offset(-12, 10));
    await tester.pump();

    // 4. 切到验证码模式并点「获取验证码」→ Mock 发送 → Toast「验证码已发送」
    //    （初始为密码模式，按钮文案为「登录」；togglePasswordMode 后按钮变为发码）
    ProviderScope.containerOf(context)
        .read(authProvider.notifier)
        .togglePasswordMode();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('获取验证码'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.text('验证码已发送'), findsOneWidget,
        reason: '按钮点击后应触发 Mock 发码并弹 Toast');

    // 5. 动画持续推进（16s/8s/3s 流光均为无限 repeat）
    bool sawAnimation = false;
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      if (tester.binding.transientCallbackCount > 0) sawAnimation = true;
    }
    expect(sawAnimation, isTrue, reason: '流光动画帧调度不应停止');
  });

  testWidgets('登录方式切换：占位符随方式切换', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: PortenApp()));
    await tester.pump(const Duration(seconds: 3, milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('请输入邮箱'), findsOneWidget);

    // 经 Provider 切换登录方式（底部面板的点选交互受测试窗口高度限制，
    // 由组件级测试覆盖；此处验证占位符随方式联动）。
    final BuildContext context = tester.element(find.byType(GradientButton));
    ProviderScope.containerOf(context)
        .read(authProvider.notifier)
        .setMethod(LoginMethod.phone);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('请输入手机号'), findsOneWidget);
  });

  testWidgets('AuthController：sendCode 进入倒计时状态', (tester) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(authProvider).codeSent, isFalse);
    // mock 通道内含 800ms 延迟，testWidgets 的 fake async 下必须经
    // runAsync 在真实异步域执行，否则 delayed 定时器永不触发。
    final bool sent = await tester.runAsync<bool>(
          () => container.read(authProvider.notifier).sendCode(),
        ) ??
        false;
    expect(sent, isTrue);
    expect(container.read(authProvider).codeSent, isTrue);
    expect(container.read(authProvider).countdown, greaterThan(0));
    // 主动释放容器，取消倒计时定时器（dispose 时触发 onDispose → _stopTimer）
    container.dispose();
  });
}
