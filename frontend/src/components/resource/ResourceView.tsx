import { ResourceTab } from "@/types/resource";
import { ResourceTipCard } from "./ResourceTipCard";
import { HospitalList } from "./HospitalList";
import { OrganizationList } from "./OrganizationList";
import { ProcessTimeline } from "./ProcessTimeline";

interface ResourceViewProps {
  activeTab: ResourceTab;
}

export function ResourceView({ activeTab }: ResourceViewProps) {
  return (
    <div className="min-h-full bg-white">
      {activeTab === "hospital" && (
        <>
          <ResourceTipCard />
          <HospitalList />
        </>
      )}
      {activeTab === "organization" && <OrganizationList />}
      {activeTab === "process" && <ProcessTimeline />}
    </div>
  );
}
