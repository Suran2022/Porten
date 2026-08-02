import { ChevronRight } from "lucide-react";

const functions = [
  { id: "diary", label: "跨儿日记" },
  { id: "files", label: "我的文件" },
  { id: "favorites", label: "知识收藏" },
];

export function ProfileFunctionList() {
  return (
    <div className="bg-white rounded-2xl overflow-hidden">
      {functions.map((item, index) => (
        <button
          key={item.id}
          type="button"
          className="w-full flex items-center justify-between px-4 py-3.5 text-left active:bg-gray-50/50 transition-colors"
        >
          <span className="text-base text-gray-900">{item.label}</span>
          <ChevronRight className="w-4 h-4 text-gray-400" strokeWidth={1.5} />
        </button>
      ))}
    </div>
  );
}
