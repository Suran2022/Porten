import { useEffect, useRef, useState } from "react";
import { ArrowLeft, History, Pencil } from "lucide-react";
import { cn } from "@/lib/utils";
import { SystemToast, ToastType } from "@/components/SystemToast";
import {
  createEmotionDiary,
  deleteEmotionDiary,
  fetchEmotionDiaryCurrent,
  fetchEmotionDiaryViewers,
  updateEmotionDiaryCurrent,
} from "@/lib/api";
import {
  EmotionDiary,
  EmotionDiaryViewer,
  MOOD_OPTIONS,
  getMoodOption,
  isCisGender,
} from "@/types/emotionDiary";
import { useAuthStore } from "@/store/authStore";
import { EmotionHistoryPage } from "./EmotionHistoryPage";

interface EmotionDiaryPageProps {
  visible: boolean;
  onClose: () => void;
}

const DEFAULT_AVATAR =
  "https://haowallpaper.com/link//common/file/previewFileImg/19197325717754752";
const TOAST_AUTO_HIDE_MS = 1500;
const MAX_CONTENT = 4000;

export function EmotionDiaryPage({ visible, onClose }: EmotionDiaryPageProps) {
  const { user, updateUser } = useAuthStore();
  const cisMode = isCisGender(user?.gender);

  // Page-level transition
  const [shouldRender, setShouldRender] = useState(false);
  const [isEntering, setIsEntering] = useState(false);

  // Data
  const [current, setCurrent] = useState<EmotionDiary | null>(null);
  const [loading, setLoading] = useState(false);

  // Edit form state
  const [isEditing, setIsEditing] = useState(false);
  const [draftMood, setDraftMood] = useState<string>("happy");
  const [draftContent, setDraftContent] = useState("");
  const [saving, setSaving] = useState(false);

  // Viewers (for current diary)
  const [viewers, setViewers] = useState<EmotionDiaryViewer[]>([]);
  const [viewerTotal, setViewerTotal] = useState(0);
  const [loadingViewers, setLoadingViewers] = useState(false);

  // History page
  const [historyVisible, setHistoryVisible] = useState(false);

  // Toast
  const [toastVisible, setToastVisible] = useState(false);
  const [toastType, setToastType] = useState<ToastType>("loading");
  const [toastText, setToastText] = useState("");
  const toastHideTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Page mount/unmount
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
      void loadCurrent();
    }
    return () => {
      if (toastHideTimerRef.current) clearTimeout(toastHideTimerRef.current);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [visible]);

  const showToast = (type: ToastType, text: string, autoHide = true) => {
    if (toastHideTimerRef.current) clearTimeout(toastHideTimerRef.current);
    setToastType(type);
    setToastText(text);
    setToastVisible(true);
    if (autoHide) {
      toastHideTimerRef.current = setTimeout(() => {
        setToastVisible(false);
        toastHideTimerRef.current = null;
      }, TOAST_AUTO_HIDE_MS);
    }
  };

  async function loadCurrent() {
    setLoading(true);
    try {
      const data = await fetchEmotionDiaryCurrent();
      setCurrent(data);
      if (data) {
        await loadViewers(data.id);
      } else {
        setViewers([]);
        setViewerTotal(0);
      }
    } catch (err) {
      showToast(
        "error",
        err instanceof Error ? err.message : "加载失败"
      );
    } finally {
      setLoading(false);
    }
  }

  async function loadViewers(diaryId: number) {
    setLoadingViewers(true);
    try {
      const data = await fetchEmotionDiaryViewers(diaryId);
      setViewers(data.items);
      setViewerTotal(data.total);
    } catch {
      setViewers([]);
      setViewerTotal(0);
    } finally {
      setLoadingViewers(false);
    }
  }

  function enterEdit() {
    if (!current) {
      setDraftMood("happy");
      setDraftContent("");
    } else {
      setDraftMood(current.mood);
      setDraftContent(current.content);
    }
    setIsEditing(true);
  }

  function cancelEdit() {
    setIsEditing(false);
  }

  async function handleSave() {
    const content = draftContent.trim();
    if (!content) {
      showToast("error", "请写下今天的心情");
      return;
    }
    if (content.length > MAX_CONTENT) {
      showToast("error", `内容最多 ${MAX_CONTENT} 字`);
      return;
    }
    setSaving(true);
    try {
      const diary = current
        ? await updateEmotionDiaryCurrent({
            content,
            mood: draftMood as EmotionDiary["mood"],
            is_public: current.is_public,
          })
        : await createEmotionDiary({
            content,
            mood: draftMood as EmotionDiary["mood"],
            is_public: true,
          });
      setCurrent(diary);
      setIsEditing(false);
      showToast("success", "已保存");
      // 同步个人中心"最新日记"+mood：直接更新 auth store，
      // 这样回到 ProfilePage 不需要再请求接口
      if (user) {
        updateUser({
          ...user,
          latestDiary: diary.content,
          mood: diary.mood,
        });
      }
      await loadViewers(diary.id);
    } catch (err) {
      showToast("error", err instanceof Error ? err.message : "保存失败");
    } finally {
      setSaving(false);
    }
  }

  async function handleDelete() {
    if (!current) return;
    if (!confirm("确定删除这条情绪日记？")) return;
    try {
      await deleteEmotionDiary(current.id);
      setCurrent(null);
      setViewers([]);
      setViewerTotal(0);
      setIsEditing(false);
      showToast("success", "已删除");
      // 清空个人中心"最新日记"+mood
      if (user) {
        updateUser({
          ...user,
          latestDiary: null,
          mood: null,
        });
      }
    } catch (err) {
      showToast("error", err instanceof Error ? err.message : "删除失败");
    }
  }

  if (!shouldRender) return null;

  const showEditForm = !current || isEditing;

  return (
    <div
      className={cn(
        "fixed inset-0 z-[68] flex flex-col transition-transform duration-300 ease-[cubic-bezier(0.25,0.1,0.25,1)]",
        cisMode ? "bg-[#fafafa]" : "bg-[#f7f7f7]",
        isEntering ? "translate-x-0" : "translate-x-full"
      )}
      onTransitionEnd={handleTransitionEnd}
    >
      {/* Top bar: back left, title center, history right */}
      <header
        className={cn(
          "flex-shrink-0 flex items-center px-4 pt-[max(0.75rem,env(safe-area-inset-top))] pb-3 z-10",
          cisMode
            ? "bg-white border-b border-gray-100"
            : "bg-white border-b border-gray-100"
        )}
      >
        <button
          type="button"
          onClick={onClose}
          className="w-8 h-8 flex items-center justify-center -ml-2"
          aria-label="退出"
        >
          <ArrowLeft className="w-5 h-5 text-gray-900" strokeWidth={1.5} />
        </button>
        <h1 className="flex-1 text-center text-base font-medium text-gray-900">
          情绪日记
        </h1>
        <button
          type="button"
          onClick={() => setHistoryVisible(true)}
          className="w-8 h-8 flex items-center justify-center -mr-2"
          aria-label="历史"
        >
          <History className="w-5 h-5 text-gray-900" strokeWidth={1.5} />
        </button>
      </header>

      {/* Main content area */}
      <div className="flex-1 overflow-y-auto">
        {loading ? (
          <div className="py-16 text-center text-sm text-gray-400">加载中...</div>
        ) : showEditForm ? (
          <EditForm
            cisMode={cisMode}
            mood={draftMood}
            content={draftContent}
            saving={saving}
            isFirstTime={!current}
            onChangeMood={setDraftMood}
            onChangeContent={setDraftContent}
            onSave={handleSave}
            onCancel={current ? cancelEdit : undefined}
          />
        ) : (
          <DiaryCard
            diary={current!}
            cisMode={cisMode}
            viewers={viewers}
            viewerTotal={viewerTotal}
            loadingViewers={loadingViewers}
            onEdit={enterEdit}
            onDelete={handleDelete}
          />
        )}
      </div>

      <SystemToast visible={toastVisible} type={toastType} text={toastText} />

      <EmotionHistoryPage
        visible={historyVisible}
        onClose={() => setHistoryVisible(false)}
        cisMode={cisMode}
      />
    </div>
  );
}

