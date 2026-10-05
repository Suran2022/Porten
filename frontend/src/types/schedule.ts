/** 日程卡片配色（创建时随机三选一）。 */
export type ScheduleColor = "pink" | "coffee" | "blue";

/** 配色候选（mock 引擎随机分配用）与卡片背景色映射。 */
export const SCHEDULE_COLOR_POOL: ScheduleColor[] = ["pink", "coffee", "blue"];

/** 日程卡片背景色：淡粉色不饱和 / 咖啡色不饱和 / 淡蓝色不饱和。 */
export const SCHEDULE_CARD_BG: Record<ScheduleColor, string> = {
  pink: "#F7C5D0",
  coffee: "#C7A98B",
  blue: "#A9C9E8",
};

/** 日程分类。 */
export type ScheduleCategory =
  | "travel"
  | "date"
  | "visit"
  | "work"
  | "daily"
  | "study"
  | "other";

/** 日程分类选项（值 + 中文标签）。 */
export const SCHEDULE_CATEGORIES: {
  value: ScheduleCategory;
  label: string;
}[] = [
  { value: "travel", label: "旅行" },
  { value: "date", label: "约会" },
  { value: "visit", label: "就诊" },
  { value: "work", label: "工作" },
  { value: "daily", label: "日常" },
  { value: "study", label: "学习" },
  { value: "other", label: "其他" },
];

/** 日程创建来源：完整表单 / 时间线快捷创建。 */
export type ScheduleSource = "form" | "quick";

/** 关联对象类型：旅行分类关联旅程 / 约会分类关联约定。 */
export type ScheduleRelatedType = "trip" | "agreement";

/** 日程条目。 */
export interface ScheduleItem {
  id: number;
  /** 日程日期，格式 YYYY-MM-DD */
  date: string;
  /** 开始时间，格式 HH:mm */
  start_time: string;
  /** 结束时间，格式 HH:mm；选填 */
  end_time: string | null;
  /** 日程标题，选填 */
  title: string | null;
  /** 日程详情，选填 */
  detail: string | null;
  /** 日程分类 */
  category: ScheduleCategory | null;
  /** 关联对象类型 */
  related_type: ScheduleRelatedType | null;
  /** 关联对象 id */
  related_id: number | null;
  /** 地点，选填 */
  place: string | null;
  /** 参与同胞的用户 id 列表 */
  participant_ids: number[];
  /** 卡片配色（创建时随机分配） */
  color: ScheduleColor;
  /** 创建来源 */
  source: ScheduleSource;
}

/** 创建/编辑日程的提交载荷。 */
export interface ScheduleCreatePayload {
  date: string;
  start_time: string;
  end_time?: string | null;
  title?: string | null;
  detail?: string | null;
  category?: ScheduleCategory | null;
  related_type?: ScheduleRelatedType | null;
  related_id?: number | null;
  place?: string | null;
  participant_ids?: number[];
  source: ScheduleSource;
}

/** 关联选择项（旅程/约定 mock 项）。 */
export interface ScheduleRelatedItem {
  id: number;
  label: string;
}

/** 参与同胞候选（mock）。 */
export interface ScheduleComrade {
  id: number;
  nickname: string;
  avatar: string;
}

/** 关联数据与同胞候选集合。 */
export interface ScheduleRelatedData {
  trips: ScheduleRelatedItem[];
  agreements: ScheduleRelatedItem[];
  comrades: ScheduleComrade[];
}
