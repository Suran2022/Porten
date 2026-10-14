/*
 * 通用底部弹出面板（100% 复刻 Web 端 components/trip/BottomSheet.tsx）。
 *
 * Web 端实现：
 *   - createPortal 挂到 body 下，fixed inset-0 z-[70] flex flex-col justify-end；
 *   - 遮罩：absolute inset-0 bg-black/40，transition-opacity duration-300，点击关闭；
 *   - 面板：relative bg-white rounded-t-3xl flex flex-col overflow-hidden，
 *     translate-y-full ↔ translate-y-0，300ms ease-[cubic-bezier(0.25,0.1,0.25,1)]；
 *   - 拖拽手柄：flex justify-center pt-3 pb-1 内 w-9 h-1 rounded-full bg-gray-300；
 *   - 标题行：relative flex items-center justify-center py-2.5，
 *     可选左侧返回按钮（absolute left-2 w-10 h-10，BackIcon w-7 h-7），
 *     标题 text-base font-medium text-gray-900。
 *
 * App 侧以独立路由（showGeneralDialog，路由转场时长置 0）承载，动画完全由
 * 内部 AnimationController 驱动：打开时遮罩淡入 + 面板上滑（300ms），
 * 关闭时先反向播完 300ms 再出栈——与 Web 的 renderVisible/isEntering
 * 两态过渡语义一致。嵌套面板（如创建日程内的时间选择器）以后压入路由
 * 天然叠于先者之上，对应 Web 中 portal 后写入 DOM 的高 z 序。
 */

import 'package:flutter/material.dart';

import '../design/porten_colors.dart';
import 'porten_back_icon.dart';

/// 面板进出场时长（Web duration-300）。
const Duration kPortenSheetDuration = Duration(milliseconds: 300);

/// 面板滑动曲线（Web ease-[cubic-bezier(0.25,0.1,0.25,1)]，
/// 亦为 CSS transition 默认 ease，遮罩淡入同曲线）。
const Cubic kPortenSheetCurve = Cubic(0.25, 0.1, 0.25, 1);

/// 面板内容构建器：close 为带动画的关闭回调（反向 300ms 后出栈）。
typedef PortenSheetContentBuilder = Widget Function(
    BuildContext context, VoidCallback close);

/// 通用底部弹出面板。
class PortenBottomSheet extends StatefulWidget {
  const PortenBottomSheet({
    super.key,
    required this.title,
    required this.onClose,
    required this.content,
    this.height,
    this.onBack,
  });

  /// 面板顶部居中标题。
  final String title;

  /// 退场动画结束后的出栈回调。
  final VoidCallback onClose;

  /// 面板内容（高度自适应或占满固定高度）。
  final PortenSheetContentBuilder content;

  /// 固定高度（如 75vh / 90vh 换算值）；null 为内容自适应。
  final double? height;

  /// 标题左侧返回按钮（机场选择第二步返回城市列表用）。
  final VoidCallback? onBack;

  /// 以独立路由打开面板。
  static Future<void> show(
    BuildContext context, {
    required String title,
    required PortenSheetContentBuilder content,
    double? height,
    VoidCallback? onBack,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent, // 遮罩由面板自身绘制（带 300ms 淡入）
      transitionDuration: Duration.zero,
      pageBuilder: (BuildContext ctx, _, _) => PortenBottomSheet(
        title: title,
        height: height,
        onBack: onBack,
        onClose: () => Navigator.of(ctx).pop(),
        content: content,
      ),
    );
  }

  @override
  State<PortenBottomSheet> createState() => _PortenBottomSheetState();
}

