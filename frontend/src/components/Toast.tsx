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
 * 样式复用悦音乐页面"暂无更多音乐"的胶囊提示：半透明黑底毛玻璃 + 2s 自动消失。
 * 通过 useToastStore.show(text, icon, position) 触发，全局挂载一次即可。
 *
 * 顶部（top）与屏幕正中间（center）两种位置各自持有独立 DOM：
 * 位置切换时新提示在自身位置原地淡入，绝不会从另一个位置滑动过来。
 */
export function Toast() {
  const { visible, text, icon, position, hide } = useToastStore();
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  if (!mounted) return null;

  const Icon = ICON_MAP[icon] || Info;

  const topVisible = visible && position === "top";
  const centerVisible = visible && position === "center";

  return createPortal(
    <>
      {/* 顶部提示：覆盖在 64px 顶部栏之上并垂直居中（top 14px + 高约 36px ≈ 中心 32px），水平居中 */}
      <div
        className={cn(
          "fixed left-1/2 top-3.5 z-[9999] flex -translate-x-1/2 items-center gap-1.5 px-4 py-2 rounded-full bg-black/75 backdrop-blur-sm text-white text-sm transition-all duration-300",
          topVisible
            ? "opacity-100 translate-y-0"
            : "opacity-0 -translate-y-2 pointer-events-none"
        )}
        onTransitionEnd={() => {
          if (!topVisible) hide();
        }}
      >
        <Icon className="w-4 h-4" strokeWidth={2} />
        <span className="whitespace-nowrap">{text}</span>
      </div>

      {/* 屏幕正中间提示：常驻同一位置，仅淡入淡出 + 轻微缩放，无位置迁移 */}
      <div
        className={cn(
          "fixed left-1/2 top-1/2 z-[9999] flex items-center gap-1.5 px-4 py-2 rounded-full bg-black/75 backdrop-blur-sm text-white text-sm transition-[opacity,transform] duration-300",
          centerVisible ? "opacity-100" : "opacity-0 pointer-events-none"
        )}
        style={{
          transform: `translate(-50%, -50%) scale(${centerVisible ? 1 : 0.92})`,
        }}
        onTransitionEnd={() => {
          if (!centerVisible) hide();
        }}
      >
        <Icon className="w-4 h-4" strokeWidth={2} />
        <span className="whitespace-nowrap">{text}</span>
      </div>
    </>,
    document.body
  );
}
