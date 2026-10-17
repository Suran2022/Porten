/*
 * 业务数据桥（porten/data）：Flutter 侧访问业务数据的唯一入口。
 *
 * 架构约束（混合开发核心）：Flutter 禁止直接访问网络，日程 / 旅程 / 笔记
 * 数据一律经本封装下沉到原生 Repository——Mock / Live 双通道由原生
 * DataSourceMode 决策，Flutter 侧只感知「当前模式」并分流：
 *   - mock 模式：读端内 Dart mock（ScheduleStore / TripStore / NoteStore）；
 *   - live 模式：经本桥调用原生 Repository（Retrofit → 后端 API）。
 *
 * 传输约定：MethodChannel 只承载基础类型，本类把返回值统一递归转为
 * Map<String, Object?> / List<Object?> 基础类型树（与 Kotlin 侧
 * DataBridgeAdapter.toPlain() 镜像），上层 Model 的 fromApi 直接消费。
 */

import '../../core/bridge/porten_channels.dart';
import '../../core/data/notes_mock.dart';
import '../../core/data/schedule_mock.dart';
import '../../core/data/trip_store.dart';

/// 业务数据桥方法封装（方法名 / 参数键与 Kotlin 侧 PortenDataMethods、
/// PortenDataArgs 严格一致）。
abstract final class PortenDataBridge {
  // ---- 我的日程 ----

  /// 拉取日程看板：{items: [...], related: {...}}。
  static Future<Map<String, Object?>> listSchedules() =>
      _invokeMap(PortenDataMethods.listSchedules);

  /// 创建日程，返回服务端分配的条目（含 id 与随机配色）。
  static Future<Map<String, Object?>> createSchedule(ScheduleItem draft) =>
      _invokeMap(
        PortenDataMethods.createSchedule,
        <String, Object?>{PortenDataArgs.payload: scheduleCreatePayloadOf(draft)},
      );

  /// 更新日程（PATCH 语义，payload 为全量字段）。
  static Future<Map<String, Object?>> updateSchedule(
    int id,
    ScheduleItem draft,
  ) =>
      _invokeMap(
        PortenDataMethods.updateSchedule,
        <String, Object?>{
          PortenDataArgs.id: id,
          PortenDataArgs.payload: scheduleUpdatePayloadOf(draft),
        },
      );

  /// 更新日程的局部字段（PATCH 语义，如拖拽手柄仅传 end_time）。
  static Future<Map<String, Object?>> patchSchedule(
    int id,
    Map<String, Object?> fields,
  ) =>
      _invokeMap(
        PortenDataMethods.updateSchedule,
        <String, Object?>{
          PortenDataArgs.id: id,
          PortenDataArgs.payload: fields,
        },
      );

  // ---- 我的旅程 ----

  /// 拉取旅程看板：{items: [...], assistant: {...}}。
  static Future<Map<String, Object?>> listTrips() =>
      _invokeMap(PortenDataMethods.listTrips);

  /// 创建旅程，返回服务端派生的条目（标题 / 提醒 / 航司图标）。
  static Future<Map<String, Object?>> createTrip(TripCreatePayload payload) =>
      _invokeMap(
        PortenDataMethods.createTrip,
        <String, Object?>{PortenDataArgs.payload: tripCreatePayloadOf(payload)},
      );

  // ---- 记笔记 ----

  /// 拉取笔记列表：{items: [...]}。
  static Future<Map<String, Object?>> listNotes() =>
      _invokeMap(PortenDataMethods.listNotes);

  /// 创建笔记，返回服务端条目（id / time / 标签归一化由服务端完成）。
  static Future<Map<String, Object?>> createNote({
    required String content,
    required List<String> tags,
  }) =>
      _invokeMap(
        PortenDataMethods.createNote,
        <String, Object?>{
          PortenDataArgs.payload: noteUpsertPayloadOf(content: content, tags: tags),
        },
      );

