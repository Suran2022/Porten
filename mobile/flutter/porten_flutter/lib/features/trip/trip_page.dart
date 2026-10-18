/*
 * 我的行程页（100% 移植 Web 端 pages/TripPage.tsx 移动端形态）。
 *
 * 结构：
 *   顶部 39% 高度淡咖啡色渐变背景（#F2DDBC → #F7E9D2 → 白），向下自然融合；
 *   顶栏：BackIcon + 居中（trip 图标 20 + 「我的行程」text-lg medium）；
 *   行程卡片列表（px-4 pt-3 pb-8 gap-3，白卡 rounded-2xl p-4）：
 *     行1：绿色竖条 w-1.5 h-5 + 标题 text-lg semibold + 右航司（icon 12 + xs）；
 *     行2 mt-5：出发城市 semibold + 时间（green-600 medium）+ 机场名（xs gray-400）
 *       ｜中间 直达/中转胶囊 + 虚线 + 飞机图标 + 虚线｜到达同构；
 *     行3（部分卡片）：tips 底色 #FBF4E8 rounded-[10px] px-3 py-2.5 xs gray-500。
 *   下拉刷新：复用 PortenPullToRefresh（数据由旅程控制器重拉）。
 *
 * 数据源：旅程控制器（Mock / Live 一键切换）——mock 通道为 TripStore
 * 种子数据（创建旅程后同步进列表），live 通道经 porten/data 桥拉取
 * 真实数据；标题 / 提醒 / 航司图标均由数据层派生，页面只展示。
 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/components/porten_back_icon.dart';
import '../../core/components/porten_pull_to_refresh.dart';
import '../../core/data/trip_controller.dart';
import '../../core/data/trip_store.dart';
import '../profile/profile_page.dart' show kGray900;

const Color kTripHeader = Color(0xFFF2DDBC);
const Color kGreen600 = Color(0xFF16A34A);
const Color kGray400 = Color(0xFF9CA3AF);
const Color kGray500 = Color(0xFF6B7280);

/// 我的行程页（从右滑入，对齐 Web translate-x-full）。
class TripPage extends ConsumerWidget {
  const TripPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<TripBoardData> tripAsync = ref.watch(tripControllerProvider);
    final List<TripItem> items = tripAsync.value?.items ?? const <TripItem>[];

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: <Widget>[
          // 顶部 39% 咖啡渐变背景
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 260, // 39% of viewport ≈ 660×0.39，取视觉近似
            child: IgnorePointer(
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const <double>[0.0, 0.45, 0.8, 1.0],
                          colors: <Color>[
                            kTripHeader,
                            const Color(0xFFF7E9D2),
                            Colors.white,
                            Colors.white,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
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
                              child:
                                  Center(child: PortenBackIcon(size: 26))),
                        ),
                        const Spacer(),
                        SvgPicture.asset(
                          'assets/icons/porten_trip_icon.svg',
                          width: 20,
                          height: 20,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(width: 6),
                        const Text('我的行程',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: kGray900)),
                        const Spacer(),
                        const SizedBox(width: 40),
                      ],
                    ),
                  ),
                ),
                // 卡片列表（下拉刷新：由旅程控制器重拉，mock 读 TripStore）
                Expanded(
                  child: PortenPullToRefresh(
                    onRefresh: () =>
                        ref.read(tripControllerProvider.notifier).refresh(),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      child: Column(
                        children: <Widget>[
                          for (final TripItem item in items)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _TripCard(item: item),
                            ),
                        ],
                      ),
                    ),
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

/// 行程卡片（对齐 TripPage 卡片结构）。
class _TripCard extends StatelessWidget {
  const _TripCard({required this.item});

  final TripItem item;

  @override
  Widget build(BuildContext context) {
    final bool direct = item.transferType == '直达';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 行1：竖条 + 标题 + 航司
          Row(
            children: <Widget>[
              Container(
                width: 6,
                height: 20,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: kGray900)),
              ),
              const SizedBox(width: 8),
              SvgPicture.asset(item.airlineIcon,
                  width: 12, height: 12, fit: BoxFit.contain),
              const SizedBox(width: 4),
              Text(item.airline,
                  style:
                      const TextStyle(fontSize: 12, color: kGray500)),
            ],
          ),
          // 行2：城市/时间/机场 + 中间虚线航程
          // r22：三段全部用 Expanded（对齐 Web flex items-start 三段分列）。
          // 原实现的中间段为 Row 非 flex 子项，其内部 Expanded 收到无界宽度
          // 约束导致 release 布局炸裂（灰色大块、文字竖排）。
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: <Widget>[
                          Flexible(
                            child: Text(item.departureCity,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: kGray900)),
                          ),
                          const SizedBox(width: 8),
                          Text(item.departureTime,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: kGreen600)),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(item.departureAirport,
                            style: const TextStyle(
                                fontSize: 12, color: kGray400)),
                      ),
                    ],
                  ),
                ),
                // 中间：直达/中转胶囊 + 虚线 + 飞机（Expanded 内宽度有界）
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: direct
                                ? const Color(0xFFF0FDF4)
                                : const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(item.transferType,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: direct
                                      ? kGreen600
                                      : const Color(0xFFD97706))),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: SizedBox(
                            width: double.infinity,
                            child: Row(
                              children: <Widget>[
                                const Expanded(child: _DashedLine()),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6),
                                  child: SvgPicture.asset(
                                    'assets/icons/porten_trip_icon.svg',
                                    width: 16,
                                    height: 16,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                const Expanded(child: _DashedLine()),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: <Widget>[
                          Flexible(
                            child: Text(item.arrivalCity,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: kGray900)),
                          ),
                          const SizedBox(width: 8),
                          Text(item.arrivalTime ?? '',
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: kGreen600)),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(item.arrivalAirport,
                            style: const TextStyle(
                                fontSize: 12, color: kGray400)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 行3：tips
          if (item.tips != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBF4E8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(item.tips!,
                    style: const TextStyle(
                        fontSize: 12,
                        color: kGray500,
                        height: 1.625)),
              ),
            ),
        ],
      ),
    );
  }
}

/// 虚线（border-dashed 等效）。
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
                color: const Color(0xFFD1D5DB),
              ),
              const SizedBox(width: gap),
            ],
          ],
        );
      },
    );
  }
}
