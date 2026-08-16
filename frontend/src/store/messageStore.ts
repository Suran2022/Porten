import { create } from "zustand";
import {
  getMessages,
  MessageItem,
  sendMessage,
  SendMessagePayload,
  uploadGenericFile,
  uploadImage,
  uploadVideo,
  uploadVoice,
  UploadResult,
} from "@/lib/api";
import {
  deleteMessage,
  deleteMessagesByIdExceptLocalId,
  getMessagesByConversation,
  saveMessage,
  saveMessages,
} from "@/lib/localMessageStore";
import {
  getCachedMediaUrl,
  saveMediaBlob,
} from "@/lib/mediaCacheStore";
import { Message, MessageStatus } from "@/types/message";
import { useAuthStore } from "./authStore";
import { useChatStore } from "./chatStore";
import { USE_MOCK } from "@/lib/mockMode";
import { onMockIncomingMessage } from "@/lib/mockEngine";
import type { MockMessage } from "@/data/mockServerData";

const API_WS_URL = import.meta.env.VITE_API_WS_URL || "ws://localhost:8000/ws";

/** 最近一次打开过的会话 id：mock 回复到达时若不在该会话中则累计未读。 */
let lastLoadedConversationId: number | null = null;

function previewForChatList(message: Message): string {
  if (message.type === "text") return message.content || "";
  if (message.type === "image") return "[图片]";
  if (message.type === "video") return "[视频]";
  if (message.type === "file") return message.content || "[文件]";
  if (message.type === "voice") return "[语音]";
  if (message.type === "system") return message.content || "";
  return "[消息]";
}

function updateConversationPreview(message: Message) {
  const conversations = useChatStore.getState().conversations;
  const index = conversations.findIndex((c) => c.id === message.conversationId);
  if (index === -1) return;

  const updated = { ...conversations[index] };
  updated.last_message = previewForChatList(message);
  updated.last_message_time = message.timestamp;

  const next = [...conversations];
  next.splice(index, 1);
  next.unshift(updated);
  useChatStore.setState({ conversations: next });
}

function generateLocalId(): string {
  return `${Date.now()}-${Math.random().toString(36).slice(2, 9)}`;
}

function mapApiToMessage(item: MessageItem, currentUserId: number): Message {
  const isMe = item.sender_id === currentUserId;
  const extra = (item.extra as Message["extra"]) || undefined;
  const duration =
    item.message_type === "voice"
      ? typeof extra?.duration === "number"
        ? extra.duration
        : typeof extra?.duration === "string"
          ? parseFloat(extra.duration) || undefined
          : undefined
      : undefined;
  const shareMeta =
    item.message_type === "share" && extra
      ? {
          shareType: (extra.share_type as "knowledge" | "resource") || "knowledge",
          title: (extra.title as string) || "",
          desc: extra.desc as string | undefined,
          cover: extra.cover as string | undefined,
          tags: extra.tags as string[] | undefined,
        }
      : undefined;
  const nameCardMeta =
    item.message_type === "nameCard" && extra
      ? {
          userId: String(extra.user_id ?? ""),
          nickname: (extra.nickname as string) || "",
          avatar: (extra.avatar as string) || "",
        }
      : undefined;
  return {
    localId: String(item.id),
    id: item.id,
    conversationId: item.conversation_id,
    type: item.message_type as Message["type"],
    content: item.content,
    extra,
    senderId: String(item.sender_id ?? 0),
    senderName: item.sender_nickname || "",
    senderAvatar: item.sender_avatar_url || "",
    timestamp: item.created_at,
    isMe,
    status: "sent",
    duration,
    shareMeta,
    nameCardMeta,
  };
}

interface MessageState {
  messagesByConversation: Record<number, Message[]>;
  connectionStatus: "closed" | "connecting" | "open";
  ws: WebSocket | null;
  reconnectTimer: number | null;

