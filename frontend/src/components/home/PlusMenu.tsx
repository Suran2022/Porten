import { useEffect, useState, useRef } from "react";
import { UserPlus, Users, StickyNote, Heart } from "lucide-react";
import { cn } from "@/lib/utils";

const menuItems = [
  { key: "add", label: "添加同胞/营地", icon: UserPlus },
  { key: "create", label: "创建营地", icon: Users },
  { key: "note", label: "记笔记", icon: StickyNote },
  { key: "mood", label: "情绪日记", icon: Heart },
];

interface PlusMenuProps {
  open: boolean;
  onClose: () => void;
  onAddFriend?: () => void;
  onCreateGroup?: () => void;
  onMoodDiary?: () => void;
}

export function PlusMenu({ open, onClose, onAddFriend, onCreateGroup, onMoodDiary }: PlusMenuProps) {
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

      {/* Menu popup */}
      <div
        className={cn(
          "absolute top-full right-0 mt-2 w-48 bg-black rounded-2xl py-2 pointer-events-auto plus-menu-origin z-[80]",
          "transition-all duration-250 ease-[cubic-bezier(0.16,1,0.3,1)]"
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
                    "w-full flex items-center gap-3 px-4 py-2.5 text-left text-white/90 hover:text-white hover:bg-white/10 transition-colors",
                    index === 0 && "rounded-t-2xl",
                    index === menuItems.length - 1 && "rounded-b-2xl"
                  )}
                  onClick={() => {
                    if (item.key === "add") {
                      onAddFriend?.();
                    } else if (item.key === "create") {
                      onCreateGroup?.();
                    } else if (item.key === "mood") {
                      onMoodDiary?.();
                    }
                    onClose();
                  }}
                >
                  <Icon className="w-4 h-4" strokeWidth={1.8} />
                  <span className="text-sm">{item.label}</span>
                </button>
            );
          })}
        </div>
      </div>
    </>
  );
}
