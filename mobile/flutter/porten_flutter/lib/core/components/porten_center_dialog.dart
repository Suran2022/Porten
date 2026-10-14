/*
 * 居中弹窗容器（100% 移植 Web 端 components/common/CenterDialog.tsx）。
 *
 * 结构：fixed inset-0 flex items-center justify-center px-6；
 *   遮罩 absolute inset-0 bg-black/40（点击关闭）；
 *   卡片 relative w-full max-w-sm bg-white rounded-2xl shadow-xl overflow-hidden；
 * 动效：遮罩 opacity 0→1（200ms）；卡片 scale 95→100 + opacity 0→1
 *   （200ms ease-out，对齐 Web transition-all duration-200 ease-out）；
 * 卸载：visible 置 false 后等过渡结束（200ms）再移出树（对齐 Web
 *   onTransitionEnd → setShouldRender(false)）。
 */

import 'package:flutter/material.dart';

class PortenCenterDialog extends StatefulWidget {
  const PortenCenterDialog({
    super.key,
    required this.visible,
    required this.onClose,
    required this.child,
  });

  final bool visible;
  final VoidCallback onClose;
  final Widget child;

  @override
  State<PortenCenterDialog> createState() => _PortenCenterDialogState();
}

class _PortenCenterDialogState extends State<PortenCenterDialog> {
  bool _shouldRender = false;
  bool _isShown = false;

  @override
  void initState() {
    super.initState();
    if (widget.visible) {
      _shouldRender = true;
      // 双帧后置 isShown：首帧先画出初始态（opacity 0 / scale 95），
      // 再触发过渡（对齐 Web 双层 requestAnimationFrame）
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.visible) setState(() => _isShown = true);
      });
    }
  }

  @override
  void didUpdateWidget(PortenCenterDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible == oldWidget.visible) return;
    if (widget.visible) {
      setState(() => _shouldRender = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.visible) setState(() => _isShown = true);
      });
    } else {
      setState(() => _isShown = false);
      // 过渡结束（200ms）后卸载
      Future<void>.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !widget.visible) setState(() => _shouldRender = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldRender) return const SizedBox.shrink();
    return Positioned.fill(
      child: Stack(
        children: <Widget>[
          // 遮罩：bg-black/40，点击关闭
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onClose,
            child: AnimatedOpacity(
              opacity: _isShown ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: const ColoredBox(color: Color(0x66000000)), // black/40
            ),
          ),
          // 卡片：居中 + max-w-sm(384) + scale/opacity 过渡
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24), // px-6
              child: AnimatedScale(
                scale: _isShown ? 1 : 0.95,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: AnimatedOpacity(
                  opacity: _isShown ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 384), // max-w-sm
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(16), // rounded-2xl
                        boxShadow: const <BoxShadow>[
                          // shadow-xl 近似：0 20px 25px -5px rgb(0 0 0/0.1)
                          BoxShadow(
                            color: Color(0x1A000000),
                            blurRadius: 20,
                            spreadRadius: -4,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias, // overflow-hidden
                      child: widget.child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 弹窗底部文本按钮（对齐 Web h-12 text-sm + active:bg-gray-50 按压反馈）。
class PortenDialogTextButton extends StatefulWidget {
  const PortenDialogTextButton({
    super.key,
    required this.label,
    required this.onTap,
    this.color = const Color(0xFF4B5563), // gray-600
    this.fontWeight = FontWeight.w400,
  });

  final String label;
  final VoidCallback onTap;
  final Color color;
  final FontWeight fontWeight;

  @override
  State<PortenDialogTextButton> createState() => _PortenDialogTextButtonState();
}

class _PortenDialogTextButtonState extends State<PortenDialogTextButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        height: 48, // h-12
        alignment: Alignment.center,
        color: _pressed ? const Color(0xFFF9FAFB) : Colors.transparent, // gray-50
        child: Text(
          widget.label,
          style: TextStyle(
            fontSize: 14, // text-sm
            fontWeight: widget.fontWeight,
            color: widget.color,
          ),
        ),
      ),
    );
  }
}

/// 弹窗底部双按钮行（对齐 Web flex border-t border-gray-100 mt-4）：
/// 左取消（gray-600）/ 右主操作（blue-500 font-medium），中间 1px 分隔。
class PortenDialogFooter extends StatelessWidget {
  const PortenDialogFooter({
    super.key,
    required this.cancelLabel,
    required this.onCancel,
    required this.confirmLabel,
    required this.onConfirm,
  });

  final String cancelLabel;
  final VoidCallback onCancel;
  final String confirmLabel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16), // mt-4
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFF3F4F6))), // gray-100
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: PortenDialogTextButton(
              label: cancelLabel,
              onTap: onCancel,
            ),
          ),
          // w-px bg-gray-100 my-2
          Container(
            width: 1,
            height: 32,
            color: const Color(0xFFF3F4F6),
            margin: const EdgeInsets.symmetric(vertical: 8),
          ),
          Expanded(
            child: PortenDialogTextButton(
              label: confirmLabel,
              onTap: onConfirm,
              color: const Color(0xFF3B82F6), // blue-500
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
