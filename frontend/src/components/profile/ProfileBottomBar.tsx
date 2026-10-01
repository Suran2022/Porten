import { useEffect } from "react";
import { Settings, Mail } from "lucide-react";
import { useSystemMessageStore } from "@/store/systemMessageStore";

interface ProfileBottomBarProps {
  onSettingsClick?: () => void;
  onSystemMessagesClick?: () => void;
}

/** 个人中心资料页底部栏：设置与系统消息（含未读红点）入口 */
export function ProfileBottomBar({
  onSettingsClick,
  onSystemMessagesClick,
}: ProfileBottomBarProps) {
  const unreadCount = useSystemMessageStore((state) => state.unreadCount);
  const loadUnreadCount = useSystemMessageStore(
    (state) => state.loadUnreadCount
  );

  useEffect(() => {
    loadUnreadCount();
  }, [loadUnreadCount]);

  return (
    <div className="flex-shrink-0 h-[4.6875rem] sm:h-[5.1875rem] w-full bg-white border-t border-gray-100 flex items-center justify-start px-4 sm:px-6">
      <button
        type="button"
        onClick={onSettingsClick}
        className="flex flex-col items-center gap-1 ml-[5px] text-gray-500 active:text-gray-700 transition-colors"
      >
        <Settings className="w-5 h-5 sm:w-6 sm:h-6" strokeWidth={1.6} />
        <span className="text-xs sm:text-sm">设置</span>
      </button>
      {/* 系统消息入口：仅在调用方提供回调时渲染（当前仅移动端使用） */}
      {onSystemMessagesClick ? (
        <button
          type="button"
          onClick={onSystemMessagesClick}
          className="relative flex flex-col items-center gap-1 ml-9 text-gray-500 active:text-gray-700 transition-colors"
        >
          <span className="relative">
            <Mail className="w-5 h-5 sm:w-6 sm:h-6" strokeWidth={1.6} />
            {unreadCount > 0 && (
              <span className="absolute -top-0.5 -right-1 w-2 h-2 rounded-full bg-red-500" />
            )}
          </span>
          <span className="text-xs sm:text-sm">系统消息</span>
        </button>
      ) : null}
    </div>
  );
}
