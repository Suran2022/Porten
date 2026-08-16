/**
 * Mock 引擎：在 USE_MOCK 模式下接管全部 API 请求。
 *
 * - 数据来自 src/data/mockServerData.ts（模块级内存状态）。
 * - 所有请求带随机延迟，模拟真实网络节奏。
 * - 发送消息后会由"对方"在一段时间后回复，通过事件回调推送给
 *   messageStore，驱动会话列表与未读角标更新。
 */

import {
  currentUser,
  DEFAULT_AVATAR,
  findUser,
  groupMemberOptions,
  imageUrl,
  mockAssistantArticles,
  mockAssistants,
  mockContactGroups,
  mockConversations,
  mockDiaries,
  mockDiaryViewers,
  mockFriendRequests,
  mockFriends,
  mockGroupRequests,
  mockMessages,
  mockSearchFiles,
  mockSearchImages,
  mockSystemMessages,
  mockUsers,
  MockConversation,
  MockMessage,
  MockSystemMessage,
  MockUser,
} from "@/data/mockServerData";
import { sharePosts } from "@/data/knowledgeMock";

/* ============================= 工具 ============================= */

function delay(ms?: number): Promise<void> {
  const wait = ms ?? 140 + Math.random() * 220;
  return new Promise((resolve) => setTimeout(resolve, wait));
}

function parseQuery(queryString: string): URLSearchParams {
  return new URLSearchParams(queryString);
}

interface MockRequestOptions {
  method?: string;
  body?: string;
}

interface RouteContext {
  body: Record<string, unknown> | null;
  query: URLSearchParams;
  params: Record<string, string>;
}

type RouteHandler = (ctx: RouteContext) => unknown;

interface Route {
  method: string;
  pattern: RegExp;
  handler: RouteHandler;
}

/* ============================= 内存状态 ============================= */

const conversations: MockConversation[] = mockConversations.map((c) => ({ ...c }));
const messages: MockMessage[] = mockMessages.map((m) => ({ ...m }));
const friends = mockFriends.map((f) => ({ ...f }));
const contactGroups = mockContactGroups.map((g) => ({ ...g }));
const friendRequests = mockFriendRequests.map((r) => ({ ...r }));
const groupRequests = mockGroupRequests.map((r) => ({ ...r }));
const systemMessages: MockSystemMessage[] = mockSystemMessages.map((m) => ({ ...m }));
const assistants = mockAssistants.map((a) => ({ ...a }));
const assistantArticles = mockAssistantArticles.map((a) => ({ ...a }));
const diaries = mockDiaries.map((d) => ({ ...d }));

const me: MockUser = {
  ...currentUser,
  mood: currentUser.mood,
  latest_diary: currentUser.latest_diary,
};

let nextId = 100_000;
let nextMessageId = 10_000;

const badgeReadState: Record<string, boolean> = { friend: false, group: false };

function touchConversation(id: number, lastMessage: string, time: string, senderId?: number, senderName?: string) {
  const conv = conversations.find((c) => c.id === id);
  if (!conv) return;
  conv.last_message = lastMessage;
  conv.last_message_time = time;
  conv.last_message_sender_id = senderId;
  conv.last_message_sender_name = senderName;
  const index = conversations.indexOf(conv);
  if (index > 0) {
    conversations.splice(index, 1);
    conversations.unshift(conv);
  }
}

function sortedConversations() {
  return [...conversations].sort(
    (a, b) =>
      new Date(b.last_message_time).getTime() - new Date(a.last_message_time).getTime()
  );
}

/* ============================= 消息映射 ============================= */

function messageToApi(m: MockMessage) {
  return {
    id: m.id,
    conversation_id: m.conversationId,
    sender_id: Number(m.senderId),
    sender_nickname: m.senderName,
    sender_avatar_url: m.senderAvatar,
    content: m.content,
    extra: m.extra ?? null,
    message_type: m.type,
    created_at: m.timestamp,
  };
}

function previewFor(type: string, content: string): string {
  if (type === "text") return content;
  if (type === "image") return "[图片]";
  if (type === "video") return "[视频]";
  if (type === "file") return "[文件]";
  if (type === "voice") return "[语音]";
  if (type === "share") return "[分享]";
  if (type === "nameCard") return "[名片]";
  if (type === "call") return "[通话]";
  if (type === "system") return content;
  return "[消息]";
}

