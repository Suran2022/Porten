/**
 * Mock 服务端数据：本地演示使用的会话、消息、联系人等种子数据。
 *
 * 时间戳以模块加载时刻为基准向前推算，保证"刚刚 / 10:23 / 昨天"等
 * 相对时间展示始终自然。
 */

export interface MockUser {
  id: number;
  email: string;
  porten_id: string;
  nickname: string;
  avatar_url: string;
  background_url: string | null;
  gender: string | null;
  mood: string | null;
  latest_diary: string | null;
  trans_days: number;
  friend_count: number;
}

export interface MockFriend {
  id: number;
  user_id: number;
  nickname: string;
  avatar_url: string;
  created_at: string;
}

export interface MockGroup {
  id: number;
  group_id: number;
  name: string;
  avatar_url: string;
  role: string;
  created_at: string;
}

export interface MockConversation {
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
  friend_user_id?: number;
}

export interface MockMessage {
  id: number;
  conversationId: number;
  type: string;
  content: string;
  extra?: Record<string, unknown>;
  senderId: string;
  senderName: string;
  senderAvatar: string;
  timestamp: string;
  isMe: boolean;
  duration?: number;
}

const now = Date.now();
const minutesAgo = (mins: number) => new Date(now - mins * 60_000).toISOString();

const avatar = (seed: string) =>
  `https://api.dicebear.com/7.x/avataaars/svg?seed=${encodeURIComponent(seed)}`;
const groupAvatar = (seed: string) =>
  `https://api.dicebear.com/7.x/identicon/svg?seed=${encodeURIComponent(seed)}`;
const imageUrl = (seed: string, w = 480, h = 360) =>
  `https://picsum.photos/seed/${encodeURIComponent(seed)}/${w}/${h}`;

export const DEFAULT_AVATAR =
  "https://haowallpaper.com/link//common/file/previewFileImg/19197325717754752";
export const DEFAULT_BACKGROUND =
  "https://haowallpaper.com/link/common/file/previewFileImg/18601605145677184";

/* ============================= 用户 ============================= */

export const mockUsers: MockUser[] = [
  {
    id: 1001,
    email: "linxi@porten.app",
    porten_id: "100001",
    nickname: "林夕",
    avatar_url: avatar("linxi"),
    background_url: DEFAULT_BACKGROUND,
    gender: "non_binary",
    mood: "happy",
    latest_diary:
      "今天阳光很好，坐在窗边写下这些的时候，突然觉得被世界温柔地接住了。愿我们都能慢慢长成自己喜欢的样子。",
    trans_days: 368,
    friend_count: 12,
  },
  { id: 1002, email: "ajie@porten.app", porten_id: "102305", nickname: "阿杰", avatar_url: avatar("ajie"), background_url: null, gender: "cis_male", mood: "calm", latest_diary: null, trans_days: 0, friend_count: 8 },
  { id: 1003, email: "xiaoyu@porten.app", porten_id: "107892", nickname: "小雨", avatar_url: avatar("xiaoyu"), background_url: null, gender: "trans_female", mood: "hopeful", latest_diary: null, trans_days: 621, friend_count: 15 },
  { id: 1004, email: "susu@porten.app", porten_id: "105671", nickname: "苏苏", avatar_url: avatar("susu"), background_url: null, gender: "trans_female", mood: "happy", latest_diary: null, trans_days: 214, friend_count: 21 },
  { id: 1005, email: "chenmo@porten.app", porten_id: "110352", nickname: "陈默", avatar_url: avatar("chenmo"), background_url: null, gender: "trans_male", mood: "tired", latest_diary: null, trans_days: 458, friend_count: 6 },
  { id: 1006, email: "laozhou@porten.app", porten_id: "113207", nickname: "老周", avatar_url: avatar("laozhou"), background_url: null, gender: "cis_male", mood: "calm", latest_diary: null, trans_days: 0, friend_count: 3 },
  { id: 1007, email: "zhaoming@porten.app", porten_id: "109886", nickname: "赵明", avatar_url: avatar("zhaoming"), background_url: null, gender: "cis_male", mood: "grateful", latest_diary: null, trans_days: 0, friend_count: 9 },
  { id: 1008, email: "lina@porten.app", porten_id: "115530", nickname: "李娜", avatar_url: avatar("lina"), background_url: null, gender: "cis_female", mood: "hopeful", latest_diary: null, trans_days: 0, friend_count: 5 },
  { id: 1012, email: "anran@porten.app", porten_id: "120618", nickname: "安然", avatar_url: avatar("anran"), background_url: null, gender: "trans_female", mood: "confused", latest_diary: null, trans_days: 90, friend_count: 4 },
  { id: 1013, email: "xiaobei@porten.app", porten_id: "122901", nickname: "小北", avatar_url: avatar("xiaobei"), background_url: null, gender: "trans_male", mood: "anxious", latest_diary: null, trans_days: 33, friend_count: 2 },
  { id: 1014, email: "luna@porten.app", porten_id: "126752", nickname: "Luna", avatar_url: avatar("luna"), background_url: null, gender: "genderfluid", mood: "grateful", latest_diary: null, trans_days: 512, friend_count: 18 },
  { id: 1015, email: "aning@porten.app", porten_id: "128930", nickname: "阿宁", avatar_url: avatar("aning"), background_url: null, gender: "questioning", mood: "lonely", latest_diary: null, trans_days: 27, friend_count: 3 },
];

