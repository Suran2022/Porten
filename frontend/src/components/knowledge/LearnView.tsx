import { useCallback, useEffect, useRef } from "react";
import { LearnCategory } from "@/types/knowledge";
import { getLearnPostsByCategory } from "@/data/knowledgeMock";
import { ArticleCard } from "./ArticleCard";
import { VideoCard } from "./VideoCard";

import { cn } from "@/lib/utils";

interface LearnViewProps {
  activeCategory: LearnCategory;
  menuFixed: boolean;
  onMenuFixedChange: (fixed: boolean) => void;
}

export function LearnView({
  activeCategory,
  menuFixed,
  onMenuFixedChange,
}: LearnViewProps) {
  const scrollRef = useRef<HTMLDivElement>(null);
  const rafRef = useRef<number>();
  const videoRefs = useRef<Map<string, HTMLVideoElement>>(new Map());

  const setVideoRef = (id: string) => (el: HTMLVideoElement | null) => {
    if (el) {
      videoRefs.current.set(id, el);
    } else {
      videoRefs.current.delete(id);
    }
  };

  const updateActiveVideo = useCallback(() => {
    if (!scrollRef.current) return;
    const container = scrollRef.current;
    const containerRect = container.getBoundingClientRect();

    let activeId: string | null = null;
    let minTop = Infinity;

    videoRefs.current.forEach((video, id) => {
      if (!video) return;
      const videoRect = video.getBoundingClientRect();
      const top = videoRect.top - containerRect.top;
      const bottom = top + videoRect.height;
      if (top < containerRect.height && bottom > 0 && top >= 0 && top < minTop) {
        minTop = top;
        activeId = id;
      }
    });

    videoRefs.current.forEach((video, id) => {
      if (!video) return;
      if (id === activeId) {
        if (video.paused) video.play().catch(() => {});
      } else {
        if (!video.paused) video.pause();
      }
    });
  }, []);

  const handleScroll = useCallback(() => {
    if (!scrollRef.current) return;
    const { scrollTop } = scrollRef.current;
    onMenuFixedChange(scrollTop > 0);
    if (rafRef.current) return;
    rafRef.current = requestAnimationFrame(() => {
      updateActiveVideo();
      rafRef.current = undefined;
    });
  }, [onMenuFixedChange, updateActiveVideo]);

  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = 0;
    }
    onMenuFixedChange(false);
    updateActiveVideo();
  }, [activeCategory, onMenuFixedChange, updateActiveVideo]);

  const posts = getLearnPostsByCategory(activeCategory);

  return (
    <div
      ref={scrollRef}
      onScroll={handleScroll}
      className={cn(
        "h-full overflow-y-auto scrollbar-hide transition-[padding-top] duration-300",
        menuFixed ? "pt-0" : "pt-14"
      )}
    >
      {/* Posts */}
      <div className="pb-4">
        {posts.map((post) =>
          post.type === "article" ? (
            <ArticleCard key={post.id} post={post} />
          ) : (
            <VideoCard
              key={post.id}
              post={post}
              ref={setVideoRef(post.id)}
            />
          )
        )}
      </div>
    </div>
  );
}
