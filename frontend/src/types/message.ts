export type MessageType =
  | "text"
  | "voice"
  | "call"
  | "image"
  | "video"
  | "file"
  | "share"
  | "link"
  | "nameCard"
  | "system";

export type MessageStatus = "sending" | "sent" | "failed";

export interface CallMeta {
  callType: "audio" | "video";
  result: "connected" | "missed" | "rejected";
  duration?: string;
}

export interface FileMeta {
  fileName: string;
  fileSize: string;
  fileType: string;
  status: "sending" | "sent" | "failed";
  progress?: number;
  url?: string;
}

export interface ShareMeta {
  shareType: "knowledge" | "resource";
  title: string;
  desc?: string;
  cover?: string;
  tags?: string[];
}

export interface NameCardMeta {
  userId: string;
  nickname: string;
  avatar: string;
}

export interface MessageExtra {
  url?: string;
  thumb_url?: string;
  width?: number;
  height?: number;
  name?: string;
  size?: number;
  [key: string]: unknown;
}

export interface Message {
  // local unique id used before server ack (and as React key)
  localId: string;
  // server id after ack
  id?: number;
  conversationId: number;
  type: MessageType;
  content: string;
  extra?: MessageExtra;
  senderId: string;
  senderName: string;
  senderAvatar: string;
  timestamp: string;
  isMe: boolean;
  status?: MessageStatus;
  progress?: number;
  duration?: number;
  callMeta?: CallMeta;
  fileMeta?: FileMeta;
  shareMeta?: ShareMeta;
  nameCardMeta?: NameCardMeta;
}
