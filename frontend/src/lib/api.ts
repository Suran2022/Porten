const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || "http://localhost:8000/api/v1";

export interface ApiResponse<T = unknown> {
  code: number;
  message: string;
  data: T | null;
}

export interface TokenData {
  access_token: string;
  token_type: string;
  expires_in: number;
}

export interface UserBrief {
  id: number;
  email: string;
  porten_id: string;
  nickname: string;
  avatar_url: string;
  background_url: string;
  role: string;
}

export interface LoginData {
  token: TokenData;
  user: UserBrief;
}

export interface ProfileData {
  id: number;
  email: string;
  porten_id: string;
  nickname: string;
  avatar_url: string;
  background_url: string;
  role: string;
  gender?: string | null;
  friend_count: number;
  trans_days: number;
  latest_diary?: string | null;
  mood?: string | null;
}

const TOKEN_KEY = "porten_token";

export function getToken(): string | null {
  return localStorage.getItem(TOKEN_KEY);
}

export function setToken(token: string): void {
  localStorage.setItem(TOKEN_KEY, token);
}

export function removeToken(): void {
  localStorage.removeItem(TOKEN_KEY);
}

export async function apiRequest<T = unknown>(
  path: string,
  options: RequestInit = {}
): Promise<T> {
  const url = `${API_BASE_URL}${path}`;
  const token = getToken();

  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    ...(options.headers as Record<string, string>),
  };
  if (token) {
    headers["Authorization"] = `Bearer ${token}`;
  }

  const response = await fetch(url, {
    ...options,
    headers,
  });

  const result = (await response.json()) as ApiResponse<T>;

  if (!response.ok || result.code !== 0) {
    if (isAuthError(response, result)) {
      handleAuthError();
    }
    // 不向上层暴露后端 message 细节，由调用方决定如何提示
    throw new ApiError(
      result.message || `request failed: ${response.status}`,
      response.status
    );
  }

  return result.data as T;
}

export class ApiError extends Error {
  status: number;
  constructor(message: string, status: number) {
    super(message);
    this.name = "ApiError";
    this.status = status;
  }
}

export class TimeoutError extends Error {
  constructor(message = "请求超时") {
    super(message);
    this.name = "TimeoutError";
  }
}

function handleAuthError() {
  removeToken();
  const publicPaths = ["/login", "/register"];
  if (!publicPaths.includes(window.location.pathname)) {
    window.location.href = "/login";
  }
}

function isAuthError(response: Response, result: ApiResponse<unknown>): boolean {
  if (response.status === 401) return true;
  if (result.code === 401) return true;
  const msg = (result.message || "").toLowerCase();
  const authKeywords = [
    "unauthorized",
    "未授权",
    "认证失败",
    "未登录",
    "expired",
    "invalid token",
  ];
  return authKeywords.some((k) => msg.includes(k));
}

export type VerificationCodePurpose =
  | "register"
  | "login"
  | "reset_password"
  | "change_email_old"
  | "change_email_new";

export async function sendVerificationCode(
  email: string,
  purpose: VerificationCodePurpose = "register"
): Promise<void> {
  await apiRequest("/auth/send-verification-code", {
    method: "POST",
    body: JSON.stringify({ email, purpose }),
  });
}

