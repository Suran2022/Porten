import { useState } from "react";
import { LearnPost } from "@/types/knowledge";
import { Eye, Share2, ImageOff } from "lucide-react";

interface ArticleCardProps {
  post: LearnPost;
}

function truncateText(text: string, maxLength: number): string {
  if (text.length <= maxLength) return text;
  return `${text.slice(0, maxLength)}…`;
}

function formatCount(count: number): string {
  if (count >= 10000) return `${(count / 10000).toFixed(1)}w`;
  if (count >= 1000) return `${(count / 1000).toFixed(1)}k`;
  return String(count);
}

export function ArticleCard({ post }: ArticleCardProps) {
  const [imgError, setImgError] = useState(false);

  return (
    <article className="px-4 py-3 bg-white active:bg-gray-50/50 transition-colors cursor-pointer">
      {/* Cover */}
      <div className="relative w-full aspect-[16/9] rounded-xl overflow-hidden bg-gray-100">
        {post.coverUrl && !imgError ? (
          <img
            src={post.coverUrl}
            alt={post.title}
            className="w-full h-full object-cover"
            onError={() => setImgError(true)}
          />
        ) : (
          <div className="w-full h-full flex flex-col items-center justify-center gap-2 bg-gray-50">
            <ImageOff className="w-10 h-10 text-gray-300" strokeWidth={1.5} />
            <span className="text-xs text-gray-400">封面加载失败</span>
          </div>
        )}
      </div>

      {/* Content */}
      <div className="mt-3">
        <h3 className="text-base font-semibold text-gray-900 leading-snug">
          {post.title}
        </h3>
        <p className="mt-1.5 text-sm text-gray-600 leading-relaxed">
          {truncateText(post.summary, 120)}
        </p>

        {/* Tags */}
        {post.tags.length > 0 && (
          <div className="mt-2 flex flex-wrap gap-1.5">
            {post.tags.map((tag) => (
              <span
                key={tag}
                className="inline-flex items-center px-2 py-0.5 rounded text-xs bg-gray-100 text-gray-500"
              >
                {tag}
              </span>
            ))}
          </div>
        )}

        {/* Meta & Actions */}
        <div className="mt-2.5 flex items-center justify-between gap-2">
          <div className="flex items-center gap-3 text-xs text-gray-500">
            <span>{post.publishedAt}</span>
            <span className="flex items-center gap-1">
              <Eye className="w-3.5 h-3.5" strokeWidth={1.8} />
              {formatCount(post.views)}
            </span>
            <span className="flex items-center gap-1">
              <Share2 className="w-3.5 h-3.5" strokeWidth={1.8} />
              {formatCount(post.shares)}
            </span>
          </div>

          <span
            className="text-xs font-semibold"
            style={{
              background: "linear-gradient(90deg, #5BCEFA, #F5A9B8, #5BCEFA)",
              WebkitBackgroundClip: "text",
              backgroundClip: "text",
              color: "transparent",
            }}
          >
            阅读全文
          </span>
        </div>
      </div>
    </article>
  );
}