const userById = new Map(mockUsers.map((u) => [u.id, u]));

export function findUser(id: number | string): MockUser | undefined {
  return userById.get(Number(id));
}

export const currentUser: MockUser = mockUsers[0];

/* ============================= 联系人 ============================= */

export const mockFriends: MockFriend[] = [
  { id: 1, user_id: 1002, nickname: "阿杰", avatar_url: avatar("ajie"), created_at: minutesAgo(60 * 24 * 86) },
  { id: 2, user_id: 1003, nickname: "小雨", avatar_url: avatar("xiaoyu"), created_at: minutesAgo(60 * 24 * 64) },
  { id: 3, user_id: 1004, nickname: "苏苏", avatar_url: avatar("susu"), created_at: minutesAgo(60 * 24 * 51) },
  { id: 4, user_id: 1005, nickname: "陈默", avatar_url: avatar("chenmo"), created_at: minutesAgo(60 * 24 * 39) },
  { id: 5, user_id: 1006, nickname: "老周", avatar_url: avatar("laozhou"), created_at: minutesAgo(60 * 24 * 30) },
  { id: 6, user_id: 1007, nickname: "赵明", avatar_url: avatar("zhaoming"), created_at: minutesAgo(60 * 24 * 26) },
  { id: 7, user_id: 1008, nickname: "李娜", avatar_url: avatar("lina"), created_at: minutesAgo(60 * 24 * 17) },
  { id: 8, user_id: 1014, nickname: "Luna", avatar_url: avatar("luna"), created_at: minutesAgo(60 * 24 * 9) },
];

export const mockContactGroups: MockGroup[] = [
  { id: 1, group_id: 201, name: "产品与设计组", avatar_url: groupAvatar("pd"), role: "member", created_at: minutesAgo(60 * 24 * 92) },
  { id: 2, group_id: 202, name: "家人群", avatar_url: groupAvatar("family"), role: "member", created_at: minutesAgo(60 * 24 * 80) },
  { id: 3, group_id: 203, name: "前端技术交流", avatar_url: groupAvatar("fe"), role: "admin", created_at: minutesAgo(60 * 24 * 70) },
  { id: 4, group_id: 204, name: "周末徒步小队", avatar_url: groupAvatar("hiking"), role: "member", created_at: minutesAgo(60 * 24 * 44) },
  { id: 5, group_id: 205, name: "姐妹互助会", avatar_url: groupAvatar("sisters"), role: "member", created_at: minutesAgo(60 * 24 * 12) },
];

