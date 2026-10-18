/*
 * 记笔记独立页面（100% 复刻 Web 端 components/home/NotesPage.tsx）。
 *
 * Web 端结构（逐项对应）：
 *   - 根容器 fixed inset-0 z-[95] bg-white，translate-x-full → 0 进场
 *     （300ms cubic-bezier(0.25,0.1,0.25,1)）——App 端由路由
 *     PortenSlideFromRightRoute 承担同曲线转场，页面内部不重复；
 *   - 顶部装饰：absolute left-0 top-0 w-full，高度 39%，145deg 五段色标
 *     线性渐变（#5BCEFA/.30 → #8BCCEE/.27 → #F5A9B8/.30 → #F8C6D1/.18 →
 *     透明），mask-image 垂直五段渐隐（#000 0%→55%、0.6 78%、0.25 92%、
 *     transparent 100%）——Flutter 用 ShaderMask(dstIn) 复刻 mask；
 *   - 顶栏 h-16：返回钮（h-9 w-9 -ml-2 rounded-full active:bg-white/45，
 *     BackIcon w-7 h-7）+ 绝对居中「我的笔记」（text-lg font-semibold）
 *     + 右「添加笔记」胶囊（h-9 gap-1.5 rounded-full bg-gray-500/10
 *     px-3 text-sm font-medium text-gray-700，Plus h-4 w-4 strokeWidth 1.8，
 *     active:bg-gray-500/20）；
 *   - 列表 main：mx-auto max-w-md space-y-3 px-4 pt-3
 *     pb-[max(2rem,env(safe-area-inset-bottom))]；卡片 rounded-[6px]
 *     bg-white px-4 py-3.5（archived → opacity-65）；正文 text-[15px]
 *     leading-6 三行截断；more 钮（-mr-2 -mt-1 h-8 w-8 rounded-full
 *     text-gray-400 active:bg-gray-100，MoreHorizontal h-5 w-5 1.7）；
 *     底行 time text-xs gray-400 + 已归档徽章 + 标签 chips
 *     （rounded-full px-2 py-0.5 text-[11px] font-medium，6 色 hash）；
 *   - 卡片下拉菜单：absolute right-3 top-10 z-30 w-36 rounded-xl bg-white
 *     py-1 ring-1 ring-black/5（overflow-hidden）；三项 px-3 py-2.5
 *     text-sm gap-2.5：编辑笔记(Pencil 1.7)/归档笔记·取消归档
 *     (Archive/ArchiveRestore 1.7)/删除笔记(Trash2 1.7, text-red-500
 *     active:bg-red-50/60)。Web 中菜单是卡片内的 absolute 元素，
 *     可溢出 article 边界且仍可点击；Flutter RenderBox.hitTest 先做
 *     size.contains 边界检查，越界即整棵子树不可命中，而卡片 Stack
 *     按内容定高（约 80px）放不下 top-10 起、高约 128px 的菜单。
 *     故 App 端把菜单提升到滚动内容级 Stack 渲染，用 GlobalKey 取
 *     卡片矩形换算定位（详见 [_cardKeys] 与 [_cardAnchorInContent]）：
 *     菜单随内容自然滚动（与 Web absolute 语义一致），内容 Stack
 *     bounds 覆盖菜单区，最后一张卡片菜单溢出内容底部的部分由
 *     滚动视口裁剪（与 Web scrollport 行为等效）；
 *   - 编辑器覆盖层：absolute inset-0 z-40 flex flex-col bg-white，
 *     translate-x-full → translate-x-0 300ms 同曲线（App 端内部
 *     AnimationController 复刻；隐藏态 pointer-events-none 等价
 *     IgnorePointer）；头部 X 钮（h-9 w-9 -ml-2 rounded-full
 *     active:bg-gray-100，X h-5 w-5 1.7）+ 居中「编辑笔记/添加笔记」
 *     + 完成钮（h-9 gap-1.5 rounded-full bg-gray-900 px-3 text-sm
 *     text-white，Check h-4 w-4 1.8；disabled: bg-gray-200 text-gray-400）；
 *     textarea min-h-[240px] rounded-[6px] bg-gray-50/80 p-4 text-[15px]
 *     leading-7 placeholder:text-gray-300 autoFocus；标签 label
 *     （mt-5 text-xs text-gray-500）+ input（mt-2 h-11 bg-gray-50/80
 *     px-4 text-sm text-gray-700）；
 *   - 交互：根点击关闭下拉；保存时标签按 、 , ， 空白切分至多 4 个，
 *     新建分支空则回退「随记」、编辑分支允许清空（与 Web 逐分支一致）；
 *     编辑同步刷新 time 为「今天 HH:mm」；新笔记 unshift（Date.now() id）。
 *
 * 按压反馈（Web active:bg-*）：GestureDetector onTapDown/Up/Cancel
 * 切换底色（沿用项目 _SecurityOptionRow 范式）。
 */

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/components/porten_back_icon.dart';
import '../../core/components/porten_lucide_icons.dart';
import '../../core/components/porten_toast.dart';
import '../../core/data/notes_controller.dart';
import '../../core/data/notes_mock.dart';
import '../../core/design/porten_colors.dart';

