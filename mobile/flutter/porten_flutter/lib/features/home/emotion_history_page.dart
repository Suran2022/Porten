/*
 * 历史情绪页（100% 复刻 Web 端 components/home/EmotionHistoryPage.tsx）。
 *
 * Web 结构（逐项对应）：
 *   - 根 fixed inset-0 z-[78] flex flex-col，translate-x-full → 0
 *     300ms cubic-bezier(0.25,0.1,0.25,1)（App 端由内部
 *     AnimationController 复刻；隐藏态 pointer-events-none 等价
 *     IgnorePointer。Web 退出后 320ms 卸载，App 端常驻树中移出
 *     屏幕外，视觉等价）；
 *   - 背景 cisMode ? bg-[#fafafa] : bg-[#f7f7f7]；
 *   - 顶栏：返回钮（w-10 h-10 -ml-2，BackIcon w-7 h-7）+ 居中
 *     「历史情绪」（text-lg font-medium text-gray-900）+ 右侧
 *     w-8 占位；px-4 pt-[max(0.75rem,safe-top)] pb-3 bg-white
 *     border-b border-gray-100；
 *   - 列表 flex-1 overflow-y-auto px-4 py-4 space-y-3：
 *     HistoryCard（rounded-2xl bg-white p-4 border-gray-100；
 *     顶行 time text-[11px] gray-400 + 徽章 text-[10px] h-5 px-2
 *     rounded-full：is_current ?「当前」（cis ? bg-gray-900 :
 *     bg-gradient #5BCEFA→#F5A9B8，白字）:「历史」（bg-gray-100
 *     gray-500）；正文 text-[14px] gray-800 leading-7
 *     whitespace-pre-wrap；底部 mood 行 emoji+label text-xs
 *     gray-500）；
 *   - 分页：hasMore（items.length >= 50）→ 「加载更多」钮
 *     （w-full py-3 text-sm gray-400，loading 时「加载中...」）；
 *     !hasMore && items.length === total → 「共 N 条记录」
 *     （py-4 text-center text-[11px] gray-300）；空列表 →
 *     「还没有历史记录」（py-20 text-center text-sm gray-400）；
 *   - 数据：打开时 loadHistory(true)（Web 组件每次挂载重载，App
 *     侧在 visible false→true 时重载）；nextCursor 取末条 id；
 *   - 自身 SystemToast（加载失败，1500ms 自动隐藏）。
 */

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/components/porten_back_icon.dart';
import '../../core/components/porten_system_toast.dart';
import '../../core/data/emotion_diary_mock.dart';
import '../../core/design/porten_colors.dart';

/// 页面转场曲线（与路由/Web transition 一致：
/// cubic-bezier(0.25,0.1,0.25,1)）。
const Cubic kEmotionHistoryCurve = Cubic(0.25, 0.1, 0.25, 1);

class EmotionHistoryPage extends StatefulWidget {
  const EmotionHistoryPage({
    super.key,
    required this.visible,
    required this.cisMode,
    required this.onClose,
  });

  final bool visible;
  final bool cisMode;
  final VoidCallback onClose;

  @override
  State<EmotionHistoryPage> createState() => _EmotionHistoryPageState();
}

