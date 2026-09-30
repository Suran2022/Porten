import { useState } from "react";
import { sharePosts } from "@/data/knowledgeMock";
import { SharePost } from "@/types/knowledge";
import { ShareCard } from "./ShareCard";
import { PullToRefresh } from "@/components/common/PullToRefresh";

/** 模拟网络延迟：让刷新动效可感知 */
const REFRESH_DELAY_MS = 700;

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

/** 知识列表（分享）：内置下拉刷新，提示条位于知识顶部栏与内容之间 */
export function ShareView() {
  const [posts, setPosts] = useState<SharePost[]>(sharePosts);

  const handleRefresh = async () => {
    await sleep(REFRESH_DELAY_MS);
    setPosts(shuffle(sharePosts));
  };

  return (
    <PullToRefresh onRefresh={handleRefresh}>
      <div className="pb-4">
        {posts.map((post) => (
          <ShareCard key={post.id} post={post} />
        ))}
      </div>
    </PullToRefresh>
  );
}
