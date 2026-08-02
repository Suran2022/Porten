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

export interface SharePost {
  id: string;
  author: ShareAuthor;
  content: string;
  latestComment?: ShareComment;
  views: number;
  comments: number;
  likes: number;
  publishedAt: string;
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
