/*
 * 我的旅程模型与 Mock 引擎（对齐 Kotlin 侧 TripModels.kt + TripMockEngine，
 * 以及 Web 端 TripPage.tsx 的 _kTripItems）。
 *
 * 字段硬约束（与后端 /api/v1/trips 系列、Kotlin 侧 TripItem 逐字段对齐，
 * 一个不多一个不少，11 字段）：title/departure_city/departure_airport/
 * departure_time/arrival_city/arrival_airport/arrival_time/transfer_type/
 * airline/airline_icon/tips。
 * departure_time/arrival_time 为服务端按展示时区派生的 HH:mm 字符串；
 * title 与 tips 由服务端派生（端上只展示），Mock 通道按同一规则在端上派生。
 */

import 'trip_mock.dart' show Airline, kAirlines;

/// 航司名 → 品牌图标资产路径（与 Kotlin 侧 AIRLINE_ICONS、Web/Flutter
/// 图标资源一一对应；未知航司回退空串由 UI 兜底）。
String tripAirlineIconOf(String airline) {
  for (final Airline item in kAirlines) {
    if (item.name == airline) return item.iconAsset;
  }
  return '';
}

/// 旅程卡片（对齐 TripItem，11 字段）。
class TripItem {
  const TripItem({
    required this.title,
    required this.departureCity,
    required this.departureAirport,
    required this.departureTime,
    required this.arrivalCity,
    required this.arrivalAirport,
    required this.arrivalTime,
    required this.transferType,
    required this.airline,
    required this.airlineIcon,
    this.tips,
  });

  /// 卡片标题，如「2天后将前往大连」（服务端派生）。
  final String title;

  /// 出发城市。
  final String departureCity;

  /// 出发机场。
  final String departureAirport;

  /// 出发时刻，HH:mm（服务端派生）。
  final String departureTime;

  /// 到达城市。
  final String arrivalCity;

  /// 到达机场。
  final String arrivalAirport;

  /// 到达时刻，HH:mm；选填。
  final String? arrivalTime;

  /// 航段类型：直达 / 中转。
  final String transferType;

  /// 航司名称。
  final String airline;

  /// 航司品牌图标资产路径（服务端按航司映射派生）。
  final String airlineIcon;

  /// 卡片下方提醒（出发倒计时 + 天气，服务端派生）；选填。
  final String? tips;
}

/// 创建旅程提交载荷（表单字段：出发/到达城市机场、出发时间、航司；
/// 与 Kotlin TripCreatePayload 一致）。
class TripCreatePayload {
  const TripCreatePayload({
    required this.departureCity,
    required this.departureAirport,
    required this.departureAt,
    required this.arrivalCity,
    required this.arrivalAirport,
    this.arrivalAt,
    this.transferType = '直达',
    required this.airline,
  });

  final String departureCity;
  final String departureAirport;

  /// 出发日期时间，ISO-8601（UTC，含 Z）。
  final String departureAt;
  final String arrivalCity;
  final String arrivalAirport;

  /// 到达日期时间，ISO-8601（UTC，含 Z）；选填。
  final String? arrivalAt;
  final String transferType;
  final String airline;
}

/// 「我的旅程」入口卡片（对齐 TripAssistantCard）。
///
/// [lastMessage] 为最新旅程摘要（端上拼接「[行程助手]：」前缀，同 mock）。
class TripAssistantCard {
  const TripAssistantCard({required this.count, this.lastMessage});

  final int count;
  final String? lastMessage;
}

// ------------------------------------------------------------ API 序列化

/// 业务数据桥返回 JSON → [TripItem]。
TripItem tripItemFromApi(Map<String, dynamic> json) {
  return TripItem(
    title: json['title'] as String,
    departureCity: json['departure_city'] as String,
    departureAirport: json['departure_airport'] as String,
    departureTime: json['departure_time'] as String,
    arrivalCity: json['arrival_city'] as String,
    arrivalAirport: json['arrival_airport'] as String,
    arrivalTime: json['arrival_time'] as String?,
    transferType: json['transfer_type'] as String,
    airline: json['airline'] as String,
    airlineIcon: json['airline_icon'] as String,
    tips: json['tips'] as String?,
  );
}

/// 创建旅程的桥载荷（snake_case；到达时刻未收集时传 null）。
Map<String, Object?> tripCreatePayloadOf(TripCreatePayload payload) {
  return <String, Object?>{
    'departure_city': payload.departureCity,
    'departure_airport': payload.departureAirport,
    'departure_at': payload.departureAt,
    'arrival_city': payload.arrivalCity,
    'arrival_airport': payload.arrivalAirport,
    'arrival_at': payload.arrivalAt,
    'transfer_type': payload.transferType,
    'airline': payload.airline,
  };
}

// ------------------------------------------------------------ Mock 引擎

/// 旅程 Mock 引擎（内存态，合成数据；行为与 Kotlin TripMockEngine 逐条对齐）。
class TripStore {
  TripStore._();

  static final List<TripItem> _items = <TripItem>[];

  /// 当前全部旅程（返回副本，按创建顺序；首次访问注入种子）。
  static List<TripItem> get items {
    _seedIfEmpty();
    return List<TripItem>.of(_items);
  }

