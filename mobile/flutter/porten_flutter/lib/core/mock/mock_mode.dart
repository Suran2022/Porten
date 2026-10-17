/*
 * Mock 引擎 · 模式管理（对齐 React Web 端 src/mock/mockMode.ts）。
 *
 * 能力目标：与 Web 端一致提供「Mock / 真实 API 一键切换」，
 * 差异点：App 端的开关由 Android 原生注入（gradle flavor 的 USE_MOCK + 运行时设置页），
 * Flutter 侧只读，不允许 UI 随意翻转生产开关（防御性设计，防误触与防逆向篡改）。
 */

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bridge/porten_channels.dart';

/// 数据源模式。
enum PortenMockMode {
  /// 端内 Mock 引擎生成数据（演示/无后端环境）。
  mock,

  /// 直连真实后端。
  live,
}

/// Mock 模式全局状态（Riverpod Notifier，对齐 Web 端 Zustand 的 mockMode store）。
class MockModeNotifier extends Notifier<PortenMockMode> {
  @override
  PortenMockMode build() => PortenMockMode.mock;

  /// 更新当前模式（仅允许启动编排器在桥接注入后调用一次）。
  void set(PortenMockMode mode) => state = mode;
}

final NotifierProvider<MockModeNotifier, PortenMockMode> mockModeProvider =
    NotifierProvider<MockModeNotifier, PortenMockMode>(MockModeNotifier.new);

/// 从原生侧读取当前模式（App 启动时由原生 env 桥注入，Flutter 不自行决策）。
///
/// 返回 null 表示原生未注册（纯 Flutter 调试），此时保持默认 mock。
Future<PortenMockMode> resolveInitialMockMode() async {
  final String? raw = await PortenChannels.env.invokeSafe<String>('mockMode');
  switch (raw) {
    case 'live':
      return PortenMockMode.live;
    case 'mock':
      return PortenMockMode.mock;
    default:
      return PortenMockMode.mock;
  }
}
