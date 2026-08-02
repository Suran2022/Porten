export type GenderValue =
  | "cis_female"
  | "cis_male"
  | "trans_female"
  | "trans_male"
  | "non_binary"
  | "genderqueer"
  | "genderfluid"
  | "agender"
  | "bigender"
  | "pangender"
  | "questioning"
  | "intersex"
  | "prefer_not_to_say"
  | "other";

export interface GenderOption {
  value: GenderValue;
  label: string;
}

export const GENDER_OPTIONS: GenderOption[] = [
  { value: "trans_female", label: "跨性别女生" },
  { value: "trans_male", label: "跨性别男生" },
  { value: "cis_female", label: "女生" },
  { value: "cis_male", label: "男生" },
  { value: "non_binary", label: "非二元性别" },
  { value: "genderqueer", label: "性别酷儿" },
  { value: "genderfluid", label: "性别流动" },
  { value: "agender", label: "无性别" },
  { value: "bigender", label: "双性别" },
  { value: "pangender", label: "泛性别" },
  { value: "questioning", label: "探索中" },
  { value: "intersex", label: "间性人" },
  { value: "prefer_not_to_say", label: "不愿透露" },
  { value: "other", label: "其他" },
];

export function getGenderLabel(value?: string | null): string {
  if (!value) return "未设置";
  return (
    GENDER_OPTIONS.find((option) => option.value === value)?.label ?? value
  );
}

export interface UserProfile {
  id: string;
  nickname: string;
  avatar: string;
  backgroundUrl: string;
  portenId: string;
  followers: number;
  gender?: GenderValue | null;
  friendCount: number;
  transDays: number;
  latestDiary: string | null;
  mood: string | null;
  notificationEnabled: boolean;
}
