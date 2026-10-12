/*
 * 知识页（100% 对齐 Web 端 KnowledgeTopBar.tsx / KnowledgeView.tsx /
 * ShareView.tsx / LearnView.tsx / LearnCategoryMenu.tsx / ShareCard.tsx /
 * ArticleCard.tsx / VideoCard.tsx）。
 *
 * 结构：
 *   顶部栏 h-16：左侧分享/学习分段控件（RubberSegment：track #f4f4f5、
 *     thumb 品牌渐变、radius 10、等分槽位）+ 分享 Tab 右侧分享入口胶囊；
 *   学习子分类横滑菜单（JellyRadio：chip #f4f4f5、radius 18、gap 8、
 *     激活蓝→粉渐变），吸附行为对齐 Web：列表滚动 > 0 时菜单吸顶、
 *     顶栏内容淡出；
 *   分享列表：ShareCard 流式布局；学习列表：ArticleCard / VideoCard。
 *
 * 差异说明（Mock 离线策略）：Web 端 RubberSegment / JellyRadio 的弹簧形变
 * 动画以 AnimatedContainer 等值过渡等价实现（视觉态一致：轨道、滑块、配色、
 * 圆角、间距、文字色），封面图以品牌渐变占位、视频保持海报态。
 */

import 'package:flutter/material.dart';

import '../../core/components/porten_avatar.dart';
import '../../core/components/porten_gradient_widgets.dart';
import '../../core/components/porten_lucide_icons.dart';
import '../../core/components/porten_page_transitions.dart';
import '../../core/components/porten_toast.dart';
import '../../core/components/porten_pull_to_refresh.dart';
import '../../core/data/knowledge_mock.dart';
import '../../core/design/porten_colors.dart';
import '../../core/design/porten_typography.dart';
import 'share_detail_page.dart';

/// 知识页布局常量（跨子组件共享）。
class _KnowledgePageStatics {
  const _KnowledgePageStatics._();

  static const double topBarHeight = 64; // h-16
  static const double menuHeight = 48; // 分类菜单高度（CATEGORY_MENU_HEIGHT）
}

/// 知识页根组件。
class KnowledgePage extends StatefulWidget {
  const KnowledgePage({super.key});

  @override
  State<KnowledgePage> createState() => _KnowledgePageState();
}

class _KnowledgePageState extends State<KnowledgePage> {
  bool _isLearn = false; // 知识 Tab：false=分享 true=学习
  bool _menuFixed = false; // 学习分类菜单是否吸顶
  String _category = 'community'; // 当前学习分类

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        // 内容区：分享 / 学习双页切换（对齐 200% translate 滑动）
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          switchInCurve: const Cubic(0.25, 0.1, 0.25, 1),
          switchOutCurve: const Cubic(0.25, 0.1, 0.25, 1),
          child: _isLearn
              ? _LearnList(
                  key: const ValueKey<bool>(true),
                  category: _category,
                  onMenuFixedChange: (bool fixed) {
                    if (fixed != _menuFixed) {
                      setState(() => _menuFixed = fixed);
                    }
                  },
                  onCategoryChange: (String c) =>
                      setState(() => _category = c),
                )
              : _ShareList(key: const ValueKey<bool>(false)),
        ),
        // 顶部栏（内容随 menuFixed 淡出；白底保留，菜单吸顶时叠在其上）
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _KnowledgeTopBar(
            isLearn: _isLearn,
            buttonsVisible: !_menuFixed,
            onTabChange: (bool learn) => setState(() => _isLearn = learn),
          ),
        ),
        // 学习分类菜单（吸附：fixed ? top-0 : top-16）。
        // r21：必须排在顶栏之后——顶栏为不透明白底，菜单吸顶（top-0）时
        // 会被顶栏盖住造成「直接消失」；后声明者后绘制，吸顶时正确过渡到
        // 屏幕最顶端（对齐 Web 端 fixed top-0 叠放）。
        if (_isLearn)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            top: _menuFixed ? 0 : _KnowledgePageStatics.topBarHeight,
            left: 0,
            right: 0,
            child: _LearnCategoryMenu(
              activeCategory: _category,
              onChange: (String c) => setState(() => _category = c),
            ),
          ),
      ],
    );
  }
}

