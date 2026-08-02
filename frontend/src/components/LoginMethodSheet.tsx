import { useEffect, useRef, useState, useCallback } from "react";
import { Check, Mail, Phone, User } from "lucide-react";
import { cn } from "@/lib/utils";

export type LoginMethod = "email" | "phone" | "porten";

interface LoginMethodOption {
  value: LoginMethod;
  label: string;
  icon: React.ReactNode;
}

const options: LoginMethodOption[] = [
  {
    value: "email",
    label: "邮箱登录",
    icon: <Mail className="w-5 h-5" strokeWidth={1.8} />,
  },
  {
    value: "phone",
    label: "手机号登录",
    icon: <Phone className="w-5 h-5" strokeWidth={1.8} />,
  },
  {
    value: "porten",
    label: "Porten 账号登录",
    icon: <User className="w-5 h-5" strokeWidth={1.8} />,
  },
];

interface LoginMethodSheetProps {
  open: boolean;
  value: LoginMethod;
  onChange: (value: LoginMethod) => void;
  onClose: () => void;
}

export function LoginMethodSheet({
  open,
  value,
  onChange,
  onClose,
}: LoginMethodSheetProps) {
  const [isVisible, setIsVisible] = useState(false);
  const [isEntering, setIsEntering] = useState(false);
  const [translateY, setTranslateY] = useState(0);
  const [isDragging, setIsDragging] = useState(false);
  const dragStartY = useRef(0);
  const currentTranslateY = useRef(0);
  const sheetRef = useRef<HTMLDivElement>(null);
  const sheetHeightRef = useRef(0);
  const closeTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    if (open) {
      setIsVisible(true);
      setIsEntering(false);
      setTranslateY(0);
      currentTranslateY.current = 0;
      if (closeTimerRef.current) {
        clearTimeout(closeTimerRef.current);
        closeTimerRef.current = null;
      }
      const raf = requestAnimationFrame(() => {
        requestAnimationFrame(() => {
          setIsEntering(true);
        });
      });
      return () => cancelAnimationFrame(raf);
    } else {
      setIsEntering(false);
      closeTimerRef.current = setTimeout(() => {
        setIsVisible(false);
        setTranslateY(0);
        currentTranslateY.current = 0;
      }, 450);
      return () => {
        if (closeTimerRef.current) {
          clearTimeout(closeTimerRef.current);
        }
      };
    }
  }, [open]);

  const handleDragStart = useCallback((clientY: number) => {
    setIsDragging(true);
    dragStartY.current = clientY;
    if (sheetRef.current) {
      sheetHeightRef.current = sheetRef.current.offsetHeight;
    }
  }, []);

  const handleDragMove = useCallback(
    (clientY: number) => {
      if (!isDragging) return;
      const delta = clientY - dragStartY.current;
      const newTranslateY = Math.max(0, delta);
      currentTranslateY.current = newTranslateY;
      setTranslateY(newTranslateY);
    },
    [isDragging]
  );

  const handleDragEnd = useCallback(() => {
    if (!isDragging) return;
    setIsDragging(false);
    const threshold = sheetHeightRef.current * 0.5;
    if (currentTranslateY.current > threshold) {
      onClose();
    } else {
      setTranslateY(0);
      currentTranslateY.current = 0;
    }
  }, [isDragging, onClose]);

  const onTouchStart = useCallback(
    (e: React.TouchEvent) => {
      handleDragStart(e.touches[0].clientY);
    },
    [handleDragStart]
  );
  const onTouchMove = useCallback(
    (e: React.TouchEvent) => {
      handleDragMove(e.touches[0].clientY);
    },
    [handleDragMove]
  );
  const onTouchEnd = useCallback(() => {
    handleDragEnd();
  }, [handleDragEnd]);

  const onMouseDown = useCallback(
    (e: React.MouseEvent) => {
      handleDragStart(e.clientY);
    },
    [handleDragStart]
  );
  const onMouseMove = useCallback(
    (e: React.MouseEvent) => {
      handleDragMove(e.clientY);
    },
    [handleDragMove]
  );
  const onMouseUp = useCallback(() => {
    handleDragEnd();
  }, [handleDragEnd]);

  const handleSelect = (method: LoginMethod) => {
    onChange(method);
    onClose();
  };

  if (!isVisible) return null;

  const baseTranslate = isEntering ? 0 : sheetHeightRef.current || "100%";
  const activeTranslate = isDragging ? translateY : baseTranslate;

  return (
    <div
      className="fixed inset-0 z-50 flex items-end pointer-events-none"
      style={{ width: "100vw" }}
    >
      <div
        className="absolute inset-0 pointer-events-auto bg-gray-100/60 transition-opacity duration-400 ease-out"
        style={{ opacity: isEntering ? 1 : 0 }}
        onClick={onClose}
      />
      <div
        ref={sheetRef}
        className={cn(
          "relative bg-white rounded-t-3xl px-5 pb-8 pt-3 border-t border-gray-100 pointer-events-auto"
        )}
        style={{
          width: "100vw",
          transform: `translateY(${activeTranslate})`,
          transition: isDragging
            ? "none"
            : "transform 450ms cubic-bezier(0.16, 1, 0.3, 1), opacity 400ms ease-out",
          opacity: isEntering ? 1 : 0,
        }}
      >
        <div
          className="flex flex-col items-center pt-2 pb-4 cursor-grab active:cursor-grabbing"
          onTouchStart={onTouchStart}
          onTouchMove={onTouchMove}
          onTouchEnd={onTouchEnd}
          onMouseDown={onMouseDown}
          onMouseMove={onMouseMove}
          onMouseUp={onMouseUp}
          onMouseLeave={onMouseUp}
        >
          <div className="sheet-handle" />
        </div>

        <div className="space-y-3">
          {options.map((option, index) => {
            const selected = option.value === value;
            return (
              <button
                key={option.value}
                type="button"
                onClick={() => handleSelect(option.value)}
                className={cn(
                  "w-full flex items-center justify-between px-4 py-3.5 rounded-2xl",
                  "border transition-all duration-300",
                  selected
                    ? "border-gray-200 bg-gray-50/50"
                    : "border-gray-100 bg-white hover:bg-gray-50/30"
                )}
                style={{
                  opacity: isEntering ? 1 : 0,
                  transform: isEntering ? "translateY(0)" : "translateY(16px)",
                  transition: isDragging
                    ? "none"
                    : `transform 450ms cubic-bezier(0.16, 1, 0.3, 1) ${120 + index * 60}ms, opacity 400ms ease-out ${120 + index * 60}ms, background-color 200ms, border-color 200ms`,
                }}
              >
                <div className="flex items-center gap-3">
                  <span className="w-9 h-9 rounded-full bg-gray-100/70 flex items-center justify-center text-gray-600">
                    {option.icon}
                  </span>
                  <span className="text-sm font-medium text-gray-800">
                    {option.label}
                  </span>
                </div>
                {selected && (
                  <span className="w-5 h-5 rounded-full porten-bg-gradient flex items-center justify-center text-white">
                    <Check className="w-3 h-3" strokeWidth={3} />
                  </span>
                )}
              </button>
            );
          })}
        </div>
      </div>
    </div>
  );
}
