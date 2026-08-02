import { useEffect, useState } from "react";
import { createPortal } from "react-dom";
import { Phone, Check, X, Info } from "lucide-react";
import { useToastStore, ToastIcon } from "@/store/toastStore";
import { cn } from "@/lib/utils";

// 图标映射
const ICON_MAP: Record<ToastIcon, typeof Phone> = {
  call: Phone,
  success: Check,
  error: X,
  info: Info,
};

/**
 * 通用 Toast 提示组件。
 * 样式复用悦音乐页面"暂无更多音乐"的胶囊提示：半透明黑底毛玻璃 + 顶部居中 + 2s 自动消失。
 * 通过 useToastStore.show(text, icon) 触发，全局挂载一次即可。
 */
export function Toast() {
  const { visible, text, icon, hide } = useToastStore();
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  if (!mounted) return null;

  const Icon = ICON_MAP[icon] || Info;

  return createPortal(
    <div
      className={cn(
        "fixed left-1/2 -translate-x-1/2 top-14 z-[9999] flex items-center gap-1.5 px-4 py-2 rounded-full bg-black/75 backdrop-blur-sm text-white text-sm transition-all duration-300",
        visible
          ? "opacity-100 translate-y-0"
          : "opacity-0 -translate-y-2 pointer-events-none"
      )}
      onTransitionEnd={() => {
        if (!visible) hide();
      }}
    >
      <Icon className="w-4 h-4" strokeWidth={2} />
      <span>{text}</span>
    </div>,
    document.body
  );
}
