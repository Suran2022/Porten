/*
 * 认证状态控制器（对齐 Web 端 authStore + LoginPage/RegisterPage 交互逻辑）。
 *
 * 职责：
 *   1. 登录方式（email/phone/porten）与 密码/验证码 模式管理；
 *   2. 验证码发送（Live 走后端邮件通道；Mock 800ms 耗时）+ 60s 倒计时；
 *   3. 登录 / 注册按 mockModeProvider 分流：mock → 端内假会话（loginAsMock
 *      语义，任意合法凭证放行）；live → porten/data 桥下沉原生 AuthRepository
 *      打真实后端，token 由原生写入安全存储（Flutter 侧不持有明文 token）；
 *   4. 协议勾选前置校验文案由页面触发（「请先同意相关协议」）。
 *
 * 防御性设计：所有异步操作带 loading 态与异常兜底，不把裸异常抛进 UI 层；
 * Live 通道失败透出后端 message，不静默放行（假会话混入生产是安全事故）。
 */

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/bridge/porten_channels.dart' show PortenBridgeException;
import '../../../core/bridge/porten_data_bridge.dart';
import '../../../core/components/login_method_sheet.dart' show LoginMethod;
import '../../../core/components/porten_toast.dart';
import '../../../core/mock/mock_mode.dart';

/// 登录凭证类型。
enum LoginCredentialType { email, phone }

/// 认证会话。
class AuthSession {
  const AuthSession({
    required this.uid,
    required this.identifier,
    required this.nickname,
    this.portenId,
    this.avatarUrl,
  });

  final String uid;
  final String identifier;
  final String nickname;

  /// Porten ID（live 登录后端返回；mock 会话为 null）。
  final String? portenId;

  /// 头像地址（live 登录后端返回；mock 会话为 null）。
  final String? avatarUrl;
}

/// 认证页面状态。
class AuthState {
  const AuthState({
    this.method = LoginMethod.email,
    this.isPasswordMode = true,
    this.codeSent = false,
    this.countdown = 0,
    this.isLoading = false,
    this.session,
  });

  final LoginMethod method;

  /// true = 密码模式；false = 验证码模式。
  final bool isPasswordMode;

  /// 验证码是否已发送（对齐 Web 端 isCodeSent）。
  final bool codeSent;

  /// 验证码重发倒计时（秒），0 表示可发送。
  final int countdown;
  final bool isLoading;
  final AuthSession? session;

  AuthState copyWith({
    LoginMethod? method,
    bool? isPasswordMode,
    bool? codeSent,
    int? countdown,
    bool? isLoading,
    AuthSession? session,
    bool clearSession = false,
  }) {
    return AuthState(
      method: method ?? this.method,
      isPasswordMode: isPasswordMode ?? this.isPasswordMode,
      codeSent: codeSent ?? this.codeSent,
      countdown: countdown ?? this.countdown,
      isLoading: isLoading ?? this.isLoading,
      session: clearSession ? null : (session ?? this.session),
    );
  }
}

/// 认证控制器。
class AuthController extends Notifier<AuthState> {
  Timer? _timer;

  @override
  AuthState build() {
    ref.onDispose(_stopTimer);
    return const AuthState();
  }

  // ------------------------------ 输入校验（对齐 Web 端正则） ------------------------------

