/*
 * 搜索页（对齐 Web 端 SearchPage.tsx 移动端布局）。
 *
 * bg-[#f7f7f7]；从右滑入；顶栏 BackIcon + 「搜索」居中 + 右 w-8 占位；
 * 搜索框：h-10 px-3 rounded-md bg-gray-100/60 + Search 图标 + input +
 *   清空 X（w-3.5 strokeWidth 2）；
 * 分类标签栏：6 类（全部 Sparkles/同胞 UsersRound/营地 Tent/文件 FileText/
 *   知识 BookOpen/图片 Image），px-3 py-2.5 text-sm，激活 text-[#F5A9B8]
 *   font-medium + 图标同色，未激活 text-gray-500 / 图标 gray-400；
 *   底部 h-0.5 rounded-full bg-[#F5A9B8] 下划线随激活项移动（300ms）；
 * 结果区：分节 SectionHeader（px-4 pt-4 pb-1.5 text-sm gray-700 + N 个结果）
 *   + 白底行列表（ComradeRow 等 px-4 py-3 gap-3，44 头像 / 44 gray-100 圆角方图标）；
 * 空态/状态：虚线圆角方框 w-16 h-16 + Search w-7 gray-300 + 文案。
 *
 * Mock 离线策略：无后端，输入关键词后 280ms 防抖返回固定演示数据
 * （对齐 Web 防抖节奏），无结果时展示空态文案。
 */

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/components/porten_back_icon.dart';
import '../../core/components/porten_lucide_icons.dart';
import '../profile/profile_page.dart'
    show kGray900, kGray700, kGray500, kGray400, kGray300, kGray100;

const Color kBrandPink = Color(0xFFF5A9B8);

class _Category {
  const _Category(this.key, this.label, this.icon, this.placeholder);
  final String key;
  final String label;
  final String icon;
  final String placeholder;
}

const List<_Category> _kCategories = <_Category>[
  _Category('all', '全部', 'sparkles', '搜索同胞、营地、文件、知识、图片…'),
  _Category('comrade', '同胞', 'users-round', '搜索同胞昵称 / Porten 账号'),
  _Category('camp', '营地', 'tent', '搜索营地名称 / 营地号'),
  _Category('file', '文件', 'file-text', '搜索文件名称…'),
  _Category('knowledge', '知识', 'book-open', '搜索文章 / 视频 / 分享标题…'),
  _Category('image', '图片', 'image', '搜索图片描述…'),
];

/// 演示结果条目。
class _ResultItem {
  const _ResultItem(this.title, this.subtitle,
      {this.icon, this.avatarAsset});
  final String title;
  final String subtitle;
  final String? avatarAsset; // 本地头像资产（优先使用）
  final String? icon; // 非空 → gray-100 方块图标
}

