import { useEffect, useMemo } from "react";
import { ChatItem, ChatType } from "@/types/chat";
import { useChatStore } from "@/store/chatStore";
import { formatMessageTime } from "@/lib/utils";
import { MessageCard } from "./MessageCard";
import { PortenPartnerCard } from "./PortenPartnerCard";

interface MessageListProps {
  onChatClick?: (item: ChatItem) => void;
  onPartnerClick?: () => void;
}

function EmptyState() {
  return (
    <div className="flex flex-col items-center justify-center py-16 px-6">
      <p className="text-sm text-gray-400 text-center">暂无消息</p>
    </div>
  );
}

function parseSortTime(timeStr: string): number {
  if (!timeStr) return 0;
  const date = new Date(timeStr);
  return isNaN(date.getTime()) ? 0 : date.getTime();
}

export function MessageList({ onChatClick, onPartnerClick }: MessageListProps) {
  const conversations = useChatStore((state) => state.conversations);
  const loadConversations = useChatStore((state) => state.loadConversations);

  useEffect(() => {
    loadConversations();
  }, [loadConversations]);

  const items = useMemo(() => {
    const chatItems: ChatItem[] = conversations.map((c) => ({
      id: `${c.type}_${c.id}`,
      type: c.type as ChatType,
      name: c.name,
      avatar: c.avatar,
      lastMessage: c.last_message,
      lastMessageTime: formatMessageTime(c.last_message_time),
      timestamp: c.last_message_time || "",
      unreadCount: c.unread_count,
      memberCount: c.member_count,
      senderId: c.last_message_sender_id,
      senderName: c.last_message_sender_name,
    }));

    // Porten 伙伴入口在首页始终展示。
    const partnerItem: ChatItem = {
      id: "porten_partner",
      type: "system",
      name: "Porten伙伴",
      avatar: "/images/porten-partner.jpg",
      lastMessage: "",
      lastMessageTime: "",
      timestamp: "",
      unreadCount: 0,
    };

    return [...chatItems, partnerItem].sort(
      (a, b) => parseSortTime(b.timestamp) - parseSortTime(a.timestamp)
    );
  }, [conversations]);

  if (items.length === 0) {
    return <EmptyState />;
  }

  return (
    <div className="pb-2">
      {items.map((item) =>
        item.id === "porten_partner" ? (
          <PortenPartnerCard
            key={item.id}
            onClick={onPartnerClick}
          />
        ) : (
          <MessageCard key={item.id} item={item} onClick={onChatClick} />
        )
      )}
    </div>
  );
}
