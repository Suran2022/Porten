import { useEffect, useState } from "react";
import { cn } from "@/lib/utils";

interface CenterDialogProps {
  visible: boolean;
  onClose: () => void;
  title?: string;
  children: React.ReactNode;
  className?: string;
}

export function CenterDialog({
  visible,
  onClose,
  children,
  className,
}: CenterDialogProps) {
  const [shouldRender, setShouldRender] = useState(false);
  const [isShown, setIsShown] = useState(false);

  useEffect(() => {
    if (visible) {
      setShouldRender(true);
      requestAnimationFrame(() => {
        requestAnimationFrame(() => setIsShown(true));
      });
    } else {
      setIsShown(false);
    }
  }, [visible]);

  const handleTransitionEnd = () => {
    if (!visible) {
      setShouldRender(false);
    }
  };

  if (!shouldRender) return null;

  return (
    <div
      className={cn(
        "fixed inset-0 z-[80] flex items-center justify-center px-6 transition-opacity duration-200",
        isShown ? "opacity-100" : "opacity-0"
      )}
      onTransitionEnd={handleTransitionEnd}
    >
      {/* 点击遮罩关闭 */}
      <div
        className="absolute inset-0 bg-black/40"
        onClick={onClose}
        aria-hidden
      />
      <div
        className={cn(
          "relative w-full max-w-sm bg-white rounded-2xl shadow-xl overflow-hidden",
          "transition-all duration-200 ease-out",
          isShown ? "scale-100 opacity-100" : "scale-95 opacity-0",
          className
        )}
      >
        {children}
      </div>
    </div>
  );
}
