import { cn } from "@/lib/utils";
import { LearnCategory } from "@/types/knowledge";
import { learnCategories } from "@/data/knowledgeMock";

interface LearnCategoryMenuProps {
  activeCategory: LearnCategory;
  onCategoryChange: (category: LearnCategory) => void;
  className?: string;
}

export function LearnCategoryMenu({
  activeCategory,
  onCategoryChange,
  className,
}: LearnCategoryMenuProps) {
  return (
    <div className={cn("bg-white", className)}>
      <div className="max-w-md mx-auto px-2 py-2">
        <div className="flex items-center gap-1 overflow-x-auto scrollbar-hide">
          {learnCategories.map((category) => {
            const isActive = category.key === activeCategory;
            return (
              <button
                key={category.key}
                type="button"
                onClick={() => onCategoryChange(category.key)}
                className={cn(
                  "flex-shrink-0 px-3 py-1.5 rounded-full text-sm whitespace-nowrap transition-all duration-300",
                  isActive
                    ? "text-white font-medium"
                    : "text-gray-600 bg-gray-100 hover:bg-gray-200"
                )}
                style={
                  isActive
                    ? {
                        background:
                          "linear-gradient(90deg, #5BCEFA, #F5A9B8, #5BCEFA)",
                      }
                    : undefined
                }
              >
                {category.label}
              </button>
            );
          })}
        </div>
      </div>
    </div>
  );
}
