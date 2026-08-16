import { useEffect, useMemo, useState } from "react";
import { ArrowLeft, X } from "lucide-react";
import { cn } from "@/lib/utils";
import {
  fetchAssistantArticles,
  fetchAssistants,
  ApiError,
  TimeoutError,
} from "@/lib/api";
import {
  AssistantArticleListItem,
  AssistantListItem,
  PortenAssistant,
} from "@/types/partner";
import { partnerName } from "@/data/partnerMock";

interface PortenPartnerPageProps {
  visible: boolean;
  onClose: () => void;
  /** PC 弹窗形态：顶部用右对齐关闭图标替代返回图标 */
  closeMode?: boolean;
  onAssistantClick: (assistantId: string, assistantName: string) => void;
}

/**
 * 助手头像：优先用图片；没有图片时回退到文字占位（名字第一个字）。
 */
function AssistantAvatar({
  src,
  name,
}: {
  src?: string | null;
  name: string;
}) {
  const first = name?.trim().charAt(0) || "?";
  if (src) {
    return (
      <img
        src={src}
        alt={name}
        className="w-12 h-12 rounded-full object-cover bg-gray-100 flex-shrink-0"
      />
    );
  }
  return (
    <div
      className="w-12 h-12 rounded-full bg-gradient-to-br from-[#F5A9B8] to-[#E48BA2] flex items-center justify-center text-white text-lg font-medium flex-shrink-0"
      aria-label={name}
    >
      {first}
    </div>
  );
}

/**
 * 取助手卡片预览文本：
 *   - 优先用「标题 + 概要前一部分」，概要为空时退回标题
 *   - 概要前一部分按首个换行 / 句号 / 问号 / 分号切分，30 字上限
 */
function previewText(article: AssistantArticleListItem | null): string {
  if (!article) return "";
  const summary = article.summary?.trim() ?? "";
  if (!summary) return article.title;
  const stopChars = ["\n", "。", "！", "?", "?", ";"];
  let cut = summary.length;
  for (const ch of stopChars) {
    const idx = summary.indexOf(ch);
    if (idx !== -1 && idx < cut) cut = idx;
  }
  const head = summary.slice(0, cut).trim();
  const clipped = head.length > 30 ? head.slice(0, 30) + "…" : head;
  return `${article.title}：${clipped}`;
}

function AssistantCard({
  item,
  onClick,
}: {
  item: AssistantListItem;
  onClick: () => void;
}) {
  const { assistant, latestArticle } = item;
  const preview = previewText(latestArticle);
  const unread = assistant.unread_count ?? 0;
  return (
    <button
      type="button"
      onClick={onClick}
      className="w-full flex items-center gap-3 px-4 py-3 bg-white active:bg-gray-50 transition-colors text-left"
    >
      <AssistantAvatar src={assistant.avatar} name={assistant.name} />

      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2">
          <h3 className="flex-1 min-w-0 text-base font-medium text-gray-900 truncate">
            {assistant.name}
          </h3>
          {unread > 0 ? (
            <span
              aria-label={`${unread} 条未读`}
              className={cn(
                "flex-shrink-0 h-[18px] px-1.5 min-w-[18px] rounded-full bg-red-500 text-white text-[11px] font-medium flex items-center justify-center",
                unread > 99 && "px-1.5"
              )}
            >
              {unread > 99 ? "99+" : unread}
            </span>
          ) : null}
        </div>
        {/* 有文章时显示「标题：概要前一部分」；无文章时下方留空 */}
        {preview ? (
          <p className="mt-0.5 text-sm text-gray-500 truncate">{preview}</p>
        ) : (
          <p className="mt-0.5 text-sm text-transparent select-none">{"\u00A0"}</p>
        )}
      </div>
    </button>
  );
}