/// red-50（Web active:bg-red-50/60 的底色）。
const Color _kRed50 = Color(0xFFFEF2F2);

class NotesPage extends ConsumerStatefulWidget {
  const NotesPage({super.key});

  @override
  ConsumerState<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends ConsumerState<NotesPage>
    with SingleTickerProviderStateMixin {
  /// 当前展开下拉菜单的笔记 id（Web activeMenuId）。
  int? _activeMenuId;

  /// 卡片锚点 key：noteId → GlobalKey（Web 无对应物）。
  ///
  /// Web 端下拉菜单是卡片内的 absolute 元素，可溢出 article 边界
  /// 且仍可点击（DOM 无命中测试 bounds 限制）；Flutter 的
  /// RenderBox.hitTest 先做 size.contains 边界检查，越界即整棵
  /// 子树（含 Positioned 溢出子节点）不可命中——卡片 Stack 按
  /// 内容定高（约 80px），top-10 起、高约 128px 的菜单溢出部分
  /// 将点不到。因此菜单提升到滚动内容级 Stack 渲染，通过每张
  /// 卡片的 GlobalKey 取矩形换算菜单坐标。
  final Map<int, GlobalKey> _cardKeys = <int, GlobalKey>{};

  /// 内容级 Stack 的 key（菜单位置换算基准）。
  final GlobalKey _contentStackKey = GlobalKey();

  /// 下拉菜单锚点矩形（内容级 Stack 局部坐标，more 钮点击时计算）。
  ///
  /// 菜单挂在滚动内容内，随内容自然滚动，与 Web absolute 语义
  /// 一致；最后一张卡片菜单溢出内容底部的部分由滚动视口裁剪，
  /// 与 Web scrollport 行为等效。
  Rect? _menuAnchor;

  /// 正在编辑的笔记（null = 新建，Web editingNote）。
  NoteItem? _editingNote;

  /// Web editorVisible：编辑器语义可见态（驱动 pointer-events-none）。
  bool _editorVisible = false;

  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final FocusNode _contentFocusNode = FocusNode();

  /// 编辑器覆盖层转场：300ms cubic-bezier(0.25,0.1,0.25,1)
  /// （与 Web transition-transform duration-300 同参数）。
  late final AnimationController _editorController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  Animation<double> get _editorSlide =>
      CurvedAnimation(parent: _editorController, curve: kPortenNoteCurve);

  @override
  void initState() {
    super.initState();
    // 草稿变化驱动「完成」钮 disabled 态（Web disabled={!draftContent.trim()}）。
    _contentController.addListener(_onDraftChanged);
  }

  void _onDraftChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _contentController.removeListener(_onDraftChanged);
    _contentController.dispose();
    _tagsController.dispose();
    _contentFocusNode.dispose();
    _editorController.dispose();
    super.dispose();
  }

