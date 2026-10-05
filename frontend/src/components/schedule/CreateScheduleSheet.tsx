import { useEffect, useMemo, useState } from "react";
import {
  BottomSheet,
  SHEET_BTN_CANCEL,
  SHEET_BTN_CONFIRM,
} from "@/components/trip/BottomSheet";
import { DateTimePickerSheet } from "./DateTimePickerSheet";
import { RelatedPickerSheet } from "./RelatedPickerSheet";
import {
  cn,
  formatDateTimeCn,
  formatHHmm,
  toDateKey,
} from "@/lib/utils";
import { useToastStore } from "@/store/toastStore";
import {
  createSchedule,
  fetchScheduleRelated,
  updateSchedule,
} from "@/lib/api";
import {
  SCHEDULE_CATEGORIES,
  type ScheduleCategory,
  type ScheduleItem,
  type ScheduleRelatedData,
  type ScheduleRelatedType,
} from "@/types/schedule";

/** 表单时间 chip：细小浅灰色圆角 border。 */
const TIME_CHIP =
  "flex-1 min-w-0 border border-gray-200 rounded-lg px-3 py-2 text-sm text-left transition-colors";

/** 文本输入框：与时间 chip 同族的细小浅灰圆角 border。 */
const TEXT_INPUT =
  "w-full border border-gray-200 rounded-lg px-3 py-2 text-sm text-gray-800 placeholder:text-gray-300 outline-none focus:border-gray-300 transition-colors";

/** 选择入口 chip：与时间 chip 同族，占满一行。 */
const PICK_TRIGGER =
  "w-full border border-gray-200 rounded-lg px-3 py-2 text-sm text-left transition-colors";

/** 参与者昵称粉色文本（比主粉 #F7C5D0 深一档，保证可读）。 */
const PINK_TEXT = "text-[#E88CA8]";

/** 可选项 chip：未选中浅灰描边 / 选中淡粉色不饱和底。 */
const CHIP = "px-3.5 py-1.5 rounded-full text-sm border transition-colors";
const CHIP_ACTIVE = "bg-[#F7C5D0] border-transparent text-white";
const CHIP_IDLE = "border-gray-200 text-gray-600";

/** 由日程条目的日期与 HH:mm 构造 Date（用于编辑回填）。 */
function parseItemDate(date: string, hhmm: string): Date {
  const [y, m, d] = date.split("-").map(Number);
  const [hh, mm] = hhmm.split(":").map(Number);
  return new Date(y, m - 1, d, hh, mm);
}

interface CreateScheduleSheetProps {
  visible: boolean;
  onClose: () => void;
  /** 编辑模式传入待编辑日程；null 表示创建模式 */
  editing: ScheduleItem | null;
  /** 创建模式默认开始时间（时间线快捷定位传入），缺省为当前时刻 */
  defaultStart?: Date | null;
  /** 保存成功回调（外层刷新列表） */
  onSaved: () => void;
}

/**
 * 创建/编辑日程底部弹层（占页面高度 75%）。
 * 依次填写：日程时间（必填）、标题（选填）、详情、分类、
 * 条件关联项（旅行→关联旅程 / 约会→关联约定）、添加地点、参与同胞。
 */