export async function changeEmail(payload: {
  new_email: string;
  old_code: string;
  new_code: string;
}): Promise<ProfileData> {
  return apiRequest<ProfileData>("/users/me/change-email", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export type {
  EmotionDiary,
  EmotionDiaryList,
  EmotionDiaryViewer,
  EmotionDiaryViewerList,
  MoodOption,
  MoodTag,
} from "@/types/emotionDiary";
import type {
  EmotionDiary,
  EmotionDiaryList,
  EmotionDiaryViewerList,
  MoodTag,
} from "@/types/emotionDiary";

export interface EmotionDiaryCreatePayload {
  content: string;
  mood: MoodTag;
  is_public?: boolean;
}

export async function fetchEmotionDiaryCurrent(): Promise<EmotionDiary | null> {
  const res = await apiRequest<EmotionDiary | null>(
    "/emotion-diaries/current"
  );
  return res;
}

export async function createEmotionDiary(
  payload: EmotionDiaryCreatePayload
): Promise<EmotionDiary> {
  return apiRequest<EmotionDiary>("/emotion-diaries", {
    method: "POST",
    body: JSON.stringify({
      content: payload.content,
      mood: payload.mood,
      is_public: payload.is_public ?? true,
    }),
  });
}

export async function updateEmotionDiaryCurrent(
  payload: EmotionDiaryCreatePayload
): Promise<EmotionDiary> {
  return apiRequest<EmotionDiary>("/emotion-diaries/current", {
    method: "PATCH",
    body: JSON.stringify({
      content: payload.content,
      mood: payload.mood,
      is_public: payload.is_public ?? true,
    }),
  });
}

export async function fetchEmotionDiaryHistory(
  cursor?: number,
  limit = 50
): Promise<EmotionDiaryList> {
  const params = new URLSearchParams();
  if (cursor) params.append("cursor", String(cursor));
  params.append("limit", String(limit));
  return apiRequest<EmotionDiaryList>(
    `/emotion-diaries/history?${params.toString()}`
  );
}

export async function deleteEmotionDiary(id: number): Promise<void> {
  await apiRequest(`/emotion-diaries/${id}`, {
    method: "DELETE",
  });
}

export async function fetchEmotionDiaryViewers(
  id: number,
  cursor?: number,
  limit = 50
): Promise<EmotionDiaryViewerList> {
  const params = new URLSearchParams();
  if (cursor) params.append("cursor", String(cursor));
  params.append("limit", String(limit));
  return apiRequest<EmotionDiaryViewerList>(
    `/emotion-diaries/${id}/viewers?${params.toString()}`
  );
}

export async function register(email: string, password: string, verificationCode: string): Promise<LoginData> {
  return apiRequest<LoginData>("/auth/register", {
    method: "POST",
    body: JSON.stringify({
      email,
      password,
      confirm_password: password,
      verification_code: verificationCode,
    }),
  });
}

export async function loginByEmailCode(email: string, verificationCode: string): Promise<LoginData> {
  return apiRequest<LoginData>("/auth/login/email-code", {
    method: "POST",
    body: JSON.stringify({ email, verification_code: verificationCode }),
  });
}

export async function loginByPassword(email: string, password: string): Promise<LoginData> {
  return apiRequest<LoginData>("/auth/login/password", {
    method: "POST",
    body: JSON.stringify({ email, password }),
  });
}

export async function loginByPortenId(portenId: string, password: string): Promise<LoginData> {
  return apiRequest<LoginData>("/auth/login/porten-id", {
    method: "POST",
    body: JSON.stringify({ porten_id: portenId, password }),
  });
}

export async function logout(): Promise<void> {
  await apiRequest("/auth/logout", {
    method: "POST",
  });
}

export async function fetchProfile(): Promise<ProfileData> {
  return apiRequest<ProfileData>("/users/me", {
    method: "GET",
  });
}

// 按 userId 获取同胞公开资料（同胞资料页使用）
export async function fetchComradeProfile(userId: number | string): Promise<ProfileData> {
  return apiRequest<ProfileData>(`/users/${userId}/profile`, {
    method: "GET",
  });
}

export async function fetchDefaultAvatar(): Promise<string> {
  const data = await apiRequest<{ avatar_url: string }>("/auth/default-avatar", {
    method: "GET",
  });
  return data.avatar_url;
}

export async function fetchDefaultNickname(): Promise<string> {
  const data = await apiRequest<{ nickname: string }>("/auth/default-nickname", {
    method: "GET",
  });
  return data.nickname;
}

export async function updateNickname(nickname: string): Promise<ProfileData> {
  return apiRequest<ProfileData>("/users/me/nickname", {
    method: "PATCH",
    body: JSON.stringify({ nickname }),
  });
}

export async function updateAvatar(avatarUrl: string): Promise<ProfileData> {
  return apiRequest<ProfileData>("/users/me/avatar", {
    method: "PATCH",
    body: JSON.stringify({ avatar_url: avatarUrl }),
  });
}

export async function updateBackground(backgroundUrl: string): Promise<ProfileData> {
  return apiRequest<ProfileData>("/users/me/background", {
    method: "PATCH",
    body: JSON.stringify({ background_url: backgroundUrl }),
  });
}

export async function updateProfile(payload: {
  nickname?: string;
  avatarUrl?: string;
  backgroundUrl?: string;
  gender?: string;
}): Promise<ProfileData> {
  return apiRequest<ProfileData>("/users/me", {
    method: "PATCH",
    body: JSON.stringify({
      nickname: payload.nickname,
      avatar_url: payload.avatarUrl,
      background_url: payload.backgroundUrl,
      gender: payload.gender,
    }),
  });
}

export interface SearchUserResult {
  id: number;
  porten_id: string;
  nickname: string;
  avatar_url: string;
}

export interface SearchGroupResult {
  id: number;
  name: string;
  avatar_url: string;
  member_count: number;
  tags: string[];
  group_type: string;
  searchable_by_name: boolean;
  camp_id?: string;
  description?: string;
  discoverable_by?: string;
  max_members?: number;
}

export interface FriendRequestItem {
  id: number;
  sender_id: number;
  receiver_id: number;
  sender_nickname: string;
  sender_avatar_url: string;
  message: string;
  status: string;
  source?: string;
  created_at: string;
}

export interface GroupRequestItem {
  id: number;
  group_id: number;
  group_name: string;
  group_avatar_url: string;
  user_id: number;
  user_nickname: string;
  user_avatar_url: string;
  message: string;
  status: string;
  created_at: string;
}

export interface BadgeCounts {
  friend_requests: number;
  group_requests: number;
}

export interface ContactFriend {
  id: number;
  user_id: number;
  nickname: string;
  avatar_url: string;
  created_at: string;
}

export interface ContactGroup {
  id: number;
  group_id: number;
  name: string;
  avatar_url: string;
  role: string;
  created_at: string;
}

export interface ContactsData {
  friends: ContactFriend[];
  groups: ContactGroup[];
}

export interface ConversationItem {
  id: number;
  type: "friend" | "group";
  name: string;
  avatar: string;
  last_message: string;
  last_message_time: string;
  last_message_sender_id?: number;
  last_message_sender_name?: string;
  unread_count: number;
  member_count?: number;
  // 好友会话对方的用户 id（同胞资料页"传达消息"据此定位会话）
  friend_user_id?: number;
}

export interface MessageItem {
  id: number;
  conversation_id: number;
  sender_id?: number;
  sender_nickname?: string;
  sender_avatar_url?: string;
  content: string;
  extra?: Record<string, unknown> | null;
  message_type: string;
  created_at: string;
}

export async function getMessages(
  conversationId: number,
  beforeId?: number,
  afterId?: number,
  limit: number = 50
): Promise<MessageItem[]> {
  const params = new URLSearchParams();
  if (beforeId) params.append("before_id", String(beforeId));
  if (afterId) params.append("after_id", String(afterId));
  params.append("limit", String(limit));
  return apiRequest<MessageItem[]>(
    `/messages/conversation/${conversationId}?${params.toString()}`
  );
}

export interface SendMessagePayload {
  conversation_id: number;
  message_type: "text" | "image" | "video" | "file" | "voice" | "system";
  content: string;
  extra?: Record<string, unknown>;
  media_file_id?: number;
}

export async function sendMessage(payload: SendMessagePayload): Promise<MessageItem> {
  return apiRequest<MessageItem>("/messages/send", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export interface CreateGroupPayload {
  name: string;
  group_type: string;
  description?: string;
  avatar_url?: string;
  tags: string[];
  discoverable_by: string;
  max_members: number;
}

export interface CreateGroupResult {
  id: number;
  name: string;
  avatar_url: string | null;
  member_count: number;
  group_type: string;
  conversation_id: number;
}

export async function createGroup(payload: CreateGroupPayload): Promise<CreateGroupResult> {
  return apiRequest<CreateGroupResult>("/groups/create", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export interface UpdateGroupPayload {
  name?: string;
  description?: string;
  avatar_url?: string;
  tags?: string[];
  discoverable_by?: string;
  max_members?: number;
}

export interface UpdateGroupResult {
  id: number;
  name: string;
  avatar_url: string | null;
  member_count: number;
  group_type: string;
  camp_id?: string;
  description?: string;
  discoverable_by?: string;
  max_members?: number;
  tags: string[];
}

export async function updateGroup(
  groupId: number,
  payload: UpdateGroupPayload
): Promise<UpdateGroupResult> {
  return apiRequest<UpdateGroupResult>(`/groups/${groupId}`, {
    method: "PATCH",
    body: JSON.stringify(payload),
  });
}

export interface UploadResult {
  media_file_id: number;
  url: string;
  thumb_url?: string | null;
  name?: string;
  size?: number;
}

export async function uploadImage(file: File, onProgress?: (p: number) => void, permanent?: boolean): Promise<UploadResult> {
  return uploadFile("/upload/image", file, onProgress, permanent);
}

export async function uploadVideo(file: File, onProgress?: (p: number) => void): Promise<UploadResult> {
  return uploadFile("/upload/video", file, onProgress);
}

export async function uploadGenericFile(
  file: File,
  onProgress?: (p: number) => void
): Promise<UploadResult> {
  return uploadFile("/upload/file", file, onProgress);
}

export async function uploadVoice(
  file: File,
  onProgress?: (p: number) => void
): Promise<UploadResult> {
  return uploadFile("/upload/voice", file, onProgress);
}

function uploadFile(
  path: string,
  file: File,
  onProgress?: (p: number) => void,
  permanent?: boolean
): Promise<UploadResult> {
  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    const formData = new FormData();
    formData.append("file", file);

    const url = permanent
      ? `${API_BASE_URL}${path}?permanent=1`
      : `${API_BASE_URL}${path}`;
    xhr.open("POST", url);
    const token = getToken();
    if (token) {
      xhr.setRequestHeader("Authorization", `Bearer ${token}`);
    }

    if (onProgress) {
      xhr.upload.addEventListener("progress", (event) => {
        if (event.lengthComputable) {
          onProgress(Math.round((event.loaded / event.total) * 100));
        }
      });
    }

    xhr.onload = () => {
      if (xhr.status >= 200 && xhr.status < 300) {
        const result = JSON.parse(xhr.responseText) as { data: UploadResult };
        resolve(result.data);
      } else {
        let message = "上传失败";
        try {
          const result = JSON.parse(xhr.responseText) as { message?: string };
          message = result.message || message;
        } catch {
          // ignore
        }
        reject(new Error(message));
      }
    };
    xhr.onerror = () => reject(new Error("上传失败"));
    xhr.send(formData);
  });
}

export async function searchUserByPortenId(portenId: string): Promise<SearchUserResult | null> {
  return apiRequest<SearchUserResult | null>(`/contacts/search/users?porten_id=${encodeURIComponent(portenId)}`);
}

export async function searchUserByNickname(nickname: string): Promise<SearchUserResult | null> {
  return apiRequest<SearchUserResult | null>(`/contacts/search/users?nickname=${encodeURIComponent(nickname)}`);
}

export async function searchGroups(keyword: string): Promise<SearchGroupResult[]> {
  return apiRequest<SearchGroupResult[]>(`/groups/search?keyword=${encodeURIComponent(keyword)}`);
}

// ===== Global search (同胞 / 营地 / 文件 / 知识 / 图片) =====
export type SearchCategoryKey = "all" | "comrade" | "camp" | "file" | "knowledge" | "image";

export interface SearchComradeItem {
  id: number;
  porten_id: string;
  nickname: string;
  avatar_url: string | null;
}

export interface SearchCampItem {
  id: number;
  name: string;
  avatar_url: string | null;
  member_count: number;
  tags: string[];
  group_type?: string | null;
  camp_id?: string | null;
  description?: string | null;
}

export interface SearchFileItem {
  id: number;
  name: string;
  url: string;
  size: number | null;
  uploader_id: number | null;
  uploader_nickname: string | null;
  created_at: string | null;
}

export interface SearchImageItem {
  id: number;
  name: string;
  url: string;
  size: number | null;
  uploader_id: number | null;
  uploader_nickname: string | null;
  created_at: string | null;
}

export interface SearchKnowledgeItem {
  id: string;
  kind: string;
  title: string;
  summary: string | null;
  cover_url: string | null;
  author_id: string | null;
  author_nickname: string | null;
  author_avatar: string | null;
}

export interface SearchAllData {
  query: string;
  // Order is fixed: 同胞 → 营地 → 文件 → 知识 → 图片
  comrade: SearchComradeItem[];
  camp: SearchCampItem[];
  file: SearchFileItem[];
  knowledge: SearchKnowledgeItem[];
  image: SearchImageItem[];
}

export interface SearchCategoryData {
  query: string;
  items: Array<
    SearchComradeItem | SearchCampItem | SearchFileItem | SearchKnowledgeItem | SearchImageItem
  >;
}

export async function globalSearch(
  query: string,
  type: SearchCategoryKey = "all",
  limit?: number,
  options?: { timeoutMs?: number; signal?: AbortSignal }
): Promise<SearchAllData | SearchCategoryData> {
  const params = new URLSearchParams();
  if (query) params.set("q", query);
  if (type && type !== "all") params.set("type", type);
  if (limit && limit > 0) params.set("limit", String(limit));
  const path = `/search?${params.toString()}`;

  // Set up timeout via AbortController (8s default for search)
  const controller = new AbortController();
  const timeoutMs = options?.timeoutMs ?? 8000;
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  // Forward caller's signal
  if (options?.signal) {
    if (options.signal.aborted) {
      controller.abort();
    } else {
      options.signal.addEventListener("abort", () => controller.abort());
    }
  }
  try {
    return await apiRequest<SearchAllData | SearchCategoryData>(path, {
      signal: controller.signal,
    });
  } catch (e) {
    if (e instanceof Error && (e.name === "AbortError" || controller.signal.aborted)) {
      throw new TimeoutError();
    }
    throw e;
  } finally {
    clearTimeout(timer);
  }
}


export async function sendFriendRequest(
  receiverPortenId: string,
  message?: string
): Promise<FriendRequestItem> {
  return apiRequest<FriendRequestItem>("/friend-requests/", {
    method: "POST",
    body: JSON.stringify({ receiver_porten_id: receiverPortenId, message }),
  });
}

export async function fetchReceivedFriendRequests(): Promise<FriendRequestItem[]> {
  return apiRequest<FriendRequestItem[]>("/friend-requests/received");
}

export async function handleFriendRequest(
  requestId: number,
  action: "accept" | "reject"
): Promise<unknown> {
  return apiRequest<unknown>(`/friend-requests/${requestId}/handle`, {
    method: "POST",
    body: JSON.stringify({ action }),
  });
}

export async function sendGroupRequest(
  groupId: number,
  message?: string
): Promise<GroupRequestItem> {
  return apiRequest<GroupRequestItem>("/groups/requests", {
    method: "POST",
    body: JSON.stringify({ group_id: groupId, message }),
  });
}

export async function fetchReceivedGroupRequests(): Promise<GroupRequestItem[]> {
  return apiRequest<GroupRequestItem[]>("/groups/requests/received");
}

export async function handleGroupRequest(
  requestId: number,
  action: "accept" | "reject"
): Promise<unknown> {
  return apiRequest<unknown>(`/groups/requests/${requestId}/handle`, {
    method: "POST",
    body: JSON.stringify({ action }),
  });
}

export async function fetchBadgeCounts(): Promise<BadgeCounts> {
  return apiRequest<BadgeCounts>("/notifications/badge");
}

export async function markNotificationsRead(type: "friend" | "group"): Promise<unknown> {
  return apiRequest<unknown>("/notifications/read", {
    method: "POST",
    body: JSON.stringify({ type }),
  });
}

export async function fetchContacts(): Promise<ContactsData> {
  return apiRequest<ContactsData>("/contacts/");
}

export async function fetchConversations(): Promise<{ conversations: ConversationItem[] }> {
  return apiRequest<{ conversations: ConversationItem[] }>("/conversations/");
}

export async function markConversationRead(conversationId: number): Promise<unknown> {
  return apiRequest<unknown>(`/conversations/${conversationId}/read`, {
    method: "POST",
  });
}

export function readFileAsDataURL(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result as string);
    reader.onerror = reject;
    reader.readAsDataURL(file);
  });
}

export interface SystemMessageItem {
  id: number;
  version: string;
  title: string;
  content: string;
  message_type: string;
  is_custom_title: boolean;
  is_read: boolean;
  created_at: string;
}

export interface SystemMessageListResponse {
  messages: SystemMessageItem[];
  unread_count: number;
}

export async function fetchSystemMessages(): Promise<SystemMessageListResponse> {
  return apiRequest<SystemMessageListResponse>("/system-messages");
}

export async function fetchSystemMessageUnreadCount(): Promise<{ unread_count: number }> {
  return apiRequest<{ unread_count: number }>("/system-messages/unread-count");
}

export async function sendAgreementEmail(
  recipient: string,
  subject: string,
  htmlBody: string
): Promise<void> {
  await apiRequest("/agreements/send-email", {
    method: "POST",
    body: JSON.stringify({ recipient, subject, html_body: htmlBody }),
  });
}

export async function markSystemMessageRead(messageId: number): Promise<unknown> {
  return apiRequest<unknown>(`/system-messages/${messageId}/read`, {
    method: "PATCH",
  });
}

export async function markAllSystemMessagesRead(): Promise<unknown> {
  return apiRequest<unknown>("/system-messages/read-all", {
    method: "POST",
  });
}

// ===== Porten 伙伴（Porten Assistants） =====
import type {
  AssistantArticleDetail,
  AssistantArticleListItem,
  PortenAssistant,
} from "@/types/partner";

export interface AssistantListResponse {
  assistants: PortenAssistant[];
}

export interface AssistantArticleListResponse {
  assistant_id: string;
  articles: AssistantArticleListItem[];
  unread_count: number;
}

export async function fetchAssistants(): Promise<PortenAssistant[]> {
  const data = await apiRequest<AssistantListResponse>("/assistants");
  return data.assistants;
}

export async function fetchAssistantArticles(
  assistantId: string
): Promise<AssistantArticleListResponse> {
  return apiRequest<AssistantArticleListResponse>(
    `/assistants/${assistantId}/articles`
  );
}

export async function fetchAssistantArticle(
  assistantId: string,
  articleId: number
): Promise<AssistantArticleDetail> {
  return apiRequest<AssistantArticleDetail>(
    `/assistants/${assistantId}/articles/${articleId}`
  );
}

export async function markAssistantArticleRead(
  assistantId: string,
  articleId: number
): Promise<void> {
  await apiRequest(`/assistants/${assistantId}/articles/${articleId}/read`, {
    method: "POST",
  });
}

export function compressImage(
  file: File,
  options: { maxWidth?: number; maxHeight?: number; quality?: number } = {}
): Promise<string> {
  const { maxWidth = 1024, maxHeight = 1024, quality = 0.8 } = options;
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = (event) => {
      const img = new Image();
      img.onload = () => {
        let { width, height } = img;
        if (width > maxWidth || height > maxHeight) {
          const ratio = Math.min(maxWidth / width, maxHeight / height);
          width = Math.round(width * ratio);
          height = Math.round(height * ratio);
        }
        const canvas = document.createElement("canvas");
        canvas.width = width;
        canvas.height = height;
        const ctx = canvas.getContext("2d");
        if (!ctx) {
          reject(new Error("Canvas context not available"));
          return;
        }
        ctx.drawImage(img, 0, 0, width, height);
        canvas.toBlob(
          (blob) => {
            if (!blob) {
              reject(new Error("Canvas toBlob failed"));
              return;
            }
            const compressedReader = new FileReader();
            compressedReader.onload = () =>
              resolve(compressedReader.result as string);
            compressedReader.onerror = reject;
            compressedReader.readAsDataURL(blob);
          },
          file.type,
          quality
        );
      };
      img.onerror = reject;
      img.src = event.target?.result as string;
    };
    reader.onerror = reject;
    reader.readAsDataURL(file);
  });
}
