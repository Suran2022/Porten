/*
 * 登录方式切换面板（对齐 Web 端 LoginMethodSheet）。
 *
 * Web 端实现：
 *   - 底部拖拽面板：sheet-handle 36x4 圆角灰条，遮罩 bg-gray-100/60；
 *   - 三种登录方式选项：w-9 h-9 圆形图标 + label + 右侧选中态
 *     （porten-bg-gradient 勾选圆）；
 *   - 选项按 120ms + index*60ms 的 stagger 入场（上移淡入）；
 *   - 支持手势下滑关闭（超过面板高度 50% 时关闭）。
 */

import 'package:flutter/material.dart';

import '../design/porten_colors.dart';
import '../design/porten_typography.dart';

/// 登录方式。
enum LoginMethod {
  email('邮箱登录', Icons.alternate_email),
  phone('手机号登录', Icons.phone_iphone),
  porten('Porten ID', Icons.fingerprint);

  const LoginMethod(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// 登录方式选择面板。
class LoginMethodSheet extends StatelessWidget {
  const LoginMethodSheet({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final LoginMethod selected;
  final ValueChanged<LoginMethod> onSelect;

  Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: PortenColor.gray100.withValues(alpha: 0.6),
      builder: (_) => this,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.3,
      maxChildSize: 0.6,
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          decoration: const BoxDecoration(
            color: PortenColor.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: PortenColor.gray300.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '选择登录方式',
                style: PortenTypography.x2l.copyWith(
                  color: PortenColor.gray900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '随时可以更换，数据保持同步',
                style: PortenTypography.sm.copyWith(color: PortenColor.gray500),
              ),
              const SizedBox(height: 16),
              ...List<Widget>.generate(LoginMethod.values.length, (int index) {
                final LoginMethod method = LoginMethod.values[index];
                return _StaggerIn(
                  delay: Duration(milliseconds: 120 + index * 60),
                  child: _MethodRow(
                    method: method,
                    selected: method == selected,
                    onTap: () {
                      onSelect(method);
                      Navigator.of(context).pop();
                    },
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

/// 单个登录方式行：图标圆 + 标签 + 选中态渐变勾选圆。
class _MethodRow extends StatelessWidget {
  const _MethodRow({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final LoginMethod method;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: selected
                    ? null
                    : PortenColor.gray100.withValues(alpha: 0.7),
                gradient: selected ? const LinearGradient(colors: PortenGradient.brandSurface) : null,
                shape: BoxShape.circle,
              ),
              child: Icon(
                method.icon,
                size: 18,
                color: selected ? PortenColor.white : PortenColor.gray600,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                method.label,
                style: PortenTypography.base.copyWith(
                  color: PortenColor.gray900,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            selected
                ? Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: PortenGradient.brandSurface),
                    ),
                    child: const Icon(Icons.check,
                        size: 14, color: PortenColor.white),
                  )
                : Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: PortenColor.gray300),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

/// 上移淡入 stagger 入场动画（对齐 Web 端 120ms + index*60ms 延迟）。
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
    duration: const Duration(milliseconds: 320),
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
          begin: const Offset(0, 0.35),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut)),
        child: widget.child,
      ),
    );
  }
}
