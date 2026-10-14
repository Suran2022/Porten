/*
 * 情绪日记独立页面（100% 复刻 Web 端 components/home/EmotionDiaryPage.tsx）。
 *
 * Web 结构（逐项对应）：
 *   - 根 fixed inset-0 z-[68] flex flex-col，translate-x-full → 0
 *     300ms cubic-bezier(0.25,0.1,0.25,1)——App 端由路由
 *     PortenSlideFromRightRoute 承担同曲线转场，页面内部不重复；
 *   - 背景 cisMode ? bg-[#fafafa] : bg-[#f7f7f7]
 *     （isCisGender：cis_female/cis_male → 顺肤色主题；App 侧性别
 *     来源为 profileEditProvider，与资料编辑页实时一致）；
 *   - 顶栏：返回钮（w-10 h-10 -ml-2，BackIcon w-7 h-7）+ 居中
 *     「情绪日记」（text-lg font-medium text-gray-900）+ 历史钮
 *     （w-8 h-8 -mr-2，History w-5 h-5 strokeWidth 1.5 gray-900）；
 *     px-4 pt-[max(0.75rem,safe-top)] pb-3 bg-white
 *     border-b border-gray-100；
 *   - 主体 flex-1 overflow-y-auto：loading → 「加载中...」
 *     （py-16 text-center text-sm gray-400）；showEditForm
 *     （!current || isEditing）→ EditForm；否则 DiaryCard；
 *   - EditForm：px-4 py-5 space-y-5；
 *     - 「现在感觉…」text-xs gray-500 mb-2.5 + 心情钮：短标签
 *       （≤2 字）grid-cols-3 gap-2.5，长标签（>2 字）flex-wrap
 *       gap-2.5 mt-2.5；MoodButton h-10 px-3 rounded-full gap-2
 *       whitespace-nowrap transition-colors(150ms)：选中态 cis ?
 *       黑灰渐变(from-gray-800 to-gray-600) : 粉蓝渐变
 *       (from-#F5A9B8 to-#5BCEFA) + 白字 + (跨性别) inset 1px
 *       白 40% 描边；未选中 text-gray-600 bg-white/60 border
 *       gray-200；emoji text-lg leading-none + label text-sm；
 *     - 「记录今天的心情」+ textarea（px-4 py-3 bg-white/40
 *       border gray-200 rounded-2xl text-[15px] gray-900
 *       placeholder gray-300 rows=8 maxLength 4000）+ 右下角
 *       计数器 text-[11px] gray-400 {len}/4000；
 *     - 按钮行 gap-3：取消（onCancel 存在时，h-12 px-5 rounded-full
 *       text-sm font-medium gray-700 bg-white border gray-200）+
 *       保存（flex-1 h-12 rounded-full text-base font-medium
 *       text-white：saving ? bg-gray-300 : cis ? bg-gray-900
 *       active:bg-gray-700 : 粉蓝渐变 active:opacity-90；文案
 *       saving ?「保存中...」: isFirstTime ?「保存」:「保存修改」）；
 *   - DiaryCard：px-4 py-5 space-y-4；
 *     - 卡片1 rounded-2xl bg-white p-5 border-gray-100：mood chip
 *       （h-7 px-3 rounded-full text-xs gap-1.5：cis ? bg-gray-100 :
 *       粉蓝 15% 渐变底，gray-700 字，emoji + 「现在 label」）+
 *       铅笔钮（w-8 h-8 rounded-full gray-400 active:bg-gray-100，
 *       Pencil w-4 h-4 strokeWidth 1.6）；正文 text-[15px]
 *       gray-800 leading-7 whitespace-pre-wrap；底行 time
 *       text-[11px] gray-400（updated_at）+「修改」钮（h-8 px-4
 *       rounded-full text-xs font-medium：cis ? bg-gray-900 白字
 *       active:bg-gray-700 : 粉蓝渐变白字 active:opacity-90）；
 *     - 卡片2（观众）rounded-2xl bg-white p-5 border-gray-100：
 *       「谁看过这条」text-sm font-medium gray-900 + 「N 人」
 *       text-xs gray-400；grid-cols-4 gap-y-4 头像（w-12 h-12
 *       圆形 object-cover bg-gray-100 mb-1.5）+ 昵称（text-xs
 *       gray-700 truncate px-1）；空态「暂时还没有人查看」
 *       （py-6 text-center text-sm gray-400）；底部分隔线 +
 *       右对齐「删除这条日记」（text-xs red-500 active:opacity-70）；
 *   - 删除确认：Web window.confirm → App AlertDialog（取消/删除）；
 *   - SystemToast（z-[80]）：空内容 → error「请写下今天的心情」；
 *     超 4000 字 → error「内容最多 4000 字」；保存成功 →
 *     success「已保存」；删除成功 → success「已删除」；失败 →
 *     error「保存失败」/「删除失败」；1500ms 自动隐藏；
 *   - EmotionHistoryPage（z-[78]，内含自身 SystemToast）；
 *   - 数据：打开页面 loadCurrent（current = is_current 日记）+
 *     loadViewers；保存/更新后同步 currentUserDiaryProvider
 *     （Web updateUser 同步个人中心「最新日记」+ mood）；删除后
 *     清空 provider。mock 引擎延迟 140~360ms 与 Web 一致。
 */

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/components/porten_back_icon.dart';
import '../../core/components/porten_lucide_icons.dart';
import '../../core/components/porten_system_toast.dart';
import '../../core/data/current_user_store.dart';
import '../../core/data/emotion_diary_mock.dart';
import '../../core/design/porten_colors.dart';
import '../../features/profile/state/profile_edit_provider.dart';
import 'emotion_history_page.dart';

