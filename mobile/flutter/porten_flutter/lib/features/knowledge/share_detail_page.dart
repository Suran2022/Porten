/*
 * 分享内容详情页（100% 移植 Web 端 knowledge/SharePostDetailPage.tsx 移动端形态）。
 *
 * 结构：
 *   顶部栏：左返回（w-9 圆钮）；右侧 举报（盾形 w-6）+ 分享（w-5），无分割线；
 *   主内容（px-4 pt-5 pb-28 滚动）：
 *     作者行 44 头像 + 昵称（base semibold）；
 *     发布时间（mt-2.5 text-xs gray-400，年月日）；
 *     正文（mt-4 15px gray-800 leading-1.8）；
 *     交流区（mt-8）：ChatIcon w-4 + 「交流」base semibold；
 *       CommentCard（rounded-xl bg-gray-50 px-3.5 py-3）：
 *         首行 24 头像 + 「昵称：」；正文 pl-8 text-sm gray-700；
 *         尾行 pl-8 左时间（xs gray-400）右 太阳点亮（点亮 #f97316）+ 举报，
 *         自己发布的额外显示红色删除；
 *       触底按需加载（每次 3 条，600ms，加载中 ptr 同款提示）；
 *   底部固定交流框：border-t bg-white/70 模糊半透明、灰色胶囊
 *     （左当前用户头像 32 + 竖线 + 提示文本），点击弹出输入面板；
 *   输入面板：底部滑入白色圆角面板 + 黑/40 遮罩，textarea + 粉色胶囊发送。
 *
 * Mock 离线策略：交流列表来自 knowledge_mock 确定性生成；点亮/举报/删除/
 * 发布均为本地状态 + Toast 提示。
 */

import 'package:flutter/material.dart';

import '../../core/components/porten_back_icon.dart';
import '../../core/components/porten_glyph_icons.dart';
import '../../core/components/porten_toast.dart';
import '../../core/data/knowledge_mock.dart';
import '../profile/profile_data.dart' show PortenProfileAssets;

const Color kGray900 = Color(0xFF111827);
const Color kGray800 = Color(0xFF1F2937);
const Color kGray700 = Color(0xFF374151);
const Color kGray500 = Color(0xFF6B7280);
const Color kGray400 = Color(0xFF9CA3AF);
const Color kGray200 = Color(0xFFE5E7EB);
const Color kGray300 = Color(0xFFD1D5DB);
const Color kBrandPink = Color(0xFFF5A9B8);

const int _kInitialCount = 5;
const int _kLoadStep = 3;

/// 发布时间「年月日」（对齐 formatYearMonthDay）。
String _formatYearMonthDay(String value) {
  final RegExp m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})');
  final RegExpMatch? match = m.firstMatch(value.trim());
  if (match == null) return value;
  return '${match.group(1)}年${int.parse(match.group(2)!)}月${int.parse(match.group(3)!)}日';
}

/// 交流相对时间（对齐 formatCommentTime）。
String _formatCommentTime(String value) {
  final DateTime? t = DateTime.tryParse(value);
  if (t == null) return value;
  final Duration diff = DateTime.now().difference(t);
  if (diff.inMinutes < 1) return '现在';
  if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
  if (diff.inHours < 24) return '${diff.inHours}小时前';
  if (diff.inDays < 7) return '${diff.inDays}天前';
  return _formatYearMonthDay(value.substring(0, 10));
}

/// 分享内容详情页。
class ShareDetailPage extends StatefulWidget {
  const ShareDetailPage({super.key, required this.post});

  final PortenSharePost post;

  @override
  State<ShareDetailPage> createState() => _ShareDetailPageState();
}

