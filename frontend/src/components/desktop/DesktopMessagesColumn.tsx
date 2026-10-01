import { SearchBar } from "@/components/home/SearchBar";
import { MessageList } from "@/components/home/MessageList";
import { ChatItem } from "@/types/chat";

interface DesktopMessagesColumnProps {
  onChatOpen: (item: ChatItem) => void;
  onPartnerOpen: () => void;
  onSearchOpen: () => void;
}

/** 中间栏（消息视图）：顶部搜索框 + 会话列表，标题由独立顶部栏承担。 */
export function DesktopMessagesColumn({
  onChatOpen,
  onPartnerOpen,
  onSearchOpen,
}: DesktopMessagesColumnProps) {
  return (
    <div className="h-full flex flex-col bg-white">
      <div className="shrink-0">
        <SearchBar onClick={onSearchOpen} />
      </div>
      <div className="flex-1 overflow-y-auto desktop-scroll">
        <MessageList
          onChatClick={onChatOpen}
          onPartnerClick={onPartnerOpen}
        />
      </div>
    </div>
  );
}
