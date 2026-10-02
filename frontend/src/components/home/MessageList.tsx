import { useEffect, useMemo } from "react";
import { ChatItem, ChatType } from "@/types/chat";
import { useChatStore } from "@/store/chatStore";
import { formatMessageTime } from "@/lib/utils";
import { MessageCard } from "./MessageCard";
import { PortenPartnerCard } from "./PortenPartnerCard";
import { TripAssistantCard } from "./TripAssistantCard";
import SwipeRow, { SwipeAction } from "@/components/common/SwipeRow";
import { HugeiconsIcon } from "@hugeicons/react";
import {
  EyeOffIcon,
  FavouriteIcon,
  PinIcon,
} from "@hugeicons/core-free-icons";

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

const ACTION_ICON_PROPS = { size: 20, strokeWidth: 2 } as const;

const SWIPE_ACTIONS: SwipeAction[] = [
  {
    id: "hide",
    label: "隐藏",
    icon: <HugeiconsIcon icon={EyeOffIcon} {...ACTION_ICON_PROPS} />,
    dismiss: true,
  },
  {
    id: "important",
    label: "重要",
    icon: <HugeiconsIcon icon={FavouriteIcon} {...ACTION_ICON_PROPS} />,
    color: "#f97316",
  },
  {
    id: "pin",
    label: "置顶",
    icon: <HugeiconsIcon icon={PinIcon} {...ACTION_ICON_PROPS} />,
    color: "#6b7280",
  },
];

export function MessageList({ onChatClick, onPartnerClick }: MessageListProps) {
  const conversations = useChatStore((state) => state.conversations);
  const loadConversations = useChatStore((state) => state.loadConversations);
  const pinnedIds = useChatStore((state) => state.pinnedIds);
  const importantIds = useChatStore((state) => state.importantIds);
  const hiddenIds = useChatStore((state) => state.hiddenIds);
  const togglePin = useChatStore((state) => state.togglePin);
  const toggleImportant = useChatStore((state) => state.toggleImportant);
  const hideConversation = useChatStore((state) => state.hideConversation);

  useEffect(() => {
    loadConversations();
  }, [loadConversations]);

  // 订阅 importantIds 以保证 setState 触发重渲染（暂时不用于视觉，仅用于响应状态变化）
  void importantIds;

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

    // 「我的旅程」功能入口在首页始终展示。
    const tripAssistantItem: ChatItem = {
      id: "trip_assistant",
      type: "system",
      name: "我的旅程",
      avatar: "",
      lastMessage: "",
      lastMessageTime: "",
      timestamp: "",
      unreadCount: 0,
    };

    const numericId = (item: ChatItem) =>
      Number(item.id.split("_")[1]);

    return [...chatItems, partnerItem, tripAssistantItem]
      .filter((item) => {
        if (item.type === "friend" || item.type === "group") {
          const id = numericId(item);
          if (!Number.isNaN(id) && hiddenIds.includes(id)) {
            return false;
          }
        }
        return true;
      })
      .sort((a, b) => {
        const aPinned =
          a.type === "friend" || a.type === "group"
            ? pinnedIds.includes(numericId(a))
            : false;
        const bPinned =
          b.type === "friend" || b.type === "group"
            ? pinnedIds.includes(numericId(b))
            : false;
        if (aPinned !== bPinned) return aPinned ? -1 : 1;
        return parseSortTime(b.timestamp) - parseSortTime(a.timestamp);
      });
  }, [conversations, pinnedIds, hiddenIds]);

  if (items.length === 0) {
    return <EmptyState />;
  }

  return (
    <div className="pb-2">
      {items.map((item) => {
        if (item.id === "porten_partner") {
          return (
            <PortenPartnerCard
              key={item.id}
              onClick={onPartnerClick}
            />
          );
        }

        if (item.id === "trip_assistant") {
          return <TripAssistantCard key={item.id} />;
        }

        const numericId = Number(item.id.split("_")[1]);

        return (
          <SwipeRow
            key={item.id}
            actions={SWIPE_ACTIONS}
            actionColor="#e5484d"
            drawerColor="#3f3f46"
            rowColor="#ffffff"
            textColor="#f5f5f5"
            height={72}
            radius={0}
            actionWidth={80}
            direction="left"
            snapBounce={0.2}
            resistance={0.55}
            collapseMs={200}
            commitAt={0.6}
            fullSwipe
            haptic
            label={item.name}
            onAction={(action) => {
              if (action.id === "pin") togglePin(numericId);
              else if (action.id === "important") toggleImportant(numericId);
            }}
            onCommit={(action) => {
              if (action.id === "hide") hideConversation(numericId);
            }}
          >
            <MessageCard item={item} onClick={onChatClick} />
          </SwipeRow>
        );
      })}
    </div>
  );
}