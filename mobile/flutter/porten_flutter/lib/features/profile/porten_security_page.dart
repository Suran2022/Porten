/*
 * Porten 安全中心（100% 移植 Web 端 components/profile/PortenSecurityPage.tsx）。
 *
 * 结构：bg-[#f7f7f7]；顶栏白底（BackIcon w-7 + 「Porten安全中心」居中 +
 *   「反馈进度」no-op 占位）；内容 pt-16 pb-8 居中：盾牌光晕区
 *   （w-20 h-20：bg-blue-400/20 ping + bg-blue-400/30 pulse +
 *   ShieldCheck w-12 h-12 blue-500 strokeWidth 1.5）+
 *   「账号安全 由 Porten 守护」text-sm gray-500；
 * 7 个选项行 px-4 py-4 bg-white（text-base gray-900 + chevron-right
 *   w-4 gray-400 strokeWidth 1.5），仅 bound_email 有业务：
 *   脱敏邮箱弹窗 → 365 天冷却弹窗 → push 换绑邮箱流程页。
 */

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/components/porten_back_icon.dart';
import '../../core/components/porten_lucide_icons.dart';
import '../../core/components/porten_page_transitions.dart';
import '../auth/state/auth_controller.dart';
import 'bound_email_dialog.dart';
import 'change_email_cooldown_dialog.dart';
import 'change_email_page.dart';
import 'profile_page.dart' show kGray900, kGray500, kGray400, kGray50;

/// Mock 阶段兜底邮箱：会话 identifier 非邮箱（如手机号登录）时使用，
/// 保证安全中心演示链路始终可用（对齐 Web 端 user.email 有值的场景）。
const String _kFallbackEmail = 'user@example.com';

class PortenSecurityPage extends ConsumerStatefulWidget {
  const PortenSecurityPage({super.key});

  @override
  ConsumerState<PortenSecurityPage> createState() => _PortenSecurityPageState();
}

class _PortenSecurityPageState extends ConsumerState<PortenSecurityPage> {
  bool _boundEmailDialog = false;
  bool _cooldownDialog = false;
  String _currentEmail = '';

  /// 安全选项（顺序与文案对齐 Web securityOptions）。
  static const List<List<String>> _securityOptions = <List<String>>[
    <String>['bound_email', '绑定的邮箱'],
    <String>['change_password', '修改登录密码'],
    <String>['device_management', '设备管理'],
    <String>['violation', '违规相关'],
    <String>['history_query', '历史查询'],
    <String>['emergency_freeze', '安全紧急冻结'],
    <String>['security_settings', '账号安全设置'],
  ];

  @override
  void initState() {
    super.initState();
    // Web 端取 user.email；Mock 阶段 AuthSession 无 email 字段，
    // 邮箱登录时 identifier 即邮箱，否则用兜底常量。
    final String identifier = ref.read(authProvider).session?.identifier ?? '';
    _currentEmail = identifier.contains('@') ? identifier : _kFallbackEmail;
  }

  /// 点击「绑定的邮箱」：直接弹出脱敏邮箱弹窗（空邮箱时无反应）。
  void _handleBoundEmailClick() {
    if (_currentEmail.isEmpty) return;
    setState(() => _boundEmailDialog = true);
  }

  /// 弹窗「换绑邮箱」：先弹出 365 天冷却提示。
  void _handleRequestChange() {
    setState(() => _boundEmailDialog = false);
    setState(() => _cooldownDialog = true);
  }

  /// 冷却提示「继续换绑」：打开换绑流程（push 右滑入页面）。
  Future<void> _handleContinueChange() async {
    setState(() => _cooldownDialog = false);
    final String? newEmail = await Navigator.of(context).push<String>(
      PortenSlideFromRightRoute<String>(
        builder: (_) => ChangeEmailPage(currentEmail: _currentEmail),
      ),
    );
    if (!mounted || newEmail == null || newEmail.isEmpty) return;
    // 换绑成功：更新本地当前邮箱（对齐 Web handleChangeSuccess）。
    setState(() => _currentEmail = newEmail);
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
                // 顶栏（白底，BackIcon + 居中标题 + 反馈进度占位）
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
                          child: Text('Porten安全中心',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: kGray900)),
                        ),
                        const _FeedbackProgressButton(),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: <Widget>[
                        // 盾牌光晕区（pt-16 pb-8 居中）
                        const Padding(
                          padding: EdgeInsets.only(top: 64, bottom: 32),
                          child: Column(
                            children: <Widget>[
                              _ShieldGlow(),
                              SizedBox(height: 16), // mt-4
                              Text('账号安全 由 Porten 守护',
                                  style: TextStyle(
                                      fontSize: 14, color: kGray500)),
                            ],
                          ),
                        ),
                        // 安全选项列表
                        Column(
                          children: _securityOptions
                              .map((List<String> opt) => _SecurityOptionRow(
                                    id: opt[0],
                                    label: opt[1],
                                    onTap: opt[0] == 'bound_email'
                                        ? _handleBoundEmailClick
                                        : () {}, // 其余项仅按压反馈（对齐 Web onClick undefined）
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // 弹窗：绑定的邮箱（脱敏展示）
            BoundEmailDialog(
              visible: _boundEmailDialog,
              email: _currentEmail,
              onClose: () => setState(() => _boundEmailDialog = false),
              onChangeEmail: _handleRequestChange,
            ),
            // 弹窗：365 天换绑冷却提示
            ChangeEmailCooldownDialog(
              visible: _cooldownDialog,
              onClose: () => setState(() => _cooldownDialog = false),
              onContinue: _handleContinueChange,
            ),
          ],
        ),
      ),
    );
  }
}