Map<String, List<_ResultItem>> _buildMockResults(String keyword) {
  return <String, List<_ResultItem>>{
    'comrade': <_ResultItem>[
      _ResultItem('符娟', 'Porten 账号：20240701',
          avatarAsset: 'assets/mock_avatars/friend_fu_juan.jpg'),
      _ResultItem('李月欣', 'Porten 账号：20241120',
          avatarAsset: 'assets/mock_avatars/friend_li_yuexin.jpg'),
    ],
    'camp': <_ResultItem>[
      _ResultItem('云端旅行营地', 'CAMP-2024 · 23 位成员',
          avatarAsset: 'assets/mock_avatars/camp_yunduan.jpg'),
      _ResultItem('K歌之家营地', 'CAMP-3210 · 18 位成员',
          avatarAsset: 'assets/mock_avatars/camp_kge.jpg'),
    ],
    'file': <_ResultItem>[
      _ResultItem('HRT 指南.pdf', '抚月 · 2.3 MB', icon: 'file-text'),
      _ResultItem('出行清单.xlsx', '符娟 · 48.5 KB', icon: 'file-text'),
    ],
    'knowledge': <_ResultItem>[
      _ResultItem('如何向朋友出柜', '希望还在犹豫的姐妹们也能早日遇到愿意理解你们的人。', icon: 'book-open'),
      _ResultItem('激素一年：我的变化记录', '身体和灵魂对上了号。', icon: 'book-open'),
    ],
    'image': <_ResultItem>[
      _ResultItem('第一次出门的照片.png', '抚月 · 1.2 MB', icon: 'image'),
    ],
  };
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  int _activeIndex = 0;
  String _keyword = '';
  bool _loading = false;
  bool _hasResult = false;
  Map<String, List<_ResultItem>>? _results;

  @override
  void initState() {
    super.initState();
    // 对齐 Web：进场 320ms 后聚焦输入框
    Future<void>.delayed(const Duration(milliseconds: 320), () {
      if (mounted) FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  final FocusNode _focusNode = FocusNode();
  final TextEditingController _inputCtrl = TextEditingController();

  Timer? _debounce;

  void _onKeywordChanged(String value) {
    _debounce?.cancel();
    if (_inputCtrl.text != value) _inputCtrl.text = value;
    setState(() => _keyword = value);    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _loading = false;
        _hasResult = false;
        _results = null;
      });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      final String key = _kCategories[_activeIndex].key;
      setState(() {
        _loading = false;
        _results = _buildMockResults(trimmed);
        _hasResult = (_results![key] ?? <_ResultItem>[]).isNotEmpty ||
            key == 'all';
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.dispose();
    _inputCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _Category activeDef = _kCategories[_activeIndex];
    final bool isAll = activeDef.key == 'all';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            // 顶栏（白底）
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: SizedBox(
                height: 28,
                child: Row(
                  children: <Widget>[
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).maybePop(),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: Center(child: const PortenBackIcon()),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: const Text('搜索',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: kGray900)),
                      ),
                    ),
                    const SizedBox(width: 32),
                  ],
                ),
              ),
            ),
            // 搜索框（白底）
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6).withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: <Widget>[
                    const PortenLucideIcon('search',
                        size: 16, color: kGray400, strokeWidth: 1.8),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _inputCtrl,
                        focusNode: _focusNode,
                        onChanged: _onKeywordChanged,
                        style: const TextStyle(fontSize: 14, color: kGray900),
                        decoration: InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                          hintText: activeDef.placeholder,
                          hintStyle:
                              const TextStyle(fontSize: 14, color: kGray400),
                        ),
                      ),
                    ),
                    if (_keyword.isNotEmpty)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _onKeywordChanged(''),
                        child: const Padding(
                          padding: EdgeInsets.all(2),
                          child: PortenLucideIcon('x',
                              size: 14, color: kGray400, strokeWidth: 2),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // 分类标签栏（白底 + 下划线 indicator）
            // r22：对齐 Web 端 overflow-x-auto + min-w-max——横向可滑动、
            // 分类完整展示（原 6 个 Expanded 均分在窄屏上挤压变形）。
            Container(
              color: Colors.white,
              child: SizedBox(
                height: 41, // py-2.5 + h-0.5
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8), // px-2
                  child: Row(
                    children: <Widget>[
                      for (int i = 0; i < _kCategories.length; i++)
                        _CategoryTab(
                          category: _kCategories[i],
                          active: i == _activeIndex,
                          onTap: () => setState(() {
                            _activeIndex = i;
                            _onKeywordChanged(_keyword);
                          }),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            // 结果区
            Expanded(
              child: _buildContent(isAll, activeDef),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool isAll, _Category activeDef) {
    final String trimmed = _keyword.trim();

    if (_loading) return _Status(text: '正在搜索…', isError: false);
    if (trimmed.isEmpty) return _EmptyHint(keyword: '', label: activeDef.label);
    if (!_hasResult) return _EmptyHint(keyword: trimmed, label: activeDef.label);

    // Mock：全部分类下展示全部节；单分类展示对应节
    final Map<String, List<_ResultItem>> results = _results!;
    final List<MapEntry<String, List<_ResultItem>>> sections =
        <MapEntry<String, List<_ResultItem>>>[];
    final List<String> order = isAll
        ? <String>['comrade', 'camp', 'file', 'knowledge', 'image']
        : <String>[activeDef.key];
    for (final String key in order) {
      final List<_ResultItem> items = results[key] ?? <_ResultItem>[];
      if (items.isNotEmpty) sections.add(MapEntry<String, List<_ResultItem>>(key, items));
    }
    if (sections.isEmpty) return _EmptyHint(keyword: trimmed, label: activeDef.label);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24), // pb-6
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final MapEntry<String, List<_ResultItem>> section in sections)
              ...<Widget>[
                // SectionHeader
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 6), // pt-4 pb-1.5
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: <Widget>[
                      Text(_sectionLabel(section.key),
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: kGray700)),
                      Text('${section.value.length} 个结果',
                          style:
                              const TextStyle(fontSize: 12, color: kGray400)),
                    ],
                  ),
                ),
                Container(
                  color: Colors.white,
                  child: Column(
                    children: section.value
                        .map((_ResultItem item) => _ResultRow(item: item))
                        .toList(),
                  ),
                ),
              ],
          ],
        ),
      ),
    );
  }

  String _sectionLabel(String key) {
    switch (key) {
      case 'comrade':
        return '同胞';
      case 'camp':
        return '营地';
      case 'file':
        return '文件';
      case 'knowledge':
        return '知识';
      case 'image':
        return '图片';
      default:
        return '';
    }
  }
}

