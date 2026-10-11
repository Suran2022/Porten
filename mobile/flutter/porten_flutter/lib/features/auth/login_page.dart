/*
 * 登录页（100% 还原 Web 端 frontend/src/pages/LoginPage.tsx）。
 *
 * 结构：
 *   - 顶部右侧「帮助」按钮（HelpCircle 14px + text-xs gray-400）；
 *   - 居中主区：GradientLogo（text-5xl）→ mt-12 →「登录」标签
 *     （text-sm gray-500 mb-3 pl-1）→ 账号输入（占位符随方式切换）→
 *     密码区（showPassword = isPasswordMode || porten，300ms 过渡）
 *     + 忘记密码 → 验证码区（showCode = codeSent && !showPassword）
 *     + 倒计时/重发行 → GradientButton（「登录」/「获取验证码」）→
 *     AgreementCheckbox；
 *   - 底部：AuthDivider「注册/其他登录方式」+ 三 IconCircleButton
 *     （UserPlus 注册 / Lock 密码登录 / MoreHorizontal 其他登录方式，gap-8）。
 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/components/agreement_checkbox.dart';
import '../../core/components/adaptive_scroll.dart';
import '../../core/components/agreement_viewer.dart';
import '../../core/components/auth_divider.dart';
import '../../core/components/gradient_logo.dart';
import '../../core/components/icon_circle_button.dart';
import '../../core/components/login_method_sheet.dart';
import '../../core/components/porten_button.dart';
import '../../core/components/porten_capsule_input.dart';
import '../../core/components/porten_icons.dart';
import '../../core/components/porten_toast.dart';
import '../../core/design/porten_colors.dart';
import '../../core/design/porten_scale.dart';
import '../../core/design/porten_typography.dart';
import 'state/auth_controller.dart';

/// 登录方式 → 占位符（对齐 Web 端 methodLabels）。
const Map<LoginMethod, String> kMethodPlaceholders = <LoginMethod, String>{
  LoginMethod.email: '请输入邮箱',
  LoginMethod.phone: '请输入手机号',
  LoginMethod.porten: '请输入 Porten 账号',
};

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
  final TextEditingController _accountCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _codeCtrl = TextEditingController();
  LoginMethod? _lastMethod;

  bool _agreed = false;

  // 对齐 Web 端：showPassword = isPasswordMode || porten；
  // showCode = codeSent && !showPassword；
  // 按钮文案：showPassword || codeSent ? '登录' : '获取验证码'。
  bool get _showPassword =>
      ref.read(authProvider).isPasswordMode ||
      ref.read(authProvider).method == LoginMethod.porten;

  bool get _showCode =>
      ref.read(authProvider).codeSent && !_showPassword;

  bool get _showLogin => _showPassword || _showCode;

  @override
  void dispose() {
    _accountCtrl.dispose();
    _passwordCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  /// 切换登录方式时清空输入与发送状态（对齐 Web 端 useEffect 重置）。
  void _syncMethodReset(AuthState auth) {
    if (_lastMethod != auth.method) {
      _lastMethod = auth.method;
      _accountCtrl.clear();
      _passwordCtrl.clear();
      _codeCtrl.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(authProvider.notifier).resetInputState();
      });
    }
  }

  // ------------------------------ 交互 ------------------------------

  bool _agreementGuard() {
    if (!_agreed) {
      PortenToast.show('请先同意相关协议');
      return false;
    }
    return true;
  }

  /// 发送验证码（对齐 Web 端 handleSendCode）。
  Future<void> _handleSendCode() async {
    if (_accountCtrl.text.trim().isEmpty) return;
    if (!_agreementGuard()) return;
    final bool sent = await ref.read(authProvider.notifier).sendCode();
    PortenToast.show(
          sent ? '验证码已发送' : '发送失败，请稍后重试',
          icon: sent ? ToastIcon.success : ToastIcon.error,
        );
  }

  /// 登录（对齐 Web 端 handleLogin）。
  Future<void> _handleLogin() async {
    if (!_agreementGuard()) return;
    final AuthState auth = ref.read(authProvider);
    final String account = _accountCtrl.text.trim();
    final bool isPhone = auth.method == LoginMethod.phone;

    if (isPhone) {
      if (_codeCtrl.text.length != 6) return;
      // Mock 阶段：任意手机号 + 6 位验证码直接进入（loginAsMock）。
      final bool ok = await ref.read(authProvider.notifier).loginMock(
            type: LoginCredentialType.phone,
            identifier: account,
          );
      if (ok && mounted) {
        PortenToast.show('登录成功', icon: ToastIcon.success);
        widget.onLoginSuccess();
      }
      return;
    }

    if (account.isEmpty || _passwordCtrl.text.isEmpty) return;
    if (auth.method == LoginMethod.email &&
        !AuthController.isValidEmail(account)) {
      PortenToast.show('请输入正确的邮箱地址');
      return;
    }
    final bool ok = await ref.read(authProvider.notifier).loginMock(
          type: LoginCredentialType.email,
          identifier: account,
        );
    if (ok && mounted) {
      PortenToast.show('登录成功', icon: ToastIcon.success);
      widget.onLoginSuccess();
    }
  }

  // ------------------------------ 构建 ------------------------------

  @override
  Widget build(BuildContext context) {
    final AuthState auth = ref.watch(authProvider);
    _syncMethodReset(auth);

    // 单屏三段布局（对齐 Web 端 h-full flex flex-col）：
    //   resizeToAvoidBottomInset=false —— 键盘弹出时页面高度不变（对齐 Web
    //   fixed 视口行为），聚焦输入框由 Flutter 自动滚动揭示，整页不压缩；
    //   Column spaceBetween —— 顶部帮助 / 中部表单 / 底部操作区，键盘收起时
    //   恰好单屏铺满，无滚动；内容超高时整体可滚动兜底。
    final double s = PortenScale.of(context);

    return Scaffold(
      backgroundColor: PortenColor.white,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        // AdaptiveScroll：内容不满一屏时锁定不滚动（对齐 Web 端单屏
        // overflow-hidden），超出才允许滚动；键盘弹出时底部补等高内边距，
        // 聚焦输入框的自动揭示才能滚到键盘上方。
        child: AdaptiveScroll(
          alignment: MainAxisAlignment.spaceBetween,
          child: Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _buildTopHelp(),
                _buildFormSection(s),
                _buildBottomActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 顶部右侧「帮助」（justify-end px-6 pt-6）。
  Widget _buildTopHelp() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          GestureDetector(
            onTap: () => PortenToast.show('帮助中心建设中'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                LucideIcon('help-circle', size: 14, color: PortenColor.gray400),
                const SizedBox(width: 4),
                Text(
                  '帮助',
                  style:
                      PortenTypography.xs.copyWith(color: PortenColor.gray400),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 中部表单区（flex-1 居中，px-6）：Logo → mt-12 → 登录标签 → 表单 → 按钮 → 协议。
  Widget _buildFormSection(double s) {
    final AuthState auth = ref.watch(authProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        children: <Widget>[
          GradientLogo(fontSize: 48 * s), // text-5xl
          SizedBox(height: 48 * s), // mt-12
          // 「登录」标签：text-sm gray-500 mb-3 pl-1
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                '登录',
                style: PortenTypography.sm
                    .copyWith(color: PortenColor.gray500),
              ),
            ),
          ),
          CapsuleInput(
            controller: _accountCtrl,
            hint: kMethodPlaceholders[auth.method]!,
            keyboardType:
                auth.method == LoginMethod.phone ? TextInputType.phone : null,
          ),
          const SizedBox(height: 12),
          // 密码区：max-h 过渡
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            sizeCurve: Curves.easeOut,
            crossFadeState: _showPassword
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CapsuleInput(
                  controller: _passwordCtrl,
                  hint: '请输入密码',
                  obscureText: true,
                ),
                // 忘记密码：flex justify-end mt-2 pr-1
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, right: 4),
                    child: GestureDetector(
                      onTap: () => PortenToast.show('找回密码功能建设中'),
                      child: Text(
                        '忘记密码？',
                        style: PortenTypography.xs
                            .copyWith(color: PortenColor.gray400),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: 12),
          // 验证码区
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            sizeCurve: Curves.easeOut,
            crossFadeState: _showCode
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Column(
              children: <Widget>[
                CapsuleInput(
                  controller: _codeCtrl,
                  hint: '请输入验证码',
                  keyboardType: TextInputType.number,
                  maxLength: 6,
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
                            onTap: _handleSendCode,
                            child: Text(
                              '重新获取验证码',
                              style: PortenTypography.xs
                                  .copyWith(color: PortenColor.brandBlue),
                            ),
                          ),
                  ),
                ),
              ],
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
          GradientButton(
            label: _showLogin ? '登录' : '获取验证码',
            loading: auth.isLoading,
            onPressed: () => _showLogin ? _handleLogin() : _handleSendCode(),
          ),
          AgreementCheckbox(
            checked: _agreed,
            onChanged: (bool v) => setState(() => _agreed = v),
            onOpenAgreement: AgreementViewer.open,
          ),
        ],
      ),
    );
  }

  /// 底部操作区：px-6 pb-8 分隔线 + 三按钮（gap-8）。
  Widget _buildBottomActions() {
    final AuthState auth = ref.watch(authProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        children: <Widget>[
          const AuthDivider(text: '注册/其他登录方式'),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              IconCircleButton(
                icon: 'user-plus',
                label: '注册',
                onTap: widget.onGoRegister,
              ),
              const SizedBox(width: 32), // gap-8
              IconCircleButton(
                icon: 'lock',
                label: '密码登录',
                onTap: () =>
                    ref.read(authProvider.notifier).togglePasswordMode(),
              ),
              const SizedBox(width: 32),
              IconCircleButton(
                icon: 'more-horizontal',
                label: '其他登录方式',
                onTap: () => LoginMethodSheet.show(
                  context,
                  value: auth.method,
                  onChange: (LoginMethod m) =>
                      ref.read(authProvider.notifier).setMethod(m),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