  // Load local then remote messages for a conversation
  loadMessages: (conversationId: number) => Promise<void>;
  // Replace/add a single message (used by optimistic send and push)
  addOrUpdateMessage: (conversationId: number, message: Message) => void;
  // Send a text message
  sendText: (conversationId: number, text: string) => Promise<void>;
  // Send media
  sendImage: (conversationId: number, file: File) => Promise<void>;
  sendVideo: (conversationId: number, file: File) => Promise<void>;
  sendFile: (conversationId: number, file: File) => Promise<void>;
  sendVoice: (conversationId: number, file: File, duration: number) => Promise<void>;
  // WebSocket lifecycle
  connect: () => void;
  disconnect: () => void;
}

function sortMessages(list: Message[]): Message[] {
  return [...list].sort(
    (a, b) => new Date(a.timestamp).getTime() - new Date(b.timestamp).getTime()
  );
}

async function maybeRestoreLocalMediaUrl(
  type: string,
  isMe: boolean,
  extra?: Message["extra"]
): Promise<Message["extra"] | undefined> {
  if (!isMe || !extra?.url) return extra;
  if (!["image", "video", "file", "voice"].includes(type)) return extra;
  const url = await getCachedMediaUrl(String(extra.url));
  return url === extra.url ? extra : { ...extra, url };
}

function shallowMessageEqual(a?: Message, b?: Message): boolean {
  if (a === b) return true;
  if (!a || !b) return false;
  if (
    a.localId !== b.localId ||
    a.id !== b.id ||
    a.conversationId !== b.conversationId ||
    a.type !== b.type ||
    a.content !== b.content ||
    a.senderId !== b.senderId ||
    a.senderName !== b.senderName ||
    a.senderAvatar !== b.senderAvatar ||
    a.timestamp !== b.timestamp ||
    a.isMe !== b.isMe ||
    a.status !== b.status ||
    a.progress !== b.progress
  ) {
    return false;
  }
  return JSON.stringify(a.extra) === JSON.stringify(b.extra);
}

function hasLocalBlobUrl(m: Message): boolean {
  const url = m.extra?.url || m.content;
  return typeof url === "string" && /^(blob:|data:)/i.test(url);
}

function dedupeMessagesByServerId(messages: Message[]): Message[] {
  const seen = new Map<number, Message>();
  const result: Message[] = [];
  for (const m of messages) {
    if (m.id == null) {
      result.push(m);
      continue;
    }
    const existing = seen.get(m.id);
    if (!existing) {
      seen.set(m.id, m);
      result.push(m);
      continue;
    }
    // Prefer the copy that carries a local blob URL (sender's cached media).
    if (hasLocalBlobUrl(m) && !hasLocalBlobUrl(existing)) {
      const idx = result.indexOf(existing);
      if (idx !== -1) result[idx] = m;
      seen.set(m.id, m);
    }
  }
  return result;
}

function findDuplicateLocalIds(messages: Message[]): string[] {
  const seen = new Map<number, Message>();
  const duplicates: string[] = [];
  for (const m of messages) {
    if (m.id == null) continue;
    const existing = seen.get(m.id);
    if (!existing) {
      seen.set(m.id, m);
      continue;
    }
    if (hasLocalBlobUrl(m) && !hasLocalBlobUrl(existing)) {
      duplicates.push(existing.localId);
      seen.set(m.id, m);
    } else {
      duplicates.push(m.localId);
    }
  }
  return duplicates;
}

function mergeMessages(
  existing: Message[],
  incoming: Message[]
): Message[] {
  const map = new Map<string, Message>();
  existing.forEach((m) => map.set(m.localId, m));
  incoming.forEach((m) => {
    const current = map.get(m.localId);
    // Merge incoming fields over existing so progress/status updates on the
    // same local message are applied, while server-confirmed messages still
    // overwrite local cached/pending copies.
    const merged: Message = current
      ? { ...current, ...m, localId: m.localId }
      : m;
    // Keep the old reference if nothing changed to avoid re-rendering
    // messages that are already correct.
    map.set(m.localId, shallowMessageEqual(current, merged) ? current : merged);
  });
  // Deduplicate by server id in case the same message was stored under
  // multiple localIds (e.g. optimistic send + WS push).
  return dedupeMessagesByServerId(sortMessages(Array.from(map.values())));
}

