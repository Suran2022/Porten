import { useEffect, useState } from "react";
import { createPortal } from "react-dom";
import { useNavigate } from "react-router-dom";
import { BackIcon } from "@/components/common/BackIcon";
import { cn } from "@/lib/utils";
import { PullToRefresh } from "@/components/common/PullToRefresh";
import tripIcon from "@/assets/trip-icon.svg";
import sichuanAirlineIcon from "@/assets/airline-sichuan.svg";
import easternAirlineIcon from "@/assets/airline-eastern.svg";
import chinaAirlineIcon from "@/assets/airline-china.svg";

/** 顶部淡咖啡色（偏橙），用于高斯模糊背景，并动态同步到状态栏 theme-color。 */
const TRIP_HEADER_COLOR = "#F2DDBC";

/** 示例行程数据（mock 阶段静态展示，后续接入接口后替换）。 */
interface TripItem {
  title: string;
  departureCity: string;
  departureAirport: string;
  departureTime: string;
  arrivalCity: string;
  arrivalAirport: string;
  arrivalTime: string;
  /** 航段类型：直达 / 中转，显示在卡片中间飞机图标上方 */
  transferType: "直达" | "中转";
  /** 航司名称与品牌图标：显示在卡片第一行右对齐 */
  airline: string;
  airlineIcon: string;
  tips?: string;
}

const TRIP_ITEMS: TripItem[] = [
  {
    title: "2天后将前往大连",
    departureCity: "广州",
    departureAirport: "白云机场",
    departureTime: "08:35",
    arrivalCity: "大连",
    arrivalAirport: "周水子机场",
    arrivalTime: "12:05",
    transferType: "直达",
    airline: "四川航空",
    airlineIcon: sichuanAirlineIcon,
    tips: "两天后可进行线上选座，当天有雨，注意带伞哦！",
  },
  {
    title: "7天后将前往东京",
    departureCity: "大连",
    departureAirport: "周水子机场",
    departureTime: "09:30",
    arrivalCity: "东京",
    arrivalAirport: "羽田机场",
    arrivalTime: "13:00",
    transferType: "直达",
    airline: "东方航空",
    airlineIcon: easternAirlineIcon,
    tips: "请注意日本签证，注意出行安全！",
  },
  {
    title: "12天后将前往旧金山",
    departureCity: "东京",
    departureAirport: "羽田机场",
    departureTime: "17:10",
    arrivalCity: "旧金山",
    arrivalAirport: "旧金山国际机场",
    arrivalTime: "10:30",
    transferType: "中转",
    airline: "中国航空",
    airlineIcon: chinaAirlineIcon,
    tips: "请注意美国签证，注意出行安全！",
  },
];

/**
 * 我的行程独立页面（不包含首页底部导航栏）。
 *
 * 顶部为偏橙淡咖啡色高斯模糊背景，占页面 39%，向下自然融入白色背景；
 * 同时将 theme-color 动态同步为顶部色，使支持状态栏着色的浏览器
 * （iOS Safari 15+ / 部分安卓机）状态栏与页面顶部自然融为一体。
 */
