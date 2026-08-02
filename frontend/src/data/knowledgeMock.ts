import { LearnCategory, LearnPost, SharePost } from "@/types/knowledge";

const coverUrl = (id: string, w = 720, h = 400) =>
  `https://picsum.photos/seed/${id}/${w}/${h}`;

const avatarUrl = (id: string) => `https://i.pravatar.cc/150?u=${id}`;

const videoSampleUrl =
  "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4";

export const sharePosts: SharePost[] = [
  {
    id: "s1",
    author: { id: "u1", nickname: "小晴的日记", avatar: avatarUrl("u1") },
    content:
      "今天终于鼓起勇气，向最好的几个朋友坦白了自己的身份。没想到她们第一时间抱住了我，说「你就是你，我们爱的就是那个你」。那一刻哭得停不下来，原来被接纳的感觉这么好。希望还在犹豫的姐妹们也能早日遇到愿意理解你们的人。",
    latestComment: {
      author: "阿宁",
      content: "替你开心！有这样的朋友真的太幸运了。",
    },
    views: 1240,
    comments: 38,
    likes: 156,
    publishedAt: "2小时前",
  },
  {
    id: "s2",
    author: { id: "u2", nickname: "山海皆可平", avatar: avatarUrl("u2") },
    content:
      "激素治疗满一年了，翻着相册里从前的自己，像在看一个陌生人。不是否定过去，而是终于觉得身体和灵魂对上了号。医生说得对，这不是终点，是重新认识自己的起点。愿我们都能温柔地成为自己。",
    latestComment: {
      author: "匿名用户",
      content: "一年变化好大，谢谢你愿意分享。",
    },
    views: 892,
    comments: 24,
    likes: 203,
    publishedAt: "5小时前",
  },
  {
    id: "s3",
    author: { id: "u3", nickname: "MidnightBlue", avatar: avatarUrl("u3") },
    content:
      "在公司洗手间门口站了三分钟，最后还是选择了无障碍卫生间。不是我不想，而是那种被注视的目光让我窒息。什么时候「上个厕所」也能变成一件不需要勇气的事？",
    latestComment: {
      author: "考拉",
      content: "很多公司已经开始推行无性别卫生间了，加油。",
    },
    views: 2156,
    comments: 67,
    likes: 412,
    publishedAt: "昨天",
  },
  {
    id: "s4",
    author: { id: "u4", nickname: "风起于青萍", avatar: avatarUrl("u4") },
    content:
      "昨晚梦见妈妈叫我新的名字，醒来枕头是湿的。现实中她还不能接受，但我愿意等。也许她永远不会完全理解，但我相信爱可以慢慢学会尊重。把这个梦记下来，当作给自己的一点甜。",
    latestComment: {
      author: "小雨",
      content: "父母的路往往比我们更长，给彼此时间。",
    },
    views: 1533,
    comments: 45,
    likes: 289,
    publishedAt: "昨天",
  },
  {
    id: "s5",
    author: { id: "u5", nickname: "野火春生", avatar: avatarUrl("u5") },
    content:
      "整理了一份国内可开具诊断证明的医院清单，跑了三个月门诊，问了十几个姐妹，信息尽量核实过。希望对刚入门的朋友有点用。记住，你不需要向任何人证明自己有多「像」。",
    latestComment: {
      author: "Luna",
      content: "辛苦了，这类信息真的太珍贵。",
    },
    views: 3421,
    comments: 89,
    likes: 567,
    publishedAt: "2天前",
  },
  {
    id: "s6",
    author: { id: "u6", nickname: "七分糖", avatar: avatarUrl("u6") },
    content:
      "第一次穿裙子出门，腿在抖，手心全是汗。但地铁上没有人多看一眼，原来世界并没有我想象中那么危险。做自己，先从迈出家门开始。",
    latestComment: {
      author: "Summer",
      content: "太棒了！第一次总是最难的。",
    },
    views: 1780,
    comments: 52,
    likes: 334,
    publishedAt: "2天前",
  },
  {
    id: "s7",
    author: { id: "u7", nickname: "二向箔", avatar: avatarUrl("u7") },
    content:
      "很多人问我，跨性别是不是一种「选择」。我想说，如果这是选择，谁愿意选择一条这么难走的路？我们只是终于停止了自欺欺人，诚实地面对了自己的内心。",
    latestComment: {
      author: "匿名用户",
      content: "说得太好了，每次都要解释真的很累。",
    },
    views: 4102,
    comments: 112,
    likes: 698,
    publishedAt: "3天前",
  },
  {
    id: "u8",
    author: { id: "u8", nickname: "春日迟迟", avatar: avatarUrl("u8") },
    content:
      "和心理咨询师聊了八次，从最初的否认、愤怒，到现在慢慢学会接纳。专业支持真的很重要，如果你也在痛苦里打转，请尝试向靠谱的心理咨询师求助，这不代表你软弱。",
    latestComment: {
      author: "阿禾",
      content: "咨询师 helped me a lot too，抱抱你。",
    },
    views: 960,
    comments: 31,
    likes: 178,
    publishedAt: "3天前",
  },
  {
    id: "s9",
    author: { id: "u9", nickname: "向北", avatar: avatarUrl("u9") },
    content:
      "改完身份证性别那天，在派出所门口站了很久。一张卡片当然不会改变所有偏见，但它让我在法律上成为了真正的自己。把这份勇气和好运传递给还在排队办理的兄弟姐妹。",
    latestComment: {
      author: "辰辰",
      content: "恭喜！这一步真的太不容易了。",
    },
    views: 2678,
    comments: 78,
    likes: 445,
    publishedAt: "4天前",
  },
];

