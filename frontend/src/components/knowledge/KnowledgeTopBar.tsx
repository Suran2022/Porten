import { cn } from "@/lib/utils";
import { KnowledgeTab } from "@/types/knowledge";
import RubberSegment from "@/components/common/RubberSegment";
import { useToastStore } from "@/store/toastStore";

interface KnowledgeTopBarProps {
  activeTab: KnowledgeTab;
  onTabChange: (tab: KnowledgeTab) => void;
  buttonsVisible?: boolean;
}

const tabs: { key: KnowledgeTab; label: string }[] = [
  { key: "share", label: "分享" },
  { key: "learn", label: "学习" },
];

/** 分享入口图标（方框 + 右上箭头） */
function ShareIcon({ className }: { className?: string }) {
  return (
    <svg
      className={className}
      viewBox="0 0 1024 1024"
      fill="currentColor"
      aria-hidden
    >
      <path d="M173.9264 670.8736v-307.2a179.2 179.2 0 0 1 179.2-179.2h153.6a25.6 25.6 0 0 1 0 51.2h-153.6a128 128 0 0 0-128 128v307.2a128 128 0 0 0 128 128h307.2a128 128 0 0 0 128-128v-153.6a25.6 25.6 0 0 1 51.2 0v153.6a179.2 179.2 0 0 1-179.2 179.2h-307.2a179.2 179.2 0 0 1-179.2-179.2z" />
      <path d="M660.3264 645.2736a25.6 25.6 0 0 1 0 51.2h-307.2a25.6 25.6 0 0 1 0-51.2h307.2zM795.4432 192.3584a25.6 25.6 0 0 1 36.864 35.4816l-307.1488 319.6416a25.6 25.6 0 0 1-36.864-35.4816l307.1488-319.6416z" />
    </svg>
  );
}

/**
 * 知识视图顶部栏：左侧为分享 / 学习分类切换 Bar，右侧为分享入口
 * （图标 + 文本，浅灰色圆角底）。学习子分类菜单固定时整栏淡出让位。
 */
export function KnowledgeTopBar({
  activeTab,
  onTabChange,
  buttonsVisible = true,
}: KnowledgeTopBarProps) {
  return (
    <header className="fixed top-0 left-0 right-0 z-40 bg-white h-16">
      <div className="max-w-md mx-auto h-full flex items-center justify-between px-4">
        {/* 左侧：分享 / 学习分类切换 Bar */}
        <div
          className={cn(
            "transition-opacity duration-300",
            !buttonsVisible && "opacity-0 pointer-events-none"
          )}
        >
          <RubberSegment
            aria-label="知识板块切换"
            items={tabs.map((tab) => ({ value: tab.key, label: tab.label }))}
            value={activeTab}
            onChange={(value) => onTabChange(value as KnowledgeTab)}
            size="md"
            radius={10}
            inset={3}
            equalSlots
            stretch={100}
            squash={3}
            speed={1}
            glide={75}
            draggable
            trackColor="#f4f4f5"
            thumbColor="linear-gradient(90deg, #5BCEFA, #F5A9B8, #5BCEFA)"
            textColor="#52525b"
            activeTextColor="#ffffff"
          />
        </div>

        {/* 右侧：分享入口（仅分享 Tab 显示；高度与分类 Bar 一致为 36px，浅灰色圆角底） */}
        {activeTab === "share" ? (
          <button
            type="button"
            aria-label="分享"
            onClick={() =>
              useToastStore
                .getState()
                .show("已生成分享卡片，快分享给同胞吧", "success", "center")
            }
            className={cn(
              "flex h-9 items-center gap-1 rounded-full bg-gray-100 pl-2.5 pr-3 text-[13px] text-[#1a1a1a] active:bg-gray-200/70 transition-all duration-300",
              !buttonsVisible && "opacity-0 pointer-events-none"
            )}
          >
            <ShareIcon className="w-4 h-4" />
            <span className="leading-none select-none">分享</span>
          </button>
        ) : null}
      </div>
    </header>
  );
}