class _ShareDetailPageState extends State<ShareDetailPage> {
  late final ScrollController _scrollCtrl = ScrollController();
  List<PortenShareDetailComment> _comments = <PortenShareDetailComment>[];
  int _visibleCount = _kInitialCount;
  bool _loadingMore = false;
  bool _composerOpen = false;
  final TextEditingController _inputCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _comments = buildShareDetailComments(widget.post);
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _inputCtrl.dispose();
    super.dispose();
  }

  /// 触底按需增载（每次 3 条、600ms，加载中不重复触发）。
  void _onScroll() {
    if (_loadingMore || _visibleCount >= _comments.length) return;
    if (_scrollCtrl.position.pixels <
        _scrollCtrl.position.maxScrollExtent - 48) {
      return;
    }
    setState(() => _loadingMore = true);
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() {
        _visibleCount =
            (_visibleCount + _kLoadStep).clamp(0, _comments.length);
        _loadingMore = false;
      });
    });
  }

  void _toggleLit(String id) {
    final PortenShareDetailComment target =
        _comments.firstWhere((PortenShareDetailComment c) => c.id == id);
    final bool lit = !target.lit;
    setState(() {
      _comments = _comments
          .map((PortenShareDetailComment c) =>
              c.id == id ? _copyWith(c, lit: lit) : c)
          .toList();
    });
    PortenToast.show(lit ? '点亮成功，谢谢你的光！' : '缘分到此我还会记得你！',
        icon: ToastIcon.success);
  }

  PortenShareDetailComment _copyWith(PortenShareDetailComment c,
      {bool? lit}) {
    return PortenShareDetailComment(
      id: c.id,
      author: c.author,
      avatarAsset: c.avatarAsset,
      content: c.content,
      publishedAt: c.publishedAt,
      lit: lit ?? c.lit,
      isOwn: c.isOwn,
    );
  }

  void _sendComment() {
    final String content = _inputCtrl.text.trim();
    if (content.isEmpty) return;
    setState(() {
      _comments = <PortenShareDetailComment>[
        PortenShareDetailComment(
          id: 'local-${DateTime.now().millisecondsSinceEpoch}',
          author: '抚月',
          avatarAsset: PortenProfileAssets.avatarAsset,
          content: content,
          publishedAt: DateTime.now().toIso8601String(),
          isOwn: true,
        ),
        ..._comments,
      ];
      _visibleCount = _kInitialCount;
      _composerOpen = false;
    });
    _inputCtrl.clear();
    PortenToast.show('发布成功', icon: ToastIcon.success);
    Future<void>.delayed(const Duration(milliseconds: 60), () {
      if (mounted && _scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<PortenShareDetailComment> visible =
        _comments.take(_visibleCount).toList();
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: <Widget>[
          SafeArea(
            bottom: false,
            child: Column(
              children: <Widget>[
                _buildHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 112),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        // 作者行
                        Row(
                          children: <Widget>[
                            _avatar(PortenProfileAssets.avatarAsset, 44),
                            const SizedBox(width: 12),
                            Text(
                              widget.post.author.nickname,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: kGray900,
                                  height: 1.25),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _formatYearMonthDay(widget.post.publishedAt),
                          style: const TextStyle(
                              fontSize: 12, color: kGray400),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.post.content,
                          style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF1F2937),
                              height: 1.8),
                        ),
                        // 交流区
                        Padding(
                          padding: const EdgeInsets.only(top: 32),
                          child: Row(
                            children: <Widget>[
                              const PortenGlyphIcon('chat_bubbles',
                                  size: 16, color: kGray900),
                              const SizedBox(width: 6),
                              const Text('交流',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: kGray900,
                                      height: 1.0)),
                              const Spacer(),
                              Text('${_comments.length}',
                                  style: const TextStyle(
                                      fontSize: 12, color: kGray400)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_comments.isEmpty)
                          const Text('还没有交流，来说点什么吧',
                              style:
                                  TextStyle(fontSize: 14, color: kGray400))
                        else
                          for (final PortenShareDetailComment c in visible)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _CommentCard(
                                comment: c,
                                onToggleLit: () => _toggleLit(c.id),
                                onReport: () => PortenToast.show(
                                    '已提交举报，感谢反馈',
                                    icon: ToastIcon.success),
                                onDelete: () {
                                  setState(() {
                                    _comments = _comments
                                        .where((PortenShareDetailComment x) =>
                                            x.id != c.id)
                                        .toList();
                                  });
                                  PortenToast.show('删除成功',
                                      icon: ToastIcon.success);
                                },
                              ),
                            ),
                        if (_loadingMore)
                          const Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<
                                          Color>(kGray400)),
                                ),
                                SizedBox(width: 8),
                                Text('加载中',
                                    style: TextStyle(
                                        fontSize: 14,
                                        height: 20 / 14,
                                        color: kGray400)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 底部固定交流框（模糊半透明）
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                border: const Border(
                    top: BorderSide(color: kGray200, width: 0.6)),
              ),
              padding: EdgeInsets.fromLTRB(
                  16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _composerOpen = true),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: <Widget>[
                      _avatar(PortenProfileAssets.avatarAsset, 32),
                      const SizedBox(width: 12),
                      Container(
                          width: 1,
                          height: 20,
                          color: kGray300.withValues(alpha: 0.8)),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          '与同伴一起同行，会走的更远哦！',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, color: kGray400),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // 输入面板
          if (_composerOpen) ...<Widget>[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _composerOpen = false),
                child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.4)),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(16)),
                ),
                padding: EdgeInsets.fromLTRB(
                    16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: _inputCtrl,
                      autofocus: true,
                      maxLines: 3,
                      maxLength: 500,
                      style: const TextStyle(
                          fontSize: 14, color: Color(0xFF1F2937)),
                      decoration: const InputDecoration(
                        hintText: '与同伴一起同行，会走的更远哦！',
                        hintStyle: TextStyle(fontSize: 14, color: kGray400),
                        border: InputBorder.none,
                        counterText: '',
                        contentPadding: EdgeInsets.all(0),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _inputCtrl,
                          builder: (BuildContext context,
                              TextEditingValue value, _) {
                            final bool canSend =
                                value.text.trim().isNotEmpty;
                            return GestureDetector(
                              onTap: canSend ? _sendComment : null,
                              child: Container(
                                constraints:
                                    const BoxConstraints(minWidth: 88),
                                height: 36,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: canSend
                                      ? kBrandPink
                                      : kBrandPink.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text('发送',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white)),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: <Widget>[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
              child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(child: PortenBackIcon(size: 26))),
            ),
            const Spacer(),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () =>
                  PortenToast.show('已提交举报，感谢反馈', icon: ToastIcon.success),
              child: const SizedBox(
                  width: 36,
                  height: 36,
                  child: Center(
                      child: PortenGlyphIcon('report_shield',
                          size: 26, color: kGray900))),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => PortenToast.show('已生成分享卡片，快分享给同胞吧',
                  icon: ToastIcon.success),
              child: const SizedBox(
                  width: 36,
                  height: 36,
                  child: Center(
                      child: PortenGlyphIcon('share_paper',
                          size: 22, color: kGray900))),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  /// 圆形头像（渐变圆底兜底 + 首字）。
  Widget _avatar(String asset, double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF5BCEFA), Color(0xFFF5A9B8)],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(asset,
          width: size, height: size, fit: BoxFit.cover),
    );
  }
}