/* ====================== Mood button (左右结构 + 细微 body 渐变) ====================== */

function MoodButton({
  opt,
  active,
  cisMode,
  onClick,
}: {
  opt: { value: string; label: string; emoji: string };
  active: boolean;
  cisMode: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={cn(
        "h-10 px-3 rounded-full flex items-center justify-center gap-2 whitespace-nowrap transition-colors",
        active
          ? cisMode
            ? // 顺性别：中性黑→灰 渐变
              "text-white bg-gradient-to-r from-gray-800 to-gray-600"
            : // 跨性别：粉→蓝 渐变
              "text-white bg-gradient-to-r from-[#F5A9B8] to-[#5BCEFA]"
          : "text-gray-600 bg-white/60 border border-gray-200"
      )}
      style={
        active && !cisMode
          ? {
              // 细微 body 渐变（不只是纯色），用 inset shadow 制造更柔和的过渡
              boxShadow:
                "inset 0 0 0 1px rgba(255,255,255,0.4)",
            }
          : undefined
      }
    >
      <span className="text-lg leading-none">{opt.emoji}</span>
      <span className="text-sm">{opt.label}</span>
    </button>
  );
}

/* ====================== Edit form (未发布态 / 修改展开态) ====================== */

function EditForm({
  cisMode,
  mood,
  content,
  saving,
  isFirstTime,
  onChangeMood,
  onChangeContent,
  onSave,
  onCancel,
}: {
  cisMode: boolean;
  mood: string;
  content: string;
  saving: boolean;
  isFirstTime: boolean;
  onChangeMood: (v: string) => void;
  onChangeContent: (v: string) => void;
  onSave: () => void;
  onCancel?: () => void;
}) {
  return (
    <div className="px-4 py-5 space-y-5">
      {/* Mood tags: 左右结构（图标+文本水平），选中态用细微 body 渐变
          - 短标签（≤2 字）放 3 列网格，整齐排列
          - 长标签（>2 字，如"充满希望"）放最后一行，自动撑开不被挤压 */}
      <section>
        <p className="text-xs text-gray-500 mb-2.5">现在感觉…</p>
        <div className="grid grid-cols-3 gap-2.5">
          {MOOD_OPTIONS.filter((o) => o.label.length <= 2).map((opt) => {
            const active = mood === opt.value;
            return <MoodButton key={opt.value} opt={opt} active={active} cisMode={cisMode} onClick={() => onChangeMood(opt.value)} />;
          })}
        </div>
        {MOOD_OPTIONS.some((o) => o.label.length > 2) && (
          <div className="flex flex-wrap gap-2.5 mt-2.5">
            {MOOD_OPTIONS.filter((o) => o.label.length > 2).map((opt) => {
              const active = mood === opt.value;
              return <MoodButton key={opt.value} opt={opt} active={active} cisMode={cisMode} onClick={() => onChangeMood(opt.value)} />;
            })}
          </div>
        )}
      </section>

      {/* Content input: 灰色透明 */}
      <section>
        <p className="text-xs text-gray-500 mb-2.5">记录今天的心情</p>
        <textarea
          value={content}
          onChange={(e) => onChangeContent(e.target.value)}
          maxLength={MAX_CONTENT}
          placeholder="今天发生了什么？你的感受是什么？"
          rows={8}
          className="w-full px-4 py-3 bg-white/40 border border-gray-200 rounded-2xl text-[15px] text-gray-900 placeholder:text-gray-300 outline-none resize-none"
        />
        <div className="mt-1.5 text-right text-[11px] text-gray-400">
          {content.length}/{MAX_CONTENT}
        </div>
      </section>

      {/* Save button */}
      <div className="flex items-center gap-3">
        {onCancel && (
          <button
            type="button"
            onClick={onCancel}
            className="h-12 px-5 rounded-full text-sm font-medium text-gray-700 bg-white border border-gray-200"
          >
            取消
          </button>
        )}
        <button
          type="button"
          onClick={onSave}
          disabled={saving}
          className={cn(
            "flex-1 h-12 rounded-full text-base font-medium text-white transition-colors",
            saving
              ? "bg-gray-300"
              : cisMode
                ? "bg-gray-900 active:bg-gray-700"
                : "bg-gradient-to-r from-[#5BCEFA] to-[#F5A9B8] active:opacity-90"
          )}
        >
          {saving ? "保存中..." : isFirstTime ? "保存" : "保存修改"}
        </button>
      </div>
    </div>
  );
}

