import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import { createPortal } from "react-dom";
import { useNavigate } from "react-router-dom";
import { Plus } from "lucide-react";
import { BackIcon } from "@/components/common/BackIcon";
import { cn, toDateKey } from "@/lib/utils";
import { useToastStore } from "@/store/toastStore";
import {
  createSchedule,
  fetchScheduleRelated,
  fetchSchedules,
  updateSchedule,
} from "@/lib/api";
import { getHolidayName } from "@/data/holidays";
import {
  CreateScheduleSheet,
} from "@/components/schedule/CreateScheduleSheet";
import {
  ScheduleCard,
  SCHEDULE_CARD_LEFT,
  SCHEDULE_CARD_RIGHT,
} from "@/components/schedule/ScheduleCard";
import type {
  ScheduleComrade,
  ScheduleItem,
  ScheduleRelatedData,
} from "@/types/schedule";

/** 页面白底，状态栏同步为白色（与创建旅程页一致）。 */
const PAGE_COLOR = "#FFFFFF";

/** 选中日期与创建按钮的淡粉色不饱和底色（与底部弹出面板确认按钮一致）。 */
const SCHEDULE_PINK = "#F7C5D0";

/** 日期网格范围：以今天为中心，向前 16 周、向后 20 周（覆盖次年春节）。 */
const WEEKS_BEFORE = 16;
const WEEKS_AFTER = 20;

/** 星期标头（周一起始，与周网格顺序一致）。 */
const WEEKDAY_LABELS = [
  "星期一",
  "星期二",
  "星期三",
  "星期四",
  "星期五",
  "星期六",
  "星期日",
];

/** 时间线单小时高度（px），刻度行与日程卡片共用。 */
const HOUR_PX = 36;
/** 时间线内容高度：24 小时刻度 + 底部预留（末尾小时日程展开详情用）。 */
const TIMELINE_HEIGHT = 24 * HOUR_PX + 160;

/** 取周一作为一周起点（当天 0 点）。 */
function startOfWeek(date: Date): Date {
  const d = new Date(date);
  const day = (d.getDay() + 6) % 7; // 周一=0 … 周日=6
  d.setDate(d.getDate() - day);
  d.setHours(0, 0, 0, 0);
  return d;
}

function addDays(date: Date, days: number): Date {
  const d = new Date(date);
  d.setDate(d.getDate() + days);
  return d;
}

/** 生成周网格：每行一周（7 天，周一起始）。 */
function buildWeeks(weeksBefore: number, weeksAfter: number): Date[][] {
  const first = addDays(startOfWeek(new Date()), -7 * weeksBefore);
  const weeks: Date[][] = [];
  for (let w = 0; w < weeksBefore + weeksAfter + 1; w++) {
    const weekStart = addDays(first, w * 7);
    weeks.push(Array.from({ length: 7 }, (_, i) => addDays(weekStart, i)));
  }
  return weeks;
}

/**
 * 我的日程独立页面（不包含底部导航栏）。
 * 顶部栏返回 + 居中标题；右上区域年月行 + 星期标头 + 按周横滑日期条；
 * 下方为选中日期的 0-23 点时间线：单击空白处快捷创建日程，
 * 日程卡片支持展开/收起、双击完整编辑、拖拽调整结束时间；
 * 右下角悬浮加号按钮打开完整创建弹层。
 */
