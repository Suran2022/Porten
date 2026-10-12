/*
 * 知识页 Mock 数据（对齐 Web 端 data/knowledgeMock.ts）。
 *
 * 差异说明（Mock 离线策略）：Web 端封面图使用 picsum.photos 在线图源、
 * 视频使用公网样例视频；移动端 Mock 模式下封面改用品牌渐变占位（与
 * ArticleCard 的封面加载失败回退同层级的确定性渲染），视频保持海报态
 * （播放按钮 + 时长徽标），不引入网络依赖。
 */

/// 分享帖子作者。
class PortenShareAuthor {
  const PortenShareAuthor({required this.id, required this.nickname, this.avatarAsset});

  final String id;
  final String nickname;

  /// 本地头像资产（r20：Mock 图片资源）。
  final String? avatarAsset;
}

/// 分享帖最新评论。
class PortenShareComment {
  const PortenShareComment({required this.author, required this.content});

  final String author;
  final String content;
}

/// 分享详情页交流条目（对齐 ShareCommentItem）。
class PortenShareDetailComment {
  const PortenShareDetailComment({
    required this.id,
    required this.author,
    required this.avatarAsset,
    required this.content,
    required this.publishedAt,
    this.lit = false,
    this.isOwn = false,
  });

  final String id;
  final String author;
  final String avatarAsset;
  final String content;
  final String publishedAt;
  final bool lit;
  final bool isOwn;
}

/// 分享帖。
class PortenSharePost {
  const PortenSharePost({
    required this.id,
    required this.author,
    required this.content,
    required this.views,
    required this.comments,
    required this.likes,
    required this.publishedAt,
    this.latestComment,
  });

  final String id;
  final PortenShareAuthor author;
  final String content;
  final PortenShareComment? latestComment;
  final int views;
  final int comments;
  final int likes;
  final String publishedAt;
}

/// 学习内容类型。
enum PortenLearnPostType { article, video }

/// 学习帖子。
class PortenLearnPost {
  const PortenLearnPost({
    required this.id,
    required this.type,
    required this.category,
    required this.title,
    required this.summary,
    required this.tags,
    required this.views,
    required this.shares,
    required this.publishedAt,
    this.duration,
  });

  final String id;
  final PortenLearnPostType type;
  final String category;
  final String title;
  final String summary;
  final List<String> tags;
  final int views;
  final int shares;
  final String publishedAt;
  final String? duration;
}