function extractVideoPoster(file: File): Promise<string | undefined> {
  return new Promise((resolve) => {
    const url = URL.createObjectURL(file);
    const video = document.createElement("video");
    video.muted = true;
    video.playsInline = true;
    video.preload = "metadata";
    let settled = false;
    const done = (result?: string) => {
      if (settled) return;
      settled = true;
      URL.revokeObjectURL(url);
      resolve(result);
    };
    video.onloadedmetadata = () => {
      if (!video.videoWidth || !video.videoHeight) {
        done();
        return;
      }
      video.currentTime = 0.1;
    };
    video.onseeked = () => {
      const canvas = document.createElement("canvas");
      canvas.width = video.videoWidth;
      canvas.height = video.videoHeight;
      const ctx = canvas.getContext("2d");
      if (!ctx) {
        done();
        return;
      }
      ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
      try {
        done(canvas.toDataURL("image/jpeg", 0.8));
      } catch {
        done();
      }
    };
    video.onerror = () => done();
    video.src = url;
    video.load();
    setTimeout(() => done(), 5000);
  });
}

export const useMessageStore = create<MessageState>((set, get) => ({
  messagesByConversation: {},
  connectionStatus: "closed",
  ws: null,
  reconnectTimer: null,

  loadMessages: async (conversationId) => {
    // 记录当前打开的会话：mock 引擎的"对方回复"到达时，
    // 不在该会话中的新消息才累计未读。
    lastLoadedConversationId = conversationId;

    const currentUser = useAuthStore.getState().user;
    if (!currentUser) return;

    let localMessages: Message[] = [];

    // 1. Load local messages first for instant display.
    try {
      const local = await getMessagesByConversation(conversationId);
      localMessages = await Promise.all(
        local.map(async (m) => {
          const senderId = String(m.senderId ?? 0);
          const isMe = m.isMe ?? senderId === String(currentUser.id);
          const extra = await maybeRestoreLocalMediaUrl(
            m.type,
            isMe,
            m.extra as Message["extra"]
          );
          const rawDuration =
            m.duration ?? (m.extra as Message["extra"])?.duration;
          const duration =
            m.type === "voice"
              ? typeof rawDuration === "number"
                ? rawDuration
                : typeof rawDuration === "string"
                  ? parseFloat(rawDuration) || undefined
                  : undefined
              : undefined;
          return {
            localId: m.localId,
            id: m.id,
            conversationId: m.conversationId,
            type: m.type as Message["type"],
            content: m.content,
            extra,
            senderId: m.senderId,
            senderName: m.senderName,
            senderAvatar: m.senderAvatar,
            timestamp: m.timestamp,
            isMe,
            status: (m.status as MessageStatus) || "sent",
            progress: m.progress,
            duration,
          };
        })
      );

      // Remove duplicate server messages that may have accumulated in IndexedDB
      // (e.g. from previous WS pushes or merges with different localIds).
      const duplicateLocalIds = findDuplicateLocalIds(localMessages);
      if (duplicateLocalIds.length > 0) {
        await Promise.all(duplicateLocalIds.map((lid) => deleteMessage(lid)));
        localMessages = localMessages.filter(
          (m) => !duplicateLocalIds.includes(m.localId)
        );
      }

      set((state) => ({
        messagesByConversation: {
          ...state.messagesByConversation,
          [conversationId]: mergeMessages(
            state.messagesByConversation[conversationId] || [],
            localMessages
          ),
        },
      }));
    } catch {
      // Local storage not available.
    }

    // 2. Fetch the latest server page and merge it over the local copy.
    // Messages that are unchanged keep their object reference, so React will
    // not re-render them and the list will not flicker or jump.
    try {
      const items = await getMessages(conversationId);
      if (!items.length) return;

      const localIdByServerId = new Map(
        localMessages
          .filter((m): m is Message & { id: number } => m.id != null)
          .map((m) => [m.id, m.localId])
      );

      const serverMessages = items.map((item) => {
        const m = mapApiToMessage(item, currentUser.id);
        // If a local copy of this server message already exists (e.g. the
        // optimistic send was saved with a generated localId), reuse that
        // localId so mergeMessages treats them as the same message instead of
        // creating a duplicate.
        if (m.id != null && localIdByServerId.has(m.id)) {
          m.localId = localIdByServerId.get(m.id)!;
        }
        return m;
      });

      // Persist the original server URLs; the in-memory state may use local
      // blob URLs for the sender's own media, but storage must keep cloud
      // URLs so they can be resolved again after a page refresh.
      await saveMessages(
        serverMessages.map((m) => ({
          localId: m.localId,
          id: m.id,
          conversationId: m.conversationId,
          type: m.type,
          content: m.content,
          extra: m.extra,
          senderId: m.senderId,
          senderName: m.senderName,
          senderAvatar: m.senderAvatar,
          timestamp: m.timestamp,
          isMe: m.isMe,
          status: m.status,
        }))
      );

      // Remove any IndexedDB entries that share the same server id but use a
      // different localId (can happen after previous saves used the server id
      // as the key).
      await Promise.all(
        serverMessages.map((m) => {
          if (m.id == null) return Promise.resolve();
          return deleteMessagesByIdExceptLocalId(m.id, m.localId);
        })
      );

      // Build the display copy: replace cloud URLs with locally cached blob
      // URLs for the sender's own media so they appear instantly.
      const displayMessages = await Promise.all(
        serverMessages.map(async (m) => ({
          ...m,
          extra: await maybeRestoreLocalMediaUrl(m.type, m.isMe, m.extra),
        }))
      );

      set((state) => ({
        messagesByConversation: {
          ...state.messagesByConversation,
          [conversationId]: mergeMessages(
            state.messagesByConversation[conversationId] || [],
            displayMessages
          ),
        },
      }));
    } catch {
      // Keep local messages if server fails.
    }
  },

  addOrUpdateMessage: (conversationId, message) => {
    set((state) => {
      const list = state.messagesByConversation[conversationId] || [];
      return {
        messagesByConversation: {
          ...state.messagesByConversation,
          [conversationId]: mergeMessages(list, [message]),
        },
      };
    });
  },

  sendText: async (conversationId, text) => {
    const currentUser = useAuthStore.getState().user;
    if (!currentUser) return;

    const localId = generateLocalId();
    const optimistic: Message = {
      localId,
      conversationId,
      type: "text",
      content: text,
      senderId: String(currentUser.id),
      senderName: currentUser.nickname,
      senderAvatar: currentUser.avatar,
      timestamp: new Date().toISOString(),
      isMe: true,
      status: "sending",
    };

    get().addOrUpdateMessage(conversationId, optimistic);
    await saveMessage({
      localId,
      conversationId,
      type: "text",
      content: text,
      senderId: String(currentUser.id),
      senderName: currentUser.nickname,
      senderAvatar: currentUser.avatar,
      timestamp: optimistic.timestamp,
      isMe: true,
      status: "sending",
    });

    try {
      const item = await sendMessage({
        conversation_id: conversationId,
        message_type: "text",
        content: text,
      });
      const confirmed = mapApiToMessage(item, currentUser.id);
      confirmed.localId = localId;
      get().addOrUpdateMessage(conversationId, confirmed);
      updateConversationPreview(confirmed);
      await deleteMessage(localId);
      await saveMessage({
        localId,
        id: confirmed.id,
        conversationId: confirmed.conversationId,
        type: confirmed.type,
        content: confirmed.content,
        extra: confirmed.extra,
        senderId: confirmed.senderId,
        senderName: confirmed.senderName,
        senderAvatar: confirmed.senderAvatar,
        timestamp: confirmed.timestamp,
        isMe: confirmed.isMe,
        status: "sent",
      });
    } catch {
      get().addOrUpdateMessage(conversationId, { ...optimistic, status: "failed" });
      await saveMessage({
        localId,
        conversationId,
        type: "text",
        content: text,
        senderId: String(currentUser.id),
        senderName: currentUser.nickname,
        senderAvatar: currentUser.avatar,
        timestamp: optimistic.timestamp,
        isMe: true,
        status: "failed",
      });
    }
  },

  sendImage: async (conversationId, file) => {
    await sendMedia(conversationId, file, "image", uploadImage);
  },
  sendVideo: async (conversationId, file) => {
    await sendMedia(conversationId, file, "video", uploadVideo);
  },
  sendFile: async (conversationId, file) => {
    await sendMedia(conversationId, file, "file", uploadGenericFile);
  },
  sendVoice: async (conversationId, file, duration) => {
    await sendVoiceMessage(conversationId, file, duration);
  },

  connect: () => {
    // Mock 模式：无需真实 WebSocket，直接跳过连接与重连。
    if (USE_MOCK) return;
    const token = useAuthStore.getState().token;
    if (!token) return;
    if (get().ws?.readyState === WebSocket.OPEN) return;

    set({ connectionStatus: "connecting" });
    const ws = new WebSocket(`${API_WS_URL}?token=${token}`);

    ws.onopen = () => {
      set({ connectionStatus: "open", ws, reconnectTimer: null });
    };

    ws.onmessage = (event) => {
      try {
        const payload = JSON.parse(event.data);
        if (payload.type === "new_message" && payload.data) {
          const currentUser = useAuthStore.getState().user;
          if (!currentUser) return;
          const item = payload.data as MessageItem;
          // Ignore messages sent by the current user: the optimistic send path
          // already keeps the local blob URL, and the WS version would overwrite
          // it with the server URL and cause a reload / loss of autoplay.
          if (item.sender_id === currentUser.id) return;
          const message = mapApiToMessage(item, currentUser.id);
          message.localId = String(item.id);
          get().addOrUpdateMessage(item.conversation_id, message);
          updateConversationPreview(message);
          saveMessage({
            localId: String(message.id),
            id: message.id,
            conversationId: message.conversationId,
            type: message.type,
            content: message.content,
            extra: message.extra,
            senderId: message.senderId,
            senderName: message.senderName,
            senderAvatar: message.senderAvatar,
            timestamp: message.timestamp,
            isMe: message.isMe,
            status: "sent",
          }).catch(() => {});
        }
      } catch {
        // ignore malformed messages
      }
    };

    ws.onclose = () => {
      set({ connectionStatus: "closed", ws: null });
      // Reconnect after 3s
      if (get().reconnectTimer) return;
      const timer = window.setTimeout(() => {
        get().connect();
      }, 3000);
      set({ reconnectTimer: timer });
    };

    ws.onerror = () => {
      ws.close();
    };

    set({ ws });
  },

  disconnect: () => {
    const { ws, reconnectTimer } = get();
    if (reconnectTimer) {
      window.clearTimeout(reconnectTimer);
    }
    if (ws) {
      ws.onclose = null;
      ws.close();
    }
    set({ ws: null, connectionStatus: "closed", reconnectTimer: null });
  },
}));

