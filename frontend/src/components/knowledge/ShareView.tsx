import { useState } from "react";
import { PictureInPicture2 } from "lucide-react";
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

interface ShareViewProps {
  /** 点击列表卡片打开分享详情页 */
  onPostOpen?: (post: SharePost) => void;
  /** 打开独立视图弹窗（仅 PC 第三栏传入，移动端不显示入口） */
  onStandaloneOpen?: () => void;
}

/** 知识列表（分享）：内置下拉刷新，提示条位于知识顶部栏与内容之间 */
export function ShareView({ onPostOpen, onStandaloneOpen }: ShareViewProps) {
  const [posts, setPosts] = useState<SharePost[]>(sharePosts);

  const handleRefresh = async () => {
    await sleep(REFRESH_DELAY_MS);
    setPosts(shuffle(sharePosts));
  };

  return (
    <PullToRefresh onRefresh={handleRefresh}>
      <div className="pb-4">
        {/* 独立视图入口：分享卡片视图右上角（仅 PC 第三栏显示） */}
        {onStandaloneOpen && (
          <div className="flex justify-end px-4 pt-3">
            <button
              type="button"
              onClick={onStandaloneOpen}
              className="flex items-center gap-1.5 text-xs text-gray-500 hover:text-gray-900 transition-colors"
            >
              <PictureInPicture2 className="w-3.5 h-3.5" strokeWidth={1.8} />
              打开独立视图
            </button>
          </div>
        )}
        {posts.map((post) => (
          <ShareCard key={post.id} post={post} onOpen={onPostOpen} />
        ))}
      </div>
    </PullToRefresh>
  );
}
