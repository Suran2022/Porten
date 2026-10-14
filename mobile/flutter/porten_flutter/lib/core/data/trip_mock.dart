/*
 * 城市与机场数据（100% 对齐 Web 端 data/cities.ts，52 城 mock 静态数据）。
 *
 * 结构：城市中文名 / 英文名 / 拼音首字母 / 机场列表；两个及以上机场的
 * 城市在选择流程中进入第二步「选择机场」（同 Web）。
 */

/// 城市机场。
class CityAirport {
  const CityAirport(this.name);

  final String name;
}

/// 城市。
class City {
  const City({
    required this.name,
    required this.en,
    required this.letter,
    required this.airports,
  });

  /// 城市中文名。
  final String name;

  /// 城市英文名（列表右侧显示）。
  final String en;

  /// 拼音首字母（分组与索引用）。
  final String letter;

  /// 城市对应机场。
  final List<CityAirport> airports;
}

/// 城市列表（顺序同 Web CITIES）。
const List<City> kCities = <City>[
  City(name: '阿姆斯特丹', en: 'Amsterdam', letter: 'A', airports: <CityAirport>[CityAirport('史基浦机场')]),
  City(name: '北京', en: 'Beijing', letter: 'B', airports: <CityAirport>[CityAirport('首都国际机场'), CityAirport('大兴国际机场')]),
  City(name: '包头', en: 'Baotou', letter: 'B', airports: <CityAirport>[CityAirport('东河机场')]),
  City(name: '博鳌', en: 'Boao', letter: 'B', airports: <CityAirport>[CityAirport('博鳌机场')]),
  City(name: '成都', en: 'Chengdu', letter: 'C', airports: <CityAirport>[CityAirport('双流国际机场'), CityAirport('天府国际机场')]),
  City(name: '重庆', en: 'Chongqing', letter: 'C', airports: <CityAirport>[CityAirport('江北国际机场')]),
  City(name: '长沙', en: 'Changsha', letter: 'C', airports: <CityAirport>[CityAirport('黄花国际机场')]),
  City(name: '长春', en: 'Changchun', letter: 'C', airports: <CityAirport>[CityAirport('龙嘉国际机场')]),
  City(name: '大连', en: 'Dalian', letter: 'D', airports: <CityAirport>[CityAirport('周水子机场')]),
  City(name: '大庆', en: 'Daqing', letter: 'D', airports: <CityAirport>[CityAirport('萨尔图机场')]),
  City(name: '鄂尔多斯', en: 'Ordos', letter: 'E', airports: <CityAirport>[CityAirport('伊金霍洛机场')]),
  City(name: '福州', en: 'Fuzhou', letter: 'F', airports: <CityAirport>[CityAirport('长乐国际机场')]),
  City(name: '佛山', en: 'Foshan', letter: 'F', airports: <CityAirport>[CityAirport('沙堤机场')]),
  City(name: '广州', en: 'Guangzhou', letter: 'G', airports: <CityAirport>[CityAirport('白云机场')]),
  City(name: '贵阳', en: 'Guiyang', letter: 'G', airports: <CityAirport>[CityAirport('龙洞堡机场')]),
  City(name: '桂林', en: 'Guilin', letter: 'G', airports: <CityAirport>[CityAirport('两江国际机场')]),
  City(name: '杭州', en: 'Hangzhou', letter: 'H', airports: <CityAirport>[CityAirport('萧山国际机场')]),
  City(name: '哈尔滨', en: 'Harbin', letter: 'H', airports: <CityAirport>[CityAirport('太平国际机场')]),
  City(name: '海口', en: 'Haikou', letter: 'H', airports: <CityAirport>[CityAirport('美兰国际机场')]),
  City(name: '呼和浩特', en: 'Hohhot', letter: 'H', airports: <CityAirport>[CityAirport('白塔国际机场')]),
  City(name: '济南', en: 'Jinan', letter: 'J', airports: <CityAirport>[CityAirport('遥墙国际机场')]),
  City(name: '揭阳', en: 'Jieyang', letter: 'J', airports: <CityAirport>[CityAirport('潮汕机场')]),
  City(name: '昆明', en: 'Kunming', letter: 'K', airports: <CityAirport>[CityAirport('长水国际机场')]),
  City(name: '兰州', en: 'Lanzhou', letter: 'L', airports: <CityAirport>[CityAirport('中川机场')]),
  City(name: '拉萨', en: 'Lhasa', letter: 'L', airports: <CityAirport>[CityAirport('贡嘎机场')]),
  City(name: '丽江', en: 'Lijiang', letter: 'L', airports: <CityAirport>[CityAirport('三义机场')]),
  City(name: '伦敦', en: 'London', letter: 'L', airports: <CityAirport>[CityAirport('希思罗机场'), CityAirport('盖特威克机场')]),
  City(name: '南京', en: 'Nanjing', letter: 'N', airports: <CityAirport>[CityAirport('禄口国际机场')]),
  City(name: '宁波', en: 'Ningbo', letter: 'N', airports: <CityAirport>[CityAirport('栎社国际机场')]),
  City(name: '南昌', en: 'Nanchang', letter: 'N', airports: <CityAirport>[CityAirport('昌北机场')]),
  City(name: '纽约', en: 'New York', letter: 'N', airports: <CityAirport>[CityAirport('肯尼迪机场'), CityAirport('拉瓜迪亚机场')]),
  City(name: '青岛', en: 'Qingdao', letter: 'Q', airports: <CityAirport>[CityAirport('胶东国际机场')]),
  City(name: '泉州', en: 'Quanzhou', letter: 'Q', airports: <CityAirport>[CityAirport('晋江机场')]),
  City(name: '上海', en: 'Shanghai', letter: 'S', airports: <CityAirport>[CityAirport('虹桥国际机场'), CityAirport('浦东国际机场')]),
  City(name: '深圳', en: 'Shenzhen', letter: 'S', airports: <CityAirport>[CityAirport('宝安国际机场')]),
  City(name: '三亚', en: 'Sanya', letter: 'S', airports: <CityAirport>[CityAirport('凤凰机场')]),
  City(name: '沈阳', en: 'Shenyang', letter: 'S', airports: <CityAirport>[CityAirport('桃仙机场')]),
  City(name: '旧金山', en: 'San Francisco', letter: 'S', airports: <CityAirport>[CityAirport('旧金山国际机场')]),
  City(name: '首尔', en: 'Seoul', letter: 'S', airports: <CityAirport>[CityAirport('仁川机场')]),
  City(name: '东京', en: 'Tokyo', letter: 'T', airports: <CityAirport>[CityAirport('羽田机场'), CityAirport('成田国际机场')]),
  City(name: '天津', en: 'Tianjin', letter: 'T', airports: <CityAirport>[CityAirport('滨海国际机场')]),
  City(name: '太原', en: 'Taiyuan', letter: 'T', airports: <CityAirport>[CityAirport('武宿机场')]),
  City(name: '乌鲁木齐', en: 'Urumqi', letter: 'W', airports: <CityAirport>[CityAirport('地窝堡机场')]),
  City(name: '武汉', en: 'Wuhan', letter: 'W', airports: <CityAirport>[CityAirport('天河机场')]),
  City(name: '无锡', en: 'Wuxi', letter: 'W', airports: <CityAirport>[CityAirport('硕放机场')]),
  City(name: '厦门', en: 'Xiamen', letter: 'X', airports: <CityAirport>[CityAirport('高崎机场')]),
  City(name: '西安', en: 'Xi\'an', letter: 'X', airports: <CityAirport>[CityAirport('咸阳机场')]),
  City(name: '西宁', en: 'Xining', letter: 'X', airports: <CityAirport>[CityAirport('曹家堡机场')]),
  City(name: '银川', en: 'Yinchuan', letter: 'Y', airports: <CityAirport>[CityAirport('河东机场')]),
  City(name: '烟台', en: 'Yantai', letter: 'Y', airports: <CityAirport>[CityAirport('蓬莱机场')]),
  City(name: '郑州', en: 'Zhengzhou', letter: 'Z', airports: <CityAirport>[CityAirport('新郑机场')]),
  City(name: '珠海', en: 'Zhuhai', letter: 'Z', airports: <CityAirport>[CityAirport('金湾机场')]),
];

