import { forwardRef, useState } from "react";
import { LearnPost } from "@/types/knowledge";
import { Eye, Share2, Play, Volume2, VolumeX } from "lucide-react";

interface VideoCardProps {
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

export const VideoCard = forwardRef<HTMLVideoElement, VideoCardProps>(
  function VideoCard({ post }, ref) {
    const [muted, setMuted] = useState(true);
    const [showPoster, setShowPoster] = useState(true);

    return (
      <article className="px-4 py-3 bg-white active:bg-gray-50/50 transition-colors cursor-pointer">
        {/* Video Player */}
        <div className="relative w-full aspect-[16/9] rounded-xl overflow-hidden bg-black">
          <video
            ref={ref}
            src={post.videoUrl}
            poster={post.coverUrl}
            muted={muted}
            loop
            playsInline
            preload="metadata"
            className="w-full h-full object-cover"
            onPlay={() => setShowPoster(false)}
            onPause={() => setShowPoster(true)}
            onWaiting={() => setShowPoster(true)}
          />

          {showPoster && (
            <div className="absolute inset-0 flex items-center justify-center bg-black/20 pointer-events-none">
              <div className="w-12 h-12 rounded-full bg-white/90 flex items-center justify-center">
                <Play className="w-5 h-5 text-gray-800 ml-0.5" strokeWidth={2} fill="currentColor" />
              </div>
            </div>
          )}

          {post.duration && (
            <span className="absolute bottom-2 right-2 px-1.5 py-0.5 rounded text-[10px] font-medium text-white bg-black/60">
              {post.duration}
            </span>
          )}

          <button
            type="button"
            onClick={(e) => {
              e.stopPropagation();
              setMuted((prev) => !prev);
            }}
            className="absolute top-2 right-2 p-1.5 rounded-full bg-black/40 text-white hover:bg-black/60 transition-colors"
          >
            {muted ? (
              <VolumeX className="w-3.5 h-3.5" strokeWidth={2} />
            ) : (
              <Volume2 className="w-3.5 h-3.5" strokeWidth={2} />
            )}
          </button>
        </div>

        {/* Content */}
        <div className="mt-3">
          <h3 className="text-base font-semibold text-gray-900 leading-snug">
            {post.title}
          </h3>
          <p className="mt-1.5 text-sm text-gray-600 leading-relaxed">
            {truncateText(post.summary, 120)}
          </p>

          {/* Meta */}
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
              分享
            </span>
          </div>
        </div>
      </article>
    );
  }
);
