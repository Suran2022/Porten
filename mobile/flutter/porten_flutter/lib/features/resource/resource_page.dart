/*
 * 资源页（100% 对齐 Web 端 ResourceTopBar.tsx / ResourceView.tsx /
 * HospitalCard.tsx / OrganizationCard.tsx / ProcessNodeItem.tsx /
 * ProcessTimeline.tsx / ResourceTipCard.tsx）。
 *
 * 结构：固定顶部 h-16（items-end pb-3）左侧三 Tab（医院/组织/流程，
 *   激活 18px semibold 品牌渐变、非激活 base gray-500）+ 右侧「收藏」；
 * 内容：医院（提示卡 + 医院卡列表）/ 组织（组织卡列表）/ 流程（时间线）。
 */

import 'package:flutter/material.dart';

import '../../core/components/porten_gradient_widgets.dart';
import '../../core/components/porten_lucide_icons.dart';
import '../../core/data/resource_mock.dart';
import '../../core/design/porten_colors.dart';
import '../../core/design/porten_typography.dart';

/// 资源页根组件。
class ResourcePage extends StatefulWidget {
  const ResourcePage({super.key});

  @override
  State<ResourcePage> createState() => _ResourcePageState();
}

class _ResourcePageState extends State<ResourcePage> {
  int _activeTab = 0; // 0=医院 1=组织 2=流程

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _buildTopBar(),
        Expanded(
          child: _activeTab == 0
              ? ListView(
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    const _ResourceTipCard(),
                    for (final PortenHospital h in kPortenHospitals)
                      _HospitalCard(hospital: h),
                  ],
                )
              : _activeTab == 1
                  ? ListView(
                      padding: EdgeInsets.zero,
                      children: <Widget>[
                        for (final PortenOrganization o
                            in kPortenOrganizations)
                          _OrganizationCard(organization: o),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      children: <Widget>[
                        for (int i = 0; i < kPortenProcessNodes.length; i++)
                          _ProcessNodeItem(
                            node: kPortenProcessNodes[i],
                            index: i,
                            isLast: i == kPortenProcessNodes.length - 1,
                            defaultExpanded: i == 0,
                          ),
                      ],
                    ),
        ),
      ],
    );
  }

  /// 顶部栏（对齐 ResourceTopBar）。
  Widget _buildTopBar() {
    const List<String> tabs = <String>['医院', '组织', '流程'];
    return Material(
      color: PortenColor.white,
      child: SizedBox(
        height: 64, // h-16
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16), // px-4
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end, // items-end
            children: <Widget>[
              // 左：Tabs
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    for (int i = 0; i < tabs.length; i++) ...<Widget>[
                      if (i > 0) const SizedBox(width: 20), // gap-5
                      GestureDetector(
                        onTap: () => setState(() => _activeTab = i),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12), // pb-3
                          child: _activeTab == i
                              ? PortenGradientText(
                                  child: Text(
                                    tabs[i],
                                    style: PortenTypography.lg.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: PortenColor.white,
                                      height: 1.0, // leading-none
                                    ),
                                  ),
                                )
                              : Text(
                                  tabs[i],
                                  style: PortenTypography.base.copyWith(
                                    color: PortenColor.gray500,
                                    height: 1.0,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // 右：收藏
              GestureDetector(
                onTap: () {}, // Web 端为静态按钮
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12), // mb-3
                  child: Text(
                    '收藏',
                    style: PortenTypography.sm.copyWith(
                      color: PortenColor.gray500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 资源提示卡（对齐 ResourceTipCard：左上 135° 品牌渐变薄雾 + 说明文案）。
class _ResourceTipCard extends StatelessWidget {
  const _ResourceTipCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0), // mx-4 mt-3
      padding: const EdgeInsets.all(16), // p-4
      decoration: BoxDecoration(
        color: PortenColor.white,
        borderRadius: BorderRadius.circular(10), // rounded-[10px]
        border: Border.all(color: PortenColor.gray200),
      ),
      child: const Text(
        'Porten 医疗资源来自跨儿组织和志愿者，均为跨儿们就医的医院。但因地区和个人情况不同，因此请根据个人情况选择所在城市或外地医院。',
        style: TextStyle(
          fontSize: 14, // text-sm
          color: PortenColor.gray600,
          height: 1.625, // leading-relaxed
        ),
      ),
    );
  }
}

/// 医院卡片（对齐 HospitalCard.tsx）。
class _HospitalCard extends StatefulWidget {
  const _HospitalCard({required this.hospital});

  final PortenHospital hospital;

  @override
  State<_HospitalCard> createState() => _HospitalCardState();
}

class _HospitalCardState extends State<_HospitalCard> {
  late bool _isFavorited = widget.hospital.isFavorited;

  @override
  Widget build(BuildContext context) {
    final PortenHospital hospital = widget.hospital;
    final List<String> tags = <String>[
      if (hospital.canIssueDiagnosis) '可开诊断单',
      if (hospital.requiresParent) '需家长陪同',
      if (hospital.firstVisitIssue) '首诊可开单',
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0), // mx-4 mt-3
      padding: const EdgeInsets.all(16), // p-4
      decoration: BoxDecoration(
        color: PortenColor.white,
        borderRadius: BorderRadius.circular(10), // rounded-[10px]
        border: Border.all(color: PortenColor.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 名称 + 收藏
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      hospital.name,
                      style: PortenTypography.base.copyWith(
                        fontWeight: FontWeight.w600,
                        color: PortenColor.gray900,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4), // mt-1
                    Text(
                      '${hospital.province} · ${hospital.city} · ${hospital.level}',
                      style: PortenTypography.xs.copyWith(
                        color: PortenColor.gray500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12), // gap-3
              // 收藏按钮
              GestureDetector(
                onTap: () => setState(() => _isFavorited = !_isFavorited),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    PortenLucideIcon(
                      'heart', // lucide Heart（收藏态实心）
                      size: 16, // w-4 h-4
                      color: _isFavorited
                          ? PortenColor.error
                          : PortenColor.gray400,
                      strokeWidth: 2,
                      fill: _isFavorited, // fill-red-500 态
                    ),
                    const SizedBox(width: 4), // gap-1
                    Text(
                      '收藏',
                      style: PortenTypography.xs.copyWith(
                        color: _isFavorited
                            ? PortenColor.error
                            : PortenColor.gray400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8), // mt-2
          Text(
            hospital.address,
            style: PortenTypography.sm.copyWith(
              color: PortenColor.gray600,
              height: 1.375, // leading-snug
            ),
          ),
          const SizedBox(height: 12), // mt-3
          // 条件标签 + 友好度
          Wrap(
            spacing: 8, // gap-2
            runSpacing: 8,
            children: <Widget>[
              for (final String tag in tags) _chip(tag),
              _chip('友好度 ${hospital.friendlyScore}'),
            ],
          ),
          const SizedBox(height: 12), // mt-3
          // 可做项目
          const Text(
            '可做项目',
            style: TextStyle(fontSize: 12, color: PortenColor.gray400),
          ),
          const SizedBox(height: 4), // mb-1
          Wrap(
            spacing: 6, // gap-1.5
            runSpacing: 6,
            children: <Widget>[
              for (final String project in hospital.availableProjects)
                _outlinedChip(project),
            ],
          ),
        ],
      ),
    );
  }

  /// 灰底小标签（bg-gray-100 text-gray-600）。
  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), // px-2 py-0.5
      decoration: BoxDecoration(
        color: PortenColor.gray100,
        borderRadius: BorderRadius.circular(4), // rounded
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: PortenColor.gray600,
          height: 1.5,
        ),
      ),
    );
  }

  /// 描边小标签（border-gray-200 text-gray-600）。
  Widget _outlinedChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: PortenColor.gray200),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: PortenColor.gray600,
          height: 1.5,
        ),
      ),
    );
  }
}

