import { organizations } from "@/data/resourceMock";
import { OrganizationCard } from "./OrganizationCard";

export function OrganizationList() {
  return (
    <div className="pb-4">
      {organizations.map((organization) => (
        <OrganizationCard key={organization.id} organization={organization} />
      ))}
    </div>
  );
}
