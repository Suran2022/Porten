/*
 * Flutter 应用根组件。
 *
 * 职责：
 *   1. 装配 PortenTheme（禁用水波纹 + 缩放密度 + 品牌配色）；
 *   2. 下发 PortenScale（等比缩放系数）；
 *   3. 认证状态机：Splash（3000ms，对齐 Web 端 .spinner 停留）→
 *      AuthSlider（登录/注册横滑）→ Home 占位（已登录）。
 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/components/gradient_logo.dart';
import 'core/components/porten_toast.dart';
import 'core/design/porten_colors.dart';
import 'core/design/porten_theme.dart';
import 'core/design/porten_typography.dart';
import 'features/auth/auth_slider.dart';
import 'features/auth/login_page.dart';
import 'features/auth/register_page.dart';
import 'features/auth/state/auth_controller.dart';

/// 应用启动阶段。
enum AppStage { splash, auth, home }

/// Porten Flutter 应用根 Widget。
class PortenApp extends StatelessWidget {
  const PortenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return PortenTheme(
      child: MaterialApp(
        title: 'Porten',
        debugShowCheckedModeBanner: false,
        home: const _PortenFlowPage(),
        builder: (BuildContext context, Widget? child) {
          // 挂载全局 Toast Overlay，使 PortenToast 脱离 Navigator 可用。
          return Stack(
            children: <Widget>[
              child ?? const SizedBox.shrink(),
              Overlay(key: PortenToast.overlayKey),
            ],
          );
        },
      ),
    );
  }
}

class _PortenFlowPage extends ConsumerStatefulWidget {
  const _PortenFlowPage();

  @override
  ConsumerState<_PortenFlowPage> createState() => _PortenFlowPageState();
}

class _PortenFlowPageState extends ConsumerState<_PortenFlowPage> {
  AppStage _stage = AppStage.splash;
  final GlobalKey<AuthSliderState> _authSliderKey =
      GlobalKey<AuthSliderState>();

  @override
  void initState() {
    super.initState();
    _startSplash();
  }

  /// 开屏 3000ms 后进入认证滑块（对齐 Web 端 splash 定时跳转）。
  Future<void> _startSplash() async {
    await Future<void>.delayed(const Duration(milliseconds: 3000));
    if (!mounted) return;
    setState(() => _stage = AppStage.auth);
  }

  @override
  Widget build(BuildContext context) {
    final AuthSession? session = ref.watch(authProvider).session;

    // Mock 登录/注册成功后统一进入 Home。
    if (session != null && _stage != AppStage.home) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _stage = AppStage.home);
      });
    }

    switch (_stage) {
      case AppStage.splash:
        return const _SplashPage();
      case AppStage.auth:
        return AuthSlider(
          key: _authSliderKey,
          loginPage: LoginPage(
            onGoRegister: _authSliderKey.currentState?.goToRegister ??
                () {},
            onLoginSuccess: () {},
          ),
          registerPage: RegisterPage(
            onGoLogin: _authSliderKey.currentState?.goToLogin ?? () {},
            onRegisterSuccess: () {},
          ),
        );
      case AppStage.home:
        return const _HomePage();
    }
  }
}

/// 开屏页：流光 Logo + 底部 spinner（对齐 Web 端开屏）。
class _SplashPage extends StatelessWidget {
  const _SplashPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PortenColor.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const SizedBox(width: 220, child: GradientLogo(fontSize: 56)),
            const SizedBox(height: 48),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(PortenColor.brandBlue),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 已登录首页占位（后续迭代接入会话/消息/行程等业务域）。
class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PortenColor.white,
      body: Center(
        child: Text('Porten', style: PortenTypography.x3l),
      ),
    );
  }
}
