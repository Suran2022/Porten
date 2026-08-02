import { UserProfile } from "@/types/profile";
import { sharePosts } from "./knowledgeMock";

export const currentProfile: UserProfile = {
  id: "u1",
  nickname: "林夕",
  avatar: "https://i.pravatar.cc/150?u=u1",
  backgroundUrl:
    "https://haowallpaper.com/link/common/file/previewFileImg/18601605145677184",
  portenId: "20240701",
  followers: 128,
  gender: "trans_female",
  friendCount: 128,
  transDays: 386,
  latestDiary:
    "今天和咨询师聊了很多，关于「被看见」这件事。也许真正的勇敢不是不害怕，而是即使害怕也选择站在光里。",
  mood: "开心",
  notificationEnabled: true,
};

export const mySharePost = sharePosts[0];