/// 组织卡片（对齐 OrganizationCard.tsx）。
class _OrganizationCard extends StatefulWidget {
  const _OrganizationCard({required this.organization});

  final PortenOrganization organization;

  @override
  State<_OrganizationCard> createState() => _OrganizationCardState();
}

class _OrganizationCardState extends State<_OrganizationCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final PortenOrganization org = widget.organization;
    return Container(
      color: PortenColor.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // px-4 py-3
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 图标圆底
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: PortenColor.gray100,
            ),
            child: const PortenLucideIcon(
              'users', // lucide Users
              size: 24, // w-6 h-6
              color: PortenColor.gray400,
              strokeWidth: 1.8,
            ),
          ),
          const SizedBox(width: 12), // gap-3
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // 名称 + 联系组织
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            org.name,
                            style: PortenTypography.base.copyWith(
                              fontWeight: FontWeight.w600,
                              color: PortenColor.gray900,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 2), // mt-0.5
                          Text(
                            '${org.nature} · ${org.country} · ${org.centerCity}',
                            style: PortenTypography.xs.copyWith(
                              color: PortenColor.gray500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8), // gap-2
                    PortenAccentGradientText(
                      child: Text(
                        '联系组织',
                        style: PortenTypography.sm.copyWith(
                          fontWeight: FontWeight.w600,
                          color: PortenColor.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8), // mt-2
                // 覆盖城市展开行
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        '覆盖城市',
                        style: PortenTypography.sm.copyWith(
                          color: PortenColor.gray600,
                        ),
                      ),
                      AnimatedRotation(
                        turns: _expanded ? 0.25 : 0, // rotate(90deg)
                        duration: const Duration(milliseconds: 300),
                        child: const PortenLucideIcon(
                          'chevron-right', // lucide ChevronRight
                          size: 16, // w-4 h-4
                          color: PortenColor.gray400,
                          strokeWidth: 2,
                        ),
                      ),
                    ],
                  ),
                ),
                // 展开区（max-height + opacity 过渡）
                AnimatedOpacity(
                  opacity: _expanded ? 1 : 0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    alignment: Alignment.topCenter,
                    child: _expanded
                        ? Padding(
                            padding: const EdgeInsets.only(top: 8), // pt-2
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Wrap(
                                spacing: 6, // gap-1.5
                                runSpacing: 6,
                                children: <Widget>[
                                  for (final String city in org.coveredCities)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: PortenColor.gray100,
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        city,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: PortenColor.gray600,
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          )
                        : const SizedBox(width: double.infinity),
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

/// 流程时间线节点（对齐 ProcessNodeItem.tsx）。
class _ProcessNodeItem extends StatefulWidget {
  const _ProcessNodeItem({
    required this.node,
    required this.index,
    required this.isLast,
    this.defaultExpanded = false,
  });

  final PortenProcessNode node;
  final int index;
  final bool isLast;
  final bool defaultExpanded;

  @override
  State<_ProcessNodeItem> createState() => _ProcessNodeItemState();
}

class _ProcessNodeItemState extends State<_ProcessNodeItem> {
  late bool _expanded = widget.defaultExpanded;

  @override
  Widget build(BuildContext context) {
    final PortenProcessNode node = widget.node;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16), // px-4
      child: Stack(
        children: <Widget>[
          // 时间线连接线（left-[27px]，节点中心）
          if (!widget.isLast)
            Positioned(
              left: 27, // left-[27px]（28 圆心 - 0.5 线宽）
              top: 28, // top-7
              bottom: 0,
              width: 1,
              child: Container(color: PortenColor.gray200),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // 序号圆点（porten-bg-gradient 白字 xs medium）
              Container(
                width: 28, // w-7 h-7
                height: 28,
                margin: const EdgeInsets.only(top: 2), // mt-0.5
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: <Color>[
                      PortenColor.brandBlue,
                      PortenColor.brandPink,
                      PortenColor.brandBlue,
                    ],
                  ),
                ),
                child: Text(
                  '${widget.index + 1}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: PortenColor.white,
                    height: 1.0,
                  ),
                ),
              ),
              const SizedBox(width: 16), // gap-4
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24), // pb-6
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // 标题 + 展开箭头
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _expanded = !_expanded),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text(
                              node.title,
                              style: PortenTypography.base.copyWith(
                                fontWeight: FontWeight.w500,
                                color: PortenColor.gray900,
                              ),
                            ),
                            AnimatedRotation(
                              turns: _expanded ? 0.25 : 0,
                              duration: const Duration(milliseconds: 300),
                              child: const PortenLucideIcon(
                                'chevron-right',
                                size: 16,
                                color: PortenColor.gray400,
                                strokeWidth: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 展开内容
                      AnimatedOpacity(
                        opacity: _expanded ? 1 : 0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        child: AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          alignment: Alignment.topCenter,
                          child: _expanded
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        node.content,
                                        style: PortenTypography.sm.copyWith(
                                          color: PortenColor.gray600,
                                          height: 1.625, // leading-relaxed
                                        ),
                                      ),
                                    ),
                                    if (node.note != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8), // mt-2
                                        child: Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(12), // p-3
                                          decoration: BoxDecoration(
                                            color: PortenColor.gray50,
                                            borderRadius:
                                                BorderRadius.circular(8), // rounded-lg
                                          ),
                                          child: Text.rich(
                                            TextSpan(
                                              children: <InlineSpan>[
                                                const TextSpan(
                                                  text: '国内外差异：',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                    color: PortenColor.gray700,
                                                    height: 1.625,
                                                  ),
                                                ),
                                                TextSpan(
                                                  text: node.note!,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: PortenColor.gray500,
                                                    height: 1.625,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                )
                              : const SizedBox(width: double.infinity),
                        ),
                      ),
                    ],
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
