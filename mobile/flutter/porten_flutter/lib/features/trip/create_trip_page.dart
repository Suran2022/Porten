/*
 * 创建我的行程独立页面（100% 复刻 Web 端 pages/CreateTripPage.tsx）。
 *
 * Web 端实现：
 *   - 页面白底、右侧滑入转场（同 TripPage 模式，PortenSlideFromRightRoute）；
 *   - 顶栏：返回图标（w-10 h-10 -ml-2）+ 居中「创建我的行程」text-lg
 *     medium + w-8 占位；
 *   - 主内容（px-4 pt-2 pb-6，可滚动）：一张白卡（rounded-2xl border
 *     gray-100 px-5）分三部分依次填写——
 *       ① 出发/到达城市：两端 flex-1（已选：城市名 text-lg semibold +
 *          机场名 text-xs gray-400 truncate；未选：出发地/到达地 text-lg
 *          gray-400），中间虚线 + 飞机图标 16px（复用行程卡片样式）；
 *       ② 出发时间：py-5 border-t gray-100，已选「YYYY年M月D日」
 *          text-lg semibold，右侧 ChevronRight 16 gray-300；
 *       ③ 承运航司：同行结构，已选显示航司图标 16 + 名字；
 *   - 四选全部完成后显示「取消旅程 / 创建旅程」按钮（复用时间选择弹层
 *     按钮样式：取消浅灰 / 确定淡粉），带 sheet-step-in 入场；
 *   - 创建：Toast「旅程创建成功」success 后返回；取消旅程同返回。
 */

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/components/porten_back_icon.dart';
import '../../core/components/porten_bottom_sheet.dart';
import '../../core/components/porten_lucide_icons.dart';
import '../../core/components/porten_toast.dart';
import '../../core/data/trip_mock.dart';
import '../../core/design/porten_colors.dart';
import 'airline_picker_sheet.dart';
import 'city_picker_sheet.dart';
import 'time_picker_sheet.dart';
import 'trip_sheet_kit.dart';

/// 创建我的行程页（从右滑入，对齐 Web translate-x-full）。
class CreateTripPage extends StatefulWidget {
  const CreateTripPage({super.key});

  @override
  State<CreateTripPage> createState() => _CreateTripPageState();
}

class _CreateTripPageState extends State<CreateTripPage> {
  City? _departureCity;
  CityAirport? _departureAirport;
  City? _arrivalCity;
  CityAirport? _arrivalAirport;
  DateTime? _time;
  Airline? _airline;

  /// 四选全部完成（Web completed）。
  bool get _completed =>
      _departureCity != null &&
      _arrivalCity != null &&
      _time != null &&
      _airline != null;

  void _handleDepartureTap() {
    CityPickerSheet.show(
      context,
      target: '出发地',
      onSelect: (City city, CityAirport airport) {
        setState(() {
          _departureCity = city;
          _departureAirport = airport;
        });
      },
    );
  }

  void _handleArrivalTap() {
    CityPickerSheet.show(
      context,
      target: '到达地',
      onSelect: (City city, CityAirport airport) {
        setState(() {
          _arrivalCity = city;
          _arrivalAirport = airport;
        });
      },
    );
  }

  void _handleTimeTap() {
    TimePickerSheet.show(
      context,
      value: _time,
      onConfirm: (DateTime date) {
        setState(() => _time = date);
      },
    );
  }

  void _handleAirlineTap() {
    AirlinePickerSheet.show(
      context,
      onSelect: (Airline airline) {
        setState(() => _airline = airline);
      },
    );
  }

