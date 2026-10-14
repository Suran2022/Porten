/*
 * 跨儿职场独立页面（100% 复刻 Web 端 pages/WorkplacePage.tsx 移动端形态）。
 *
 * Web 端实现：
 *   - 白底，从右滑入 translate-x-full → 0（300ms
 *     cubic-bezier(0.25,0.1,0.25,1)，同我的日程页模式）；
 *   - 顶部栏：返回图标 + 居中「我的工作」+ 右 w-8 占位；
 *   - 主内容区始终挂载滚动容器：空状态撑满可视区垂直居中——
 *     职场插画（w-36 h-36，Web 端 assets/workplace-empty.svg 同款资产）
 *     + mt-4 text-sm gray-400 居中文案「还没有工作哟，去添加现在的工作趴！」；
 *   - 内容区底部 h-24 滚动余量（内容不足一屏也保留可滑动距离）；
 *   - 右下悬浮淡蓝胶囊「添加工作」：h-11 px-5 rounded-full bg-blue-100，
 *     Plus 20 text-blue-500 + text-sm font-medium text-blue-500；
 *     点击 toast「添加工作功能即将上线，敬请期待」（页面暂未实现）。
 */

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/components/porten_back_icon.dart';
import '../../core/components/porten_lucide_icons.dart';
import '../../core/components/porten_toast.dart';
import '../../core/design/porten_colors.dart';

/// 淡蓝胶囊按钮底色（Web bg-blue-100）。
const Color kBlue100 = Color(0xFFDBEAFE);

/// 淡蓝胶囊按钮前景（Web text-blue-500）。
const Color kBlue500 = Color(0xFF3B82F6);

class WorkplacePage extends StatelessWidget {
  const WorkplacePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PortenColor.white,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: <Widget>[
            Column(
              children: <Widget>[
                _buildTopBar(context),
                // 主内容区：始终挂载滚动容器（空状态下同样支持滑动）
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: <Widget>[
                        // 空状态：撑满可视区垂直居中
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height -
                              56 - // 顶栏高（40 + 上下 padding 24）
                              MediaQuery.paddingOf(context).top -
                              24, // 底部滚动余量 h-24
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              // 职场插画：w-36 h-36
                              SvgPicture.asset(
                                'assets/icons/workplace-empty.svg',
                                width: 144,
                                height: 144,
                              ),
                              const SizedBox(height: 16), // mt-4
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 32), // px-8
                                child: Text(
                                  '还没有工作哟，去添加现在的工作趴！',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14, // text-sm
                                    color: PortenColor.gray400,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // 底部滚动余量：h-24
                        const SizedBox(height: 96),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // 右下悬浮淡蓝胶囊「添加工作」
            Positioned(
              right: 20, // right-5
              bottom: 24, // bottom-6
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => PortenToast.show('添加工作功能即将上线，敬请期待'),
                child: Container(
                  height: 44, // h-11
                  padding: const EdgeInsets.symmetric(horizontal: 20), // px-5
                  decoration: BoxDecoration(
                    color: kBlue100, // bg-blue-100
                    borderRadius: BorderRadius.circular(22), // rounded-full
                  ),
                  child: Row(
                    children: <Widget>[
                      const PortenLucideIcon('plus',
                          size: 20, color: kBlue500, strokeWidth: 2), // w-5 h-5
                      const SizedBox(width: 6), // gap-1.5
                      const Text(
                        '添加工作',
                        style: TextStyle(
                          fontSize: 14, // text-sm
                          fontWeight: FontWeight.w500, // font-medium
                          color: kBlue500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      // px-4 + -ml-2 → 左 8：返回键盒 [8,48]，与 Web margin 盒逐像素一致。
      // （Flutter Padding 断言拒绝负内边距、Transform 不外扩命中区，
      // 故以收窄左内距等价实现负外距；同 chat_page 顶栏范式）
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
      child: SizedBox(
        height: 40,
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
                '我的工作',
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
}