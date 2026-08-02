import { KnowledgeTab, LearnCategory } from "@/types/knowledge";
import { ShareView } from "./ShareView";
import { LearnView } from "./LearnView";

interface KnowledgeViewProps {
  activeTab: KnowledgeTab;
  activeCategory: LearnCategory;
  menuFixed: boolean;
  onMenuFixedChange: (fixed: boolean) => void;
}

export function KnowledgeView({
  activeTab,
  activeCategory,
  menuFixed,
  onMenuFixedChange,
}: KnowledgeViewProps) {
  return (
    <div className="h-full flex flex-col bg-white">
      <div className="flex-1 overflow-hidden">
        <div
          className="flex h-full w-[200%] transition-transform duration-500 ease-[cubic-bezier(0.25,0.1,0.25,1)]"
          style={{
            transform: `translateX(${activeTab === "share" ? 0 : "-50%"})`,
          }}
        >
          <div className="h-full w-1/2 overflow-y-auto scrollbar-hide">
            <ShareView />
          </div>
          <div className="h-full w-1/2 overflow-y-auto scrollbar-hide">
            <LearnView
              activeCategory={activeCategory}
              menuFixed={menuFixed}
              onMenuFixedChange={onMenuFixedChange}
            />
          </div>
        </div>
      </div>
    </div>
  );
}