  /// 创建旅程：Mock 阶段提示成功后返回（Web showToast + navigate(-1)）。
  void _handleCreate() {
    PortenToast.show('旅程创建成功', icon: ToastIcon.success);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PortenColor.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            _buildTopBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom: 24,
                ), // px-4 pt-2 pb-6
                children: <Widget>[
                  _buildFormCard(),
                  // 四选全部完成后：取消旅程 / 创建旅程（sheet-step-in 入场）
                  if (_completed) ...<Widget>[
                    const SizedBox(height: 24), // mt-6
                    SheetStepIn(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4), // px-1
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: PortenSheetCancelButton(
                                label: '取消旅程',
                                onTap: () => Navigator.of(context).pop(),
                              ),
                            ),
                            const SizedBox(width: 12), // gap-3
                            Expanded(
                              child: PortenSheetConfirmButton(
                                label: '创建旅程',
                                onTap: _handleCreate,
                              ),
                            ),
                          ],
                        ),
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

  /// 顶部栏：返回图标（-ml-2）+ 居中「创建我的行程」+ w-8 占位。
  Widget _buildTopBar() {
    return Padding(
      // px-4 + -ml-2 → 左 8：返回键盒 [8,48]，与 Web margin 盒逐像素一致。
      // （Flutter Padding 断言拒绝负内边距、Transform 不外扩命中区，
      // 故以收窄左内距等价实现负外距；同 chat_page 顶栏范式）
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
      child: SizedBox(
        height: 40, // 顶栏行高（w-10 h-10）
        child: Row(
          children: <Widget>[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
              child: const SizedBox(
                width: 40, // w-10
                height: 40, // h-10
                child: Center(child: PortenBackIcon(size: 28)), // w-7 h-7
              ),
            ),
            const Expanded(
              child: Text(
                '创建我的行程',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18, // text-lg
                  fontWeight: FontWeight.w500, // font-medium
                  color: PortenColor.gray900,
                ),
              ),
            ),
            const SizedBox(width: 32), // w-8
          ],
        ),
      ),
    );
  }

  /// 三部分填写卡片（白卡 rounded-2xl border gray-100 px-5）。
  Widget _buildFormCard() {
    return Container(
      decoration: BoxDecoration(
        color: PortenColor.white,
        borderRadius: BorderRadius.circular(16), // rounded-2xl
        border: Border.all(color: PortenColor.gray100), // border-gray-100
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20), // px-5
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildEndpointsRow(),
          _buildTimeRow(),
          _buildAirlineRow(),
        ],
      ),
    );
  }

  /// 第一部分：出发与到达城市（中间虚线航程 + 飞机图标）。
  Widget _buildEndpointsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24), // py-6
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center, // items-center
        children: <Widget>[
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _handleDepartureTap,
              child: _buildEndpointField(
                city: _departureCity,
                airport: _departureAirport,
                placeholder: '出发地',
                alignEnd: false,
              ),
            ),
          ),
          // 虚线航程 + 飞机（复用行程卡片样式）
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12), // px-3
              child: Row(
                children: <Widget>[
                  const Expanded(child: _DashedLine()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6), // mx-1.5
                    child: SvgPicture.asset(
                      'assets/icons/porten_trip_icon.svg',
                      width: 16, // w-4
                      height: 16, // h-4
                      fit: BoxFit.contain,
                    ),
                  ),
                  const Expanded(child: _DashedLine()),
                ],
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _handleArrivalTap,
              child: _buildEndpointField(
                city: _arrivalCity,
                airport: _arrivalAirport,
                placeholder: '到达地',
                alignEnd: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 单端（出发/到达）字段：已选城市名 + 机场名，未选占位文案。
  Widget _buildEndpointField({
    required City? city,
    required CityAirport? airport,
    required String placeholder,
    required bool alignEnd,
  }) {
    final CrossAxisAlignment cross =
        alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final TextAlign textAlign = alignEnd ? TextAlign.right : TextAlign.left;
    if (city == null || airport == null) {
      return Text(
        placeholder,
        textAlign: textAlign,
        style: const TextStyle(
          fontSize: 18, // text-lg
          color: PortenColor.gray400,
        ),
      );
    }
    return Column(
      crossAxisAlignment: cross,
      children: <Widget>[
        Text(
          city.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          style: const TextStyle(
            fontSize: 18, // text-lg
            fontWeight: FontWeight.w600, // font-semibold
            color: PortenColor.gray900,
          ),
        ),
        const SizedBox(height: 4), // mt-1
        Text(
          airport.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          style: const TextStyle(
            fontSize: 12, // text-xs
            color: PortenColor.gray400,
          ),
        ),
      ],
    );
  }

  /// 第二部分：出发时间（py-5 border-t gray-100 + ChevronRight）。
  Widget _buildTimeRow() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTimeTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20), // py-5
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: PortenColor.gray100), // border-t gray-100
          ),
        ),
        child: Row(
          children: <Widget>[
            if (_time != null)
              Text(
                '${_time!.year}年${_time!.month}月${_time!.day}日',
                style: const TextStyle(
                  fontSize: 18, // text-lg
                  fontWeight: FontWeight.w600, // font-semibold
                  color: PortenColor.gray900,
                ),
              )
            else
              const Text(
                '出发时间',
                style: TextStyle(
                  fontSize: 18, // text-lg
                  color: PortenColor.gray400,
                ),
              ),
            const Spacer(),
            const PortenLucideIcon('chevron-right',
                size: 16, color: PortenColor.gray300), // w-4 h-4 gray-300
          ],
        ),
      ),
    );
  }

  /// 第三部分：承运航司（同行结构，已选显示航司图标 + 名字）。
  Widget _buildAirlineRow() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleAirlineTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20), // py-5
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: PortenColor.gray100), // border-t gray-100
          ),
        ),
        child: Row(
          children: <Widget>[
            if (_airline != null)
              Row(
                children: <Widget>[
                  SvgPicture.asset(
                    _airline!.iconAsset,
                    width: 16, // w-4
                    height: 16, // h-4
                    fit: BoxFit.contain, // object-contain
                  ),
                  const SizedBox(width: 8), // gap-2
                  Text(
                    _airline!.name,
                    style: const TextStyle(
                      fontSize: 18, // text-lg
                      fontWeight: FontWeight.w600, // font-semibold
                      color: PortenColor.gray900,
                    ),
                  ),
                ],
              )
            else
              const Text(
                '承运航司',
                style: TextStyle(
                  fontSize: 18, // text-lg
                  color: PortenColor.gray400,
                ),
              ),
            const Spacer(),
            const PortenLucideIcon('chevron-right',
                size: 16, color: PortenColor.gray300), // w-4 h-4 gray-300
          ],
        ),
      ),
    );
  }
}

/// 虚线（border-t border-dashed border-gray-300 等效；与 TripPage 同参数）。
class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final double w = c.maxWidth;
        const double dash = 3;
        const double gap = 3;
        final int n = (w / (dash + gap)).floor();
        return Row(
          children: <Widget>[
            for (int i = 0; i < n; i++) ...<Widget>[
              Container(
                width: dash,
                height: 1,
                color: const Color(0xFFD1D5DB), // gray-300
              ),
              const SizedBox(width: gap),
            ],
          ],
        );
      },
    );
  }
}