const categoryMeta: Record<
  LearnCategory,
  { label: string; articleTitles: string[]; videoTitles: string[] }
> = {
  community: {
    label: "跨性别群体",
    articleTitles: [
      "跨性别者常见称谓与身份表达指南",
      "如何参与线下跨性别社群活动",
      "跨性别纪念日与历史事件回顾",
    ],
    videoTitles: [
      "五分钟了解跨性别群体多元面貌",
      "跨性别活动家访谈：我们如何被看见",
      "纪录片精选：跨性别者的生活日常",
    ],
  },
  mental: {
    label: "跨儿心理",
    articleTitles: [
      "性别焦虑与自我接纳：一份温和指南",
      "跨性别者常见心理问题及应对方式",
      "如何寻找对跨性别友善的心理咨询师",
    ],
    videoTitles: [
      "心理咨询如何帮助跨性别者",
      "冥想练习：缓解出柜前的焦虑",
      "专家解读：家庭接纳对心理健康的影响",
    ],
  },
  relationship: {
    label: "人际关系",
    articleTitles: [
      "如何向家人和朋友出柜",
      "伴侣是跨性别者，我该如何支持",
      "处理职场与同事关系的小建议",
    ],
    videoTitles: [
      "父母的接纳之路：从困惑到支持",
      "伴侣视角：爱与尊重的平衡",
      "朋友出柜后，你可以这样说",
    ],
  },
  workplace: {
    label: "职场",
    articleTitles: [
      "跨性别者求职与简历使用建议",
      "如何在职场进行社会性别过渡",
      "劳动权益与反歧视法律知识",
    ],
    videoTitles: [
      "跨性别职场人的一天",
      "HR 访谈：打造包容性办公环境",
      "如何应对职场中的偏见言论",
    ],
  },
  campus: {
    label: "校园",
    articleTitles: [
      "跨性别学生的校园权益指南",
      "如何在宿舍与卫生间问题上获得支持",
      "写给跨性别青少年的生存与成长建议",
    ],
    videoTitles: [
      "校园里的跨性别友善小组",
      "老师可以做些什么来支持跨性别学生",
      "青春期阻断剂科普：家长和学生须知",
    ],
  },
  love: {
    label: "恋爱",
    articleTitles: [
      "跨性别者的亲密关系与自我表达",
      "约会软件上的安全与真诚",
      "关于身体、边界与同意的沟通",
    ],
    videoTitles: [
      "跨性别情侣 Q&A：常见困惑解答",
      "亲密关系中的身体焦虑怎么办",
      "如何谈论过去与未来的计划",
    ],
  },
  fashion: {
    label: "穿搭",
    articleTitles: [
      "跨性别女性的日常穿搭入门",
      "跨性别男性的男装搭配技巧",
      "声音、体态与着装的整体协调",
    ],
    videoTitles: [
      "新手妆容教程：打造自然日常妆",
      "如何选择适合自己的发型",
      "穿搭改造：从基础款开始",
    ],
  },
  medical: {
    label: "医疗",
    articleTitles: [
      "激素治疗入门：流程、风险与效果",
      "国内性别肯定手术流程概览",
      "跨性别医疗常见问题与就医建议",
    ],
    videoTitles: [
      "医生讲解：HRT 前需要做哪些检查",
      "手术前后护理与康复经验",
      "跨性别医疗中的知情同意原则",
    ],
  },
};

