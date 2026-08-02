import { hospitals } from "@/data/resourceMock";
import { HospitalCard } from "./HospitalCard";

export function HospitalList() {
  return (
    <div className="pb-4">
      {hospitals.map((hospital) => (
        <HospitalCard key={hospital.id} hospital={hospital} />
      ))}
    </div>
  );
}
