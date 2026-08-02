export type MoodTag =
  | "happy"
  | "calm"
  | "sad"
  | "anxious"
  | "angry"
  | "tired"
  | "grateful"
  | "lonely"
  | "hopeful"
  | "confused";

export interface MoodOption {
  value: MoodTag;
  label: string;
  emoji: string;
}

// 标签是**左右结构**：图标 + 文字水平排列（不是上下）
export const MOOD_OPTIONS: MoodOption[] = [
  { value: "happy", label: "开心", emoji: "😊" },
  { value: "calm", label: "平静", emoji: "😌" },
  { value: "sad", label: "难过", emoji: "😢" },
  { value: "anxious", label: "焦虑", emoji: "😰" },
  { value: "angry", label: "愤怒", emoji: "😠" },
  { value: "tired", label: "疲惫", emoji: "😩" },
  { value: "grateful", label: "感恩", emoji: "🙏" },
  { value: "lonely", label: "孤独", emoji: "🥀" },
  { value: "hopeful", label: "充满希望", emoji: "🌅" },
  { value: "confused", label: "迷茫", emoji: "🌫️" },
];

export function getMoodOption(value: string | null | undefined): MoodOption | null {
  if (!value) return null;
  return MOOD_OPTIONS.find((m) => m.value === value) ?? null;
}

// 顺性别（男女）→ 共用一套独立 UI（cis theme）
// 跨性别 / 非二元等 → 跨性别主题 UI（trans theme）
export function isCisGender(gender?: string | null): boolean {
  return gender === "cis_female" || gender === "cis_male";
}

export interface EmotionDiaryAuthor {
  id: number;
  nickname: string;
  avatar_url: string | null;
  porten_id: string;
}

export interface EmotionDiary {
  id: number;
  content: string;
  mood: MoodTag;
  mood_label: string;
  is_public: boolean;
  is_current: boolean;
  view_count: number;
  created_at: string;
  updated_at: string;
  author: EmotionDiaryAuthor;
  is_mine: boolean;
}

export interface EmotionDiaryList {
  items: EmotionDiary[];
  total: number;
}

export interface EmotionDiaryViewer {
  id: number;
  user_id: number;
  nickname: string;
  avatar_url: string | null;
  porten_id: string;
  viewed_at: string;
}

export interface EmotionDiaryViewerList {
  items: EmotionDiaryViewer[];
  total: number;
}
