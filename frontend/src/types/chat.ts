export type ChatType = "friend" | "group" | "system";

export interface ChatItem {
  id: string;
  type: ChatType;
  name: string;
  avatar?: string;
  lastMessage: string;
  lastMessageTime: string;
  timestamp: string;
  unreadCount: number;
  memberCount?: number;
  senderId?: number;
  senderName?: string;
  assistantTitle?: string;
}

export interface UserProfile {
  id: string;
  nickname: string;
  avatar: string;
  mood: string;
}