const List<PortenSharePost> kPortenSharePosts = <PortenSharePost>[
  PortenSharePost(
    id: 's1',
    author: PortenShareAuthor(id: 'u1', nickname: '符娟',
        avatarAsset: 'assets/mock_avatars/friend_fu_juan.jpg'),
    content: '今天终于鼓起勇气，向最好的几个朋友坦白了自己的身份。没想到她们第一时间抱住了我，说「你就是你，我们爱的就是那个你」。那一刻哭得停不下来，原来被接纳的感觉这么好。希望还在犹豫的姐妹们也能早日遇到愿意理解你们的人。',
    latestComment: PortenShareComment(author: '阿宁', content: '替你开心！有这样的朋友真的太幸运了。'),
    views: 1240, comments: 38, likes: 156, publishedAt: '2小时前',
  ),
  PortenSharePost(
    id: 's2',
    author: PortenShareAuthor(id: 'u2', nickname: '李月欣',
        avatarAsset: 'assets/mock_avatars/friend_li_yuexin.jpg'),
    content: '激素治疗满一年了，翻着相册里从前的自己，像在看一个陌生人。不是否定过去，而是终于觉得身体和灵魂对上了号。医生说得对，这不是终点，是重新认识自己的起点。愿我们都能温柔地成为自己。',
    latestComment: PortenShareComment(author: '匿名用户', content: '一年变化好大，谢谢你愿意分享。'),
    views: 892, comments: 24, likes: 203, publishedAt: '5小时前',
  ),
  PortenSharePost(
    id: 's3',
    author: PortenShareAuthor(id: 'u3', nickname: '陈雨桐',
        avatarAsset: 'assets/mock_avatars/friend_chen_yutong.jpg'),
    content: '在公司洗手间门口站了三分钟，最后还是选择了无障碍卫生间。不是我不想，而是那种被注视的目光让我窒息。什么时候「上个厕所」也能变成一件不需要勇气的事？',
    latestComment: PortenShareComment(author: '考拉', content: '很多公司已经开始推行无性别卫生间了，加油。'),
    views: 2156, comments: 67, likes: 412, publishedAt: '昨天',
  ),
  PortenSharePost(
    id: 's4',
    author: PortenShareAuthor(id: 'u4', nickname: '林晚晴',
        avatarAsset: 'assets/mock_avatars/friend_lin_wanqing.jpg'),
    content: '昨晚梦见妈妈叫我新的名字，醒来枕头是湿的。现实中她还不能接受，但我愿意等。也许她永远不会完全理解，但我相信爱可以慢慢学会尊重。把这个梦记下来，当作给自己的一点甜。',
    latestComment: PortenShareComment(author: '小雨', content: '父母的路往往比我们更长，给彼此时间。'),
    views: 1533, comments: 45, likes: 289, publishedAt: '昨天',
  ),
  PortenSharePost(
    id: 's5',
    author: PortenShareAuthor(id: 'u5', nickname: '许清欢',
        avatarAsset: 'assets/mock_avatars/friend_xu_qinghuan.jpg'),
    content: '整理了一份国内可开具诊断证明的医院清单，跑了三个月门诊，问了十几个姐妹，信息尽量核实过。希望对刚入门的朋友有点用。记住，你不需要向任何人证明自己有多「像」。',
    latestComment: PortenShareComment(author: 'Luna', content: '辛苦了，这类信息真的太珍贵。'),
    views: 3421, comments: 89, likes: 567, publishedAt: '2天前',
  ),
  PortenSharePost(
    id: 's6',
    author: PortenShareAuthor(id: 'u6', nickname: '周诗涵',
        avatarAsset: 'assets/mock_avatars/friend_zhou_shihan.jpg'),
    content: '第一次穿裙子出门，腿在抖，手心全是汗。但地铁上没有人多看一眼，原来世界并没有我想象中那么危险。做自己，先从迈出家门开始。',
    latestComment: PortenShareComment(author: 'Summer', content: '太棒了！第一次总是最难的。'),
    views: 1780, comments: 52, likes: 334, publishedAt: '2天前',
  ),
  PortenSharePost(
    id: 's7',
    author: PortenShareAuthor(id: 'u7', nickname: '苏念',
        avatarAsset: 'assets/mock_avatars/friend_su_nian.jpg'),
    content: '很多人问我，跨性别是不是一种「选择」。我想说，如果这是选择，谁愿意选择一条这么难走的路？我们只是终于停止了自欺欺人，诚实地面对了自己的内心。',
    latestComment: PortenShareComment(author: '匿名用户', content: '说得太好了，每次都要解释真的很累。'),
    views: 4102, comments: 112, likes: 698, publishedAt: '3天前',
  ),
  PortenSharePost(
    id: 's8',
    author: PortenShareAuthor(id: 'u8', nickname: '夏栀',
        avatarAsset: 'assets/mock_avatars/friend_xia_zhi.jpg'),
    content: '和心理咨询师聊了八次，从最初的否认、愤怒，到现在慢慢学会接纳。专业支持真的很重要，如果你也在痛苦里打转，请尝试向靠谱的心理咨询师求助，这不代表你软弱。',
    latestComment: PortenShareComment(author: '阿禾', content: '咨询师 helped me a lot too，抱抱你。'),
    views: 960, comments: 31, likes: 178, publishedAt: '3天前',
  ),
  PortenSharePost(
    id: 's9',
    author: PortenShareAuthor(id: 'u9', nickname: '顾晓萌',
        avatarAsset: 'assets/mock_avatars/friend_gu_xiaomeng.jpg'),
    content: '改完身份证性别那天，在派出所门口站了很久。一张卡片当然不会改变所有偏见，但它让我在法律上成为了真正的自己。把这份勇气和好运传递给还在排队办理的兄弟姐妹。',
    latestComment: PortenShareComment(author: '辰辰', content: '恭喜！这一步真的太不容易了。'),
    views: 2678, comments: 78, likes: 445, publishedAt: '4天前',
  ),
];

/// 分类元数据（对齐 categoryMeta）。
const Map<String, String> kLearnCategoryLabels = <String, String>{
  'community': '跨性别群体',
  'mental': '跨儿心理',
  'relationship': '人际关系',
  'workplace': '职场',
  'campus': '校园',
  'love': '恋爱',
  'fashion': '穿搭',
  'medical': '医疗',
};

const List<String> kLearnCategoryOrder = <String>[
  'community', 'mental', 'relationship', 'workplace', 'campus', 'love', 'fashion', 'medical',
];

