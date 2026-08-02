import { Settings } from "lucide-react";

interface ProfileBottomBarProps {
  onSettingsClick?: () => void;
}

export function ProfileBottomBar({ onSettingsClick }: ProfileBottomBarProps) {
  return (
    <div className="flex-shrink-0 h-[4.6875rem] sm:h-[5.1875rem] w-full bg-white border-t border-gray-100 flex items-center justify-start px-4 sm:px-6">
      <button
        type="button"
        onClick={onSettingsClick}
        className="flex flex-col items-center gap-1 ml-[5px] text-gray-500 active:text-gray-700 transition-colors"
      >
        <Settings className="w-5 h-5 sm:w-6 sm:h-6" strokeWidth={1.6} />
        <span className="text-xs sm:text-sm">设置</span>
      </button>
    </div>
  );
}
