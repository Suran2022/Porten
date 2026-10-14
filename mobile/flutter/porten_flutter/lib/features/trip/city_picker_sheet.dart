/*
 * 城市选择底部弹窗（100% 复刻 Web 端 components/trip/CityPickerSheet.tsx）。
 *
 * Web 端实现：
 *   - 两步流程：第一步选城市（字母分组列表 + 右侧字母索引条），单机场
 *     城市点击即选定关闭；双机场城市进入第二步「选择机场」；
 *   - 面板高度 h-[90vh]；标题随步骤切换（选择出发地/到达地 ↔ 选择机场），
 *     第二步标题左侧出现返回按钮回到城市列表；
 *   - 搜索框：浅灰圆角、提示文本居中、聚焦无样式变化（SheetSearchField）；
 *   - 城市行：左中文名（text-base gray-900）右英文名（text-sm gray-400），
 *     按压 gray-50 圆角反馈；
 *   - 第二步：左对齐城市名（text-lg 字重 600），机场名缩进，树杈竖线 +
 *     横枝连接（最后一行竖线只画到中线）；
 *   - 两步内容均带 sheet-step-in 入场（opacity 0→1 + translateY 8→0，
 *     250ms cubic-bezier(0.25,0.1,0.25,1) both）。
 *
 * App 侧差异点处理：
 *   - 标题随内部步骤状态变化：以 _CityPickerShell 自持路由（直接复用
 *     PortenBottomSheet 组件而非静态 show），步骤状态提升到 shell，
 *     重建时把最新标题/返回回调传给面板（对应 Web 父组件状态驱动
 *     title prop 重渲染）；
 *   - 字母索引点击定位：Web scrollIntoView({block:"start", smooth}) →
 *     分组头 GlobalKey + Scrollable.ensureVisible(alignment: 0, 300ms ease)；
 *   - Web 的 activeTarget 快照（防关闭动画期间标题闪变）在 App 侧不需要：
 *     面板每次打开全新挂载、关闭即销毁，不存在外部 target 回退时序。
 */

import 'package:flutter/material.dart';

import '../../core/components/porten_bottom_sheet.dart';
import '../../core/data/trip_mock.dart';
import '../../core/design/porten_colors.dart';
import 'trip_sheet_kit.dart';

/// 城市选择底部弹窗（静态入口）。
abstract final class CityPickerSheet {
  const CityPickerSheet._();

  /// 打开城市选择面板；选定城市（含机场）后回调，由调用方负责关闭面板。
  static Future<void> show(
    BuildContext context, {
    required String target,
    required void Function(City city, CityAirport airport) onSelect,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent, // 遮罩由面板自身绘制（带 300ms 淡入）
      transitionDuration: Duration.zero, // 动画由面板内部控制
      pageBuilder: (BuildContext ctx, _, _) => _CityPickerShell(
        target: target,
        onSelect: onSelect,
      ),
    );
  }
}

/// 面板宿主：自持步骤状态（city / airport），驱动标题与内容切换。
class _CityPickerShell extends StatefulWidget {
  const _CityPickerShell({required this.target, required this.onSelect});

  /// 目标文案：「出发地」/「到达地」，用于标题与搜索提示。
  final String target;

  final void Function(City city, CityAirport airport) onSelect;

  @override
  State<_CityPickerShell> createState() => _CityPickerShellState();
}

class _CityPickerShellState extends State<_CityPickerShell> {
  /// 当前步骤：city 选城市 / airport 选机场。
  String _step = 'city';

  /// 第二步选中的城市。
  City? _selectedCity;

  /// 搜索文本（每次打开面板均为全新控制器，等价 Web 打开时重置）。
  final TextEditingController _searchController = TextEditingController();

  /// 字母分组定位锚点（Web data-letter + scrollIntoView）。
  late final Map<String, GlobalKey> _letterKeys = <String, GlobalKey>{
    for (final CityGroup group in kCityGroups) group.letter: GlobalKey(),
  };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 按中文名 / 英文名过滤城市（同 Web filteredGroups）。
  List<CityGroup> get _filteredGroups {
    final String raw = _searchController.text.trim();
    if (raw.isEmpty) return kCityGroups;
    final String q = raw.toLowerCase();
    return kCityGroups
        .map((CityGroup group) => CityGroup(
              group.letter,
              group.cities
                  .where((City city) =>
                      city.name.contains(raw) ||
                      city.en.toLowerCase().contains(q))
                  .toList(),
            ))
        .where((CityGroup group) => group.cities.isNotEmpty)
        .toList();
  }

