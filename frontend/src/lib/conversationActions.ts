/**
 * 会话本地动作（置顶 / 重要 / 隐藏）的轻量持久化。
 *
 * 不污染 ConversationItem 类型；用 localStorage 单独存三类 ID 集合，
 * 前端展示层按需 filter / sort。
 */

const STORAGE_KEY = "porten_conversation_actions";

export interface ConversationActions {
  pinned: number[];
  important: number[];
  hidden: number[];
}

const EMPTY: ConversationActions = {
  pinned: [],
  important: [],
  hidden: [],
};

export function loadConversationActions(): ConversationActions {
  if (typeof window === "undefined") return EMPTY;
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    if (!raw) return EMPTY;
    const parsed = JSON.parse(raw);
    return {
      pinned: Array.isArray(parsed?.pinned) ? parsed.pinned : [],
      important: Array.isArray(parsed?.important) ? parsed.important : [],
      hidden: Array.isArray(parsed?.hidden) ? parsed.hidden : [],
    };
  } catch {
    return EMPTY;
  }
}

export function saveConversationActions(actions: ConversationActions): void {
  if (typeof window === "undefined") return;
  try {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(actions));
  } catch {
    /* quota exceeded or disabled: silently drop */
  }
}