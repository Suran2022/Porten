import { MessageList } from "@/components/home/MessageList";
import { ChatItem } from "@/types/chat";

interface DesktopMessagesColumnProps {
  onChatOpen: (item: ChatItem) => void;
  onPartnerOpen: () => void;
}

/** 中间栏（消息视图）：仅会话列表，搜索与标题已合并到顶部栏。 */
export function DesktopMessagesColumn({
  onChatOpen,
  onPartnerOpen,
}: DesktopMessagesColumnProps) {
  return (
    <div className="h-full flex flex-col bg-white">
      <div className="flex-1 overflow-y-auto desktop-scroll">
        <MessageList
          onChatClick={onChatOpen}
          onPartnerClick={onPartnerOpen}
        />
      </div>
    </div>
  );
}
