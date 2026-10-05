import { useEffect, useMemo, useState } from "react";
import {
  BottomSheet,
  SHEET_BTN_CANCEL,
  SHEET_BTN_CONFIRM,
} from "@/components/trip/BottomSheet";
import { cn } from "@/lib/utils";

/** 选择器候选：有 avatar 的显示头像行，否则显示纯文本行。 */
export interface PickerOption {
  id: number;
  label: string;
  avatar?: string;
}

interface RelatedPickerSheetProps {
  visible: boolean;
  title: string;
  /** 搜索框占位提示 */
  placeholder?: string;
  options: PickerOption[];
  /** 多选（参与者）/ 单选点击即确认（关联旅程、约定） */
  multiple?: boolean;
  /** 打开时已选中的 id（多选回显勾选态） */
  selectedIds?: number[];
  /** 未搜索时默认展示前 N 条（缺省全部展示） */
  defaultLimit?: number;
  onConfirm: (ids: number[]) => void;
  onClose: () => void;
}

/** 列表行：头像（可选）+ 文本，选中时淡粉底。 */
function OptionRow({
  option,
  selected,
  onClick,
}: {
  option: PickerOption;
  selected: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={cn(
        "w-full flex items-center gap-3 px-3 py-2.5 rounded-xl transition-colors text-left",
        selected ? "bg-[#FBE3EA]" : "active:bg-gray-50"
      )}
    >
      {option.avatar ? (
        <img
          src={option.avatar}
          alt=""
          className="w-9 h-9 rounded-full object-cover flex-shrink-0 bg-gray-100"
        />
      ) : null}
      <span className="flex-1 min-w-0 text-sm text-gray-800 truncate">
        {option.label}
      </span>
      <span
        className={cn(
          "w-5 h-5 rounded-full flex-shrink-0 flex items-center justify-center text-[11px] transition-colors",
          selected
            ? "bg-[#F7C5D0] text-white"
            : "border border-gray-200 text-transparent"
        )}
      >
        ✓
      </span>
    </button>
  );
}

/**
 * 搜索式选择底部弹层（与时间选择器同一弹层范式）：
 * 顶部搜索框过滤候选，未搜索时默认只展示前 defaultLimit 条，
 * 支持单选（点击即确认）与多选（勾选后统一确认）两种模式。
 */
export function RelatedPickerSheet({
  visible,
  title,
  placeholder,
  options,
  multiple = false,
  selectedIds = [],
  defaultLimit,
  onConfirm,
  onClose,
}: RelatedPickerSheetProps) {
  const [query, setQuery] = useState("");
  const [picked, setPicked] = useState<number[]>(selectedIds);

  // 打开时重置搜索词并回显已选
  useEffect(() => {
    if (visible) {
      setQuery("");
      setPicked(selectedIds);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [visible]);

  // 搜索过滤；未搜索时按 defaultLimit 截断
  const visibleOptions = useMemo(() => {
    const q = query.trim();
    const filtered = q
      ? options.filter((o) => o.label.toLowerCase().includes(q.toLowerCase()))
      : options;
    return !q && defaultLimit != null ? filtered.slice(0, defaultLimit) : filtered;
  }, [options, query, defaultLimit]);

  const togglePick = (id: number) => {
    setPicked((prev) =>
      prev.includes(id) ? prev.filter((p) => p !== id) : [...prev, id]
    );
  };

  return (
    <BottomSheet visible={visible} onClose={onClose} title={title}>
      {/* 搜索框：与表单文本输入同族的细小浅灰圆角样式 */}
      <div className="px-5 pt-1 pb-2 flex-shrink-0">
        <input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder={placeholder ?? "搜索"}
          className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm text-gray-800 placeholder:text-gray-300 outline-none focus:border-gray-300 transition-colors"
        />
      </div>

      {/* 候选列表 */}
      <div className="flex-1 min-h-0 overflow-y-auto scrollbar-hide px-3 pb-2">
        {visibleOptions.length === 0 ? (
          <div className="py-10 text-center text-sm text-gray-300">
            没有匹配的结果
          </div>
        ) : (
          visibleOptions.map((o) => (
            <OptionRow
              key={o.id}
              option={o}
              selected={picked.includes(o.id)}
              onClick={() => {
                if (multiple) {
                  togglePick(o.id);
                } else {
                  onConfirm([o.id]);
                }
              }}
            />
          ))
        )}
      </div>

      {/* 多选底部按钮；单选（点击即确认）不显示 */}
      {multiple && (
        <div className="flex gap-3 px-5 pt-1 pb-[calc(1.25rem+env(safe-area-inset-bottom))] flex-shrink-0">
          <button type="button" onClick={onClose} className={SHEET_BTN_CANCEL}>
            取消
          </button>
          <button
            type="button"
            onClick={() => onConfirm(picked)}
            className={SHEET_BTN_CONFIRM}
          >
            确定
          </button>
        </div>
      )}
    </BottomSheet>
  );
}
