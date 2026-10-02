/** 城市与机场数据（mock 阶段静态数据，后续接入接口后替换）。 */
export interface CityAirport {
  name: string;
}

export interface City {
  /** 城市中文名 */
  name: string;
  /** 城市英文名（列表右侧显示） */
  en: string;
  /** 拼音首字母（分组与索引用） */
  letter: string;
  /** 城市对应机场（两个及以上时选择流程进入第二步选择机场） */
  airports: CityAirport[];
}

export const CITIES: City[] = [
  { name: "阿姆斯特丹", en: "Amsterdam", letter: "A", airports: [{ name: "史基浦机场" }] },
  { name: "北京", en: "Beijing", letter: "B", airports: [{ name: "首都国际机场" }, { name: "大兴国际机场" }] },
  { name: "包头", en: "Baotou", letter: "B", airports: [{ name: "东河机场" }] },
  { name: "博鳌", en: "Boao", letter: "B", airports: [{ name: "博鳌机场" }] },
  { name: "成都", en: "Chengdu", letter: "C", airports: [{ name: "双流国际机场" }, { name: "天府国际机场" }] },
  { name: "重庆", en: "Chongqing", letter: "C", airports: [{ name: "江北国际机场" }] },
  { name: "长沙", en: "Changsha", letter: "C", airports: [{ name: "黄花国际机场" }] },
  { name: "长春", en: "Changchun", letter: "C", airports: [{ name: "龙嘉国际机场" }] },
  { name: "大连", en: "Dalian", letter: "D", airports: [{ name: "周水子机场" }] },
  { name: "大庆", en: "Daqing", letter: "D", airports: [{ name: "萨尔图机场" }] },
  { name: "鄂尔多斯", en: "Ordos", letter: "E", airports: [{ name: "伊金霍洛机场" }] },
  { name: "福州", en: "Fuzhou", letter: "F", airports: [{ name: "长乐国际机场" }] },
  { name: "佛山", en: "Foshan", letter: "F", airports: [{ name: "沙堤机场" }] },
  { name: "广州", en: "Guangzhou", letter: "G", airports: [{ name: "白云机场" }] },
  { name: "贵阳", en: "Guiyang", letter: "G", airports: [{ name: "龙洞堡机场" }] },
  { name: "桂林", en: "Guilin", letter: "G", airports: [{ name: "两江国际机场" }] },
  { name: "杭州", en: "Hangzhou", letter: "H", airports: [{ name: "萧山国际机场" }] },
  { name: "哈尔滨", en: "Harbin", letter: "H", airports: [{ name: "太平国际机场" }] },
  { name: "海口", en: "Haikou", letter: "H", airports: [{ name: "美兰国际机场" }] },
  { name: "呼和浩特", en: "Hohhot", letter: "H", airports: [{ name: "白塔国际机场" }] },
  { name: "济南", en: "Jinan", letter: "J", airports: [{ name: "遥墙国际机场" }] },
  { name: "揭阳", en: "Jieyang", letter: "J", airports: [{ name: "潮汕机场" }] },
  { name: "昆明", en: "Kunming", letter: "K", airports: [{ name: "长水国际机场" }] },
  { name: "兰州", en: "Lanzhou", letter: "L", airports: [{ name: "中川机场" }] },
  { name: "拉萨", en: "Lhasa", letter: "L", airports: [{ name: "贡嘎机场" }] },
  { name: "丽江", en: "Lijiang", letter: "L", airports: [{ name: "三义机场" }] },
  { name: "伦敦", en: "London", letter: "L", airports: [{ name: "希思罗机场" }, { name: "盖特威克机场" }] },
  { name: "南京", en: "Nanjing", letter: "N", airports: [{ name: "禄口国际机场" }] },
  { name: "宁波", en: "Ningbo", letter: "N", airports: [{ name: "栎社国际机场" }] },
  { name: "南昌", en: "Nanchang", letter: "N", airports: [{ name: "昌北机场" }] },
  { name: "纽约", en: "New York", letter: "N", airports: [{ name: "肯尼迪机场" }, { name: "拉瓜迪亚机场" }] },
  { name: "青岛", en: "Qingdao", letter: "Q", airports: [{ name: "胶东国际机场" }] },
  { name: "泉州", en: "Quanzhou", letter: "Q", airports: [{ name: "晋江机场" }] },
  { name: "上海", en: "Shanghai", letter: "S", airports: [{ name: "虹桥国际机场" }, { name: "浦东国际机场" }] },
  { name: "深圳", en: "Shenzhen", letter: "S", airports: [{ name: "宝安国际机场" }] },
  { name: "三亚", en: "Sanya", letter: "S", airports: [{ name: "凤凰机场" }] },
  { name: "沈阳", en: "Shenyang", letter: "S", airports: [{ name: "桃仙机场" }] },
  { name: "旧金山", en: "San Francisco", letter: "S", airports: [{ name: "旧金山国际机场" }] },
  { name: "首尔", en: "Seoul", letter: "S", airports: [{ name: "仁川机场" }] },
  { name: "东京", en: "Tokyo", letter: "T", airports: [{ name: "羽田机场" }, { name: "成田国际机场" }] },
  { name: "天津", en: "Tianjin", letter: "T", airports: [{ name: "滨海国际机场" }] },
  { name: "太原", en: "Taiyuan", letter: "T", airports: [{ name: "武宿机场" }] },
  { name: "乌鲁木齐", en: "Urumqi", letter: "W", airports: [{ name: "地窝堡机场" }] },
  { name: "武汉", en: "Wuhan", letter: "W", airports: [{ name: "天河机场" }] },
  { name: "无锡", en: "Wuxi", letter: "W", airports: [{ name: "硕放机场" }] },
  { name: "厦门", en: "Xiamen", letter: "X", airports: [{ name: "高崎机场" }] },
  { name: "西安", en: "Xi'an", letter: "X", airports: [{ name: "咸阳机场" }] },
  { name: "西宁", en: "Xining", letter: "X", airports: [{ name: "曹家堡机场" }] },
  { name: "银川", en: "Yinchuan", letter: "Y", airports: [{ name: "河东机场" }] },
  { name: "烟台", en: "Yantai", letter: "Y", airports: [{ name: "蓬莱机场" }] },
  { name: "郑州", en: "Zhengzhou", letter: "Z", airports: [{ name: "新郑机场" }] },
  { name: "珠海", en: "Zhuhai", letter: "Z", airports: [{ name: "金湾机场" }] },
];

/** 按字母分组并排序后的城市分组（含索引条字母） */
export const CITY_GROUPS: { letter: string; cities: City[] }[] = (() => {
  const map = new Map<string, City[]>();
  for (const city of CITIES) {
    const list = map.get(city.letter) ?? [];
    list.push(city);
    map.set(city.letter, list);
  }
  return [...map.entries()]
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([letter, cities]) => ({ letter, cities }));
})();
