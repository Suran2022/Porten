/*
 * 注册页（100% 还原 Web 端 frontend/src/pages/RegisterPage.tsx）。
 *
 * 两步流程：
 *   step=form  —— 「注册 Porten」大标题（text-5xl font-bold）+「创建身份继续」
 *                 + 邮箱/设置密码/确认密码 + 校验（错误红字居中显示于按钮上方）+
 *                 GradientButton「下一步」+ 协议勾选（未勾选 → agreementError
 *                 红字「请阅读并同意相关协议后继续」显示在勾选行下方 mt-2）；
 *   step=code  —— 「输入代码完成身份创建」+ 6 位验证码 + 60s 倒计时
 *                 （「{n}s 重新获取验证码」/「重新获取验证码」#5BCEFA）+
 *                 GradientButton「立即注册」；
 *   底部：AuthDivider「去登录」+ 单个 LogIn 图标按钮「去登录」。
 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/components/agreement_checkbox.dart';
import '../../core/components/agreement_viewer.dart';
import '../../core/components/auth_divider.dart';
import '../../core/components/icon_circle_button.dart';
import '../../core/components/porten_button.dart';
import '../../core/components/porten_capsule_input.dart';
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
  bool _agreementError = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  // ------------------------------ 校验（对齐 Web 端 validateForm） ------------------------------

  String? _validateForm() {
    final String email = _emailCtrl.text.trim();
    if (email.isEmpty || !AuthController.isValidEmail(email)) {
      return '请输入正确的邮箱地址';
    }
    final String? passwordError = AuthController.validatePassword(_passwordCtrl.text);
    if (passwordError != null) return passwordError;
    if (_passwordCtrl.text != _confirmCtrl.text) {
      return '两次输入的密码不一致';
    }
    return null;
  }

  // ------------------------------ 交互 ------------------------------

  Future<void> _handleNext() async {
    setState(() {
      _error = null;
      if (!_agreed) _agreementError = true;
    });
    if (!_agreed) return;
    setState(() => _agreementError = false);
    final String? err = _validateForm();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    final bool sent = await ref.read(authProvider.notifier).sendCode();
    if (!mounted) return;
    if (!sent) {
      setState(() => _error = '发送验证码失败');
      return;
    }
    setState(() {
      _step = _RegisterStep.code;
      _codeCtrl.clear();
    });
  }

  Future<void> _handleResend() async {
    final AuthState auth = ref.read(authProvider);
    if (auth.countdown > 0) return;
    setState(() => _error = null);
    final bool sent = await ref.read(authProvider.notifier).sendCode();
    if (!mounted) return;
    if (!sent) setState(() => _error = '发送验证码失败');
  }

  Future<void> _handleRegister() async {
    setState(() {
      _error = null;
      if (!_agreed) _agreementError = true;
    });
    if (!_agreed) return;
    setState(() => _agreementError = false);
    if (_codeCtrl.text.length != 6) {
      setState(() => _error = '请输入 6 位验证码');
      return;
    }
    final bool ok = await ref
        .read(authProvider.notifier)
        .registerMock(identifier: _emailCtrl.text.trim());
    if (ok && mounted) {
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
        child: Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    const SizedBox(height: 48),
                    // 标题：仅 step=form 显示（text-5xl font-bold）
                    if (isFormStep)
                      Text(
                        '注册 Porten',
                        style: TextStyle(
                          inherit: false,
                          fontFamily: PortenTypography.base.fontFamily,
                          fontSize: 48,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          letterSpacing: -48 * 0.025, // tracking-tight
                          color: PortenColor.gray900,
                        ),
                      ),
                    const SizedBox(height: 48), // mt-12
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 12),
                        child: Text(
                          isFormStep ? '创建身份继续' : '输入代码完成身份创建',
                          style: PortenTypography.sm
                              .copyWith(color: PortenColor.gray500),
                        ),
                      ),
                    ),
                    // Step 1 表单区：max-h 过渡
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 300),
                      sizeCurve: Curves.easeOut,
                      crossFadeState: isFormStep
                          ? CrossFadeState.showFirst
                          : CrossFadeState.showSecond,
                      firstChild: Column(
                        children: <Widget>[
                          CapsuleInput(
                            controller: _emailCtrl,
                            hint: '请输入邮箱',
                            keyboardType: TextInputType.emailAddress,
                            onChanged: (_) {
                              if (_error != null) setState(() => _error = null);
                            },
                          ),
                          const SizedBox(height: 12),
                          CapsuleInput(
                            controller: _passwordCtrl,
                            hint: '设置密码',
                            obscureText: true,
                            onChanged: (_) {
                              if (_error != null) setState(() => _error = null);
                            },
                          ),
                          const SizedBox(height: 12),
                          CapsuleInput(
                            controller: _confirmCtrl,
                            hint: '确认密码',
                            obscureText: true,
                            onChanged: (_) {
                              if (_error != null) setState(() => _error = null);
                            },
                          ),
                          const SizedBox(height: 20), // mb-5
                        ],
                      ),
                      secondChild: const SizedBox(width: double.infinity),
                    ),
                    // Step 2 验证码区
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 300),
                      sizeCurve: Curves.easeOut,
                      crossFadeState: isFormStep
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      firstChild: Column(
                        children: <Widget>[
                          CapsuleInput(
                            controller: _codeCtrl,
                            hint: '请输入验证码',
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            onChanged: (_) {
                              if (_error != null) setState(() => _error = null);
                            },
                          ),
                          SizedBox(
                            height: 32,
                            child: Center(
                              child: auth.countdown > 0
                                  ? Text(
                                      '${auth.countdown}s 重新获取验证码',
                                      style: PortenTypography.xs
                                          .copyWith(color: PortenColor.gray400),
                                    )
                                  : GestureDetector(
                                      onTap: _handleResend,
                                      child: Text(
                                        '重新获取验证码',
                                        style: PortenTypography.xs.copyWith(
                                          color: PortenColor.brandBlue,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                      secondChild: const SizedBox(width: double.infinity),
                    ),
                    // 错误红字：text-xs text-red-500 text-center mb-3
                    if (_error != null) ...<Widget>[
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: PortenTypography.xs
                            .copyWith(color: PortenColor.error),
                      ),
                      const SizedBox(height: 12),
                    ],
                    GradientButton(
                      label: isFormStep ? '下一步' : '立即注册',
                      loading: auth.isLoading,
                      onPressed: isFormStep ? _handleNext : _handleRegister,
                    ),
                    AgreementCheckbox(
                      checked: _agreed,
                      onChanged: (bool v) => setState(() {
                        _agreed = v;
                        if (v) _agreementError = false;
                      }),
                      onOpenAgreement: AgreementViewer.open,
                    ),
                    // agreementError：text-xs text-red-500 text-center mt-2
                    if (_agreementError)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '请阅读并同意相关协议后继续',
                          textAlign: TextAlign.center,
                          style: PortenTypography.xs
                              .copyWith(color: PortenColor.error),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // 底部：去登录
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                children: <Widget>[
                  const AuthDivider(text: '去登录'),
                  const SizedBox(height: 16),
                  Center(
                    child: IconCircleButton(
                      icon: 'log-in',
                      label: '去登录',
                      onTap: widget.onGoLogin,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
