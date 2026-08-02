import { ChatItem } from "@/types/chat";
import { cn } from "@/lib/utils";
import { Bot } from "lucide-react";
import { useAuthStore } from "@/store/authStore";
import { CampAvatar } from "./CampAvatar";

interface MessageCardProps {
  item: ChatItem;
  onClick?: (item: ChatItem) => void;
}

export function MessageCard({ item, onClick }: MessageCardProps) {
  const currentUser = useAuthStore((state) => state.user);
  const currentUserId = currentUser?.id != null ? String(currentUser.id) : null;
  const isLastMessageFromMe =
    item.senderId != null && String(item.senderId) === currentUserId;

  const displayLastMessage = () => {
    if (
      item.type === "group" &&
      item.senderName &&
      !isLastMessageFromMe
    ) {
      return `${item.senderName}: ${item.lastMessage}`;
    }
    if (item.type === "system" && item.assistantTitle) {
      return `${item.assistantTitle}: ${item.lastMessage}`;
    }
    return item.lastMessage;
  };

  return (
    <div
      className="flex items-center gap-3 px-4 py-3 bg-white active:bg-gray-50/50 transition-colors cursor-pointer"
      onClick={() => onClick?.(item)}
    >
      <div className="relative flex-shrink-0">
        {item.type === "group" ? (
          <CampAvatar src={item.avatar} name={item.name} size={48} />
        ) : item.avatar ? (
          <img
            src={item.avatar}
            alt={item.name}
            className="w-12 h-12 rounded-full object-cover bg-gray-100"
          />
        ) : (
          <div className="w-12 h-12 rounded-full bg-gray-100 flex items-center justify-center">
            <Bot className="w-6 h-6 text-gray-400" strokeWidth={1.8} />
          </div>
        )}
      </div>

      <div className="flex-1 min-w-0">
        <div className="flex items-center justify-between gap-2">
          <h3 className="text-base font-medium text-gray-900 truncate">
            {item.name}
          </h3>
          {item.unreadCount > 0 && (
            <span className="flex-shrink-0 min-w-[1.25rem] h-5 px-1 rounded-full bg-red-500 text-white text-xs font-medium flex items-center justify-center">
              {item.unreadCount > 99 ? "99+" : item.unreadCount}
            </span>
          )}
        </div>
        <div className="flex items-end justify-between gap-2 mt-0.5">
          <p className="text-sm text-gray-500 truncate flex-1">
            {displayLastMessage()}
          </p>
          <span className="flex-shrink-0 text-xs text-gray-400">
            {item.lastMessageTime}
          </span>
        </div>
      </div>
    </div>
  );
}
