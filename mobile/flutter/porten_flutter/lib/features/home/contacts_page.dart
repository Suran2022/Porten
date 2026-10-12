/*
 * 联系人页面（100% 移植 Web 端 home/ContactsPage.tsx 移动端形态）。
 *
 * 结构：
 *   顶栏：BackIcon w-7（-ml-2）+ 「联系人」text-lg medium 居中 + w-8 占位；
 *   搜索框：h-10 px-3 rounded-md bg-gray-100/60 + Search 16 + input +
 *     「清空」text-xs gray-400；placeholder 随 tab 切换；
 *   功能入口：新的同胞 / 新营地邀请（h-12，右侧 ChevronRight 16），
 *     右侧红点徽标（min-w-5 h-5 red-500）；
 *   6px 灰条分隔（h-1.5 bg-gray-50）；
 *   双 tab：同胞 / 营地（激活 #F5A9B8、未激活 #5BCEFA，激活下划线 h-0.5）；
 *   分组列表：首字母 sticky 分节（px-4 py-1.5 text-xs gray-500 medium）+
 *     ContactCard（44 头像 + 名称 text-base，px-4 py-3）；
 *   右侧字母索引条（w-5 h-4 text-[10px] gray-400，点击滚动定位）。
 *
 * Mock 离线策略：联系人与首页同胞/营地 Mock 同源（真人名 + 本地头像），
 * 拼音首字母用预置映射表（固定数据集，无需引入 pinyin 库）。
 */

import 'package:flutter/material.dart';

import '../../core/components/porten_back_icon.dart';
import '../../core/components/porten_lucide_icons.dart';
import '../../core/components/porten_toast.dart';
import '../profile/profile_page.dart'
    show kGray900, kGray500, kGray400, kGray100;

const Color kBrandPink = Color(0xFFF5A9B8);
const Color kBrandBlue = Color(0xFF5BCEFA);

class _Contact {
  const _Contact(this.name, this.avatarAsset);
  final String name;
  final String avatarAsset;
}

/// 同胞 Mock（与首页消息列表同源）。
const List<_Contact> _kFriends = <_Contact>[
  _Contact('符娟', 'assets/mock_avatars/friend_fu_juan.jpg'),
  _Contact('李月欣', 'assets/mock_avatars/friend_li_yuexin.jpg'),
  _Contact('陈雨桐', 'assets/mock_avatars/friend_chen_yutong.jpg'),
  _Contact('林晚晴', 'assets/mock_avatars/friend_lin_wanqing.jpg'),
  _Contact('周诗涵', 'assets/mock_avatars/friend_zhou_shihan.jpg'),
  _Contact('许清欢', 'assets/mock_avatars/friend_xu_qinghuan.jpg'),
  _Contact('苏念', 'assets/mock_avatars/friend_su_nian.jpg'),
  _Contact('夏栀', 'assets/mock_avatars/friend_xia_zhi.jpg'),
  _Contact('顾晓萌', 'assets/mock_avatars/friend_gu_xiaomeng.jpg'),
  _Contact('Midnight', 'assets/mock_avatars/friend_xia_zhi.jpg'),
];

/// 营地 Mock（与首页消息列表同源）。
const List<_Contact> _kGroups = <_Contact>[
  _Contact('云端旅行营地', 'assets/mock_avatars/camp_yunduan.jpg'),
  _Contact('K歌之家营地', 'assets/mock_avatars/camp_kge.jpg'),
  _Contact('拾光编程营地', 'assets/mock_avatars/camp_shiguang.jpg'),
  _Contact('职场互助营地', 'assets/mock_avatars/camp_zhichang.jpg'),
];

/// 拼音首字母预置映射（固定数据集；未命中回落 '#'）。
const Map<String, String> _kLetterMap = <String, String>{
  '符': 'F', '李': 'L', '陈': 'C', '林': 'L', '周': 'Z', '许': 'X',
  '苏': 'S', '夏': 'X', '顾': 'G', '云': 'Y', 'K': 'K', '拾': 'S', '职': 'Z',
  'M': 'M',
};

const String _kAlphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

String _letterOf(String name) {
  if (name.isEmpty) return '#';
  final String first = name.characters.first;
  if (_kLetterMap.containsKey(first)) return _kLetterMap[first]!;
  return '#';
}

