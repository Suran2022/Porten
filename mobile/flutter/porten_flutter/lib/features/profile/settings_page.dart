/*
 * 设置页（对齐 Web 端 components/profile/SettingsPage.tsx 移动端形态）。
 *
 * 背景 bg-[#f7f7f7]；从右滑入 translate-x-full→0；
 * 顶栏：BackIcon w-7 + 「设置」text-lg font-medium 居中（-ml-8 校正）；
 * 选项行 px-4 py-4 bg-white：Porten安全 / 应用栏管理 / 关于 Porten /
 *   问题反馈 / 版本更新（右侧 Web-v 0.2.2 text-sm gray-400，点击提示「已是最新版本」）；
 * 退出登录：底部固定 px-6 py-6、h-11 rounded-full bg-gray-200/50 text-red-500
 *   text-base font-medium。
 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/components/porten_back_icon.dart';
import '../../core/components/porten_lucide_icons.dart';
import '../../core/components/porten_toast.dart';
import '../auth/state/auth_controller.dart';
import 'profile_page.dart' show kGray900, kGray400;

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  /// 退出登录（复刻 Web 端 SettingsPage.handleLogout）：
  /// loading 提示 → 800ms 后 success 提示 → 清会话并回登录页。
  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    PortenToast.show('正在退出登录');
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!context.mounted) return;
    ref.read(authProvider.notifier).signOut();
    PortenToast.show('已退出登录', icon: ToastIcon.success);
    // 回到登录页：弹掉设置页/资料页等所有二级页面，根路由随会话清空
    // 由 app.dart 的认证状态机切回 AuthSlider。
    Navigator.of(context, rootNavigator: true)
        .popUntil((Route<Object?> route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            // 顶栏（白底，BackIcon + 居中标题 -ml-8）
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
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: Center(child: const PortenBackIcon()),
                      ),
                    ),
                    Expanded(
                      child: Transform.translate(
                        offset: const Offset(-32, 0), // -ml-8
                        child: const Text('设置',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: kGray900)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: <Widget>[
                    _OptionRow(
                      label: 'Porten安全',
                      onTap: () => PortenToast.show('Porten安全即将上线，敬请期待'),
                    ),
                    _OptionRow(
                      label: '应用栏管理',
                      onTap: () => PortenToast.show('应用栏管理即将上线，敬请期待'),
                    ),
                    _OptionRow(
                      label: '关于 Porten',
                      onTap: () => PortenToast.show('关于 Porten 即将上线，敬请期待'),
                    ),
                    _OptionRow(
                      label: '问题反馈',
                      onTap: () => PortenToast.show('问题反馈即将上线，敬请期待'),
                    ),
                    _OptionRow(
                      label: '版本更新',
                      trailing: const Text('v0.2.2',
                          style: TextStyle(fontSize: 14, color: kGray400)),
                      onTap: () =>
                          PortenToast.show('已是最新版本', icon: ToastIcon.success),
                    ),
                  ],
                ),
              ),
            ),
            // 退出登录（底部固定，px-6 py-6）
            Container(
              padding: const EdgeInsets.all(24),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _handleLogout(context, ref),
                child: Container(
                  width: double.infinity,
                  height: 44, // h-11
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text('退出登录',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFEF4444))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.label, this.trailing, this.onTap});

  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(label, style: const TextStyle(fontSize: 16, color: kGray900)),
            trailing ??
                const PortenLucideIcon('chevron-right',
                    size: 16, color: kGray400, strokeWidth: 1.5),
          ],
        ),
      ),
    );
  }
}
