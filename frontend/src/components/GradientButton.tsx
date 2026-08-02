import { ButtonHTMLAttributes, forwardRef } from "react";
import { cn } from "@/lib/utils";

interface GradientButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  loading?: boolean;
}

export const GradientButton = forwardRef<HTMLButtonElement, GradientButtonProps>(
  ({ className, children, loading = false, disabled, ...props }, ref) => {
    return (
      <button
        ref={ref}
        disabled={disabled || loading}
        className={cn(
          "w-full h-12 rounded-full porten-bg-gradient text-white font-medium",
          "flex items-center justify-center",
          "transition-opacity duration-200",
          "disabled:opacity-70 disabled:cursor-not-allowed",
          className
        )}
        {...props}
      >
        {loading ? (
          <span className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full spinner" />
        ) : (
          children
        )}
      </button>
    );
  }
);

GradientButton.displayName = "GradientButton";
