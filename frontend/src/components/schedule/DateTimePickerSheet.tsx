import { useEffect, useMemo, useRef, useState } from "react";
import { cn } from "@/lib/utils";
import { BottomSheet, SHEET_BTN_CANCEL, SHEET_BTN_CONFIRM } from "@/components/trip/BottomSheet";

const ITEM_HEIGHT = 40;
const WHEEL_HEIGHT = ITEM_HEIGHT * 5; // 可见 5 行
const WHEEL_PADDING = ITEM_HEIGHT * 2; // 上下各留 2 行空白，使选中项居中

/** 上下渐隐遮罩：不滑动时选项列表上下逐渐隐藏 */
const FADE_MASK =
  "linear-gradient(to bottom, transparent 12%, black 38%, black 62%, transparent 88%)";

interface WheelColumnProps {
  values: string[];
  index: number;
  onChange: (index: number) => void;
}

/** 单列滚轮：scroll-snap 对齐 + 滚动停止 120ms 后同步选中值（与 TimePickerSheet 同模式）。 */
function WheelColumn({ values, index, onChange }: WheelColumnProps) {
  const ref = useRef<HTMLDivElement>(null);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const prevLength = useRef(values.length);

  // 挂载时定位到当前选中项（面板每次打开重新挂载）
  useEffect(() => {
    ref.current?.scrollTo({ top: index * ITEM_HEIGHT });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // 选项数量变化（如大月切小月）且当前索引越界时校正滚动位置
  useEffect(() => {
    if (prevLength.current !== values.length) {
      prevLength.current = values.length;
      if (index >= values.length) {
        ref.current?.scrollTo({ top: (values.length - 1) * ITEM_HEIGHT });
      }
    }
  });

  // 卸载时清理 debounce 计时器
  useEffect(() => {
    return () => {
      if (timer.current) clearTimeout(timer.current);
    };
  }, []);

  const handleScroll = () => {
    if (timer.current) clearTimeout(timer.current);
    timer.current = setTimeout(() => {
      const scrollTop = ref.current?.scrollTop ?? 0;
      const next = Math.min(
        values.length - 1,
        Math.max(0, Math.round(scrollTop / ITEM_HEIGHT))
      );
      if (next !== index) onChange(next);
    }, 120);
  };

  return (
    <div
      ref={ref}
      onScroll={handleScroll}
      className="flex-1 min-w-0 overflow-y-auto scrollbar-hide"
      style={{ height: WHEEL_HEIGHT, scrollSnapType: "y mandatory" }}
    >
      <div style={{ height: WHEEL_PADDING }} />
      {values.map((value, i) => (
        <div
          key={value}
          style={{ height: ITEM_HEIGHT, scrollSnapAlign: "center" }}
          className="flex items-center justify-center"
        >
          <span
            className={cn(
              "text-sm whitespace-nowrap",
              i === index ? "text-gray-900 font-medium" : "text-gray-400"
            )}
          >
            {value}
          </span>
        </div>
      ))}
      <div style={{ height: WHEEL_PADDING }} />
    </div>
  );
}

interface DateTimePickerSheetProps {
  visible: boolean;
  /** 当前已选时间（重新打开时定位），可为空 */
  value: Date | null;
  onConfirm: (date: Date) => void;
  onClose: () => void;
}

/**
 * 日程时间选择底部弹窗：五栏（年/月/日/时/分）滚轮，精确到分钟。
 * 交互模式与出发时间选择（TimePickerSheet）一致：
 * 滑动时中间显示浅灰圆角固定选中区域，选项列表上下逐渐隐藏（渐隐遮罩）。
 */
export function DateTimePickerSheet({
  visible,
  value,
  onConfirm,
  onClose,
}: DateTimePickerSheetProps) {
  const now = new Date();

  // 年份范围：今年 ~ 今年+2
  const years = useMemo(
    () => Array.from({ length: 3 }, (_, i) => `${now.getFullYear() + i}年`),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    []
  );
  const months = useMemo(
    () => Array.from({ length: 12 }, (_, i) => `${i + 1}月`),
    []
  );
  const hourValues = useMemo(
    () => Array.from({ length: 24 }, (_, i) => `${String(i).padStart(2, "0")}时`),
    []
  );
  const minuteValues = useMemo(
    () => Array.from({ length: 60 }, (_, i) => `${String(i).padStart(2, "0")}分`),
    []
  );

  const [yearIndex, setYearIndex] = useState(() => {
    const y = value?.getFullYear() ?? now.getFullYear();
    return Math.min(2, Math.max(0, y - now.getFullYear()));
  });
  const [monthIndex, setMonthIndex] = useState(
    () => (value ? value.getMonth() : now.getMonth())
  );
  const [dayIndex, setDayIndex] = useState(
    () => (value ? value.getDate() : now.getDate()) - 1
  );
  const [hourIndex, setHourIndex] = useState(() =>
    value ? value.getHours() : now.getHours()
  );
  const [minuteIndex, setMinuteIndex] = useState(() =>
    value ? value.getMinutes() : now.getMinutes()
  );

  // 选中年月对应的实际天数（自动处理大小月与闰年）
  const yearNumber = now.getFullYear() + yearIndex;
  const daysInMonth = new Date(yearNumber, monthIndex + 1, 0).getDate();
  const days = useMemo(
    () => Array.from({ length: daysInMonth }, (_, i) => `${i + 1}日`),
    [daysInMonth]
  );

  // 大月切小月时修正越界的日
  useEffect(() => {
    if (dayIndex > daysInMonth - 1) setDayIndex(daysInMonth - 1);
  }, [daysInMonth, dayIndex]);

  const handleConfirm = () => {
    onConfirm(
      new Date(yearNumber, monthIndex, dayIndex + 1, hourIndex, minuteIndex)
    );
  };

  return (
    <BottomSheet visible={visible} onClose={onClose} title="选择时间">
      {/* 五栏滚轮 + 中间固定选中区域 + 上下渐隐 */}
      <div className="relative px-2 pb-2 flex-shrink-0">
        <div className="absolute left-5 right-5 top-1/2 -translate-y-1/2 h-10 bg-gray-100 rounded-xl pointer-events-none" />
        <div
          className="flex"
          style={{ WebkitMaskImage: FADE_MASK, maskImage: FADE_MASK }}
        >
          <WheelColumn
            values={years}
            index={yearIndex}
            onChange={setYearIndex}
          />
          <WheelColumn
            values={months}
            index={monthIndex}
            onChange={setMonthIndex}
          />
          <WheelColumn values={days} index={dayIndex} onChange={setDayIndex} />
          <WheelColumn
            values={hourValues}
            index={hourIndex}
            onChange={setHourIndex}
          />
          <WheelColumn
            values={minuteValues}
            index={minuteIndex}
            onChange={setMinuteIndex}
          />
        </div>
      </div>

      {/* 底部按钮：取消 / 确定（与全站底部弹层按钮样式一致） */}
      <div className="flex gap-3 px-5 pt-1 pb-[calc(1.25rem+env(safe-area-inset-bottom))] flex-shrink-0">
        <button type="button" onClick={onClose} className={SHEET_BTN_CANCEL}>
          取消
        </button>
        <button
          type="button"
          onClick={handleConfirm}
          className={SHEET_BTN_CONFIRM}
        >
          确定
        </button>
      </div>
    </BottomSheet>
  );
}