class _EmotionHistoryPageState extends State<EmotionHistoryPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  List<EmotionDiary> _items = <EmotionDiary>[];
  int _total = 0;
  bool _loading = false;
  bool _hasMore = false;
  int? _nextCursor;

  bool _toastVisible = false;
  PortenSystemToastType _toastType = PortenSystemToastType.loading;
  String _toastText = '';
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    _syncVisible();
  }

  @override
  void didUpdateWidget(EmotionHistoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Web 组件每次挂载（visible 打开）都会 loadHistory(true)；
    // App 侧常驻树中，用 false→true 边沿复刻「每次打开重载」。
    if (!oldWidget.visible && widget.visible) {
      _loadHistory(reset: true);
    }
    _syncVisible();
  }

  void _syncVisible() {
    if (widget.visible) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _showToast(PortenSystemToastType type, String text) {
    _toastTimer?.cancel();
    setState(() {
      _toastType = type;
      _toastText = text;
      _toastVisible = true;
    });
    _toastTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() => _toastVisible = false);
    });
  }

  /// loadHistory：reset 时整页替换；否则按 nextCursor 追加
  /// （Web fetchEmotionDiaryHistory(reset ? undefined : nextCursor)，
  /// mock 引擎忽略 cursor 返回全量，语义一致）。
  Future<void> _loadHistory({bool reset = false}) async {
    setState(() => _loading = true);
    try {
      final List<EmotionDiary> data =
          await mockFetchDiaryHistory(reset ? null : _nextCursor);
      if (!mounted) return;
      setState(() {
        _items = reset ? data : <EmotionDiary>[..._items, ...data];
        _total = data.length;
        _hasMore = data.length >= 50;
        _nextCursor = data.isNotEmpty ? data[data.length - 1].id : null;
      });
    } catch (_) {
      if (!mounted) return;
      _showToast(PortenSystemToastType.error, '加载失败');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double safeTop = MediaQuery.paddingOf(context).top;
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double t = CurvedAnimation(parent: _controller, curve: kEmotionHistoryCurve).value;
        return Positioned.fill(
          child: IgnorePointer(
            ignoring: !widget.visible,
            child: Transform.translate(
              // translate-x-full → translate-x-0。
              offset: Offset(MediaQuery.sizeOf(context).width * (1 - t), 0),
              child: ColoredBox(
                color: widget.cisMode
                    ? const Color(0xFFFAFAFA)
                    : const Color(0xFFF7F7F7),
                child: Stack(
                  children: <Widget>[
                    Column(
                      children: <Widget>[
                        _buildHeader(safeTop),
                        Expanded(child: _buildBody()),
                      ],
                    ),
                    PortenSystemToast(
                      visible: _toastVisible,
                      type: _toastType,
                      text: _toastText,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 顶栏：返回 / 「历史情绪」居中 / w-8 占位。
  Widget _buildHeader(double safeTop) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: math.max(12, safeTop), // pt-[max(0.75rem,safe-top)]
        bottom: 12, // pb-3
      ),
      decoration: const BoxDecoration(
        color: PortenColor.white,
        border: Border(bottom: BorderSide(color: PortenColor.gray100)),
      ),
      child: Row(
        children: <Widget>[
          // 返回钮：w-10 h-10 -ml-2
          Transform.translate(
            offset: const Offset(-8, 0),
            child: _PressCircle(
              onTap: widget.onClose,
              size: 40,
              child: const Center(child: PortenBackIcon(size: 28)),
            ),
          ),
          const Expanded(
            child: Text(
              '历史情绪',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18, // text-lg
                fontWeight: FontWeight.w500, // font-medium
                color: PortenColor.gray900,
              ),
            ),
          ),
          const SizedBox(width: 32), // w-8 占位
        ],
      ),
    );
  }

  /// 列表：空态 / 卡片流 / 分页尾注。
  Widget _buildBody() {
    if (_items.isEmpty && !_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 80), // py-20
        child: Center(
          child: Text(
            '还没有历史记录',
            style: TextStyle(fontSize: 14, color: PortenColor.gray400),
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < _items.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: 12), // space-y-3
            _HistoryCard(diary: _items[i], cisMode: widget.cisMode),
          ],
          if (_hasMore && _items.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _loading ? null : () => _loadHistory(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12), // py-3
                  foregroundColor: PortenColor.gray400,
                  textStyle: const TextStyle(fontSize: 14),
                ),
                child: Text(_loading ? '加载中...' : '加载更多'),
              ),
            ),
          if (!_hasMore && _items.isNotEmpty && _items.length == _total)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16), // py-4
              child: Center(
                child: Text(
                  '共 $_total 条记录',
                  style: const TextStyle(
                    fontSize: 11, // text-[11px]
                    color: PortenColor.gray300,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 历史卡片（Web HistoryCard）。
class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.diary, required this.cisMode});

  final EmotionDiary diary;
  final bool cisMode;

  @override
  Widget build(BuildContext context) {
    final MoodOption? moodOption = moodOptionOf(diary.mood);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16), // p-4
      decoration: BoxDecoration(
        color: PortenColor.white,
        borderRadius: BorderRadius.circular(16), // rounded-2xl
        border: Border.all(color: PortenColor.gray100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                formatDiaryTime(diary.createdAt),
                style: const TextStyle(
                  fontSize: 11, // text-[11px]
                  color: PortenColor.gray400,
                ),
              ),
              // 徽章：text-[10px] h-5 px-2 rounded-full
              Container(
                height: 20,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: diary.isCurrent
                      ? (cisMode
                          ? PortenColor.gray900
                          : null) // cis：bg-gray-900
                      : PortenColor.gray100,
                  gradient: diary.isCurrent && !cisMode
                      ? const LinearGradient(
                          // trans：bg-gradient #5BCEFA→#F5A9B8
                          colors: <Color>[Color(0xFF5BCEFA), Color(0xFFF5A9B8)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        )
                      : null,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  diary.isCurrent ? '当前' : '历史',
                  style: TextStyle(
                    fontSize: 10, // text-[10px]
                    color: diary.isCurrent
                        ? PortenColor.white
                        : PortenColor.gray500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8), // mb-2
          Text(
            diary.content,
            style: const TextStyle(
              fontSize: 14, // text-[14px]
              height: 28 / 14, // leading-7
              color: PortenColor.gray800,
            ),
          ),
          if (moodOption != null) ...<Widget>[
            const SizedBox(height: 12), // mt-3
            Row(
              children: <Widget>[
                Text(
                  moodOption.emoji,
                  style: const TextStyle(
                      fontSize: 12, color: PortenColor.gray500), // text-xs
                ),
                const SizedBox(width: 6), // gap-1.5
                Text(
                  moodOption.label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: PortenColor.gray500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 圆形按压反馈钮（对齐 Web active:bg-* 语义；本页按钮无 active 态，
/// 仅提供点击热区与返回/历史入口的通用容器）。
class _PressCircle extends StatefulWidget {
  const _PressCircle({
    required this.onTap,
    required this.child,
    this.size = 32,
  });

  final VoidCallback onTap;
  final Widget child;
  final double size;

  @override
  State<_PressCircle> createState() => _PressCircleState();
}

class _PressCircleState extends State<_PressCircle> {
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
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _pressed
              ? PortenColor.gray100
              : Colors.transparent, // active:bg-gray-100
        ),
        child: widget.child,
      ),
    );
  }
}
