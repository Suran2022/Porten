import { useState } from "react";
import { ChevronRight, Users } from "lucide-react";
import { Organization } from "@/types/resource";

interface OrganizationCardProps {
  organization: Organization;
}

export function OrganizationCard({ organization }: OrganizationCardProps) {
  const [expanded, setExpanded] = useState(false);

  return (
    <div className="flex items-start gap-3 px-4 py-3 bg-white active:bg-gray-50/50 transition-colors cursor-pointer">
      <div className="w-12 h-12 rounded-full bg-gray-100 flex items-center justify-center flex-shrink-0">
        <Users className="w-6 h-6 text-gray-400" strokeWidth={1.8} />
      </div>

      <div className="flex-1 min-w-0">
        <div className="flex items-start justify-between gap-2">
          <div className="flex-1 min-w-0">
            <h3 className="text-base font-semibold text-gray-900 leading-tight">
              {organization.name}
            </h3>
            <p className="mt-0.5 text-xs text-gray-500">
              {organization.nature} · {organization.country} · {organization.centerCity}
            </p>
          </div>
          <span
            className="flex-shrink-0 text-sm font-semibold"
            style={{
              background: "linear-gradient(90deg, #5BCEFA, #F5A9B8, #5BCEFA)",
              WebkitBackgroundClip: "text",
              backgroundClip: "text",
              color: "transparent",
            }}
          >
            联系组织
          </span>
        </div>

        <button
          type="button"
          onClick={(e) => {
            e.stopPropagation();
            setExpanded((prev) => !prev);
          }}
          className="mt-2 w-full flex items-center justify-between text-left"
        >
          <span className="text-sm text-gray-600">
            覆盖城市
          </span>
          <span
            className="text-gray-400 transition-transform duration-300"
            style={{ transform: expanded ? "rotate(90deg)" : "rotate(0deg)" }}
          >
            <ChevronRight className="w-4 h-4" strokeWidth={1.5} />
          </span>
        </button>

        <div
          className="overflow-hidden transition-all duration-300 ease-out"
          style={{
            maxHeight: expanded ? "200px" : "0px",
            opacity: expanded ? 1 : 0,
          }}
        >
          <div className="pt-2 flex flex-wrap gap-1.5">
            {organization.coveredCities.map((city) => (
              <span
                key={city}
                className="inline-flex items-center px-2 py-0.5 rounded text-xs bg-gray-100 text-gray-600"
              >
                {city}
              </span>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