function profileOf(u: MockUser) {
  return {
    id: u.id,
    email: u.email,
    porten_id: u.porten_id,
    nickname: u.nickname,
    avatar_url: u.avatar_url,
    background_url: u.background_url,
    role: "user",
    gender: u.gender,
    friend_count: friends.length,
    trans_days: u.trans_days,
    latest_diary: u.id === me.id ? me.latest_diary : u.latest_diary,
    mood: u.id === me.id ? me.mood : u.mood,
  };
}

function loginData() {
  return {
    token: {
      access_token: `mock-token-${Date.now()}`,
      token_type: "bearer",
      expires_in: 604800,
    },
    user: {
      id: me.id,
      email: me.email,
      porten_id: me.porten_id,
      nickname: me.nickname,
      avatar_url: me.avatar_url,
      background_url: me.background_url,
      role: "user",
    },
  };
}

/* ============================= 模拟回复 ============================= */

const REPLY_POOL = [
  "哈哈哈好呀",
  "收到收到～",
  "嗯嗯，我也是这么想的",
  "好呀，就这么定了",
  "刚刚在忙，才看到消息",
  "可以呀，没问题",
  "这个我也有同感",
  "好呀，晚上有空吗？",
  "太棒了，替开心",
  "晚点回复你，先忙一下",
  "没问题，交给我吧",
  "好呀，下次一起",
];

type IncomingListener = (message: MockMessage) => void;
const incomingListeners = new Set<IncomingListener>();

/** 订阅 mock 引擎推送的"对方新消息"。返回取消订阅函数。 */
export function onMockIncomingMessage(listener: IncomingListener): () => void {
  incomingListeners.add(listener);
  return () => incomingListeners.delete(listener);
}

function emitIncoming(message: MockMessage) {
  incomingListeners.forEach((fn) => {
    try {
      fn(message);
    } catch {
      // ignore listener errors
    }
  });
}

function scheduleReply(conversationId: number) {
  const conv = conversations.find((c) => c.id === conversationId);
  if (!conv) return;

  const members =
    conv.type === "group"
      ? groupMemberOptions(conversationId).filter((m) => m.id !== me.id)
      : [];
  const friendId = conv.friend_user_id;

  let senderId: number;
  let senderName: string;
  let senderAvatar: string;

  if (conv.type === "friend" && friendId) {
    const friend = findUser(friendId);
    senderId = friend?.id ?? friendId;
    senderName = friend?.nickname ?? conv.name;
    senderAvatar = friend?.avatar_url ?? conv.avatar;
  } else if (members.length > 0) {
    const pick = members[Math.floor(Math.random() * members.length)];
    senderId = pick.id;
    senderName = pick.name;
    senderAvatar = pick.avatar_url;
  } else {
    return;
  }

  const wait = 900 + Math.random() * 900;
  setTimeout(() => {
    const text = REPLY_POOL[Math.floor(Math.random() * REPLY_POOL.length)];
    const msg: MockMessage = {
      id: nextMessageId++,
      conversationId,
      type: "text",
      content: text,
      senderId: String(senderId),
      senderName,
      senderAvatar,
      timestamp: new Date().toISOString(),
      isMe: false,
    };
    messages.push(msg);
    touchConversation(conversationId, text, msg.timestamp, senderId, senderName);
    emitIncoming(msg);
  }, wait);
}

/* ============================= 路由 ============================= */

const routes: Route[] = [];

function route(method: string, pattern: RegExp, handler: RouteHandler) {
  routes.push({ method, pattern, handler });
}

/* ---- 认证 ---- */

route("POST", /^\/auth\/register$/, () => loginData());
route("POST", /^\/auth\/login\/email-code$/, () => loginData());
route("POST", /^\/auth\/login\/password$/, () => loginData());
route("POST", /^\/auth\/login\/porten-id$/, () => loginData());
route("POST", /^\/auth\/send-verification-code$/, () => ({ sent: true }));
route("POST", /^\/auth\/logout$/, () => ({ success: true }));
route("GET", /^\/auth\/default-avatar$/, () => ({ avatar_url: DEFAULT_AVATAR }));
route("GET", /^\/auth\/default-nickname$/, () => {
  let id = "";
  while (id.length < 6) {
    const digit = Math.floor(Math.random() * 10);
    if (digit === 4) continue;
    id += String(digit);
  }
  return { nickname: id };
});

