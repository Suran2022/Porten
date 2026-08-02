import { useEffect, useLayoutEffect, useMemo, useRef, useState } from "react";
import {
  ArrowLeft,
  Search as SearchIcon,
  UsersRound,
  Tent,
  FileText,
  BookOpen,
  Image as ImageIcon,
  Sparkles,
  X,
  Search,
} from "lucide-react";
import { cn } from "@/lib/utils";
import {
  globalSearch,
  TimeoutError,
  type SearchAllData,
  type SearchCampItem,
  type SearchCategoryData,
  type SearchCategoryKey,
  type SearchComradeItem,
  type SearchFileItem,
  type SearchImageItem,
  type SearchKnowledgeItem,
} from "@/lib/api";
import { CampAvatar } from "@/components/home/CampAvatar";

const SEARCH_ERROR_TEXT = "响应超时，请稍后重试";

interface SearchPageProps {
  visible: boolean;
  onClose: () => void;
}

interface CategoryDef {
  key: SearchCategoryKey;
  label: string;
  icon: typeof UsersRound;
  placeholder: string;
}

const CATEGORIES: CategoryDef[] = [
  { key: "all", label: "全部", icon: Sparkles, placeholder: "搜索同胞、营地、文件、知识、图片…" },
  { key: "comrade", label: "同胞", icon: UsersRound, placeholder: "搜索同胞昵称 / Porten 账号" },
  { key: "camp", label: "营地", icon: Tent, placeholder: "搜索营地名称 / 营地号" },
  { key: "file", label: "文件", icon: FileText, placeholder: "搜索文件名称…" },
  { key: "knowledge", label: "知识", icon: BookOpen, placeholder: "搜索文章 / 视频 / 分享标题…" },
  { key: "image", label: "图片", icon: ImageIcon, placeholder: "搜索图片描述…" },
];

const PER_CATEGORY_LIMIT = 20;

type AllData = SearchAllData;
type SingleData = SearchCategoryData;

function formatFileSize(bytes: number | null | undefined): string {
  if (!bytes || bytes <= 0) return "";
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
  return `${(bytes / 1024 / 1024 / 1024).toFixed(2)} GB`;
}

// ===== Row components =====

function ComradeRow({ item }: { item: SearchComradeItem }) {
  return (
    <div className="flex items-center gap-3 px-4 py-3 active:bg-gray-50 transition-colors">
      <CampAvatar src={item.avatar_url} name={item.nickname} size={44} />
      <div className="flex-1 min-w-0">
        <div className="text-sm text-gray-900 truncate">{item.nickname}</div>
        <div className="text-xs text-gray-400 truncate mt-0.5">
          Porten 账号：{item.porten_id}
        </div>
      </div>
    </div>
  );
}

function CampRow({ item }: { item: SearchCampItem }) {
  return (
    <div className="flex items-center gap-3 px-4 py-3 active:bg-gray-50 transition-colors">
      <CampAvatar src={item.avatar_url} name={item.name} size={44} />
      <div className="flex-1 min-w-0">
        <div className="text-sm text-gray-900 truncate">{item.name}</div>
        <div className="text-xs text-gray-400 truncate mt-0.5">
          {item.camp_id ? `${item.camp_id} · ` : ""}
          {item.member_count ?? 0} 位成员
        </div>
      </div>
    </div>
  );
}

function FileRow({ item }: { item: SearchFileItem }) {
  return (
    <div className="flex items-center gap-3 px-4 py-3 active:bg-gray-50 transition-colors">
      <div className="w-11 h-11 rounded-md bg-gray-100 flex items-center justify-center flex-shrink-0">
        <FileText className="w-5 h-5 text-gray-500" strokeWidth={1.5} />
      </div>
      <div className="flex-1 min-w-0">
        <div className="text-sm text-gray-900 truncate">{item.name}</div>
        <div className="text-xs text-gray-400 truncate mt-0.5">
          {item.uploader_nickname ? `${item.uploader_nickname} · ` : ""}
          {formatFileSize(item.size)}
        </div>
      </div>
    </div>
  );
}

function ImageRow({ item }: { item: SearchImageItem }) {
  return (
    <div className="flex items-center gap-3 px-4 py-3 active:bg-gray-50 transition-colors">
      <div className="w-11 h-11 rounded-md bg-gray-100 overflow-hidden flex-shrink-0">
        {item.url ? (
          <img
            src={item.url}
            alt={item.name}
            loading="lazy"
            className="w-full h-full object-cover"
          />
        ) : (
          <div className="w-full h-full flex items-center justify-center">
            <ImageIcon className="w-5 h-5 text-gray-400" strokeWidth={1.5} />
          </div>
        )}
      </div>
      <div className="flex-1 min-w-0">
        <div className="text-sm text-gray-900 truncate">{item.name}</div>
        <div className="text-xs text-gray-400 truncate mt-0.5">
          {item.uploader_nickname ? `${item.uploader_nickname} · ` : ""}
          {formatFileSize(item.size)}
        </div>
      </div>
    </div>
  );
}

