/*
 * 换绑邮箱流程页（100% 移植 Web 端 components/profile/ChangeEmailPage.tsx）。
 *
 * 结构：bg-[#f7f7f7]；顶栏 BackIcon + 「换绑邮箱」+ w-8 占位；
 * 内容 px-6 pt-8：标题 text-2xl font-semibold tracking-tight +
 *   副标题 text-sm gray-500 leading-6；三步表单（space-y-5）：
 *   verifyCurrent 验证原邮箱（脱敏展示 + 脱敏部分输入）→
 *   oldCode 原邮箱验证码（CodeInputRow）→
 *   newEmail 新邮箱 + 新邮箱验证码；
 * SystemToast（loading 旋转 / success / error，300ms 淡入 + scale 90→100，
 *   换绑成功 loading 态 800ms 后回调 onSuccess）。
 *
 * API Mock 策略：与登录/注册一致，本地延迟 800ms 模拟，不发真实请求。
 */

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/components/porten_back_icon.dart';
import '../../core/components/porten_lucide_icons.dart';
import '../../core/utils/porten_email.dart';
import 'profile_page.dart' show kGray900, kGray700, kGray500, kGray400, kGray300, kGray200;

const int _kCountdownSeconds = 60;
const int _kToastAutoHideMs = 1500;
const int _kSuccessDelayMs = 800;

/// 换绑步骤（对齐 Web Step）。
enum _Step { verifyCurrent, oldCode, newEmail }

/// SystemToast 类型（对齐 Web ToastType）。
enum _ToastType { loading, success, error }

class ChangeEmailPage extends StatefulWidget {
  const ChangeEmailPage({super.key, required this.currentEmail});

  final String currentEmail;

  @override
  State<ChangeEmailPage> createState() => _ChangeEmailPageState();
}

class _ChangeEmailPageState extends State<ChangeEmailPage> {
  _Step _step = _Step.verifyCurrent;
  String _oldEmailInput = '';
  String _oldCode = '';
  String _newEmail = '';
  String _newCode = '';

  int _oldCountdown = 0;
  int _newCountdown = 0;
  bool _sendingOld = false;
  bool _sendingNew = false;
  bool _submitting = false;

  final Map<String, String> _errors = <String, String>{};

  bool _toastVisible = false;
  _ToastType _toastType = _ToastType.loading;
  String _toastText = '';

  Timer? _oldTimer;
  Timer? _newTimer;
  Timer? _toastHideTimer;

  @override
  void initState() {
    super.initState();
    // Web 端 masked 由 currentEmail useMemo 得出；页面创建时即确定。
    _maskedRef = maskEmailForVerify(widget.currentEmail);
  }

  /// 原邮箱脱敏结构（initState 中按 currentEmail 计算）。
  late final MaskedEmail? _maskedRef;

  @override
  void dispose() {
    _oldTimer?.cancel();
    _newTimer?.cancel();
    _toastHideTimer?.cancel();
    super.dispose();
  }

  // ------------------------------ Toast ------------------------------

  void _showToast(_ToastType type, String text, {bool autoHide = true}) {
    _toastHideTimer?.cancel();
    _toastHideTimer = null;
    setState(() {
      _toastType = type;
      _toastText = text;
      _toastVisible = true;
    });
    if (autoHide) {
      _toastHideTimer = Timer(
        const Duration(milliseconds: _kToastAutoHideMs),
        () {
          if (!mounted) return;
          setState(() => _toastVisible = false);
        },
      );
    }
  }

  void _hideToast() {
    _toastHideTimer?.cancel();
    _toastHideTimer = null;
    if (!mounted) return;
    setState(() => _toastVisible = false);
  }

  // ------------------------------ 倒计时 ------------------------------

