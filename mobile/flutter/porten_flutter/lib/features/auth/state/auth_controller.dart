/*
 * 认证状态控制器（对齐 Web 端 authStore + LoginPage/RegisterPage 交互逻辑）。
 *
 * 职责：
 *   1. 登录方式（email/phone/porten）与 密码/验证码 模式管理；
 *   2. 验证码 60s 倒计时（页面销毁即停止，无泄漏）；
 *   3. Mock 登录/注册（对齐 Web 端 loginAsMock / mockEngine 认证路由）；
 *   4. 协议勾选前置校验（未勾选时 toast「请先同意相关协议」由页面触发）。
 *
 * 防御性设计：所有异步操作带 loading 态与 try/catch，异常统一转 Toast 文案，
 * 绝不把裸异常抛进 UI 层。
 */

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/components/login_method_sheet.dart' show LoginMethod;
import '../../../core/components/porten_toast.dart';

/// 登录凭证类型。
enum LoginCredentialType { email, phone }

/// 认证会话（Mock 阶段）。
class AuthSession {
  const AuthSession({required this.uid, required this.identifier, required this.nickname});

  final String uid;
  final String identifier;
  final String nickname;
}

/// 认证页面状态。
class AuthState {
  const AuthState({
    this.method = LoginMethod.email,
    this.isPasswordMode = true,
    this.countdown = 0,
    this.isLoading = false,
    this.session,
  });

  final LoginMethod method;

  /// true = 密码模式；false = 验证码模式。
  final bool isPasswordMode;

  /// 验证码重发倒计时（秒），0 表示可发送。
  final int countdown;
  final bool isLoading;
  final AuthSession? session;

  AuthState copyWith({
    LoginMethod? method,
    bool? isPasswordMode,
    int? countdown,
    bool? isLoading,
    AuthSession? session,
    bool clearSession = false,
  }) {
    return AuthState(
      method: method ?? this.method,
      isPasswordMode: isPasswordMode ?? this.isPasswordMode,
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
    final RegExp regex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return regex.hasMatch(value);
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

  /// 发送验证码：启动 60s 倒计时（对齐 Web 端 sendVerificationCode）。
  /// 返回是否成功触发（倒计时进行中会拒绝重复发送）。
  bool sendCode() {
    if (state.countdown > 0) return false;
    state = state.copyWith(countdown: 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (state.countdown <= 1) {
        _stopTimer();
        state = state.copyWith(countdown: 0);
      } else {
        state = state.copyWith(countdown: state.countdown - 1);
      }
    });
    return true;
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  // ------------------------------ Mock 登录 ------------------------------

  /// Mock 登录：任意格式合法凭证 + 任意密码/验证码均可通过（对齐 Web 端 loginAsMock）。
  Future<bool> loginMock({
    required LoginCredentialType type,
    required String identifier,
  }) async {
    if (state.isLoading) return false;
    state = state.copyWith(isLoading: true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      state = state.copyWith(
        isLoading: false,
        session: AuthSession(
          uid: 'mock-${identifier.hashCode.abs()}',
          identifier: identifier,
          nickname: 'Porten 用户',
        ),
      );
      return true;
    } on Exception catch (_) {
      state = state.copyWith(isLoading: false);
      PortenToast.show('登录失败，请稍后重试');
      return false;
    }
  }

  /// Mock 注册：两步流程的第二步（验证码提交后创建会话）。
  Future<bool> registerMock({required String identifier}) async {
    if (state.isLoading) return false;
    state = state.copyWith(isLoading: true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      state = state.copyWith(
        isLoading: false,
        session: AuthSession(
          uid: 'mock-${identifier.hashCode.abs()}',
          identifier: identifier,
          nickname: 'Porten 新成员',
        ),
      );
      return true;
    } on Exception catch (_) {
      state = state.copyWith(isLoading: false);
      PortenToast.show('注册失败，请稍后重试');
      return false;
    }
  }

  /// 退出登录（占位：本轮仅清空会话）。
  void signOut() {
    _stopTimer();
    state = state.copyWith(
      countdown: 0,
      isLoading: false,
      clearSession: true,
    );
  }
}

/// 全局认证 Provider。
final NotifierProvider<AuthController, AuthState> authProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
