import { useMemo, useState } from "react";
import { Search, X } from "lucide-react";
import { sharePosts } from "@/data/knowledgeMock";
import { ShareCard } from "./ShareCard";

interface ShareStandaloneDialogProps {
  onClose: () => void;
}

/**
 * 记录与分享独立视图弹窗（PC 端）。
 *
 * 结构：
 *   - 头部一行三元素：左上角标题「记录与分享」、居中胶囊搜索框
 *     （细黑 border + 黑色提示文本）、右上角关闭叉叉；
 *   - 主内容区域：分享卡片列表，随搜索词实时过滤
 *     （匹配正文 / 作者昵称 / 最新评论），无结果时显示空态。
 */
export function ShareStandaloneDialog({ onClose }: ShareStandaloneDialogProps) {
  const [keyword, setKeyword] = useState("");

  const filteredPosts = useMemo(() => {
    const query = keyword.trim().toLowerCase();
    if (!query) return sharePosts;
    return sharePosts.filter(
      (post) =>
        post.content.toLowerCase().includes(query) ||
        post.author.nickname.toLowerCase().includes(query) ||
        (post.latestComment?.content ?? "").toLowerCase().includes(query)
    );
  }, [keyword]);

  return (
    <div className="h-full flex flex-col bg-white">
      {/* 头部：左标题 / 中搜索 / 右关闭 */}
      <div className="shrink-0 relative flex items-center px-4 pt-4 pb-3">
        <h2 className="text-base font-semibold text-gray-900">记录与分享</h2>

        <div className="absolute left-1/2 -translate-x-1/2 w-64">
          <div className="flex items-center gap-2 h-9 px-4 rounded-full border border-black/80">
            <Search className="w-3.5 h-3.5 text-black/60 shrink-0" strokeWidth={1.8} />
            <input
              value={keyword}
              onChange={(e) => setKeyword(e.target.value)}
              placeholder="搜索记录与分享"
              className="flex-1 min-w-0 bg-transparent text-sm text-gray-900 placeholder-black outline-none"
            />
            {keyword && (
              <button
                type="button"
                onClick={() => setKeyword("")}
                className="shrink-0 text-black/40 hover:text-black/70 transition-colors"
                aria-label="清空搜索"
              >
                <X className="w-3.5 h-3.5" strokeWidth={1.8} />
              </button>
            )}
          </div>
        </div>

        <button
          type="button"
          onClick={onClose}
          className="ml-auto shrink-0 w-8 h-8 flex items-center justify-center rounded-full text-gray-500 hover:text-gray-900 hover:bg-gray-100 transition-colors"
          aria-label="关闭"
        >
          <X className="w-4.5 h-4.5" strokeWidth={1.8} />
        </button>
      </div>

      {/* 主内容区域：分享卡片列表 */}
      <div className="flex-1 min-h-0 overflow-y-auto desktop-scroll">
        {filteredPosts.length > 0 ? (
          <div className="pb-4">
            {filteredPosts.map((post) => (
              <ShareCard key={post.id} post={post} />
            ))}
          </div>
        ) : (
          <div className="h-full flex flex-col items-center justify-center gap-2 text-sm text-gray-400">
            <Search className="w-8 h-8 text-gray-300" strokeWidth={1.5} />
            没有找到相关分享
          </div>
        )}
      </div>
    </div>
  );
}
