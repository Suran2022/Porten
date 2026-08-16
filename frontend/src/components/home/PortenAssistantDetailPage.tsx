import { useEffect, useState } from "react";
import { ArrowLeft, Loader2, X } from "lucide-react";
import { cn } from "@/lib/utils";
import {
  ApiError,
  TimeoutError,
  fetchAssistantArticle,
  fetchAssistantArticles,
  markAssistantArticleRead,
} from "@/lib/api";
import { AssistantArticleDetail, AssistantArticleListItem } from "@/types/partner";
import { Markdown } from "@/components/common/Markdown";

interface PortenAssistantDetailPageProps {
  visible: boolean;
  assistantId: string | null;
  assistantName?: string;
  onClose: () => void;
  /** PC 弹窗形态：顶部用右对齐关闭图标替代返回图标 */
  closeMode?: boolean;
}

function formatPublishTime(iso: string): string {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "";
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

function ArticleListCard({
  article,
  onClick,
}: {
  article: AssistantArticleListItem;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="w-full text-left px-4 py-4 active:bg-gray-50 transition-colors"
    >
      <div className="flex items-start gap-3">
        <div className="flex-1 min-w-0">
          <h3 className="text-base font-semibold text-gray-900 leading-snug">
            {article.title}
          </h3>
          {article.summary ? (
            <p className="mt-2 text-sm text-gray-600 leading-[1.7] line-clamp-3">
              {article.summary}
            </p>
          ) : null}
          <div className="mt-3 flex items-center justify-between text-xs text-gray-400">
            <span>{article.publisher || "Porten 官方"}</span>
            <span>{formatPublishTime(article.publish_time)}</span>
          </div>
        </div>
        {article.is_read ? null : (
          <span
            aria-label="未读"
            className="flex-shrink-0 mt-1.5 w-2 h-2 rounded-full bg-red-500"
          />
        )}
      </div>
    </button>
  );
}

export function PortenAssistantDetailPage({
  visible,
  assistantId,
  assistantName,
  onClose,
  closeMode = false,
}: PortenAssistantDetailPageProps) {
  const [shouldRender, setShouldRender] = useState(false);
  const [isEntering, setIsEntering] = useState(false);

  const [articles, setArticles] = useState<AssistantArticleListItem[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string>("");

  const [openArticleId, setOpenArticleId] = useState<number | null>(null);
  const [articleDetail, setArticleDetail] = useState<AssistantArticleDetail | null>(
    null
  );
  const [articleLoading, setArticleLoading] = useState(false);
  const [articleError, setArticleError] = useState<string>("");

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

  // 打开助手详情时拉取文章列表
  useEffect(() => {
    if (!visible || !assistantId) return;
    let cancelled = false;
    setLoading(true);
    setError("");
    setArticles([]);
    setOpenArticleId(null);
    setArticleDetail(null);
    fetchAssistantArticles(assistantId)
      .then((res) => {
        if (cancelled) return;
        setArticles(res.articles);
      })
      .catch((e) => {
        if (cancelled) return;
        if (e instanceof TimeoutError || e instanceof ApiError) {
          setError("响应超时，请稍后重试");
        } else {
          setError("响应超时，请稍后重试");
        }
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [visible, assistantId]);

  // 打开文章详情时拉取 markdown 正文 + 自动标记已读
  useEffect(() => {
    if (!assistantId || openArticleId == null) {
      setArticleDetail(null);
      setArticleError("");
      return;
    }
    let cancelled = false;
    setArticleLoading(true);
    setArticleError("");
    setArticleDetail(null);
    fetchAssistantArticle(assistantId, openArticleId)
      .then((res) => {
        if (cancelled) return;
        setArticleDetail(res);
        // 静默标记已读，失败不影响阅读
        markAssistantArticleRead(assistantId, openArticleId).catch(() => {});
      })
      .catch((e) => {
        if (cancelled) return;
        if (e instanceof TimeoutError || e instanceof ApiError) {
          setArticleError("响应超时，请稍后重试");
        } else {
          setArticleError("响应超时，请稍后重试");
        }
      })
      .finally(() => {
        if (!cancelled) setArticleLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [assistantId, openArticleId]);

  if (!shouldRender) return null;

  return (
    <>
      {/* 文章列表 */}
      <div
        className={cn(
          "fixed inset-0 z-[75] bg-white flex flex-col transition-transform duration-300 ease-[cubic-bezier(0.25,0.1,0.25,1)]",
          isEntering ? "translate-x-0" : "translate-x-full"
        )}
        onTransitionEnd={handleTransitionEnd}
      >
        <div className="flex-shrink-0 flex items-center px-4 pt-[max(0.75rem,env(safe-area-inset-top))] pb-3 bg-white z-10">
          {closeMode ? (
            <>
              <h1 className="flex-1 text-left text-base font-medium text-gray-900">
                {assistantName || "助手"}
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
                {assistantName || "助手"}
              </h1>
            </>
          )}
        </div>

        <div className="flex-1 overflow-y-auto">
          {error ? (
            <div className="flex items-center justify-center py-16 px-6">
              <p className="text-sm text-gray-400 text-center">{error}</p>
            </div>
          ) : loading ? (
            <div className="flex items-center justify-center py-16 px-6 gap-2">
              <Loader2 className="w-4 h-4 animate-spin text-gray-300" />
              <p className="text-sm text-gray-400 text-center">加载中…</p>
            </div>
          ) : articles.length === 0 ? (
            <div className="flex items-center justify-center py-16 px-6">
              <p className="text-sm text-gray-400 text-center">暂无文章</p>
            </div>
          ) : (
            <div>
              {articles.map((a) => (
                <ArticleListCard
                  key={a.id}
                  article={a}
                  onClick={() => setOpenArticleId(a.id)}
                />
              ))}
            </div>
          )}
        </div>
      </div>

      {/* 文章详情（markdown 渲染），z 比列表高一层 */}
      <ArticleDetailView
        open={openArticleId != null}
        title={articleDetail?.title}
        publisher={articleDetail?.publisher}
        publishTime={articleDetail?.publish_time}
        content={articleDetail?.content}
        loading={articleLoading}
        error={articleError}
        onBack={() => setOpenArticleId(null)}
      />
    </>
  );
}

interface ArticleDetailViewProps {
  open: boolean;
  title?: string;
  publisher?: string;
  publishTime?: string;
  content?: string;
  loading: boolean;
  error: string;
  onBack: () => void;
}

function ArticleDetailView({
  open,
  title,
  publisher,
  publishTime,
  content,
  loading,
  error,
  onBack,
}: ArticleDetailViewProps) {
  const [shouldRender, setShouldRender] = useState(false);
  const [isEntering, setIsEntering] = useState(false);

  useEffect(() => {
    if (open) {
      setShouldRender(true);
      requestAnimationFrame(() => {
        requestAnimationFrame(() => setIsEntering(true));
      });
    } else {
      setIsEntering(false);
    }
  }, [open]);

  const handleTransitionEnd = () => {
    if (!open) {
      setShouldRender(false);
    }
  };

  if (!shouldRender) return null;

  return (
    <div
      className={cn(
        "fixed inset-0 z-[80] bg-white flex flex-col transition-transform duration-300 ease-[cubic-bezier(0.25,0.1,0.25,1)]",
        isEntering ? "translate-x-0" : "translate-x-full"
      )}
      onTransitionEnd={handleTransitionEnd}
    >
      <div className="flex-shrink-0 flex items-center px-4 pt-[max(0.75rem,env(safe-area-inset-top))] pb-3 bg-white z-10">
        <button
          type="button"
          onClick={onBack}
          className="w-8 h-8 flex items-center justify-center -ml-2 active:opacity-60 transition-opacity"
          aria-label="返回"
        >
          <ArrowLeft className="w-5 h-5 text-gray-900" strokeWidth={1.5} />
        </button>
        <h1 className="flex-1 text-center text-base font-medium text-gray-900 -mr-6">
          {title || "文章"}
        </h1>
      </div>

      <div className="flex-1 overflow-y-auto">
        {loading ? (
          <div className="flex items-center justify-center py-16 px-6 gap-2">
            <Loader2 className="w-4 h-4 animate-spin text-gray-300" />
            <p className="text-sm text-gray-400 text-center">加载中…</p>
          </div>
        ) : error ? (
          <div className="flex items-center justify-center py-16 px-6">
            <p className="text-sm text-gray-400 text-center">{error}</p>
          </div>
        ) : (
          <article className="px-5 py-5">
            {title ? (
              <h1 className="text-[22px] font-semibold text-gray-900 leading-snug">
                {title}
              </h1>
            ) : null}
            <div className="mt-2.5 flex items-center justify-between text-xs text-gray-400">
              <span>{publisher || "Porten 官方"}</span>
              {publishTime ? <span>{formatPublishTime(publishTime)}</span> : null}
            </div>
            {content ? (
              <div className="mt-5">
                <Markdown content={content} />
              </div>
            ) : (
              <p className="mt-4 text-sm text-gray-400">暂无内容</p>
            )}
          </article>
        )}
      </div>
    </div>
  );
}
