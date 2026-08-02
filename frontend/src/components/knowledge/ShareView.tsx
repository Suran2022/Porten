import { sharePosts } from "@/data/knowledgeMock";
import { ShareCard } from "./ShareCard";

export function ShareView() {
  return (
    <div className="pb-4">
      {sharePosts.map((post) => (
        <ShareCard key={post.id} post={post} />
      ))}
    </div>
  );
}