/* ---- 用户 ---- */

route("GET", /^\/users\/me$/, () => profileOf(me));
route("GET", /^\/users\/(\d+)\/profile$/, (ctx) => {
  const user = findUser(ctx.params[0]);
  if (!user) throw new Error("user not found");
  return profileOf(user);
});
route("PATCH", /^\/users\/me\/nickname$/, (ctx) => {
  const nickname = String((ctx.body as Record<string, string>)?.nickname ?? me.nickname);
  me.nickname = nickname;
  return profileOf(me);
});
route("PATCH", /^\/users\/me\/avatar$/, (ctx) => {
  const avatarUrl = String((ctx.body as Record<string, string>)?.avatar_url ?? me.avatar_url);
  me.avatar_url = avatarUrl;
  return profileOf(me);
});
route("PATCH", /^\/users\/me\/background$/, (ctx) => {
  const backgroundUrl = String((ctx.body as Record<string, string>)?.background_url ?? me.background_url ?? "");
  me.background_url = backgroundUrl;
  return profileOf(me);
});
route("PATCH", /^\/users\/me$/, (ctx) => {
  const body = ctx.body as Record<string, unknown> | null;
  if (body?.nickname != null) me.nickname = String(body.nickname);
  if (body?.avatar_url != null) me.avatar_url = String(body.avatar_url);
  if (body?.background_url != null) me.background_url = String(body.background_url);
  if (body?.gender != null) me.gender = String(body.gender);
  return profileOf(me);
});
route("POST", /^\/users\/me\/change-email$/, (ctx) => {
  const body = ctx.body as Record<string, string> | null;
  if (body?.new_email) me.email = body.new_email;
  return profileOf(me);
});

/* ---- 联系人 / 营地 ---- */

route("GET", /^\/contacts\/$/, () => ({
  friends: friends.map((f) => ({ ...f })),
  groups: contactGroups.map((g) => ({ ...g })),
}));

route("GET", /^\/contacts\/search\/users$/, (ctx) => {
  const q = (ctx.query.get("porten_id") || ctx.query.get("nickname") || "").toLowerCase().trim();
  if (!q) return null;
  const found = mockUsers.find(
    (u) =>
      u.id !== me.id &&
      (u.nickname.toLowerCase().includes(q) || u.porten_id.includes(q))
  );
  if (!found) return null;
  return { id: found.id, porten_id: found.porten_id, nickname: found.nickname, avatar_url: found.avatar_url };
});

route("GET", /^\/groups\/search$/, (ctx) => {
  const q = (ctx.query.get("keyword") || "").toLowerCase().trim();
  const base = [
    { id: 205, name: "姐妹互助会", avatar_url: groupAvatarOf("sisters"), member_count: 156, tags: ["互助", "陪伴"], group_type: "peer", searchable_by_name: true, camp_id: "C205", description: "姐妹互助，陪伴成长", discoverable_by: "搜索营地名称", max_members: 2000 },
    { id: 206, name: "跨儿读书会", avatar_url: groupAvatarOf("reading"), member_count: 68, tags: ["阅读", "分享"], group_type: "peer", searchable_by_name: true, camp_id: "C206", description: "每月共读一本书", discoverable_by: "搜索营地名称", max_members: 500 },
    { id: 207, name: "编程学习小组", avatar_url: groupAvatarOf("code"), member_count: 132, tags: ["技术", "学习"], group_type: "peer", searchable_by_name: true, camp_id: "C207", description: "一起写代码、互相帮助", discoverable_by: "搜索营地名称", max_members: 1000 },
  ];
  if (!q) return base;
  return base.filter((g) => g.name.toLowerCase().includes(q) || (g.camp_id || "").toLowerCase().includes(q));
});

function groupAvatarOf(seed: string) {
  return `https://api.dicebear.com/7.x/identicon/svg?seed=${encodeURIComponent(seed)}`;
}

/* ---- 好友申请 ---- */