export default function SchedulePage() {
  const navigate = useNavigate();
  const showToast = useToastStore((state) => state.show);

  // 进入/退出交互：与全站页面统一的右侧滑入/滑出（同创建旅程页模式）
  const [entered, setEntered] = useState(false);
  const [leaving, setLeaving] = useState(false);

  // 数据：日程列表（mock 引擎内存态）与有日程的日期集合（驱动绿点）
  const [items, setItems] = useState<ScheduleItem[]>([]);

  // 关联候选（旅程/约定/同胞）：用于展开卡片时解析关联名称与参与者信息
  const [relatedData, setRelatedData] = useState<ScheduleRelatedData | null>(
    null
  );

  // 选中日期（默认今天）与年月行显示（跟随日期条可视区域第一周）
  const [selected, setSelected] = useState(() => toDateKey(new Date()));
  const [viewYear, setViewYear] = useState(() => new Date().getFullYear());
  const [viewMonth, setViewMonth] = useState(() => new Date().getMonth() + 1);

  // 时间线交互：展开的日程卡 / 双击编辑的日程 / 完整创建弹层 / 快捷创建草稿
  const [expandedId, setExpandedId] = useState<number | null>(null);
  const [editing, setEditing] = useState<ScheduleItem | null>(null);
  const [createSheetOpen, setCreateSheetOpen] = useState(false);
  const [quickDraftHour, setQuickDraftHour] = useState<number | null>(null);
  const [draftTitle, setDraftTitle] = useState("");
  const [draftDetail, setDraftDetail] = useState("");

  const scrollRef = useRef<HTMLDivElement>(null);
  const weeks = useMemo(() => buildWeeks(WEEKS_BEFORE, WEEKS_AFTER), []);
  const hours = useMemo(() => Array.from({ length: 24 }, (_, i) => i), []);

  const reload = useCallback(async () => {
    try {
      setItems(await fetchSchedules());
    } catch {
      // mock 数据加载失败不阻塞页面
    }
  }, []);

  useEffect(() => {
    void reload();
    fetchScheduleRelated()
      .then(setRelatedData)
      .catch(() => {
        // 候选数据加载失败不阻塞页面（展开卡片仅缺关联/参与者信息）
      });
  }, [reload]);

  // 关联项 id → 名称（"trip-1" / "agreement-2"）
  const relatedLabelMap = useMemo(() => {
    const map = new Map<string, string>();
    (relatedData?.trips ?? []).forEach((t) => map.set(`trip-${t.id}`, t.label));
    (relatedData?.agreements ?? []).forEach((a) =>
      map.set(`agreement-${a.id}`, a.label)
    );
    return map;
  }, [relatedData]);

  // 参与者 id → 完整信息（头像/昵称）
  const comradeMap = useMemo(() => {
    const map = new Map<number, ScheduleComrade>();
    (relatedData?.comrades ?? []).forEach((c) => map.set(c.id, c));
    return map;
  }, [relatedData]);

  useEffect(() => {
    const raf = requestAnimationFrame(() => {
      requestAnimationFrame(() => setEntered(true));
    });
    return () => cancelAnimationFrame(raf);
  }, []);

  // 状态栏着色为白色（与创建旅程页同模式）：
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

  // 初始定位到选中日期所在周
  useEffect(() => {
    const container = scrollRef.current;
    if (!container) return;
    const selectedIndex = weeks.findIndex((week) =>
      week.some((date) => toDateKey(date) === selected)
    );
    if (selectedIndex >= 0) {
      container.scrollLeft = selectedIndex * container.clientWidth;
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const scheduleDates = useMemo(
    () => new Set(items.map((it) => it.date)),
    [items]
  );
  const dayItems = useMemo(
    () => items.filter((it) => it.date === selected),
    [items, selected]
  );

  const handleBack = () => {
    if (!leaving) setLeaving(true);
  };

  const handleTransitionEnd = () => {
    // 仅在滑出结束时卸载路由（滑入结束也会触发 transitionend，需守卫）
    if (leaving) navigate(-1);
  };

  // 年月行跟随日期条可视区域第一周（每次滑动对齐一整周）；
  // 跨月周取周中点（周四）所在月，与该周多数天一致
  const handleScroll = () => {
    const container = scrollRef.current;
    if (!container || container.clientWidth === 0) return;
    const index = Math.min(
      Math.max(Math.round(container.scrollLeft / container.clientWidth), 0),
      weeks.length - 1
    );
    const mid = weeks[index]?.[3];
    if (!mid) return;
    setViewYear(mid.getFullYear());
    setViewMonth(mid.getMonth() + 1);
  };

  // 时间线：单击空白刻度行 → 原位快捷创建（标题选填 + 详情）
  const handleTimelineClick = (hour: number) => {
    setQuickDraftHour(hour);
    setDraftTitle("");
    setDraftDetail("");
  };

  const handleQuickCancel = () => {
    setQuickDraftHour(null);
    setDraftTitle("");
    setDraftDetail("");
  };

  const handleQuickSave = async () => {
    if (quickDraftHour == null) return;
    if (!draftDetail.trim()) {
      showToast("写点什么再保存吧", "error");
      return;
    }
    const hour = quickDraftHour;
    try {
      await createSchedule({
        date: selected,
        start_time: `${String(hour).padStart(2, "0")}:00`,
        end_time: hour < 23 ? `${String(hour + 1).padStart(2, "0")}:00` : "24:00",
        title: draftTitle.trim() || null,
        detail: draftDetail.trim(),
        source: "quick",
      });
      handleQuickCancel();
      await reload();
      showToast("日程已创建", "success");
    } catch (err) {
      showToast(err instanceof Error ? err.message : "创建失败", "error");
    }
  };

  // 拖拽调整结束时间：乐观更新 + 静默同步 mock 引擎
  const handleEndTimeChange = async (id: number, endTime: string) => {
    setItems((prev) =>
      prev.map((it) => (it.id === id ? { ...it, end_time: endTime } : it))
    );
    try {
      await updateSchedule(id, { end_time: endTime });
    } catch {
      // 乐观更新，失败不回滚演示数据
    }
  };

  const handleToggleExpand = (id: number) => {
    setExpandedId((prev) => (prev === id ? null : id));
  };

  const handleOpenEdit = (item: ScheduleItem) => {
    setEditing(item);
    setCreateSheetOpen(false);
  };

  const handleCloseSheet = () => {
    setCreateSheetOpen(false);
    setEditing(null);
  };

  return (
    <>
      {/* 状态栏取色源色块：portal 到 body 下、z-[1000] 成为视觉最顶层，
          供 iOS Safari 26 采样着色（与创建旅程页已验证实现一致）。
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
        {/* 顶部栏：返回图标 + 居中"我的日程" */}
        <div className="relative flex items-center justify-between px-4 pt-[max(0.75rem,env(safe-area-inset-top))] pb-3 flex-shrink-0">
          <button
            type="button"
            onClick={handleBack}
            className="w-10 h-10 flex items-center justify-center -ml-2"
            aria-label="返回"
          >
            <BackIcon className="w-7 h-7" />
          </button>
          <h1 className="text-lg font-medium text-gray-900">我的日程</h1>
          <div className="w-8" />
        </div>

        {/* 年月行：左对齐年份与居中月份同样式，基线对齐 */}
        <div className="grid grid-cols-3 items-baseline px-5 pt-1 pb-2 flex-shrink-0">
          <span className="justify-self-start text-base font-semibold text-gray-900">
            {viewYear}年
          </span>
          <span className="justify-self-center text-base font-semibold text-gray-900">
            {viewMonth}月
          </span>
          <span />
        </div>

        {/* 星期标头：与日期卡逐列对齐 */}
        <div className="grid grid-cols-7 gap-1 px-2 pt-2 pb-1 flex-shrink-0">
          {WEEKDAY_LABELS.map((label) => (
            <span
              key={label}
              className="text-center text-xs font-semibold leading-none text-gray-400"
            >
              {label}
            </span>
          ))}
        </div>

        {/* 日期条：按周分组的横向滑动列表，滑动按周对齐 */}
        <div
          ref={scrollRef}
          onScroll={handleScroll}
          className="flex snap-x snap-mandatory overflow-x-auto scrollbar-hide flex-shrink-0"
        >
          {weeks.map((week, weekIndex) => (
            <div
              key={weekIndex}
              className="w-full flex-shrink-0 snap-start px-2"
            >
              <div className="grid grid-cols-7 gap-1">
                {week.map((date) => {
                  const key = toDateKey(date);
                  const holiday = getHolidayName(key);
                  const hasSchedule = scheduleDates.has(key);
                  const isSelected = key === selected;
                  return (
                    <button
                      key={key}
                      type="button"
                      onClick={() => setSelected(key)}
                      className={cn(
                        "relative h-14 rounded-xl transition-colors",
                        isSelected
                          ? "text-white"
                          : "bg-gray-500/10 text-gray-800"
                      )}
                      style={
                        isSelected
                          ? { backgroundColor: SCHEDULE_PINK }
                          : undefined
                      }
                    >
                      {/* 数字固定锚点：不随节日名有无上下浮动，保证逐卡对齐 */}
                      <span className="absolute top-2 left-1/2 -translate-x-1/2 text-sm font-medium leading-none">
                        {date.getDate()}
                      </span>
                      {holiday ? (
                        <span
                          className={cn(
                            "absolute bottom-1.5 left-1/2 -translate-x-1/2 text-[10px] leading-none whitespace-nowrap",
                            isSelected ? "text-white/90" : "text-rose-400"
                          )}
                        >
                          {holiday}
                        </span>
                      ) : null}
                      {/* 有日程：右上角浅绿色小圆点（留出边距，不贴卡缘） */}
                      {hasSchedule ? (
                        <span className="absolute top-1.5 right-1.5 w-1.5 h-1.5 rounded-full bg-emerald-300" />
                      ) : null}
                    </button>
                  );
                })}
              </div>
            </div>
          ))}
        </div>

        {/* 时间线：0-23 点刻度铺底 + 日程卡片层 + 快捷创建内联卡（与日期条留出间距） */}
        <div className="flex-1 min-h-0 overflow-y-auto scrollbar-hide mt-4">
          <div className="relative" style={{ height: TIMELINE_HEIGHT }}>
            {/* 刻度行铺底（单击空白处快捷创建） */}
            {hours.map((hour) => (
              <div
                key={hour}
                className="absolute left-5 right-5 flex items-center cursor-pointer"
                style={{ top: hour * HOUR_PX, height: HOUR_PX }}
                onClick={() => handleTimelineClick(hour)}
              >
                <span className="w-12 flex-shrink-0 text-sm font-bold text-gray-700 tabular-nums">
                  {String(hour).padStart(2, "0")}:00
                </span>
                <span className="ml-3 flex-1 border-t border-gray-200" />
              </div>
            ))}

            {/* 日程卡片层 */}
            {dayItems.map((item) => (
              <ScheduleCard
                key={item.id}
                item={item}
                expanded={expandedId === item.id}
                hourPx={HOUR_PX}
                relatedLabel={
                  item.related_type && item.related_id != null
                    ? (relatedLabelMap.get(
                        `${item.related_type}-${item.related_id}`
                      ) ?? null)
                    : null
                }
                participants={item.participant_ids
                  .map((id) => comradeMap.get(id))
                  .filter((c): c is ScheduleComrade => c != null)}
                onToggleExpand={handleToggleExpand}
                onOpenEdit={handleOpenEdit}
                onEndTimeChange={handleEndTimeChange}
              />
            ))}

            {/* 快捷创建内联卡：标题选填 + 详情，保存后落入时间线 */}
            {quickDraftHour != null && (
              <div
                className="absolute z-30 rounded-xl border border-[#F7C5D0] bg-white shadow-lg p-2.5"
                style={{
                  left: SCHEDULE_CARD_LEFT,
                  right: SCHEDULE_CARD_RIGHT,
                  top: quickDraftHour * HOUR_PX,
                }}
              >
                <input
                  autoFocus
                  value={draftTitle}
                  onChange={(e) => setDraftTitle(e.target.value)}
                  placeholder="标题（选填）"
                  className="w-full text-sm text-gray-800 placeholder:text-gray-300 outline-none"
                />
                <textarea
                  value={draftDetail}
                  onChange={(e) => setDraftDetail(e.target.value)}
                  rows={2}
                  placeholder="写点什么…（必填）"
                  className="mt-1 w-full text-xs text-gray-700 placeholder:text-gray-300 outline-none resize-none"
                />
                <div className="mt-1.5 flex justify-end gap-2">
                  <button
                    type="button"
                    onClick={handleQuickCancel}
                    className="px-3 py-1 rounded-lg bg-gray-100 text-gray-500 text-xs transition-colors active:bg-gray-200"
                  >
                    取消
                  </button>
                  <button
                    type="button"
                    onClick={handleQuickSave}
                    className="px-3 py-1 rounded-lg bg-[#F7C5D0] text-white text-xs transition-opacity active:opacity-80"
                  >
                    保存
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>

        {/* 悬浮创建按钮：右下角常规位置，打开完整创建弹层 */}
        <button
          type="button"
          onClick={() => setCreateSheetOpen(true)}
          className="fixed right-5 bottom-6 z-[65] w-14 h-14 rounded-full flex items-center justify-center shadow-md transition-opacity active:opacity-80"
          style={{ backgroundColor: SCHEDULE_PINK }}
          aria-label="创建日程"
        >
          <Plus className="w-6 h-6 text-white" strokeWidth={2} />
        </button>
      </div>

      {/* 创建/编辑日程弹层（编辑模式由 editing 驱动回填） */}
      <CreateScheduleSheet
        visible={createSheetOpen || editing != null}
        editing={editing}
        onClose={handleCloseSheet}
        onSaved={reload}
      />
    </>
  );
}
