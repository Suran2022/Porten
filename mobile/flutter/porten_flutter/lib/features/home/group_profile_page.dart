/*
 * 营地资料完善页（100% 复刻 Web 端 components/home/GroupProfilePage.tsx
 * 移动端形态）。
 *
 * Web 端实现：
 *   - 白底全屏，从左滑入 -translate-x-full → 0（300ms
 *     cubic-bezier(0.25,0.1,0.25,1)，叠于组建营地页之上）；
 *   - 顶栏：左「上一步」（w-16 text-sm gray-600）+ 居中「营地资料完善」
 *     + 右 w-16 占位（closeMode 为 PC 形态，App 不走）；
 *   - 内容区 px-6 py-6 pb-40 滚动：
 *     头像 w-24 h-24 rounded-2xl bg-gray-100/80 居中（Camera 32 gray-400，
 *     点击上传——App 无选图能力，Toast 占位）；
 *     营地昵称（必填，30 字计数）、营地介绍（选填，120 字计数）、
 *     营地特色（popup 最多 5）、可发现营地的方式（3 选 popup）、
 *     营地规模（200~2000 popup）；
 *   - 底栏：协议勾选（16 圆角方框，选中 #F5A9B8）+「组建」按钮
 *     （可用 bg #F5A9B8 / 禁用 bg-gray-200 gray-400）；
 *   - 三个 BottomPopup：fixed inset-0 z-[80]，遮罩 black/40 + 面板
 *     rounded-t-3xl 上滑 300ms；标题左 + 右上 X 关闭。
 */

import 'package:flutter/material.dart';

import '../../core/components/porten_bottom_sheet.dart'
    show kPortenSheetDuration, kPortenSheetCurve;
import '../../core/components/porten_lucide_icons.dart';
import '../../core/components/porten_page_transitions.dart';
import '../../core/components/porten_toast.dart';
import '../../core/data/home_mock.dart';
import '../../core/design/porten_colors.dart';
import '../chat/chat_page.dart';

/// 品牌粉（Web bg-[#F5A9B8]，协议勾选与组建按钮同色）。
const Color kBrandPink = Color(0xFFF5A9B8);

/// 选中行浅粉底（Web bg-pink-50）。
const Color kPink50 = Color(0xFFFDF2F8);

class GroupProfilePage extends StatefulWidget {
  const GroupProfilePage({super.key, required this.groupType});

  /// 营地分类 key（peer / org / acg / medical / school）。
  final String groupType;

  @override
  State<GroupProfilePage> createState() => _GroupProfilePageState();
}

class _GroupProfilePageState extends State<GroupProfilePage> {
  String _name = '';
  String _intro = '';
  final List<String> _selectedFeatures = <String>[];
  String _discoverMethod = '';
  int _scale = 200;
  bool _agreed = false;
  String? _popup; // features / discover / scale
  bool _submitting = false;

  static const List<String> _features = <String>[
    '包容',
    '多元',
    '热爱',
    '友好',
    '互助',
    '专业',
    '支持',
    '组织',
    '医院',
    '校园',
  ];

  static const List<String> _discoverMethods = <String>[
    '搜索营地名称',
    '搜索营地号',
    '不允许搜索',
  ];

  static const List<int> _scales = <int>[200, 500, 1000, 1200, 1500, 2000];

  bool get _canSubmit =>
      _name.trim().isNotEmpty &&
      _discoverMethod.isNotEmpty &&
      _scale > 0 &&
      _agreed;

  void _toggleFeature(String feature) {
    setState(() {
      if (_selectedFeatures.contains(feature)) {
        _selectedFeatures.remove(feature);
      } else if (_selectedFeatures.length < 5) {
        // 最多选择 5 个（同 Web：超出忽略）
        _selectedFeatures.add(feature);
      }
    });
  }

