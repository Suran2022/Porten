export interface Hospital {
  id: string;
  name: string;
  province: string;
  city: string;
  address: string;
  level: string;
  canIssueDiagnosis: boolean;
  friendlyScore: number;
  requiresParent: boolean;
  firstVisitIssue: boolean;
  availableProjects: string[];
  isFavorited: boolean;
}

export interface Organization {
  id: string;
  name: string;
  nature: string;
  country: string;
  centerCity: string;
  coveredCities: string[];
  contactUrl?: string;
}

export interface ProcessNode {
  id: string;
  title: string;
  content: string;
  note?: string;
}

export type ResourceTab = "hospital" | "organization" | "process";
