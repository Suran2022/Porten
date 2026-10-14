/*
 * 编辑资料页（100% 移植 Web 端 components/profile/EditProfilePage.tsx）。
 *
 * 结构：fixed inset-0 z-50 bg-[#f7f7f7]，从左滑入
 *   （-translate-x-full → translate-x-0，300ms，由 PortenSlideFromLeftRoute 承担）；
 *   顶栏白底（BackIcon w-10 h-10 -ml-2 +「编辑资料」text-lg w500 +
 *     「保存」text-sm w500 gray-900）；
 *   选项区 space-y-[2px]，三行 px-4 py-4 bg-white + active:bg-gray-50/50：
 *     修改昵称（push EditNicknamePage，Web 为 z-[60] 从左滑入覆盖层）；
 *     设置性别（右侧 genderLabel text-sm gray-500 + gap-1 + ChevronRight）→
 *       GenderPickerSheet 页内叠加弹窗；
 *     设置背景图（Web 为隐藏 file input 选图上传）。
 *
 * 保存链路：Web 各字段均已通过各自接口即时持久化，「保存」仅关闭页面；
 *   App Mock 同理——昵称/性别即时写 profileEditProvider，「保存」pop。
 *   背景图：App 无选图能力（未接入 image_picker，Mock 阶段不引入原生依赖），
 *   降级为 Toast 占位，与「悦音乐即将上线」等占位策略一致。
 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/components/porten_back_icon.dart';
import '../../core/components/porten_lucide_icons.dart';
import '../../core/components/porten_page_transitions.dart';
import '../../core/components/porten_toast.dart';
import 'edit_nickname_page.dart';
import 'gender_picker_sheet.dart';
import 'profile_page.dart' show kGray900, kGray500, kGray400, kGray50;
import 'state/profile_edit_provider.dart';

/// 编辑资料页（从左滑入）。
class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  /// 性别选择弹窗可见性（昵称页在 App 端为 push 路由，无需此标志）。
  bool _genderVisible = false;

  /// 修改昵称：push 从左滑入页面（等价 Web z-[60] 覆盖层）。
  void _openNicknamePage() {
    Navigator.of(context).push<void>(PortenSlideFromLeftRoute<void>(
      builder: (_) => const EditNicknamePage(),
    ));
  }

  /// 设置性别（对齐 Web handleGenderChange → updateProfile({gender})）：
  /// App Mock 即时写 provider，资料卡/编辑页同步回显；
  /// 弹窗关闭由 GenderPickerSheet 选中后自行回调 onClose 完成。
  void _handleGenderChange(String value) {
    ref.read(profileEditProvider.notifier).setGender(value);
  }

  /// 设置背景图：Web 走选图 + 压缩 + updateBackground；
  /// App 无选图能力，Toast 占位（不阻断其余编辑功能）。
  void _handleBackgroundClick() {
    PortenToast.show('背景图设置即将上线，敬请期待');
  }

  @override
  Widget build(BuildContext context) {
    final ProfileEditState editState = ref.watch(profileEditProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: <Widget>[
            Column(
              children: <Widget>[
                // 顶栏（白底）：BackIcon + 标题 +「保存」
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: SizedBox(
                    height: 40,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => Navigator.of(context).maybePop(),
                          // -ml-2：Container margin 不支持负值，用 Transform 位移等价实现
                          child: Transform.translate(
                            offset: const Offset(-8, 0),
                            child: const SizedBox(
                              width: 40,
                              height: 40,
                              child: Center(child: PortenBackIcon()),
                            ),
                          ),
                        ),
                        const Text(
                          '编辑资料',
                          style: TextStyle(
                            fontSize: 18, // text-lg
                            fontWeight: FontWeight.w500,
                            color: kGray900,
                          ),
                        ),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          // Web：handleSave 仅 onClose（字段均已即时持久化）
                          onTap: () => Navigator.of(context).maybePop(),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Text(
                              '保存',
                              style: TextStyle(
                                fontSize: 14, // text-sm
                                fontWeight: FontWeight.w500,
                                color: kGray900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // 选项区（space-y-[2px]）
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _OptionRow(
                        label: '修改昵称',
                        onTap: _openNicknamePage,
                      ),
                      const SizedBox(height: 2),
                      _OptionRow(
                        label: '设置性别',
                        // 右侧当前性别（text-sm gray-500）+ gap-1 + chevron
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              editState.genderLabel,
                              style: const TextStyle(fontSize: 14, color: kGray500),
                            ),
                            const SizedBox(width: 4), // gap-1
                            const PortenLucideIcon('chevron-right',
                                size: 20, color: kGray400, strokeWidth: 1.5),
                          ],
                        ),
                        onTap: () => setState(() => _genderVisible = true),
                      ),
                      const SizedBox(height: 2),
                      _OptionRow(
                        label: '设置背景图',
                        onTap: _handleBackgroundClick,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // 性别选择弹窗：常驻页内 Stack（对齐 Web 始终渲染、内部管理显隐），
            // 关闭后由自身 300ms 离场动画结束才卸载，故不能用 if 条件移除。
            Positioned.fill(
              child: GenderPickerSheet(
                visible: _genderVisible,
                selected: editState.genderValue,
                onSelect: _handleGenderChange,
                onClose: () => setState(() => _genderVisible = false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 选项行（px-4 py-4 bg-white + active:bg-gray-50/50；右侧默认 chevron）。
class _OptionRow extends StatefulWidget {
  const _OptionRow({
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final String label;
  final VoidCallback onTap;

  /// 自定义右侧区域（设置性别行：性别文案 + chevron）。
  final Widget? trailing;

  @override
  State<_OptionRow> createState() => _OptionRowState();
}

class _OptionRowState extends State<_OptionRow> {
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
            widget.trailing ??
                const PortenLucideIcon('chevron-right',
                    size: 20, color: kGray400, strokeWidth: 1.5), // w-5 h-5
          ],
        ),
      ),
    );
  }
}
