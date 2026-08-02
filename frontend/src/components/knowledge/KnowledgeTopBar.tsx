import { cn } from "@/lib/utils";
import { KnowledgeTab } from "@/types/knowledge";

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
            "inline-flex items-center rounded-full border border-black p-[0.5px] transition-opacity duration-300",
            !buttonsVisible && "opacity-0 pointer-events-none"
          )}
        >
          {tabs.map((tab) => {
            const isActive = tab.key === activeTab;
            return (
              <button
                key={tab.key}
                type="button"
                onClick={() => onTabChange(tab.key)}
                className={cn(
                  "relative px-8 py-1.5 rounded-full text-sm font-medium transition-all duration-300 ease-out",
                  isActive
                    ? "text-white"
                    : "text-gray-700 hover:text-gray-900 bg-white"
                )}
              >
                {isActive && (
                  <span
                    className="absolute inset-0 rounded-full -z-10"
                    style={{
                      background:
                        "linear-gradient(90deg, #5BCEFA, #F5A9B8, #5BCEFA)",
                    }}
                  />
                )}
                {tab.label}
              </button>
            );
          })}
        </div>
      </div>
    </header>
  );
}