/// 内容上限（Web MAX_CONTENT = 4000，textarea maxLength 同值）。
const int kMaxDiaryContent = 4000;

class EmotionDiaryPage extends ConsumerStatefulWidget {
  const EmotionDiaryPage({super.key});

  @override
  ConsumerState<EmotionDiaryPage> createState() => _EmotionDiaryPageState();
}

class _EmotionDiaryPageState extends ConsumerState<EmotionDiaryPage> {
  /// 当前日记（Web current；null = 未发布态）。
  EmotionDiary? _current;

  /// Web loading：控制「加载中...」占位。
  bool _loading = false;

  /// Web isEditing：已发布态的修改展开态。
  bool _isEditing = false;

  /// Web draftMood（初始 'happy'，enterEdit 时按当前日记重置）。
  String _draftMood = 'happy';

  /// Web saving：保存中（按钮禁用 + 灰底）。
  bool _saving = false;

  /// 观众列表（Web viewers/viewerTotal/loadingViewers）。
  List<EmotionDiaryViewer> _viewers = const <EmotionDiaryViewer>[];
  int _viewerTotal = 0;
  bool _loadingViewers = false;

  /// 历史页可见态（Web historyVisible）。
  bool _historyVisible = false;

  /// Toast 状态（Web toastVisible/toastType/toastText + 1500ms 定时器）。
  bool _toastVisible = false;
  PortenSystemToastType _toastType = PortenSystemToastType.loading;
  String _toastText = '';
  Timer? _toastTimer;