async function sendVoiceMessage(
  conversationId: number,
  file: File,
  duration: number
) {
  const currentUser = useAuthStore.getState().user;
  if (!currentUser) return;

  const localId = generateLocalId();
  const objectUrl = URL.createObjectURL(file);

  const optimistic: Message = {
    localId,
    conversationId,
    type: "voice",
    content: "",
    extra: {
      url: objectUrl,
      name: file.name,
      size: file.size,
    },
    senderId: String(currentUser.id),
    senderName: currentUser.nickname,
    senderAvatar: currentUser.avatar,
    timestamp: new Date().toISOString(),
    isMe: true,
    status: "sending",
    duration,
  };

  const store = useMessageStore.getState();
  store.addOrUpdateMessage(conversationId, optimistic);
  await saveMessage({
    localId,
    conversationId,
    type: "voice",
    content: "",
    extra: optimistic.extra,
    senderId: String(currentUser.id),
    senderName: currentUser.nickname,
    senderAvatar: currentUser.avatar,
    timestamp: optimistic.timestamp,
    isMe: true,
    status: "sending",
  });

  try {
    const uploaded = await uploadVoice(file);

    try {
      await saveMediaBlob(uploaded.url, file);
    } catch {
      // Cache failure should not block sending.
    }

    const payload: SendMessagePayload = {
      conversation_id: conversationId,
      message_type: "voice",
      content: "",
      extra: {
        url: uploaded.url,
        name: uploaded.name,
        size: uploaded.size,
        duration,
      },
      media_file_id: uploaded.media_file_id,
    };

    const item = await sendMessage(payload);
    const confirmed = mapApiToMessage(item, currentUser.id);
    confirmed.localId = localId;
    confirmed.duration = duration;
    confirmed.extra = { ...confirmed.extra, url: objectUrl, duration };
    store.addOrUpdateMessage(conversationId, confirmed);
    updateConversationPreview(confirmed);
    await deleteMessage(localId);
    await saveMessage({
      localId,
      id: confirmed.id,
      conversationId: confirmed.conversationId,
      type: confirmed.type,
      content: confirmed.content,
      extra: { url: uploaded.url, name: uploaded.name, size: uploaded.size, duration },
      senderId: confirmed.senderId,
      senderName: confirmed.senderName,
      senderAvatar: confirmed.senderAvatar,
      timestamp: confirmed.timestamp,
      isMe: confirmed.isMe,
      status: "sent",
      duration,
    });
  } catch (err) {
    console.error("send voice failed:", err);
    URL.revokeObjectURL(objectUrl);
    store.addOrUpdateMessage(conversationId, {
      ...optimistic,
      status: "failed",
    });
    await saveMessage({
      localId,
      conversationId,
      type: "voice",
      content: "",
      extra: optimistic.extra,
      senderId: String(currentUser.id),
      senderName: currentUser.nickname,
      senderAvatar: currentUser.avatar,
      timestamp: optimistic.timestamp,
      isMe: true,
      status: "failed",
      duration,
    });
  }
}