  void _startCountdown({required bool isOld}) {
    final Timer? existing = isOld ? _oldTimer : _newTimer;
    existing?.cancel();
    setState(() {
      if (isOld) {
        _oldCountdown = _kCountdownSeconds;
      } else {
        _newCountdown = _kCountdownSeconds;
      }
    });
    final Timer timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (isOld) {
          if (_oldCountdown <= 1) {
            timer.cancel();
            _oldTimer = null;
            _oldCountdown = 0;
          } else {
            _oldCountdown -= 1;
          }
        } else {
          if (_newCountdown <= 1) {
            timer.cancel();
            _newTimer = null;
            _newCountdown = 0;
          } else {
            _newCountdown -= 1;
          }
        }
      });
    });
    if (isOld) {
      _oldTimer = timer;
    } else {
      _newTimer = timer;
    }
  }

  // ------------------------------ API（Mock 800ms） ------------------------------

  Future<void> _sendVerificationCodeMock(String email) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    // Mock 阶段始终成功；失败路径与 Web 一致走 showToast('error', msg)。
  }

  Future<void> _changeEmailMock() async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
  }

  // ------------------------------ 步骤 1：验证原邮箱 ------------------------------

  void _handleVerifyCurrent() {
    final MaskedEmail? masked = _maskedRef;
    if (masked == null) {
      setState(() => _errors['oldEmailInput'] = '当前账号未绑定邮箱');
      return;
    }
    final EmailVerifyResult result =
        verifyEmailByMask(masked, _oldEmailInput, widget.currentEmail);
    if (!result.isOk) {
      setState(() => _errors['oldEmailInput'] = result.message ?? '原邮箱不正确');
      return;
    }
    setState(() => _errors.remove('oldEmailInput'));
    setState(() => _step = _Step.oldCode);
  }

  // ------------------------------ 步骤 2：原邮箱验证码 ------------------------------

  Future<void> _handleSendOldCode() async {
    if (!isValidEmail(widget.currentEmail)) {
      _showToast(_ToastType.error, '当前邮箱格式异常');
      return;
    }
    setState(() => _sendingOld = true);
    try {
      await _sendVerificationCodeMock(widget.currentEmail);
      _showToast(_ToastType.success, '验证码已发送至原邮箱');
      _startCountdown(isOld: true);
    } on Exception catch (err) {
      _showToast(_ToastType.error, _errorMessage(err, '发送失败，请稍后重试'));
    } finally {
      if (mounted) setState(() => _sendingOld = false);
    }
  }

  void _handleSubmitOldCode() {
    final String? err = validateVerificationCode(_oldCode);
    if (err != null) {
      setState(() => _errors['oldCode'] = err);
      return;
    }
    setState(() => _errors.remove('oldCode'));
    setState(() => _step = _Step.newEmail);
  }

  // ------------------------------ 步骤 3：新邮箱 ------------------------------

  Future<void> _handleSendNewCode() async {
    final String? err = validateNewEmail(_newEmail, widget.currentEmail);
    if (err != null) {
      setState(() => _errors['newEmail'] = err);
      return;
    }
    setState(() => _errors.remove('newEmail'));
    setState(() => _sendingNew = true);
    try {
      await _sendVerificationCodeMock(_newEmail.trim());
      _showToast(_ToastType.success, '验证码已发送至新邮箱');
      _startCountdown(isOld: false);
    } on Exception catch (err) {
      _showToast(_ToastType.error, _errorMessage(err, '发送失败，请稍后重试'));
    } finally {
      if (mounted) setState(() => _sendingNew = false);
    }
  }

  Future<void> _handleSubmitNewCode() async {
    final String? emailErr = validateNewEmail(_newEmail, widget.currentEmail);
    if (emailErr != null) {
      setState(() => _errors['newEmail'] = emailErr);
      return;
    }
    final String? codeErr = validateVerificationCode(_newCode);
    if (codeErr != null) {
      setState(() => _errors['newCode'] = codeErr);
      return;
    }
    _errors.clear();
    setState(() => _submitting = true);
    try {
      await _changeEmailMock();
      // loading 态不自动隐藏：800ms 后隐藏并回调成功（对齐 Web）
      _showToast(_ToastType.loading, '邮箱换绑成功', autoHide: false);
      Timer(const Duration(milliseconds: _kSuccessDelayMs), () {
        _hideToast();
        if (mounted) Navigator.of(context).pop(_newEmail.trim());
      });
    } on Exception catch (err) {
      _showToast(_ToastType.error, _errorMessage(err, '换绑失败，请稍后重试'));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  static String _errorMessage(Exception err, String fallback) {
    return err.toString().replaceFirst('Exception: ', '');
  }

  // ------------------------------ 构建 ------------------------------

  String get _stepTitle {
    switch (_step) {
      case _Step.verifyCurrent:
      case _Step.oldCode:
        return '验证原邮箱';
      case _Step.newEmail:
        return '绑定新邮箱';
    }
  }

  String get _stepSubtitle {
    switch (_step) {
      case _Step.verifyCurrent:
        return '请输入原邮箱脱敏部分以验证账号所有权';
      case _Step.oldCode:
        return '请输入原邮箱收到的验证码';
      case _Step.newEmail:
        return '请输入新的邮箱地址，并通过验证码完成换绑';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: <Widget>[
            Column(
              children: <Widget>[
                // 顶栏（白底，BackIcon + 居中标题 + w-8 占位）
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: SizedBox(
                    height: 40,
                    child: Row(
                      children: <Widget>[
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => Navigator.of(context).maybePop(),
                          // -ml-2：Container margin 不支持负值，用 Transform 位移等价实现
                          child: Transform.translate(
                            offset: const Offset(-8, 0),
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: Center(child: const PortenBackIcon()),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text('换绑邮箱',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: kGray900)),
                        ),
                        const SizedBox(width: 32), // w-8 占位
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        // 标题区（px-6 pt-8）
                        Padding(
                          padding: const EdgeInsets.only(left: 24, right: 24, top: 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(_stepTitle,
                                  style: const TextStyle(
                                    fontSize: 24, // text-2xl
                                    fontWeight: FontWeight.w600, // font-semibold
                                    letterSpacing: -0.6, // tracking-tight
                                    height: 32 / 24,
                                    color: kGray900,
                                  )),
                              const SizedBox(height: 8), // mt-2
                              Text(_stepSubtitle,
                                  style: const TextStyle(
                                    fontSize: 14, // text-sm
                                    height: 24 / 14, // leading-6
                                    color: kGray500,
                                  )),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32), // 表单 mt-8
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24), // px-6
                          child: _buildStepForm(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // SystemToast（页内局部移植）
            _SystemToast(
              visible: _toastVisible,
              type: _toastType,
              text: _toastText,
            ),
          ],
        ),
      ),
    );
  }

  /// 当前步骤表单（对齐 Web space-y-5：子块间距 20px）。
  Widget _buildStepForm() {
    switch (_step) {
      case _Step.verifyCurrent:
        return _buildVerifyCurrentForm();
      case _Step.oldCode:
        return _buildOldCodeForm();
      case _Step.newEmail:
        return _buildNewEmailForm();
    }
  }

  Widget _buildVerifyCurrentForm() {
    final MaskedEmail? masked = _maskedRef;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // 原邮箱（脱敏展示）
        const _FieldLabel('原邮箱'),
        const SizedBox(height: 8), // mb-2
        Container(
          height: 48, // h-12
          padding: const EdgeInsets.symmetric(horizontal: 16), // px-4
          alignment: Alignment.centerLeft,
          child: Text(
            masked?.display ?? '当前账号未绑定邮箱',
            style: TextStyle(
              fontSize: 16, // text-base
              fontFamily: 'monospace', // font-mono
              letterSpacing: 0.4, // tracking-wide
              color: masked != null ? kGray700 : kGray400,
            ),
          ),
        ),
        if (masked != null)
          Padding(
            padding: const EdgeInsets.only(top: 8), // mt-2
            child: Text(masked.hint,
                style: const TextStyle(fontSize: 12, color: kGray400)), // text-xs
          ),
        const SizedBox(height: 20), // space-y-5
        // 脱敏部分输入
        const _FieldLabel('脱敏部分'),
        const SizedBox(height: 8), // mb-2
        _PortenTextField(
          value: _oldEmailInput,
          enabled: masked != null,
          maxLength: masked?.inputLen ?? 0,
          placeholder: masked != null ? '请输入 ${masked.inputLen} 个字符' : '请先绑定邮箱',
          error: _errors['oldEmailInput'] != null,
          onChanged: (String v) {
            setState(() {
              _oldEmailInput = v;
              _errors.remove('oldEmailInput');
            });
          },
        ),
        if (_errors['oldEmailInput'] != null)
          _ErrorText(_errors['oldEmailInput']!),
        const SizedBox(height: 20), // space-y-5
        _PrimaryButton(
          label: '下一步',
          enabled: masked != null,
          onTap: _handleVerifyCurrent,
        ),
      ],
    );
  }

  Widget _buildOldCodeForm() {
    final MaskedEmail? masked = _maskedRef;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _FieldLabel('原邮箱'),
        const SizedBox(height: 8), // mb-2
        Container(
          height: 48, // h-12
          padding: const EdgeInsets.symmetric(horizontal: 16), // px-4
          alignment: Alignment.centerLeft,
          child: Text(
            masked?.display ?? widget.currentEmail,
            style: const TextStyle(
              fontSize: 16, // text-base
              fontFamily: 'monospace', // font-mono
              letterSpacing: 0.4, // tracking-wide
              color: kGray700,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 8), // mt-2
          child: Text('验证码将发送至该邮箱',
              style: TextStyle(fontSize: 12, color: kGray400)), // text-xs
        ),
        const SizedBox(height: 20), // space-y-5
        const _FieldLabel('验证码'),
        const SizedBox(height: 8), // mb-2
        _CodeInputRow(
          value: _oldCode,
          countdown: _oldCountdown,
          sending: _sendingOld,
          error: _errors['oldCode'] != null,
          onChanged: (String v) {
            setState(() {
              _oldCode = v;
              _errors.remove('oldCode');
            });
          },
          onSend: _handleSendOldCode,
        ),
        if (_errors['oldCode'] != null) _ErrorText(_errors['oldCode']!),
        const SizedBox(height: 20), // space-y-5
        _PrimaryButton(
          label: '下一步',
          enabled: true,
          onTap: _handleSubmitOldCode,
        ),
      ],
    );
  }

  Widget _buildNewEmailForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _FieldLabel('新邮箱'),
        const SizedBox(height: 8), // mb-2
        _PortenTextField(
          value: _newEmail,
          placeholder: '请输入新邮箱',
          keyboardType: TextInputType.emailAddress,
          error: _errors['newEmail'] != null,
          onChanged: (String v) {
            setState(() {
              _newEmail = v;
              _errors.remove('newEmail');
            });
          },
        ),
        if (_errors['newEmail'] != null) _ErrorText(_errors['newEmail']!),
        const SizedBox(height: 20), // space-y-5
        const _FieldLabel('新邮箱验证码'),
        const SizedBox(height: 8), // mb-2
        _CodeInputRow(
          value: _newCode,
          countdown: _newCountdown,
          sending: _sendingNew,
          error: _errors['newCode'] != null,
          disabled: _newEmail.isEmpty,
          onChanged: (String v) {
            setState(() {
              _newCode = v;
              _errors.remove('newCode');
            });
          },
          onSend: _handleSendNewCode,
        ),
        if (_errors['newCode'] != null) _ErrorText(_errors['newCode']!),
        const SizedBox(height: 20), // space-y-5
        _PrimaryButton(
          label: _submitting ? '提交中...' : '确认换绑',
          enabled: !_submitting,
          submitting: _submitting,
          onTap: _handleSubmitNewCode,
        ),
      ],
    );
  }
}