/* ============================= 会话 ============================= */

export const mockConversations: MockConversation[] = [
  {
    id: 301,
    type: "friend",
    name: "阿杰",
    avatar: avatar("ajie"),
    last_message: "晚上一起吃饭吗？",
    last_message_time: minutesAgo(18),
    last_message_sender_id: 1002,
    last_message_sender_name: "阿杰",
    unread_count: 2,
    friend_user_id: 1002,
  },
  {
    id: 302,
    type: "group",
    name: "产品与设计组",
    avatar: groupAvatar("pd"),
    last_message: "新版本的原型图已经上传了，大家看看",
    last_message_time: minutesAgo(42),
    last_message_sender_id: 1002,
    last_message_sender_name: "阿杰",
    unread_count: 12,
    member_count: 12,
  },
  {
    id: 303,
    type: "friend",
    name: "小雨",
    avatar: avatar("xiaoyu"),
    last_message: "我到了，你在哪？",
    last_message_time: minutesAgo(60 * 3),
    last_message_sender_id: 1003,
    last_message_sender_name: "小雨",
    unread_count: 0,
    friend_user_id: 1003,
  },
  {
    id: 304,
    type: "friend",
    name: "苏苏",
    avatar: avatar("susu"),
    last_message: "哈哈哈这个太好笑了",
    last_message_time: minutesAgo(60 * 6),
    last_message_sender_id: 1004,
    last_message_sender_name: "苏苏",
    unread_count: 0,
    friend_user_id: 1004,
  },
  {
    id: 305,
    type: "group",
    name: "家人群",
    avatar: groupAvatar("family"),
    last_message: "周末回家吃饭吗？",
    last_message_time: minutesAgo(60 * 26),
    last_message_sender_id: 1009,
    last_message_sender_name: "妈妈",
    unread_count: 0,
    member_count: 5,
  },
  {
    id: 306,
    type: "group",
    name: "前端技术交流",
    avatar: groupAvatar("fe"),
    last_message: "React 19 发布了",
    last_message_time: minutesAgo(60 * 30),
    last_message_sender_id: 1010,
    last_message_sender_name: "前端小王",
    unread_count: 36,
    member_count: 48,
  },
  {
    id: 307,
    type: "friend",
    name: "陈默",
    avatar: avatar("chenmo"),
    last_message: "文件发你了",
    last_message_time: minutesAgo(60 * 24 * 1),
    last_message_sender_id: 1001,
    last_message_sender_name: "林夕",
    unread_count: 0,
    friend_user_id: 1005,
  },
  {
    id: 308,
    type: "friend",
    name: "老周",
    avatar: avatar("laozhou"),
    last_message: "收到了，谢谢",
    last_message_time: minutesAgo(60 * 24 * 2),
    last_message_sender_id: 1006,
    last_message_sender_name: "老周",
    unread_count: 0,
    friend_user_id: 1006,
  },
  {
    id: 309,
    type: "group",
    name: "周末徒步小队",
    avatar: groupAvatar("hiking"),
    last_message: "明天早上八点集合",
    last_message_time: minutesAgo(60 * 24 * 3),
    last_message_sender_id: 1011,
    last_message_sender_name: "领队",
    unread_count: 5,
    member_count: 23,
  },
  {
    id: 310,
    type: "group",
    name: "姐妹互助会",
    avatar: groupAvatar("sisters"),
    last_message: "欢迎新加入的姐妹，先做个自我介绍吧～",
    last_message_time: minutesAgo(60 * 24 * 4),
    last_message_sender_id: 1014,
    last_message_sender_name: "Luna",
    unread_count: 0,
    member_count: 156,
  },
];

/* ============================= 消息 ============================= */