  void _handleCityTap(City city, VoidCallback close) {
    if (city.airports.length == 1) {
      // 单机场城市：自动匹配机场，直接关闭
      widget.onSelect(city, city.airports[0]);
      close();
    } else {
      // 多机场城市：不关闭，进入第二步选择机场
      setState(() {
        _selectedCity = city;
        _step = 'airport';
      });
    }
  }

  void _handleAirportTap(CityAirport airport, VoidCallback close) {
    final City? city = _selectedCity;
    if (city == null) return;
    widget.onSelect(city, airport);
    close();
  }

  /// 字母索引点击定位（Web scrollIntoView block:"start" smooth）。
  void _scrollToLetter(String letter) {
    final BuildContext? target = _letterKeys[letter]?.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 300), // behavior: "smooth"
      curve: Curves.ease,
      alignment: 0.0, // block: "start"：分组头顶到列表顶部
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<CityGroup> groups = _filteredGroups;
    return PortenBottomSheet(
      title: _step == 'city' ? '选择${widget.target}' : '选择机场',
      height: MediaQuery.sizeOf(context).height * 0.9, // h-[90vh]
      onBack: _step == 'airport'
          ? () => setState(() {
                _step = 'city';
                _selectedCity = null;
              })
          : null,
      onClose: () => Navigator.of(context).pop(),
      content: (BuildContext ctx, VoidCallback close) {
        if (_step == 'city') {
          return _CityStepBody(
            target: widget.target,
            groups: groups,
            controller: _searchController,
            letterKeys: _letterKeys,
            onQueryChanged: () => setState(() {}),
            onCityTap: (City city) => _handleCityTap(city, close),
            onLetterTap: _scrollToLetter,
          );
        }
        return _AirportStepBody(
          city: _selectedCity!,
          onAirportTap: (CityAirport airport) =>
              _handleAirportTap(airport, close),
        );
      },
    );
  }
}

/// 第一步：选择城市（搜索框 + 城市列表 + 字母索引条）。
class _CityStepBody extends StatelessWidget {
  const _CityStepBody({
    required this.target,
    required this.groups,
    required this.controller,
    required this.letterKeys,
    required this.onQueryChanged,
    required this.onCityTap,
    required this.onLetterTap,
  });

  final String target;
  final List<CityGroup> groups;
  final TextEditingController controller;
  final Map<String, GlobalKey> letterKeys;
  final VoidCallback onQueryChanged;
  final ValueChanged<City> onCityTap;
  final ValueChanged<String> onLetterTap;

  @override
  Widget build(BuildContext context) {
    return SheetStepIn( // sheet-step-in
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // 搜索框：px-4 py-2（提示文本居中、聚焦无样式变化）
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SheetSearchField(
              controller: controller,
              placeholder: '搜索$target',
              onChanged: (_) => onQueryChanged(),
            ),
          ),
          // 城市列表 + 字母索引条（flex-1 min-h-0 flex）
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(child: _buildCityList()),
                _LetterIndexBar(groups: groups, onLetterTap: onLetterTap),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCityList() {
    return ListView(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 32), // px-4 pb-8
      children: <Widget>[
        for (final CityGroup group in groups)
          Container(
            key: letterKeys[group.letter],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // 字母分组头：py-2 text-sm font-medium text-gray-400
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    group.letter,
                    style: const TextStyle(
                      fontSize: 14, // text-sm
                      fontWeight: FontWeight.w500, // font-medium
                      color: PortenColor.gray400,
                    ),
                  ),
                ),
                for (final City city in group.cities)
                  _CityRow(city: city, onTap: () => onCityTap(city)),
              ],
            ),
          ),
        if (groups.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48), // py-12
            child: Text(
              '未找到相关城市',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: PortenColor.gray400),
            ),
          ),
      ],
    );
  }
}

/// 城市行：左中文名右英文名，按压浅灰底圆角。
class _CityRow extends StatelessWidget {
  const _CityRow({required this.city, required this.onTap});

