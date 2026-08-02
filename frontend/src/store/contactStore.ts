import { create } from "zustand";
import {
  fetchContacts,
  fetchReceivedFriendRequests,
  fetchReceivedGroupRequests,
  fetchBadgeCounts,
  markNotificationsRead,
  sendFriendRequest as apiSendFriendRequest,
  handleFriendRequest as apiHandleFriendRequest,
  sendGroupRequest as apiSendGroupRequest,
  handleGroupRequest as apiHandleGroupRequest,
  ContactsData,
  FriendRequestItem,
  GroupRequestItem,
  BadgeCounts,
} from "@/lib/api";
import { useChatStore } from "./chatStore";

interface ContactState {
  contacts: ContactsData;
  friendRequests: FriendRequestItem[];
  groupRequests: GroupRequestItem[];
  badge: BadgeCounts;
  loading: boolean;
  error: string | null;

  loadContacts: () => Promise<void>;
  loadFriendRequests: () => Promise<void>;
  loadGroupRequests: () => Promise<void>;
  loadBadge: () => Promise<void>;
  markRead: (type: "friend" | "group") => Promise<void>;
  sendFriendRequest: (receiverPortenId: string, message?: string) => Promise<void>;
  handleFriendRequest: (requestId: number, action: "accept" | "reject") => Promise<void>;
  sendGroupRequest: (groupId: number, message?: string) => Promise<void>;
  handleGroupRequest: (requestId: number, action: "accept" | "reject") => Promise<void>;
  startPolling: () => void;
  stopPolling: () => void;
}

const POLL_INTERVAL = 8000;

const initialContacts: ContactsData = { friends: [], groups: [] };
const initialBadge: BadgeCounts = { friend_requests: 0, group_requests: 0 };

let pollingInterval: ReturnType<typeof setInterval> | null = null;
let pollingCount = 0;
let visibilityHandler: (() => void) | null = null;

const runPoll = () => {
  if (typeof document !== "undefined" && document.visibilityState !== "visible") {
    return;
  }
  const state = useContactStore.getState();
  state.loadBadge().catch(() => undefined);
  useChatStore.getState().loadConversations().catch(() => undefined);
  state.loadContacts().catch(() => undefined);
};

const attachVisibilityListener = () => {
  if (typeof document === "undefined") return;
  visibilityHandler = () => {
    if (document.visibilityState === "visible") {
      runPoll();
    }
  };
  document.addEventListener("visibilitychange", visibilityHandler);
};

const detachVisibilityListener = () => {
  if (visibilityHandler && typeof document !== "undefined") {
    document.removeEventListener("visibilitychange", visibilityHandler);
    visibilityHandler = null;
  }
};

export const useContactStore = create<ContactState>((set, get) => ({
  contacts: initialContacts,
  friendRequests: [],
  groupRequests: [],
  badge: initialBadge,
  loading: false,
  error: null,

  loadContacts: async () => {
    set({ loading: true });
    try {
      const data = await fetchContacts();
      set((state) => {
        const changed = JSON.stringify(state.contacts) !== JSON.stringify(data);
        return { ...(changed ? { contacts: data } : {}), loading: false };
      });
    } catch (err) {
      console.error("loadContacts failed", err);
      set({ loading: false });
    }
  },

  loadFriendRequests: async () => {
    try {
      const data = await fetchReceivedFriendRequests();
      set((state) => {
        const next = data || [];
        const changed = JSON.stringify(state.friendRequests) !== JSON.stringify(next);
        return changed ? { friendRequests: next } : {};
      });
    } catch (err) {
      console.error("loadFriendRequests failed", err);
    }
  },

  loadGroupRequests: async () => {
    try {
      const data = await fetchReceivedGroupRequests();
      set((state) => {
        const next = data || [];
        const changed = JSON.stringify(state.groupRequests) !== JSON.stringify(next);
        return changed ? { groupRequests: next } : {};
      });
    } catch (err) {
      console.error("loadGroupRequests failed", err);
    }
  },

  loadBadge: async () => {
    try {
      const data = await fetchBadgeCounts();
      set((state) => {
        const next = data || initialBadge;
        const changed = JSON.stringify(state.badge) !== JSON.stringify(next);
        return changed ? { badge: next } : {};
      });
    } catch (err) {
      console.error("loadBadge failed", err);
    }
  },

  markRead: async (type) => {
    try {
      await markNotificationsRead(type);
      if (type === "friend") {
        await get().loadFriendRequests();
      } else {
        await get().loadGroupRequests();
      }
      await get().loadBadge();
    } catch (err) {
      console.error("markRead failed", err);
    }
  },

  sendFriendRequest: async (receiverPortenId, message) => {
    try {
      await apiSendFriendRequest(receiverPortenId, message);
    } catch (err) {
      console.error("sendFriendRequest failed", err);
      throw err;
    }
  },

  handleFriendRequest: async (requestId, action) => {
    try {
      await apiHandleFriendRequest(requestId, action);
      await Promise.all([
        get().loadFriendRequests(),
        get().loadContacts(),
        useChatStore.getState().loadConversations(),
        get().loadBadge(),
      ]);
    } catch (err) {
      console.error("handleFriendRequest failed", err);
      throw err;
    }
  },

  sendGroupRequest: async (groupId, message) => {
    try {
      await apiSendGroupRequest(groupId, message);
    } catch (err) {
      console.error("sendGroupRequest failed", err);
      throw err;
    }
  },

  handleGroupRequest: async (requestId, action) => {
    try {
      await apiHandleGroupRequest(requestId, action);
      await Promise.all([
        get().loadGroupRequests(),
        get().loadContacts(),
        useChatStore.getState().loadConversations(),
        get().loadBadge(),
      ]);
    } catch (err) {
      console.error("handleGroupRequest failed", err);
      throw err;
    }
  },

  startPolling: () => {
    pollingCount += 1;
    if (pollingCount === 1) {
      runPoll();
      pollingInterval = setInterval(runPoll, POLL_INTERVAL);
      attachVisibilityListener();
    }
  },

  stopPolling: () => {
    pollingCount = Math.max(0, pollingCount - 1);
    if (pollingCount === 0) {
      if (pollingInterval) {
        clearInterval(pollingInterval);
        pollingInterval = null;
      }
      detachVisibilityListener();
    }
  },
}));
