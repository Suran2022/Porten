import { create } from "zustand";
import {
  fetchSystemMessages,
  fetchSystemMessageUnreadCount,
  markAllSystemMessagesRead,
  markSystemMessageRead,
  SystemMessageItem,
} from "@/lib/api";

interface SystemMessageState {
  messages: SystemMessageItem[];
  unreadCount: number;
  loading: boolean;

  loadMessages: () => Promise<void>;
  loadUnreadCount: () => Promise<void>;
  markAsRead: (messageId: number) => Promise<void>;
  markAllAsRead: () => Promise<void>;
}

export const useSystemMessageStore = create<SystemMessageState>((set, get) => ({
  messages: [],
  unreadCount: 0,
  loading: false,

  loadMessages: async () => {
    set({ loading: true });
    try {
      const data = await fetchSystemMessages();
      set({ messages: data.messages, unreadCount: data.unread_count });
    } catch (err) {
      console.error("loadSystemMessages failed", err);
    } finally {
      set({ loading: false });
    }
  },

  loadUnreadCount: async () => {
    try {
      const data = await fetchSystemMessageUnreadCount();
      set({ unreadCount: data.unread_count });
    } catch (err) {
      console.error("loadSystemMessageUnreadCount failed", err);
    }
  },

  markAsRead: async (messageId) => {
    const message = get().messages.find((m) => m.id === messageId);
    if (!message || message.is_read) return;

    set((state) => ({
      messages: state.messages.map((m) =>
        m.id === messageId ? { ...m, is_read: true } : m
      ),
      unreadCount: Math.max(0, state.unreadCount - 1),
    }));

    try {
      await markSystemMessageRead(messageId);
    } catch (err) {
      console.error("markSystemMessageRead failed", err);
      // Revert on failure
      set((state) => ({
        messages: state.messages.map((m) =>
          m.id === messageId ? { ...m, is_read: false } : m
        ),
        unreadCount: state.unreadCount + 1,
      }));
    }
  },

  markAllAsRead: async () => {
    const previousMessages = get().messages;
    const previousUnreadCount = get().unreadCount;

    set((state) => ({
      messages: state.messages.map((m) => ({ ...m, is_read: true })),
      unreadCount: 0,
    }));

    try {
      await markAllSystemMessagesRead();
    } catch (err) {
      console.error("markAllSystemMessagesRead failed", err);
      set({
        messages: previousMessages,
        unreadCount: previousUnreadCount,
      });
    }
  },
}));
