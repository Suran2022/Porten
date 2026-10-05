import { useRef, useState } from "react";
import { cn, hmmToMinutes, minutesToHHmm } from "@/lib/utils";
import { usePointerInteraction } from "@/hooks/usePointerInteraction";
import { SCHEDULE_CARD_BG, type ScheduleComrade, type ScheduleItem } from "@/types/schedule";

/** 卡片左缘：时间线容器左留白 20px + 时间文本 48px + 间距 12px。 */
export const SCHEDULE_CARD_LEFT = 80;
/** 卡片右缘距容器右侧留白。 */
export const SCHEDULE_CARD_RIGHT = 20;

/** 拖拽结束时间的吸附粒度（分钟）。 */
const RESIZE_SNAP_MINUTES = 15;

interface ScheduleCardProps {
  item: ScheduleItem;
  /** 是否展开（展示详情） */
  expanded: boolean;
  /** 单小时高度（px），与时间线刻度行一致 */
  hourPx: number;
  /** 已解析的关联项名称（关联旅程 / 关联约定），展开时显示 */
  relatedLabel?: string | null;
  /** 已选参与同胞（含头像），展开时显示 */
  participants?: ScheduleComrade[];
  onToggleExpand: (id: number) => void;
  onOpenEdit: (item: ScheduleItem) => void;
  /** 拖拽结束后提交新的结束时间（HH:mm） */
  onEndTimeChange: (id: number, endTime: string) => void;
}

/**
 * 时间线日程卡片：按开始/结束时间绝对定位覆盖刻度行。
 * 单击展开/收起详情，双击打开完整编辑弹层，
 * 底部拖拽手柄可拉到目标时间线位置调整结束时间（15 分钟吸附）。
 */
export function ScheduleCard({
  item,
  expanded,
  hourPx,
  relatedLabel,
  participants,
  onToggleExpand,
  onOpenEdit,
  onEndTimeChange,
}: ScheduleCardProps) {
  const startMin = hmmToMinutes(item.start_time);
  const baseEndMin = item.end_time
    ? hmmToMinutes(item.end_time)
    : startMin + 60;

  // 拖拽预览的结束时间（分钟）；null 表示未在拖拽
  const [previewEndMin, setPreviewEndMin] = useState<number | null>(null);
  const [dragging, setDragging] = useState(false);
  const dragState = useRef<{ startY: number; baseEnd: number } | null>(null);
  const handleRef = useRef<HTMLDivElement>(null);

  // 单击/双击区分：单击延迟 250ms 触发展开收起，双击直接打开编辑
  const clickTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  usePointerInteraction(handleRef, {
    onPointerDown: (e) => {
      dragState.current = { startY: e.clientY, baseEnd: baseEndMin };
      setDragging(true);
    },
    onPointerMove: (e) => {
      const state = dragState.current;
      if (!state) return;
      const deltaMin = (e.clientY - state.startY) / (hourPx / 60);
      const snapped =
        Math.round((state.baseEnd + deltaMin) / RESIZE_SNAP_MINUTES) *
        RESIZE_SNAP_MINUTES;
      const clamped = Math.min(
        24 * 60,
        Math.max(startMin + RESIZE_SNAP_MINUTES, snapped)
      );
      setPreviewEndMin(clamped);
    },
    onPointerUp: () => {
      const state = dragState.current;
      const preview = previewEndMin;
      dragState.current = null;
      setDragging(false);
      setPreviewEndMin(null);
      if (state && preview != null) {
        onEndTimeChange(item.id, minutesToHHmm(preview));
      }
    },
    onPointerCancel: () => {
      dragState.current = null;
      setDragging(false);
      setPreviewEndMin(null);
    },
  });

  const handleClick = () => {
    if (clickTimer.current) {
      clearTimeout(clickTimer.current);
      clickTimer.current = null;
      return;
    }
    clickTimer.current = setTimeout(() => {
      clickTimer.current = null;
      onToggleExpand(item.id);
    }, 250);
  };

  const handleDoubleClick = () => {
    if (clickTimer.current) {
      clearTimeout(clickTimer.current);
      clickTimer.current = null;
    }
    onOpenEdit(item);
  };

  // 收起态高度跟随时间跨度（拖拽中实时预览），无结束时间默认 1 小时
  const displayEndMin = previewEndMin ?? baseEndMin;
  const collapsedHeight = Math.max(
    hourPx,
    ((displayEndMin - startMin) / 60) * hourPx
  );

  return (
    <div
      className="absolute z-10"
      style={{
        left: SCHEDULE_CARD_LEFT,
        right: SCHEDULE_CARD_RIGHT,
        top: (startMin / 60) * hourPx,
        height: expanded ? "auto" : collapsedHeight,
        minHeight: expanded ? collapsedHeight : undefined,
      }}
    >
      <div
        className={cn(
          "relative rounded-xl px-3 py-1.5 text-white shadow-sm overflow-hidden select-none cursor-pointer transition-shadow",
          expanded && "shadow-lg",
          dragging && "ring-2 ring-white/80"
        )}
        style={{ backgroundColor: SCHEDULE_CARD_BG[item.color], height: expanded ? "auto" : "100%" }}
        onClick={handleClick}
        onDoubleClick={handleDoubleClick}
      >
        <div className="text-[11px] leading-tight opacity-90 tabular-nums">
          {item.start_time}
          {item.end_time ? ` - ${item.end_time}` : ""}
        </div>
        <div className="text-sm font-medium leading-snug truncate">
          {item.title || "快速日程"}
        </div>
        {expanded && item.detail ? (
          <div className="mt-1 text-xs leading-relaxed opacity-95 whitespace-pre-wrap break-words">
            {item.detail}
          </div>
        ) : null}
        {expanded && item.place ? (
          <div className="mt-0.5 text-xs opacity-90">📍 {item.place}</div>
        ) : null}
        {expanded && relatedLabel ? (
          <div className="mt-0.5 text-xs opacity-95 whitespace-nowrap overflow-hidden text-ellipsis">
            🔗 {item.related_type === "trip" ? "旅程" : "约定"} · {relatedLabel}
          </div>
        ) : null}
        {expanded && participants && participants.length > 0 ? (
          <div className="mt-1.5 flex flex-wrap gap-x-2.5 gap-y-1">
            {participants.map((p) => (
              <span
                key={p.id}
                className="flex flex-col items-center w-11"
              >
                <img
                  src={p.avatar}
                  alt=""
                  className="w-7 h-7 rounded-full object-cover bg-white/40"
                />
                <span className="mt-0.5 max-w-full text-[10px] leading-tight truncate text-[#E88CA8] font-medium">
                  @{p.nickname}
                </span>
              </span>
            ))}
          </div>
        ) : null}

        {/* 底部拖拽手柄：拉到目标时间线位置调整结束时间 */}
        <div
          ref={handleRef}
          className="absolute bottom-0 left-0 right-0 h-2.5 cursor-ns-resize flex items-center justify-center"
          style={{ touchAction: "none" }}
          aria-label="拖动调整结束时间"
        >
          <span className="w-8 h-1 rounded-full bg-white/60" />
        </div>
      </div>
    </div>
  );
}
