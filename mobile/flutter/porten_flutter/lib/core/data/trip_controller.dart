/*
 * 我的旅程控制器（Mock / Live 一键切换的分发点，对齐 Kotlin 侧
 * TripRepository 的双通道语义）。
 *
 * 职责：
 *   1. 拉取旅程看板（卡片列表 + 「我的旅程」入口卡片摘要），按
 *      mockModeProvider 分流：mock → 端内 TripStore；live → porten/data 桥；
 *   2. 创建旅程（标题 / 提醒 / 航司图标在 Live 通道由服务端派生，
 *      mock 通道按同一规则在端上派生）；
 *   3. 创建后同步：入口卡片（消息列表）与行程页共享同一 Provider，
 *      创建旅程即双向同步（用户可见的「创建后同步到我的旅程卡片」）。
 */

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bridge/porten_data_bridge.dart';
import '../mock/mock_mode.dart';
import 'trip_store.dart';

/// 旅程看板数据：卡片列表 + 入口卡片摘要。
class TripBoardData {
  const TripBoardData({required this.items, required this.assistant});

  /// 旅程卡片列表（按创建顺序）。
  final List<TripItem> items;

  /// 「我的旅程」入口卡片（count + last_message）。
  final TripAssistantCard assistant;

  static const TripBoardData empty = TripBoardData(
    items: <TripItem>[],
    assistant: TripAssistantCard(count: 0),
  );

  /// 从桥返回 JSON 构造（live 通道）。
  static TripBoardData fromApi(Map<String, Object?> board) {
    final List<TripItem> items = ((board['items'] as List<Object?>?) ?? const <Object?>[])
        .map((Object? e) => tripItemFromApi(e as Map<String, Object?>))
        .toList();
    final Object? assistant = board['assistant'];
    return TripBoardData(
      items: items,
      assistant: assistant is Map<String, Object?>
          ? TripAssistantCard(
              count: (assistant['count'] as num?)?.toInt() ?? 0,
              lastMessage: assistant['last_message'] as String?,
            )
          : const TripAssistantCard(count: 0),
    );
  }
}

/// 旅程控制器（AsyncNotifier：首次 listen 时拉取，页面销毁即释放）。
class TripController extends AsyncNotifier<TripBoardData> {
  @override
  Future<TripBoardData> build() => _fetch();

  bool get _isMock => ref.read(mockModeProvider) == PortenMockMode.mock;

  Future<TripBoardData> _fetch() async {
    if (_isMock) {
      return TripBoardData(
        items: TripStore.items,
        assistant: TripStore.assistantCard(),
      );
    }
    return TripBoardData.fromApi(await PortenDataBridge.listTrips());
  }

  /// 重新拉取（下拉刷新 / 写操作后同步）。
  Future<void> refresh() async {
    state = const AsyncValue<TripBoardData>.loading();
    state = await AsyncValue.guard<TripBoardData>(_fetch);
  }

  /// 创建旅程（标题 / 提醒 / 图标在 Live 通道由服务端派生）。
  Future<TripItem> create(TripCreatePayload payload) async {
    final TripItem created = _isMock
        ? TripStore.create(payload)
        : tripItemFromApi(await PortenDataBridge.createTrip(payload));
    await refresh();
    return created;
  }
}

/// 全局旅程 Provider（行程页与消息列表入口卡片共享，创建即同步）。
final AsyncNotifierProvider<TripController, TripBoardData>
    tripControllerProvider =
    AsyncNotifierProvider<TripController, TripBoardData>(TripController.new);
