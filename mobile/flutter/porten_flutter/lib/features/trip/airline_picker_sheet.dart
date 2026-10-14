/*
 * 承运航司选择底部弹窗（100% 复刻 Web 端 components/trip/AirlinePickerSheet.tsx）。
 *
 * Web 端实现：
 *   - BottomSheet「承运航司」，自适应高度；
 *   - 搜索框复用城市选择样式（提示文本改为「搜索航司」，聚焦无样式变化）；
 *   - 航司列表：左对齐，图标在前名字在后（图标 16px 与文本 text-base
 *     视觉 size 一致），行 py-3.5 px-1 gap-3，按压 gray-50 圆角反馈；
 *   - 名字 text-base leading-none font-semibold text-gray-900；
 *   - 无匹配结果：居中 text-sm gray-400「未找到相关航司」。
 */

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/components/porten_bottom_sheet.dart';
import '../../core/data/trip_mock.dart';
import '../../core/design/porten_colors.dart';
import 'trip_sheet_kit.dart';

/// 承运航司选择底部弹窗（静态入口）。
abstract final class AirlinePickerSheet {
  const AirlinePickerSheet._();

  /// 打开航司选择面板；选定航司后回调，由调用方负责关闭面板。
  static Future<void> show(
    BuildContext context, {
    required void Function(Airline airline) onSelect,
  }) {
    return PortenBottomSheet.show(
      context,
      title: '承运航司',
      content: (BuildContext ctx, VoidCallback close) => _AirlinePickerBody(
        onSelect: (Airline airline) {
          onSelect(airline);
          close();
        },
      ),
    );
  }
}

class _AirlinePickerBody extends StatefulWidget {
  const _AirlinePickerBody({required this.onSelect});

  final void Function(Airline airline) onSelect;

  @override
  State<_AirlinePickerBody> createState() => _AirlinePickerBodyState();
}

class _AirlinePickerBodyState extends State<_AirlinePickerBody> {
  /// 搜索文本（每次打开面板均为全新控制器，等价 Web 打开时重置）。
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 按名字过滤（同 Web：name.includes(query.trim())）。
  List<Airline> get _filtered {
    final String q = _searchController.text.trim();
    if (q.isEmpty) return kAirlines;
    return kAirlines.where((Airline a) => a.name.contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final List<Airline> filtered = _filtered;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // 搜索框：px-4 py-2（复用城市选择搜索框样式，仅提示文本不同）
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SheetSearchField(
            controller: _searchController,
            placeholder: '搜索航司',
            onChanged: (_) => setState(() {}),
          ),
        ),
        // 航司列表：flex-1 min-h-0，自适应高度（超长时内部滚动）
        Flexible(
          fit: FlexFit.loose,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 32), // px-5 pb-8
            children: <Widget>[
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48), // py-12
                  child: Text(
                    '未找到相关航司',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: PortenColor.gray400),
                  ),
                )
              else
                for (final Airline airline in filtered)
                  _AirlineRow(
                    airline: airline,
                    onTap: () => widget.onSelect(airline),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 航司行：图标在前、名字在后（text-base leading-none font-semibold）。
class _AirlineRow extends StatelessWidget {
  const _AirlineRow({required this.airline, required this.onTap});

  final Airline airline;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TripPressRow(
      onTap: onTap,
      builder: (bool pressed) => Container(
        height: 44, // py-3.5(28) + leading-none 行高(16)
        padding: const EdgeInsets.symmetric(horizontal: 4), // px-1
        decoration: BoxDecoration(
          color: pressed ? PortenColor.gray50 : Colors.transparent, // active:bg-gray-50
          borderRadius: BorderRadius.circular(8), // rounded-lg
        ),
        child: Row(
          children: <Widget>[
            SvgPicture.asset(
              airline.iconAsset,
              width: 16, // w-4
              height: 16, // h-4
              fit: BoxFit.contain, // object-contain
            ),
            const SizedBox(width: 12), // gap-3
            Text(
              airline.name,
              style: const TextStyle(
                fontSize: 16, // text-base
                height: 1, // leading-none
                fontWeight: FontWeight.w600, // font-semibold
                color: PortenColor.gray900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