  /// 组建：mock 创建营地会话并打开群聊（对齐 Web onCreated 流程：
  /// 两层页面依次退场后进入聊天页）。
  void _handleSubmit() {
    if (!_canSubmit || _submitting) return;
    setState(() => _submitting = true);
    final String name = _name.trim();
    // mock 引擎 createGroup：member_count 恒 1，系统消息「您已成功组建XX营地」
    final PortenConversation conversation = PortenConversation(
      id: 900001,
      isGroup: true,
      name: name,
      lastMessage: '您已成功组建$name营地',
      minutesAgo: 0,
      unreadCount: 0,
      memberCount: 1,
      avatarAsset: null,
    );
    setState(() => _submitting = false);
    // 先退出资料页与组建页，再从右滑入聊天页
    Navigator.of(context).pop();
    Navigator.of(context).pop();
    Navigator.of(context).push(PortenSlideFromRightRoute<void>(
      builder: (_) => ChatPage(conversation: conversation),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PortenColor.white,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: <Widget>[
            Column(
              children: <Widget>[
                _buildTopBar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 160), // px-6 py-6 pb-40
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _buildAvatar(),
                        const SizedBox(height: 32), // mb-8
                        _buildNameField(),
                        const SizedBox(height: 20), // mb-5
                        _buildIntroField(),
                        const SizedBox(height: 20),
                        _buildFeaturesField(),
                        const SizedBox(height: 20),
                        _buildDiscoverField(),
                        const SizedBox(height: 20),
                        _buildScaleField(),
                      ],
                    ),
                  ),
                ),
                _buildBottomBar(),
              ],
            ),
            // 三个 BottomPopup（覆盖于页面之上，同 Web z-[80]）
            if (_popup != null)
              _GroupBottomPopup(
                // key 保证每次打开重新挂载播入场动画（同 Web 每次 open 重挂）
                key: ValueKey<String>(_popup!),
                title: _popupTitle,
                onClose: () => setState(() => _popup = null),
                child: _buildPopupContent(),
              ),
          ],
        ),
      ),
    );
  }

  String get _popupTitle {
    switch (_popup) {
      case 'features':
        return '选择营地特色';
      case 'discover':
        return '可发现营地的方式';
      case 'scale':
        return '选择营地规模';
      default:
        return '';
    }
  }

  // ------------------------------------------------------------ 顶栏

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12), // px-4 pt-3 pb-3
      child: SizedBox(
        height: 28,
        child: Row(
          children: <Widget>[
            _TopBarTextButton(
              label: '上一步',
              width: 64, // w-16
              alignLeft: true,
              onTap: () => Navigator.of(context).maybePop(),
            ),
            const Expanded(
              child: Text(
                '营地资料完善',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18, // text-lg
                  fontWeight: FontWeight.w500, // font-medium
                  color: PortenColor.gray900,
                ),
              ),
            ),
            const SizedBox(width: 64), // w-16
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------ 表单

  Widget _buildAvatar() {
    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => PortenToast.show('营地头像上传即将上线，敬请期待'),
        child: Container(
          width: 96, // w-24
          height: 96, // h-24
          decoration: BoxDecoration(
            color: PortenColor.gray100.withValues(alpha: 0.8), // bg-gray-100/80
            borderRadius: BorderRadius.circular(16), // rounded-2xl
          ),
          child: const Center(
            child: PortenLucideIcon('camera',
                size: 32, color: PortenColor.gray400, strokeWidth: 1.5), // w-8 h-8
          ),
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _RequiredLabel(label: '营地昵称'),
        _GrayField(
          height: 44, // h-11
          hintText: '请输入营地昵称',
          value: _name,
          maxLength: 30,
          counterText: '${_name.length}/30',
          counterCentered: true,
          onChanged: (String v) => setState(() => _name = v),
        ),
      ],
    );
  }

  Widget _buildIntroField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _OptionalLabel(label: '营地介绍'),
        _GrayField(
          hintText: '请输入营地介绍',
          value: _intro,
          maxLength: 120,
          maxLines: 4, // rows={4}
          counterText: '${_intro.length}/120',
          counterBottom: true,
          onChanged: (String v) => setState(() => _intro = v),
        ),
      ],
    );
  }

  Widget _buildFeaturesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _OptionalLabel(label: '营地特色'),
        _TriggerField(
          text: _selectedFeatures.isNotEmpty ? _selectedFeatures.join('、') : null,
          placeholder: '请选择营地特色（最多5个）',
          onTap: () => setState(() => _popup = 'features'),
        ),
      ],
    );
  }

  Widget _buildDiscoverField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _RequiredLabel(label: '可发现营地的方式'),
        _TriggerField(
          text: _discoverMethod.isNotEmpty ? _discoverMethod : null,
          placeholder: '请选择可发现营地的方式',
          onTap: () => setState(() => _popup = 'discover'),
        ),
      ],
    );
  }

  Widget _buildScaleField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _RequiredLabel(label: '营地规模'),
        _TriggerField(
          text: '$_scale人', // 始终 gray-900（同 Web）
          onTap: () => setState(() => _popup = 'scale'),
        ),
      ],
    );
  }

  // ------------------------------------------------------------ 底栏

  Widget _buildBottomBar() {
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + bottomInset), // px-6 py-4 pb-[max(1rem,inset)]
      decoration: const BoxDecoration(
        color: PortenColor.white,
        border: Border(top: BorderSide(color: Color(0xFFF3F4F6))), // border-t gray-100
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // 协议勾选
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _agreed = !_agreed),
            child: Row(
              children: <Widget>[
                Container(
                  width: 16, // w-4
                  height: 16, // h-4
                  decoration: BoxDecoration(
                    color: _agreed ? kBrandPink : Colors.transparent,
                    borderRadius: BorderRadius.circular(4), // rounded
                    border: _agreed
                        ? null
                        : Border.all(color: PortenColor.gray300), // border-gray-300
                  ),
                  child: _agreed
                      ? const Center(
                          child: PortenLucideIcon('check',
                              size: 11, color: PortenColor.white, strokeWidth: 2.5),
                        )
                      : null,
                ),
                const SizedBox(width: 8), // gap-2
                const Expanded(
                  child: Text(
                    '我已知晓并遵守《Porten营地组织共建管理》',
                    style: TextStyle(
                      fontSize: 12, // text-xs
                      color: PortenColor.gray600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16), // mb-4
          // 组建按钮
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _handleSubmit,
            child: Container(
              height: 44, // h-11
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _canSubmit && !_submitting
                    ? kBrandPink // bg-[#F5A9B8]
                    : PortenColor.gray200, // bg-gray-200
                borderRadius: BorderRadius.circular(22), // rounded-full
              ),
              child: Text(
                _submitting ? '组建中…' : '组建',
                style: TextStyle(
                  fontSize: 14, // text-sm
                  fontWeight: FontWeight.w500, // font-medium
                  color: _canSubmit && !_submitting
                      ? PortenColor.white
                      : PortenColor.gray400, // text-gray-400
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ Popup 内容

  Widget _buildPopupContent() {
    switch (_popup) {
      case 'features':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '最多选择 5 个（已选 ${_selectedFeatures.length}/5）',
              style: const TextStyle(fontSize: 12, color: PortenColor.gray400), // text-xs
            ),
            const SizedBox(height: 8), // mb-2
            Wrap(
              spacing: 8, // gap-2
              runSpacing: 8,
              children: <Widget>[
                for (final String feature in _features)
                  _FeatureChip(
                    label: feature,
                    selected: _selectedFeatures.contains(feature),
                    onTap: () => _toggleFeature(feature),
                  ),
              ],
            ),
            const SizedBox(height: 24), // mb-6
            _PopupConfirmButton(
              label: '确定',
              onTap: () => setState(() => _popup = null),
            ),
          ],
        );
      case 'discover':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final String method in _discoverMethods)
              Padding(
                padding: const EdgeInsets.only(bottom: 4), // space-y-1
                child: _DiscoverRow(
                  label: method,
                  selected: _discoverMethod == method,
                  onTap: () {
                    setState(() {
                      _discoverMethod = method;
                      _popup = null;
                    });
                  },
                ),
              ),
            const SizedBox(height: 24), // mb-6
          ],
        );
      case 'scale':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Wrap(
              spacing: 12, // gap-3
              runSpacing: 12,
              children: <Widget>[
                for (final int s in _scales)
                  SizedBox(
                    width: (MediaQuery.sizeOf(context).width - 48 - 24) / 3, // grid-cols-3 gap-3
                    child: _ScaleCell(
                      value: s,
                      selected: _scale == s,
                      onTap: () {
                        setState(() {
                          _scale = s;
                          _popup = null;
                        });
                      },
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24), // mb-6
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

/// 顶栏文字按钮（上一步 / 取消，w-16 宽）。
class _TopBarTextButton extends StatelessWidget {
  const _TopBarTextButton({
    required this.label,
    required this.width,
    required this.onTap,
    this.alignLeft = false,
  });

  final String label;
  final double width;
  final VoidCallback onTap;
  final bool alignLeft;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Text(
          label,
          textAlign: alignLeft ? TextAlign.left : TextAlign.right,
          style: const TextStyle(
            fontSize: 14, // text-sm
            color: PortenColor.gray600,
          ),
        ),
      ),
    );
  }
}

/// 必填标签（text-sm gray-700 + 红色 *）。
class _RequiredLabel extends StatelessWidget {
  const _RequiredLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6), // mb-1.5
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: PortenColor.gray700),
          ),
          const Text(
            ' *',
            style: TextStyle(fontSize: 14, color: Color(0xFFEF4444)), // text-red-500
          ),
        ],
      ),
    );
  }
}

