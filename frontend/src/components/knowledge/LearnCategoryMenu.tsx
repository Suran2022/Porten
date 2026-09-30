import { cn } from "@/lib/utils";
import { LearnCategory } from "@/types/knowledge";
import { learnCategories } from "@/data/knowledgeMock";
import JellyRadio from "@/components/common/JellyRadio";

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
      <div className="max-w-md mx-auto">
        <div className="flex overflow-x-auto scrollbar-hide">
          <JellyRadio
            ariaLabel="学习分类切换"
            items={learnCategories.map((category) => ({
              value: category.key,
              label: category.label,
            }))}
            value={activeCategory}
            onChange={(value) => onCategoryChange(value as LearnCategory)}
            size="md"
            gap={8}
            radius={18}
            swell={0.2}
            barge={6}
            shrink={0.05}
            jelly={1}
            bounce={0.25}
            stagger={22}
            stiffness={580}
            chipColor="#f4f4f5"
            activeColor="linear-gradient(90deg, #5BCEFA, #F5A9B8)"
            textColor="#4b5563"
            activeTextColor="#ffffff"
          />
        </div>
      </div>
    </div>
  );
}