let nextMessageId = 9000;

function mk(
  conversationId: number,
  senderId: number,
  senderName: string,
  senderAvatarUrl: string,
  type: string,
  content: string,
  minsAgo: number,
  extra?: Record<string, unknown>,
  duration?: number
): MockMessage {
  return {
    id: nextMessageId++,
    conversationId,
    type,
    content,
    extra,
    senderId: String(senderId),
    senderName,
    senderAvatar: senderAvatarUrl,
    timestamp: minutesAgo(minsAgo),
    isMe: senderId === currentUser.id,
    duration,
  };
}

function msgFor(
  conversationId: number,
  peer: MockUser,
  type: string,
  content: string,
  minsAgo: number,
  extra?: Record<string, unknown>,
  duration?: number
): MockMessage {
  return mk(
    conversationId,
    peer.id,
    peer.nickname,
    peer.avatar_url,
    type,
    content,
    minsAgo,
    extra,
    duration
  );
}

const ajie = userById.get(1002)!;
const xiaoyu = userById.get(1003)!;
const susu = userById.get(1004)!;
const chenmo = userById.get(1005)!;
const laozhou = userById.get(1006)!;

const GROUP_MEMBER_NAMES: Record<number, { id: number; name: string; avatar_url: string }[]> = {
  302: [
    { id: 1002, name: "阿杰", avatar_url: avatar("ajie") },
    { id: 1003, name: "小雨", avatar_url: avatar("xiaoyu") },
    { id: 1014, name: "Luna", avatar_url: avatar("luna") },
    { id: 1016, name: "Summer", avatar_url: avatar("summer") },
    { id: 1017, name: "考拉", avatar_url: avatar("kaola") },
  ],
  305: [
    { id: 1009, name: "妈妈", avatar_url: avatar("mama") },
    { id: 1001, name: "林夕", avatar_url: avatar("linxi") },
  ],
  306: [
    { id: 1010, name: "前端小王", avatar_url: avatar("fe-wang") },
    { id: 1001, name: "林夕", avatar_url: avatar("linxi") },
  ],
  309: [
    { id: 1011, name: "领队", avatar_url: avatar("lingdui") },
    { id: 1004, name: "苏苏", avatar_url: avatar("susu") },
  ],
  310: [
    { id: 1014, name: "Luna", avatar_url: avatar("luna") },
    { id: 1012, name: "安然", avatar_url: avatar("anran") },
    { id: 1004, name: "苏苏", avatar_url: avatar("susu") },
  ],
};

const c1 = 301; // 阿杰（好友）
const c2 = 302; // 产品与设计组
const c3 = 303; // 小雨
const c4 = 304; // 苏苏
const c5 = 305; // 家人群
const c6 = 306; // 前端技术交流
const c7 = 307; // 陈默
const c8 = 308; // 老周
const c9 = 309; // 周末徒步小队
const c10 = 310; // 姐妹互助会

