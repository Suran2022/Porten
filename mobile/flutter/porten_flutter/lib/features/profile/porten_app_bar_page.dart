/*
 * 应用栏管理页（100% 移植 Web 端 components/profile/PortenAppBarPage.tsx
 * 移动端形态：fixed inset-0 z-[65] bg-white 右滑入；PC 端 closeMode
 * 弹窗形态不涉及，app 仅实现移动形态）。
 *
 * 结构：顶栏 BackIcon（p-1 -ml-1 text-gray-700）+ ml-3「应用栏管理」
 *   text-lg font-medium gray-900（无分割线）；
 *   说明 text-xs gray-400 mt-2 mb-2 px-4「开启后，底部菜单栏会展示对应入口」；
 *   选项行 px-4 py-4：左侧 w-11 h-11 rounded-xl 粉→蓝渐变图标容器
 *   （Music2 w-5 h-5 gray-700 strokeWidth 1.8）+ 两行文案
 *   （text-[15px] gray-900 w500「情绪音乐馆」+
 *   text-xs gray-400 mt-0.5「在底部栏展示「悦音乐」入口」）；
 *   右侧开关 w-[52px] h-[30px] rounded-full（开：品牌面渐变 + 8s 流光；
 *   关：bg-gray-300），滑块 w-[26px] h-[26px] bg-white rounded-full shadow，
 *   on 时 translate-x-[22px]，transition 200ms。
 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/components/porten_back_icon.dart';
import '../../../core/components/porten_brand_switch.dart';
import '../../../core/components/porten_lucide_icons.dart';
import '../../../core/design/porten_colors.dart';
import '../home/state/app_bar_config_provider.dart';

class PortenAppBarPage extends ConsumerWidget {
  const PortenAppBarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool showMusic = ref.watch(appBarConfigProvider).showMusic;
    return Scaffold(
      backgroundColor: PortenColor.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            // 顶栏（白底无分割线：BackIcon + ml-3 标题）
            Container(
              color: PortenColor.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: SizedBox(
                height: 36, // BackIcon w-7(28) + p-1*2(8)
                child: Row(
                  children: <Widget>[
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).maybePop(),
                      // -ml-1：Container margin 不支持负值，Transform 位移等价
                      child: Transform.translate(
                        offset: const Offset(-4, 0),
                        child: const Padding(
                          padding: EdgeInsets.all(4), // p-1
                          child: PortenBackIcon(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12), // ml-3
                    Text('应用栏管理',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: PortenColor.gray900)),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // 说明文案（text-xs gray-400 mt-2 mb-2 px-4）
                    Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 8), // mt-2 mb-2
                      padding: const EdgeInsets.symmetric(horizontal: 16), // px-4
                      child: const Text('开启后，底部菜单栏会展示对应入口',
                          style: TextStyle(
                              fontSize: 12, color: PortenColor.gray400)),
                    ),
                    // 情绪音乐馆行（px-4 py-4）
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              // 粉→蓝渐变图标容器（w-11 h-11 rounded-xl）
                              Container(
                                width: 44, // w-11
                                height: 44, // h-11
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12), // rounded-xl
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft, // to-br
                                    end: Alignment.bottomRight,
                                    colors: <Color>[
                                      Color(0xFFFCE7F3), // pink-100
                                      Color(0xFFDBEAFE), // blue-100
                                    ],
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: const PortenLucideIcon('music2',
                                    size: 20,
                                    color: PortenColor.gray700,
                                    strokeWidth: 1.8),
                              ),
                              const SizedBox(width: 12), // gap-3
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const <Widget>[
                                  Text('情绪音乐馆',
                                      style: TextStyle(
                                        fontSize: 15, // text-[15px]
                                        fontWeight: FontWeight.w500, // font-medium
                                        color: PortenColor.gray900,
                                      )),
                                  SizedBox(height: 2), // mt-0.5
                                  Text('在底部栏展示「悦音乐」入口',
                                      style: TextStyle(
                                        fontSize: 12, // text-xs
                                        color: PortenColor.gray400,
                                      )),
                                ],
                              ),
                            ],
                          ),
                          // 品牌渐变开关
                          PortenBrandSwitch(
                            value: showMusic,
                            onChanged: (bool value) => ref
                                .read(appBarConfigProvider.notifier)
                                .setShowMusic(value),
                          ),
                        ],
                      ),
                    ),
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
