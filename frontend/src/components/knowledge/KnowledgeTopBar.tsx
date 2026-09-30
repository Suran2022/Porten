import { cn } from "@/lib/utils";
import { KnowledgeTab } from "@/types/knowledge";
import RubberSegment from "@/components/common/RubberSegment";

interface KnowledgeTopBarProps {
  activeTab: KnowledgeTab;
  onTabChange: (tab: KnowledgeTab) => void;
  buttonsVisible?: boolean;
}

const tabs: { key: KnowledgeTab; label: string }[] = [
  { key: "share", label: "分享" },
  { key: "learn", label: "学习" },
];

export function KnowledgeTopBar({
  activeTab,
  onTabChange,
  buttonsVisible = true,
}: KnowledgeTopBarProps) {
  return (
    <header className="fixed top-0 left-0 right-0 z-40 bg-white h-16">
      <div className="max-w-md mx-auto h-full flex items-center justify-center px-4">
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
      </div>
    </header>
  );
}