class _PortenBottomSheetState extends State<PortenBottomSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: kPortenSheetDuration);
  late final Animation<double> _anim =
      CurvedAnimation(parent: _controller, curve: kPortenSheetCurve);

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

  /// 带动画的关闭：反向播完 300ms 再出栈（对齐 Web 滑出后卸载）。
  void _handleClose() {
    _controller.reverse().whenComplete(() {
      if (mounted) widget.onClose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.sizeOf(context).height;
    final double? panelHeight = widget.height;

    return AnimatedBuilder(
      animation: _anim,
      builder: (BuildContext context, _) {
        return Stack(
          children: <Widget>[
            // 遮罩：bg-black/40，点击关闭
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _handleClose,
                child: ColoredBox(
                  color: PortenColor.black.withValues(alpha: 0.4 * _anim.value),
                ),
              ),
            ),
            // 面板：贴底，translate-y-full ↔ translate-y-0
            Align(
              alignment: Alignment.bottomCenter,
              child: FractionalTranslation(
                translation: Offset(0, 1 - _anim.value),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: panelHeight ?? screenHeight,
                  ),
                  // Material 承载面板：为内容提供 Material 祖先
                  // （TextField 等必须有，否则抛「No Material widget found」），
                  // 白色圆角与 Web 面板 bg-white rounded-t-3xl 一致
                  child: SizedBox(
                    width: double.infinity,
                    child: Material(
                      color: PortenColor.white,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24), // rounded-t-3xl
                      ),
                      clipBehavior: Clip.antiAlias, // 对齐 Web overflow-hidden
                      child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        // 拖拽手柄：pt-3 pb-1 + w-9 h-1 bg-gray-300
                        const Padding(
                          padding: EdgeInsets.only(top: 12, bottom: 4),
                          child: Center(
                            child: SizedBox(
                              width: 36, // w-9
                              height: 4, // h-1
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: PortenColor.gray300,
                                  borderRadius: BorderRadius.all(Radius.circular(2)),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // 标题行：py-2.5，可选左侧返回
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: SizedBox(
                            height: 28,
                            child: Stack(
                              alignment: Alignment.center,
                              children: <Widget>[
                                if (widget.onBack != null)
                                  Positioned(
                                    left: 8, // left-2
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: widget.onBack,
                                      child: const SizedBox(
                                        width: 40, // w-10
                                        height: 40, // h-10
                                        child: Center(
                                          child: PortenBackIcon(size: 28), // w-7 h-7
                                        ),
                                      ),
                                    ),
                                  ),
                                Text(
                                  widget.title,
                                  style: const TextStyle(
                                    fontSize: 16, // text-base
                                    fontWeight: FontWeight.w500, // font-medium
                                    color: PortenColor.gray900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // 内容区：固定高度时撑满剩余空间；自适应时限高为
                        // 剩余空间（Web 面板 flex-col + 内容 flex-1 min-h-0：
                        // 内容不超出面板、超出时内部滚动）。
                        // 注意：自适应模式也必须用 Flexible——否则内容作为
                        // 非 flex 子项会收到整屏高度约束，内部 Flexible 的
                        // 剩余空间计算全盘错位，长列表直接溢出面板。
                        if (panelHeight != null)
                          Expanded(child: widget.content(context, _handleClose))
                        else
                          Flexible(
                            fit: FlexFit.loose,
                            child: widget.content(context, _handleClose),
                          ),
                      ],
                    ),
                  ), // Material
                  ), // SizedBox
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 面板底部取消按钮（Web SHEET_BTN_CANCEL：flex-1 py-3 rounded-xl
/// bg-gray-100 text-gray-500 text-base font-medium，按压 bg-gray-200）。
class PortenSheetCancelButton extends StatelessWidget {
  const PortenSheetCancelButton({super.key, required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _SheetButton(
      label: label,
      onTap: onTap,
      background: PortenColor.gray100,
      pressedBackground: PortenColor.gray200,
      foreground: PortenColor.gray500,
      pressedOpacity: null,
    );
  }
}

/// 面板底部确定按钮（Web SHEET_BTN_CONFIRM：flex-1 py-3 rounded-xl
/// bg-[#F7C5D0] text-white text-base font-medium，按压 opacity-80）。
class PortenSheetConfirmButton extends StatelessWidget {
  const PortenSheetConfirmButton({super.key, required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _SheetButton(
      label: label,
      onTap: onTap,
      background: PortenColor.brandPinkLight, // #F7C5D0
      pressedBackground: PortenColor.brandPinkLight,
      foreground: PortenColor.white,
      pressedOpacity: 0.8,
    );
  }
}

/// 面板底部按钮行（Web flex gap-3 px-5 pb-[calc(1.25rem+env(safe-area-inset-bottom))]）。
class PortenSheetButtonRow extends StatelessWidget {
  const PortenSheetButtonRow({
    super.key,
    required this.cancelLabel,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
  });

  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 4, bottom: 20 + bottomInset),
      child: Row(
        children: <Widget>[
          Expanded(
            child: PortenSheetCancelButton(label: cancelLabel, onTap: onCancel),
          ),
          const SizedBox(width: 12), // gap-3
          Expanded(
            child: PortenSheetConfirmButton(label: confirmLabel, onTap: onConfirm),
          ),
        ],
      ),
    );
  }
}

/// 带按压态（颜色/透明度过渡）的面板按钮。
class _SheetButton extends StatefulWidget {
  const _SheetButton({
    required this.label,
    required this.onTap,
    required this.background,
    required this.pressedBackground,
    required this.foreground,
    this.pressedOpacity,
  });

  final String label;
  final VoidCallback? onTap;
  final Color background;
  final Color pressedBackground;
  final Color foreground;
  final double? pressedOpacity;

  @override
  State<_SheetButton> createState() => _SheetButtonState();
}

class _SheetButtonState extends State<_SheetButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final double? opacity =
        widget.pressedOpacity != null && _pressed ? widget.pressedOpacity : null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedOpacity(
        opacity: opacity ?? 1,
        duration: const Duration(milliseconds: 150),
        child: Container(
          height: 48, // py-3 + text-base 行高 ≈ 48
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _pressed ? widget.pressedBackground : widget.background,
            borderRadius: BorderRadius.circular(12), // rounded-xl
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 16, // text-base
              fontWeight: FontWeight.w500, // font-medium
              color: widget.foreground,
            ),
          ),
        ),
      ),
    );
  }
}
