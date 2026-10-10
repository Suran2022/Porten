/*
 * 原生 ↔ Flutter 桥接契约（Dart 侧）。
 *
 * 架构约束（混合开发核心）：
 *   - Android 原生负责「核心能力」：长连接保活、IM 收发、推送、安全存储；
 *   - Flutter 负责「表现层」：UI、消息渲染；
 *   - 数据流向单向：Flutter 只消费桥接接口，禁止直接访问网络/存储，
 *     保证原生与 Flutter 职责边界与官方 Add-to-App 最佳实践一致。
 *
 * 通道命名规范：porten/<域>/<动作>，与 Kotlin 侧 core/bridge 的常量一一对应。
 */

import 'package:flutter/services.dart';

/// 桥接通道名常量（与 Kotlin 侧 PortenChannels 严格一致）。
abstract final class PortenChannels {
  /// IM 长连接桥：连接状态、消息收发事件由原生推送。
  static const MethodChannel im = MethodChannel('porten/im');

  /// 推送桥：厂商推送透传到 Flutter 层展示。
  static const MethodChannel push = MethodChannel('porten/push');

  /// 安全存储桥：加密 KV（token 等），明文永不落入 Flutter 侧。
  static const MethodChannel secureStore = MethodChannel('porten/secure_store');

  /// 环境与配置桥：Mock 开关、API 地址等由原生注入。
  static const MethodChannel env = MethodChannel('porten/env');
}

/// IM 桥事件类型常量（EventChannel 流中的 type 字段）。
abstract final class PortenImEvents {
  static const String connectionStateChanged = 'connectionStateChanged';
  static const String messageReceived = 'messageReceived';
  static const String messageSent = 'messageSent';
  static const String messageReadReceipt = 'messageReadReceipt';
}

/// 桥接调用异常的统一封装（防御性编程：原生层异常不得直接裸抛到 UI）。
class PortenBridgeException implements Exception {
  PortenBridgeException(this.code, this.message, [this.details]);

  final String code;
  final String message;
  final Object? details;

  @override
  String toString() => 'PortenBridgeException($code): $message';
}

/// 桥接调用安全包装：统一把 PlatformException 转换为 [PortenBridgeException]。
extension PortenBridgeSafeInvoke on MethodChannel {
  /// 带防御包装的 invokeMethod。
  Future<T?> invokeSafe<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      throw PortenBridgeException(e.code, e.message ?? 'unknown', e.details);
    } on MissingPluginException {
      // 原生侧未注册（例如纯 Flutter 调试模式）：按业务约定返回 null，不崩溃。
      return null;
    }
  }
}
