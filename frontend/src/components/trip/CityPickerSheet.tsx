import { useEffect, useMemo, useRef, useState } from "react";
import { cn } from "@/lib/utils";
import { BottomSheet } from "./BottomSheet";
import { CITY_GROUPS, type City, type CityAirport } from "@/data/cities";

interface CityPickerSheetProps {
  visible: boolean;
  /** 目标文案："出发地" / "到达地"，用于标题与搜索提示 */
  target: string;
  onClose: () => void;
  /** 选定城市（含机场）后回调，由调用方负责关闭弹窗 */
  onSelect: (city: City, airport: CityAirport) => void;
}

/**
 * 城市选择底部弹窗（两步流程）：
 * 第一步选择城市 —— 浅灰圆角搜索框（提示文本居中、聚焦无任何样式变化）、
 * 城市列表左中文名右英文名、按字母分类、右侧字母索引条点击定位；
 * 单机场城市点击即选定关闭；双机场城市进入第二步"选择机场"——
 * 左对齐显示城市名，机场名缩进并以树杈分支线连接。
 */
export function CityPickerSheet({
  visible,
  target,
  onClose,
  onSelect,
}: CityPickerSheetProps) {
  const [step, setStep] = useState<"city" | "airport">("city");
  const [selectedCity, setSelectedCity] = useState<City | null>(null);
  const [query, setQuery] = useState("");
  // 记录打开时的目标文案：关闭动画期间外部 target 已回退，避免标题/提示闪变
  const [activeTarget, setActiveTarget] = useState(target);
  const listRef = useRef<HTMLDivElement>(null);

  // 每次打开重置为第一步
  useEffect(() => {
    if (visible) {
      setStep("city");
      setSelectedCity(null);
      setQuery("");
      setActiveTarget(target);
    }
  }, [visible, target]);

  // 按中文名 / 英文名过滤城市
  const filteredGroups = useMemo(() => {
    const raw = query.trim();
    if (!raw) return CITY_GROUPS;
    const q = raw.toLowerCase();
    return CITY_GROUPS.map((group) => ({
      ...group,
      cities: group.cities.filter(
        (city) => city.name.includes(raw) || city.en.toLowerCase().includes(q)
      ),
    })).filter((group) => group.cities.length > 0);
  }, [query]);

  const handleCityClick = (city: City) => {
    if (city.airports.length === 1) {
      // 单机场城市：自动匹配机场，直接关闭
      onSelect(city, city.airports[0]);
      onClose();
    } else {
      // 多机场城市：不关闭，进入第二步选择机场
      setSelectedCity(city);
      setStep("airport");
    }
  };

  const scrollToLetter = (letter: string) => {
    listRef.current
      ?.querySelector(`[data-letter="${letter}"]`)
      ?.scrollIntoView({ behavior: "smooth", block: "start" });
  };

  const handleAirportClick = (airport: CityAirport) => {
    if (selectedCity) {
      onSelect(selectedCity, airport);
      onClose();
    }
  };

  return (
    <BottomSheet
      visible={visible}
      onClose={onClose}
      title={step === "city" ? `选择${activeTarget}` : "选择机场"}
      heightClass="h-[90vh]"
      onBack={
        step === "airport"
          ? () => {
              setStep("city");
              setSelectedCity(null);
            }
          : undefined
      }
    >
      {step === "city" ? (
        <div className="flex-1 min-h-0 flex flex-col sheet-step-in">
          {/* 搜索框：浅灰圆角、提示文本居中；聚焦不需要 border/背景变化等任何样式 */}
          <div className="px-4 py-2 flex-shrink-0">
            <input
              type="text"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder={`搜索${activeTarget}`}
              className="w-full bg-gray-100 rounded-xl px-4 py-2.5 text-sm text-gray-900 text-center placeholder:text-gray-400 outline-none"
            />
          </div>

          {/* 城市列表 + 字母索引条 */}
          <div className="flex-1 min-h-0 flex">
            <div ref={listRef} className="flex-1 min-w-0 overflow-y-auto scrollbar-hide px-4 pb-8">
              {filteredGroups.map((group) => (
                <div key={group.letter} data-letter={group.letter}>
                  <div className="py-2 text-sm font-medium text-gray-400">
                    {group.letter}
                  </div>
                  {group.cities.map((city) => (
                    <button
                      key={city.name}
                      type="button"
                      onClick={() => handleCityClick(city)}
                      className="w-full flex items-center justify-between py-3 text-left active:bg-gray-50 rounded-lg"
                    >
                      <span className="text-base text-gray-900">{city.name}</span>
                      <span className="text-sm text-gray-400">{city.en}</span>
                    </button>
                  ))}
                </div>
              ))}
              {filteredGroups.length === 0 && (
                <p className="py-12 text-center text-sm text-gray-400">
                  未找到相关城市
                </p>
              )}
            </div>

            {/* 字母索引条：点击定位到对应分类 */}
            <div className="flex flex-col items-center justify-center gap-0.5 px-2 flex-shrink-0">
              {filteredGroups.map((group) => (
                <button
                  key={group.letter}
                  type="button"
                  onClick={() => scrollToLetter(group.letter)}
                  className="w-5 h-4 flex items-center justify-center text-xs text-gray-500 active:text-[#F5A9B8]"
                >
                  {group.letter}
                </button>
              ))}
            </div>
          </div>
        </div>
      ) : (
        /* 第二步：选择机场 —— 左对齐城市名，机场名缩进 + 树杈分支线连接 */
        <div className="flex-1 min-h-0 overflow-y-auto scrollbar-hide px-5 pb-8 sheet-step-in">
          <h3 className="pt-3 pb-1 text-lg font-semibold text-gray-900">
            {selectedCity?.name}
          </h3>
          <div className="mt-1">
            {selectedCity?.airports.map((airport, index) => {
              const isLast = index === selectedCity.airports.length - 1;
              return (
                <button
                  key={airport.name}
                  type="button"
                  onClick={() => handleAirportClick(airport)}
                  className={cn(
                    "relative block w-full pl-7 pr-2 py-3.5 text-left rounded-lg",
                    "active:bg-gray-50"
                  )}
                >
                  {/* 树杈竖线：最后一行只画到中线 */}
                  <span
                    className={cn(
                      "absolute left-1.5 top-0 w-px bg-gray-300",
                      isLast ? "h-1/2" : "h-full"
                    )}
                  />
                  {/* 横向枝杈：连接竖线与机场名 */}
                  <span
                    className={cn(
                      "absolute left-1.5 w-3 h-px bg-gray-300",
                      isLast ? "top-1/2" : "top-0"
                    )}
                  />
                  <span className="text-base text-gray-900">
                    {airport.name}
                  </span>
                </button>
              );
            })}
          </div>
        </div>
      )}
    </BottomSheet>
  );
}
