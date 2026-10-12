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
import '../profile/profile_page.dart' show kGray900, kGray700, kGray100;

class CreateGroupPage extends StatelessWidget {
  const CreateGroupPage({super.key});

  static const List<(String, String)> _categories = <(String, String)>[
    ('跨儿同行', 'users'),
    ('跨儿组织', 'building2'),
    ('二次元', 'sparkles'),
    ('医疗机构', 'stethoscope'),
    ('院校', 'graduation-cap'),
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
                          label: _categories[i].$1, icon: _categories[i].$2),
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
  const _CategoryItem({required this.label, required this.icon});

  final String label;
  final String icon;

  @override
  Widget build(BuildContext context) {
    return Column(
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
    );
  }
}
