import { useEffect, useState, useRef } from "react";
import {
  UserPlus,
  Users,
  CalendarCheck,
  Map,
  CalendarDays,
  Wallet,
  Briefcase,
  ScanLine,
  StickyNote,
  Heart,
} from "lucide-react";
import { cn } from "@/lib/utils";

const menuItems = [
  { key: "add", label: "添加同胞/营地", icon: UserPlus },
  { key: "create", label: "创建营地", icon: Users },
  { key: "agreement", label: "创建约定", icon: CalendarCheck },
  { key: "journey", label: "创建旅程", icon: Map },
  { key: "schedule", label: "我的日程", icon: CalendarDays },
  { key: "finance", label: "跨儿财务", icon: Wallet },
  { key: "workplace", label: "跨儿职场", icon: Briefcase },
  { key: "scan", label: "扫一扫", icon: ScanLine },
  { key: "note", label: "记笔记", icon: StickyNote },
  { key: "mood", label: "情绪日记", icon: Heart },
];

interface PlusMenuProps {
  open: boolean;
  onClose: () => void;
  onAddFriend?: () => void;
  onCreateGroup?: () => void;
  /** 创建旅程：跳转创建旅程独立页面 */
  onCreateJourney?: () => void;
  onScan?: () => void;
  onNote?: () => void;
  onMoodDiary?: () => void;
  /** 暂未实现页面的功能项统一回调（携带菜单项标题） */
  onPlaceholder?: (label: string) => void;
}

export function PlusMenu({ open, onClose, onAddFriend, onCreateGroup, onCreateJourney, onScan, onNote, onMoodDiary, onPlaceholder }: PlusMenuProps) {
  const [isVisible, setIsVisible] = useState(false);
  const [isEntering, setIsEntering] = useState(false);
  const closeTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    if (open) {
      setIsVisible(true);
      if (closeTimerRef.current) {
        clearTimeout(closeTimerRef.current);
        closeTimerRef.current = null;
      }
      requestAnimationFrame(() => {
        requestAnimationFrame(() => setIsEntering(true));
      });
    } else {
      setIsEntering(false);
      closeTimerRef.current = setTimeout(() => {
        setIsVisible(false);
      }, 260);
    }
    return () => {
      if (closeTimerRef.current) {
        clearTimeout(closeTimerRef.current);
      }
    };
  }, [open]);

  if (!isVisible) return null;

  return (
    <>
      {/* Gray transparent overlay */}
      <div
        className="fixed inset-0 z-[60] bg-gray-100/60 transition-opacity duration-250 ease-out pointer-events-auto"
        style={{ opacity: isEntering ? 1 : 0 }}
        onClick={onClose}
      />

      {/* Menu popup
          展开：ease-out 快速弹出；收起：ease-in 先慢后快，
          配合 transform-origin(top right) 呈现逐渐缩回加号位置的反向动画 */}
      <div
        className={cn(
          "absolute top-full right-0 mt-2 w-max bg-black rounded-2xl py-2.5 pointer-events-auto plus-menu-origin z-[80]",
          "transition-all duration-250",
          isEntering
            ? "ease-[cubic-bezier(0.16,1,0.3,1)]"
            : "ease-[cubic-bezier(0.55,0,0.85,0.36)]"
        )}
        style={{
          transform: isEntering ? "scale(1)" : "scale(0)",
          opacity: isEntering ? 1 : 0,
        }}
      >
        {/* Triangle pointer aligned to plus button center */}
        <div
          className="absolute -top-1.5 w-3 h-3 bg-black rotate-45"
          style={{ right: "14px" }}
        />

        <div className="relative">
          {menuItems.map((item, index) => {
            const Icon = item.icon;
            return (
              <button
                  key={item.key}
                  type="button"
                  className={cn(
                    "w-full flex items-center gap-3.5 px-5 py-3 text-left text-white/90 hover:text-white hover:bg-white/10 transition-colors",
                    index === 0 && "rounded-t-2xl",
                    index === menuItems.length - 1 && "rounded-b-2xl"
                  )}
                  onClick={() => {
                    if (item.key === "add") {
                      onAddFriend?.();
                    } else if (item.key === "create") {
                      onCreateGroup?.();
                    } else if (item.key === "journey") {
                      onCreateJourney?.();
                    } else if (item.key === "scan") {
                      onScan?.();
                    } else if (item.key === "note") {
                      onNote?.();
                    } else if (item.key === "mood") {
                      onMoodDiary?.();
                    } else {
                      // 暂未实现页面的功能项统一走占位提示
                      onPlaceholder?.(item.label);
                    }
                    onClose();
                  }}
                >
                  <Icon className="w-5 h-5" strokeWidth={1.8} />
                  <span className="text-base">{item.label}</span>
                </button>
            );
          })}
        </div>
      </div>
    </>
  );
}
