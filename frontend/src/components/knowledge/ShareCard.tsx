import { useState } from "react";
import { SharePost } from "@/types/knowledge";
import { Eye, MessageCircle, Heart, Share2 } from "lucide-react";

interface ShareCardProps {
  post: SharePost;
}

function formatCount(count: number): string {
  if (count >= 10000) {
    return `${(count / 10000).toFixed(1)}w`;
  }
  if (count >= 1000) {
    return `${(count / 1000).toFixed(1)}k`;
  }
  return String(count);
}

function truncateText(text: string, maxLength: number): string {
  if (text.length <= maxLength) return text;
  return `${text.slice(0, maxLength)}…`;
}

export function ShareCard({ post }: ShareCardProps) {
  const { author, content, latestComment, views, comments, likes, publishedAt } = post;
  const [imgError, setImgError] = useState(false);

  const avatarFallback = author.nickname.slice(0, 1);

  return (
    <article className="px-4 py-3 bg-white active:bg-gray-50/50 transition-colors cursor-pointer">
      <div className="flex gap-3">
        {/* Avatar */}
        <div className="flex-shrink-0 w-11 h-11 rounded-full bg-gradient-to-br from-[#5BCEFA] to-[#F5A9B8] flex items-center justify-center overflow-hidden">
          {author.avatar && !imgError ? (
            <img
              src={author.avatar}
              alt={author.nickname}
              className="w-full h-full object-cover"
              onError={() => setImgError(true)}
            />
          ) : (
            <span className="text-sm font-medium text-white">{avatarFallback}</span>
          )}
        </div>

        {/* Content */}
        <div className="flex-1 min-w-0">
          <h3 className="text-base font-semibold text-gray-900 leading-tight">
            {author.nickname}
          </h3>

          <p className="mt-1 text-sm text-gray-700 leading-relaxed">
            {truncateText(content, 120)}
          </p>

          {latestComment && (
            <div className="mt-2 rounded-lg bg-gray-100/80 px-3 py-2">
              <p className="text-xs text-gray-600 leading-relaxed">
                <span className="font-medium text-gray-800">
                  {latestComment.author}
                </span>
                <span className="mx-1 text-gray-400">·</span>
                {truncateText(latestComment.content, 60)}
              </p>
            </div>
          )}

          {/* Meta & Actions */}
          <div className="mt-2.5 flex items-center justify-between gap-2">
            <div className="flex items-center gap-4 text-xs text-gray-500">
              <span className="flex items-center gap-1">
                <Eye className="w-3.5 h-3.5" strokeWidth={1.8} />
                {formatCount(views)}
              </span>
              <span className="flex items-center gap-1">
                <MessageCircle className="w-3.5 h-3.5" strokeWidth={1.8} />
                {formatCount(comments)}
              </span>
              <span className="flex items-center gap-1">
                <Heart className="w-3.5 h-3.5" strokeWidth={1.8} />
                {formatCount(likes)}
              </span>
            </div>

            <div className="flex items-center gap-3 flex-shrink-0">
              <span
                className="flex items-center gap-1 text-xs font-semibold"
                style={{
                  background:
                    "linear-gradient(90deg, #5BCEFA, #F5A9B8, #5BCEFA)",
                  WebkitBackgroundClip: "text",
                  backgroundClip: "text",
                  color: "transparent",
                }}
              >
                <Share2 className="w-3.5 h-3.5" strokeWidth={1.8} />
                分享
              </span>
              <span className="text-xs text-gray-400">{publishedAt}</span>
            </div>
          </div>
        </div>
      </div>
    </article>
  );
}