  /// 创建旅程：标题与提醒按与后端相同的规则在端上派生
  /// （天气未配置时只有倒计时，同后端降级策略）。
  static TripItem create(TripCreatePayload payload) {
    _seedIfEmpty();
    final DateTime departureAt = DateTime.parse(payload.departureAt).toLocal();
    final DateTime? arrivalAt =
        payload.arrivalAt != null ? DateTime.parse(payload.arrivalAt!).toLocal() : null;
    final TripItem item = TripItem(
      title: buildTripTitle(departureAt, payload.arrivalCity),
      departureCity: payload.departureCity,
      departureAirport: payload.departureAirport,
      departureTime: formatTripHHmm(departureAt),
      arrivalCity: payload.arrivalCity,
      arrivalAirport: payload.arrivalAirport,
      arrivalTime: arrivalAt != null ? formatTripHHmm(arrivalAt) : null,
      transferType: payload.transferType,
      airline: payload.airline,
      airlineIcon: tripAirlineIconOf(payload.airline),
      tips: buildTripTips(departureAt, payload.arrivalCity),
    );
    _items.add(item);
    return item;
  }

  /// 「我的旅程」入口卡片（mock：种子旅程全部计为即将出发，
  /// count 为当前旅程条数，摘要取列表第一条）。
  static TripAssistantCard assistantCard() {
    _seedIfEmpty();
    final TripItem? first = _items.isEmpty ? null : _items.first;
    return TripAssistantCard(
      count: _items.length,
      lastMessage: first == null
          ? null
          : '您有一条在${titlePrefixOf(first.title)}前往${first.arrivalCity}的旅程',
    );
  }

  /// 标题前缀：取「将前往」之前的部分（「2天后将前往大连」→「2天后」）。
  static String titlePrefixOf(String title) {
    final int index = title.indexOf('将前往');
    return index >= 0 ? title.substring(0, index) : title;
  }

  /// 卡片标题：今天 / 明天 / N天后将前往X（与 Kotlin buildTitle 对齐）。
  static String buildTripTitle(DateTime departureAt, String arrivalCity) {
    final int days = _daysBetweenToday(departureAt);
    final String prefix = switch (days) {
      <= 0 => '今天',
      1 => '明天',
      _ => '$days天后',
    };
    return '$prefix将前往$arrivalCity';
  }

  /// 提醒文案：出发倒计时（mock 无天气数据源，与后端 NullWeatherProvider
  /// 降级一致；已出发返回 null）。
  static String? buildTripTips(DateTime departureAt, String arrivalCity) {
    final DateTime now = DateTime.now();
    if (!departureAt.isAfter(now)) return null;
    final int days = _daysBetweenToday(departureAt);
    if (days >= 1) return '还有$days天飞往$arrivalCity';
    final int hours = departureAt.difference(now).inHours;
    return '还有${hours < 1 ? 1 : hours}小时飞往$arrivalCity';
  }

  /// 出发时刻的 HH:mm。
  static String formatTripHHmm(DateTime time) {
    final String hh = time.hour.toString().padLeft(2, '0');
    final String mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  /// 按日历日计算与今天的差（负数为过去；同 Kotlin ChronoUnit.DAYS）。
  static int _daysBetweenToday(DateTime time) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime day = DateTime(time.year, time.month, time.day);
    return day.difference(today).inDays;
  }

  /// 种子旅程（与 trip_page 原 _kTripItems 逐条一致；标题为静态字符串，
  /// 与 Kotlin 种子保持一致——种子无真实出发时刻，不动态派生）。
  static void _seedIfEmpty() {
    if (_items.isNotEmpty) return;
    _items.add(const TripItem(
      title: '2天后将前往大连',
      departureCity: '广州',
      departureAirport: '白云机场',
      departureTime: '08:35',
      arrivalCity: '大连',
      arrivalAirport: '周水子机场',
      arrivalTime: '12:05',
      transferType: '直达',
      airline: '四川航空',
      airlineIcon: 'assets/icons/airline-sichuan.svg',
      tips: '两天后可进行线上选座，当天有雨，注意带伞哦！',
    ));
    _items.add(const TripItem(
      title: '7天后将前往东京',
      departureCity: '大连',
      departureAirport: '周水子机场',
      departureTime: '09:30',
      arrivalCity: '东京',
      arrivalAirport: '羽田机场',
      arrivalTime: '13:00',
      transferType: '直达',
      airline: '东方航空',
      airlineIcon: 'assets/icons/airline-eastern.svg',
      tips: '请注意日本签证，注意出行安全！',
    ));
    _items.add(const TripItem(
      title: '12天后将前往旧金山',
      departureCity: '东京',
      departureAirport: '羽田机场',
      departureTime: '17:10',
      arrivalCity: '旧金山',
      arrivalAirport: '旧金山国际机场',
      arrivalTime: '10:30',
      transferType: '中转',
      airline: '中国航空',
      airlineIcon: 'assets/icons/airline-china.svg',
      tips: '请注意美国签证，注意出行安全！',
    ));
  }
}
