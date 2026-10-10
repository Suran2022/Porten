/*
 * Mock 引擎核心（借鉴 React Web 端 src/mock/mockEngine.ts 的设计与一键切换能力）。
 *
 * 设计要点：
 *   1. 请求拦截式：业务层始终面向统一数据源接口（Repository），Mock 引擎在
 *      mockModeProvider == mock 时接管数据生成，业务代码零感知；
 *   2. Handler 注册表：每个业务域（会话/消息/行程…）注册自己的 mock handler，
 *      与 Web 端 mockEngine 的 route 表结构对齐，便于逐域移植；
 *   3. 延迟模拟：还原真实网络的往返延迟，保证 UI 交互（骨架屏/加载态）可被完整验证；
 *   4. 确定性随机：使用固定 seed 的随机数，保证演示数据在会话间可复现。
 */

import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mock_mode.dart';

/// Mock 请求上下文。
class MockRequest {
  MockRequest({required this.path, this.payload, this.query});

  /// 业务路径，形如 `/sessions`、`/sessions/:id/messages`。
  final String path;
  final Map<String, Object?>? payload;
  final Map<String, String>? query;
}

/// Mock 处理器：返回模拟数据（任意 JSON 可序列化结构）。
typedef MockHandler = Future<Object?> Function(MockRequest request);

/// Mock 引擎。
///
/// 用法：
/// ```dart
/// final engine = MockEngine()..register('/sessions', (req) async => fakeSessions);
/// final data = await engine.dispatch(MockRequest(path: '/sessions'));
/// ```
class MockEngine {
  final Map<String, MockHandler> _handlers = <String, MockHandler>{};
  final Random _random = Random(20260101);

  /// 模拟网络延迟区间（毫秒），对齐真实弱网手感。
  static const int _minLatencyMs = 120;
  static const int _maxLatencyMs = 480;

  /// 注册某路径的 Mock 处理器；重复注册视为编程错误，立即抛出（防御性）。
  void register(String path, MockHandler handler) {
    assert(!_handlers.containsKey(path), 'Mock handler 重复注册：$path');
    _handlers[path] = handler;
  }

  /// 是否已注册某路径。
  bool contains(String path) => _handlers.containsKey(path);

  /// 分发请求；未注册路径立即抛错（暴露移植遗漏，而非静默返回空数据）。
  Future<Object?> dispatch(MockRequest request, {required Ref ref}) async {
    final MockHandler? handler = _handlers[request.path];
    if (handler == null) {
      throw StateError('Mock 引擎未注册路径：${request.path}');
    }
    await Future<void>.delayed(
      Duration(milliseconds: _random.nextInt(_maxLatencyMs - _minLatencyMs) + _minLatencyMs),
    );
    return handler(request);
  }

  /// 当前是否启用 Mock（由全局模式状态决定）。
  bool isEnabled(Ref ref) => ref.read(mockModeProvider) == PortenMockMode.mock;
}

/// 全局单例 Provider（引擎无状态副作用，安全共享）。
final Provider<MockEngine> mockEngineProvider =
    Provider<MockEngine>((Ref ref) => MockEngine());
