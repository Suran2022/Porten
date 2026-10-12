/*
 * 添加同胞/营地页（对齐 Web 端 AddFriendPage.tsx 移动端布局）。
 *
 * 白底；从左滑入 -translate-x-full→0；
 * 顶栏：BackIcon + 「添加同胞/营地」text-lg font-medium 居中 + w-8 占位；
 * 搜索框（sticky）：h-10 px-3 rounded-md bg-gray-100/60 + Search 图标 +
 *   placeholder（搜用户「搜索用户Porten账号/自己的昵称」/ 搜营地「搜索营地名称/营地号」）
 *   + 有字时右侧「清空」text-xs gray-400；
 * Tabs：搜用户 / 搜营地 text-sm font-medium px-1 py-1 ml-6，
 *   激活 #F5A9B8 + 底部 h-0.5 bg-[#F5A9B8]，未激活 #5BCEFA；
 * 内容：
 *   搜用户空关键词 → 「我的同胞」组头（px-4 py-2 text-xs gray-400）+ 好友列表
 *     （UserItem：48 圆头像 + text-base 昵称 + text-xs gray-400 账号，行 px-4 py-3）；
 *   搜营地空关键词 → 「我已加入的营地」+ 营地行（48 头像 + 名称 + N 人）；
 *   有关键词 → 防抖 300ms 搜索结果（Mock），关键词高亮 #F5A9B8；无结果空态。
 */

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/components/porten_back_icon.dart';
import '../../core/components/porten_lucide_icons.dart';
import '../profile/profile_page.dart'
    show kGray900, kGray400, kGray100, kGray300;

const Color kBrandPink = Color(0xFFF5A9B8);
const Color kBrandBlue = Color(0xFF5BCEFA);

class _Contact {
  const _Contact(this.name, this.subtitle,
      {this.isCamp = false, this.avatarAsset});
  final String name;
  final String subtitle;
  final bool isCamp;

  /// 本地头像资产路径（r19：Mock 图片资源）。
  final String? avatarAsset;
}

const List<_Contact> _kMyFriends = <_Contact>[
  _Contact('陈雨桐', '20241120',
      avatarAsset: 'assets/mock_avatars/friend_chen_yutong.jpg'),
  _Contact('苏念', '20250115',
      avatarAsset: 'assets/mock_avatars/friend_su_nian.jpg'),
  _Contact('夏栀', '20240308',
      avatarAsset: 'assets/mock_avatars/friend_xia_zhi.jpg'),
];

const List<_Contact> _kMyCamps = <_Contact>[
  _Contact('云端旅行营地', '23 人',
      isCamp: true, avatarAsset: 'assets/mock_avatars/camp_yunduan.jpg'),
  _Contact('K歌之家营地', '18 人',
      isCamp: true, avatarAsset: 'assets/mock_avatars/camp_kge.jpg'),
  _Contact('职场互助营地', '32 人',
      isCamp: true, avatarAsset: 'assets/mock_avatars/camp_zhichang.jpg'),
];

List<_Contact> _mockSearch(String keyword, bool isUserTab) {
  if (isUserTab) {
    return <_Contact>[
      _Contact('符娟', '20240701',
          avatarAsset: 'assets/mock_avatars/friend_fu_juan.jpg'),
      _Contact('李月欣', '20241120',
          avatarAsset: 'assets/mock_avatars/friend_li_yuexin.jpg'),
    ];
  }
  return <_Contact>[
    _Contact('云端旅行营地', '23 人',
        isCamp: true, avatarAsset: 'assets/mock_avatars/camp_yunduan.jpg'),
    _Contact('拾光编程营地', '48 人',
        isCamp: true, avatarAsset: 'assets/mock_avatars/camp_shiguang.jpg'),
  ];
}

/// 关键词高亮（对齐 HighlightText：匹配段 #F5A9B8）。
TextSpan _highlight(String text, String keyword) {
  if (keyword.isEmpty) return TextSpan(text: text);
  final List<TextSpan> spans = <TextSpan>[];
  final String lower = text.toLowerCase();
  final String kw = keyword.toLowerCase();
  int start = 0;
  while (true) {
    final int idx = lower.indexOf(kw, start);
    if (idx < 0) {
      spans.add(TextSpan(text: text.substring(start)));
      break;
    }
    if (idx > start) {
      spans.add(TextSpan(text: text.substring(start, idx)));
    }
    spans.add(TextSpan(
        text: text.substring(idx, idx + kw.length),
        style: const TextStyle(color: kBrandPink)));
    start = idx + kw.length;
  }
  return TextSpan(children: spans);
}

