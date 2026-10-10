/*
 * Flutter 侧启动编排器（镜像 Kotlin 侧 AppBootstrap 的任务模型）。
 *
 * 设计约束（防御性编程）：
 *   1. 任务按 [StartupTask.priority] 升序执行，先注册的能力先可用；
 *   2. 单个任务失败不阻断启动：记录错误并继续（敏感身份用户不应看到白屏/闪退）；
 *   3. 所有任务实现必须幂等，允许引擎重建时重复执行。
 */

import 'package:flutter/foundation.dart';

/// 启动任务契约。
abstract interface class StartupTask {
  /// 任务名称（用于日志与问题定位）。
  String get name;

  /// 执行优先级，数值越小越先执行。
  int get priority;

  /// 执行任务；实现必须自行捕获可恢复异常，不可恢复异常将被编排器兜底。
  Future<void> execute();
}

/// 启动任务执行结果（供调试与埋点）。
@immutable
class StartupTaskResult {
  const StartupTaskResult({
    required this.name,
    required this.succeeded,
    this.error,
    required this.elapsedMs,
  });

  final String name;
  final bool succeeded;
  final Object? error;
  final int elapsedMs;

  @override
  String toString() =>
      'StartupTaskResult($name, ok=$succeeded, ${elapsedMs}ms, error=$error)';
}

/// 启动编排器。
final class AppBootstrap {
  AppBootstrap({required List<StartupTask> tasks})
      : _tasks = List<StartupTask>.from(tasks)..sort(
          (a, b) => a.priority.compareTo(b.priority),
        );

  final List<StartupTask> _tasks;

  /// 已执行的任务结果（测试与诊断用）。
  final List<StartupTaskResult> results = <StartupTaskResult>[];

  /// 依序执行全部任务；任何异常均被兜底记录，绝不向调用方抛出。
  Future<void> run() async {
    for (final StartupTask task in _tasks) {
      final Stopwatch watch = Stopwatch()..start();
      bool ok = true;
      Object? error;
      try {
        await task.execute();
      } catch (err, stack) {
        // 防御性兜底：启动期任务失败不阻断应用，记录后继续。
        ok = false;
        error = err;
        debugPrint('PortenBootstrap[${task.name}] failed: $err\n$stack');
      }
      watch.stop();
      results.add(
        StartupTaskResult(
          name: task.name,
          succeeded: ok,
          error: error,
          elapsedMs: watch.elapsedMilliseconds,
        ),
      );
    }
  }
}
