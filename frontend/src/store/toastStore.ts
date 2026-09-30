import { create } from "zustand";

// 通用提示图标类型
export type ToastIcon = "call" | "success" | "error" | "info";

// 提示位置：顶部（默认）或屏幕正中间
export type ToastPosition = "top" | "center";

interface ToastState {
  visible: boolean;
  text: string;
  icon: ToastIcon;
  position: ToastPosition;
  // show: 弹出提示，2 秒后自动消失。重复调用会重置计时器。
  show: (text: string, icon?: ToastIcon, position?: ToastPosition) => void;
  hide: () => void;
}

let hideTimer: ReturnType<typeof setTimeout> | null = null;

export const useToastStore = create<ToastState>((set) => ({
  visible: false,
  text: "",
  icon: "info",
  position: "top",
  show: (text, icon = "info", position = "top") => {
    if (hideTimer) {
      clearTimeout(hideTimer);
      hideTimer = null;
    }
    set({ text, icon, position, visible: true });
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
