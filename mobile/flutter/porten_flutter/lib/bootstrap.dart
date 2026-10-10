/*
 * Flutter 侧启动编排（与原生 AppBootstrap 对齐的镜像设计）。
 *
 * 职责边界：
 *   - Flutter 入口保持极简：runApp 一个 ProviderScope + PortenApp，不处理业务；
 *   - 启动期任务（Mock 引擎预热、桥接通道注册、主题令牌装配）全部收敛到 bootstrap 流程；
 *   - 防御性编程：任何启动任务失败都不应导致白屏，降级进入可用状态。
 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

/// Flutter 侧唯一入口。
///
/// 原生壳通过 FlutterEngine 缓存预热后调用此入口；保持极简，禁止在此追加逻辑。
void runPortenFlutterApp() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: PortenApp()));
}