export default function TripPage() {
  const navigate = useNavigate();
  // 进入/退出交互：与全站页面（悦音乐、聊天页、通讯录等）统一的右侧滑入/滑出。
  // 进入：挂载后双 rAF 置 translate-x-0 触发滑入；
  // 退出：先滑出（leaving），动画结束后再真正卸载路由。
  const [entered, setEntered] = useState(false);
  const [leaving, setLeaving] = useState(false);

  useEffect(() => {
    const raf = requestAnimationFrame(() => {
      requestAnimationFrame(() => setEntered(true));
    });
    return () => cancelAnimationFrame(raf);
  }, []);

  const handleBack = () => {
    if (!leaving) setLeaving(true);
  };

  const handleTransitionEnd = () => {
    // 仅在滑出结束时卸载路由（滑入结束也会触发 transitionend，需守卫）
    if (leaving) navigate(-1);
  };

  // 下拉刷新（复用全站通用 PullToRefresh 动效）。
  // Mock 阶段模拟重新拉取行程数据；后续接入接口后替换为真实请求。
  const handleRefresh = async () => {
    await new Promise((resolve) => setTimeout(resolve, 800));
  };

  useEffect(() => {
    // 状态栏着色（iOS Safari 15+ 与安卓 Chrome 均需生效）。
    // iOS Safari 对已有 meta 节点执行 setAttribute 在部分版本不会触发
    // 状态栏重绘，社区验证最可靠的方式是：移除旧 meta 节点并重建一个
    // 携带目标色的新节点（兼容 Safari 15~18 与安卓 Chrome 的 theme-color）。
    // Safari 26 起已弃用 theme-color，改由页面内的取色源元素着色，
    // 见下方 STATUS_BAR_TINT 元素，这里不再改动 html/body 背景色。
    const head = document.head;
    const existing = head.querySelector<HTMLMetaElement>(
      'meta[name="theme-color"]'
    );
    const previousContent = existing?.getAttribute("content") ?? null;
    existing?.remove();

    const meta = document.createElement("meta");
    meta.setAttribute("name", "theme-color");
    meta.setAttribute("content", TRIP_HEADER_COLOR);
    head.appendChild(meta);

    return () => {
      meta.remove();
      if (existing) {
        if (previousContent !== null) {
          existing.setAttribute("content", previousContent);
        }
        head.appendChild(existing);
      }
    };
  }, []);

  return (
    <>
      {/* 状态栏色块：iOS 26 Safari 采样 fixed 元素背景色着色状态栏。
          与悦音乐页（MusicView）已验证的实现保持一致：色块必须通过
          createPortal 挂到 body 下、z-[1000] 高于页面根容器，确保
          色块是视觉最顶层元素才会被 Safari 采样（藏在页面内部或被
          其他元素覆盖的色块不会被采样）。
          采样条件（andesco/safari-color-tinting 验证）：
          - 距视口顶部 <5px（top:0 满足）
          - 宽度 >88%（left:0 right:0 = 100% 满足）
          - 高度 >2px（用 max(env,15px) 保证非刘海设备也满足）
          颜色与顶部渐变层顶部一致，视觉上完全不可见。 */}
      {createPortal(
        <div
          className="fixed top-0 left-0 right-0 z-[1000] pointer-events-none"
          style={{
            height: "max(env(safe-area-inset-top, 0px), 15px)",
            backgroundColor: TRIP_HEADER_COLOR,
          }}
        />,
        document.body
      )}

      <div
        className={cn(
          "fixed inset-0 z-[60] flex flex-col overflow-hidden transition-transform duration-300 ease-[cubic-bezier(0.25,0.1,0.25,1)]",
          entered && !leaving ? "translate-x-0" : "translate-x-full"
        )}
        onTransitionEnd={handleTransitionEnd}
      >
      {/* 顶部背景：底层为实色咖啡渐变（占页面 39%），上层 blur-3xl
          高斯模糊柔化过渡，使色带与白色背景自然融合。
          模糊层渐变首个 stop 推迟到 40%：视口顶部（含 blur 采样窗口
          主体）均为纯 TRIP_HEADER_COLOR，使页面顶部实际渲染色与状态栏
          色块的 TRIP_HEADER_COLOR 严格一致（否则模糊混白后页面顶部偏浅，
          状态栏与页面色度不一致）。 */}
      <div className="pointer-events-none absolute inset-x-0 top-0 h-[39%]">
        <div
          className="absolute inset-x-0 top-0 h-full"
          style={{
            background: `linear-gradient(180deg, ${TRIP_HEADER_COLOR} 0%, #F7E9D2 45%, #FFFFFF 80%, #FFFFFF 100%)`,
          }}
        />
        <div
          className="absolute -inset-x-12 -top-20 h-[calc(100%+5rem)] blur-3xl opacity-90"
          style={{
            background: `linear-gradient(180deg, ${TRIP_HEADER_COLOR} 40%, #F7E9D2 55%, rgba(255, 255, 255, 0) 100%)`,
          }}
        />
      </div>

      {/* 顶部栏：返回图标 + 居中（SVG 图标 + 我的行程） */}
      <div className="relative z-10 flex items-center justify-between px-4 pt-[max(0.75rem,env(safe-area-inset-top))] pb-3">
        <button
          type="button"
          onClick={handleBack}
          className="w-10 h-10 flex items-center justify-center -ml-2"
          aria-label="返回"
        >
          <BackIcon className="w-7 h-7" />
        </button>
        <div className="flex items-center gap-1.5">
          <img src={tripIcon} alt="" className="w-5 h-5 object-contain" />
          <h1 className="text-lg font-medium text-gray-900">我的行程</h1>
        </div>
        <div className="w-8 mr-2" />
      </div>

      {/* 主内容区：行程卡片列表（PullToRefresh 自带滚动容器：三张卡片
          超一屏可滑动，顶部下拉触发全站统一的下拉刷新动效） */}
      <div className="relative z-10 flex-1 min-h-0">
        <PullToRefresh onRefresh={handleRefresh}>
          <div className="px-4 pt-3 pb-8 flex flex-col gap-3">
            {TRIP_ITEMS.map((item) => (
              <div key={item.title} className="bg-white rounded-2xl p-4">
                {/* 第一行：绿色胶囊竖条 + 行程标题 + 右对齐航司信息
                    （图标 12px 与 text-xs 汉字字面等大，视觉一致） */}
                <div className="flex items-center gap-2.5">
                  <span className="flex-shrink-0 w-1.5 h-5 rounded-full bg-green-500" />
                  <h2 className="min-w-0 flex-1 text-lg font-semibold text-gray-900 truncate">
                    {item.title}
                  </h2>
                  <div className="flex-shrink-0 flex items-center gap-1">
                    <img src={item.airlineIcon} alt="" className="w-3 h-3 object-contain" />
                    <span className="text-xs leading-none text-gray-500">
                      {item.airline}
                    </span>
                  </div>
                </div>

                {/* 第二行：城市（后紧跟时间）+ 虚线航程 + 城市；机场名显示在城市下方 */}
                <div className="mt-5 flex items-start">
                  <div className="min-w-0">
                    <div className="flex items-baseline gap-2">
                      <span className="text-lg font-semibold text-gray-900">
                        {item.departureCity}
                      </span>
                      <span className="text-sm font-medium text-green-600">
                        {item.departureTime}
                      </span>
                    </div>
                    <p className="mt-1 text-xs text-gray-400">
                      {item.departureAirport}
                    </p>
                  </div>
                  {/* 虚线航程 + 飞机；直达/中转标签显示在飞机图标正上方
                      （中间列整体高 23px，虚线落在城市文本基线位置） */}
                  <div className="flex-1 flex flex-col items-center px-3">
                    <span
                      className={cn(
                        "rounded-full px-2 py-[3px] text-[10px] leading-none font-medium",
                        item.transferType === "直达"
                          ? "bg-green-50 text-green-600"
                          : "bg-amber-50 text-amber-600"
                      )}
                    >
                      {item.transferType}
                    </span>
                    <div className="w-full flex items-center mt-1.5">
                      <span className="flex-1 border-t border-dashed border-gray-300" />
                      <img src={tripIcon} alt="" className="w-4 h-4 mx-1.5 flex-shrink-0" />
                      <span className="flex-1 border-t border-dashed border-gray-300" />
                    </div>
                  </div>
                  {/* 机场名与到达城市文本左对齐（items-start），整块仍由中间虚线推至最右 */}
                  <div className="min-w-0 flex flex-col items-start">
                    <div className="flex items-baseline gap-2">
                      <span className="text-lg font-semibold text-gray-900">
                        {item.arrivalCity}
                      </span>
                      <span className="text-sm font-medium text-green-600">
                        {item.arrivalTime}
                      </span>
                    </div>
                    <p className="mt-1 text-xs text-gray-400">
                      {item.arrivalAirport}
                    </p>
                  </div>
                </div>

                {/* 第三行：tips 提示（弱化字号与颜色，浅底色区分层级；仅部分卡片有） */}
                {item.tips && (
                  <div className="mt-4 rounded-[10px] bg-[#FBF4E8] px-3 py-2.5">
                    <p className="text-xs text-gray-500 leading-relaxed">
                      {item.tips}
                    </p>
                  </div>
                )}
              </div>
            ))}
          </div>
        </PullToRefresh>
      </div>
    </div>
    </>
  );
}
