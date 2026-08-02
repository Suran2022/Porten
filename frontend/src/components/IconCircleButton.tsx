import { cn } from "@/lib/utils";
import { ReactNode } from "react";

interface IconCircleButtonProps {
  icon: ReactNode;
  label: string;
  onClick?: () => void;
  className?: string;
}

export function IconCircleButton({
  icon,
  label,
  onClick,
  className,
}: IconCircleButtonProps) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={cn(
        "flex flex-col items-center gap-2 group",
        className
      )}
    >
      <span className="w-12 h-12 rounded-full bg-gray-100/70 flex items-center justify-center transition-colors duration-200 group-hover:bg-gray-100">
        <span className="w-5 h-5 text-gray-600 flex items-center justify-center">
          {icon}
        </span>
      </span>
      <span className="text-xs text-gray-500">{label}</span>
    </button>
  );
}
