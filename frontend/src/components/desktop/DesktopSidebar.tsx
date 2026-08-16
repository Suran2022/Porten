import { useState } from "react";
import {
  BookOpen,
  FolderOpen,
  MessageSquare,
  Music2,
  Settings,
  Users,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { currentUser } from "@/data/mock";
import { useAuthStore } from "@/store/authStore";
import { useChatStore } from "@/store/chatStore";
import { useContactStore } from "@/store/contactStore";
import { getMoodOption } from "@/types/emotionDiary";

export type DesktopNavKey =
  | "messages"
  | "contacts"
  | "resources"
  | "knowledge";

interface DesktopSidebarProps {
  active: DesktopNavKey;
  onNavChange: (key: DesktopNavKey) => void;
  onProfileOpen: () => void;
  onSettingsOpen: () => void;
  onMusicOpen: () => void;
  /** 应用栏管理中是否开启"悦音乐"入口（与移动端底部菜单一致） */
  showMusic?: boolean;
}

const navItems: { key: DesktopNavKey | "music"; label: string; icon: typeof MessageSquare }[] = [
  { key: "messages", label: "消息", icon: MessageSquare },
  { key: "contacts", label: "联系人", icon: Users },
  { key: "resources", label: "资源", icon: FolderOpen },
  { key: "knowledge", label: "知识", icon: BookOpen },
  { key: "music", label: "悦音乐", icon: Music2 },
];

export function DesktopSidebar({
  active,
  onNavChange,
  onProfileOpen,
  onSettingsOpen,
  onMusicOpen,
  showMusic = false,
}: DesktopSidebarProps) {
  const [bouncingKey, setBouncingKey] = useState<string | null>(null);

  const { user } = useAuthStore();
  const conversations = useChatStore((state) => state.conversations);
  const totalUnread = conversations.reduce((sum, c) => sum + (c.unread_count || 0), 0);
  const badge = useContactStore((state) => state.badge);
  const contactBadge = badge.friend_requests + badge.group_requests;

  const avatarUrl = user?.avatar || currentUser.avatar;
  const nickname = user?.nickname || currentUser.nickname;
  const moodOption = getMoodOption(user?.mood);
  const mood = moodOption
    ? `${moodOption.emoji} ${moodOption.label}`
    : currentUser.mood;

  const handleNavClick = (key: DesktopNavKey | "music") => {
    setBouncingKey(key);
    window.setTimeout(() => setBouncingKey(null), 300);
    if (key === "music") {
      onMusicOpen();
      return;
    }
    onNavChange(key);
  };

  return (
    <aside className="relative z-20 w-[84px] shrink-0 h-full bg-white flex flex-col items-center py-4">
      {/* 个人信息卡片（PC 版：紧凑头像 + 昵称 + 心情） */}
      <button
        type="button"
        onClick={onProfileOpen}
        className="flex flex-col items-center w-full px-2 group"
      >
        <span className="relative block">
          <img
            src={avatarUrl}
            alt={nickname}
            className="w-11 h-11 rounded-full object-cover bg-gray-100 transition-opacity duration-200 group-hover:opacity-90"
          />
        </span>
        <span className="mt-1.5 w-full text-center text-xs font-medium text-gray-900 truncate">
          {nickname}
        </span>
        <span className="mt-0.5 w-full text-center text-[10px] text-gray-400 truncate">
          {mood}
        </span>
      </button>

      {/* 导航（对应移动端底部菜单栏，选中无背景色） */}
      <nav className="mt-5 w-full flex-1 flex flex-col items-center gap-1.5 px-2">
        {navItems
          .filter((item) => item.key !== "music" || showMusic)
          .map((item) => {
            const isActive = item.key === active;
            const Icon = item.icon;
            const showBadge =
              (item.key === "messages" && totalUnread > 0) ||
              (item.key === "contacts" && contactBadge > 0);
            const badgeCount =
              item.key === "messages" ? totalUnread : contactBadge;
            return (
              <button
                key={item.key}
                type="button"
                onClick={() => handleNavClick(item.key)}
                className="relative w-full flex flex-col items-center gap-1 py-2.5 rounded-2xl"
              >
                <span
                  className={cn(
                    "relative inline-block",
                    bouncingKey === item.key && "animate-bounce-icon"
                  )}
                >
                  <Icon
                    className="w-6 h-6 transition-all duration-300"
                    color={
                      isActive
                        ? `url(#desktopIconGradient-${item.key})`
                        : "#9ca3af"
                    }
                    strokeWidth={1.8}
                  >
                    {isActive && (
                      <defs>
                        <linearGradient
                          id={`desktopIconGradient-${item.key}`}
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
                      {badgeCount > 99 ? "99+" : badgeCount}
                    </span>
                  )}
                </span>
                <span
                  className={cn(
                    "text-[11px] leading-none whitespace-nowrap transition-all duration-300",
                    isActive ? "porten-gradient font-medium" : "text-gray-400"
                  )}
                >
                  {item.label}
                </span>
              </button>
            );
          })}
      </nav>

      {/* 设置（第一栏底部） */}
      <button
        type="button"
        onClick={onSettingsOpen}
        className="w-full flex flex-col items-center gap-1 py-2.5 rounded-2xl hover:bg-gray-50 transition-colors duration-300"
        aria-label="设置"
      >
        <Settings className="w-6 h-6 text-gray-400" strokeWidth={1.8} />
        <span className="text-[11px] leading-none text-gray-400">设置</span>
      </button>
    </aside>
  );
}