export function CreateScheduleSheet({
  visible,
  onClose,
  editing,
  defaultStart,
  onSaved,
}: CreateScheduleSheetProps) {
  const showToast = useToastStore((state) => state.show);

  const [start, setStart] = useState<Date | null>(null);
  const [end, setEnd] = useState<Date | null>(null);
  const [title, setTitle] = useState("");
  const [detail, setDetail] = useState("");
  const [category, setCategory] = useState<ScheduleCategory | null>(null);
  const [relatedId, setRelatedId] = useState<number | null>(null);
  const [place, setPlace] = useState("");
  const [participantIds, setParticipantIds] = useState<number[]>([]);
  const [related, setRelated] = useState<ScheduleRelatedData | null>(null);
  const [pickerTarget, setPickerTarget] = useState<"start" | "end" | null>(
    null
  );
  const [relatedPickerOpen, setRelatedPickerOpen] = useState(false);
  const [participantPickerOpen, setParticipantPickerOpen] = useState(false);
  const [saving, setSaving] = useState(false);

  // 打开时初始化表单：编辑模式回填；创建模式默认当日当前时间（精确到分钟）
  useEffect(() => {
    if (!visible) return;
    if (editing) {
      setStart(parseItemDate(editing.date, editing.start_time));
      setEnd(
        editing.end_time
          ? parseItemDate(editing.date, editing.end_time)
          : null
      );
      setTitle(editing.title ?? "");
      setDetail(editing.detail ?? "");
      setCategory(editing.category);
      setRelatedId(editing.related_id);
      setPlace(editing.place ?? "");
      setParticipantIds(editing.participant_ids);
    } else {
      setStart(defaultStart ?? new Date());
      setEnd(null);
      setTitle("");
      setDetail("");
      setCategory(null);
      setRelatedId(null);
      setPlace("");
      setParticipantIds([]);
    }
    setRelated(null);
    fetchScheduleRelated()
      .then(setRelated)
      .catch(() => {
        // 候选数据加载失败不阻塞表单（关联/同胞列表留空）
      });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [visible]);

  // 当前分类对应的关联候选（旅行→旅程 / 约会→约定）
  const relatedItems = useMemo(() => {
    if (category === "travel") return related?.trips ?? [];
    if (category === "date") return related?.agreements ?? [];
    return [];
  }, [category, related]);

  const handleCategoryChange = (value: ScheduleCategory) => {
    // 再点一次取消选择；切换分类时清空已选关联项
    setCategory((prev) => (prev === value ? null : value));
    setRelatedId(null);
  };

  // 已选参与者完整信息（id → 头像/昵称，用于表单回显）
  const selectedParticipants = useMemo(
    () =>
      participantIds
        .map((id) => (related?.comrades ?? []).find((c) => c.id === id))
        .filter((c): c is NonNullable<typeof c> => c != null),
    [participantIds, related]
  );

  // 已选关联项的 label（回显用）
  const selectedRelated = useMemo(
    () => relatedItems.find((r) => r.id === relatedId) ?? null,
    [relatedItems, relatedId]
  );

  const handleSave = async () => {
    if (!start) {
      showToast("请选择日程开始时间", "error");
      return;
    }
    if (end && end.getTime() <= start.getTime()) {
      showToast("结束时间需晚于开始时间", "error");
      return;
    }
    const relatedType: ScheduleRelatedType | null =
      category === "travel" && relatedId != null
        ? "trip"
        : category === "date" && relatedId != null
          ? "agreement"
          : null;
    const payload = {
      date: toDateKey(start),
      start_time: formatHHmm(start),
      end_time: end ? formatHHmm(end) : null,
      title: title.trim() || null,
      detail: detail.trim() || null,
      category,
      related_type: relatedType,
      related_id: relatedType ? relatedId : null,
      place: place.trim() || null,
      participant_ids: participantIds,
      source: editing?.source ?? ("form" as const),
    };
    setSaving(true);
    try {
      if (editing) {
        await updateSchedule(editing.id, payload);
        showToast("日程已保存", "success");
      } else {
        await createSchedule(payload);
        showToast("日程创建成功", "success");
      }
      onSaved();
      onClose();
    } catch (err) {
      showToast(err instanceof Error ? err.message : "保存失败", "error");
    } finally {
      setSaving(false);
    }
  };

  return (
    <BottomSheet
      visible={visible}
      onClose={onClose}
      title={editing ? "编辑日程" : "创建我的日程"}
      heightClass="h-[75vh]"
    >
      <div className="flex-1 min-h-0 overflow-y-auto scrollbar-hide px-5 py-4 space-y-5">
        {/* 第一项：日程时间（必填） */}
        <div>
          <div className="flex items-center">
            <span className="text-sm font-medium text-gray-700">日程时间</span>
            <span className="ml-0.5 text-red-500">*</span>
          </div>
          <div className="mt-2 flex gap-2">
            <button
              type="button"
              onClick={() => setPickerTarget("start")}
              className={TIME_CHIP}
            >
              {start ? (
                formatDateTimeCn(start)
              ) : (
                <span className="text-gray-400">开始时间</span>
              )}
            </button>
            <button
              type="button"
              onClick={() => setPickerTarget("end")}
              className={cn(TIME_CHIP, !end && "text-gray-400")}
            >
              {end ? (
                <span className="flex items-center justify-between">
                  <span>{formatDateTimeCn(end)}</span>
                  <span
                    role="button"
                    aria-label="清除结束时间"
                    onClick={(e) => {
                      e.stopPropagation();
                      setEnd(null);
                    }}
                    className="ml-2 text-gray-300 hover:text-gray-400"
                  >
                    ×
                  </span>
                </span>
              ) : (
                "结束时间（选填）"
              )}
            </button>
          </div>
        </div>

        {/* 第二项：日程标题（选填） */}
        <div>
          <div className="text-sm font-medium text-gray-700">日程标题</div>
          <input
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            placeholder="给你的旅程来个标题！"
            className={cn(TEXT_INPUT, "mt-2")}
          />
        </div>

        {/* 第三项：日程详情（至少 5 行，超出滚动） */}
        <div>
          <div className="text-sm font-medium text-gray-700">日程详情</div>
          <textarea
            value={detail}
            onChange={(e) => setDetail(e.target.value)}
            rows={5}
            placeholder="不知道做点什么，但至少先写下来趴！"
            className={cn(
              TEXT_INPUT,
              "mt-2 resize-none leading-relaxed overflow-y-auto"
            )}
          />
        </div>

        {/* 第四项：日程分类 */}
        <div>
          <div className="text-sm font-medium text-gray-700">日程分类</div>
          <div className="mt-2 flex flex-wrap gap-2">
            {SCHEDULE_CATEGORIES.map((c) => (
              <button
                key={c.value}
                type="button"
                onClick={() => handleCategoryChange(c.value)}
                className={cn(
                  CHIP,
                  category === c.value ? CHIP_ACTIVE : CHIP_IDLE
                )}
              >
                {c.label}
              </button>
            ))}
          </div>
        </div>

        {/* 第五项（条件）：旅行→关联旅程 / 约会→关联约定，搜索式选择 */}
        {category === "travel" || category === "date" ? (
          <div>
            <div className="text-sm font-medium text-gray-700">
              {category === "travel" ? "关联旅程" : "关联约定"}
            </div>
            <button
              type="button"
              onClick={() => setRelatedPickerOpen(true)}
              className={cn(PICK_TRIGGER, "mt-2", !selectedRelated && "text-gray-400")}
            >
              {selectedRelated ? (
                <span className="flex items-center justify-between">
                  <span className="text-gray-800 truncate">{selectedRelated.label}</span>
                  <span
                    role="button"
                    aria-label="清除关联项"
                    onClick={(e) => {
                      e.stopPropagation();
                      setRelatedId(null);
                    }}
                    className="ml-2 text-gray-300 hover:text-gray-400"
                  >
                    ×
                  </span>
                </span>
              ) : (
                category === "travel" ? "选择关联旅程" : "选择关联约定"
              )}
            </button>
          </div>
        ) : null}

        {/* 添加地点 */}
        <div>
          <div className="text-sm font-medium text-gray-700">添加地点</div>
          <input
            value={place}
            onChange={(e) => setPlace(e.target.value)}
            placeholder="添加地点"
            className={cn(TEXT_INPUT, "mt-2")}
          />
        </div>

        {/* 添加日程参与的同胞：搜索式多选，已选显示头像上、@昵称下 */}
        <div>
          <div className="text-sm font-medium text-gray-700">
            添加日程参与的同胞
          </div>
          {selectedParticipants.length > 0 && (
            <div className="mt-2.5 flex flex-wrap gap-x-3 gap-y-2">
              {selectedParticipants.map((p) => (
                <button
                  key={p.id}
                  type="button"
                  onClick={() =>
                    setParticipantIds((prev) => prev.filter((x) => x !== p.id))
                  }
                  className="flex flex-col items-center w-14"
                  aria-label={`移除 ${p.nickname}`}
                >
                  <img
                    src={p.avatar}
                    alt=""
                    className="w-10 h-10 rounded-full object-cover bg-gray-100"
                  />
                  <span
                    className={cn(
                      "mt-1 max-w-full text-xs truncate",
                      PINK_TEXT
                    )}
                  >
                    @{p.nickname}
                  </span>
                </button>
              ))}
            </div>
          )}
          <button
            type="button"
            onClick={() => setParticipantPickerOpen(true)}
            className={cn(PICK_TRIGGER, "mt-2", selectedParticipants.length > 0 && "text-gray-400")}
          >
            {selectedParticipants.length > 0 ? "继续添加参与的同胞" : "选择参与的同胞"}
          </button>
        </div>
      </div>

      {/* 底部按钮：取消 / 创建（编辑模式为保存） */}
      <div className="flex gap-3 px-5 pt-2 pb-[calc(1.25rem+env(safe-area-inset-bottom))] flex-shrink-0">
        <button type="button" onClick={onClose} className={SHEET_BTN_CANCEL}>
          取消
        </button>
        <button
          type="button"
          onClick={handleSave}
          disabled={saving}
          className={cn(SHEET_BTN_CONFIRM, saving && "opacity-60")}
        >
          {editing ? "保存" : "创建"}
        </button>
      </div>

      {/* 时间选择器（开始/结束共用，精确到分钟） */}
      <DateTimePickerSheet
        visible={pickerTarget != null}
        value={pickerTarget === "start" ? start : end}
        onConfirm={(d) => {
          if (pickerTarget === "start") setStart(d);
          else setEnd(d);
          setPickerTarget(null);
        }}
        onClose={() => setPickerTarget(null)}
      />

      {/* 关联旅程 / 约定选择器：单选，未搜索时默认展示前 3 条 */}
      <RelatedPickerSheet
        visible={relatedPickerOpen}
        title={category === "travel" ? "选择关联旅程" : "选择关联约定"}
        placeholder={category === "travel" ? "搜索旅程" : "搜索约定"}
        options={relatedItems}
        defaultLimit={3}
        onConfirm={(ids) => {
          setRelatedId(ids[0] ?? null);
          setRelatedPickerOpen(false);
        }}
        onClose={() => setRelatedPickerOpen(false)}
      />

      {/* 参与同胞选择器：多选 */}
      <RelatedPickerSheet
        visible={participantPickerOpen}
        title="选择参与的同胞"
        placeholder="搜索昵称"
        options={(related?.comrades ?? []).map((c) => ({
          id: c.id,
          label: c.nickname,
          avatar: c.avatar,
        }))}
        multiple
        selectedIds={participantIds}
        onConfirm={(ids) => {
          setParticipantIds(ids);
          setParticipantPickerOpen(false);
        }}
        onClose={() => setParticipantPickerOpen(false)}
      />
    </BottomSheet>
  );
}
