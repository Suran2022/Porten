import { useEffect, useState } from "react";
import { createPortal } from "react-dom";
import { useNavigate } from "react-router-dom";
import { ArrowLeft, ChevronRight } from "lucide-react";
import { cn } from "@/lib/utils";
import { CityPickerSheet } from "@/components/trip/CityPickerSheet";
import { TimePickerSheet } from "@/components/trip/TimePickerSheet";
import { AirlinePickerSheet } from "@/components/trip/AirlinePickerSheet";
import { SHEET_BTN_CANCEL, SHEET_BTN_CONFIRM } from "@/components/trip/BottomSheet";
import { useToastStore } from "@/store/toastStore";
import tripIcon from "@/assets/trip-icon.svg";
import type { City, CityAirport } from "@/data/cities";
import type { Airline } from "@/data/airlines";

/** 单端选择结果：城市 + 匹配机场 */
interface EndpointSelection {
  city: City;
  airport: CityAirport;
}

type PickerTarget = "departure" | "arrival" | "time" | "airline" | null;

/** 页面白底，状态栏同步为白色（与页面顶部严格一致）。 */
const PAGE_COLOR = "#FFFFFF";

/**
 * 创建我的行程独立页面（不包含底部导航栏）。
 * 三部分依次填写：出发与到达城市（中间虚线飞机）、出发时间、承运航司，
 * 均通过底部弹出面板选择；三部分全部选择完成后下方显示
 * "取消旅程 / 创建旅程"按钮（复用时间选择弹出框按钮样式）。
 */