export function PortenPartnerPage({
  visible,
  onClose,
  closeMode = false,
  onAssistantClick,
}: PortenPartnerPageProps) {
  const [shouldRender, setShouldRender] = useState(false);
  const [isEntering, setIsEntering] = useState(false);

  const [assistants, setAssistants] = useState<PortenAssistant[]>([]);
  const [articlesByAssistant, setArticlesByAssistant] = useState<
    Record<string, AssistantArticleListItem[]>
  >({});
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string>("");

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
    if (!visible) {
      setShouldRender(false);
    }
  };

  // 打开时拉取助手列表 + 每个助手下的最新文章
  useEffect(() => {
    if (!visible) return;
    let cancelled = false;
    setLoading(true);
    setError("");
    (async () => {
      try {
        const list = await fetchAssistants();
        if (cancelled) return;
        setAssistants(list);
        // 并行拉取每个助手的文章
        const all = await Promise.all(
          list.map((a) =>
            fetchAssistantArticles(a.id)
              .then((r) => ({ id: a.id, articles: r.articles }))
              .catch(() => ({ id: a.id, articles: [] }))
          )
        );
        if (cancelled) return;
        const map: Record<string, AssistantArticleListItem[]> = {};
        all.forEach((it) => (map[it.id] = it.articles));
        setArticlesByAssistant(map);
      } catch (e) {
        if (cancelled) return;
        if (e instanceof TimeoutError) setError("响应超时，请稍后重试");
        else if (e instanceof ApiError) setError("响应超时，请稍后重试");
        else setError("响应超时，请稍后重试");
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [visible]);

  const list: AssistantListItem[] = useMemo(
    () =>
      assistants.map((a) => ({
        assistant: a,
        latestArticle: articlesByAssistant[a.id]?.[0] ?? null,
      })),
    [assistants, articlesByAssistant]
  );

  if (!shouldRender) return null;

  return (
    <div
      className={cn(
        "fixed inset-0 z-[70] bg-white flex flex-col transition-transform duration-300 ease-[cubic-bezier(0.25,0.1,0.25,1)]",
        isEntering ? "translate-x-0" : "translate-x-full"
      )}
      onTransitionEnd={handleTransitionEnd}
    >
      {/* 通用顶部栏 */}
      <div className="flex-shrink-0 flex items-center px-4 pt-[max(0.75rem,env(safe-area-inset-top))] pb-3 bg-white z-10">
        {closeMode ? (
          <>
            <h1 className="flex-1 text-left text-base font-medium text-gray-900">
              {partnerName}
            </h1>
            <button
              type="button"
              onClick={onClose}
              className="w-8 h-8 flex items-center justify-center -mr-2 active:opacity-60 transition-opacity"
              aria-label="关闭"
            >
              <X className="w-5 h-5 text-gray-900" strokeWidth={1.8} />
            </button>
          </>
        ) : (
          <>
            <button
              type="button"
              onClick={onClose}
              className="w-8 h-8 flex items-center justify-center -ml-2 active:opacity-60 transition-opacity"
              aria-label="返回"
            >
              <ArrowLeft className="w-5 h-5 text-gray-900" strokeWidth={1.5} />
            </button>
            <h1 className="flex-1 text-center text-base font-medium text-gray-900 -mr-6">
              {partnerName}
            </h1>
          </>
        )}
      </div>

      {/* 助手列表 */}
      <div className="flex-1 overflow-y-auto">
        {error ? (
          <div className="flex items-center justify-center py-16 px-6">
            <p className="text-sm text-gray-400 text-center">{error}</p>
          </div>
        ) : loading && list.length === 0 ? (
          <div className="flex items-center justify-center py-16 px-6">
            <p className="text-sm text-gray-400 text-center">加载中…</p>
          </div>
        ) : list.length === 0 ? (
          <div className="flex items-center justify-center py-16 px-6">
            <p className="text-sm text-gray-400 text-center">暂无助手</p>
          </div>
        ) : (
          <div className="pb-2">
            {list.map((item) => (
              <AssistantCard
                key={item.assistant.id}
                item={item}
                onClick={() =>
                  onAssistantClick(item.assistant.id, item.assistant.name)
                }
              />
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