/// 选填标签（text-sm gray-700）。
class _OptionalLabel extends StatelessWidget {
  const _OptionalLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(fontSize: 14, color: PortenColor.gray700),
      ),
    );
  }
}

/// 浅灰填充输入框（Web bg-gray-100/60 rounded-[7px] text-sm），
/// 带右下/居中字数计数。
class _GrayField extends StatefulWidget {
  const _GrayField({
    required this.hintText,
    required this.value,
    required this.maxLength,
    required this.counterText,
    required this.onChanged,
    this.height,
    this.maxLines = 1,
    this.counterCentered = false,
    this.counterBottom = false,
  });

  final String hintText;
  final String value;
  final int maxLength;
  final String counterText;
  final ValueChanged<String> onChanged;
  final double? height;
  final int maxLines;
  final bool counterCentered;
  final bool counterBottom;

  @override
  State<_GrayField> createState() => _GrayFieldState();
}

class _GrayFieldState extends State<_GrayField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget counter = Text(
      widget.counterText,
      style: const TextStyle(fontSize: 12, color: PortenColor.gray400), // text-xs
    );
    return Stack(
      children: <Widget>[
        Container(
          height: widget.height, // h-11（多行态为 null 自适应）
          padding: EdgeInsets.symmetric(
            horizontal: 12, // px-3
            vertical: widget.maxLines > 1 ? 10 : 0, // 多行 py-2.5
          ),
          decoration: BoxDecoration(
            color: PortenColor.gray100.withValues(alpha: 0.6), // bg-gray-100/60
            borderRadius: BorderRadius.circular(7), // rounded-[7px]
          ),
          child: TextField(
            controller: _controller,
            onChanged: widget.onChanged,
            maxLines: widget.maxLines,
            maxLength: widget.maxLength, // 截断超长输入（同 Web slice）
            cursorColor: PortenColor.gray900,
            style: const TextStyle(fontSize: 14, color: PortenColor.gray900),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: widget.maxLines > 1
                  ? EdgeInsets.zero
                  : const EdgeInsets.symmetric(vertical: 12),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              counterText: '', // 计数由外层 Stack 定位渲染
              hintText: widget.hintText,
              hintStyle: const TextStyle(fontSize: 14, color: PortenColor.gray400),
            ),
          ),
        ),
        if (widget.counterCentered)
          Positioned(
            right: 12, // right-3
            top: 0,
            bottom: 0,
            child: IgnorePointer(child: Center(child: counter)), // top-1/2
          ),
        if (widget.counterBottom)
          Positioned(
            right: 12,
            bottom: 10, // bottom-2.5
            child: IgnorePointer(child: counter),
          ),
      ],
    );
  }
}