const Map<String, List<String>> _kArticleTitles = <String, List<String>>{
  'community': ['跨性别者常见称谓与身份表达指南', '如何参与线下跨性别社群活动', '跨性别纪念日与历史事件回顾'],
  'mental': ['性别焦虑与自我接纳：一份温和指南', '跨性别者常见心理问题及应对方式', '如何寻找对跨性别友善的心理咨询师'],
  'relationship': ['如何向家人和朋友出柜', '伴侣是跨性别者，我该如何支持', '处理职场与同事关系的小建议'],
  'workplace': ['跨性别者求职与简历使用建议', '如何在职场进行社会性别过渡', '劳动权益与反歧视法律知识'],
  'campus': ['跨性别学生的校园权益指南', '如何在宿舍与卫生间问题上获得支持', '写给跨性别青少年的生存与成长建议'],
  'love': ['跨性别者的亲密关系与自我表达', '约会软件上的安全与真诚', '关于身体、边界与同意的沟通'],
  'fashion': ['跨性别女性的日常穿搭入门', '跨性别男性的男装搭配技巧', '声音、体态与着装的整体协调'],
  'medical': ['激素治疗入门：流程、风险与效果', '国内性别肯定手术流程概览', '跨性别医疗常见问题与就医建议'],
};

const Map<String, List<String>> _kVideoTitles = <String, List<String>>{
  'community': ['五分钟了解跨性别群体多元面貌', '跨性别活动家访谈：我们如何被看见', '纪录片精选：跨性别者的生活日常'],
  'mental': ['心理咨询如何帮助跨性别者', '冥想练习：缓解出柜前的焦虑', '专家解读：家庭接纳对心理健康的影响'],
  'relationship': ['父母的接纳之路：从困惑到支持', '伴侣视角：爱与尊重的平衡', '朋友出柜后，你可以这样说'],
  'workplace': ['跨性别职场人的一天', 'HR 访谈：打造包容性办公环境', '如何应对职场中的偏见言论'],
  'campus': ['校园里的跨性别友善小组', '老师可以做些什么来支持跨性别学生', '青春期阻断剂科普：家长和学生须知'],
  'love': ['跨性别情侣 Q&A：常见困惑解答', '亲密关系中的身体焦虑怎么办', '如何谈论过去与未来的计划'],
  'fashion': ['新手妆容教程：打造自然日常妆', '如何选择适合自己的发型', '穿搭改造：从基础款开始'],
  'medical': ['医生讲解：HRT 前需要做哪些检查', '手术前后护理与康复经验', '跨性别医疗中的知情同意原则'],
};

const List<String> _kArticleSummaries = <String>[
  '本文从基础概念出发，帮助你更全面地理解相关议题，并提供实用的行动建议与资源链接。',
  '通过真实案例与专家解读，梳理常见误区，帮助你在日常生活中做出更适合自己的选择。',
  '这是一份面向新手与亲友的温和指南，希望能在你探索自我或支持他人时提供一点光亮。',
];

const List<String> _kVideoSummaries = <String>[
  '通过真实影像与访谈，带你走近这一议题的核心，适合在碎片化时间里观看。',
  '本期视频邀请了几位亲历者分享经验，希望他们的故事能给你带来力量与共鸣。',
  '用通俗易懂的语言拆解关键知识，帮助你快速建立系统认知。',
];

const List<String> _kTagPool = <String>['科普', '经验', '必读', '新手', '心理健康', '法律', '生活'];

/// 确定性标签（对齐 Web 端 randomTags 的 seed 逻辑）。
List<String> _randomTags(int seed) {
  final List<String> shuffled = List<String>.of(_kTagPool)
    ..sort((String a, String b) => (a.hashCode * 31 + seed) % 3 - 1 >= 0 ? 1 : -1);
  return shuffled.sublist(0, 2 + seed % 3);
}

/// 学习帖子（对齐 Web 端 learnPosts 的生成规则，随机量取确定性值）。
final List<PortenLearnPost> kPortenLearnPosts = <PortenLearnPost>[
  for (final String category in kLearnCategoryOrder) ...<PortenLearnPost>[
    for (int i = 0; i < 3; i++)
      PortenLearnPost(
        id: '$category-a${i + 1}',
        type: PortenLearnPostType.article,
        category: category,
        title: _kArticleTitles[category]![i],
        summary: _kArticleSummaries[i % _kArticleSummaries.length],
        tags: _randomTags(i + 1),
        views: 500 + (i * 811 + category.hashCode.abs() % 97) % 2500,
        shares: (i * 47 + category.hashCode.abs() % 53) % 150,
        publishedAt: '${1 + (i % 7)}天前',
      ),
    for (int i = 0; i < 3; i++)
      PortenLearnPost(
        id: '$category-v${i + 1}',
        type: PortenLearnPostType.video,
        category: category,
        title: _kVideoTitles[category]![i],
        summary: _kVideoSummaries[i % _kVideoSummaries.length],
        tags: _randomTags(i + 10),
        views: 800 + (i * 977 + category.hashCode.abs() % 131) % 3200,
        shares: (i * 71 + category.hashCode.abs() % 89) % 200,
        publishedAt: '${1 + (i % 5)}天前',
        duration: '${3 + (i % 8)}:${(10 + (i * 7) % 50).toString().padLeft(2, '0')}',
      ),
  ],
];