export const mockMessages: MockMessage[] = [
  // ---- 阿杰 ----
  mk(c1, 1001, "林夕", avatar("linxi"), "text", "昨天说的那家餐厅，我看了下评价还不错", 420),
  msgFor(c1, ajie, "text", "可以呀，我正好也想去试试", 400),
  mk(c1, 1001, "林夕", avatar("linxi"), "image", "", 395, { url: imageUrl("dinner-1", 640, 480), thumb_url: imageUrl("dinner-1", 320, 240), name: "餐厅环境.jpg", size: 186_000 }),
  msgFor(c1, ajie, "text", "环境看起来可以，周末去吗？", 380),
  mk(c1, 1001, "林夕", avatar("linxi"), "voice", "", 350, { name: "voice.m4a", size: 96_000 }, 8),
  msgFor(c1, ajie, "text", "收到，那我周六订位", 330),
  mk(c1, 1001, "林夕", avatar("linxi"), "text", "好呀，晚上六点半见", 300),
  msgFor(c1, ajie, "text", "晚上一起吃饭吗？", 18),

  // ---- 产品与设计组 ----
  mk(c2, 1002, "阿杰", avatar("ajie"), "text", "早呀，昨天的方案评审结论出来了", 60 * 8),
  mk(c2, 1003, "小雨", avatar("xiaoyu"), "text", "整体方向没问题，细节再打磨一下", 60 * 8 - 6),
  mk(c2, 1014, "Luna", avatar("luna"), "image", "", 60 * 8 - 12, { url: imageUrl("proto-1", 640, 400), thumb_url: imageUrl("proto-1", 320, 200), name: "原型图.png", size: 420_000 }),
  mk(c2, 1014, "Luna", avatar("luna"), "text", "首页和消息流的两版对比，大家投个票", 60 * 8 - 13),
  mk(c2, 1001, "林夕", avatar("linxi"), "text", "我倾向第二版，视觉更清爽", 60 * 5),
  mk(c2, 1002, "阿杰", avatar("ajie"), "share", "", 42, undefined, undefined),
  mk(c2, 1002, "阿杰", avatar("ajie"), "text", "新版本的原型图已经上传了，大家看看", 42),

  // ---- 小雨 ----
  mk(c3, 1001, "林夕", avatar("linxi"), "text", "出发了吗？", 60 * 4),
  msgFor(c3, xiaoyu, "text", "刚上地铁，大概二十分钟到", 60 * 3.8),
  msgFor(c3, xiaoyu, "text", "我到了，你在哪？", 60 * 3),

  // ---- 苏苏 ----
  mk(c4, 1001, "林夕", avatar("linxi"), "text", "给你看个好玩的", 60 * 7),
  mk(c4, 1001, "林夕", avatar("linxi"), "image", "", 60 * 6.9, { url: imageUrl("funny-cat", 500, 500), thumb_url: imageUrl("funny-cat", 250, 250), name: "猫咪.jpg", size: 210_000 }),
  msgFor(c4, susu, "text", "哈哈哈这个太好笑了", 60 * 6),

  // ---- 家人群 ----
  mk(c5, 1009, "妈妈", avatar("mama"), "text", "这周降温，记得多穿点", 60 * 30),
  mk(c5, 1001, "林夕", avatar("linxi"), "text", "知道啦，你们也多注意身体", 60 * 28),
  mk(c5, 1009, "妈妈", avatar("mama"), "text", "周末回家吃饭吗？", 60 * 26),

  // ---- 前端技术交流 ----
  mk(c6, 1010, "前端小王", avatar("fe-wang"), "share", "", 60 * 31),
  mk(c6, 1010, "前端小王", avatar("fe-wang"), "text", "React 19 发布了", 60 * 30),

  // ---- 陈默 ----
  mk(c7, 1005, "陈默", avatar("chenmo"), "file", "项目排期表.xlsx", 60 * 24 * 1.1, { url: "", name: "项目排期表.xlsx", size: 82_400 }),
  msgFor(c7, chenmo, "text", "文件发你了", 60 * 24),

  // ---- 老周 ----
  msgFor(c8, laozhou, "text", "好的，那就这么定了", 60 * 24 * 2.2),
  msgFor(c8, laozhou, "text", "收到了，谢谢", 60 * 24 * 2),

  // ---- 周末徒步小队 ----
  mk(c9, 1011, "领队", avatar("lingdui"), "image", "", 60 * 24 * 3.2, { url: imageUrl("hiking-route", 640, 400), thumb_url: imageUrl("hiking-route", 320, 200), name: "路线图.png", size: 520_000 }),
  mk(c9, 1011, "领队", avatar("lingdui"), "text", "明天早上八点集合", 60 * 24 * 3),

  // ---- 姐妹互助会 ----
  mk(c10, 1001, "林夕", avatar("linxi"), "system", "您已加入姐妹互助会营地，快来和大家分享您的故事趴！", 60 * 24 * 4.5, { join_user_id: 1001, group_name: "姐妹互助会" }),
  mk(c10, 1014, "Luna", avatar("luna"), "nameCard", "", 60 * 24 * 4.2, {
    userId: "1014",
    nickname: "Luna",
    avatar: avatar("luna"),
  }),
  mk(c10, 1014, "Luna", avatar("luna"), "text", "欢迎新加入的姐妹，先做个自我介绍吧～", 60 * 24 * 4),
];