/// 选择入口行（h-11 bg-gray-100/60 rounded-[7px] px-3，右箭头）。
class _TriggerField extends StatelessWidget {
  const _TriggerField({required this.text, this.placeholder, required this.onTap});

  final String? text;
  final String? placeholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 44, // h-11
        padding: const EdgeInsets.symmetric(horizontal: 12), // px-3
        decoration: BoxDecoration(
          color: PortenColor.gray100.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                text ?? placeholder ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14, // text-sm
                  color: text != null
                      ? PortenColor.gray900
                      : PortenColor.gray400, // placeholder
                ),
              ),
            ),
            const SizedBox(width: 8),
            const PortenLucideIcon('chevron-right',
                size: 16, color: PortenColor.gray400, strokeWidth: 1.5), // w-4 h-4
          ],
        ),
      ),
    );
  }
}

/// 营地特色 chip（px-4 py-1.5 rounded-full text-sm）。
class _FeatureChip extends StatelessWidget {
  const _FeatureChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150), // transition-colors
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), // px-4 py-1.5
        decoration: BoxDecoration(
          color: selected ? kBrandPink : PortenColor.white, // bg-[#F5A9B8]
          borderRadius: BorderRadius.circular(999), // rounded-full
          border: Border.all(
            color: selected ? kBrandPink : PortenColor.gray200, // border-[#F5A9B8] / gray-200
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14, // text-sm
            color: selected ? PortenColor.white : PortenColor.gray700,
          ),
        ),
      ),
    );
  }
}

