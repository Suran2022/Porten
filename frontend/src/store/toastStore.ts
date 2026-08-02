import { create } from "zustand";

// 通用提示图标类型
export type ToastIcon = "call" | "success" | "error" | "info";

interface ToastState {
  visible: boolean;
  text: string;
  icon: ToastIcon;
  // show: 弹出提示，2 秒后自动消失。重复调用会重置计时器。
  show: (text: string, icon?: ToastIcon) => void;
  hide: () => void;
}

let hideTimer: ReturnType<typeof setTimeout> | null = null;

export const useToastStore = create<ToastState>((set) => ({
  visible: false,
  text: "",
  icon: "info",
  show: (text, icon = "info") => {
    if (hideTimer) {
      clearTimeout(hideTimer);
      hideTimer = null;
    }
    set({ text, icon, visible: true });
    hideTimer = setTimeout(() => {
      set({ visible: false });
      hideTimer = null;
    }, 2000);
  },
  hide: () => {
    if (hideTimer) {
      clearTimeout(hideTimer);
      hideTimer = null;
    }
    set({ visible: false });
  },
}));