route("POST", /^\/friend-requests\/$/, (ctx) => {
  const body = ctx.body as Record<string, string> | null;
  const portenId = body?.receiver_porten_id || "";
  const target = mockUsers.find((u) => u.porten_id === portenId);
  const item = {
    id: nextId++,
    sender_id: me.id,
    receiver_id: target?.id ?? 0,
    sender_nickname: me.nickname,
    sender_avatar_url: me.avatar_url,
    message: body?.message || "",
    status: "pending",
    source: "搜索添加",
    created_at: new Date().toISOString(),
  };
  return item;
});

route("GET", /^\/friend-requests\/received$/, () => friendRequests.map((r) => ({ ...r })));

route("POST", /^\/friend-requests\/(\d+)\/handle$/, (ctx) => {
  const id = Number(ctx.params[0]);
  const action = (ctx.body as Record<string, string>)?.action;
  const req = friendRequests.find((r) => r.id === id);
  if (req) {
    req.status = action === "accept" ? "accepted" : "rejected";
    if (action === "accept") {
      const user = findUser(req.sender_id);
      if (user && !friends.some((f) => f.user_id === user.id)) {
        friends.push({
          id: nextId++,
          user_id: user.id,
          nickname: user.nickname,
          avatar_url: user.avatar_url,
          created_at: new Date().toISOString(),
        });
        const convId = nextId++;
        conversations.push({
          id: convId,
          type: "friend",
          name: user.nickname,
          avatar: user.avatar_url,
          last_message: "你们已成为同胞，开始聊天吧",
          last_message_time: new Date().toISOString(),
          last_message_sender_id: me.id,
          last_message_sender_name: me.nickname,
          unread_count: 0,
          friend_user_id: user.id,
        });
      }
    }
  }
  return {};
});

/* ---- 营地申请 ---- */

route("POST", /^\/groups\/requests$/, (ctx) => {
  const body = ctx.body as Record<string, unknown> | null;
  const groupId = Number(body?.group_id);
  const contactGroup = contactGroups.find((g) => g.group_id === groupId);
  const convGroup = mockConversations.find(
    (c) => c.type === "group" && c.id === groupId
  );
  const groupName = contactGroup?.name ?? convGroup?.name ?? "营地";
  const groupAvatarUrl = contactGroup
    ? contactGroup.avatar_url
    : convGroup?.avatar ?? groupAvatarOf("unknown");
  return {
    id: nextId++,
    group_id: groupId,
    group_name: groupName,
    group_avatar_url: groupAvatarUrl,
    user_id: me.id,
    user_nickname: me.nickname,
    user_avatar_url: me.avatar_url,
    message: String(body?.message ?? ""),
    status: "pending",
    created_at: new Date().toISOString(),
  };
});

route("GET", /^\/groups\/requests\/received$/, () => groupRequests.map((r) => ({ ...r })));

route("POST", /^\/groups\/requests\/(\d+)\/handle$/, (ctx) => {
  const id = Number(ctx.params[0]);
  const action = (ctx.body as Record<string, string>)?.action;
  const req = groupRequests.find((r) => r.id === id);
  if (req) req.status = action === "accept" ? "accepted" : "rejected";
  return {};
});

/* ---- 通知角标 ---- */

route("GET", /^\/notifications\/badge$/, () => ({
  friend_requests: badgeReadState.friend ? 0 : friendRequests.filter((r) => r.status === "pending").length,
  group_requests: badgeReadState.group ? 0 : groupRequests.filter((r) => r.status === "pending").length,
}));

route("POST", /^\/notifications\/read$/, (ctx) => {
  const type = (ctx.body as Record<string, string>)?.type;
  if (type === "friend") badgeReadState.friend = true;
  if (type === "group") badgeReadState.group = true;
  return {};
});

/* ---- 会话 ---- */

route("GET", /^\/conversations\/$/, () => ({ conversations: sortedConversations().map((c) => ({ ...c })) }));

route("POST", /^\/conversations\/(\d+)\/read$/, (ctx) => {
  const conv = conversations.find((c) => c.id === Number(ctx.params[0]));
  if (conv) conv.unread_count = 0;
  return {};
});

/* ---- 消息 ---- */

