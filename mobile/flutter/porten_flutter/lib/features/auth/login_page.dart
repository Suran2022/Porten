/*
 * 登录页（100% 还原 Web 端 frontend/src/pages/LoginPage.tsx）。
 *
 * 结构（自上而下）：
 *   - 右上角「帮助」；
 *   - 中央 GradientLogo（流光）+ 副标题；
 *   - 登录方式指示文案（随 method 切换）；
 *   - 凭证输入（email/phone 切换占位符与图标）；
 *   - 密码/验证码模式区（AnimatedCrossFade 对齐 Web 端 max-h 过渡）；
 *   - GradientButton（文案随模式切换「获取验证码」/「登录」，验证码模式
 *     且倒计时进行中显示「xx s」）；
 *   - AgreementCheckbox；
 *   - 底部 AuthDivider「注册 / 其他登录方式」+ 三个 IconCircleButton。
 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/components/agreement_checkbox.dart';
import '../../core/components/auth_divider.dart';
import '../../core/components/gradient_logo.dart';
import '../../core/components/icon_circle_button.dart';
import '../../core/components/login_method_sheet.dart';
import '../../core/components/porten_button.dart';
import '../../core/components/porten_capsule_input.dart';
import '../../core/components/porten_toast.dart';
import '../../core/design/porten_colors.dart';
import '../../core/design/porten_typography.dart';
import 'state/auth_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({
    super.key,
    required this.onGoRegister,
    required this.onLoginSuccess,
  });

  final VoidCallback onGoRegister;
  final VoidCallback onLoginSuccess;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final TextEditingController _identifierCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _codeCtrl = TextEditingController();
  final FocusNode _identifierFocus = FocusNode();

  bool _agreed = false;

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    _codeCtrl.dispose();
    _identifierFocus.dispose();
    super.dispose();
  }

  // ------------------------------ 交互 ------------------------------

  void _onMainButtonTap(AuthState auth) {
    final String identifier = _identifierCtrl.text.trim();
    final bool emailMode = auth.method == LoginMethod.email;

    if (identifier.isEmpty) {
      PortenToast.show(emailMode ? '请输入邮箱' : '请输入手机号');
      return;
    }
    if (emailMode && !AuthController.isValidEmail(identifier)) {
      PortenToast.show('请输入正确的邮箱地址');
      return;
    }
    if (!emailMode && !AuthController.isValidPhone(identifier)) {
      PortenToast.show('请输入正确的手机号');
      return;
    }

    if (auth.isPasswordMode) {
      if (_passwordCtrl.text.isEmpty) {
        PortenToast.show('请输入密码');
        return;
      }
    } else {
      if (_codeCtrl.text.length != 6) {
        PortenToast.show('请输入 6 位验证码');
        return;
      }
    }

    if (!_agreed) {
      PortenToast.show('请先同意相关协议');
      return;
    }

    _submitLogin(auth, identifier);
  }

  Future<void> _submitLogin(AuthState auth, String identifier) async {
    // Porten ID / 手机号在 Mock 环境直接走 Mock 登录（对齐 Web 端 loginAsMock）；
    // 邮箱密码模式同样走 Mock 引擎。
    final bool ok = await ref.read(authProvider.notifier).loginMock(
          type: auth.method == LoginMethod.email
              ? LoginCredentialType.email
              : LoginCredentialType.phone,
          identifier: identifier,
        );
    if (ok && mounted) {
      PortenToast.show('欢迎回来');
      widget.onLoginSuccess();
    }
  }

  void _onSendCode(AuthState auth) {
    if (auth.countdown > 0) return;
    final String identifier = _identifierCtrl.text.trim();
    final bool emailMode = auth.method == LoginMethod.email;
    if (emailMode && !AuthController.isValidEmail(identifier)) {
      PortenToast.show('请输入正确的邮箱地址');
      return;
    }
    if (!emailMode && !AuthController.isValidPhone(identifier)) {
      PortenToast.show('请输入正确的手机号');
      return;
    }
    ref.read(authProvider.notifier).sendCode();
    PortenToast.show('验证码已发送（Mock 环境任意 6 位可通过）');
  }

  // ------------------------------ 构建 ------------------------------

  @override
  Widget build(BuildContext context) {
    final AuthState auth = ref.watch(authProvider);
    final bool emailMode = auth.method == LoginMethod.email;

    return Scaffold(
      backgroundColor: PortenColor.white,
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            Positioned(
              top: 8,
              right: 20,
              child: TextButton(
                onPressed: () => PortenToast.show('帮助中心建设中'),
                child: Text(
                  '帮助',
                  style: PortenTypography.sm.copyWith(color: PortenColor.gray500),
                ),
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: <Widget>[
                  const SizedBox(height: 72),
                  const GradientLogo(fontSize: 48),
                  const SizedBox(height: 10),
                  Text(
                    emailMode ? '邮箱登录' : (auth.method == LoginMethod.phone ? '手机号登录' : 'Porten ID 登录'),
                    style: PortenTypography.lg.copyWith(
                      color: PortenColor.gray900,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '登录后继续你的旅程',
                    style: PortenTypography.sm.copyWith(color: PortenColor.gray500),
                  ),
                  const SizedBox(height: 40),
                  CapsuleInput(
                    controller: _identifierCtrl,
                    hint: emailMode ? '邮箱地址' : '手机号',
                    prefixIcon: emailMode ? Icons.mail_outline : Icons.phone_iphone,
                    keyboardType: emailMode
                        ? TextInputType.emailAddress
                        : TextInputType.phone,
                    focusNode: _identifierFocus,
                  ),
                  const SizedBox(height: 12),
                  // 密码/验证码模式区：对齐 Web 端 max-h 过渡。
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 300),
                    sizeCurve: Curves.easeInOut,
                    crossFadeState: auth.isPasswordMode
                        ? CrossFadeState.showFirst
                        : CrossFadeState.showSecond,
                    firstChild: Column(
                      children: <Widget>[
                        CapsuleInput(
                          controller: _passwordCtrl,
                          hint: '密码',
                          prefixIcon: Icons.lock_outline,
                          obscureText: true,
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () =>
                                PortenToast.show('找回密码功能建设中'),
                            child: Text(
                              '忘记密码？',
                              style: PortenTypography.xs.copyWith(
                                color: PortenColor.gray500,
                              ),
                            ),
                          ),
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
                      ],
                    ),
                  ),
                  GradientButton(
                    label: _mainButtonLabel(auth),
                    loading: auth.isLoading,
                    onPressed: () => _onMainButtonTap(auth),
                  ),
                  if (!auth.isPasswordMode) ...<Widget>[
                    const SizedBox(height: 12),
                    _buildCodeActionRow(auth),
                  ],
                  const SizedBox(height: 20),
                  AgreementCheckbox(
                    checked: _agreed,
                    onChanged: (bool v) => setState(() => _agreed = v),
                  ),
                  const SizedBox(height: 36),
                  AuthDivider(label: '注册 / 其他登录方式'),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      IconCircleButton(
                        icon: Icons.person_add_alt_1,
                        label: '注册',
                        onTap: widget.onGoRegister,
                      ),
                      const SizedBox(width: 28),
                      IconCircleButton(
                        icon: Icons.lock_open,
                        label: '密码登录',
                        onTap: () => ref
                            .read(authProvider.notifier)
                            .togglePasswordMode(),
                      ),
                      const SizedBox(width: 28),
                      IconCircleButton(
                        icon: Icons.apps,
                        label: '其他登录方式',
                        onTap: () => LoginMethodSheet(
                          selected: auth.method,
                          onSelect: (LoginMethod m) =>
                              ref.read(authProvider.notifier).setMethod(m),
                        ).show(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _mainButtonLabel(AuthState auth) {
    if (!auth.isPasswordMode) {
      return auth.countdown > 0 ? '${auth.countdown} s 后重发' : '获取验证码';
    }
    return '登录';
  }

  /// 验证码模式下按钮下方的「发送验证码」动作行。
  Widget _buildCodeActionRow(AuthState auth) {
    final bool canSend = auth.countdown == 0;
    return TextButton(
      onPressed: canSend ? () => _onSendCode(auth) : null,
      child: Text(
        canSend
            ? '发送验证码'
            : '${auth.countdown} s 后可重新发送',
        style: PortenTypography.xs.copyWith(
          color: canSend ? PortenColor.brandBlue : PortenColor.gray400,
        ),
      ),
    );
  }
}