function KnowledgeRow({ item }: { item: SearchKnowledgeItem }) {
  return (
    <div className="flex items-center gap-3 px-4 py-3 active:bg-gray-50 transition-colors">
      <div className="w-11 h-11 rounded-md bg-gray-100 flex items-center justify-center flex-shrink-0">
        <BookOpen className="w-5 h-5 text-gray-500" strokeWidth={1.5} />
      </div>
      <div className="flex-1 min-w-0">
        <div className="text-sm text-gray-900 truncate">{item.title}</div>
        {item.summary ? (
          <div className="text-xs text-gray-400 truncate mt-0.5">
            {item.summary}
          </div>
        ) : null}
      </div>
    </div>
  );
}

// ===== Section header =====

function SectionHeader({ label, count }: { label: string; count: number }) {
  return (
    <div className="px-4 pt-4 pb-1.5 flex items-baseline justify-between">
      <h3 className="text-sm font-medium text-gray-700">{label}</h3>
      {count > 0 ? (
        <span className="text-xs text-gray-400">{count} 个结果</span>
      ) : null}
    </div>
  );
}

function EmptyHint({ keyword, label }: { keyword: string; label: string }) {
  return (
    <div className="flex flex-col items-center justify-center px-6 pt-20 pb-10 text-center">
      <div className="w-16 h-16 rounded-2xl border-2 border-dashed border-gray-300 flex items-center justify-center mb-4">
        <Search className="w-7 h-7 text-gray-300" strokeWidth={1.5} />
      </div>
      {keyword ? (
        <>
          <p className="text-sm text-gray-500">
            在「{label}」中没找到与「{keyword}」相关的内容
          </p>
          <p className="text-xs text-gray-400 mt-2">换个关键词或切换分类试试</p>
        </>
      ) : (
        <>
          <p className="text-sm text-gray-500">在「{label}」下输入关键词开始搜索</p>
          <p className="text-xs text-gray-400 mt-2 leading-relaxed max-w-xs">
            搜索时会同时匹配昵称 / 营地 / 文件 / 文章中的关键词
          </p>
        </>
      )}
    </div>
  );
}

// ===== Main component =====