route("GET", /^\/messages\/conversation\/(\d+)$/, (ctx) => {
  const conversationId = Number(ctx.params[0]);
  return messages
    .filter((m) => m.conversationId === conversationId)
    .sort((a, b) => new Date(a.timestamp).getTime() - new Date(b.timestamp).getTime())
    .map(messageToApi);
});

route("POST", /^\/messages\/send$/, (ctx) => {
  const body = ctx.body as Record<string, unknown> | null;
  const conversationId = Number(body?.conversation_id);
  const type = String(body?.message_type ?? "text");
  const content = String(body?.content ?? "");
  const extra = (body?.extra as Record<string, unknown>) ?? undefined;

  const msg: MockMessage = {
    id: nextMessageId++,
    conversationId,
    type,
    content,
    extra,
    senderId: String(me.id),
    senderName: me.nickname,
    senderAvatar: me.avatar_url,
    timestamp: new Date().toISOString(),
    isMe: true,
  };
  messages.push(msg);
  touchConversation(conversationId, previewFor(type, content), msg.timestamp, me.id, me.nickname);
  scheduleReply(conversationId);
  return messageToApi(msg);
});

/* ---- 系统消息 ---- */

route("GET", /^\/system-messages$/, () => ({
  messages: systemMessages.map((m) => ({ ...m })),
  unread_count: systemMessages.filter((m) => !m.is_read).length,
}));

route("GET", /^\/system-messages\/unread-count$/, () => ({
  unread_count: systemMessages.filter((m) => !m.is_read).length,
}));

route("PATCH", /^\/system-messages\/(\d+)\/read$/, (ctx) => {
  const item = systemMessages.find((m) => m.id === Number(ctx.params[0]));
  if (item) item.is_read = true;
  return {};
});

route("POST", /^\/system-messages\/read-all$/, () => {
  systemMessages.forEach((m) => (m.is_read = true));
  return {};
});

/* ---- Porten 助手 ---- */

route("GET", /^\/assistants$/, () => ({
  assistants: assistants.map((a) => ({ ...a })),
}));

route("GET", /^\/assistants\/([^/]+)\/articles$/, (ctx) => {
  const assistantId = ctx.params[0];
  const articles = assistantArticles
    .filter((a) => a.assistant_id === assistantId)
    .map((a) => ({
      id: a.id,
      assistant_id: a.assistant_id,
      title: a.title,
      summary: a.summary,
      publish_time: a.publish_time,
      publisher: a.publisher,
      is_read: a.is_read,
    }));
  return {
    assistant_id: assistantId,
    articles,
    unread_count: articles.filter((a) => !a.is_read).length,
  };
});

route("GET", /^\/assistants\/([^/]+)\/articles\/(\d+)$/, (ctx) => {
  const article = assistantArticles.find(
    (a) => a.assistant_id === ctx.params[0] && a.id === Number(ctx.params[1])
  );
  if (!article) throw new Error("article not found");
  return { ...article };
});

route("POST", /^\/assistants\/([^/]+)\/articles\/(\d+)\/read$/, (ctx) => {
  const article = assistantArticles.find(
    (a) => a.assistant_id === ctx.params[0] && a.id === Number(ctx.params[1])
  );
  if (article) article.is_read = true;
  return {};
});

/* ---- 情绪日记 ---- */

function diaryToApi(d: (typeof diaries)[number]) {
  return {
    id: d.id,
    content: d.content,
    mood: d.mood,
    mood_label: d.mood,
    is_public: d.is_public,
    is_current: d.is_current,
    view_count: d.view_count,
    created_at: d.created_at,
    updated_at: d.updated_at,
    author: {
      id: me.id,
      nickname: me.nickname,
      avatar_url: me.avatar_url,
      porten_id: me.porten_id,
    },
    is_mine: true,
  };
}

route("GET", /^\/emotion-diaries\/current$/, () => {
  const current = diaries.find((d) => d.is_current);
  return current ? diaryToApi(current) : null;
});

route("GET", /^\/emotion-diaries\/history$/, () => ({
  items: diaries
    .slice()
    .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())
    .map(diaryToApi),
  total: diaries.length,
}));