  /// 邮箱格式（对齐 Web 端 EMAIL_REGEX）。
  static bool isValidEmail(String value) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
  }
  /// 手机号格式（大陆 11 位）。
  static bool isValidPhone(String value) {
    return RegExp(r'^1\d{10}$').hasMatch(value);
  }

  /// 密码校验：返回错误文案，null 表示通过（对齐 Web 端 RegisterPage 规则）。
  static String? validatePassword(String password) {
    if (password.length < 8) return '密码长度不能少于 8 位';
    if (!RegExp(r'[A-Za-z]').hasMatch(password) ||
        !RegExp(r'\d').hasMatch(password)) {
      return '密码需同时包含字母和数字';
    }
    return null;
  }

  // ------------------------------ 状态变更 ------------------------------

  /// 切换登录方式（拖拽面板选中）。
  void setMethod(LoginMethod method) {
    state = state.copyWith(method: method);
  }

  /// 切换密码/验证码模式。
  void togglePasswordMode() {
    state = state.copyWith(isPasswordMode: !state.isPasswordMode);
  }

  /// 发送验证码：Mock 800ms 耗时 + 60s 倒计时（对齐 Web 端 sendCode）；
  /// Live 走后端邮件通道（后端限流 429 等错误透出 message）。
  ///
  /// [email] 收件邮箱（live 模式必填且须为合法邮箱）；
  /// [purpose] 用途：login / register / reset_password。
  ///
  /// 注意：Web 端倒计时是各页面自己的局部 state，互不影响；
  /// Flutter 端 countdown 在共享 provider 里，若在这里用
  /// `countdown > 0` 拦截，登录页发过的倒计时会误伤注册页发送
  /// （r8 回归：「发送验证码失败」），故此处仅拦截 isLoading 防连点。
  Future<bool> sendCode({
    String email = '',
    String purpose = 'login',
  }) async {
    if (state.isLoading) return false;
    final bool isMock = _isMock;
    if (!isMock) {
      if (!isValidEmail(email)) {
        PortenToast.show('请输入正确的邮箱地址', icon: ToastIcon.error);
        return false;
      }
    }
    _stopTimer();
    state = state.copyWith(isLoading: true);
    try {
      if (isMock) {
        await Future<void>.delayed(const Duration(milliseconds: 800));
      } else {
        await PortenDataBridge.sendVerificationCode(
          email: email,
          purpose: purpose,
        );
      }
      state = state.copyWith(isLoading: false, codeSent: true, countdown: 60);
      _startCountdown();
      return true;
    } catch (e) {
      // 全捕（含 Error）：桥接链路任何类型异常都不能让 isLoading 卡死，
      // 否则按钮永久转圈（现场反馈「输入验证码转半天没反应」）。
      state = state.copyWith(isLoading: false);
      PortenToast.show(_messageOf(e, fallback: '发送失败，请稍后重试'));
      return false;
    } finally {
      if (state.isLoading) state = state.copyWith(isLoading: false);
    }
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (state.countdown <= 1) {
        _stopTimer();
        state = state.copyWith(countdown: 0);
      } else {
        state = state.copyWith(countdown: state.countdown - 1);
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  /// 切换方式/模式时清空输入相关状态（对齐 Web 端 useEffect 重置）。
  void resetInputState() {
    _stopTimer();
    state = state.copyWith(codeSent: false, countdown: 0, isLoading: false);
  }

  // ------------------------------ 登录 / 注册（mock / live 双通道） ------------------------------

  bool get _isMock => ref.read(mockModeProvider) == PortenMockMode.mock;

  /// 登录（mock：任意合法凭证放行；live：打真实后端，token 由原生落盘）。
  ///
  /// [type] 凭证类型；[identifier] 邮箱（live 仅支持邮箱）；
  /// [password] 密码模式凭证；[verificationCode] 验证码模式凭证。
  Future<bool> login({
    required LoginCredentialType type,
    required String identifier,
    String? password,
    String? verificationCode,
  }) async {
    if (state.isLoading) return false;
    state = state.copyWith(isLoading: true);
    try {
      final AuthSession session = _isMock
          ? await _loginMock(type: type, identifier: identifier)
          : await _loginLive(
              type: type,
              identifier: identifier,
              password: password,
              verificationCode: verificationCode,
            );
      state = state.copyWith(isLoading: false, session: session);
      return true;
    } catch (e) {
      // 全捕（含 Error）+ finally 兜底：isLoading 绝不卡死。
      state = state.copyWith(isLoading: false);
      PortenToast.show(_messageOf(e, fallback: '登录失败，请稍后重试'));
      return false;
    } finally {
      if (state.isLoading) state = state.copyWith(isLoading: false);
    }
  }

  /// Mock 登录：任意格式合法凭证 + 任意密码/验证码均可通过（对齐 Web 端 loginAsMock）。
  Future<AuthSession> _loginMock({
    required LoginCredentialType type,
    required String identifier,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return AuthSession(
      uid: 'mock-${identifier.hashCode.abs()}',
      identifier: identifier,
      nickname: 'Porten 用户',
    );
  }

  /// Live 登录：邮箱 + 密码 / 邮箱 + 验证码打真实后端。
  Future<AuthSession> _loginLive({
    required LoginCredentialType type,
    required String identifier,
    String? password,
    String? verificationCode,
  }) async {
    if (type != LoginCredentialType.email) {
      throw Exception('请使用邮箱登录');
    }
    final Map<String, Object?> result = (password != null && password.isNotEmpty)
        ? await PortenDataBridge.loginPassword(email: identifier, password: password)
        : await PortenDataBridge.loginEmailCode(
            email: identifier,
            verificationCode: verificationCode ?? '',
          );
    return _sessionFromApi(result);
  }

  /// 注册（mock：验证码提交后创建会话；live：打真实后端，token 由原生落盘）。
  Future<bool> register({
    required String email,
    required String password,
    required String confirmPassword,
    required String verificationCode,
  }) async {
    if (state.isLoading) return false;
    state = state.copyWith(isLoading: true);
    try {
      final AuthSession session = _isMock
          ? await _registerMock(identifier: email)
          : _sessionFromApi(
              await PortenDataBridge.register(
                email: email,
                password: password,
                confirmPassword: confirmPassword,
                verificationCode: verificationCode,
              ),
            );
      state = state.copyWith(isLoading: false, session: session);
      return true;
    } catch (e) {
      // 全捕（含 Error）+ finally 兜底：isLoading 绝不卡死。
      state = state.copyWith(isLoading: false);
      PortenToast.show(_messageOf(e, fallback: '注册失败，请稍后重试'));
      return false;
    } finally {
      if (state.isLoading) state = state.copyWith(isLoading: false);
    }
  }

  /// Mock 注册：验证码提交后创建会话（对齐 Web 端 register）。
  Future<AuthSession> _registerMock({required String identifier}) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    return AuthSession(
      uid: 'mock-${identifier.hashCode.abs()}',
      identifier: identifier,
      nickname: 'Porten 新成员',
    );
  }

  /// 退出登录（live 经桥通知服务端解绑并清除本地 token；mock 仅清会话）。
  void signOut() {
    _stopTimer();
    if (!_isMock) {
      // 防御：登出是显式意图，桥异常不影响本地会话清除
      PortenDataBridge.logout().catchError((Object _) {});
    }
    state = state.copyWith(countdown: 0, isLoading: false, clearSession: true);
  }

  // ------------------------------ 辅助 ------------------------------

  /// 后端登录结果 → 认证会话（token 已由原生侧写入安全存储，此处不持有）。
  AuthSession _sessionFromApi(Map<String, Object?> result) {
    final Map<String, Object?> user =
        (result['user'] as Map<Object?, Object?>?)?.cast<String, Object?>() ??
            const <String, Object?>{};
    return AuthSession(
      uid: '${user['id']}',
      identifier: '${user['email']}',
      nickname: '${user['nickname']}',
      portenId: user['porten_id'] as String?,
      avatarUrl: user['avatar_url'] as String?,
    );
  }

  /// 桥接异常 → 用户可读文案（PortenBridgeException 透出后端 message）。
  String _messageOf(Object error, {required String fallback}) {
    if (error is PortenBridgeException && error.message.isNotEmpty) {
      return error.message;
    }
    return fallback;
  }
}

/// 全局认证 Provider。
final NotifierProvider<AuthController, AuthState> authProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
