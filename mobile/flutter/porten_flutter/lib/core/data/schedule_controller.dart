/*
 * 我的日程控制器（Mock / Live 一键切换的分发点，对齐 Kotlin 侧
 * ScheduleRepository 的双通道语义）。
 *
 * 职责：
 *   1. 拉取日程看板（列表 + 关联候选），按 mockModeProvider 分流：
 *      mock → 端内 ScheduleStore + Dart mock 候选；live → porten/data 桥；
 *   2. 创建 / 更新 / 局部 PATCH（拖拽手柄只改结束时间）；
 *   3. Live 通道异常不静默回退 Mock（演示数据混入生产是安全事故），
 *      异常经 AsyncValue.error 向上抛由 UI 呈现。
 */

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bridge/porten_data_bridge.dart';
import '../mock/mock_mode.dart';
import 'schedule_mock.dart';

/// 日程看板数据：列表 + 关联候选（日程页一次性所需）。
class ScheduleBoardData {
  const ScheduleBoardData({required this.items, required this.related});

  /// 日程列表（按日期 + 开始时间升序，同后端排序）。
  final List<ScheduleItem> items;

  /// 关联候选（旅程 / 约定 / 同胞）。
  final ScheduleRelatedData related;

  static const ScheduleBoardData empty = ScheduleBoardData(
    items: <ScheduleItem>[],
    related: ScheduleRelatedData(),
  );

  /// 从桥返回 JSON 构造（live 通道）。
  static ScheduleBoardData fromApi(Map<String, Object?> board) {
    final List<ScheduleItem> items = ((board['items'] as List<Object?>?) ?? const <Object?>[])
        .map((Object? e) => scheduleItemFromApi(e as Map<String, Object?>))
        .toList()
      ..sort((ScheduleItem a, ScheduleItem b) {
        final int byDate = a.date.compareTo(b.date);
        return byDate != 0 ? byDate : a.startTime.compareTo(b.startTime);
      });
    final Object? related = board['related'];
    return ScheduleBoardData(
      items: items,
      related: related is Map<String, Object?>
          ? scheduleRelatedDataFromApi(related)
          : const ScheduleRelatedData(),
    );
  }
}

/// 日程控制器（AsyncNotifier：首次 listen 时拉取，页面销毁即释放）。
class ScheduleController extends AsyncNotifier<ScheduleBoardData> {
  @override
  Future<ScheduleBoardData> build() => _fetch();

  bool get _isMock => ref.read(mockModeProvider) == PortenMockMode.mock;

  Future<ScheduleBoardData> _fetch() async {
    if (_isMock) {
      return ScheduleBoardData(
        items: _sorted(ScheduleStore.items),
        related: const ScheduleRelatedData(
          trips: kMockTrips,
          agreements: kMockAgreements,
          comrades: kMockComrades,
        ),
      );
    }
    return ScheduleBoardData.fromApi(await PortenDataBridge.listSchedules());
  }

  /// 重新拉取（下拉刷新 / 写操作后同步）。
  Future<void> refresh() async {
    state = const AsyncValue<ScheduleBoardData>.loading();
    state = await AsyncValue.guard<ScheduleBoardData>(_fetch);
  }

  /// 创建日程（mock：Store 随机配色；live：服务端分配）。
  Future<ScheduleItem> create(ScheduleItem draft) async {
    final ScheduleItem created = _isMock
        ? ScheduleStore.create(draft)
        : scheduleItemFromApi(await PortenDataBridge.createSchedule(draft));
    await refresh();
    return created;
  }

  /// 更新日程（编辑表单全量覆盖，PATCH 语义）。
  /// 命名避开 Riverpod AsyncNotifier 内置 update(T Function(T))。
  Future<ScheduleItem> updateItem(int id, ScheduleItem draft) async {
    final ScheduleItem updated = _isMock
        ? ScheduleStore.update(id, draft)
        : scheduleItemFromApi(await PortenDataBridge.updateSchedule(id, draft));
    await refresh();
    return updated;
  }

  /// 局部更新：拖拽手柄只改结束时间（乐观更新由调用方先行，
  /// 这里负责持久化 + 同步列表；失败不回滚演示数据，同 Web 行为）。
  Future<void> updateEndTime(int id, String endTime) async {
    if (_isMock) {
      ScheduleStore.updateEndTime(id, endTime);
    } else {
      await PortenDataBridge.patchSchedule(id, <String, Object?>{'end_time': endTime});
    }
    await refresh();
  }

  /// 按日期 + 开始时间升序（同 Kotlin ScheduleMockEngine.list 排序）。
  static List<ScheduleItem> _sorted(List<ScheduleItem> items) {
    final List<ScheduleItem> sorted = List<ScheduleItem>.of(items)
      ..sort((ScheduleItem a, ScheduleItem b) {
        final int byDate = a.date.compareTo(b.date);
        return byDate != 0 ? byDate : a.startTime.compareTo(b.startTime);
      });
    return sorted;
  }
}

/// 全局日程 Provider。
final AsyncNotifierProvider<ScheduleController, ScheduleBoardData>
    scheduleControllerProvider =
    AsyncNotifierProvider<ScheduleController, ScheduleBoardData>(
  ScheduleController.new,
);
