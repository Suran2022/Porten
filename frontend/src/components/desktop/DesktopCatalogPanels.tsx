import { ResourceView } from "@/components/resource/ResourceView";
import { KnowledgeView } from "@/components/knowledge/KnowledgeView";
import { LearnCategoryMenu } from "@/components/knowledge/LearnCategoryMenu";
import { cn } from "@/lib/utils";
import { ResourceTab } from "@/types/resource";
import { KnowledgeTab, LearnCategory } from "@/types/knowledge";

/* ============================= 通用菜单栏（第二栏） ============================= */

export interface CatalogMenuItem {
  key: string;
  label: string;
}

function CatalogMenu({
  items,
  active,
  onChange,
  children,
}: {
  items: CatalogMenuItem[];
  active: string;
  onChange: (key: string) => void;
  children?: React.ReactNode;
}) {
  return (
    <div className="h-full flex flex-col bg-white">
      <div className="shrink-0 px-3 pt-3 pb-2">
        {items.map((item) => {
          const isActive = item.key === active;
          return (
            <button
              key={item.key}
              type="button"
              onClick={() => onChange(item.key)}
              className={cn(
                "w-full flex items-center justify-between px-3 h-11 rounded-xl text-left transition-colors duration-300",
                isActive ? "bg-gray-100/80" : "hover:bg-gray-50"
              )}
            >
              <span
                className={cn(
                  "text-sm transition-all duration-300",
                  isActive
                    ? "porten-gradient font-medium"
                    : "text-gray-600"
                )}
              >
                {item.label}
              </span>
            </button>
          );
        })}
      </div>
      <div className="flex-1 overflow-y-auto desktop-scroll">{children}</div>
    </div>
  );
}

/* ============================= 资源视图 ============================= */

const resourceItems: CatalogMenuItem[] = [
  { key: "hospital", label: "医院" },
  { key: "organization", label: "组织" },
  { key: "process", label: "流程" },
];

export function DesktopResourcePanel({
  activeTab,
  onTabChange,
}: {
  activeTab: ResourceTab;
  onTabChange: (tab: ResourceTab) => void;
}) {
  return (
    <CatalogMenu
      items={resourceItems}
      active={activeTab}
      onChange={(key) => onTabChange(key as ResourceTab)}
    >
      <div className="px-3 pb-3">
        <button
          type="button"
          className="w-full flex items-center justify-between px-3 h-11 rounded-xl text-left text-sm text-gray-600 hover:bg-gray-50 transition-colors duration-300"
        >
          收藏
        </button>
      </div>
    </CatalogMenu>
  );
}

export function DesktopResourceContent({ activeTab }: { activeTab: ResourceTab }) {
  return (
    <div className="h-full overflow-y-auto desktop-scroll bg-white">
      <div className="max-w-2xl mx-auto">
        <ResourceView activeTab={activeTab} />
      </div>
    </div>
  );
}

/* ============================= 知识视图 ============================= */

const knowledgeItems: CatalogMenuItem[] = [
  { key: "share", label: "分享" },
  { key: "learn", label: "学习" },
];

export function DesktopKnowledgePanel({
  activeTab,
  onTabChange,
}: {
  activeTab: KnowledgeTab;
  onTabChange: (tab: KnowledgeTab) => void;
}) {
  return (
    <CatalogMenu
      items={knowledgeItems}
      active={activeTab}
      onChange={(key) => onTabChange(key as KnowledgeTab)}
    />
  );
}

export function DesktopKnowledgeContent({
  activeTab,
  activeCategory,
  onCategoryChange,
}: {
  activeTab: KnowledgeTab;
  activeCategory: LearnCategory;
  onCategoryChange: (category: LearnCategory) => void;
}) {
  return (
    <div className="h-full overflow-hidden bg-white flex flex-col">
      <div className="w-full max-w-2xl mx-auto flex flex-col min-h-0">
        {/* 学习分类 Bar 位于第三栏顶部，与内容列左缘对齐 */}
        {activeTab === "learn" && (
          <div className="shrink-0 pt-4 pb-3">
            <LearnCategoryMenu
              activeCategory={activeCategory}
              onCategoryChange={onCategoryChange}
              align="left"
            />
          </div>
        )}
        <div className="flex-1 min-h-0">
          {/* 分类菜单已移至第三栏顶部，内容区无需预留顶部空间 */}
          <KnowledgeView
            activeTab={activeTab}
            activeCategory={activeCategory}
            menuFixed
            onMenuFixedChange={() => {}}
          />
        </div>
      </div>
    </div>
  );
}