export function SearchPage({ visible, onClose }: SearchPageProps) {
  const [isEntering, setIsEntering] = useState(false);
  const [activeCategory, setActiveCategory] = useState<SearchCategoryKey>("all");
  const [keyword, setKeyword] = useState("");
  const [indicator, setIndicator] = useState<{ left: number; width: number }>({
    left: 0,
    width: 0,
  });
  const [allData, setAllData] = useState<AllData | null>(null);
  const [singleData, setSingleData] = useState<SingleData | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const inputRef = useRef<HTMLInputElement>(null);
  const closeTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const tabsScrollRef = useRef<HTMLDivElement>(null);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const tabButtonRefs = useRef<Record<SearchCategoryKey, HTMLButtonElement | null>>({
    all: null,
    comrade: null,
    camp: null,
    file: null,
    knowledge: null,
    image: null,
  });

  // 进场 / 离场动画（与 Porten 安全中心一致）
  useEffect(() => {
    if (visible) {
      if (closeTimerRef.current) {
        clearTimeout(closeTimerRef.current);
        closeTimerRef.current = null;
      }
      requestAnimationFrame(() => {
        requestAnimationFrame(() => setIsEntering(true));
      });
      const focusTimer = setTimeout(() => inputRef.current?.focus(), 320);
      return () => clearTimeout(focusTimer);
    }
    setIsEntering(false);
    closeTimerRef.current = setTimeout(() => {
      setKeyword("");
      setActiveCategory("all");
      setAllData(null);
      setSingleData(null);
      setError(null);
      setLoading(false);
    }, 320);
    return () => {
      if (closeTimerRef.current) {
        clearTimeout(closeTimerRef.current);
      }
    };
  }, [visible]);

  // 计算下划线 indicator 位置
  useLayoutEffect(() => {
    const btn = tabButtonRefs.current[activeCategory];
    const container = tabsScrollRef.current;
    if (!btn || !container) return;
    const containerRect = container.getBoundingClientRect();
    const btnRect = btn.getBoundingClientRect();
    const next = {
      left: btnRect.left - containerRect.left + container.scrollLeft,
      width: btnRect.width,
    };
    setIndicator(next);
    const targetScrollLeft =
      next.left + next.width / 2 - containerRect.width / 2;
    container.scrollTo({
      left: Math.max(0, targetScrollLeft),
      behavior: "smooth",
    });
  }, [activeCategory, visible]);

  // Debounced search: only when page is visible and keyword is meaningful
  useEffect(() => {
    if (!visible) return;
    if (debounceRef.current) {
      clearTimeout(debounceRef.current);
    }
    // If keyword is empty for the "all" view, do not call the API — show hints.
    if (!keyword.trim()) {
      setAllData(null);
      setSingleData(null);
      setError(null);
      setLoading(false);
      return;
    }
    setLoading(true);
    setError(null);
    debounceRef.current = setTimeout(async () => {
      try {
        const result = await globalSearch(keyword, activeCategory, PER_CATEGORY_LIMIT);
        if (activeCategory === "all") {
          setAllData(result as AllData);
        } else {
          setSingleData(result as SingleData);
        }
      } catch (e) {
        // 不向上层 / 用户暴露后端 message，统一提示"响应超时，请稍后重试"
        if (!(e instanceof TimeoutError)) {
          // eslint-disable-next-line no-console
          console.warn("[search] failed:", e);
        }
        setError(SEARCH_ERROR_TEXT);
        setAllData(null);
        setSingleData(null);
      } finally {
        setLoading(false);
      }
    }, 280);

    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    };
  }, [keyword, activeCategory, visible]);

  const activeDef = useMemo(
    () => CATEGORIES.find((c) => c.key === activeCategory) ?? CATEGORIES[0],
    [activeCategory]
  );

  const handleCategoryClick = (key: SearchCategoryKey) => {
    if (key === activeCategory) return;
    setActiveCategory(key);
  };

  const handleClear = () => {
    setKeyword("");
    inputRef.current?.focus();
  };

  // ===== Render content for the current view =====

  const renderAllContent = () => {
    if (loading) {
      return <SearchStatus text="正在搜索…" />;
    }
    if (error) {
      return <SearchStatus text={error} isError />;
    }
    if (!keyword.trim()) {
      return <EmptyHint keyword="" label={activeDef.label} />;
    }
    if (!allData) {
      return <EmptyHint keyword={keyword} label={activeDef.label} />;
    }
    const sections: Array<{
      key: SearchCategoryKey;
      label: string;
      count: number;
      children: React.ReactNode;
    }> = [
      {
        key: "comrade",
        label: "同胞",
        count: allData.comrade?.length ?? 0,
        children: (allData.comrade ?? []).map((it) => (
          <ComradeRow key={`c-${it.id}`} item={it} />
        )),
      },
      {
        key: "camp",
        label: "营地",
        count: allData.camp?.length ?? 0,
        children: (allData.camp ?? []).map((it) => (
          <CampRow key={`p-${it.id}`} item={it} />
        )),
      },
      {
        key: "file",
        label: "文件",
        count: allData.file?.length ?? 0,
        children: (allData.file ?? []).map((it) => (
          <FileRow key={`f-${it.id}`} item={it} />
        )),
      },
      {
        key: "knowledge",
        label: "知识",
        count: allData.knowledge?.length ?? 0,
        children: (allData.knowledge ?? []).map((it) => (
          <KnowledgeRow key={`k-${it.id}`} item={it} />
        )),
      },
      {
        key: "image",
        label: "图片",
        count: allData.image?.length ?? 0,
        children: (allData.image ?? []).map((it) => (
          <ImageRow key={`i-${it.id}`} item={it} />
        )),
      },
    ];

    const totalCount = sections.reduce((acc, s) => acc + s.count, 0);
    if (totalCount === 0) {
      return <EmptyHint keyword={keyword} label={activeDef.label} />;
    }

    return (
      <div className="pb-6">
        {sections.map((section, idx) => (
          <div key={section.key} className={idx === 0 ? "" : ""}>
            {section.count > 0 ? (
              <>
                <SectionHeader label={section.label} count={section.count} />
                <div className="bg-white">{section.children}</div>
              </>
            ) : null}
          </div>
        ))}
      </div>
    );
  };

  const renderSingleContent = () => {
    if (loading) {
      return <SearchStatus text="正在搜索…" />;
    }
    if (error) {
      return <SearchStatus text={error} isError />;
    }
    if (!keyword.trim()) {
      return <EmptyHint keyword="" label={activeDef.label} />;
    }
    if (!singleData || singleData.items.length === 0) {
      return <EmptyHint keyword={keyword} label={activeDef.label} />;
    }
    return (
      <div className="bg-white pb-6">
        {singleData.items.map((it, idx) => {
          const key = `s-${activeCategory}-${idx}-${(it as { id?: number | string }).id ?? idx}`;
          switch (activeCategory) {
            case "comrade":
              return <ComradeRow key={key} item={it as SearchComradeItem} />;
            case "camp":
              return <CampRow key={key} item={it as SearchCampItem} />;
            case "file":
              return <FileRow key={key} item={it as SearchFileItem} />;
            case "image":
              return <ImageRow key={key} item={it as SearchImageItem} />;
            case "knowledge":
              return <KnowledgeRow key={key} item={it as SearchKnowledgeItem} />;
            default:
              return null;
          }
        })}
      </div>
    );
  };

  return (
    <div
      className={cn(
        "fixed inset-0 z-[70] bg-[#f7f7f7] flex flex-col transition-transform duration-300 ease-[cubic-bezier(0.25,0.1,0.25,1)]",
        isEntering ? "translate-x-0" : "translate-x-full"
      )}
    >
      {/* 通用顶部栏 */}
      <div className="flex-shrink-0 flex items-center px-4 pt-[max(0.75rem,env(safe-area-inset-top))] pb-3 bg-white z-10">
        <button
          type="button"
          onClick={onClose}
          className="w-8 h-8 flex items-center justify-center -ml-2 active:opacity-60 transition-opacity"
          aria-label="返回"
        >
          <ArrowLeft className="w-5 h-5 text-gray-900" strokeWidth={1.5} />
        </button>
        <h1 className="flex-1 text-center text-base font-medium text-gray-900">
          搜索
        </h1>
        <div className="w-8" />
      </div>

      {/* 可聚焦的搜索框 */}
      <div className="flex-shrink-0 px-4 pt-3 pb-3 bg-white">
        <div className="flex items-center gap-2 h-10 px-3 rounded-md bg-gray-100/60 text-gray-900">
          <SearchIcon
            className="w-4 h-4 text-gray-400 flex-shrink-0"
            strokeWidth={1.8}
          />
          <input
            ref={inputRef}
            type="text"
            value={keyword}
            onChange={(e) => setKeyword(e.target.value)}
            placeholder={activeDef.placeholder}
            className="flex-1 bg-transparent text-sm outline-none placeholder:text-gray-400"
          />
          {keyword ? (
            <button
              type="button"
              onClick={handleClear}
              className="text-gray-400 p-0.5 active:text-gray-600"
              aria-label="清空"
            >
              <X className="w-3.5 h-3.5" strokeWidth={2} />
            </button>
          ) : null}
        </div>
      </div>

      {/* 分类标签栏 */}
      <div className="flex-shrink-0 bg-white">
        <div
          ref={tabsScrollRef}
          className="relative max-w-md mx-auto px-2 overflow-x-auto scrollbar-hide"
        >
          <div className="flex items-center gap-1 min-w-max">
            {CATEGORIES.map((cat) => {
              const isActive = cat.key === activeCategory;
              const Icon = cat.icon;
              return (
                <button
                  key={cat.key}
                  ref={(el) => {
                    tabButtonRefs.current[cat.key] = el;
                  }}
                  type="button"
                  onClick={() => handleCategoryClick(cat.key)}
                  className={cn(
                    "relative flex items-center gap-1 px-3 py-2.5 text-sm whitespace-nowrap transition-colors duration-300",
                    isActive
                      ? "text-[#F5A9B8] font-medium"
                      : "text-gray-500"
                  )}
                >
                  <Icon
                    className={cn(
                      "w-3.5 h-3.5 transition-colors duration-300",
                      isActive ? "text-[#F5A9B8]" : "text-gray-400"
                    )}
                    strokeWidth={1.8}
                  />
                  <span>{cat.label}</span>
                </button>
              );
            })}
          </div>
          <span
            className="absolute bottom-0 h-0.5 rounded-full bg-[#F5A9B8] transition-all duration-300 ease-[cubic-bezier(0.25,0.1,0.25,1)]"
            style={{
              left: indicator.left,
              width: indicator.width,
            }}
          />
        </div>
      </div>

      {/* 搜索结果区 */}
      <div className="flex-1 overflow-y-auto overflow-x-hidden scrollbar-hide">
        <div key={activeCategory} className="animate-content-in">
          {activeCategory === "all" ? renderAllContent() : renderSingleContent()}
        </div>
      </div>
    </div>
  );
}

function SearchStatus({ text, isError }: { text: string; isError?: boolean }) {
  return (
    <div className="flex flex-col items-center justify-center px-6 pt-20 pb-10 text-center">
      <div
        className={cn(
          "w-16 h-16 rounded-2xl border-2 border-dashed flex items-center justify-center mb-4",
          isError ? "border-red-200" : "border-gray-300"
        )}
      >
        <Search
          className={cn(
            "w-7 h-7",
            isError ? "text-red-300" : "text-gray-300"
          )}
          strokeWidth={1.5}
        />
      </div>
      <p className={cn("text-sm", isError ? "text-red-500" : "text-gray-500")}>
        {text}
      </p>
    </div>
  );
}