/// 按分类取学习帖子（对齐 getLearnPostsByCategory）。
List<PortenLearnPost> getLearnPostsByCategory(String category) =>
    kPortenLearnPosts.where((PortenLearnPost p) => p.category == category).toList();

/// 计数格式化（对齐 formatCount：万→w、千→k）。
String formatCount(int count) {
  if (count >= 10000) {
    return '${(count / 10000).toStringAsFixed(1)}w';
  }
  if (count >= 1000) {
    return '${(count / 1000).toStringAsFixed(1)}k';
  }
  return count.toString();
}

/// 文本截断（对齐 truncateText）。
String truncateText(String text, int maxLength) =>
    text.length <= maxLength ? text : '${text.substring(0, maxLength)}…';

/// 交流内容池（r20 详情页 Mock：确定性分配）。
const List<String> _kCommentPool = <String>[
  '谢谢你的分享，看完心里暖暖的，抱抱你。',
  '我也在经历类似的阶段，你的文字给了我很多力量。',
  '这一步真的太不容易了，恭喜你走到了这里！',
  '收藏了，等我有勇气的时候一定会用得上。',
  '愿我们都能被世界温柔以待，一起加油。',
  '看到最后一句眼泪掉下来了，说出了我的心声。',
  '很感谢你愿意把这些写出来，真的很有价值。',
  '加油，你比自己想象中更勇敢！',
];

/// 交流作者池（与同胞 Mock 同源，头像复用 mock_avatars 资产）。
const List<(String, String)> _kCommentAuthors = <(String, String)>[
  ('符娟', 'assets/mock_avatars/friend_fu_juan.jpg'),
  ('苏念', 'assets/mock_avatars/friend_su_nian.jpg'),
  ('陈雨桐', 'assets/mock_avatars/friend_chen_yutong.jpg'),
  ('李月欣', 'assets/mock_avatars/friend_li_yuexin.jpg'),
  ('周诗涵', 'assets/mock_avatars/friend_zhou_shihan.jpg'),
  ('林晚晴', 'assets/mock_avatars/friend_lin_wanqing.jpg'),
  ('夏栀', 'assets/mock_avatars/friend_xia_zhi.jpg'),
  ('许清欢', 'assets/mock_avatars/friend_xu_qinghuan.jpg'),
];

const List<String> _kCommentTimes = <String>[
  '2026-10-12T09:20:00', '2026-10-11T21:40:00', '2026-10-11T14:05:00',
  '2026-10-10T19:30:00', '2026-10-09T11:15:00', '2026-10-07T20:50:00',
  '2026-10-04T08:35:00', '2026-09-28T16:00:00', '2026-09-20T10:10:00',
];

/// 按帖子生成详情页交流列表（确定性：以帖子序号为 seed，共 9 条）。
List<PortenShareDetailComment> buildShareDetailComments(PortenSharePost post) {
  final int seed = int.tryParse(post.id.substring(1)) ?? 0;
  return <PortenShareDetailComment>[
    // 第一条：当前账号「抚月」自己的交流（可删除）
    PortenShareDetailComment(
      id: '${post.id}-c0',
      author: '抚月',
      avatarAsset: 'assets/mock_avatars/avatar_fuyue.jpg',
      content: '谢谢你愿意分享，这句话也被我记下来了。',
      publishedAt: '2026-10-12T10:30:00',
      isOwn: true,
    ),
    for (int i = 0; i < 8; i++)
      PortenShareDetailComment(
        id: '${post.id}-c${i + 1}',
        author: _kCommentAuthors[(seed + i) % _kCommentAuthors.length].$1,
        avatarAsset:
            _kCommentAuthors[(seed + i) % _kCommentAuthors.length].$2,
        content: _kCommentPool[(seed * 3 + i) % _kCommentPool.length],
        publishedAt: _kCommentTimes[i % _kCommentTimes.length],
      ),
  ];
}