  /// 正文草稿（Web draftContent 受控态，App 侧用 controller 承载）。
  final TextEditingController _contentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 草稿变化驱动计数器与页面重建（Web 受控 value/onChange）。
    _contentController.addListener(_onDraftChanged);
    // Web useEffect([visible]) 在首帧绘制后触发 loadCurrent；App 侧
    // 用 post-frame callback 复刻同一时序（首帧先渲染未发布态表单）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_loadCurrent());
    });
  }

  void _onDraftChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _contentController.dispose();
    super.dispose();
  }

  // ==================== 数据（对齐 Web loadCurrent/loadViewers） ====================

  Future<void> _loadCurrent() async {
    setState(() => _loading = true);
    try {
      final EmotionDiary? data = await mockFetchCurrentDiary();
      if (!mounted) return;
      setState(() => _current = data);
      if (data != null) {
        await _loadViewers(data.id);
      } else {
        setState(() {
          _viewers = const <EmotionDiaryViewer>[];
          _viewerTotal = 0;
        });
      }
    } catch (_) {
      if (!mounted) return;
      _showToast(PortenSystemToastType.error, '加载失败');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadViewers(int diaryId) async {
    setState(() => _loadingViewers = true);
    try {
      final List<EmotionDiaryViewer> data = await mockFetchDiaryViewers();
      if (!mounted) return;
      setState(() {
        _viewers = data;
        _viewerTotal = data.length;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _viewers = const <EmotionDiaryViewer>[];
        _viewerTotal = 0;
      });
    } finally {
      if (mounted) setState(() => _loadingViewers = false);
    }
  }

  // ==================== 交互（对齐 Web handlers） ====================

  /// enterEdit：草稿重置为当前日记（无日记 → happy + 空）。
  void _enterEdit() {
    final EmotionDiary? current = _current;
    setState(() {
      _draftMood = current?.mood ?? 'happy';
      _contentController.text = current?.content ?? '';
      _isEditing = true;
    });
  }

  /// cancelEdit：收起修改展开态（仅已发布态有取消钮）。
  void _cancelEdit() {
    setState(() => _isEditing = false);
  }

  /// handleSave：空内容/超长 → error toast；否则创建或更新当前日记，
  /// 同步个人中心 store（Web updateUser），成功后刷新观众。
  Future<void> _handleSave() async {
    final String content = _contentController.text.trim();
    if (content.isEmpty) {
      _showToast(PortenSystemToastType.error, '请写下今天的心情');
      return;
    }
    if (content.length > kMaxDiaryContent) {
      _showToast(PortenSystemToastType.error, '内容最多 $kMaxDiaryContent 字');
      return;
    }
    setState(() => _saving = true);
    try {
      final EmotionDiary? current = _current;
      final EmotionDiary diary = current != null
          ? await mockUpdateCurrentDiary(
              content: content,
              mood: _draftMood,
              isPublic: current.isPublic,
            )
          : await mockCreateDiary(content: content, mood: _draftMood);
      if (!mounted) return;
      setState(() {
        _current = diary;
        _isEditing = false;
      });
      _showToast(PortenSystemToastType.success, '已保存');
      // 同步个人中心「最新日记」+ mood（Web updateUser）。
      ref
          .read(currentUserDiaryProvider.notifier)
          .updateFromDiary(mood: diary.mood, content: diary.content);
      await _loadViewers(diary.id);
    } catch (_) {
      if (!mounted) return;
      _showToast(PortenSystemToastType.error, '保存失败');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// handleDelete：确认弹窗（Web window.confirm）→ 删除 → 清空状态
  /// 与个人中心 store。
  Future<void> _handleDelete() async {
    final EmotionDiary? current = _current;
    if (current == null) return;
    final bool confirmed = await _confirmDeleteDiary();
    if (!confirmed) return;
    try {
      await mockDeleteDiary(current.id);
      if (!mounted) return;
      setState(() {
        _current = null;
        _viewers = const <EmotionDiaryViewer>[];
        _viewerTotal = 0;
        _isEditing = false;
      });
      _showToast(PortenSystemToastType.success, '已删除');
      // 清空个人中心「最新日记」+ mood（Web updateUser）。
      ref.read(currentUserDiaryProvider.notifier).clear();
    } catch (_) {
      if (!mounted) return;
      _showToast(PortenSystemToastType.error, '删除失败');
    }
  }

  /// 删除确认弹窗（Web window.confirm 的原生等价）。
  Future<bool> _confirmDeleteDiary() async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: PortenColor.white,
          surfaceTintColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          content: const Text(
            '确定删除这条情绪日记？',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: PortenColor.gray800,
              height: 1.5,
            ),
          ),
          actions: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      foregroundColor: PortenColor.gray500,
                      textStyle: const TextStyle(fontSize: 14),
                    ),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      foregroundColor: PortenColor.error,
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    child: const Text('删除'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  /// showToast：1500ms 自动隐藏（Web TOAST_AUTO_HIDE_MS）。
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

  // ==================== 构建 ====================

  @override
  Widget build(BuildContext context) {
    final double safeTop = MediaQuery.paddingOf(context).top;
    // cisMode：性别来自资料编辑 provider（Web authStore user.gender）。
    final bool cisMode =
        isCisGender(ref.watch(profileEditProvider).genderValue);

    return Scaffold(
      backgroundColor:
          cisMode ? const Color(0xFFFAFAFA) : const Color(0xFFF7F7F7),
      body: Stack(
        children: <Widget>[
          Column(
            children: <Widget>[
              _buildHeader(safeTop),
              Expanded(child: _buildBody(cisMode)),
            ],
          ),
          // 历史情绪页（Web z-[78]，内含自身 SystemToast z-[80]，
          // 层级高于本页内容与本页 toast）。
          EmotionHistoryPage(
            visible: _historyVisible,
            cisMode: cisMode,
            onClose: () => setState(() => _historyVisible = false),
          ),
          // SystemToast（Web z-[80]）。
          PortenSystemToast(
            visible: _toastVisible,
            type: _toastType,
            text: _toastText,
          ),
        ],
      ),
    );
  }

  /// 顶栏：返回 / 「情绪日记」居中 / 历史。
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
              onTap: () => Navigator.of(context).maybePop(),
              size: 40,
              child: const Center(child: PortenBackIcon(size: 28)),
            ),
          ),
          const Expanded(
            child: Text(
              '情绪日记',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18, // text-lg
                fontWeight: FontWeight.w500, // font-medium
                color: PortenColor.gray900,
              ),
            ),
          ),
          // 历史钮：w-8 h-8 -mr-2
          Transform.translate(
            offset: const Offset(8, 0),
            child: _PressCircle(
              onTap: () => setState(() => _historyVisible = true),
              size: 32,
              child: const Center(
                child: PortenLucideIcon('history',
                    size: 20, color: PortenColor.gray900, strokeWidth: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 主体：加载占位 / 编辑表单 / 日记卡。
  Widget _buildBody(bool cisMode) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 64), // py-16
        child: Center(
          child: Text(
            '加载中...',
            style: TextStyle(fontSize: 14, color: PortenColor.gray400),
          ),
        ),
      );
    }
    final bool showEditForm = _current == null || _isEditing;
    if (showEditForm) {
      return SingleChildScrollView(
        child: _EmotionEditForm(
          cisMode: cisMode,
          mood: _draftMood,
          contentController: _contentController,
          saving: _saving,
          isFirstTime: _current == null,
          onChangeMood: (String value) =>
              setState(() => _draftMood = value),
          onSave: () => unawaited(_handleSave()),
          onCancel: _current != null ? _cancelEdit : null,
        ),
      );
    }
    final EmotionDiary diary = _current!;
    return SingleChildScrollView(
      child: _DiaryCard(
        diary: diary,
        cisMode: cisMode,
        viewers: _viewers,
        viewerTotal: _viewerTotal,
        loadingViewers: _loadingViewers,
        onEdit: _enterEdit,
        onDelete: () => unawaited(_handleDelete()),
      ),
    );
  }
}

