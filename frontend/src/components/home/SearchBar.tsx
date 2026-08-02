import { Search } from "lucide-react";

interface SearchBarProps {
  onClick?: () => void;
}

export function SearchBar({ onClick }: SearchBarProps) {
  return (
    <div className="px-4 py-3 bg-white">
      <button
        type="button"
        onClick={onClick}
        className="w-full flex items-center gap-2 h-10 px-3 rounded-md bg-gray-100/60 text-gray-400 active:bg-gray-200/60 transition-colors text-left"
      >
        <Search className="w-4 h-4" strokeWidth={1.8} />
        <span className="text-sm">搜索同胞/营地/图片…</span>
      </button>
    </div>
  );
}