/// 表单字段标签（text-xs text-gray-500 mb-2）。
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(fontSize: 12, color: kGray500)); // text-xs
  }
}

/// 字段错误提示（mt-2 text-xs text-red-500）。
class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8), // mt-2
      child: Text(text,
          style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444))), // red-500
    );
  }
}

/// 圆角输入框（h-12 px-4 bg-white border rounded-xl；
/// 错误 border-red-400 / 聚焦 border-blue-400 / 默认 border-gray-200；
/// disabled：bg-gray-50 text-gray-400）。
class _PortenTextField extends StatefulWidget {
  const _PortenTextField({
    required this.value,
    required this.onChanged,
    required this.placeholder,
    this.error = false,
    this.enabled = true,
    this.maxLength,
    this.keyboardType,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String placeholder;
  final bool error;
  final bool enabled;
  final int? maxLength;
  final TextInputType? keyboardType;

  @override
  State<_PortenTextField> createState() => _PortenTextFieldState();
}

class _PortenTextFieldState extends State<_PortenTextField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value);
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (mounted) setState(() => _focused = _focusNode.hasFocus);
  }

  @override
  void didUpdateWidget(covariant _PortenTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != _controller.text) {
      _controller.text = widget.value;
      _controller.selection =
          TextSelection.collapsed(offset: _controller.text.length);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color borderColor;
    if (widget.error) {
      borderColor = const Color(0xFFF87171); // red-400
    } else if (_focused) {
      borderColor = const Color(0xFF60A5FA); // blue-400
    } else {
      borderColor = kGray200; // gray-200
    }
    return Container(
      height: 48, // h-12
      padding: const EdgeInsets.symmetric(horizontal: 16), // px-4
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: widget.enabled ? Colors.white : const Color(0xFFF9FAFB), // bg-gray-50
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(12), // rounded-xl
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        enabled: widget.enabled,
        maxLength: widget.maxLength,
        keyboardType: widget.keyboardType,
        textInputAction: TextInputAction.next,
        style: TextStyle(
          fontSize: 16, // text-base
          color: widget.enabled ? kGray900 : kGray400,
        ),
        cursorColor: const Color(0xFF3B82F6), // blue-500
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          counterText: '', // 隐藏 maxLength 计数
          hintText: widget.placeholder,
          hintStyle: const TextStyle(
              fontSize: 16, color: kGray300), // placeholder:text-gray-300
        ),
        onChanged: widget.onChanged,
      ),
    );
  }
}

