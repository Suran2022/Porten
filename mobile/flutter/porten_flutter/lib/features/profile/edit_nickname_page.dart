/*
 * 修改昵称页（100% 移植 Web 端 components/profile/EditNicknamePage.tsx）。
 *
 * 结构：fixed inset-0 z-[60] bg-[#f7f7f7]，从左滑入
 *   （-translate-x-full → translate-x-0，300ms，由 PortenSlideFromLeftRoute 承担）；
 *   顶栏白底（BackIcon w-10 h-10 -ml-2 +「修改昵称」text-lg w500 +
 *     「修改」text-sm w500，空昵称时 disabled gray-400）；
 *   输入卡 bg-white px-4 py-4：「新昵称」text-xs gray-400 mb-2 +
 *     TextField text-base、placeholder gray-400、maxLength 50、autoFocus。
 *
 * 保存链路（Web：updateNickname API → updateUser → onClose）：
 *   App Mock 阶段无 HTTP 层，trim 后即时写 profileEditProvider
 *   （资料页/编辑资料页同步回显）并 pop，与 AuthSession Mock 策略一致。
 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/components/porten_back_icon.dart';
import 'profile_page.dart' show kGray900, kGray400;
import 'state/profile_edit_provider.dart';

/// 修改昵称页（从左滑入，叠于编辑资料页之上）。
class EditNicknamePage extends ConsumerStatefulWidget {
  const EditNicknamePage({super.key});

  @override
  ConsumerState<EditNicknamePage> createState() => _EditNicknamePageState();
}

class _EditNicknamePageState extends ConsumerState<EditNicknamePage> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    // Web：visible 时以 user.nickname 初始化输入框；
    // App：读 profileEditProvider 当前昵称（与资料卡回显同源）。
    _controller = TextEditingController(text: ref.read(profileEditProvider).nickname);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 空昵称（trim 后）时禁用「修改」（对齐 Web disabled={!nickname.trim()}）。
  bool get _canSave => _controller.text.trim().isNotEmpty;

  void _handleSave() {
    final String trimmed = _controller.text.trim();
    if (trimmed.isEmpty) return;
    ref.read(profileEditProvider.notifier).setNickname(trimmed);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            // 顶栏（白底）：BackIcon + 标题 +「修改」
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
                      '修改昵称',
                      style: TextStyle(
                        fontSize: 18, // text-lg
                        fontWeight: FontWeight.w500,
                        color: kGray900,
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _canSave ? _handleSave : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text(
                          '修改',
                          style: TextStyle(
                            fontSize: 14, // text-sm
                            fontWeight: FontWeight.w500,
                            // disabled:text-gray-400
                            color: _canSave ? kGray900 : kGray400,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 输入卡（bg-white px-4 py-4，位于可滚动区域内）
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('新昵称',
                          style: TextStyle(fontSize: 12, color: kGray400)), // text-xs
                      const SizedBox(height: 8), // mb-2
                      TextField(
                        controller: _controller,
                        autofocus: true, // autoFocus={visible}
                        maxLength: 50,
                        style: const TextStyle(fontSize: 16, color: kGray900), // text-base
                        onChanged: (_) => setState(() {}), // 驱动「修改」可用态
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          counterText: '', // 隐藏长度计数器（对齐 Web 无装饰输入框）
                          hintText: '请输入新昵称',
                          hintStyle: TextStyle(fontSize: 16, color: kGray400),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