  // ==================== 交互（对齐 Web 端 handlers） ====================

  /// openEditor：重置草稿 → 关闭下拉 → 编辑器可见 → 自动聚焦
  /// （Web autoFocus={editorVisible}）。
  void _openEditor([NoteItem? note]) {
    setState(() {
      _editingNote = note;
      _contentController.text = note?.content ?? '';
      _tagsController.text = note?.tags.join('、') ?? '';
      _activeMenuId = null;
      _editorVisible = true;
    });
    _editorController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _contentFocusNode.requestFocus();
    });
  }

  /// 关闭编辑器（X 钮）：滑出 + 收起键盘。
  void _closeEditor() {
    setState(() => _editorVisible = false);
    _editorController.reverse();
    _contentFocusNode.unfocus();
  }

  /// saveNote：空内容直接返回；标签切分至多 4 个（新建分支空则回退
  /// 「随记」、编辑分支允许清空）；提交笔记控制器（mock 写 NoteStore /
  /// live 走 data 桥），列表经共享控制器自动刷新。
  Future<void> _saveNote() async {
    final String content = _contentController.text.trim();
    if (content.isEmpty) return;
    final NoteItem? editing = _editingNote;
    final String tagsText = _tagsController.text;
    try {
      final NotesController controller =
          ref.read(notesControllerProvider.notifier);
      if (editing != null) {
        await controller.updateItem(editing.id, content: content, tagsText: tagsText);
      } else {
        await controller.create(content: content, tagsText: tagsText);
      }
      if (!mounted) return;
      setState(() => _editorVisible = false);
      _editorController.reverse();
      _contentFocusNode.unfocus();
    } catch (_) {
      if (!mounted) return;
      PortenToast.show('保存失败', icon: ToastIcon.error);
    }
  }

  /// deleteNote：提交控制器删除 + 关闭下拉。
  Future<void> _deleteNote(int noteId) async {
    setState(() => _activeMenuId = null);
    try {
      await ref.read(notesControllerProvider.notifier).delete(noteId);
    } catch (_) {
      if (!mounted) return;
      PortenToast.show('删除失败', icon: ToastIcon.error);
    }
  }

  /// toggleArchive：提交控制器翻转 archived + 关闭下拉。
  Future<void> _toggleArchive(int noteId) async {
    setState(() => _activeMenuId = null);
    try {
      await ref.read(notesControllerProvider.notifier).toggleArchive(noteId);
    } catch (_) {
      if (!mounted) return;
      PortenToast.show('操作失败', icon: ToastIcon.error);
    }
  }

  // ==================== 构建 ====================

  @override
  Widget build(BuildContext context) {
    final double pageWidth = MediaQuery.sizeOf(context).width;
    final double pageHeight = MediaQuery.sizeOf(context).height;
    final double safeTop = MediaQuery.paddingOf(context).top;
    final double safeBottom = MediaQuery.paddingOf(context).bottom;
    // 笔记列表由控制器驱动（mock 读 NoteStore / live 走 data 桥）。
    final List<NoteItem> notes =
        ref.watch(notesControllerProvider).value?.items ?? const <NoteItem>[];

    return Scaffold(
      backgroundColor: PortenColor.white,
      body: Stack(
        children: <Widget>[
          // 顶部渐变装饰（absolute left-0 top-0 w-full，高度 39%，
          // pointer-events-none → IgnorePointer；mask 用 ShaderMask dstIn）。
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: IgnorePointer(
              child: SizedBox(
                height: pageHeight * 0.39,
                child: const _NotesTopGradient(),
              ),
            ),
          ),
          // 根点击关闭下拉（Web 根 div onClick → setActiveMenuId(null)）。
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (_activeMenuId != null) {
                setState(() => _activeMenuId = null);
              }
            },
            child: Column(
              children: <Widget>[
                _buildHeader(safeTop),
                _buildList(safeBottom, notes),
              ],
            ),
          ),
          // 编辑器覆盖层（absolute inset-0 z-40）。
          _buildEditorOverlay(pageWidth, safeTop),
        ],
      ),
    );
  }

  /// 顶栏：h-16（内容高 64 + 状态栏 inset，Web pt-[env(safe-area-inset-top)]）。
  Widget _buildHeader(double safeTop) {
    return SizedBox(
      height: 64 + safeTop,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(left: 16, right: 16, top: safeTop),
            child: Row(
              children: <Widget>[
                // 返回钮：h-9 w-9 -ml-2 rounded-full active:bg-white/45
                Transform.translate(
                  offset: const Offset(-8, 0),
                  child: _PressBox(
                    onTap: () => Navigator.of(context).maybePop(),
                    activeColor: Colors.white.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(999),
                    child: const SizedBox(
                      width: 36,
                      height: 36,
                      child: Center(child: PortenBackIcon(size: 28)),
                    ),
                  ),
                ),
                const Expanded(child: SizedBox.shrink()),
                // 添加笔记：h-9 gap-1.5 rounded-full bg-gray-500/10 px-3
                _PressBox(
                  onTap: () => _openEditor(),
                  normalColor: PortenColor.gray500.withValues(alpha: 0.10),
                  activeColor: PortenColor.gray500.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        PortenLucideIcon('plus',
                            size: 16,
                            color: PortenColor.gray700,
                            strokeWidth: 1.8),
                        SizedBox(width: 6), // gap-1.5
                        Text(
                          '添加笔记',
                          style: TextStyle(
                            fontSize: 14, // text-sm
                            fontWeight: FontWeight.w500, // font-medium
                            color: PortenColor.gray700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 标题：absolute left-1/2 -translate-x-1/2（pointer-events-none）
          const IgnorePointer(
            child: Text(
              '我的笔记',
              style: TextStyle(
                fontSize: 18, // text-lg
                fontWeight: FontWeight.w600, // font-semibold
                color: PortenColor.gray900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 列表：mx-auto max-w-md space-y-3 px-4 pt-3 pb-[max(2rem,safe-bottom)]。
  ///
  /// 结构上把卡片 Column 包进内容级 Stack：下拉菜单作为 Column 的
  /// 兄弟 Positioned 节点渲染（原因见 [_cardKeys]——卡片内 Stack
  /// 放不下溢出的菜单，越界部分不可命中）。Stack 尺寸取 Padding
  /// （含底部 32px 内边距），clipBehavior: none 让最后一张卡片的
  /// 菜单可溢入底部内边距区，由滚动视口统一裁剪（与 Web 一致）。
  Widget _buildList(double safeBottom, List<NoteItem> notes) {
    return Expanded(
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 448), // max-w-md
            child: Stack(
              key: _contentStackKey,
              clipBehavior: Clip.none,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 12,
                    bottom: math.max(32, safeBottom),
                  ),
                  child: Column(
                    children: <Widget>[
                      for (int i = 0; i < notes.length; i++) ...<Widget>[
                        if (i > 0) const SizedBox(height: 12), // space-y-3
                        _noteCard(notes[i]),
                      ],
                    ],
                  ),
                ),
                // 卡片下拉菜单：absolute right-3 top-10 z-30 w-36
                // （相对卡片定位，提到内容级 Stack 渲染）。
                if (_menuAnchor != null) _buildActiveNoteMenu(notes),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 当前展开下拉菜单的笔记（null = 未展开 / 笔记已不存在）。
  NoteItem? _activeNote(List<NoteItem> notes) {
    final int? id = _activeMenuId;
    if (id == null) return null;
    for (final NoteItem note in notes) {
      if (note.id == id) return note;
    }
    return null;
  }

  /// 下拉菜单覆盖层：按锚点矩形换算 Positioned 坐标
  /// （right-3 → left = anchor.right - 12 - 144；top-10 → top + 40）。
  Widget _buildActiveNoteMenu(List<NoteItem> notes) {
    final NoteItem? note = _activeNote(notes);
    final Rect? anchor = _menuAnchor;
    if (note == null || anchor == null) return const SizedBox.shrink();
    return Positioned(
      left: anchor.right - 12 - 144,
      top: anchor.top + 40,
      child: _buildNoteMenu(note),
    );
  }

  /// 卡片矩形 → 内容级 Stack 局部坐标（下拉菜单定位锚点）。
  ///
  /// 点击 more 钮时调用（此时上一帧布局已完成，卡片与内容 Stack
  /// 的 RenderBox 均已布局，变换链有效）。菜单打开不改变任何
  /// 卡片尺寸（Positioned 子节点不影响 Stack 尺寸），锚点跨帧
  /// 保持有效；增删改笔记时菜单均已关闭，无失效场景。
  Rect? _cardAnchorInContent(int noteId) {
    final GlobalKey? cardKey = _cardKeys[noteId];
    final RenderBox? cardBox =
        cardKey?.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? stackBox =
        _contentStackKey.currentContext?.findRenderObject() as RenderBox?;
    if (cardBox == null || stackBox == null) return null;
    if (!cardBox.hasSize || !stackBox.hasSize) return null;
    return stackBox.globalToLocal(cardBox.localToGlobal(Offset.zero)) &
        cardBox.size;
  }

  /// 笔记卡片（article）：rounded-[6px] bg-white px-4 py-3.5，
  /// archived → opacity-65；含 more 钮 / 时间行 / 徽章 / 标签。
  /// 下拉菜单不在此渲染（提到内容级 Stack，见 [_cardKeys]）。
  Widget _noteCard(NoteItem note) {
    return Opacity(
      // 菜单定位锚点（见 [_cardKeys]）。
      key: _cardKeys.putIfAbsent(note.id, () => GlobalKey()),
      opacity: note.archived ? 0.65 : 1.0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: PortenColor.white,
          borderRadius: BorderRadius.circular(6), // rounded-[6px]
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // 正文行：flex items-start gap-3
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // 正文：text-[15px] leading-6 text-gray-800，三行截断
                Expanded(
                  child: Text(
                    note.content,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 24 / 15, // leading-6
                      color: PortenColor.gray800,
                    ),
                  ),
                ),
                const SizedBox(width: 12), // gap-3
                // more 钮：-mr-2 -mt-1 h-8 w-8 rounded-full
                // text-gray-400 active:bg-gray-100
                Transform.translate(
                  offset: const Offset(8, -4),
                  child: _PressBox(
                    onTap: () {
                      final bool opening = _activeMenuId != note.id;
                      setState(() {
                        _activeMenuId = opening ? note.id : null;
                        // 展开时计算菜单锚点（内容级 Stack 坐标）。
                        _menuAnchor =
                            opening ? _cardAnchorInContent(note.id) : null;
                      });
                    },
                    activeColor: PortenColor.gray100,
                    borderRadius: BorderRadius.circular(999),
                    child: const SizedBox(
                      width: 32,
                      height: 32,
                      child: Center(
                        child: PortenLucideIcon('more-horizontal',
                            size: 20,
                            color: PortenColor.gray400,
                            strokeWidth: 1.7),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12), // mt-3
            // 底行：time mr-auto + 已归档徽章 + 标签 chips
            Row(
              children: <Widget>[
                Text(
                  note.time,
                  style: const TextStyle(
                    fontSize: 12, // text-xs
                    height: 16 / 12,
                    color: PortenColor.gray400,
                  ),
                ),
                if (note.archived) ...<Widget>[
                  const SizedBox(width: 8), // gap-2
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: PortenColor.gray100,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      '已归档',
                      style: TextStyle(
                        fontSize: 11, // text-[11px]
                        color: PortenColor.gray500,
                      ),
                    ),
                  ),
                ],
                for (final String tag in note.tags) ...<Widget>[
                  const SizedBox(width: 8), // gap-2
                  _tagChip(tag),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 标签 chip：rounded-full px-2 py-0.5 text-[11px] font-medium，
  /// 底色/字色由 tagStyle hash 决定（6 色）。
  Widget _tagChip(String tag) {
    final NoteTagStyle style = noteTagStyleOf(tag);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        tag,
        style: TextStyle(
          fontSize: 11, // text-[11px]
          fontWeight: FontWeight.w500, // font-medium
          color: style.foreground,
        ),
      ),
    );
  }

  /// 卡片下拉菜单：w-36 rounded-xl bg-white py-1 ring-1 ring-black/5；
  /// 三项（编辑/归档·取消归档/删除）。容器自身吸收点击，
  /// 避免冒泡到根关闭菜单（Web event.stopPropagation）。
  Widget _buildNoteMenu(NoteItem note) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Container(
        width: 144, // w-36
        padding: const EdgeInsets.symmetric(vertical: 4), // py-1
        clipBehavior: Clip.antiAlias, // overflow-hidden
        decoration: BoxDecoration(
          color: PortenColor.white,
          borderRadius: BorderRadius.circular(12), // rounded-xl
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.05), // ring-1 ring-black/5
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _menuItem(
              icon: 'pencil',
              label: '编辑笔记',
              onTap: () => _openEditor(note),
            ),
            _menuItem(
              icon: note.archived ? 'archive-restore' : 'archive',
              label: note.archived ? '取消归档' : '归档笔记',
              onTap: () => _toggleArchive(note.id),
            ),
            _menuItem(
              icon: 'trash-2',
              label: '删除笔记',
              color: PortenColor.error, // text-red-500
              activeColor: _kRed50.withValues(alpha: 0.6), // active:bg-red-50/60
              onTap: () => _deleteNote(note.id),
            ),
          ],
        ),
      ),
    );
  }

  /// 菜单项：px-3 py-2.5 text-sm gap-2.5 text-gray-700 active:bg-gray-50。
  Widget _menuItem({
    required String icon,
    required String label,
    required VoidCallback onTap,
    Color color = PortenColor.gray700,
    Color activeColor = PortenColor.gray50,
  }) {
    return _PressBox(
      onTap: onTap,
      activeColor: activeColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: <Widget>[
            PortenLucideIcon(icon, size: 16, color: color, strokeWidth: 1.7),
            const SizedBox(width: 10), // gap-2.5
            Text(
              label,
              style: TextStyle(
                fontSize: 14, // text-sm
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 编辑器覆盖层：absolute inset-0 z-40，translate-x-full → 0
  /// 300ms cubic-bezier(0.25,0.1,0.25,1)；隐藏态 IgnorePointer
  /// （等价 Web pointer-events-none）。
  Widget _buildEditorOverlay(double pageWidth, double safeTop) {
    return AnimatedBuilder(
      animation: _editorController,
      builder: (BuildContext context, Widget? child) {
        final double t = _editorSlide.value;
        return Positioned.fill(
          child: IgnorePointer(
            ignoring: !_editorVisible,
            child: Transform.translate(
              offset: Offset(pageWidth * (1 - t), 0),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {}, // 阻断冒泡到根（Web stopPropagation）
                child: ColoredBox(
                  color: PortenColor.white,
                  child: Column(
                    children: <Widget>[
                      _buildEditorHeader(safeTop),
                      _buildEditorBody(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 编辑器头部：X 钮 + 居中「编辑笔记/添加笔记」+ 完成钮。
  Widget _buildEditorHeader(double safeTop) {
    final bool enabled = _contentController.text.trim().isNotEmpty;
    return SizedBox(
      height: 64 + safeTop,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(left: 16, right: 16, top: safeTop),
            child: Row(
              children: <Widget>[
                // X 钮：h-9 w-9 -ml-2 rounded-full text-gray-700
                // active:bg-gray-100，X h-5 w-5 strokeWidth 1.7
                Transform.translate(
                  offset: const Offset(-8, 0),
                  child: _PressBox(
                    onTap: _closeEditor,
                    activeColor: PortenColor.gray100,
                    borderRadius: BorderRadius.circular(999),
                    child: const SizedBox(
                      width: 36,
                      height: 36,
                      child: Center(
                        child: PortenLucideIcon('x',
                            size: 20,
                            color: PortenColor.gray700,
                            strokeWidth: 1.7),
                      ),
                    ),
                  ),
                ),
                const Expanded(child: SizedBox.shrink()),
                // 完成钮：h-9 gap-1.5 rounded-full px-3 text-sm
                // bg-gray-900 text-white；disabled:bg-gray-200
                // disabled:text-gray-400
                _PressBox(
                  onTap: enabled ? () => _saveNote() : null,
                  disabled: !enabled,
                  normalColor: enabled ? PortenColor.gray900 : PortenColor.gray200,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        PortenLucideIcon('check',
                            size: 16,
                            color: enabled
                                ? PortenColor.white
                                : PortenColor.gray400,
                            strokeWidth: 1.8),
                        const SizedBox(width: 6), // gap-1.5
                        Text(
                          '完成',
                          style: TextStyle(
                            fontSize: 14, // text-sm
                            color: enabled
                                ? PortenColor.white
                                : PortenColor.gray400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          IgnorePointer(
            child: Text(
              _editingNote != null ? '编辑笔记' : '添加笔记',
              style: const TextStyle(
                fontSize: 18, // text-lg
                fontWeight: FontWeight.w600, // font-semibold
                color: PortenColor.gray900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 编辑器主体：flex-1 overflow-y-auto px-4 pb-8 pt-3；
  /// textarea min-h-[240px] rounded-[6px] bg-gray-50/80 p-4 text-[15px]
  /// leading-7 placeholder:text-gray-300 autoFocus；标签 label + input h-11。
  Widget _buildEditorBody() {
    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // textarea（min-h-[240px] 含 padding，border-box 语义）
            Container(
              constraints: const BoxConstraints(minHeight: 240),
              decoration: BoxDecoration(
                color: PortenColor.gray50.withValues(alpha: 0.8), // bg-gray-50/80
                borderRadius: BorderRadius.circular(6), // rounded-[6px]
              ),
              padding: const EdgeInsets.all(16), // p-4
              child: TextField(
                controller: _contentController,
                focusNode: _contentFocusNode,
                maxLines: null, // 随内容增高（Web textarea 默认行为）
                textAlignVertical: TextAlignVertical.top,
                cursorColor: PortenColor.gray900,
                style: const TextStyle(
                  fontSize: 15, // text-[15px]
                  height: 28 / 15, // leading-7
                  color: PortenColor.gray800,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  hintText: '记录此刻的想法……',
                  hintStyle: TextStyle(
                    fontSize: 15,
                    height: 28 / 15,
                    color: PortenColor.gray300, // placeholder:text-gray-300
                  ),
                ),
              ),
            ),
            // 标签 label：mt-5 block text-xs text-gray-500
            const Padding(
              padding: EdgeInsets.only(top: 20),
              child: Text(
                '标签',
                style: TextStyle(
                  fontSize: 12, // text-xs
                  color: PortenColor.gray500,
                ),
              ),
            ),
            // 标签 input：mt-2 h-11 rounded-[6px] bg-gray-50/80 px-4
            // text-sm text-gray-700 placeholder:text-gray-300
            Container(
              height: 44, // h-11
              margin: const EdgeInsets.only(top: 8), // mt-2
              decoration: BoxDecoration(
                color: PortenColor.gray50.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16), // px-4
              alignment: Alignment.center,
              child: TextField(
                controller: _tagsController,
                style: const TextStyle(
                  fontSize: 14, // text-sm
                  color: PortenColor.gray700,
                ),
                cursorColor: PortenColor.gray900,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  hintText: '多个标签使用空格或顿号分隔',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: PortenColor.gray300,
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

/// 页面转场曲线（与路由 PortenSlideFromRightRoute 一致：
/// cubic-bezier(0.25,0.1,0.25,1)）。
const Cubic kPortenNoteCurve = Cubic(0.25, 0.1, 0.25, 1);

/// 顶部渐变装饰：145deg 五段色标 + 垂直 mask 五段渐隐。
///
/// Web：
///   background: linear-gradient(145deg,
///     rgba(91,206,250,0.30) 0%, rgba(139,204,238,0.27) 22%,
///     rgba(245,169,184,0.30) 52%, rgba(248,198,209,0.18) 72%,
///     rgba(255,255,255,0) 100%);
///   mask-image: linear-gradient(180deg, #000 0%, #000 55%,
///     rgba(0,0,0,0.6) 78%, rgba(0,0,0,0.25) 92%, transparent 100%);
///
/// CSS 145deg → 方向向量 (sin145°, -cos145°) = (0.5736, 0.8192)
/// （指向右下）；Flutter 用 Alignment(-0.5736,-0.8192) →
/// Alignment(0.5736,0.8192) 表达同方向渐变。
/// mask 用 ShaderMask + BlendMode.dstIn 复刻（src alpha 调制 dst alpha）。
class _NotesTopGradient extends StatelessWidget {
  const _NotesTopGradient();

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (Rect bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xFF000000), // #000 0%
          Color(0xFF000000), // #000 55%
          Color(0x99000000), // rgba(0,0,0,0.6) 78%
          Color(0x40000000), // rgba(0,0,0,0.25) 92%
          Color(0x00000000), // transparent 100%
        ],
        stops: <double>[0, 0.55, 0.78, 0.92, 1],
      ).createShader(bounds),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-0.5736, -0.8192),
            end: Alignment(0.5736, 0.8192),
            colors: <Color>[
              Color(0x4D5BCEFA), // rgba(91,206,250,0.30) 0%
              Color(0x458BCCEE), // rgba(139,204,238,0.27) 22%
              Color(0x4DF5A9B8), // rgba(245,169,184,0.30) 52%
              Color(0x2EF8C6D1), // rgba(248,198,209,0.18) 72%
              Color(0x00FFFFFF), // rgba(255,255,255,0) 100%
            ],
            stops: <double>[0, 0.22, 0.52, 0.72, 1],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// 按压反馈容器（对齐 Web active:bg-*）：
/// onTapDown/Up/Cancel 切换底色（沿用项目 _SecurityOptionRow 范式）。
class _PressBox extends StatefulWidget {
  const _PressBox({
    required this.onTap,
    required this.child,
    this.normalColor = Colors.transparent,
    this.activeColor = const Color(0x14000000),
    this.borderRadius,
    this.disabled = false,
  });

  final VoidCallback? onTap;
  final Widget child;
  final Color normalColor;
  final Color activeColor;
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.disabled ? null : (_) => _setPressed(true),
      onTapUp: widget.disabled ? null : (_) => _setPressed(false),
      onTapCancel: widget.disabled ? null : () => _setPressed(false),
      onTap: widget.disabled ? null : widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _pressed ? widget.activeColor : widget.normalColor,
          borderRadius: widget.borderRadius,
        ),
        child: widget.child,
      ),
    );
  }
}
