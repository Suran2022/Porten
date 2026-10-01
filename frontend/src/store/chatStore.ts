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
import {
  loadConversationActions,
  saveConversationActions,
} from "@/lib/conversationActions";

interface ChatState {
  conversations: ConversationItem[];
  loading: boolean;
  pinnedIds: number[];
  importantIds: number[];
  hiddenIds: number[];

  loadConversations: () => Promise<void>;
  markRead: (conversationId: number) => Promise<void>;

  togglePin: (conversationId: number) => void;
  toggleImportant: (conversationId: number) => void;
  hideConversation: (conversationId: number) => void;
}

function shallowEqualConversations(
  a: ConversationItem[],
  b: ConversationItem[],
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

function toggleInList(list: number[], id: number): number[] {
  return list.includes(id) ? list.filter((x) => x !== id) : [...list, id];
}

const initialActions = loadConversationActions();

export const useChatStore = create<ChatState>((set, get) => ({
  conversations: [],
  loading: false,
  pinnedIds: initialActions.pinned,
  importantIds: initialActions.important,
  hiddenIds: initialActions.hidden,

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
        c.id === conversationId ? { ...c, unread_count: 0 } : c,
      ),
    }));
    try {
      await markConversationRead(conversationId);
    } catch (err) {
      console.error("markRead failed", err);
    }
  },

  togglePin: (conversationId) => {
    const next = toggleInList(get().pinnedIds, conversationId);
    set({ pinnedIds: next });
    saveConversationActions({
      pinned: next,
      important: get().importantIds,
      hidden: get().hiddenIds,
    });
  },

  toggleImportant: (conversationId) => {
    const next = toggleInList(get().importantIds, conversationId);
    set({ importantIds: next });
    saveConversationActions({
      pinned: get().pinnedIds,
      important: next,
      hidden: get().hiddenIds,
    });
  },

  hideConversation: (conversationId) => {
    const next = toggleInList(get().hiddenIds, conversationId);
    set({ hiddenIds: next });
    saveConversationActions({
      pinned: get().pinnedIds,
      important: get().importantIds,
      hidden: next,
    });
  },
}));