/// 验证码输入行（整体 h-12 圆角容器：输入框 flex-1 + 右侧发送按钮
/// border-l；disabled：gray-300 border-gray-100；可用：blue-500
/// border-gray-100 active:bg-gray-50）。
class _CodeInputRow extends StatefulWidget {
  const _CodeInputRow({
    required this.value,
    required this.onChanged,
    required this.countdown,
    required this.sending,
    required this.onSend,
    this.error = false,
    this.disabled = false,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final int countdown;
  final bool sending;
  final bool error;
  final bool disabled;
  final VoidCallback onSend;

  @override
  State<_CodeInputRow> createState() => _CodeInputRowState();
}

class _CodeInputRowState extends State<_CodeInputRow> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value);
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;
  bool _sendPressed = false;

  bool get _sendDisabled =>
      widget.sending || widget.countdown > 0 || widget.disabled;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (mounted) setState(() => _focused = _focusNode.hasFocus);
  }

  @override
  void didUpdateWidget(covariant _CodeInputRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != _controller.text) {
      _controller.text = widget.value;
      _controller.selection =
          TextSelection.collapsed(offset: _controller.text.length);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color borderColor;
    if (widget.error) {
      borderColor = const Color(0xFFF87171); // red-400
    } else if (_focused) {
      borderColor = const Color(0xFF60A5FA); // blue-400（focus-within）
    } else {
      borderColor = kGray200; // gray-200
    }
    final String sendLabel = widget.sending
        ? '发送中'
        : widget.countdown > 0
            ? '${widget.countdown}s'
            : '获取验证码';
    return Container(
      height: 48, // h-12
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(12), // rounded-xl
      ),
      clipBehavior: Clip.antiAlias, // overflow-hidden
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              maxLength: 8,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              textInputAction: TextInputAction.next,
              style: const TextStyle(fontSize: 16, color: kGray900),
              cursorColor: const Color(0xFF3B82F6), // blue-500
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                counterText: '',
                contentPadding: EdgeInsets.symmetric(horizontal: 16), // px-4
                hintText: '请输入验证码',
                hintStyle: TextStyle(fontSize: 16, color: kGray300),
              ),
              onChanged: widget.onChanged,
            ),
          ),
          // 发送按钮（h-full px-4 text-sm font-medium border-l）
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: _sendDisabled
                ? null
                : (_) => setState(() => _sendPressed = true),
            onTapUp: _sendDisabled
                ? null
                : (_) => setState(() => _sendPressed = false),
            onTapCancel: _sendDisabled
                ? null
                : () => setState(() => _sendPressed = false),
            onTap: _sendDisabled ? null : widget.onSend,
            child: _SendButtonLabel(
              label: sendLabel,
              disabled: _sendDisabled,
              pressed: _sendPressed,
            ),
          ),
        ],
      ),
    );
  }
}

