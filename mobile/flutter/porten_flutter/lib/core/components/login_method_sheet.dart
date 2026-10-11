/*
 * 登录方式切换面板（100% 对齐 Web 端 LoginMethodSheet.tsx）。
 *
 * Web 端实现：
 *   - 底部面板 bg-white rounded-t-3xl px-5 pb-8 pt-3 border-t border-gray-100，
 *     sheet-handle 36x4 圆角灰条（可拖拽，下滑超过面板高度 50% 关闭）；
 *   - 遮罩 bg-gray-100/60；
 *   - 三选项按钮：w-full px-4 py-3.5 rounded-2xl，选中 border-gray-200
 *     bg-gray-50/50，未选中 border-gray-100 bg-white；
 *     左侧 w-9 h-9 圆形 bg-gray-100/70 + lucide 图标（Mail/Phone/User，
 *     w-5 h-5 gray-600），文字 text-sm font-medium gray-800；
 *     选中时右侧 w-5 h-5 porten-bg-gradient 圆 + Check w-3 h-3 strokeWidth 3；
 *   - 选项 stagger 入场：translateY(16px) → 0，120ms + index*60ms 延迟。
 */

import 'package:flutter/material.dart';

import '../design/porten_colors.dart';
import '../design/porten_typography.dart';
import 'porten_icons.dart';

/// 登录方式。
enum LoginMethod { email, phone, porten }

/// 登录方式选择面板。
class LoginMethodSheet extends StatefulWidget {
  const LoginMethodSheet({
    super.key,
    required this.value,
    required this.onChange,
    required this.onClose,
  });

  final LoginMethod value;
  final ValueChanged<LoginMethod> onChange;
  final VoidCallback onClose;

  /// 以底部面板形式弹出。
  static Future<void> show(
    BuildContext context, {
    required LoginMethod value,
    required ValueChanged<LoginMethod> onChange,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: PortenColor.gray100.withValues(alpha: 0.6),
      builder: (_) => _SheetBody(value: value, onChange: onChange),
    );
  }

  @override
  State<LoginMethodSheet> createState() => _LoginMethodSheetState();
}

class _LoginMethodSheetState extends State<LoginMethodSheet> {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({required this.value, required this.onChange});

  final LoginMethod value;
  final ValueChanged<LoginMethod> onChange;

  static const List<(LoginMethod, String, String)> _options =
      <(LoginMethod, String, String)>[
    (LoginMethod.email, '邮箱登录', 'mail'),
    (LoginMethod.phone, '手机号登录', 'phone'),
    (LoginMethod.porten, 'Porten 账号登录', 'user'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 32), // px-5 pt-3+handle区 pb-8
        decoration: const BoxDecoration(
          color: PortenColor.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)), // rounded-t-3xl
          border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // 拖拽把手区（含手势，移动端整体面板可拖拽由 showModalBottomSheet 自带）
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 8, bottom: 16),
              decoration: BoxDecoration(
                color: PortenColor.gray300.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // space-y-3
            for (int i = 0; i < _options.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: 12),
              _StaggerIn(
                delay: Duration(milliseconds: 120 + i * 60),
                child: _OptionRow(
                  method: _options[i].$1,
                  label: _options[i].$2,
                  icon: _options[i].$3,
                  selected: _options[i].$1 == value,
                  onTap: () {
                    onChange(_options[i].$1);
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 单个选项行。
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.method,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final LoginMethod method;
  final String label;
  final String icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? PortenColor.gray50.withValues(alpha: 0.5) // bg-gray-50/50
          : PortenColor.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16), // rounded-2xl
        side: BorderSide(
          color: selected ? PortenColor.gray200 : PortenColor.gray100,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), // px-4 py-3.5
          child: Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: PortenColor.gray100.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: LucideIcon(icon, size: 20, color: PortenColor.gray600),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: PortenTypography.sm.copyWith(
                    color: PortenColor.gray800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (selected)
                Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: PortenGradient.brandSurface),
                  ),
                  alignment: Alignment.center,
                  child: LucideIcon('check',
                      size: 12,
                      color: PortenColor.white,
                      strokeWidth: 3),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 上移淡入 stagger 入场（对齐 Web 端 120ms + index*60ms，translateY 16px）。
class _StaggerIn extends StatefulWidget {
  const _StaggerIn({required this.delay, required this.child});

  final Duration delay;
  final Widget child;

  @override
  State<_StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<_StaggerIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
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
      opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 16 / 56), // 16px 相对行高近似
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _controller,
          curve: const Cubic(0.16, 1, 0.3, 1),
        )),
        child: widget.child,
      ),
    );
  }
}
