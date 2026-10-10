/*
 * 注册页（100% 还原 Web 端 frontend/src/pages/RegisterPage.tsx）。
 *
 * 两步流程：
 *   step=form  —— 标题「注册 Porten」+ 副文案「创建身份继续」
 *                 邮箱/密码/确认密码 + 校验（EMAIL_REGEX、密码≥8 位、
 *                 字母数字混合、两次一致）+ 协议勾选（未勾选显示
 *                 agreementError「请阅读并同意相关协议后继续」）+
 *                 GradientButton「下一步」；
 *   step=code  —— 副文案「输入代码完成身份创建」+ 6 位验证码 + 60s 倒计时
 *                 + GradientButton「立即注册」。
 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/components/agreement_checkbox.dart';
import '../../core/components/porten_button.dart';
import '../../core/components/porten_capsule_input.dart';
import '../../core/components/porten_toast.dart';
import '../../core/design/porten_colors.dart';
import '../../core/design/porten_typography.dart';
import 'state/auth_controller.dart';

enum _RegisterStep { form, code }

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({
    super.key,
    required this.onGoLogin,
    required this.onRegisterSuccess,
  });

  final VoidCallback onGoLogin;
  final VoidCallback onRegisterSuccess;

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _confirmCtrl = TextEditingController();
  final TextEditingController _codeCtrl = TextEditingController();

  _RegisterStep _step = _RegisterStep.form;
  bool _agreed = false;
  String? _agreementError;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  // ------------------------------ 第一步：表单校验 ------------------------------

  void _onNextTap(AuthState auth) {
    final String email = _emailCtrl.text.trim();

    if (_step == _RegisterStep.code) {
      _onRegisterTap(auth, email);
      return;
    }

    if (email.isEmpty) {
      PortenToast.show('请输入邮箱');
      return;
    }
    if (!AuthController.isValidEmail(email)) {
      PortenToast.show('请输入正确的邮箱地址');
      return;
    }
    final String? passwordError = AuthController.validatePassword(_passwordCtrl.text);
    if (passwordError != null) {
      PortenToast.show(passwordError);
      return;
    }
    if (_confirmCtrl.text != _passwordCtrl.text) {
      PortenToast.show('两次输入的密码不一致');
      return;
    }
    if (!_agreed) {
      setState(() => _agreementError = '请阅读并同意相关协议后继续');
      return;
    }
    setState(() => _agreementError = null);

    // 进入第二步：发送验证码并启动倒计时。
    if (ref.read(authProvider.notifier).sendCode()) {
      setState(() => _step = _RegisterStep.code);
      PortenToast.show('验证码已发送（Mock 环境任意 6 位可通过）');
    }
  }

  Future<void> _onRegisterTap(AuthState auth, String email) async {
    if (_codeCtrl.text.length != 6) {
      PortenToast.show('请输入 6 位验证码');
      return;
    }
    final bool ok =
        await ref.read(authProvider.notifier).registerMock(identifier: email);
    if (ok && mounted) {
      PortenToast.show('注册成功，欢迎加入 Porten');
      widget.onRegisterSuccess();
    }
  }

  // ------------------------------ 构建 ------------------------------

  @override
  Widget build(BuildContext context) {
    final AuthState auth = ref.watch(authProvider);
    final bool isFormStep = _step == _RegisterStep.form;

    return Scaffold(
      backgroundColor: PortenColor.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: 56),
              if (isFormStep) ...<Widget>[
                Text(
                  '注册 Porten',
                  style: TextStyle(
                    inherit: false,
                    fontFamily: PortenTypography.base.fontFamily,
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    color: PortenColor.gray900,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Text(
                isFormStep ? '创建身份继续' : '输入代码完成身份创建',
                style: PortenTypography.sm.copyWith(color: PortenColor.gray500),
              ),
              const SizedBox(height: 36),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 300),
                sizeCurve: Curves.easeInOut,
                crossFadeState: isFormStep
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                firstChild: Column(
                  children: <Widget>[
                    CapsuleInput(
                      controller: _emailCtrl,
                      hint: '邮箱地址',
                      prefixIcon: Icons.mail_outline,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    CapsuleInput(
                      controller: _passwordCtrl,
                      hint: '密码（至少 8 位，含字母和数字）',
                      prefixIcon: Icons.lock_outline,
                      obscureText: true,
                    ),
                    const SizedBox(height: 12),
                    CapsuleInput(
                      controller: _confirmCtrl,
                      hint: '确认密码',
                      prefixIcon: Icons.lock_outline,
                      obscureText: true,
                    ),
                  ],
                ),
                secondChild: Column(
                  children: <Widget>[
                    CapsuleInput(
                      controller: _codeCtrl,
                      hint: '6 位验证码',
                      prefixIcon: Icons.shield_outlined,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed:
                            auth.countdown > 0 ? null : () => _resendCode(),
                        child: Text(
                          auth.countdown > 0
                              ? '${auth.countdown} s 后重发'
                              : '重新发送验证码',
                          style: PortenTypography.xs.copyWith(
                            color: auth.countdown > 0
                                ? PortenColor.gray400
                                : PortenColor.brandBlue,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GradientButton(
                label: isFormStep ? '下一步' : '立即注册',
                loading: auth.isLoading,
                onPressed: () => _onNextTap(auth),
              ),
              const SizedBox(height: 20),
              if (isFormStep)
                AgreementCheckbox(
                  checked: _agreed,
                  onChanged: (bool v) => setState(() {
                    _agreed = v;
                    if (v) _agreementError = null;
                  }),
                  errorText: _agreementError,
                ),
              const SizedBox(height: 28),
              Center(
                child: TextButton(
                  onPressed: widget.onGoLogin,
                  child: Text.rich(
                    TextSpan(
                      text: '已有身份？',
                      style: PortenTypography.sm.copyWith(
                        color: PortenColor.gray500,
                      ),
                      children: <InlineSpan>[
                        TextSpan(
                          text: '去登录',
                          style: PortenTypography.sm.copyWith(
                            color: PortenColor.brandBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _resendCode() {
    if (ref.read(authProvider.notifier).sendCode()) {
      PortenToast.show('验证码已重新发送');
    }
  }
}