  /// 更新笔记（PATCH 语义，仅传入字段覆盖）。
  static Future<Map<String, Object?>> updateNote(
    int id, {
    String? content,
    List<String>? tags,
    bool? archived,
  }) =>
      _invokeMap(
        PortenDataMethods.updateNote,
        <String, Object?>{
          PortenDataArgs.id: id,
          PortenDataArgs.payload:
              noteUpsertPayloadOf(content: content, tags: tags, archived: archived),
        },
      );

  /// 删除笔记（返回 true）。
  static Future<bool> deleteNote(int id) async {
    final Map<String, Object?> result = await _invokeMap(
      PortenDataMethods.deleteNote,
      <String, Object?>{PortenDataArgs.id: id},
    );
    return result['deleted'] as bool? ?? false;
  }

  // ---- 认证（登录 / 注册 / 验证码 / 登出）----

  /// 发送验证码（Live 走后端邮件通道；Mock 仅模拟耗时）。
  static Future<void> sendVerificationCode({
    required String email,
    required String purpose,
  }) async {
    await _invokeMap(
      PortenDataMethods.authSendCode,
      <String, Object?>{'email': email, 'purpose': purpose},
    );
  }

  /// 邮箱注册，返回 {token: {...}, user: {...}}。
  static Future<Map<String, Object?>> register({
    required String email,
    required String password,
    required String confirmPassword,
    required String verificationCode,
  }) =>
      _invokeMap(
        PortenDataMethods.authRegister,
        <String, Object?>{
          'email': email,
          'password': password,
          'confirmPassword': confirmPassword,
          'verificationCode': verificationCode,
        },
      );

  /// 邮箱 + 密码登录，返回 {token: {...}, user: {...}}。
  static Future<Map<String, Object?>> loginPassword({
    required String email,
    required String password,
  }) =>
      _invokeMap(
        PortenDataMethods.authLoginPassword,
        <String, Object?>{'email': email, 'password': password},
      );

  /// 邮箱 + 验证码登录，返回 {token: {...}, user: {...}}。
  static Future<Map<String, Object?>> loginEmailCode({
    required String email,
    required String verificationCode,
  }) =>
      _invokeMap(
        PortenDataMethods.authLoginEmailCode,
        <String, Object?>{'email': email, 'verificationCode': verificationCode},
      );

  /// 登出（服务端解绑 + 清除本地 token）。
  static Future<void> logout() async {
    await _invokeMap(PortenDataMethods.authLogout);
  }

  // ---- 底层调用 ----

  /// 调用 data 桥并把返回值统一递归转为基础类型树（`Map<String, Object?>`）。
  static Future<Map<String, Object?>> _invokeMap(
    String method, [
    Map<String, Object?>? args,
  ]) async {
    final Map<Object?, Object?>? raw =
        await PortenChannels.data.invokeSafe<Map<Object?, Object?>>(method, args);
    if (raw == null) {
      throw PortenBridgeException('null_result', '业务数据桥返回空结果：$method');
    }
    return _toPlainMap(raw);
  }

  /// MethodChannel 基础类型树递归规范化（与 Kotlin 侧 toPlain 镜像）：
  /// 嵌套 Map / List 一并转为强类型视图，供 Model fromApi 直接消费。
  static Map<String, Object?> _toPlainMap(Object? raw) {
    if (raw is Map) {
      return raw.map(
        (Object? key, Object? value) => MapEntry(key.toString(), _toPlainValue(value)),
      );
    }
    throw PortenBridgeException('bad_shape', '业务数据桥返回值不是 Map：$methodTag(raw)');
  }

  static Object? _toPlainValue(Object? raw) {
    if (raw is Map) return _toPlainMap(raw);
    if (raw is List) return raw.map(_toPlainValue).toList();
    return raw;
  }

  static String methodTag(Object? raw) => raw == null ? 'null' : raw.runtimeType.toString();
}
