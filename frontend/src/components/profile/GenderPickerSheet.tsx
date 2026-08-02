import { useEffect, useState } from "react";
import { Check } from "lucide-react";
import { cn } from "@/lib/utils";
import { GENDER_OPTIONS, GenderValue } from "@/types/profile";

interface GenderPickerSheetProps {
  visible: boolean;
  selected?: GenderValue | null;
  onSelect: (value: GenderValue) => void;
  onClose: () => void;
}

export function GenderPickerSheet({
  visible,
  selected,
  onSelect,
  onClose,
}: GenderPickerSheetProps) {
  const [renderVisible, setRenderVisible] = useState(visible);
  const [isEntering, setIsEntering] = useState(false);

  useEffect(() => {
    if (visible) {
      setRenderVisible(true);
      setIsEntering(false);
      requestAnimationFrame(() => {
        requestAnimationFrame(() => setIsEntering(true));
      });
    } else if (renderVisible) {
      setIsEntering(false);
      const timer = setTimeout(() => setRenderVisible(false), 300);
      return () => clearTimeout(timer);
    }
  }, [visible, renderVisible]);

  if (!renderVisible) return null;

  const handleSelect = (value: GenderValue) => {
    onSelect(value);
    onClose();
  };

  return (
    <div className="fixed inset-0 z-[60] flex flex-col justify-end">
      {/* Backdrop */}
      <button
        type="button"
        onClick={onClose}
        className={cn(
          "absolute inset-0 bg-black/40 transition-opacity duration-300",
          isEntering ? "opacity-100" : "opacity-0"
        )}
        aria-label="关闭"
      />

      {/* Sheet */}
      <div
        className={cn(
          "relative bg-white rounded-t-2xl max-h-[70vh] flex flex-col transition-transform duration-300 ease-[cubic-bezier(0.25,0.1,0.25,1)]",
          isEntering ? "translate-y-0" : "translate-y-full"
        )}
      >
        {/* Drag handle */}
        <div className="flex justify-center pt-3 pb-2">
          <div className="w-9 h-1 rounded-full bg-gray-300" />
        </div>

        <h2 className="px-5 pb-3 text-base font-medium text-gray-900">
          选择性别
        </h2>

        <div className="overflow-y-auto px-3 pb-6">
          <div className="space-y-1">
            {GENDER_OPTIONS.map((option) => {
              const isSelected = option.value === selected;
              return (
                <button
                  key={option.value}
                  type="button"
                  onClick={() => handleSelect(option.value)}
                  className={cn(
                    "w-full flex items-center justify-between px-4 py-3.5 rounded-xl text-left transition-colors",
                    isSelected
                      ? "bg-gradient-to-r from-[#5BCEFA]/10 to-[#F5A9B8]/10"
                      : "hover:bg-gray-50 active:bg-gray-100"
                  )}
                >
                  <span
                    className={cn(
                      "text-base",
                      isSelected ? "text-gray-900 font-medium" : "text-gray-700"
                    )}
                  >
                    {option.label}
                  </span>
                  {isSelected && (
                    <Check
                      className="w-5 h-5 text-[#F5A9B8] flex-shrink-0"
                      strokeWidth={2}
                    />
                  )}
                </button>
              );
            })}
          </div>
        </div>
      </div>
    </div>
  );
}
