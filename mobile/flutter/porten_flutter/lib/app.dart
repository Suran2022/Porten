/*
 * Flutter 应用根组件。
 *
 * 职责：
 *   1. 装配 PortenTheme（禁用水波纹 + 缩放密度 + 品牌配色）；
 *   2. 下发 PortenScale（等比缩放系数，与 Kotlin 侧 PortenScaling 同源）；
 *   3. 承载路由（go_router），页面结构对齐 React Web 端。
 */

import 'package:flutter/material.dart';

import 'core/design/porten_theme.dart';
import 'core/design/porten_typography.dart';

/// Porten Flutter 应用根 Widget。
class PortenApp extends StatelessWidget {
  const PortenApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 路由表由 core/navigation 模块提供（Phase 2 接入 go_router）；
    // 骨架阶段先挂载占位首页，保证引擎装载即可见、不白屏。
    return PortenTheme(
      child: MaterialApp(
        title: 'Porten',
        debugShowCheckedModeBanner: false,
        home: const _SkeletonHomePage(),
      ),
    );
  }
}

/// 骨架阶段占位首页（Phase 2 由 go_router 路由表替换）。
class _SkeletonHomePage extends StatelessWidget {
  const _SkeletonHomePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: Center(
        child: Text(
          'Porten',
          style: PortenTypography.x3l,
        ),
      ),
    );
  }
}
