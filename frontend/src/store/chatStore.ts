import { create } from "zustand";
import {
  fetchConversations,
  markConversationRead,
  ConversationItem,
} from "@/lib/api";
import {
  getConversations,
  saveConversations,
} from "@/lib/localConversationStore";

interface ChatState {
  conversations: ConversationItem[];
  loading: boolean;

  loadConversations: () => Promise<void>;
  markRead: (conversationId: number) => Promise<void>;
}

function shallowEqualConversations(
  a: ConversationItem[],
  b: ConversationItem[]
): boolean {
  if (a === b) return true;
  if (a.length !== b.length) return false;
  return a.every((item, i) => {
    const other = b[i];
    return (
      item.id === other.id &&
      item.type === other.type &&
      item.name === other.name &&
      item.avatar === other.avatar &&
      item.last_message === other.last_message &&
      item.last_message_time === other.last_message_time &&
      item.unread_count === other.unread_count
    );
  });
}

export const useChatStore = create<ChatState>((set, get) => ({
  conversations: [],
  loading: false,

  loadConversations: async () => {
    set({ loading: true });

    // 1. Show local cache instantly.
    try {
      const cached = await getConversations();
      if (cached.length > 0) {
        set((state) => ({
          conversations: shallowEqualConversations(state.conversations, cached)
            ? state.conversations
            : cached,
        }));
      }
    } catch {
      // ignore local storage errors
    }

    // 2. Fetch from server and merge silently.
    try {
      const data = await fetchConversations();
      const next = data.conversations || [];
      if (!shallowEqualConversations(get().conversations, next)) {
        set({ conversations: next });
      }
      await saveConversations(next).catch(() => {});
    } catch (err) {
      console.error("loadConversations failed", err);
    } finally {
      set({ loading: false });
    }
  },

  markRead: async (conversationId) => {
    set((state) => ({
      conversations: state.conversations.map((c) =>
        c.id === conversationId ? { ...c, unread_count: 0 } : c
      ),
    }));
    try {
      await markConversationRead(conversationId);
    } catch (err) {
      console.error("markRead failed", err);
    }
  },
}));
