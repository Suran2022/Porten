import { useState } from "react";
import { MessageSquare, FolderOpen, BookOpen, Music2 } from "lucide-react";
import { cn } from "@/lib/utils";
import { useChatStore } from "@/store/chatStore";

const baseTabs = [
  { key: "messages", label: "消息", icon: MessageSquare },
  { key: "resources", label: "资源", icon: FolderOpen },
  { key: "knowledge", label: "知识", icon: BookOpen },
];

const musicTab = { key: "music", label: "悦音乐", icon: Music2 };

interface BottomNavProps {
  activeIndex: number;
  onChange: (index: number) => void;
  showMusic?: boolean;
  onMusicClick?: () => void;
}

export function BottomNav({ activeIndex, onChange, showMusic = false, onMusicClick }: BottomNavProps) {
  const [bouncingIndex, setBouncingIndex] = useState<number | null>(null);
  const conversations = useChatStore((state) => state.conversations);
  const totalUnread = conversations.reduce((sum, c) => sum + (c.unread_count || 0), 0);

  const tabs = showMusic ? [...baseTabs, musicTab] : baseTabs;

  const handleClick = (index: number) => {
    const tab = tabs[index];
    if (tab?.key === "music") {
      onMusicClick?.();
      setBouncingIndex(index);
      setTimeout(() => setBouncingIndex(null), 300);
      return;
    }
    if (index === activeIndex) return;
    onChange(index);
    setBouncingIndex(index);
    setTimeout(() => setBouncingIndex(null), 300);
  };

  return (
    <nav className="fixed bottom-0 left-0 right-0 z-50 bg-white h-16">
      <div className="max-w-md mx-auto h-full px-2 flex items-center justify-around gap-1">
          {tabs.map((tab, index) => {
            const isActive = index === activeIndex;
            const Icon = tab.icon;
            const showBadge = tab.key === "messages" && totalUnread > 0;
            return (
              <button
                key={tab.key}
                type="button"
                onClick={() => handleClick(index)}
                className="flex flex-col items-center gap-0.5 py-1.5 px-2 rounded-xl transition-colors duration-300 min-w-0"
              >
                <span
                  className={cn(
                    "relative inline-block",
                    bouncingIndex === index && "animate-bounce-icon"
                  )}
                >
                  <Icon
                    className="w-6 h-6 transition-all duration-300"
                    color={
                      isActive
                        ? `url(#portenIconGradient-${tab.key})`
                        : "#9ca3af"
                    }
                    strokeWidth={1.8}
                  >
                    {isActive && (
                      <defs>
                        <linearGradient
                          id={`portenIconGradient-${tab.key}`}
                          gradientUnits="userSpaceOnUse"
                          x1="0"
                          y1="12"
                          x2="24"
                          y2="12"
                        >
                          <stop offset="0" stopColor="#5BCEFA" />
                          <stop offset="1" stopColor="#F5A9B8" />
                        </linearGradient>
                      </defs>
                    )}
                  </Icon>
                  {showBadge && (
                    <span className="absolute -top-1 -right-2 min-w-[1rem] h-4 px-1 rounded-full bg-red-500 text-white text-[10px] font-medium flex items-center justify-center">
                      {totalUnread > 99 ? "99+" : totalUnread}
                    </span>
                  )}
                </span>
                <span
                  className={cn(
                    "text-xs leading-none transition-all duration-300 whitespace-nowrap",
                    isActive ? "porten-gradient font-medium" : "text-gray-400"
                  )}
                >
                  {tab.label}
                </span>
              </button>
            );
          })}
      </div>
    </nav>
  );
}
