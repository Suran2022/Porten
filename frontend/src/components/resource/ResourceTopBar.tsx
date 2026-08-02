import { cn } from "@/lib/utils";
import { ResourceTab } from "@/types/resource";

const tabs: { key: ResourceTab; label: string }[] = [
  { key: "hospital", label: "医院" },
  { key: "organization", label: "组织" },
  { key: "process", label: "流程" },
];

interface ResourceTopBarProps {
  activeTab: ResourceTab;
  onTabChange: (tab: ResourceTab) => void;
}

export function ResourceTopBar({ activeTab, onTabChange }: ResourceTopBarProps) {
  return (
    <header className="fixed top-0 left-0 right-0 z-40 bg-white w-full">
      <div className="max-w-md mx-auto h-16 px-4 flex items-end justify-between">
        {/* Left: tabs */}
        <nav className="flex items-end gap-5 h-full pb-3">
          {tabs.map((tab) => {
            const isActive = tab.key === activeTab;
            return (
              <button
                key={tab.key}
                type="button"
                onClick={() => onTabChange(tab.key)}
                className={cn(
                  "leading-none transition-all duration-300 ease-out",
                  isActive
                    ? "text-[18px] font-semibold porten-gradient"
                    : "text-base text-gray-500 hover:text-gray-700"
                )}
              >
                {tab.label}
              </button>
            );
          })}
        </nav>

        {/* Right: favorites */}
        <button
          type="button"
          className="mb-3 text-sm text-gray-500 hover:text-gray-700 transition-colors"
        >
          收藏
        </button>
      </div>
    </header>
  );
}
