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

  /// 业务数据桥：日程 / 旅程 / 笔记的读取与提交（Flutter 禁止直连网络，
  /// 业务数据一律经本通道下沉到原生 Repository，Mock / Live 由原生决策）。
  static const MethodChannel data = MethodChannel('porten/data');

  /// 导航桥：Add-to-App 缓存引擎模式无 FlutterActivity 背书，
  /// 系统返回键由原生转发——原生先调 canPop 判断 Flutter 导航栈，
  /// 可弹则发系统 popRoute（Dart 内 pop 一级），不可弹则原生收尾 Activity。
  static const MethodChannel navigation = MethodChannel('porten/navigation');
}

/// 业务数据桥方法名（与 Kotlin 侧 PortenDataMethods 严格一致）。
///
/// 命名规范：动词 + 领域名词；请求参数与返回值均为 JSON Map
/// （参数键见 [PortenDataArgs]，字段由各端 Model 的序列化约定承载）。
abstract final class PortenDataMethods {
  // ---- 认证 ----
  static const String authSendCode = 'authSendCode';
  static const String authRegister = 'authRegister';
  static const String authLoginPassword = 'authLoginPassword';
  static const String authLoginEmailCode = 'authLoginEmailCode';
  static const String authLogout = 'authLogout';

  // ---- 我的日程 ----
  static const String listSchedules = 'listSchedules';
  static const String createSchedule = 'createSchedule';
  static const String updateSchedule = 'updateSchedule';

  // ---- 我的旅程 ----
  static const String listTrips = 'listTrips';
  static const String createTrip = 'createTrip';

  // ---- 记笔记 ----
  static const String listNotes = 'listNotes';
  static const String createNote = 'createNote';
  static const String updateNote = 'updateNote';
  static const String deleteNote = 'deleteNote';
}

/// 业务数据桥参数键（与 Kotlin 侧 PortenDataArgs 严格一致）。
abstract final class PortenDataArgs {
  /// 日程 / 笔记更新时的条目 id。
  static const String id = 'id';

  /// 创建 / 更新载荷（JSON Map，字段与各端 Model 一致）。
  static const String payload = 'payload';
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