class AddFriendPage extends StatefulWidget {
  const AddFriendPage({super.key});

  @override
  State<AddFriendPage> createState() => _AddFriendPageState();
}

class _AddFriendPageState extends State<AddFriendPage> {
  bool _userTab = true;
  String _keyword = '';
  List<_Contact>? _results;
  Timer? _debounce;
  final TextEditingController _inputCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 320), () {
      if (mounted) FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    setState(() => _keyword = value);
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() => _results = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _results = _mockSearch(trimmed, _userTab));
    });
  }

  void _switchTab(bool user) {
    _debounce?.cancel();
    setState(() {
      _userTab = user;
      _keyword = '';
      _results = null;
      _inputCtrl.clear();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _inputCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<_Contact> defaultList =
        _userTab ? _kMyFriends : _kMyCamps;
    final List<_Contact> showList = _results ?? defaultList;
    final String trimmed = _keyword.trim();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            // 顶栏
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: SizedBox(
                height: 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.of(context).maybePop(),
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: Center(child: const PortenBackIcon()),
                        ),
                      ),
                    ),
                    const Text('添加同胞/营地',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: kGray900)),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: <Widget>[
                    // 搜索框
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12), // px-4 py-3
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
                                onChanged: _onChanged,
                                style: const TextStyle(
                                    fontSize: 14, color: kGray900),
                                decoration: InputDecoration(
                                  isCollapsed: true,
                                  border: InputBorder.none,
                                  hintText: _userTab
                                      ? '搜索用户Porten账号/自己的昵称'
                                      : '搜索营地名称/营地号',
                                  hintStyle: const TextStyle(
                                      fontSize: 14, color: kGray400),
                                ),
                              ),
                            ),
                            if (trimmed.isNotEmpty)
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _onChanged(''),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 4),
                                  child: Text('清空',
                                      style: TextStyle(
                                          fontSize: 12, color: kGray400)),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    // Tabs
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Row(
                        children: <Widget>[
                          _TabItem(
                              label: '搜用户',
                              active: _userTab,
                              onTap: () => _switchTab(true)),
                          const SizedBox(width: 24), // ml-6
                          _TabItem(
                              label: '搜营地',
                              active: !_userTab,
                              onTap: () => _switchTab(false)),
                        ],
                      ),
                    ),
                    // 内容
                    if (trimmed.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                              _userTab ? '我的同胞' : '我已加入的营地',
                              style: const TextStyle(
                                  fontSize: 12, color: kGray400)),
                        ),
                      ),
                    if (showList.isEmpty)
                      _EmptyState(
                          text: _userTab
                              ? (trimmed.isEmpty ? '还没有添加同胞' : '未搜索到相关用户')
                              : (trimmed.isEmpty ? '还没有加入营地' : '未搜索到相关营地'))
                    else
                      ...showList.map((_Contact c) => _ContactRow(
                            contact: c,
                            keyword: trimmed,
                          )),
                    const SizedBox(height: 24), // pb-6
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        children: <Widget>[
          Text(label,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: active ? kBrandPink : kBrandBlue)),
          const SizedBox(height: 4),
          Container(
            height: 2,
            width: double.infinity,
            decoration: BoxDecoration(
              color: active ? kBrandPink : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }
}

/// 联系人行：UserItem（48 圆头像）或 GroupItem（CampAvatar 48）。
class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.contact, required this.keyword});

  final _Contact contact;
  final String keyword;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // px-4 py-3
      child: Row(
        children: <Widget>[
          contact.avatarAsset != null
              ? Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: kGray100,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(contact.avatarAsset!,
                      width: 48, height: 48, fit: BoxFit.cover),
                )
              : contact.isCamp
                  ? Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: kGray100,
                      ),
                      child: const PortenLucideIcon('users-round',
                          size: 22, color: kGray400, strokeWidth: 1.5),
                    )
                  : Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[kBrandBlue, kBrandPink],
                        ),
                      ),
                      child: Text(contact.name.characters.first,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.white)),
                    ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text.rich(
                  _highlight(contact.name, keyword.toLowerCase().trim()),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, color: kGray900),
                ),
                const SizedBox(height: 2),
                Text(
                  contact.isCamp && keyword.isNotEmpty
                      ? '营地号：CAMP-2024'
                      : contact.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: kGray400),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 空态（对齐 EmptyState）。
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24), // py-16 px-6
      child: Column(
        children: <Widget>[
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kGray300, width: 2),
            ),
            child: const Center(
              child: PortenLucideIcon('users-round',
                  size: 32, color: kGray300, strokeWidth: 1.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: kGray400)),
        ],
      ),
    );
  }
}