const categoryOrder: LearnCategory[] = [
  "community",
  "mental",
  "relationship",
  "workplace",
  "campus",
  "love",
  "fashion",
  "medical",
];

const articleSummaries = [
  "本文从基础概念出发，帮助你更全面地理解相关议题，并提供实用的行动建议与资源链接。",
  "通过真实案例与专家解读，梳理常见误区，帮助你在日常生活中做出更适合自己的选择。",
  "这是一份面向新手与亲友的温和指南，希望能在你探索自我或支持他人时提供一点光亮。",
];

const videoSummaries = [
  "通过真实影像与访谈，带你走近这一议题的核心，适合在碎片化时间里观看。",
  "本期视频邀请了几位亲历者分享经验，希望他们的故事能给你带来力量与共鸣。",
  "用通俗易懂的语言拆解关键知识，帮助你快速建立系统认知。",
];

const tagPool = ["科普", "经验", "必读", "新手", "心理健康", "法律", "生活"];

function randomTags(seed: number): string[] {
  const shuffled = [...tagPool].sort(() => Math.sin(seed) * 0.5 - 0.25);
  return shuffled.slice(0, 2 + (seed % 3));
}

export const learnCategories: { key: LearnCategory; label: string }[] =
  categoryOrder.map((key) => ({ key, label: categoryMeta[key].label }));

export const learnPosts: LearnPost[] = categoryOrder.flatMap((category) => {
  const meta = categoryMeta[category];
  const articles: LearnPost[] = meta.articleTitles.map((title, i) => ({
    id: `${category}-a${i + 1}`,
    type: "article",
    category,
    title,
    summary: articleSummaries[i % articleSummaries.length],
    coverUrl: coverUrl(`${category}-a${i + 1}`),
    tags: randomTags(i + 1),
    views: 500 + Math.floor(Math.random() * 2500),
    shares: Math.floor(Math.random() * 150),
    publishedAt: `${1 + (i % 7)}天前`,
  }));

  const videos: LearnPost[] = meta.videoTitles.map((title, i) => ({
    id: `${category}-v${i + 1}`,
    type: "video",
    category,
    title,
    summary: videoSummaries[i % videoSummaries.length],
    coverUrl: coverUrl(`${category}-v${i + 1}`),
    videoUrl: videoSampleUrl,
    duration: `${3 + (i % 8)}:${10 + (i * 7) % 50}`,
    tags: randomTags(i + 10),
    views: 800 + Math.floor(Math.random() * 3200),
    shares: Math.floor(Math.random() * 200),
    publishedAt: `${1 + (i % 5)}天前`,
  }));

  return [...articles, ...videos];
});

export function getLearnPostsByCategory(category: LearnCategory): LearnPost[] {
  return learnPosts.filter((post) => post.category === category);
}