/// 顶部栏（对齐 KnowledgeTopBar）。
class _KnowledgeTopBar extends StatelessWidget {
  const _KnowledgeTopBar({
    required this.isLearn,
    required this.buttonsVisible,
    required this.onTabChange,
  });

  final bool isLearn;
  final bool buttonsVisible;
  final ValueChanged<bool> onTabChange;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PortenColor.white,
      child: SizedBox(
        height: 64, // h-16
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16), // px-4
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              // 左：分享 / 学习分段控件
              AnimatedOpacity(
                opacity: buttonsVisible ? 1 : 0,
                duration: const Duration(milliseconds: 300),
                child: IgnorePointer(
                  ignoring: !buttonsVisible,
                  child: _RubberSegment(
                    value: isLearn,
                    onChange: onTabChange,
                  ),
                ),
              ),
              // 右：分享入口（仅分享 Tab）
              if (!isLearn)
                AnimatedOpacity(
                  opacity: buttonsVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: IgnorePointer(
                    ignoring: !buttonsVisible,
                    child: GestureDetector(
                      onTap: () => PortenToast.show(
                        '已生成分享卡片，快分享给同胞吧',
                        icon: ToastIcon.success,
                      ),
                      child: Container(
                        height: 36, // h-9
                        padding: const EdgeInsets.only(
                            left: 10, right: 12), // pl-2.5 pr-3
                        decoration: BoxDecoration(
                          color: PortenColor.gray100,
                          borderRadius: BorderRadius.circular(18), // rounded-full
                        ),
                        child: Row(
                          children: <Widget>[
                            const PortenShareGlyph(
                              size: 16, // w-4 h-4
                              color: PortenColor.inkDark,
                            ), // 分享入口图标
                            const SizedBox(width: 4), // gap-1
                            Text(
                              '分享',
                              style: PortenTypography.body13.copyWith(
                                color: PortenColor.inkDark,
                                height: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              else
                const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }
}

/// 分享 / 学习分段控件（对齐 RubberSegment md：h-9、radius 10、inset 3、等分）。
class _RubberSegment extends StatelessWidget {
  const _RubberSegment({required this.value, required this.onChange});

  final bool value;
  final ValueChanged<bool> onChange;

  static const double _height = 36;
  static const double _itemWidth = 64;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _height,
      width: _itemWidth * 2,
      padding: const EdgeInsets.all(3), // inset 3
      decoration: BoxDecoration(
        color: PortenColor.zinc100, // trackColor #f4f4f5
        borderRadius: BorderRadius.circular(10), // radius 10
      ),
      child: Stack(
        children: <Widget>[
          // 滑块（thumb：90deg 蓝→粉→蓝 渐变）
          AnimatedAlign(
            duration: const Duration(milliseconds: 220), // speed=1 等效时长
            curve: Curves.easeOutCubic,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: _itemWidth,
              height: _height - 6,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[
                    PortenColor.brandBlue,
                    PortenColor.brandPink,
                    PortenColor.brandBlue,
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          // 文本层
          Row(
            children: <Widget>[
              _label('分享', !value, () => onChange(false)),
              _label('学习', value, () => onChange(true)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _label(String text, bool active, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: _itemWidth,
        child: Center(
          child: Text(
            text,
            style: PortenTypography.sm.copyWith(
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              color: active
                  ? PortenColor.white // activeTextColor #ffffff
                  : PortenColor.zinc600, // textColor #52525b
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}

/// 学习分类横滑菜单（对齐 LearnCategoryMenu + JellyRadio 视觉态）。
class _LearnCategoryMenu extends StatelessWidget {
  const _LearnCategoryMenu({
    required this.activeCategory,
    required this.onChange,
  });

  final String activeCategory;
  final ValueChanged<String> onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PortenColor.white,
      height: 48, // CATEGORY_MENU_HEIGHT
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: <Widget>[
            for (final String key in kLearnCategoryOrder) ...<Widget>[
              if (key != kLearnCategoryOrder.first)
                const SizedBox(width: 8), // gap 8
              _chip(key),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(String key) {
    final bool active = key == activeCategory;
    final String label = kLearnCategoryLabels[key] ?? key;
    return GestureDetector(
      onTap: () => onChange(key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? null : PortenColor.zinc100, // chipColor #f4f4f5
          gradient: active
              ? const LinearGradient(
                  colors: <Color>[PortenColor.brandBlue, PortenColor.brandPink],
                )
              : null, // activeColor 蓝→粉
          borderRadius: BorderRadius.circular(18), // radius 18
        ),
        child: Text(
          label,
          style: PortenTypography.sm.copyWith(
            color: active ? PortenColor.white : PortenColor.gray500,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

/// 分享列表（对齐 ShareView）。
class _ShareList extends StatelessWidget {
  const _ShareList({super.key});

  @override
  Widget build(BuildContext context) {
    // 下拉刷新（对齐 Web ShareView：PullToRefresh 包裹滚动容器，
    // 提示条基准 = 顶栏 64，对称内边距 = 64）
    return PortenPullToRefresh(
      indicatorOffset: 64,
      contentPaddingTop: 64,
      onRefresh: () async {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      },
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(0, 64, 0, 16), // 顶栏高度 + pb-4
        itemCount: kPortenSharePosts.length,
        itemBuilder: (BuildContext context, int index) =>
            _ShareCard(post: kPortenSharePosts[index]),
      ),
    );
  }
}

/// 分享卡片（对齐 ShareCard.tsx）。
class _ShareCard extends StatelessWidget {
  const _ShareCard({required this.post});

  final PortenSharePost post;

  @override
  Widget build(BuildContext context) {
    final PortenSharePost p = post;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push(PortenSlideFromRightRoute<void>(
        builder: (_) => ShareDetailPage(post: post),
      )),
      child: Container(
      color: PortenColor.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // px-4 py-3
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 作者头像（r20：本地资产图，回退渐变圆底 + 首字）
          PortenAuthorAvatar(
              nickname: p.author.nickname, asset: p.author.avatarAsset),
          const SizedBox(width: 12), // gap-3
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  p.author.nickname,
                  style: PortenTypography.base.copyWith(
                    fontWeight: FontWeight.w600,
                    color: PortenColor.gray900,
                    height: 1.25, // leading-tight
                  ),
                ),
                const SizedBox(height: 4), // mt-1
                Text(
                  truncateText(p.content, 120),
                  style: PortenTypography.sm.copyWith(
                    color: PortenColor.gray700,
                    height: 1.625, // leading-relaxed
                  ),
                ),
                // 最新评论
                if (p.latestComment != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8), // mt-2
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8), // px-3 py-2
                      decoration: BoxDecoration(
                        color: PortenColor.gray100
                            .withValues(alpha: 0.8), // gray-100/80
                        borderRadius: BorderRadius.circular(8), // rounded-lg
                      ),
                      child: Text.rich(
                        TextSpan(
                          children: <InlineSpan>[
                            TextSpan(
                              text: p.latestComment!.author,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: PortenColor.gray800,
                                height: 1.625,
                              ),
                            ),
                            const TextSpan(
                              text: ' · ',
                              style: TextStyle(
                                fontSize: 12,
                                color: PortenColor.gray400,
                                height: 1.625,
                              ),
                            ),
                            TextSpan(
                              text: truncateText(p.latestComment!.content, 60),
                              style: const TextStyle(
                                fontSize: 12,
                                color: PortenColor.gray600,
                                height: 1.625,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 10), // mt-2.5
                // Meta & Actions
                Row(
                  children: <Widget>[
                    _metaStat(const PortenLucideIcon('eye', size: 14, color: PortenColor.gray500, strokeWidth: 1.8), formatCount(p.views)),
                    const SizedBox(width: 16), // gap-4
                    _metaStat(
                        const PortenLucideIcon('message-circle',
                            size: 14, color: PortenColor.gray500, strokeWidth: 1.8),
                        formatCount(p.comments)),
                    const SizedBox(width: 16),
                    _metaStat(const PortenLucideIcon('heart', size: 14, color: PortenColor.gray500, strokeWidth: 1.8), formatCount(p.likes)),
                    const Spacer(),
                    PortenAccentGradientText(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const PortenLucideIcon(
                            'share-2', // lucide Share2
                            size: 14, // w-3.5 h-3.5
                            color: PortenColor.white,
                            strokeWidth: 1.8,
                          ),
                          const SizedBox(width: 4), // gap-1
                          Text(
                            '分享',
                            style: PortenTypography.xs.copyWith(
                              fontWeight: FontWeight.w600,
                              color: PortenColor.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12), // gap-3
                    Text(
                      p.publishedAt,
                      style: PortenTypography.xs.copyWith(
                        color: PortenColor.gray400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  /// 浏览 / 评论 / 点赞计数（text-xs gray-500 + 14px 图标）。
  Widget _metaStat(Widget icon, String count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        icon,
        const SizedBox(width: 4), // gap-1
        Text(
          count,
          style: PortenTypography.xs.copyWith(color: PortenColor.gray500),
        ),
      ],
    );
  }
}

/// 学习列表（对齐 LearnView：分类过滤 + 吸附上报）。
class _LearnList extends StatefulWidget {
  const _LearnList({
    super.key,
    required this.category,
    required this.onMenuFixedChange,
    required this.onCategoryChange,
  });

  final String category;
  final ValueChanged<bool> onMenuFixedChange;
  final ValueChanged<String> onCategoryChange;

  @override
  State<_LearnList> createState() => _LearnListState();
}

class _LearnListState extends State<_LearnList> {
  late List<PortenLearnPost> _posts = getLearnPostsByCategory(widget.category);

  @override
  void didUpdateWidget(_LearnList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.category != widget.category) {
      // 切换分类：重新拉取数据、回到顶部并复位分类栏吸附
      setState(() => _posts = getLearnPostsByCategory(widget.category));
      widget.onMenuFixedChange(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 顶部内边距：顶栏 + 分类菜单（对齐 Web 端 pt-14 = 56 + 顶栏 64）
    final double topPadding = _KnowledgePageStatics.topBarHeight + _KnowledgePageStatics.menuHeight;
    return PortenPullToRefresh(
      indicatorOffset: _KnowledgePageStatics.topBarHeight + _KnowledgePageStatics.menuHeight,
      contentPaddingTop: _KnowledgePageStatics.topBarHeight + 56,
      onRefresh: () async {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      },
      child: NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        widget.onMenuFixedChange(notification.metrics.pixels > 0);
        return false;
      },
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(0, topPadding, 0, 16),
        itemCount: _posts.length,
        itemBuilder: (BuildContext context, int index) {
          final PortenLearnPost post = _posts[index];
          return post.type == PortenLearnPostType.article
              ? _ArticleCard(post: post)
              : _VideoCard(post: post);
        },
      ),
      ),
    );
  }
}

/// 文章卡片（对齐 ArticleCard.tsx）。
class _ArticleCard extends StatelessWidget {
  const _ArticleCard({required this.post});

  final PortenLearnPost post;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PortenColor.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // px-4 py-3
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 封面（16:9 圆角 xl；Mock：品牌渐变占位）
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12), // rounded-xl
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    PortenColor.brandBlue.withValues(alpha: 0.35),
                    PortenColor.brandPink.withValues(alpha: 0.35),
                  ],
                ),
              ),
              child: Center(
                child: Text(
                  post.title,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: PortenTypography.base.copyWith(
                    fontWeight: FontWeight.w600,
                    color: PortenColor.gray700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12), // mt-3
          Text(
            post.title,
            style: PortenTypography.base.copyWith(
              fontWeight: FontWeight.w600,
              color: PortenColor.gray900,
              height: 1.375, // leading-snug
            ),
          ),
          const SizedBox(height: 6), // mt-1.5
          Text(
            truncateText(post.summary, 120),
            style: PortenTypography.sm.copyWith(
              color: PortenColor.gray600,
              height: 1.625,
            ),
          ),
          // Tags
          Padding(
            padding: const EdgeInsets.only(top: 8), // mt-2
            child: Wrap(
              spacing: 6, // gap-1.5
              runSpacing: 6,
              children: <Widget>[
                for (final String tag in post.tags)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2), // px-2 py-0.5
                    decoration: BoxDecoration(
                      color: PortenColor.gray100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      tag,
                      style: const TextStyle(
                        fontSize: 12,
                        color: PortenColor.gray500,
                        height: 1.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10), // mt-2.5
          // Meta & 阅读全文
          Row(
            children: <Widget>[
              Text(
                post.publishedAt,
                style: PortenTypography.xs.copyWith(
                  color: PortenColor.gray500,
                ),
              ),
              const SizedBox(width: 12), // gap-3
              _metaStat(const PortenLucideIcon('eye', size: 14, color: PortenColor.gray500, strokeWidth: 1.8), formatCount(post.views)),
              const SizedBox(width: 12),
              _metaStat(const PortenLucideIcon('share-2', size: 14, color: PortenColor.gray500, strokeWidth: 1.8), formatCount(post.shares)),
              const Spacer(),
              PortenAccentGradientText(
                child: Text(
                  '阅读全文',
                  style: PortenTypography.xs.copyWith(
                    fontWeight: FontWeight.w600,
                    color: PortenColor.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaStat(Widget icon, String count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        icon,
        const SizedBox(width: 4),
        Text(
          count,
          style: PortenTypography.xs.copyWith(color: PortenColor.gray500),
        ),
      ],
    );
  }
}

/// 视频卡片（对齐 VideoCard.tsx 海报态：封面 + 播放按钮 + 时长徽标 + 静音钮）。
class _VideoCard extends StatelessWidget {
  const _VideoCard({required this.post});

  final PortenLearnPost post;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PortenColor.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 视频区（16:9 黑底 rounded-xl）
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Container(
                  decoration: BoxDecoration(
                    color: PortenColor.black, // bg-black
                    borderRadius: BorderRadius.circular(12), // rounded-xl
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        PortenColor.gray800,
                        PortenColor.black,
                      ],
                    ),
                  ),
                ),
                // 海报态播放按钮（w-12 h-12 白底 90% 圆形）
                Center(
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: PortenColor.white.withValues(alpha: 0.9),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.only(left: 2), // ml-0.5
                      child: PortenLucideIcon(
                        'play', // lucide Play（fill="currentColor"）
                        size: 20, // w-5 h-5
                        color: PortenColor.gray800,
                        strokeWidth: 2,
                        fill: true,
                      ),
                    ),
                  ),
                ),
                // 时长徽标（bottom-2 right-2 bg-black/60 text-[10px]）
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2), // px-1.5 py-0.5
                    decoration: BoxDecoration(
                      color: PortenColor.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      post.duration ?? '',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: PortenColor.white,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
                // 静音钮（top-2 right-2 bg-black/40 圆形）
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(6), // p-1.5
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: PortenColor.black.withValues(alpha: 0.4),
                    ),
                    child: const PortenLucideIcon(
                      'volume-x', // lucide VolumeX
                      size: 14, // w-3.5 h-3.5
                      color: PortenColor.white,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12), // mt-3
          Text(
            post.title,
            style: PortenTypography.base.copyWith(
              fontWeight: FontWeight.w600,
              color: PortenColor.gray900,
              height: 1.375,
            ),
          ),
          const SizedBox(height: 6), // mt-1.5
          Text(
            truncateText(post.summary, 120),
            style: PortenTypography.sm.copyWith(
              color: PortenColor.gray600,
              height: 1.625,
            ),
          ),
          const SizedBox(height: 10), // mt-2.5
          Row(
            children: <Widget>[
              Text(
                post.publishedAt,
                style: PortenTypography.xs.copyWith(
                  color: PortenColor.gray500,
                ),
              ),
              const SizedBox(width: 12),
              _metaStat(const PortenLucideIcon('eye', size: 14, color: PortenColor.gray500, strokeWidth: 1.8), formatCount(post.views)),
              const SizedBox(width: 12),
              _metaStat(const PortenLucideIcon('share-2', size: 14, color: PortenColor.gray500, strokeWidth: 1.8), formatCount(post.shares)),
              const Spacer(),
              PortenAccentGradientText(
                child: Text(
                  '分享',
                  style: PortenTypography.xs.copyWith(
                    fontWeight: FontWeight.w600,
                    color: PortenColor.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaStat(Widget icon, String count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        icon,
        const SizedBox(width: 4),
        Text(
          count,
          style: PortenTypography.xs.copyWith(color: PortenColor.gray500),
        ),
      ],
    );
  }
}