export default function CreateTripPage() {
  const navigate = useNavigate();
  const showToast = useToastStore((state) => state.show);

  // 进入/退出交互：与全站页面统一的右侧滑入/滑出（同 TripPage 模式）
  const [entered, setEntered] = useState(false);
  const [leaving, setLeaving] = useState(false);
  const [picker, setPicker] = useState<PickerTarget>(null);

  const [departure, setDeparture] = useState<EndpointSelection | null>(null);
  const [arrival, setArrival] = useState<EndpointSelection | null>(null);
  const [time, setTime] = useState<Date | null>(null);
  const [airline, setAirline] = useState<Airline | null>(null);

  useEffect(() => {
    const raf = requestAnimationFrame(() => {
      requestAnimationFrame(() => setEntered(true));
    });
    return () => cancelAnimationFrame(raf);
  }, []);

  // 状态栏着色为白色（与 TripPage 同模式）：
  // iOS Safari 15~18 / 安卓 Chrome 用 theme-color（移除旧节点重建以触发重绘）；
  // Safari 26 起由下方 createPortal 的取色源色块着色。
  useEffect(() => {
    const head = document.head;
    const existing = head.querySelector<HTMLMetaElement>(
      'meta[name="theme-color"]'
    );
    const previousContent = existing?.getAttribute("content") ?? null;
    existing?.remove();

    const meta = document.createElement("meta");
    meta.setAttribute("name", "theme-color");
    meta.setAttribute("content", PAGE_COLOR);
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

  const handleBack = () => {
    if (!leaving) setLeaving(true);
  };

  const handleTransitionEnd = () => {
    // 仅在滑出结束时卸载路由（滑入结束也会触发 transitionend，需守卫）
    if (leaving) navigate(-1);
  };

  // 三部分全部选择完成后显示底部操作按钮
  const completed = departure !== null && arrival !== null && time !== null && airline !== null;

  const handleCreate = () => {
    // Mock 阶段：提示成功并返回；后续接入接口后替换为真实创建请求
    showToast("旅程创建成功", "success");
    navigate(-1);
  };

  return (
    <>
      {/* 状态栏取色源色块：portal 到 body 下、z-[1000] 成为视觉最顶层，
          供 iOS Safari 26 采样着色（与悦音乐页/行程页已验证实现一致）。
          白色与页面白底一致，视觉上完全不可见。 */}
      {createPortal(
        <div
          className="fixed top-0 left-0 right-0 z-[1000] pointer-events-none"
          style={{
            height: "max(env(safe-area-inset-top, 0px), 15px)",
            backgroundColor: PAGE_COLOR,
          }}
        />,
        document.body
      )}

      <div
        className={cn(
          "fixed inset-0 z-[60] flex flex-col overflow-hidden bg-white transition-transform duration-300 ease-[cubic-bezier(0.25,0.1,0.25,1)]",
          entered && !leaving ? "translate-x-0" : "translate-x-full"
        )}
        onTransitionEnd={handleTransitionEnd}
      >
      {/* 顶部栏：返回图标 + 居中"创建我的行程" */}
      <div className="relative flex items-center justify-between px-4 pt-[max(0.75rem,env(safe-area-inset-top))] pb-3 flex-shrink-0">
        <button
          type="button"
          onClick={handleBack}
          className="w-8 h-8 flex items-center justify-center -ml-2"
          aria-label="返回"
        >
          <ArrowLeft className="w-5 h-5 text-gray-900" strokeWidth={1.5} />
        </button>
        <h1 className="text-base font-medium text-gray-900">创建我的行程</h1>
        <div className="w-8" />
      </div>

      {/* 主内容区：三部分填写 */}
      <div className="flex-1 min-h-0 overflow-y-auto scrollbar-hide px-4 pt-2 pb-6">
        <div className="bg-white rounded-2xl border border-gray-100 px-5">
          {/* 第一部分：出发与到达城市（中间复用卡片虚线 + 飞机图标） */}
          <div className="flex items-center py-6">
            <button
              type="button"
              onClick={() => setPicker("departure")}
              className="min-w-0 flex-1 text-left"
            >
              {departure ? (
                <>
                  <div className="text-lg font-semibold text-gray-900">
                    {departure.city.name}
                  </div>
                  <div className="mt-1 text-xs text-gray-400 truncate">
                    {departure.airport.name}
                  </div>
                </>
              ) : (
                <span className="text-lg text-gray-400">出发地</span>
              )}
            </button>

            {/* 虚线航程 + 飞机（复用行程卡片样式） */}
            <div className="flex-1 flex items-center px-3 flex-shrink-0">
              <span className="flex-1 border-t border-dashed border-gray-300" />
              <img
                src={tripIcon}
                alt=""
                className="w-4 h-4 mx-1.5 flex-shrink-0"
              />
              <span className="flex-1 border-t border-dashed border-gray-300" />
            </div>

            <button
              type="button"
              onClick={() => setPicker("arrival")}
              className="min-w-0 flex-1 text-right"
            >
              {arrival ? (
                <>
                  <div className="text-lg font-semibold text-gray-900">
                    {arrival.city.name}
                  </div>
                  <div className="mt-1 text-xs text-gray-400 truncate">
                    {arrival.airport.name}
                  </div>
                </>
              ) : (
                <span className="text-lg text-gray-400">到达地</span>
              )}
            </button>
          </div>

          {/* 第二部分：出发时间 */}
          <button
            type="button"
            onClick={() => setPicker("time")}
            className="w-full flex items-center justify-between py-5 border-t border-gray-100 text-left"
          >
            {time ? (
              <span className="text-lg font-semibold text-gray-900">
                {time.getFullYear()}年{time.getMonth() + 1}月{time.getDate()}日
              </span>
            ) : (
              <span className="text-lg text-gray-400">出发时间</span>
            )}
            <ChevronRight className="w-4 h-4 text-gray-300 flex-shrink-0" />
          </button>

          {/* 第三部分：承运航司 */}
          <button
            type="button"
            onClick={() => setPicker("airline")}
            className="w-full flex items-center justify-between py-5 border-t border-gray-100 text-left"
          >
            {airline ? (
              <span className="flex items-center gap-2">
                <img
                  src={airline.icon}
                  alt=""
                  className="w-4 h-4 object-contain"
                />
                <span className="text-lg font-semibold text-gray-900">
                  {airline.name}
                </span>
              </span>
            ) : (
              <span className="text-lg text-gray-400">承运航司</span>
            )}
            <ChevronRight className="w-4 h-4 text-gray-300 flex-shrink-0" />
          </button>
        </div>

        {/* 三部分选择完成后：取消旅程 / 创建旅程（复用时间选择弹出框按钮样式） */}
        {completed && (
          <div className="flex gap-3 px-1 mt-6 sheet-step-in">
            <button
              type="button"
              onClick={handleBack}
              className={SHEET_BTN_CANCEL}
            >
              取消旅程
            </button>
            <button
              type="button"
              onClick={handleCreate}
              className={SHEET_BTN_CONFIRM}
            >
              创建旅程
            </button>
          </div>
        )}
      </div>

      {/* 城市选择弹窗（出发地 / 到达地） */}
      <CityPickerSheet
        visible={picker === "departure" || picker === "arrival"}
        target={picker === "arrival" ? "到达地" : "出发地"}
        onClose={() => setPicker(null)}
        onSelect={(city, airport) => {
          if (picker === "arrival") {
            setArrival({ city, airport });
          } else {
            setDeparture({ city, airport });
          }
        }}
      />

      {/* 出发时间选择弹窗 */}
      <TimePickerSheet
        visible={picker === "time"}
        value={time}
        onConfirm={(date) => {
          setTime(date);
          setPicker(null);
        }}
        onClose={() => setPicker(null)}
      />

      {/* 承运航司选择弹窗 */}
      <AirlinePickerSheet
        visible={picker === "airline"}
        onSelect={(selected) => setAirline(selected)}
        onClose={() => setPicker(null)}
      />
      </div>
    </>
  );
}