  final City city;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TripPressRow(
      onTap: onTap,
      builder: (bool pressed) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12), // py-3
        decoration: BoxDecoration(
          color: pressed ? PortenColor.gray50 : Colors.transparent, // active:bg-gray-50
          borderRadius: BorderRadius.circular(8), // rounded-lg
        ),
        child: Row(
          children: <Widget>[
            Text(
              city.name,
              style: const TextStyle(
                fontSize: 16, // text-base
                color: PortenColor.gray900,
              ),
            ),
            const Spacer(), // justify-between
            Text(
              city.en,
              style: const TextStyle(
                fontSize: 14, // text-sm
                color: PortenColor.gray400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 右侧字母索引条（Web：flex flex-col items-center justify-center gap-0.5 px-2）。
///
/// 稳健性处理：26 个字母在矮屏（内容高度 < 字母总高）时会超出面板，
/// Web 侧由面板 overflow-hidden 裁切；App 侧改为「不足时可滚动、
/// 足够时仍严格居中」——正常机型视觉与 Web 完全一致。
class _LetterIndexBar extends StatelessWidget {
  const _LetterIndexBar({required this.groups, required this.onLetterTap});

  final List<CityGroup> groups;
  final ValueChanged<String> onLetterTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8), // px-2
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints c) =>
            SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center, // justify-center
              children: <Widget>[
                for (int i = 0; i < groups.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(height: 2), // gap-0.5
                  _LetterCell(
                    letter: groups[i].letter,
                    onTap: () => onLetterTap(groups[i].letter),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 单个字母按钮（Web：w-5 h-4 text-xs text-gray-500 active:text-[#F5A9B8]）。
class _LetterCell extends StatefulWidget {
  const _LetterCell({required this.letter, required this.onTap});

  final String letter;
  final VoidCallback onTap;

  @override
  State<_LetterCell> createState() => _LetterCellState();
}

class _LetterCellState extends State<_LetterCell> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: SizedBox(
        width: 20, // w-5
        height: 16, // h-4
        child: Center(
          child: Text(
            widget.letter,
            style: TextStyle(
              fontSize: 12, // text-xs
              color: _pressed ? PortenColor.brandPink : PortenColor.gray500,
            ),
          ),
        ),
      ),
    );
  }
}

/// 第二步：选择机场（左对齐城市名 + 机场名缩进树杈分支线）。
class _AirportStepBody extends StatelessWidget {
  const _AirportStepBody({required this.city, required this.onAirportTap});

  final City city;
  final ValueChanged<CityAirport> onAirportTap;

  @override
  Widget build(BuildContext context) {
    return SheetStepIn( // sheet-step-in
      child: ListView(
        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 32), // px-5 pb-8
        children: <Widget>[
          // 城市名：pt-3 pb-1 text-lg font-semibold text-gray-900
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Text(
              city.name,
              style: const TextStyle(
                fontSize: 18, // text-lg
                fontWeight: FontWeight.w600, // font-semibold
                color: PortenColor.gray900,
              ),
            ),
          ),
          const SizedBox(height: 4), // mt-1
          for (int i = 0; i < city.airports.length; i++)
            _AirportRow(
              airport: city.airports[i],
              isLast: i == city.airports.length - 1,
              onTap: () => onAirportTap(city.airports[i]),
            ),
        ],
      ),
    );
  }
}

/// 机场行（Web：relative block w-full pl-7 pr-2 py-3.5 rounded-lg
/// active:bg-gray-50 + 树杈竖线/横枝）。
class _AirportRow extends StatelessWidget {
  const _AirportRow({
    required this.airport,
    required this.isLast,
    required this.onTap,
  });

  final CityAirport airport;

  /// 是否最后一行（竖线只画到中线、横枝对齐中线）。
  final bool isLast;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 行高 = py-3.5(28) + text-base 行高(24) = 52；半高 26 供末行树杈定位
    const double rowHeight = 52;
    const double halfHeight = 26;
    return TripPressRow(
      onTap: onTap,
      builder: (bool pressed) => Container(
        height: rowHeight,
        decoration: BoxDecoration(
          color: pressed ? PortenColor.gray50 : Colors.transparent,
          borderRadius: BorderRadius.circular(8), // rounded-lg
        ),
        child: Stack(
          children: <Widget>[
            // 树杈竖线：absolute left-1.5 top-0 w-px bg-gray-300，
            // 最后一行只画到中线（h-1/2）
            Positioned(
              left: 6, // left-1.5
              top: 0,
              width: 1, // w-px
              bottom: isLast ? halfHeight : 0,
              child: const ColoredBox(color: PortenColor.gray300),
            ),
            // 横向枝杈：absolute left-1.5 w-3 h-px bg-gray-300，
            // 末行对齐中线（top-1/2）
            Positioned(
              left: 6, // left-1.5
              top: isLast ? halfHeight : 0,
              width: 12, // w-3
              height: 1, // h-px
              child: const ColoredBox(color: PortenColor.gray300),
            ),
            // 机场名：pl-7 pr-2，垂直居中
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.only(left: 28, right: 8), // pl-7 pr-2
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    airport.name,
                    style: const TextStyle(
                      fontSize: 16, // text-base
                      height: 1.5, // 24px 行高（与半高推算一致）
                      color: PortenColor.gray900,
                    ),
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