async function sendMedia(
  conversationId: number,
  file: File,
  messageType: "image" | "video" | "file",
  uploader: (file: File, onProgress: (p: number) => void) => Promise<UploadResult>
) {
  const currentUser = useAuthStore.getState().user;
  if (!currentUser) return;

  const localId = generateLocalId();
  const isVideo = messageType === "video";

  let poster: string | undefined;
  if (isVideo) {
    poster = await extractVideoPoster(file);
  }

  const objectUrl = URL.createObjectURL(file);

  const optimistic: Message = {
    localId,
    conversationId,
    type: messageType,
    content: messageType === "file" ? file.name : objectUrl,
    extra: {
      url: objectUrl,
      name: file.name,
      size: file.size,
      ...(poster ? { poster } : {}),
    },
    senderId: String(currentUser.id),
    senderName: currentUser.nickname,
    senderAvatar: currentUser.avatar,
    timestamp: new Date().toISOString(),
    isMe: true,
    status: "sending",
    progress: 0,
  };

  const store = useMessageStore.getState();
  store.addOrUpdateMessage(conversationId, optimistic);
  await saveMessage({
    localId,
    conversationId,
    type: messageType,
    content: optimistic.content,
    extra: optimistic.extra,
    senderId: String(currentUser.id),
    senderName: currentUser.nickname,
    senderAvatar: currentUser.avatar,
    timestamp: optimistic.timestamp,
    isMe: true,
    status: "sending",
    progress: 0,
  });

  try {
    const uploaded = await uploader(file, (progress) => {
      store.addOrUpdateMessage(conversationId, {
        ...optimistic,
        progress,
      });
    });

    // Persist the original file locally so the sender can view the media
    // from cache instead of re-downloading it from the server later.
    try {
      await saveMediaBlob(uploaded.url, file);
    } catch {
      // Cache failure should not block sending.
    }

    const payload: SendMessagePayload = {
      conversation_id: conversationId,
      message_type: messageType,
      content: messageType === "file" ? uploaded.name || file.name : "",
      extra: {
        url: uploaded.url,
        thumb_url: uploaded.thumb_url || undefined,
        name: uploaded.name,
        size: uploaded.size,
      },
      media_file_id: uploaded.media_file_id,
    };

    const item = await sendMessage(payload);
    const confirmed = mapApiToMessage(item, currentUser.id);
    confirmed.localId = localId;
    if (isVideo && poster && confirmed.extra) {
      confirmed.extra = { ...confirmed.extra, poster };
    }
    // Keep the local blob URL in the current session so the sender sees the
    // media immediately without waiting for the server URL to load again.
    // This also prevents the video from reloading so auto-play can work.
    confirmed.extra = { ...confirmed.extra, url: objectUrl };
    if (messageType !== "file") {
      confirmed.content = optimistic.content;
    }
    store.addOrUpdateMessage(conversationId, confirmed);
    updateConversationPreview(confirmed);
    await deleteMessage(localId);
    await saveMessage({
      localId,
      id: confirmed.id,
      conversationId: confirmed.conversationId,
      type: confirmed.type,
      content: item.content,
      extra: { url: uploaded.url, name: uploaded.name, size: uploaded.size },
      senderId: confirmed.senderId,
      senderName: confirmed.senderName,
      senderAvatar: confirmed.senderAvatar,
      timestamp: confirmed.timestamp,
      isMe: confirmed.isMe,
      status: "sent",
    });
  } catch {
    URL.revokeObjectURL(objectUrl);
    store.addOrUpdateMessage(conversationId, {
      ...optimistic,
      status: "failed",
      progress: undefined,
    });
    await saveMessage({
      localId,
      conversationId,
      type: messageType,
      content: optimistic.content,
      extra: optimistic.extra,
      senderId: String(currentUser.id),
      senderName: currentUser.nickname,
      senderAvatar: currentUser.avatar,
      timestamp: optimistic.timestamp,
      isMe: true,
      status: "failed",
    });
  }
}

