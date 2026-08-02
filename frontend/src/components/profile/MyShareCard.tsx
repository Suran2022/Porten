import { SharePost } from "@/types/knowledge";
import { Eye, MessageCircle, Heart } from "lucide-react";

interface MyShareCardProps {
  post: SharePost;
  title?: string;
  // flat=true 时去除外层白色圆角背景包裹（同胞资料页使用）
  flat?: boolean;
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

export function MyShareCard({ post, title = "我的分享", flat = false }: MyShareCardProps) {
  const { content, latestComment, views, comments, likes } = post;

  return (
    <div className={flat ? "" : "bg-white rounded-2xl p-4"}>
      <h3 className="text-base font-semibold text-gray-900 mb-3">{title}</h3>
      <div className="rounded-[10px] border border-gray-200 overflow-hidden">
        <article className="px-3 py-3 bg-white active:bg-gray-50/50 transition-colors cursor-pointer">
          <p className="text-sm text-gray-700 leading-relaxed">
            {truncateText(content, 140)}
          </p>

          {latestComment && (
            <div className="mt-2 rounded-lg bg-gray-100/80 px-3 py-2">
              <p className="text-xs text-gray-600 leading-relaxed">
                <span className="font-medium text-gray-800">
                  {latestComment.author}
                </span>
                <span className="mx-1 text-gray-400">·</span>
                {truncateText(latestComment.content, 70)}
              </p>
            </div>
          )}

          <div className="mt-2.5 flex items-center gap-4 text-xs text-gray-500">
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
        </article>
      </div>
    </div>
  );
}