/// 交流卡片（对齐 CommentCard）。
class _CommentCard extends StatelessWidget {
  const _CommentCard({
    required this.comment,
    required this.onToggleLit,
    required this.onReport,
    required this.onDelete,
  });

  final PortenShareDetailComment comment;
  final VoidCallback onToggleLit;
  final VoidCallback onReport;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _Avatar24(comment: comment),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '${comment.author}：',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: kGray900,
                      height: 1.25),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 6, 0, 0),
            child: Text(
              comment.content,
              style: const TextStyle(
                  fontSize: 14, color: kGray700, height: 1.625),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 6, 0, 0),
            child: Row(
              children: <Widget>[
                Text(_formatCommentTime(comment.publishedAt),
                    style:
                        const TextStyle(fontSize: 12, color: kGray400)),
                const Spacer(),
                // 点亮太阳
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onToggleLit,
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: Center(
                      child: PortenGlyphIcon(
                        'sun_lit',
                        size: 16,
                        color: comment.lit
                            ? const Color(0xFFF97316)
                            : kGray400,
                      ),
                    ),
                  ),
                ),
                // 举报
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onReport,
                  child: const SizedBox(
                    width: 32,
                    height: 32,
                    child: Center(
                        child: PortenGlyphIcon('report_flag',
                            size: 16, color: kGray400)),
                  ),
                ),
                if (comment.isOwn)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onDelete,
                    child: const SizedBox(
                      width: 32,
                      height: 32,
                      child: Center(
                          child: PortenGlyphIcon('delete_trash',
                              size: 16, color: Color(0xFFEF4444))),
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

/// 24px 交流头像。
class _Avatar24 extends StatelessWidget {
  const _Avatar24({required this.comment});

  final PortenShareDetailComment comment;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF5BCEFA), Color(0xFFF5A9B8)],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(comment.avatarAsset,
          width: 24, height: 24, fit: BoxFit.cover),
    );
  }
}