/// 「反馈进度」占位按钮（对齐 Web：-mr-2 px-2 py-1 text-sm gray-500
/// active:text-gray-700，仅点击区域无业务）。
class _FeedbackProgressButton extends StatefulWidget {
  const _FeedbackProgressButton();

  @override
  State<_FeedbackProgressButton> createState() => _FeedbackProgressButtonState();
}

class _FeedbackProgressButtonState extends State<_FeedbackProgressButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {}, // 无业务
      // -mr-2：Container margin 不支持负值，用 Transform 位移等价实现
      child: Transform.translate(
        offset: const Offset(8, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // px-2 py-1
          child: Text(
            '反馈进度',
            style: TextStyle(
              fontSize: 14, // text-sm
              color: _pressed ? kGray700Pressed : kGray500,
            ),
          ),
        ),
      ),
    );
  }
}

/// active:text-gray-700。
const Color kGray700Pressed = Color(0xFF374151);

/// 安全选项行（px-4 py-4 bg-white + active:bg-gray-50/50 按压反馈）。
class _SecurityOptionRow extends StatefulWidget {
  const _SecurityOptionRow({required this.id, required this.label, required this.onTap});

  final String id;
  final String label;
  final VoidCallback onTap;

  @override
  State<_SecurityOptionRow> createState() => _SecurityOptionRowState();
}

class _SecurityOptionRowState extends State<_SecurityOptionRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: Container(
        width: double.infinity,
        color: _pressed ? kGray50.withValues(alpha: 0.5) : Colors.white, // active:bg-gray-50/50
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), // px-4 py-4
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(widget.label,
                style: const TextStyle(fontSize: 16, color: kGray900)), // text-base
            const PortenLucideIcon('chevron-right',
                size: 16, color: kGray400, strokeWidth: 1.5),
          ],
        ),
      ),
    );
  }
}

/// 盾牌光晕区（w-20 h-20，三层结构对齐 Web）：
///   外层 bg-blue-400/20 animate-ping（1s，scale 1→2 + opacity→0）；
///   中层 bg-blue-400/30 animate-pulse（2s，opacity 0.3↔0.15）；
///   内层 ShieldCheck w-12 h-12 blue-500 strokeWidth 1.5。
class _ShieldGlow extends StatefulWidget {
  const _ShieldGlow();

  @override
  State<_ShieldGlow> createState() => _ShieldGlowState();
}

class _ShieldGlowState extends State<_ShieldGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // pulse 周期 2s（ping 归一化到同一周期）
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80, // w-20
      height: 80, // h-20
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          final double t = _controller.value; // 0~1，周期 2s
          // animate-ping：1s 周期，前 0.75 比例推进 scale/opacity，其余时间不可见
          final double pingT = (t * 2) % 1.0; // 0~1
          final double pingProgress =
              pingT <= 0.75 ? Curves.easeOut.transform(pingT / 0.75) : 1.0;
          final double pingScale = 1 + pingProgress; // scale(2)
          final double pingOpacity = 0.2 * (1 - pingProgress); // →0
          // animate-pulse：2s 周期，opacity 1→.5→1（基准 0.3）
          final double pulsePhase =
              0.5 - 0.5 * math.cos(t * 2 * math.pi); // 0→1→0
          final double pulseOpacity = 0.3 * (1 - 0.5 * pulsePhase);
          return Stack(
            alignment: Alignment.center,
            children: <Widget>[
              // 外层波动光晕（ping）
              Opacity(
                opacity: pingOpacity,
                child: Transform.scale(
                  scale: pingScale,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: Color(0x3393C5FD), // blue-400/20
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              // 中层呼吸光晕（pulse）
              Opacity(
                opacity: pulseOpacity,
                child: Container(
                  width: 64, // inset-2（80-8*2）
                  height: 64,
                  decoration: const BoxDecoration(
                    color: Color(0x4D93C5FD), // blue-400/30
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              // 盾牌图标
              const PortenLucideIcon('shield-check',
                  size: 48, color: Color(0xFF3B82F6), strokeWidth: 1.5),
            ],
          );
        },
      ),
    );
  }
}