/* ====================== Edit form（未发布态 / 修改展开态） ====================== */

class _EmotionEditForm extends StatelessWidget {
  const _EmotionEditForm({
    required this.cisMode,
    required this.mood,
    required this.contentController,
    required this.saving,
    required this.isFirstTime,
    required this.onChangeMood,
    required this.onSave,
    this.onCancel,
  });

  final bool cisMode;
  final String mood;
  final TextEditingController contentController;
  final bool saving;
  final bool isFirstTime;
  final ValueChanged<String> onChangeMood;
  final VoidCallback onSave;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    // 短标签（≤2 字）→ 3 列网格；长标签（>2 字）→ 末行自动撑开。
    final List<MoodOption> shortOptions = kMoodOptions
        .where((MoodOption o) => o.label.length <= 2)
        .toList(growable: false);
    final List<MoodOption> longOptions = kMoodOptions
        .where((MoodOption o) => o.label.length > 2)
        .toList(growable: false);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // 心情标签区
          const Text(
            '现在感觉…',
            style: TextStyle(fontSize: 12, color: PortenColor.gray500),
          ),
          const SizedBox(height: 10), // mb-2.5
          for (int i = 0; i < shortOptions.length; i += 3) ...<Widget>[
            if (i > 0) const SizedBox(height: 10), // gap-2.5
            Row(
              children: <Widget>[
                for (int j = i; j < i + 3 && j < shortOptions.length; j++) ...<Widget>[
                  if (j > i) const SizedBox(width: 10),
                  Expanded(
                    child: _MoodButton(
                      option: shortOptions[j],
                      active: mood == shortOptions[j].value,
                      cisMode: cisMode,
                      stretch: true, // 网格单元格撑满
                      onClick: () => onChangeMood(shortOptions[j].value),
                    ),
                  ),
                ],
              ],
            ),
          ],
          if (longOptions.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10), // mt-2.5
            Wrap(
              spacing: 10, // gap-2.5
              runSpacing: 10,
              children: <Widget>[
                for (final MoodOption option in longOptions)
                  _MoodButton(
                    option: option,
                    active: mood == option.value,
                    cisMode: cisMode,
                    stretch: false, // flex-wrap 内容宽度
                    onClick: () => onChangeMood(option.value),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 20), // space-y-5
          // 正文输入区
          const Text(
            '记录今天的心情',
            style: TextStyle(fontSize: 12, color: PortenColor.gray500),
          ),
          const SizedBox(height: 10), // mb-2.5
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.4), // bg-white/40
              borderRadius: BorderRadius.circular(16), // rounded-2xl
              border: Border.all(color: PortenColor.gray200),
            ),
            child: TextField(
              controller: contentController,
              maxLines: 8, // rows=8（超出内部滚动，对齐 textarea）
              maxLength: kMaxDiaryContent,
              cursorColor: PortenColor.gray900,
              style: const TextStyle(
                fontSize: 15, // text-[15px]
                color: PortenColor.gray900,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                // 计数器自绘在输入框外右下角（Web 同款），禁用内置计数器。
                counter: const SizedBox.shrink(),
                hintText: '今天发生了什么？你的感受是什么？',
                hintStyle: const TextStyle(
                  fontSize: 15,
                  color: PortenColor.gray300, // placeholder:text-gray-300
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6), // mt-1.5
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${contentController.text.length}/$kMaxDiaryContent',
                style: const TextStyle(
                  fontSize: 11, // text-[11px]
                  color: PortenColor.gray400,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20), // space-y-5
          // 按钮行
          Row(
            children: <Widget>[
              if (onCancel != null) ...<Widget>[
                // 取消：h-12 px-5 rounded-full text-sm font-medium
                // text-gray-700 bg-white border border-gray-200
                // （Web 无 active 态，不加按压反馈）
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onCancel,
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: PortenColor.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: PortenColor.gray200),
                    ),
                    child: const Text(
                      '取消',
                      style: TextStyle(
                        fontSize: 14, // text-sm
                        fontWeight: FontWeight.w500, // font-medium
                        color: PortenColor.gray700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12), // gap-3
              ],
              Expanded(
                child: _PressBox(
                  onTap: saving ? null : onSave,
                  disabled: saving,
                  normalColor: saving
                      ? PortenColor.gray300
                      : (cisMode ? PortenColor.gray900 : null),
                  activeColor:
                      cisMode && !saving ? PortenColor.gray700 : null,
                  gradient: !saving && !cisMode
                      ? const LinearGradient(
                          // 跨性别：粉蓝渐变 #5BCEFA→#F5A9B8
                          colors: <Color>[Color(0xFF5BCEFA), Color(0xFFF5A9B8)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        )
                      : null,
                  activeOpacity: !saving && !cisMode ? 0.9 : null,
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    height: 48, // h-12
                    child: Center(
                      child: Text(
                        saving
                            ? '保存中...'
                            : (isFirstTime ? '保存' : '保存修改'),
                        style: const TextStyle(
                          fontSize: 16, // text-base
                          fontWeight: FontWeight.w500, // font-medium
                          color: PortenColor.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 心情钮（Web MoodButton：左右结构 + transition-colors）。
///
/// [stretch] = true 时撑满网格单元格（grid 列等宽）；false 时取
/// 内容宽度（flex-wrap 行内）。
class _MoodButton extends StatelessWidget {
  const _MoodButton({
    required this.option,
    required this.active,
    required this.cisMode,
    required this.stretch,
    required this.onClick,
  });

  final MoodOption option;
  final bool active;
  final bool cisMode;
  final bool stretch;
  final VoidCallback onClick;

  @override
  Widget build(BuildContext context) {
    // 选中态渐变：cis 黑灰 / 跨性别粉蓝。
    final Gradient? activeGradient = active
        ? LinearGradient(
            colors: cisMode
                ? const <Color>[PortenColor.gray800, PortenColor.gray600]
                : const <Color>[Color(0xFFF5A9B8), Color(0xFF5BCEFA)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          )
        : null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onClick,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150), // transition-colors
        curve: Curves.ease,
        height: 40, // h-10
        padding: const EdgeInsets.symmetric(horizontal: 12), // px-3
        decoration: BoxDecoration(
          gradient: activeGradient,
          color: active ? null : Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(999), // rounded-full
          // 跨性别选中态：inset 0 0 0 1px rgba(255,255,255,0.4)
          // （Flutter 以 1px 白描边等价）。
          border: active
              ? (cisMode
                  ? null
                  : Border.all(color: Colors.white.withValues(alpha: 0.4)))
              : Border.all(color: PortenColor.gray200),
        ),
        child: Row(
          mainAxisSize: stretch ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              option.emoji,
              style: const TextStyle(
                fontSize: 18, // text-lg
                height: 1, // leading-none
              ),
            ),
            const SizedBox(width: 8), // gap-2
            Text(
              option.label,
              style: TextStyle(
                fontSize: 14, // text-sm
                color: active ? PortenColor.white : PortenColor.gray600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ====================== Diary card（已发布态） ====================== */

class _DiaryCard extends StatelessWidget {
  const _DiaryCard({
    required this.diary,
    required this.cisMode,
    required this.viewers,
    required this.viewerTotal,
    required this.loadingViewers,
    required this.onEdit,
    required this.onDelete,
  });

  final EmotionDiary diary;
  final bool cisMode;
  final List<EmotionDiaryViewer> viewers;
  final int viewerTotal;
  final bool loadingViewers;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final MoodOption? moodOption = moodOptionOf(diary.mood);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        children: <Widget>[
          // 卡片1：日记本体
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20), // p-5
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
                    if (moodOption != null)
                      // mood chip：h-7 px-3 rounded-full text-xs gap-1.5
                      Container(
                        height: 28,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: cisMode ? PortenColor.gray100 : null,
                          gradient: cisMode
                              ? null
                              : const LinearGradient(
                                  // 跨性别：粉蓝 15% 渐变底
                                  colors: <Color>[
                                    Color(0x26F5A9B8),
                                    Color(0x265BCEFA)
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          children: <Widget>[
                            Text(
                              moodOption.emoji,
                              style: const TextStyle(
                                fontSize: 12, // text-xs
                                color: PortenColor.gray700,
                              ),
                            ),
                            const SizedBox(width: 6), // gap-1.5
                            Text(
                              '现在 ${moodOption.label}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: PortenColor.gray700,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      const SizedBox.shrink(), // Web <span /> 占位
                    // 铅笔钮：w-8 h-8 rounded-full text-gray-400
                    // active:bg-gray-100，Pencil w-4 h-4 1.6
                    _PressCircle(
                      onTap: onEdit,
                      size: 32,
                      child: const Center(
                        child: PortenLucideIcon('pencil',
                            size: 16,
                            color: PortenColor.gray400,
                            strokeWidth: 1.6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12), // mb-3
                // 正文：text-[15px] gray-800 leading-7 pre-wrap
                Text(
                  diary.content,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 28 / 15, // leading-7
                    color: PortenColor.gray800,
                  ),
                ),
                const SizedBox(height: 16), // mt-4
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      // Web: updated_at || created_at
                      formatDiaryTime(diary.updatedAt),
                      style: const TextStyle(
                        fontSize: 11, // text-[11px]
                        color: PortenColor.gray400,
                      ),
                    ),
                    // 修改钮：h-8 px-4 rounded-full text-xs font-medium
                    _PressBox(
                      onTap: onEdit,
                      normalColor:
                          cisMode ? PortenColor.gray900 : null,
                      activeColor:
                          cisMode ? PortenColor.gray700 : null,
                      gradient: cisMode
                          ? null
                          : const LinearGradient(
                              colors: <Color>[
                                Color(0xFF5BCEFA),
                                Color(0xFFF5A9B8)
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                      activeOpacity: cisMode ? null : 0.9,
                      borderRadius: BorderRadius.circular(999),
                      child: SizedBox(
                        height: 32, // h-8
                        child: Center(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16), // px-4
                            child: const Text(
                              '修改',
                              style: TextStyle(
                                fontSize: 12, // text-xs
                                fontWeight: FontWeight.w500, // font-medium
                                color: PortenColor.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16), // space-y-4
          // 卡片2：谁看过
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20), // p-5
            decoration: BoxDecoration(
              color: PortenColor.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: PortenColor.gray100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    const Text(
                      '谁看过这条',
                      style: TextStyle(
                        fontSize: 14, // text-sm
                        fontWeight: FontWeight.w500, // font-medium
                        color: PortenColor.gray900,
                      ),
                    ),
                    Text(
                      '$viewerTotal 人',
                      style: const TextStyle(
                        fontSize: 12, // text-xs
                        color: PortenColor.gray400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12), // mb-3
                if (loadingViewers)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24), // py-6
                    child: Center(
                      child: Text(
                        '加载中...',
                        style: TextStyle(
                            fontSize: 14, color: PortenColor.gray400),
                      ),
                    ),
                  )
                else if (viewers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24), // py-6
                    child: Center(
                      child: Text(
                        '暂时还没有人查看',
                        style: TextStyle(
                            fontSize: 14, color: PortenColor.gray400),
                      ),
                    ),
                  )
                else
                  // grid-cols-4 gap-y-4（横向无间距）
                  Column(
                    children: <Widget>[
                      for (int i = 0; i < viewers.length; i += 4) ...<Widget>[
                        if (i > 0) const SizedBox(height: 16), // gap-y-4
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            for (int j = i;
                                j < i + 4 && j < viewers.length;
                                j++) ...<Widget>[
                              Expanded(child: _ViewerItem(viewer: viewers[j])),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                const SizedBox(height: 16), // mt-4
                // 底部分隔线 + 右对齐删除
                Container(
                  padding: const EdgeInsets.only(top: 12), // mt-4 pt-3
                  decoration: const BoxDecoration(
                    border: Border(
                        top: BorderSide(color: PortenColor.gray100)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      // 删除这条日记：text-xs red-500 active:opacity-70
                      _PressBox(
                        onTap: onDelete,
                        activeOpacity: 0.7,
                        child: const Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          child: Text(
                            '删除这条日记',
                            style: TextStyle(
                              fontSize: 12, // text-xs
                              color: PortenColor.error, // red-500
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 观众项（上下结构：头像在上、昵称在下）。
class _ViewerItem extends StatelessWidget {
  const _ViewerItem({required this.viewer});

  final EmotionDiaryViewer viewer;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        // 头像：w-12 h-12 rounded-full object-cover bg-gray-100
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: PortenColor.gray100,
            image: DecorationImage(
              image: AssetImage(viewer.avatarAsset),
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 6), // mb-1.5
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4), // px-1
          child: Text(
            viewer.nickname,
            maxLines: 1,
            overflow: TextOverflow.ellipsis, // truncate
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12, // text-xs
              color: PortenColor.gray700,
            ),
          ),
        ),
      ],
    );
  }
}

/* ====================== 通用按压反馈 ====================== */

/// 圆形按压反馈钮（对齐 Web active:bg-*）。
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150), // transition-colors
        curve: Curves.ease,
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _pressed ? PortenColor.gray100 : Colors.transparent,
        ),
        child: widget.child,
      ),
    );
  }
}

/// 按压反馈容器（对齐 Web active:bg-* / active:opacity-*）：
/// onTapDown/Up/Cancel 切换按压态；[activeColor] 换底色（150ms
/// 过渡，对齐 transition-colors）；[activeOpacity] 换不透明度
/// （Web active:opacity-* 无 transition，即时切换）。
class _PressBox extends StatefulWidget {
  const _PressBox({
    required this.onTap,
    required this.child,
    this.normalColor = Colors.transparent,
    this.activeColor,
    this.gradient,
    this.activeOpacity,
    this.borderRadius,
    this.disabled = false,
  });

  final VoidCallback? onTap;
  final Widget child;

  /// 常态底色（activeColor 为 null 时按压不换色）。
  final Color? normalColor;

  /// 按压底色（cis 主题 active:bg-gray-700）。
  final Color? activeColor;

  /// 渐变底（跨性别主题；与 normalColor 互斥）。
  final Gradient? gradient;

  /// 按压不透明度（跨性别主题 active:opacity-90）。
  final double? activeOpacity;

  final BorderRadius? borderRadius;
  final bool disabled;

  @override
  State<_PressBox> createState() => _PressBoxState();
}

class _PressBoxState extends State<_PressBox> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (mounted && _pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasColorSwap = widget.activeColor != null;
    final Color? color = hasColorSwap
        ? (_pressed ? widget.activeColor : widget.normalColor)
        : widget.normalColor;
    Widget box = Container(
      decoration: BoxDecoration(
        color: color,
        gradient: widget.gradient,
        borderRadius: widget.borderRadius,
      ),
      child: widget.child,
    );
    if (hasColorSwap) {
      box = AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.ease,
        decoration: BoxDecoration(
          color: color,
          gradient: widget.gradient,
          borderRadius: widget.borderRadius,
        ),
        child: widget.child,
      );
    }
    if (widget.activeOpacity != null) {
      box = Opacity(
        opacity: _pressed ? widget.activeOpacity! : 1.0,
        child: box,
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.disabled ? null : (_) => _setPressed(true),
      onTapUp: widget.disabled ? null : (_) => _setPressed(false),
      onTapCancel: widget.disabled ? null : () => _setPressed(false),
      onTap: widget.disabled ? null : widget.onTap,
      child: box,
    );
  }
}
