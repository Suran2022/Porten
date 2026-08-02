import { useEffect, useRef, useState } from "react";
import { Users, Building2, Sparkles, Stethoscope, GraduationCap } from "lucide-react";
import { cn } from "@/lib/utils";

interface CreateGroupPageProps {
  visible: boolean;
  onClose: () => void;
  onSelectCategory?: (category: string) => void;
}

export const GROUP_CATEGORIES = [
  { key: "peer", label: "跨儿同行", icon: Users },
  { key: "org", label: "跨儿组织", icon: Building2 },
  { key: "acg", label: "二次元", icon: Sparkles },
  { key: "medical", label: "医疗机构", icon: Stethoscope },
  { key: "school", label: "院校", icon: GraduationCap },
] as const;

export function CreateGroupPage({ visible, onClose, onSelectCategory }: CreateGroupPageProps) {
  const [isEntering, setIsEntering] = useState(false);
  const closeTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    if (visible) {
      if (closeTimerRef.current) {
        clearTimeout(closeTimerRef.current);
        closeTimerRef.current = null;
      }
      requestAnimationFrame(() => {
        requestAnimationFrame(() => setIsEntering(true));
      });
    } else {
      setIsEntering(false);
      closeTimerRef.current = setTimeout(() => {}, 320);
    }
    return () => {
      if (closeTimerRef.current) clearTimeout(closeTimerRef.current);
    };
  }, [visible]);

  return (
    <div
      className={cn(
        "fixed inset-0 z-[70] bg-white flex flex-col transition-transform duration-300 ease-[cubic-bezier(0.25,0.1,0.25,1)]",
        isEntering ? "translate-x-0" : "-translate-x-full"
      )}
    >
      {/* Top bar */}
      <div className="flex-shrink-0 flex items-center justify-between px-4 pt-[max(0.75rem,env(safe-area-inset-top))] pb-3 bg-white z-10">
        <div className="w-14" />
        <h1 className="text-base font-medium text-gray-900">组建营地</h1>
        <button
          type="button"
          onClick={onClose}
          className="w-14 text-right text-sm text-gray-600 active:text-gray-900 transition-colors"
        >
          取消
        </button>
      </div>

      {/* Categories */}
      <div className="flex-1 px-6 pt-8 overflow-hidden">
        <div className="grid grid-cols-5 gap-3">
          {GROUP_CATEGORIES.map((item) => {
            const Icon = item.icon;
            return (
              <button
                key={item.key}
                type="button"
                onClick={() => onSelectCategory?.(item.key)}
                className="flex flex-col items-center gap-2 active:opacity-70 transition-opacity"
              >
                <div className="w-12 h-12 rounded-2xl bg-gray-100/80 flex items-center justify-center">
                  <Icon className="w-6 h-6 text-gray-700" strokeWidth={1.5} />
                </div>
                <span className="text-xs text-gray-700">{item.label}</span>
              </button>
            );
          })}
        </div>
      </div>
    </div>
  );
}