route("POST", /^\/emotion-diaries$/, (ctx) => {
  const body = ctx.body as Record<string, unknown> | null;
  diaries.forEach((d) => (d.is_current = false));
  const diary = {
    id: nextId++,
    content: String(body?.content ?? ""),
    mood: String(body?.mood ?? "happy"),
    is_public: Boolean(body?.is_public ?? true),
    is_current: true,
    view_count: 0,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  };
  diaries.unshift(diary);
  me.latest_diary = diary.content;
  me.mood = diary.mood;
  return diaryToApi(diary);
});

route("PATCH", /^\/emotion-diaries\/current$/, (ctx) => {
  const body = ctx.body as Record<string, unknown> | null;
  const current = diaries.find((d) => d.is_current);
  if (!current) throw new Error("no current diary");
  current.content = String(body?.content ?? current.content);
  current.mood = String(body?.mood ?? current.mood);
  current.is_public = Boolean(body?.is_public ?? current.is_public);
  current.updated_at = new Date().toISOString();
  me.latest_diary = current.content;
  me.mood = current.mood;
  return diaryToApi(current);
});

route("DELETE", /^\/emotion-diaries\/(\d+)$/, (ctx) => {
  const id = Number(ctx.params[0]);
  const index = diaries.findIndex((d) => d.id === id);
  if (index >= 0) diaries.splice(index, 1);
  me.latest_diary = null;
  me.mood = null;
  return {};
});

route("GET", /^\/emotion-diaries\/(\d+)\/viewers$/, () => ({
  items: mockDiaryViewers.map((v) => ({ ...v })),
  total: mockDiaryViewers.length,
}));

/* ---- 营地创建 / 更新 ---- */

route("POST", /^\/groups\/create$/, (ctx) => {
  const body = ctx.body as Record<string, unknown> | null;
  const name = String(body?.name ?? "新营地");
  const groupId = nextId++;
  const conversationId = nextId++;
  const nowStr = new Date().toISOString();
  const item: MockConversation = {
    id: conversationId,
    type: "group",
    name,
    avatar: String(body?.avatar_url ?? groupAvatarOf(String(groupId))),
    last_message: `您已成功组建${name}营地`,
    last_message_time: nowStr,
    last_message_sender_id: me.id,
    last_message_sender_name: me.nickname,
    unread_count: 0,
    member_count: 1,
  };
  conversations.unshift(item);
  contactGroups.push({
    id: nextId++,
    group_id: groupId,
    name,
    avatar_url: item.avatar,
    role: "owner",
    created_at: nowStr,
  });
  return {
    id: groupId,
    name,
    avatar_url: item.avatar,
    member_count: 1,
    group_type: String(body?.group_type ?? "peer"),
    conversation_id: conversationId,
  };
});

route("PATCH", /^\/groups\/(\d+)$/, (ctx) => {
  const body = ctx.body as Record<string, unknown> | null;
  return {
    id: Number(ctx.params[0]),
    name: String(body?.name ?? "营地"),
    avatar_url: (body?.avatar_url as string) ?? null,
    member_count: 1,
    group_type: String(body?.group_type ?? "peer"),
    tags: (body?.tags as string[]) ?? [],
  };
});

/* ---- 协议邮件 ---- */

route("POST", /^\/agreements\/send-email$/, () => ({ sent: true }));

/* ---- 全局搜索 ---- */

function searchComrades(q: string, limit: number) {
  return mockUsers
    .filter(
      (u) =>
        u.id !== me.id &&
        (u.nickname.toLowerCase().includes(q) || u.porten_id.includes(q))
    )
    .slice(0, limit)
    .map((u) => ({
      id: u.id,
      porten_id: u.porten_id,
      nickname: u.nickname,
      avatar_url: u.avatar_url,
    }));
}

function searchCamps(q: string, limit: number) {
  const base = [
    { id: 201, name: "产品与设计组", avatar_url: groupAvatarOf("pd"), member_count: 12, tags: ["设计", "产品"], group_type: "peer", camp_id: "C201" },
    { id: 203, name: "前端技术交流", avatar_url: groupAvatarOf("fe"), member_count: 48, tags: ["技术"], group_type: "peer", camp_id: "C203" },
    { id: 205, name: "姐妹互助会", avatar_url: groupAvatarOf("sisters"), member_count: 156, tags: ["互助"], group_type: "peer", camp_id: "C205" },
    { id: 206, name: "跨儿读书会", avatar_url: groupAvatarOf("reading"), member_count: 68, tags: ["阅读"], group_type: "peer", camp_id: "C206" },
    { id: 207, name: "编程学习小组", avatar_url: groupAvatarOf("code"), member_count: 132, tags: ["技术", "学习"], group_type: "peer", camp_id: "C207" },
  ];
  return base
    .filter((g) => !q || g.name.toLowerCase().includes(q) || (g.camp_id || "").toLowerCase().includes(q))
    .slice(0, limit);
}