/* ====================== Diary card (已发布态) ====================== */

function DiaryCard({
  diary,
  cisMode,
  viewers,
  viewerTotal,
  loadingViewers,
  onEdit,
  onDelete,
}: {
  diary: EmotionDiary;
  cisMode: boolean;
  viewers: EmotionDiaryViewer[];
  viewerTotal: number;
  loadingViewers: boolean;
  onEdit: () => void;
  onDelete: () => void;
}) {
  const moodOpt = getMoodOption(diary.mood);
  return (
    <div className="px-4 py-5 space-y-4">
      <div
        className={cn(
          "rounded-2xl bg-white p-5 relative",
          cisMode ? "border border-gray-100" : "border border-gray-100"
        )}
      >
        {/* Mood chip + edit pencil row (top) */}
        <div className="flex items-center justify-between mb-3">
          {moodOpt ? (
            <span
              className={cn(
                "inline-flex items-center gap-1.5 h-7 px-3 rounded-full text-xs",
                cisMode
                  ? "bg-gray-100 text-gray-700"
                  : "bg-gradient-to-r from-[#F5A9B8]/15 to-[#5BCEFA]/15 text-gray-700"
              )}
            >
              <span>{moodOpt.emoji}</span>
              <span>现在 {moodOpt.label}</span>
            </span>
          ) : (
            <span />
          )}
          <button
            type="button"
            onClick={onEdit}
            className="w-8 h-8 flex items-center justify-center rounded-full text-gray-400 active:bg-gray-100"
            aria-label="修改"
          >
            <Pencil className="w-4 h-4" strokeWidth={1.6} />
          </button>
        </div>

        {/* Content */}
        <p className="text-[15px] text-gray-800 leading-7 whitespace-pre-wrap break-words">
          {diary.content}
        </p>

        {/* Footer: time + 修改按钮（右下角） */}
        <div className="mt-4 flex items-end justify-between">
          <span className="text-[11px] text-gray-400">
            {formatTime(diary.updated_at || diary.created_at)}
          </span>
          <button
            type="button"
            onClick={onEdit}
            className={cn(
              "h-8 px-4 rounded-full text-xs font-medium transition-colors",
              cisMode
                ? "bg-gray-900 text-white active:bg-gray-700"
                : "bg-gradient-to-r from-[#5BCEFA] to-[#F5A9B8] text-white active:opacity-90"
            )}
          >
            修改
          </button>
        </div>
      </div>

      {/* Viewers list: 上下结构（头像在上、昵称在下） */}
      <section
        className={cn(
          "rounded-2xl bg-white p-5",
          cisMode ? "border border-gray-100" : "border border-gray-100"
        )}
      >
        <div className="flex items-center justify-between mb-3">
          <h3 className="text-sm font-medium text-gray-900">
            谁看过这条
          </h3>
          <span className="text-xs text-gray-400">{viewerTotal} 人</span>
        </div>
        {loadingViewers ? (
          <div className="py-6 text-center text-sm text-gray-400">加载中...</div>
        ) : viewers.length === 0 ? (
          <div className="py-6 text-center text-sm text-gray-400">
            暂时还没有人查看
          </div>
        ) : (
          <div className="grid grid-cols-4 gap-y-4">
            {viewers.map((v) => (
              <div key={v.id} className="flex flex-col items-center">
                <img
                  src={v.avatar_url || DEFAULT_AVATAR}
                  alt={v.nickname}
                  className="w-12 h-12 rounded-full object-cover bg-gray-100 mb-1.5"
                />
                <span className="text-xs text-gray-700 text-center truncate w-full px-1">
                  {v.nickname}
                </span>
              </div>
            ))}
          </div>
        )}
        <div className="mt-4 pt-3 border-t border-gray-100 flex justify-end">
          <button
            type="button"
            onClick={onDelete}
            className="text-xs text-red-500 active:opacity-70"
          >
            删除这条日记
          </button>
        </div>
      </section>
    </div>
  );
}

/* ====================== Helpers ====================== */

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
