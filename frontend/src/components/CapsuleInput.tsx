import { forwardRef, InputHTMLAttributes } from "react";
import { cn } from "@/lib/utils";

interface CapsuleInputProps extends InputHTMLAttributes<HTMLInputElement> {}

export const CapsuleInput = forwardRef<HTMLInputElement, CapsuleInputProps>(
  ({ className, ...props }, ref) => {
    return (
      <input
        ref={ref}
        className={cn(
          "w-full h-12 px-5 rounded-full bg-gray-100/60 text-gray-900 placeholder:text-gray-400",
          "outline-none border-none focus:ring-0 focus:border-none focus:bg-gray-100/80",
          "transition-colors duration-200",
          className
        )}
        {...props}
      />
    );
  }
);

CapsuleInput.displayName = "CapsuleInput";
