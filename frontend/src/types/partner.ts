/**
 * Porten 助手（Partner）相关类型。
 *
 * 一个 Porten 助手对应列表里的一张卡片，助手下可有若干条
 * 官方推送的文章；点击助手卡片进入助手详情页查看所有文章。
 */

export interface PortenAssistant {
  /** 助手唯一 ID */
  id: string;
  /** 助手名称（用于顶部栏居中标题） */
  name: string;
  /** 助手头像（可空，为空时回退到文字占位） */
  avatar?: string | null;
  /** 助手简介（列表卡片上显示） */
  bio?: string | null;
  /** 当前助手下的文章数 */
  article_count: number;
  /** 当前用户未读文章数 */
  unread_count: number;
}

export interface AssistantArticleListItem {
  id: number;
  assistant_id: string;
  title: string;
  summary: string;
  publish_time: string;
  publisher: string;
  is_read: boolean;
}

export interface AssistantArticleDetail extends AssistantArticleListItem {
  /** 完整 markdown 正文，前端用 react-markdown 渲染 */
  content: string;
}

export interface AssistantListItem {
  /** 助手元信息 */
  assistant: PortenAssistant;
  /** 助手下最新一篇文章，没有文章时为 null */
  latestArticle: AssistantArticleListItem | null;
}