/* ============================= Mock 消息订阅 ============================= */

if (USE_MOCK) {
  onMockIncomingMessage((msg: MockMessage) => {
    const message: Message = {
      localId: String(msg.id),
      id: msg.id,
      conversationId: msg.conversationId,
      type: msg.type as Message["type"],
      content: msg.content,
      extra: msg.extra as Message["extra"],
      senderId: msg.senderId,
      senderName: msg.senderName,
      senderAvatar: msg.senderAvatar,
      timestamp: msg.timestamp,
      isMe: false,
      status: "sent",
      duration: msg.duration,
    };

    useMessageStore.getState().addOrUpdateMessage(msg.conversationId, message);
    updateConversationPreview(message);
    saveMessage({
      localId: String(msg.id),
      id: msg.id,
      conversationId: msg.conversationId,
      type: msg.type,
      content: msg.content,
      extra: msg.extra as Record<string, unknown>,
      senderId: msg.senderId,
      senderName: msg.senderName,
      senderAvatar: msg.senderAvatar,
      timestamp: msg.timestamp,
      isMe: false,
      status: "sent",
    }).catch(() => {});

    // 回复不在当前打开的会话中 → 未读角标 +1。
    if (msg.conversationId !== lastLoadedConversationId) {
      useChatStore.setState((state) => ({
        conversations: state.conversations.map((c) =>
          c.id === msg.conversationId
            ? { ...c, unread_count: (c.unread_count || 0) + 1 }
            : c
        ),
      }));
    }
  });
}
