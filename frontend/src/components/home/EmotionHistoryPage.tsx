import { useEffect, useRef, useState } from "react";
import { ArrowLeft } from "lucide-react";
import { cn } from "@/lib/utils";
import { SystemToast, ToastType } from "@/components/SystemToast";
import { fetchEmotionDiaryHistory } from "@/lib/api";
import {
  EmotionDiary,
  MOOD_OPTIONS,
  getMoodOption,
} from "@/types/emotionDiary";

interface EmotionHistoryPageProps {
  visible: boolean;
  onClose: () => void;
  cisMode: boolean;
}

const TOAST_AUTO_HIDE_MS = 1500;

export function EmotionHistoryPage({
  visible,
  onClose,
  cisMode,
}: EmotionHistoryPageProps) {
  const [shouldRender, setShouldRender] = useState(false);
  const [isEntering, setIsEntering] = useState(false);

  const [items, setItems] = useState<EmotionDiary[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(false);
  const [hasMore, setHasMore] = useState(false);
  const [nextCursor, setNextCursor] = useState<number | null>(null);

  const [toastVisible, setToastVisible] = useState(false);
  const [toastType, setToastType] = useState<ToastType>("loading");
  const [toastText, setToastText] = useState("");
  const toastHideTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    if (visible) {
      setShouldRender(true);
      requestAnimationFrame(() => {
        requestAnimationFrame(() => setIsEntering(true));
      });
    } else {
      setIsEntering(false);
    }
  }, [visible]);

  const handleTransitionEnd = () => {
    if (!visible) setShouldRender(false);
  };

  useEffect(() => {
    if (visible) {
      void loadHistory(true);
    }
    return () => {
      if (toastHideTimerRef.current) clearTimeout(toastHideTimerRef.current);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [visible]);

  const showToast = (type: ToastType, text: string) => {
    if (toastHideTimerRef.current) clearTimeout(toastHideTimerRef.current);
    setToastType(type);
    setToastText(text);
    setToastVisible(true);
    toastHideTimerRef.current = setTimeout(() => {
      setToastVisible(false);
      toastHideTimerRef.current = null;
    }, TOAST_AUTO_HIDE_MS);
  };

  async function loadHistory(reset = false) {
    setLoading(true);
    try {
      const data = await fetchEmotionDiaryHistory(
        reset ? undefined : nextCursor ?? undefined
      );
      setItems((prev) => (reset ? data.items : [...prev, ...data.items]));
      setTotal(data.total);
      setHasMore(data.items.length >= 50);
      setNextCursor(
        data.items.length > 0 ? data.items[data.items.length - 1].id : null
      );
    } catch (err) {
      showToast(
        "error",
        err instanceof Error ? err.message : "加载失败"
      );
    } finally {
      setLoading(false);
    }
  }

  if (!shouldRender) return null;

  return (
    <div
      className={cn(
        "fixed inset-0 z-[78] flex flex-col transition-transform duration-300 ease-[cubic-bezier(0.25,0.1,0.25,1)]",
        cisMode ? "bg-[#fafafa]" : "bg-[#f7f7f7]",
        isEntering ? "translate-x-0" : "translate-x-full"
      )}
      onTransitionEnd={handleTransitionEnd}
    >
      {/* Top bar: 复用通用（返回 / 标题居中 / 右侧空） */}
      <header className="flex-shrink-0 flex items-center px-4 pt-[max(0.75rem,env(safe-area-inset-top))] pb-3 z-10 bg-white border-b border-gray-100">
        <button
          type="button"
          onClick={onClose}
          className="w-8 h-8 flex items-center justify-center -ml-2"
          aria-label="返回"
        >
          <ArrowLeft className="w-5 h-5 text-gray-900" strokeWidth={1.5} />
        </button>
        <h1 className="flex-1 text-center text-base font-medium text-gray-900">
          历史情绪
        </h1>
        <div className="w-8" />
      </header>

      <div className="flex-1 overflow-y-auto px-4 py-4">
        {items.length === 0 && !loading ? (
          <div className="py-20 text-center text-sm text-gray-400">
            还没有历史记录
          </div>
        ) : (
          <div className="space-y-3">
            {items.map((d) => (
              <HistoryCard
                key={d.id}
                diary={d}
                cisMode={cisMode}
              />
            ))}
            {hasMore && items.length > 0 && (
              <button
                type="button"
                onClick={() => loadHistory(false)}
                disabled={loading}
                className="w-full py-3 text-sm text-gray-400"
              >
                {loading ? "加载中..." : "加载更多"}
              </button>
            )}
            {!hasMore && items.length > 0 && items.length === total && (
              <div className="py-4 text-center text-[11px] text-gray-300">
                共 {total} 条记录
              </div>
            )}
          </div>
        )}
      </div>

      <SystemToast visible={toastVisible} type={toastType} text={toastText} />
    </div>
  );
}

function HistoryCard({
  diary,
  cisMode,
}: {
  diary: EmotionDiary;
  cisMode: boolean;
}) {
  const moodOpt = getMoodOption(diary.mood);
  return (
    <div
      className={cn(
        "rounded-2xl bg-white p-4",
        cisMode ? "border border-gray-100" : "border border-gray-100"
      )}
    >
      <div className="flex items-center justify-between mb-2">
        <span className="text-[11px] text-gray-400">
          {formatTime(diary.created_at)}
        </span>
        {diary.is_current ? (
          <span
            className={cn(
              "text-[10px] h-5 px-2 rounded-full inline-flex items-center",
              cisMode
                ? "bg-gray-900 text-white"
                : "bg-gradient-to-r from-[#5BCEFA] to-[#F5A9B8] text-white"
            )}
          >
            当前
          </span>
        ) : (
          <span className="text-[10px] h-5 px-2 rounded-full inline-flex items-center bg-gray-100 text-gray-500">
            历史
          </span>
        )}
      </div>
      <p className="text-[14px] text-gray-800 leading-7 whitespace-pre-wrap break-words">
        {diary.content}
      </p>
      {moodOpt && (
        <div className="mt-3 flex items-center gap-1.5 text-xs text-gray-500">
          <span>{moodOpt.emoji}</span>
          <span>{moodOpt.label}</span>
        </div>
      )}
    </div>
  );
}

function formatTime(iso: string): string {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "";
  const now = new Date();
  const sameDay =
    d.getFullYear() === now.getFullYear() &&
    d.getMonth() === now.getMonth() &&
    d.getDate() === now.getDate();
  const hh = String(d.getHours()).padStart(2, "0");
  const mm = String(d.getMinutes()).padStart(2, "0");
  if (sameDay) return `今天 ${hh}:${mm}`;
  const yyyy = d.getFullYear();
  const MM = String(d.getMonth() + 1).padStart(2, "0");
  const dd = String(d.getDate()).padStart(2, "0");
  return `${yyyy}-${MM}-${dd} ${hh}:${mm}`;
}