/// 联系人页面（从左滑入，对齐 Web -translate-x-full）。
class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  bool _groupTab = false; // false=同胞 true=营地
  String _keyword = '';
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  final Map<String, GlobalKey> _sectionKeys = <String, GlobalKey>{};

  List<_Contact> get _list {
    final List<_Contact> base = _groupTab ? _kGroups : _kFriends;
    final String kw = _keyword.trim().toLowerCase();
    if (kw.isEmpty) return base;
    return base
        .where((_Contact c) => c.name.toLowerCase().contains(kw))
        .toList();
  }

  Map<String, List<_Contact>> get _grouped {
    final Map<String, List<_Contact>> map = <String, List<_Contact>>{};
    for (final _Contact c in _list) {
      map.putIfAbsent(_letterOf(c.name), () => <_Contact>[]).add(c);
    }
    final List<String> keys = map.keys.toList()
      ..sort((String a, String b) {
        if (a == '#') return 1;
        if (b == '#') return -1;
        return a.compareTo(b);
      });
    return <String, List<_Contact>>{
      for (final String k in keys) k: map[k]!,
    };
  }

  void _scrollToLetter(String letter) {
    final GlobalKey? key = _sectionKeys[letter];
    final BuildContext? ctx = key?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, List<_Contact>> grouped = _grouped;
    _sectionKeys.clear();
    for (final String letter in grouped.keys) {
      _sectionKeys[letter] = GlobalKey();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // 顶栏
            SizedBox(
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
                    const Expanded(
                      child: Text('联系人',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: kGray900)),
                    ),
                    const SizedBox(width: 32),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
            // 搜索框
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: kGray100.withValues(alpha: 0.6),
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
                        onChanged: (String v) =>
                            setState(() => _keyword = v),
                        style: const TextStyle(
                            fontSize: 14, color: kGray900),
                        decoration: InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                          hintText: _groupTab ? '搜索营地名称' : '搜索同胞昵称/Porten账号',
                          hintStyle: const TextStyle(
                              fontSize: 14, color: kGray400),
                        ),
                      ),
                    ),
                    if (_keyword.isNotEmpty)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          _inputCtrl.clear();
                          setState(() => _keyword = '');
                        },
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
            // 功能入口
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: <Widget>[
                  _entryRow('新的同胞', 3),
                  _entryRow('新营地邀请', 1),
                ],
              ),
            ),
            // 6px 灰条
            Container(
                height: 6,
                margin: const EdgeInsets.only(top: 0),
                color: const Color(0xFFF9FAFB)),
            // tabs
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: <Widget>[
                  _tab('同胞', !_groupTab),
                  const SizedBox(width: 24),
                  _tab('营地', _groupTab),
                ],
              ),
            ),
            // 列表
            Expanded(
              child: Stack(
                children: <Widget>[
                  grouped.isEmpty
                      ? Center(
                          child: Text(
                            _keyword.trim().isNotEmpty
                                ? '未搜索到相关${_groupTab ? "营地" : "同胞"}'
                                : '还没有${_groupTab ? "加入营地" : "添加同胞"}',
                            style: const TextStyle(
                                fontSize: 14, color: kGray400),
                          ),
                        )
                      : SingleChildScrollView(
                          controller: _scrollCtrl,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                for (final MapEntry<String,
                                        List<_Contact>> entry
                                    in grouped.entries)
                                  _section(entry.key, entry.value),
                              ],
                            ),
                          ),
                        ),
                  // 字母索引（有关键词时隐藏）
                  if (_keyword.trim().isEmpty && grouped.isNotEmpty)
                    Positioned(
                      right: 4,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            for (final String letter in _kAlphabet
                                .split('')
                                .where(grouped.containsKey))
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _scrollToLetter(letter),
                                child: SizedBox(
                                  width: 20,
                                  height: 16,
                                  child: Center(
                                    child: Text(letter,
                                        style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                            color: kGray400)),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _entryRow(String label, int badge) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => PortenToast.show('$label功能即将上线，敬请期待'),
      child: Container(
        height: 48,
        color: Colors.white,
        child: Row(
          children: <Widget>[
            Text(label,
                style:
                    const TextStyle(fontSize: 16, color: kGray900)),
            if (badge > 0) ...<Widget>[
              const SizedBox(width: 8),
              Container(
                constraints: const BoxConstraints(minWidth: 20),
                height: 20,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$badge',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                        height: 1.0)),
              ),
            ],
            const Spacer(),
            const PortenLucideIcon('chevron-right',
                size: 16, color: kGray400, strokeWidth: 1.5),
          ],
        ),
      ),
    );
  }

  Widget _tab(String label, bool active) {
    // r22：IntrinsicWidth 包裹——原下划线 width:double.infinity 在 Row 非
    // flex 子项中把 tab 撑到整屏宽，第二个 tab 被挤出屏幕（视觉上「消失」）。
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _groupTab = label == '营地'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: active ? kBrandPink : kBrandBlue)),
              const SizedBox(height: 4),
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

  Widget _section(String letter, List<_Contact> items) {
    return Container(
      key: _sectionKeys[letter],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(letter,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: kGray500)),
          ),
          for (final _Contact c in items) _card(c),
        ],
      ),
    );
  }

  Widget _card(_Contact c) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => PortenToast.show('资料页功能即将上线，敬请期待'),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: kGray100,
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(c.avatarAsset,
                  width: 44, height: 44, fit: BoxFit.cover),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(c.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, color: kGray900)),
            ),
          ],
        ),
      ),
    );
  }
}