function searchFiles(q: string, limit: number) {
  return mockSearchFiles
    .filter((f) => !q || f.name.toLowerCase().includes(q))
    .slice(0, limit);
}

function searchImages(q: string, limit: number) {
  return mockSearchImages
    .filter((f) => !q || f.name.toLowerCase().includes(q))
    .slice(0, limit);
}

function searchKnowledge(q: string, limit: number) {
  return sharePosts
    .map((p) => ({
      id: p.id,
      kind: "share",
      title: p.content.slice(0, 18) + (p.content.length > 18 ? "…" : ""),
      summary: p.content.slice(0, 60),
      cover_url: imageUrl(`kp-${p.id}`, 320, 200),
      author_id: p.author.id,
      author_nickname: p.author.nickname,
      author_avatar: p.author.avatar,
    }))
    .filter(
      (k) =>
        !q ||
        k.title.toLowerCase().includes(q) ||
        (k.summary ?? "").toLowerCase().includes(q) ||
        (k.author_nickname ?? "").toLowerCase().includes(q)
    )
    .slice(0, limit);
}

route("GET", /^\/search$/, (ctx) => {
  const q = (ctx.query.get("q") || "").toLowerCase().trim();
  const type = ctx.query.get("type") || "all";
  const limit = Number(ctx.query.get("limit") || "20");

  if (type !== "all") {
    let items: unknown[] = [];
    if (type === "comrade") items = searchComrades(q, limit);
    else if (type === "camp") items = searchCamps(q, limit);
    else if (type === "file") items = searchFiles(q, limit);
    else if (type === "image") items = searchImages(q, limit);
    else if (type === "knowledge") items = searchKnowledge(q, limit);
    return { query: q, items };
  }

  return {
    query: q,
    comrade: searchComrades(q, limit),
    camp: searchCamps(q, limit),
    file: searchFiles(q, limit),
    knowledge: searchKnowledge(q, limit),
    image: searchImages(q, limit),
  };
});

/* ============================= 入口 ============================= */

/**
 * mock 版 API 请求：解析路径并返回业务 data（成功）或抛出带 message 的 Error（失败）。
 */
export async function mockApiRequest(
  path: string,
  options: MockRequestOptions = {}
): Promise<unknown> {
  await delay();

  const method = (options.method || "GET").toUpperCase();
  const [pathname, queryString] = path.split("?");
  const query = parseQuery(queryString ?? "");

  const body: Record<string, unknown> | null = options.body
    ? (JSON.parse(options.body) as Record<string, unknown>)
    : null;

  for (const r of routes) {
    if (r.method !== method) continue;
    const match = r.pattern.exec(pathname ?? "");
    if (!match) continue;
    const params: Record<string, string> = {};
    match.slice(1).forEach((value, index) => {
      params[String(index)] = value ?? "";
    });
    return r.handler({ body, query, params });
  }

  throw new Error(`mock: 未实现接口 ${method} ${path}`);
}

/**
 * mock 版文件上传：模拟进度并返回本地 object URL，供消息内联预览使用。
 */
export function mockUploadFile(
  file: File,
  onProgress?: (percent: number) => void
): Promise<{ media_file_id: number; url: string; thumb_url?: string | null; name?: string; size?: number }> {
  return new Promise((resolve) => {
    const objectUrl = URL.createObjectURL(file);
    let progress = 0;
    const timer = setInterval(() => {
      progress = Math.min(100, progress + 12 + Math.round(Math.random() * 18));
      onProgress?.(progress);
      if (progress >= 100) {
        clearInterval(timer);
        setTimeout(() => {
          resolve({
            media_file_id: nextId++,
            url: objectUrl,
            thumb_url: file.type.startsWith("image/") ? objectUrl : null,
            name: file.name,
            size: file.size,
          });
        }, 60);
      }
    }, 120);
  });
}