/// 可发现方式行（h-12 px-3 rounded-lg text-sm，选中浅粉底 + 粉点）。
class _DiscoverRow extends StatelessWidget {
  const _DiscoverRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 48, // h-12
        padding: const EdgeInsets.symmetric(horizontal: 12), // px-3
        decoration: BoxDecoration(
          color: selected ? kPink50 : PortenColor.white, // bg-pink-50
          borderRadius: BorderRadius.circular(8), // rounded-lg
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14, // text-sm
                  color: selected ? kBrandPink : PortenColor.gray700,
                ),
              ),
            ),
            if (selected)
              Container(
                width: 8, // w-2
                height: 8, // h-2
                decoration: const BoxDecoration(
                  color: kBrandPink, // bg-[#F5A9B8]
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 规模单元格（h-11 rounded-lg text-sm font-medium）。
class _ScaleCell extends StatelessWidget {
  const _ScaleCell({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final int value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 44, // h-11
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? kBrandPink // bg-[#F5A9B8]
              : PortenColor.gray100.withValues(alpha: 0.6), // bg-gray-100/60
          borderRadius: BorderRadius.circular(8), // rounded-lg
        ),
        child: Text(
          '$value',
          style: TextStyle(
            fontSize: 14, // text-sm
            fontWeight: FontWeight.w500, // font-medium
            color: selected ? PortenColor.white : PortenColor.gray700,
          ),
        ),
      ),
    );
  }
}

/// Popup 确定按钮（w-full h-11 rounded-full bg #F5A9B8）。
class _PopupConfirmButton extends StatelessWidget {
  const _PopupConfirmButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 44, // h-11
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: kBrandPink,
          borderRadius: BorderRadius.circular(22), // rounded-full
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14, // text-sm
            fontWeight: FontWeight.w500, // font-medium
            color: PortenColor.white,
          ),
        ),
      ),
    );
  }
}

/// 营地资料页内嵌底部弹层（100% 复刻 Web GroupProfilePage 内的
/// BottomPopup：fixed inset-0 z-[80]，遮罩 black/40 淡入 + 面板
/// rounded-t-3xl 上滑，300ms cubic-bezier(0.25,0.1,0.25,1)；
/// 标题左对齐 + 右上 X 关闭，无拖拽手柄）。
class _GroupBottomPopup extends StatefulWidget {
  const _GroupBottomPopup({
    super.key,
    required this.title,
    required this.onClose,
    required this.child,
  });

  final String title;
  final VoidCallback onClose;
  final Widget child;

  @override
  State<_GroupBottomPopup> createState() => _GroupBottomPopupState();
}

class _GroupBottomPopupState extends State<_GroupBottomPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: kPortenSheetDuration,
  );
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

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    return Positioned.fill(
      child: Stack(
        children: <Widget>[
          // 遮罩：bg-black/40，点击关闭
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onClose,
              child: ColoredBox(
                color: PortenColor.black.withValues(alpha: 0.4 * _anim.value),
              ),
            ),
          ),
          // 面板：贴底，translateY(100%) ↔ 0
          Align(
            alignment: Alignment.bottomCenter,
            child: FractionalTranslation(
              translation: Offset(0, 1 - _anim.value),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset), // px-4 pt-4 pb-[max(1rem,inset)]
                decoration: const BoxDecoration(
                  color: PortenColor.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)), // rounded-t-3xl
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // 标题行：左标题 + 右上 X
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            widget.title,
                            style: const TextStyle(
                              fontSize: 16, // text-base
                              fontWeight: FontWeight.w500, // font-medium
                              color: PortenColor.gray900,
                            ),
                          ),
                        ),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: widget.onClose,
                          child: const SizedBox(
                            width: 32, // w-8
                            height: 32, // h-8
                            child: Center(
                              child: PortenLucideIcon('x',
                                  size: 20,
                                  color: PortenColor.gray500,
                                  strokeWidth: 1.5), // w-5 h-5
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16), // mb-4
                    widget.child,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