class _CategoryTab extends StatelessWidget {
  const _CategoryTab({required this.category, required this.active, required this.onTap});

  final _Category category;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color textColor = active ? kBrandPink : kGray500;
    // r22：去 Expanded（横向滚动布局），tab 宽度由内容决定（whitespace-nowrap）；
    // 下划线经 IntrinsicWidth 跟随内容宽度。
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // px-3 py-2.5
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  PortenLucideIcon(category.icon,
                      size: 14,
                      color: active ? kBrandPink : kGray400,
                      strokeWidth: 1.8),
                  const SizedBox(width: 4),
                  Text(category.label,
                      maxLines: 1,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                          color: textColor)),
                ],
              ),
              const SizedBox(height: 5),
              // 下划线 indicator
              Container(
                height: 2,
                decoration: BoxDecoration(
                  color: active ? kBrandPink : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 结果行（对齐 ComradeRow/CampRow/FileRow/ImageRow/KnowledgeRow）。
class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.item});

  final _ResultItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // px-4 py-3
      child: Row(
        children: <Widget>[
          if (item.avatarAsset != null)
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: kGray100,
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(item.avatarAsset!,
                  width: 44, height: 44, fit: BoxFit.cover),
            )
          else if (item.title.isNotEmpty)
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[Color(0xFF5BCEFA), Color(0xFFF5A9B8)],
                ),
              ),
              child: Text(item.title.characters.first,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white)),
            )
          else
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: kGray100,
                borderRadius: BorderRadius.circular(6), // rounded-md
              ),
              child: Center(
                child: PortenLucideIcon(item.icon ?? 'file-text',
                    size: 20, color: kGray500, strokeWidth: 1.5),
              ),
            ),
          const SizedBox(width: 12), // gap-3
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, color: kGray900)),
                const SizedBox(height: 2), // mt-0.5
                Text(item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: kGray400)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 状态提示（加载 / 错误）。
class _Status extends StatelessWidget {
  const _Status({required this.text, required this.isError});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const SizedBox(height: 80),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isError ? const Color(0xFFFECACA) : kGray300, width: 2),
          ),
          child: Center(
            child: PortenLucideIcon('search',
                size: 28,
                color: isError ? const Color(0xFFFCA5A5) : kGray300,
                strokeWidth: 1.5),
          ),
        ),
        const SizedBox(height: 16),
        Text(text,
            style: TextStyle(
                fontSize: 14,
                color: isError ? const Color(0xFFEF4444) : kGray500)),
      ],
    );
  }
}

/// 空态提示（对齐 EmptyHint）。
class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.keyword, required this.label});

  final String keyword;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const SizedBox(height: 80), // pt-20
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kGray300, width: 2, style: BorderStyle.solid),
          ),
          child: Center(
            child: PortenLucideIcon('search', size: 28, color: kGray300, strokeWidth: 1.5),
          ),
        ),
        const SizedBox(height: 16), // mb-4
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            keyword.isEmpty
                ? '在「$label」下输入关键词开始搜索'
                : '在「$label」中没找到与「$keyword」相关的内容',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: kGray500),
          ),
        ),
        const SizedBox(height: 8), // mt-2
        Text(
          keyword.isEmpty ? '搜索时会同时匹配昵称 / 营地 / 文件 / 文章中的关键词' : '换个关键词或切换分类试试',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: kGray400, height: 1.6),
        ),
      ],
    );
  }
}
