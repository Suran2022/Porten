/*
 * Flutter 应用根组件。
 *
 * 职责：
 *   1. 装配 PortenTheme（禁用水波纹 + 缩放密度 + 品牌配色）；
 *   2. 下发 PortenScale（等比缩放系数）；
 *   3. 认证状态机：Splash（3000ms 停留 + 400ms 淡出，对齐 Web 端
 *      SplashScreen.tsx，不允许跳过）→ AuthSlider（登录/注册横滑）→
 *      Home 占位（已登录）。
 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'core/bridge/porten_navigator_key.dart';
import 'core/components/gradient_logo.dart';
import 'core/components/porten_toast.dart';
import 'core/design/porten_colors.dart';
import 'core/design/porten_theme.dart';
import 'core/design/porten_typography.dart';
import 'features/auth/auth_slider.dart';
import 'features/auth/login_page.dart';
import 'features/auth/register_page.dart';
import 'features/auth/state/auth_controller.dart';
import 'features/home/home_view.dart';

/// 应用启动阶段。
enum AppStage { splash, auth, home }

/// 开屏停留时长（对齐 Web 端 SPLASH_DURATION = 3000，不允许跳过）。
const Duration _kSplashDuration = Duration(milliseconds: 3000);

/// 开屏淡出时长（对齐 Web 端 FADE_DURATION = 400）。
const Duration _kFadeDuration = Duration(milliseconds: 400);

/// Porten Flutter 应用根 Widget。
class PortenApp extends StatelessWidget {
  const PortenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return PortenTheme(
      child: MaterialApp(
        title: 'Porten',
        debugShowCheckedModeBanner: false,
        navigatorKey: portenNavigatorKey, // r20：原生返回桥用
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
  bool _splashFadingOut = false;
  final GlobalKey<AuthSliderState> _authSliderKey = GlobalKey<AuthSliderState>();

  @override
  void initState() {
    super.initState();
    _startSplash();
  }

  /// 开屏 3000ms 后淡出 400ms，再进入认证滑块（淡出期间不可点击）。
  Future<void> _startSplash() async {
    await Future<void>.delayed(_kSplashDuration);
    if (!mounted) return;
    setState(() => _splashFadingOut = true);
    await Future<void>.delayed(_kFadeDuration);
    if (!mounted) return;
    setState(() => _stage = AppStage.auth);
  }

  @override
  Widget build(BuildContext context) {
    final AuthSession? session = ref.watch(authProvider).session;

    // r21：退出登录（会话清空）→ 状态机切回认证滑块（对齐 Web logout → /login）。
    if (session == null && _stage == AppStage.home) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _stage = AppStage.auth);
      });
    }

    // Mock 登录/注册成功后统一进入 Home。
    if (session != null &&
        _stage != AppStage.home &&
        _stage != AppStage.splash) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _stage = AppStage.home);
      });
    }

    switch (_stage) {
      case AppStage.splash:
        return _SplashPage(fadingOut: _splashFadingOut);
      case AppStage.auth:
        return AuthSlider(
          key: _authSliderKey,
          loginPage: LoginPage(
            onGoRegister: _authSliderKey.currentState?.goToRegister ?? () {},
            onLoginSuccess: () {},
          ),
          registerPage: RegisterPage(
            onGoLogin: _authSliderKey.currentState?.goToLogin ?? () {},
            onRegisterSuccess: () {},
          ),
        );
      case AppStage.home:
        return const HomeView();
    }
  }
}

/// 开屏页（100% 对齐 Web 端 SplashScreen.tsx）：
///   - 白底全屏、不响应点击（不允许跳过）；
///   - 屏幕正中央显示 splash-icon.svg（w-24 h-24），整体上移 40px
///     （-translate-y-10），入场 0.7s scale 0.72→1 渐现（splash-icon-in）；
///   - 底部（safe-area + 1.75rem）：GradientLogo（text-3xl，splash-fade-up
///     0.6s 延迟 0.15s 上移 14px 渐现）+「静夜思云提供计算服务」
///     （text-xs gray-400，延迟 0.45s）；
///   - 停留 3 秒后 400ms 淡出。
class _SplashPage extends StatefulWidget {
  const _SplashPage({required this.fadingOut});

  final bool fadingOut;

  @override
  State<_SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<_SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: _kFadeDuration,
    value: 1,
  );

  @override
  void didUpdateWidget(_SplashPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.fadingOut && !oldWidget.fadingOut) {
      _fade.reverse(); // opacity 1 → 0
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true, // 全屏覆盖、不响应点击
      child: FadeTransition(
        opacity: _fade,
        child: Scaffold(
          backgroundColor: PortenColor.white,
          body: Stack(
            children: <Widget>[
              // 中央：图标 Logo（外层上移 40px 补偿，保持原视觉中心位置）
              Center(
                child: Transform.translate(
                  offset: const Offset(0, -40), // -translate-y-10
                  child: _SplashIconIn(
                    child: SvgPicture.asset(
                      'assets/icons/splash_icon.svg',
                      width: 96, // w-24 h-24
                      height: 96,
                    ),
                  ),
                ),
              ),
              // 底部：文本 Logo + 服务声明
              Positioned(
                left: 0,
                right: 0,
                bottom: MediaQuery.paddingOf(context).bottom + 28, // +1.75rem
                child: Column(
                  children: <Widget>[
                    // splash-fade-up：0.6s，延迟 0.15s，上移 14px
                    _SplashFadeUp(
                      delay: const Duration(milliseconds: 150),
                      child: const GradientLogo(fontSize: 30), // text-3xl
                    ),
                    // splash-caption：延迟 0.45s
                    _SplashFadeUp(
                      delay: const Duration(milliseconds: 450),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8), // mt-2
                        child: Text(
                          '静夜思云提供计算服务',
                          style: PortenTypography.xs
                              .copyWith(color: PortenColor.gray400),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 图标入场动画：opacity 0→1、scale 0.72→1，0.7s cubic-bezier(0.25,0.1,0.25,1)。
class _SplashIconIn extends StatefulWidget {
  const _SplashIconIn({required this.child});

  final Widget child;

  @override
  State<_SplashIconIn> createState() => _SplashIconInState();
}

class _SplashIconInState extends State<_SplashIconIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  late final Animation<double> _anim = CurvedAnimation(
    parent: _controller,
    curve: const Cubic(0.25, 0.1, 0.25, 1),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.72, end: 1).animate(_anim),
        child: widget.child,
      ),
    );
  }
}

/// 上移渐现动画：opacity 0→1、translateY 14px→0，0.6s ease（带延迟）。
class _SplashFadeUp extends StatefulWidget {
  const _SplashFadeUp({required this.delay, required this.child});

  final Duration delay;
  final Widget child;

  @override
  State<_SplashFadeUp> createState() => _SplashFadeUpState();
}

class _SplashFadeUpState extends State<_SplashFadeUp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 14 / 40),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut)),
        child: widget.child,
      ),
    );
  }
}