/// 发送按钮内容（含 active:bg-gray-50 按压反馈，按压态由父级驱动）。
class _SendButtonLabel extends StatelessWidget {
  const _SendButtonLabel({
    required this.label,
    required this.disabled,
    required this.pressed,
  });

  final String label;
  final bool disabled;
  final bool pressed;

  @override
  Widget build(BuildContext context) {
    final bool showPressed = pressed && !disabled;
    return Container(
      height: 48, // h-full（父容器 h-12）
      padding: const EdgeInsets.symmetric(horizontal: 16), // px-4
      decoration: BoxDecoration(
        color: showPressed ? const Color(0xFFF9FAFB) : Colors.transparent, // active:bg-gray-50
        border: const Border(
          left: BorderSide(color: Color(0xFFF3F4F6)), // border-gray-100
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14, // text-sm
          fontWeight: FontWeight.w500, // font-medium
          color: disabled
              ? kGray300 // gray-300
              : const Color(0xFF3B82F6), // blue-500
        ),
      ),
    );
  }
}

/// 主按钮（w-full h-12 rounded-full text-base font-medium；
/// 可用 bg-blue-500 active:bg-blue-600；默认禁用 bg-gray-200 text-gray-400；
/// submitting 态 bg-blue-300 text-white/80）。
class _PrimaryButton extends StatefulWidget {
  const _PrimaryButton({
    required this.label,
    required this.enabled,
    required this.onTap,
    this.submitting = false,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final bool submitting;

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor;
    final Color textColor;
    if (!widget.enabled) {
      backgroundColor =
          widget.submitting ? const Color(0xFF93C5FD) : const Color(0xFFE5E7EB); // blue-300 / gray-200
      textColor = widget.submitting
          ? Colors.white.withValues(alpha: 0.8) // text-white/80
          : kGray400;
    } else {
      backgroundColor =
          _pressed ? const Color(0xFF2563EB) : const Color(0xFF3B82F6); // active:bg-blue-600
      textColor = Colors.white;
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.enabled
          ? (_) => setState(() => _pressed = true)
          : null,
      onTapUp: widget.enabled
          ? (_) => setState(() => _pressed = false)
          : null,
      onTapCancel: widget.enabled
          ? () => setState(() => _pressed = false)
          : null,
      onTap: widget.enabled ? widget.onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150), // transition-colors
        height: 48, // h-12
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(999), // rounded-full
        ),
        child: Text(
          widget.label,
          style: TextStyle(
            fontSize: 16, // text-base
            fontWeight: FontWeight.w500, // font-medium
            color: textColor,
          ),
        ),
      ),
    );
  }
}