/** 为 share 类消息补充展示元数据（mock 中统一渲染为知识分享卡片）。 */
export function decorateMockMessages(): void {
  for (const m of mockMessages) {
    if (m.type === "share") {
      m.extra = {
        share_type: "knowledge",
        title: "激素治疗常见问题与解答",
        desc: "整理了姐妹们最常问的十个问题，附门诊准备清单。",
        cover: imageUrl("share-cover", 640, 360),
        tags: ["健康", "科普"],
      };
    }
    if (m.type === "nameCard") {
      m.extra = {
        user_id: "1014",
        nickname: "Luna",
        avatar: avatar("luna"),
      };
    }
  }
}
decorateMockMessages();

export function messagesOf(conversationId: number): MockMessage[] {
  return mockMessages
    .filter((m) => m.conversationId === conversationId)
    .sort((a, b) => new Date(a.timestamp).getTime() - new Date(b.timestamp).getTime());
}

export function groupMemberOptions(conversationId: number) {
  return GROUP_MEMBER_NAMES[conversationId] ?? [];
}

/* ============================= 好友 / 营地申请 ============================= */

export interface MockFriendRequest {
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

export interface MockGroupRequest {
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

export const mockFriendRequests: MockFriendRequest[] = [
  {
    id: 1,
    sender_id: 1012,
    receiver_id: 1001,
    sender_nickname: "安然",
    sender_avatar_url: avatar("anran"),
    message: "在知识广场看到你的分享，可以认识一下吗？",
    status: "pending",
    source: "搜索添加",
    created_at: minutesAgo(60 * 5),
  },
  {
    id: 2,
    sender_id: 1013,
    receiver_id: 1001,
    sender_nickname: "小北",
    sender_avatar_url: avatar("xiaobei"),
    message: "你好呀，我是小北～",
    status: "pending",
    source: "营地成员",
    created_at: minutesAgo(60 * 26),
  },
];

export const mockGroupRequests: MockGroupRequest[] = [
  {
    id: 1,
    group_id: 205,
    group_name: "姐妹互助会",
    group_avatar_url: groupAvatar("sisters"),
    user_id: 1001,
    user_nickname: "林夕",
    user_avatar_url: avatar("linxi"),
    message: "想加入营地认识更多朋友",
    status: "pending",
    created_at: minutesAgo(60 * 9),
  },
];

/* ============================= 系统消息 ============================= */

export interface MockSystemMessage {
  id: number;
  version: string;
  title: string;
  content: string;
  message_type: string;
  is_custom_title: boolean;
  is_read: boolean;
  created_at: string;
}

export const mockSystemMessages: MockSystemMessage[] = [
  {
    id: 1,
    version: "1.6.0",
    title: "新版本发布",
    content:
      "Porten 1.6.0 已上线：新增情绪日记历史回顾、营地资料页优化，以及若干体验细节修复。感谢每一位同胞的反馈与陪伴。",
    message_type: "update",
    is_custom_title: false,
    is_read: false,
    created_at: minutesAgo(60 * 3),
  },
  {
    id: 2,
    version: "1.5.2",
    title: "安全提醒",
    content:
      "请勿将验证码、登录链接分享给他人。Porten 官方不会以任何理由索要您的账号密码。",
    message_type: "security",
    is_custom_title: false,
    is_read: false,
    created_at: minutesAgo(60 * 24 * 2),
  },
  {
    id: 3,
    version: "1.5.0",
    title: "社区公约更新",
    content:
      "我们更新了社区公约，新增了关于内容分享边界的说明，让这个家更安全、更温暖。",
    message_type: "update",
    is_custom_title: false,
    is_read: true,
    created_at: minutesAgo(60 * 24 * 8),
  },
];

/* ============================= Porten 助手 ============================= */

export interface MockAssistant {
  id: string;
  name: string;
  avatar: string | null;
  bio: string | null;
  article_count: number;
  unread_count: number;
}

export interface MockAssistantArticle {
  id: number;
  assistant_id: string;
  title: string;
  summary: string;
  publish_time: string;
  publisher: string;
  is_read: boolean;
  content: string;
}

export const mockAssistants: MockAssistant[] = [
  {
    id: "a1",
    name: "Porten 小助手",
    avatar: null,
    bio: "官方资讯、版本更新与活动通知",
    article_count: 3,
    unread_count: 2,
  },
  {
    id: "a2",
    name: "身心关怀",
    avatar: null,
    bio: "情绪照顾与自我关怀的小贴士",
    article_count: 2,
    unread_count: 0,
  },
];

export const mockAssistantArticles: MockAssistantArticle[] = [
  {
    id: 11,
    assistant_id: "a1",
    title: "Porten 1.6.0 更新说明",
    summary: "情绪日记历史回顾、营地资料页优化等新特性一览。",
    publish_time: minutesAgo(60 * 3),
    publisher: "Porten 团队",
    is_read: false,
    content:
      "## 新特性\n\n- **情绪日记历史回顾**：翻阅过往日记，见证自己的成长轨迹。\n- **营地资料页优化**：营地信息展示更清晰。\n\n## 体验修复\n\n- 修复了部分机型上语音消息偶发无法播放的问题。\n- 优化了图片缩略图的加载速度。\n\n感谢每一位同胞的反馈与陪伴。🌈",
  },
  {
    id: 12,
    assistant_id: "a1",
    title: "账号安全小贴士",
    summary: "保护好自己的验证码与登录信息。",
    publish_time: minutesAgo(60 * 24 * 2),
    publisher: "Porten 团队",
    is_read: false,
    content:
      "## 请牢记\n\n1. 验证码、登录链接请勿分享给他人。\n2. Porten 官方不会索要您的账号密码。\n\n如遇可疑情况，请通过「设置 → Porten安全」联系我们。",
  },
  {
    id: 13,
    assistant_id: "a1",
    title: "社区公约更新说明",
    summary: "关于内容分享边界的新说明。",
    publish_time: minutesAgo(60 * 24 * 8),
    publisher: "Porten 团队",
    is_read: true,
    content: "## 社区公约更新\n\n我们新增了关于内容分享边界的说明，让这个家更安全、更温暖。",
  },
  {
    id: 21,
    assistant_id: "a2",
    title: "睡前放松呼吸练习",
    summary: "5 分钟，帮你在睡前放松下来。",
    publish_time: minutesAgo(60 * 24 * 3),
    publisher: "身心关怀",
    is_read: true,
    content:
      "## 睡前放松呼吸\n\n1. 找一个舒服的姿势躺下。\n2. 吸气 4 秒，屏住 2 秒，呼气 6 秒。\n3. 重复 8 轮，把注意力放在呼吸上。\n\n愿你能有一个安稳的夜晚。",
  },
  {
    id: 22,
    assistant_id: "a2",
    title: "写给偶尔疲惫的你",
    summary: "你不必时刻坚强。",
    publish_time: minutesAgo(60 * 24 * 6),
    publisher: "身心关怀",
    is_read: true,
    content:
      "## 写给偶尔疲惫的你\n\n允许自己休息，允许自己难过，允许自己慢慢来。\n\n你走过的每一步都算数。",
  },
];

/* ============================= 情绪日记 ============================= */

export interface MockDiary {
  id: number;
  content: string;
  mood: string;
  is_public: boolean;
  is_current: boolean;
  view_count: number;
  created_at: string;
  updated_at: string;
}

export const mockDiaries: MockDiary[] = [
  {
    id: 2,
    content:
      "今天和咨询师聊了最近的状态，突然意识到自己已经很久没有好好照顾情绪了。晚上给自己煮了热汤，看了半部电影。慢慢来，都会好的。",
    mood: "calm",
    is_public: true,
    is_current: false,
    view_count: 6,
    created_at: minutesAgo(60 * 24 * 3),
    updated_at: minutesAgo(60 * 24 * 3),
  },
  {
    id: 1,
    content:
      "今天阳光很好，坐在窗边写下这些的时候，突然觉得被世界温柔地接住了。愿我们都能慢慢长成自己喜欢的样子。",
    mood: "happy",
    is_public: true,
    is_current: true,
    view_count: 12,
    created_at: minutesAgo(60 * 20),
    updated_at: minutesAgo(60 * 20),
  },
];

export const mockDiaryViewers = [
  {
    id: 1,
    user_id: 1003,
    nickname: "小雨",
    avatar_url: avatar("xiaoyu"),
    porten_id: "107892",
    viewed_at: minutesAgo(60 * 6),
  },
  {
    id: 2,
    user_id: 1014,
    nickname: "Luna",
    avatar_url: avatar("luna"),
    porten_id: "126752",
    viewed_at: minutesAgo(60 * 9),
  },
  {
    id: 3,
    user_id: 1004,
    nickname: "苏苏",
    avatar_url: avatar("susu"),
    porten_id: "105671",
    viewed_at: minutesAgo(60 * 15),
  },
];

/* ============================= 搜索语料 ============================= */

export interface MockSearchFile {
  id: number;
  name: string;
  url: string;
  size: number | null;
  uploader_id: number | null;
  uploader_nickname: string | null;
  created_at: string | null;
}

export const mockSearchFiles: MockSearchFile[] = [
  { id: 1, name: "项目排期表.xlsx", url: "#", size: 82_400, uploader_id: 1005, uploader_nickname: "陈默", created_at: minutesAgo(60 * 24) },
  { id: 2, name: "跨性别就医指南.pdf", url: "#", size: 1_240_000, uploader_id: 1014, uploader_nickname: "Luna", created_at: minutesAgo(60 * 24 * 4) },
  { id: 3, name: "激素治疗常见问题.md", url: "#", size: 18_600, uploader_id: 1001, uploader_nickname: "林夕", created_at: minutesAgo(60 * 24 * 7) },
  { id: 4, name: "社群活动照片.zip", url: "#", size: 8_640_000, uploader_id: 1003, uploader_nickname: "小雨", created_at: minutesAgo(60 * 24 * 12) },
];

export const mockSearchImages: MockSearchFile[] = [
  { id: 1, name: "餐厅环境.jpg", url: imageUrl("dinner-1", 320, 240), size: 186_000, uploader_id: 1001, uploader_nickname: "林夕", created_at: minutesAgo(60 * 6) },
  { id: 2, name: "原型图.png", url: imageUrl("proto-1", 320, 200), size: 420_000, uploader_id: 1014, uploader_nickname: "Luna", created_at: minutesAgo(60 * 8) },
  { id: 3, name: "猫咪.jpg", url: imageUrl("funny-cat", 250, 250), size: 210_000, uploader_id: 1001, uploader_nickname: "林夕", created_at: minutesAgo(60 * 7) },
  { id: 4, name: "路线图.png", url: imageUrl("hiking-route", 320, 200), size: 520_000, uploader_id: 1011, uploader_nickname: "领队", created_at: minutesAgo(60 * 24 * 3) },
];

export { minutesAgo, avatar, groupAvatar, imageUrl };
