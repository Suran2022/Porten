import { useState } from "react";
import { Heart } from "lucide-react";
import { Hospital } from "@/types/resource";
import { cn } from "@/lib/utils";

interface HospitalCardProps {
  hospital: Hospital;
}

export function HospitalCard({ hospital }: HospitalCardProps) {
  const [isFavorited, setIsFavorited] = useState(hospital.isFavorited);

  const toggleFavorite = () => setIsFavorited((prev) => !prev);

  const renderTags = () => {
    const tags = [
      { label: "可开诊断单", show: hospital.canIssueDiagnosis },
      { label: "需家长陪同", show: hospital.requiresParent },
      { label: "首诊可开单", show: hospital.firstVisitIssue },
    ].filter((t) => t.show);

    return tags.map((tag) => (
      <span
        key={tag.label}
        className="inline-flex items-center px-2 py-0.5 rounded text-xs bg-gray-100 text-gray-600"
      >
        {tag.label}
      </span>
    ));
  };

  return (
    <div className="mx-4 mt-3 p-4 border border-gray-200 rounded-[10px] bg-white">
      <div className="flex items-start justify-between gap-3">
        <div className="flex-1 min-w-0">
          <h3 className="text-base font-semibold text-gray-900 leading-tight">
            {hospital.name}
          </h3>
          <p className="mt-1 text-xs text-gray-500">
            {hospital.province} · {hospital.city} · {hospital.level}
          </p>
        </div>
        <button
          type="button"
          onClick={toggleFavorite}
          className="flex items-center gap-1 text-xs text-gray-400 hover:text-red-500 transition-colors flex-shrink-0"
        >
          <Heart
            className={cn("w-4 h-4", isFavorited && "fill-red-500 text-red-500")}
            strokeWidth={1.8}
          />
          <span>收藏</span>
        </button>
      </div>

      <p className="mt-2 text-sm text-gray-600 leading-snug">
        {hospital.address}
      </p>

      <div className="mt-3 flex flex-wrap items-center gap-2">
        {renderTags()}
        <span className="inline-flex items-center px-2 py-0.5 rounded text-xs bg-gray-100 text-gray-600">
          友好度 {hospital.friendlyScore}
        </span>
      </div>

      <div className="mt-3">
        <p className="text-xs text-gray-400 mb-1">可做项目</p>
        <div className="flex flex-wrap gap-1.5">
          {hospital.availableProjects.map((project) => (
            <span
              key={project}
              className="inline-flex items-center px-2 py-0.5 rounded text-xs border border-gray-200 text-gray-600"
            >
              {project}
            </span>
          ))}
        </div>
      </div>
    </div>
  );
}
