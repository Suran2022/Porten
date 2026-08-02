import { useEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";
import { X } from "lucide-react";
import { cn } from "@/lib/utils";

interface FloatingMusicWidgetProps {
  visible: boolean;
  spinning: boolean;
  coverImage: string;
  onClick: () => void; // 点击转盘重新打开音乐页
  onClose: () => void; // 关闭悬浮窗并停止播放
}

// 悬浮音乐悬浮窗：转盘样式，可拖动，右上角叉叉关闭
export function FloatingMusicWidget({
  visible,
  spinning,
  coverImage,
  onClick,
  onClose,
}: FloatingMusicWidgetProps) {
  // 悬浮窗位置（相对视口 px）
  const [pos, setPos] = useState({ x: 16, y: 120 });
  const [rendered, setRendered] = useState(false);
  const [shown, setShown] = useState(false);
  const dragRef = useRef<{
    startX: number;
    startY: number;
    origX: number;
    origY: number;
    moved: boolean;
  } | null>(null);
  const WIDGET = 56; // 转盘直径

  useEffect(() => {
    if (visible) {
      setRendered(true);
      requestAnimationFrame(() => setShown(true));
    } else {
      setShown(false);
    }
  }, [visible]);

  const handleTransitionEnd = () => {
    if (!shown) setRendered(false);
  };

  const handlePointerDown = (e: React.PointerEvent) => {
    dragRef.current = {
      startX: e.clientX,
      startY: e.clientY,
      origX: pos.x,
      origY: pos.y,
      moved: false,
    };
    (e.currentTarget as HTMLElement).setPointerCapture?.(e.pointerId);
  };

  const handlePointerMove = (e: React.PointerEvent) => {
    const d = dragRef.current;
    if (!d) return;
    const dx = e.clientX - d.startX;
    const dy = e.clientY - d.startY;
    if (Math.abs(dx) > 4 || Math.abs(dy) > 4) d.moved = true;
    // 限制在视口内
    const maxX = window.innerWidth - WIDGET - 8;
    const maxY = window.innerHeight - WIDGET - 8;
    const nx = Math.min(Math.max(8, d.origX + dx), maxX);
    const ny = Math.min(Math.max(8, d.origY + dy), maxY);
    setPos({ x: nx, y: ny });
  };

  const handlePointerUp = () => {
    const d = dragRef.current;
    dragRef.current = null;
    // 未拖动则视为点击，打开音乐页
    if (d && !d.moved) {
      onClick();
    }
  };

  if (!rendered) return null;

  return createPortal(
    <div
      className={cn(
        "fixed z-[60] transition-opacity duration-300",
        shown ? "opacity-100" : "opacity-0 pointer-events-none"
      )}
      style={{ left: pos.x, top: pos.y, transition: "opacity 300ms ease" }}
      onTransitionEnd={handleTransitionEnd}
    >
      {/* 右上角叉叉：关闭并停止播放 */}
      <button
        type="button"
        onClick={(e) => {
          e.stopPropagation();
          onClose();
        }}
        className="absolute -top-1.5 -right-1.5 z-10 w-5 h-5 rounded-full bg-black/80 text-white flex items-center justify-center shadow-md active:scale-90 transition-transform"
        aria-label="关闭"
      >
        <X className="w-3 h-3" strokeWidth={2.5} />
      </button>

      {/* 转盘：可拖动 */}
      <div
        className="relative cursor-grab active:cursor-grabbing touch-none"
        style={{ width: WIDGET, height: WIDGET }}
        onPointerDown={handlePointerDown}
        onPointerMove={handlePointerMove}
        onPointerUp={handlePointerUp}
        onPointerCancel={handlePointerUp}
      >
        {/* 黑胶外圈 */}
        <div
          className="absolute inset-0 rounded-full"
          style={{
            background:
              "radial-gradient(circle at 50% 50%, #1a1a1a 60%, #050505 100%)",
            boxShadow: "0 6px 16px rgba(0,0,0,0.5)",
          }}
        />
        {/* 中心封面图：随播放旋转 */}
        <div
          className={cn(
            "absolute rounded-full overflow-hidden",
            spinning && "animate-spin-slow"
          )}
          style={{
            top: "16%",
            left: "16%",
            right: "16%",
            bottom: "16%",
          }}
        >
          <img
            src={coverImage}
            alt="cover"
            className="w-full h-full object-cover"
            draggable={false}
          />
          {/* 中心孔 */}
          <div
            className="absolute rounded-full bg-black"
            style={{
              top: "50%",
              left: "50%",
              width: 6,
              height: 6,
              transform: "translate(-50%, -50%)",
            }}
          />
        </div>
      </div>
    </div>,
    document.body
  );
}
