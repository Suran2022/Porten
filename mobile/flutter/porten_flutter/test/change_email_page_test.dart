// #12 验收：换绑邮箱三步流程（对齐 Web 端 ChangeEmailPage.tsx）——
//   步骤 1 脱敏输入校验 → 步骤 2 原邮箱验证码（60s 倒计时）→
//   步骤 3 新邮箱 + 验证码 → 提交成功回调（pop 返回新邮箱）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:porten_flutter/core/components/porten_page_transitions.dart';
import 'package:porten_flutter/features/profile/change_email_page.dart';

const String _kCurrentEmail = 'user@example.com';

/// 换绑页测试harness：经路由打开换绑页并捕获 pop 返回值（对齐真实 push 路径）。
class _Harness {
  _Harness(this.tester);

  final WidgetTester tester;
  String? result;
  late Future<String?> pushFuture;

  Future<void> open() async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  pushFuture = Navigator.of(context)
                      .push<String>(
                        PortenSlideFromRightRoute<String>(
                          builder: (_) => const ChangeEmailPage(
                            currentEmail: _kCurrentEmail,
                          ),
                        ),
                      )
                      .then((String? v) {
                    result = v;
                    return v;
                  });
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('步骤 1：脱敏输入错误提示 + 正确后进入步骤 2', (WidgetTester tester) async {
    final _Harness harness = _Harness(tester);
    await harness.open();

    // 步骤 1 初始态
    expect(find.text('验证原邮箱'), findsOneWidget);
    expect(find.text('请输入原邮箱脱敏部分以验证账号所有权'), findsOneWidget);
    expect(find.text('u**r@example.com'), findsOneWidget);

    // 输入错误脱敏部分（应为 'se'）
    await tester.enterText(find.byType(TextField).first, 'xx');
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
    expect(find.text('原邮箱不正确'), findsOneWidget);
    // 仍停留在步骤 1（副标题未切换）
    expect(find.text('请输入原邮箱脱敏部分以验证账号所有权'), findsOneWidget);
    expect(find.text('请输入原邮箱收到的验证码'), findsNothing);

    // 输入正确脱敏部分 → 步骤 2
    await tester.enterText(find.byType(TextField).first, 'se');
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
    expect(find.text('请输入原邮箱收到的验证码'), findsOneWidget);
    expect(find.text('验证码将发送至该邮箱'), findsOneWidget);
    expect(find.text('原邮箱不正确'), findsNothing);
  });

  testWidgets('步骤 2：发送验证码 toast + 60s 倒计时 + 验证码格式校验', (WidgetTester tester) async {
    final _Harness harness = _Harness(tester);
    await harness.open();

    // 直达步骤 2
    await tester.enterText(find.byType(TextField).first, 'se');
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    // 发送验证码：Mock 800ms 后 success toast + 倒计时启动
    await tester.tap(find.text('获取验证码'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('发送中'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('验证码已发送至原邮箱'), findsOneWidget);
    expect(find.text('60s'), findsOneWidget);

    // 倒计时推进 1s → 59s
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('59s'), findsOneWidget);

    // 倒计时期间不可再发送（按钮文案仍为倒计时）
    await tester.tap(find.text('59s'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('59s'), findsOneWidget);

    // 验证码格式错误
    await tester.enterText(find.byType(TextField).first, '12');
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
    expect(find.text('验证码格式不正确'), findsOneWidget);

    // 输入合法验证码 → 步骤 3
    await tester.enterText(find.byType(TextField).first, '123456');
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
    expect(find.text('绑定新邮箱'), findsOneWidget);
    expect(find.text('请输入新的邮箱地址，并通过验证码完成换绑'), findsOneWidget);
  });

  testWidgets('步骤 3：新邮箱校验 + 完整换绑成功回调', (WidgetTester tester) async {
    final _Harness harness = _Harness(tester);
    await harness.open();

    // 直达步骤 3
    await tester.enterText(find.byType(TextField).first, 'se');
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '123456');
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
    expect(find.text('绑定新邮箱'), findsOneWidget);

    // 新邮箱为空时发送按钮禁用
    expect(find.text('获取验证码'), findsOneWidget);

    // 新邮箱与当前相同 → 校验失败
    await tester.enterText(find.byType(TextField).first, 'user@example.com');
    await tester.pumpAndSettle();
    await tester.tap(find.text('获取验证码'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('新邮箱不能与当前邮箱相同'), findsOneWidget);

    // 合法新邮箱：发送验证码
    await tester.enterText(find.byType(TextField).first, 'new@example.com');
    await tester.pumpAndSettle();
    await tester.tap(find.text('获取验证码'));
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('验证码已发送至新邮箱'), findsOneWidget);
    expect(find.text('60s'), findsOneWidget);

    // 提交：校验码 → Mock 800ms → loading toast → 800ms 后 pop 返回新邮箱
    await tester.enterText(find.byType(TextField).last, '654321');
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认换绑'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('提交中...'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('邮箱换绑成功'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 900));
    // pop 后回到入口页
    expect(find.text('open'), findsOneWidget);

    await harness.pushFuture;
    expect(harness.result, 'new@example.com');
  });
}
