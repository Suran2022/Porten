/*
 * 组建营地页（对齐 Web 端 CreateGroupPage.tsx 移动端布局）。
 *
 * 白底；从左滑入 -translate-x-full→0；
 * 顶栏：w-14 占位 + 「组建营地」text-lg font-medium + 右「取消」w-14 text-sm gray-600；
 * 分类区：px-6 pt-8，grid-cols-5 gap-3，每项 = 48 rounded-2xl bg-gray-100/80
 *   图标 24 gray-700 strokeWidth 1.5 + 下方 text-xs gray-700 标签；
 * 分类：跨儿同行 Users / 跨儿组织 Building2 / 二次元 Sparkles /
 *   医疗机构 Stethoscope / 院校 GraduationCap。
 */

import 'package:flutter/material.dart';

import '../../core/components/porten_lucide_icons.dart';
import '../../core/components/porten_page_transitions.dart';
import '../profile/profile_page.dart' show kGray900, kGray700, kGray100;
import 'group_profile_page.dart';

class CreateGroupPage extends StatelessWidget {
  const CreateGroupPage({super.key});

  /// 分类（key 对齐 Web GROUP_CATEGORIES：peer / org / acg / medical / school）。
  static const List<(String, String, String)> _categories =
      <(String, String, String)>[
    ('peer', '跨儿同行', 'users'),
    ('org', '跨儿组织', 'building2'),
    ('acg', '二次元', 'sparkles'),
    ('medical', '医疗机构', 'stethoscope'),
    ('school', '院校', 'graduation-cap'),
  ];

  @override
  Widget build(BuildContext context) {
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
                child: Row(
                  children: <Widget>[
                    const SizedBox(width: 56), // w-14
                    const Expanded(
                      child: Text('组建营地',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: kGray900)),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).maybePop(),
                      child: const SizedBox(
                        width: 56, // w-14
                        child: Text('取消',
                            textAlign: TextAlign.right,
                            style: TextStyle(fontSize: 14, color: kGray700)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 分类
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 0), // px-6 pt-8
              child: Row(
                children: <Widget>[
                  for (int i = 0; i < _categories.length; i++) ...<Widget>[
                    if (i > 0) const SizedBox(width: 12), // gap-3
                    Expanded(
                      child: _CategoryItem(
                        key: ValueKey<String>(_categories[i].$1),
                        categoryKey: _categories[i].$1,
                        label: _categories[i].$2,
                        icon: _categories[i].$3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryItem extends StatelessWidget {
  const _CategoryItem({
    super.key,
    required this.categoryKey,
    required this.label,
    required this.icon,
  });

  final String categoryKey;
  final String label;
  final String icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // 点击分类 → 营地资料完善页（同 Web onSelectCategory → GroupProfilePage，
      // 从左滑入叠于本页之上）
      onTap: () => Navigator.of(context).push(PortenSlideFromLeftRoute<void>(
        builder: (_) => GroupProfilePage(groupType: categoryKey),
      )),
      child: Column(
      children: <Widget>[
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: kGray100.withValues(alpha: 0.8), // bg-gray-100/80
            borderRadius: BorderRadius.circular(16), // rounded-2xl
          ),
          child: Center(
            child: PortenLucideIcon(icon,
                size: 24, color: kGray700, strokeWidth: 1.5),
          ),
        ),
        const SizedBox(height: 8), // gap-2
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: kGray700)),
      ],
    ),
    );
  }
}
