import { useEffect, useRef, useState } from "react";
import { cn } from "@/lib/utils";

interface PcDialogProps {
  open: boolean;
  onClose: () => void;
  children: React.ReactNode;
  /** 弹窗宽度，默认 420（与移动端页面宽度一致） */
  width?: number | string;
  /** 弹窗高度，默认 min(720px, 86vh) */
  height?: number | string;
  /** 顶部圆角 & 溢出裁剪样式覆盖 */
  className?: string;
}

/**
 * PC 端通用居中弹窗。
 *
 * - 打开 / 关闭：背景淡入淡出 + 内容轻微缩放上浮（无悬停类动效）。
 * - 容器保持常驻 transform，使内部复用移动端全屏页面（position: fixed）
 *   的定位边界收敛到弹窗盒子内，实现"移动端页面装进 PC 弹窗"。
 * - 支持 Esc 关闭。
 */
export function PcDialog({
  open,
  onClose,
  children,
  width = 420,
  height = "min(720px, 86vh)",
  className,
}: PcDialogProps) {
  const [render, setRender] = useState(open);
  const [entering, setEntering] = useState(false);
  const closeTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    if (open) {
      if (closeTimerRef.current) {
        clearTimeout(closeTimerRef.current);
        closeTimerRef.current = null;
      }
      setRender(true);
      requestAnimationFrame(() => {
        requestAnimationFrame(() => setEntering(true));
      });
    } else {
      setEntering(false);
      closeTimerRef.current = setTimeout(() => setRender(false), 280);
    }
    return () => {
      if (closeTimerRef.current) clearTimeout(closeTimerRef.current);
    };
  }, [open]);

  useEffect(() => {
    if (!open) return;
    const handleKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
    };
    window.addEventListener("keydown", handleKey);
    return () => window.removeEventListener("keydown", handleKey);
  }, [open, onClose]);

  if (!render) return null;

  return (
    <div className="fixed inset-0 z-[120] flex items-center justify-center p-6">
      {/* 背景遮罩 */}
      <div
        className="absolute inset-0 bg-black/30 transition-opacity duration-300 ease-out"
        style={{ opacity: entering ? 1 : 0 }}
        onClick={onClose}
      />

      {/* 弹窗盒子：常驻 transform 提供 fixed 子元素边界 + 进出场动画 */}
      <div
        className={cn(
          "relative overflow-hidden rounded-2xl bg-white",
          className
        )}
        style={{
          width,
          height,
          maxWidth: "calc(100vw - 48px)",
          maxHeight: "calc(100vh - 48px)",
          opacity: entering ? 1 : 0,
          transform: entering
            ? "scale(1) translateY(0)"
            : "scale(0.96) translateY(14px)",
          transition:
            "transform 280ms cubic-bezier(0.16, 1, 0.3, 1), opacity 240ms ease-out",
        }}
      >
        <div
          className="absolute inset-0"
          style={{ transform: "translateZ(0)" }}
        >
          {children}
        </div>
      </div>
    </div>
  );
}
