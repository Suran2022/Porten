import { useEffect, useState } from "react";
import { BottomSheet } from "./BottomSheet";
import { AIRLINES, type Airline } from "@/data/airlines";

interface AirlinePickerSheetProps {
  visible: boolean;
  onClose: () => void;
  /** 选定航司后回调，由调用方负责关闭弹窗 */
  onSelect: (airline: Airline) => void;
}

/**
 * 承运航司选择底部弹窗：
 * 搜索框复用城市选择样式（提示文本改为"搜索航司"）；
 * 航司列表左对齐，图标在前名字在后，字号粗度大，
 * 图标（16px）与文本（text-base = 16px）视觉 size 一致。
 */
export function AirlinePickerSheet({
  visible,
  onSelect,
  onClose,
}: AirlinePickerSheetProps) {
  const [query, setQuery] = useState("");

  // 每次打开重置搜索
  useEffect(() => {
    if (visible) setQuery("");
  }, [visible]);

  const filtered = AIRLINES.filter((airline) =>
    airline.name.includes(query.trim())
  );

  return (
    <BottomSheet visible={visible} onClose={onClose} title="承运航司">
      {/* 搜索框：复用城市选择搜索框样式，仅提示文本不同 */}
      <div className="px-4 py-2 flex-shrink-0">
        <input
          type="text"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="搜索航司"
          className="w-full bg-gray-100 rounded-xl px-4 py-2.5 text-sm text-gray-900 text-center placeholder:text-gray-400 outline-none"
        />
      </div>

      {/* 航司列表：图标在前、名字在后 */}
      <div className="flex-1 min-h-0 overflow-y-auto scrollbar-hide px-5 pb-8">
        {filtered.map((airline) => (
          <button
            key={airline.name}
            type="button"
            onClick={() => {
              onSelect(airline);
              onClose();
            }}
            className="w-full flex items-center gap-3 py-3.5 px-1 text-left active:bg-gray-50 rounded-lg"
          >
            <img
              src={airline.icon}
              alt=""
              className="w-4 h-4 object-contain flex-shrink-0"
            />
            <span className="text-base leading-none font-semibold text-gray-900">
              {airline.name}
            </span>
          </button>
        ))}
        {filtered.length === 0 && (
          <p className="py-12 text-center text-sm text-gray-400">
            未找到相关航司
          </p>
        )}
      </div>
    </BottomSheet>
  );
}
