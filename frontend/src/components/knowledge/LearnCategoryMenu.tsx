import { useEffect, useRef } from "react";
import { cn } from "@/lib/utils";
import { LearnCategory } from "@/types/knowledge";
import { learnCategories } from "@/data/knowledgeMock";
import JellyRadio from "@/components/common/JellyRadio";

interface LearnCategoryMenuProps {
  activeCategory: LearnCategory;
  onCategoryChange: (category: LearnCategory) => void;
  className?: string;
  /** 水平对齐方式；默认居中且限宽（移动端），PC 第三栏传 left 左对齐并占满列宽。 */
  align?: "center" | "left";
}

export function LearnCategoryMenu({
  activeCategory,
  onCategoryChange,
  className,
  align = "center",
}: LearnCategoryMenuProps) {
  const scrollRef = useRef<HTMLDivElement>(null);

  // PC：纵向滚轮转为横向滚动，分类放不下时鼠标滚轮可直接查看；
  // 移动端（align 默认 center）触摸滑动即可，不挂该监听。
  useEffect(() => {
    if (align !== "left") return;
    const el = scrollRef.current;
    if (!el) return;
    const onWheel = (e: WheelEvent) => {
      if (el.scrollWidth <= el.clientWidth) return;
      e.preventDefault();
      el.scrollLeft += e.deltaY + e.deltaX;
    };
    el.addEventListener("wheel", onWheel, { passive: false });
    return () => el.removeEventListener("wheel", onWheel);
  }, [align]);

  return (
    <div className={cn("bg-white", className)}>
      <div className={cn(align === "left" ? "w-full" : "max-w-md mx-auto")}>
        <div ref={scrollRef} className="flex overflow-x-auto scrollbar-hide">
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
