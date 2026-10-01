export type KnowledgeTab = "share" | "learn";

export interface ShareAuthor {
  id: string;
  nickname: string;
  avatar?: string;
}

export interface ShareComment {
  author: string;
  content: string;
}

/** 分享详情页的交流条目（平铺展示，不支持回复） */
export interface ShareCommentItem {
  id: string;
  author: string;
  avatar?: string;
  content: string;
  /** 发布时间（ISO 字符串），用于相对时间展示 */
  publishedAt: string;
  /** 是否为当前用户发布的交流（显示删除按钮） */
  isOwn?: boolean;
  /** 是否已点亮太阳 */
  lit?: boolean;
}

export interface SharePost {
  id: string;
  author: ShareAuthor;
  content: string;
  latestComment?: ShareComment;
  /** 详情页交流列表（comments 字段保留为数量计数） */
  commentList?: ShareCommentItem[];
  views: number;
  comments: number;
  likes: number;
  publishedAt: string;
  /** 发布日期（详情页年月日展示用），如 "2026-09-28" */
  publishedDate?: string;
  /** 是否为当前用户发布的文章（详情页据此显示编辑入口） */
  isOwn?: boolean;
}

export type LearnCategory =
  | "community"
  | "mental"
  | "relationship"
  | "workplace"
  | "campus"
  | "love"
  | "fashion"
  | "medical";

export interface LearnPost {
  id: string;
  type: "article" | "video";
  category: LearnCategory;
  title: string;
  summary: string;
  coverUrl?: string;
  videoUrl?: string;
  duration?: string;
  tags: string[];
  views: number;
  shares: number;
  publishedAt: string;
}