/// 按字母分组的城市（同 Web CITY_GROUPS：保持原顺序分组后按字母排序）。
class CityGroup {
  const CityGroup(this.letter, this.cities);

  final String letter;
  final List<City> cities;
}

final List<CityGroup> kCityGroups = _buildCityGroups();

List<CityGroup> _buildCityGroups() {
  final Map<String, List<City>> map = <String, List<City>>{};
  for (final City city in kCities) {
    map.putIfAbsent(city.letter, () => <City>[]).add(city);
  }
  final List<CityGroup> groups = map.entries
      .map((MapEntry<String, List<City>> e) => CityGroup(e.key, e.value))
      .toList();
  groups.sort((CityGroup a, CityGroup b) => a.letter.compareTo(b.letter));
  return groups;
}

/// 承运航司。
class Airline {
  const Airline({required this.name, required this.iconAsset});

  final String name;

  /// 航司图标资产（Web 端同款 SVG，已拷入 assets/icons）。
  final String iconAsset;
}

/// 航司列表（顺序同 Web AIRLINES）。
const List<Airline> kAirlines = <Airline>[
  Airline(name: '四川航空', iconAsset: 'assets/icons/airline-sichuan.svg'),
  Airline(name: '东方航空', iconAsset: 'assets/icons/airline-eastern.svg'),
  Airline(name: '中国航空', iconAsset: 'assets/icons/airline-china.svg'),
  Airline(name: '瑞丽航空', iconAsset: 'assets/icons/airline-ruili.svg'),
  Airline(name: '南方航空', iconAsset: 'assets/icons/airline-southern.svg'),
  Airline(name: '法国航空', iconAsset: 'assets/icons/airline-france.svg'),
  Airline(name: '厦门航空', iconAsset: 'assets/icons/airline-xiamen.svg'),
  Airline(name: '春秋航空', iconAsset: 'assets/icons/airline-spring.svg'),
  Airline(name: '吉祥航空', iconAsset: 'assets/icons/airline-juneyao.svg'),
  Airline(name: '大韩航空', iconAsset: 'assets/icons/airline-korean.svg'),
  Airline(name: '山东航空', iconAsset: 'assets/icons/airline-shandong.svg'),
];
