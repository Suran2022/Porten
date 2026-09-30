import { useCallback, useEffect, useRef, useState } from "react";
import { LearnCategory } from "@/types/knowledge";
import { getLearnPostsByCategory } from "@/data/knowledgeMock";
import { LearnPost } from "@/types/knowledge";
import { ArticleCard } from "./ArticleCard";
import { VideoCard } from "./VideoCard";
import { PullToRefresh } from "@/components/common/PullToRefresh";

import { cn } from "@/lib/utils";

/** 模拟网络延迟：让刷新动效可感知 */
const REFRESH_DELAY_MS = 700;

/** 分类栏高度（px）：下拉刷新提示条需让位到分类栏之下 */
const CATEGORY_MENU_HEIGHT = 48;

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/** 洗牌：刷新后打乱列表顺序，使刷新结果可感知 */
function shuffle<T>(list: T[]): T[] {
  const arr = [...list];
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}

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

  // 列表数据改为受控 state：下拉刷新时重新拉取（洗牌）触发重渲
  const [posts, setPosts] = useState<LearnPost[]>(() =>
    getLearnPostsByCategory(activeCategory)
  );

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

  // 切换分类：重新拉取数据、回到顶部并复位分类栏吸附
  useEffect(() => {
    setPosts(getLearnPostsByCategory(activeCategory));
    if (scrollRef.current) {
      scrollRef.current.scrollTop = 0;
    }
    onMenuFixedChange(false);
    updateActiveVideo();
  }, [activeCategory, onMenuFixedChange, updateActiveVideo]);

  const handleRefresh = useCallback(async () => {
    await sleep(REFRESH_DELAY_MS);
    setPosts(shuffle(getLearnPostsByCategory(activeCategory)));
  }, [activeCategory]);

  return (
    <PullToRefresh
      onRefresh={handleRefresh}
      scrollRef={scrollRef}
      onScroll={handleScroll}
      // 提示条让位到吸附式分类栏之下，并计入滚动容器的 pt-14 顶部内边距，
      // 使提示内容始终居中于"分类栏底 ~ 主内容顶"，上下间距对称
      indicatorOffset={CATEGORY_MENU_HEIGHT}
      contentPaddingTop={56}
      scrollClassName={cn(
        "transition-[padding-top] duration-300",
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
    </PullToRefresh>
  );
}
