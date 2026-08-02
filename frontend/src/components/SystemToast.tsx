import { Loader2, Check, X } from "lucide-react";
import { cn } from "@/lib/utils";

export type ToastType = "loading" | "success" | "error";

interface SystemToastProps {
  visible: boolean;
  type: ToastType;
  text: string;
}

export function SystemToast({ visible, type, text }: SystemToastProps) {
  return (
    <div
      className={cn(
        "fixed inset-0 z-[80] flex items-center justify-center transition-opacity duration-300",
        visible ? "opacity-100" : "opacity-0 pointer-events-none"
      )}
    >
      <div
        className={cn(
          "flex flex-col items-center justify-center gap-3 px-6 py-5 text-white",
          "bg-black/70 backdrop-blur-sm rounded-[9px] min-w-[120px]",
          "transition-transform duration-300",
          visible ? "scale-100" : "scale-90"
        )}
      >
        {type === "loading" ? (
          <Loader2 className="w-7 h-7 animate-spin" strokeWidth={1.5} />
        ) : type === "error" ? (
          <X className="w-7 h-7" strokeWidth={2} />
        ) : (
          <Check className="w-7 h-7" strokeWidth={2} />
        )}
        <span className="text-sm font-medium whitespace-nowrap">{text}</span>
      </div>
    </div>
  );
}
