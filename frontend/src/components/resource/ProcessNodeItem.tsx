import { useState } from "react";
import { ChevronRight } from "lucide-react";
import { ProcessNode } from "@/types/resource";

interface ProcessNodeItemProps {
  node: ProcessNode;
  index: number;
  isLast: boolean;
  defaultExpanded?: boolean;
}

export function ProcessNodeItem({
  node,
  index,
  isLast,
  defaultExpanded = false,
}: ProcessNodeItemProps) {
  const [expanded, setExpanded] = useState(defaultExpanded);

  return (
    <div className="relative flex gap-4 px-4">
      {/* Timeline line */}
      {!isLast && (
        <div className="absolute left-[27px] top-7 bottom-0 w-px bg-gray-200" />
      )}

      {/* Dot */}
      <div className="relative z-10 flex-shrink-0 w-7 h-7 rounded-full porten-bg-gradient flex items-center justify-center text-white text-xs font-medium mt-0.5">
        {index + 1}
      </div>

      {/* Content */}
      <div className="flex-1 min-w-0 pb-6">
        <button
          type="button"
          onClick={() => setExpanded((prev) => !prev)}
          className="w-full flex items-center justify-between text-left"
        >
          <span className="text-base font-medium text-gray-900">
            {node.title}
          </span>
          <span
            className="text-gray-400 transition-transform duration-300 flex-shrink-0 ml-2"
            style={{ transform: expanded ? "rotate(90deg)" : "rotate(0deg)" }}
          >
            <ChevronRight className="w-4 h-4" strokeWidth={1.5} />
          </span>
        </button>

        <div
          className="overflow-hidden transition-all duration-300 ease-out"
          style={{
            maxHeight: expanded ? "600px" : "0px",
            opacity: expanded ? 1 : 0,
          }}
        >
          <p className="pt-2 text-sm text-gray-600 leading-relaxed">
            {node.content}
          </p>
          {node.note && (
            <p className="mt-2 text-xs text-gray-500 leading-relaxed bg-gray-50 rounded-lg p-3">
              <span className="font-medium text-gray-700">国内外差异：</span>
              {node.note}
            </p>
          )}
        </div>
      </div>
    </div>
  );
}