/// SystemToast 页内局部移植（对齐 Web components/SystemToast.tsx）：
/// 居中深色卡（bg-black/70 rounded-[9px] min-w-[120px] px-6 py-5 gap-3），
/// Loader2 旋转 / X / Check（w-7 h-7）+ text-sm font-medium 白字；
/// 300ms 淡入 + scale 90→100；不可见时 pointer-events-none。
class _SystemToast extends StatefulWidget {
  const _SystemToast({
    required this.visible,
    required this.type,
    required this.text,
  });

  final bool visible;
  final _ToastType type;
  final String text;

  @override
  State<_SystemToast> createState() => _SystemToastState();
}

class _SystemToastState extends State<_SystemToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinController =
      AnimationController(vsync: this, duration: const Duration(seconds: 1)); // animate-spin

  /// 仅 loading 可见时旋转（避免空闲期持续动画）。
  bool get _shouldSpin => widget.visible && widget.type == _ToastType.loading;

  @override
  void initState() {
    super.initState();
    if (_shouldSpin) _spinController.repeat();
  }

  @override
  void didUpdateWidget(covariant _SystemToast oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_shouldSpin && !_spinController.isAnimating) _spinController.repeat();
    if (!_shouldSpin && _spinController.isAnimating) _spinController.stop();
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !widget.visible, // pointer-events-none
        child: AnimatedOpacity(
          opacity: widget.visible ? 1 : 0, // transition-opacity duration-300
          duration: const Duration(milliseconds: 300),
          child: Center(
            child: AnimatedScale(
              scale: widget.visible ? 1 : 0.9, // scale-90 → scale-100
              duration: const Duration(milliseconds: 300),
              child: Container(
                constraints: const BoxConstraints(minWidth: 120), // min-w-[120px]
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20), // px-6 py-5
                decoration: BoxDecoration(
                  color: const Color(0xB3000000), // bg-black/70
                  borderRadius: BorderRadius.circular(9), // rounded-[9px]
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _buildIcon(),
                    const SizedBox(height: 12), // gap-3
                    Text(
                      widget.text,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14, // text-sm
                        fontWeight: FontWeight.w500, // font-medium
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    switch (widget.type) {
      case _ToastType.loading:
        return RotationTransition(
          turns: _spinController,
          child: const PortenLucideIcon('loader-2',
              size: 28, color: Colors.white, strokeWidth: 1.5), // w-7 h-7
        );
      case _ToastType.error:
        return const PortenLucideIcon('x',
            size: 28, color: Colors.white, strokeWidth: 2);
      case _ToastType.success:
        return const PortenLucideIcon('check',
            size: 28, color: Colors.white, strokeWidth: 2);
    }
  }
}
