export interface SearchableUser {
  id: string;
  nickname: string;
  avatar: string;
  portenId?: string;
  bio?: string;
  pinyin: string;
}

export interface SearchableGroup {
  id: string;
  name: string;
  avatar: string;
  memberCount: number;
  pinyin: string;
}

export const allUsers: SearchableUser[] = [
  {
    id: "u1",
    nickname: "阿杰",
    avatar: "https://api.dicebear.com/7.x/avataaars/svg?seed=ajie",
    portenId: "385797322957",
    bio: "产品设计师，喜欢爬山",
    pinyin: "ajie",
  },
  {
    id: "u2",
    nickname: "小雨",
    avatar: "https://api.dicebear.com/7.x/avataaars/svg?seed=xiaoyu",
    portenId: "286715433968",
    bio: "前端开发，爱猫",
    pinyin: "xiaoyu",
  },
  {
    id: "u3",
    nickname: "老周",
    avatar: "https://api.dicebear.com/7.x/avataaars/svg?seed=laozhou",
    portenId: "573922846715",
    bio: "后端工程师",
    pinyin: "laozhou",
  },
  {
    id: "u4",
    nickname: "陈默",
    avatar: "https://api.dicebear.com/7.x/avataaars/svg?seed=chenmo",
    portenId: "691284357620",
    bio: "自由职业者",
    pinyin: "chenmo",
  },
  {
    id: "u5",
    nickname: "苏苏",
    avatar: "https://api.dicebear.com/7.x/avataaars/svg?seed=susu",
    portenId: "482603915847",
    bio: "插画师",
    pinyin: "susu",
  },
  {
    id: "u6",
    nickname: "赵明",
    avatar: "https://api.dicebear.com/7.x/avataaars/svg?seed=zhaoming",
    portenId: "739105628493",
    bio: "项目经理",
    pinyin: "zhaoming",
  },
  {
    id: "u7",
    nickname: "李娜",
    avatar: "https://api.dicebear.com/7.x/avataaars/svg?seed=lina",
    portenId: "105739284653",
    bio: "UI 设计师",
    pinyin: "lina",
  },
  {
    id: "u8",
    nickname: "林夕",
    avatar: "https://api.dicebear.com/7.x/avataaars/svg?seed=linxi",
    portenId: "202407013856",
    bio: "这就是我自己",
    pinyin: "linxi",
  },
];

export const allGroups: SearchableGroup[] = [
  {
    id: "g1",
    name: "产品与设计组",
    avatar: "https://api.dicebear.com/7.x/identicon/svg?seed=pd",
    memberCount: 128,
    pinyin: "chanpinyushejizu",
  },
  {
    id: "g2",
    name: "家人群",
    avatar: "https://api.dicebear.com/7.x/identicon/svg?seed=family",
    memberCount: 6,
    pinyin: "jiarenqun",
  },
  {
    id: "g3",
    name: "前端技术交流",
    avatar: "https://api.dicebear.com/7.x/identicon/svg?seed=fe",
    memberCount: 342,
    pinyin: "qianduanjishujiaoliu",
  },
  {
    id: "g4",
    name: "周末徒步小队",
    avatar: "https://api.dicebear.com/7.x/identicon/svg?seed=hiking",
    memberCount: 12,
    pinyin: "zhoumotubuxiaodui",
  },
  {
    id: "g5",
    name: "跨性别互助小组",
    avatar: "https://api.dicebear.com/7.x/identicon/svg?seed=trans",
    memberCount: 86,
    pinyin: "kuaxingbiehuzhuxiaozu",
  },
  {
    id: "g6",
    name: "摄影爱好者",
    avatar: "https://api.dicebear.com/7.x/identicon/svg?seed=photo",
    memberCount: 56,
    pinyin: "sheyingaihaozhe",
  },
];

export interface FriendRequest {
  id: string;
  nickname: string;
  avatar: string;
  message: string;
  source: string;
}

export const friendRequests: FriendRequest[] = [
  {
    id: "r1",
    nickname: "小月",
    avatar: "https://api.dicebear.com/7.x/avataaars/svg?seed=xiaoyue",
    message: "你好，想和你成为同胞，一起交流。",
    source: "通过搜索 Porten 账号添加",
  },
  {
    id: "r2",
    nickname: "阿伟",
    avatar: "https://api.dicebear.com/7.x/avataaars/svg?seed=awei",
    message: "我们在同一个营地，加个同胞吧。",
    source: "来自营地「前端技术交流」",
  },
  {
    id: "r3",
    nickname: "静静",
    avatar: "https://api.dicebear.com/7.x/avataaars/svg?seed=jingjing",
    message: "你好呀，看到你的资料很感兴趣。",
    source: "来自推荐",
  },
  {
    id: "r4",
    nickname: "大伟",
    avatar: "https://api.dicebear.com/7.x/avataaars/svg?seed=dawei",
    message: "朋友推荐我加你的，希望能认识你。",
    source: "来自名片分享",
  },
];

export interface GroupInvitation {
  id: string;
  name: string;
  avatar: string;
  message: string;
  source: string;
  role: "invitee" | "applicant";
}

export const groupInvitations: GroupInvitation[] = [
  {
    id: "gi1",
    name: "跨性别互助小组",
    avatar: "https://api.dicebear.com/7.x/identicon/svg?seed=trans",
    message: "邀请你加入营地，一起互助交流。",
    source: "来自营地管理员",
    role: "invitee",
  },
  {
    id: "gi2",
    name: "摄影爱好者",
    avatar: "https://api.dicebear.com/7.x/identicon/svg?seed=photo",
    message: "等回应",
    source: "你申请的营地",
    role: "applicant",
  },
  {
    id: "gi3",
    name: "周末徒步小队",
    avatar: "https://api.dicebear.com/7.x/identicon/svg?seed=hiking",
    message: "欢迎加入我们的周末活动。",
    source: "来自同胞推荐",
    role: "invitee",
  },
  {
    id: "gi4",
    name: "前端技术交流",
    avatar: "https://api.dicebear.com/7.x/identicon/svg?seed=fe",
    message: "等回应",
    source: "你申请的营地",
    role: "applicant",
  },
];

export const myFriends: SearchableUser[] = allUsers.filter((u) =>
  ["u1", "u2", "u3", "u4", "u5", "u6", "u7"].includes(u.id)
);

export const myGroups: SearchableGroup[] = allGroups.filter((g) =>
  ["g1", "g2", "g3", "g4"].includes(g.id)
);
