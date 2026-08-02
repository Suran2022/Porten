import { ProfileTopBar } from "./ProfileTopBar";
import { ProfileCard } from "./ProfileCard";
import { MyShareCard } from "./MyShareCard";
import { ProfileFunctionList } from "./ProfileFunctionList";
import { ProfileBottomBar } from "./ProfileBottomBar";
import { ProfileSkeleton } from "./ProfileSkeleton";
import { EditProfilePage, useAvatarInput } from "./EditProfilePage";
import { currentProfile, mySharePost } from "@/data/profileMock";
import { useAuthStore } from "@/store/authStore";
import { UserProfile } from "@/types/profile";
import { useState } from "react";

interface ProfilePageProps {
  visible: boolean;
  onClose: () => void;
  onSettingsClick?: () => void;
}

const defaultBackgroundUrl =
  "https://haowallpaper.com/link/common/file/previewFileImg/18601605145677184";

export function ProfilePage({ visible, onClose, onSettingsClick }: ProfilePageProps) {
  const { user } = useAuthStore();
  const [editVisible, setEditVisible] = useState(false);
  const { inputRef: avatarInputRef, openAvatarPicker, handleChange: handleAvatarChange } = useAvatarInput();

  // user 未加载完成时显示骨架屏，避免弱网下图片错误与空白混合堆叠
  const loading = !user;

  const profile: UserProfile = {
    ...currentProfile,
    nickname: user?.nickname || currentProfile.nickname,
    avatar: user?.avatar || currentProfile.avatar,
    backgroundUrl: user?.backgroundUrl || currentProfile.backgroundUrl || defaultBackgroundUrl,
    portenId: user?.portenId || currentProfile.portenId,
    gender: (user?.gender as (typeof currentProfile.gender)) ?? currentProfile.gender,
    friendCount: user?.friendCount ?? currentProfile.friendCount,
    transDays: user?.transDays ?? currentProfile.transDays,
    // 最新日记 / mood 完全跟随后端数据；如果用户还没写过日记则为 null，
    // 不再用 mock 兜底（避免出现"我没写过却显示一长串"的诡异情况）
    latestDiary: user?.latestDiary ?? null,
    mood: user?.mood ?? null,
  };

  const profileBackgroundUrl = profile.backgroundUrl || defaultBackgroundUrl;

  return (
    <div
      className="fixed inset-0 z-40 bg-white flex flex-col transition-transform duration-300 ease-[cubic-bezier(0.25,0.1,0.25,1)]"
      style={{ transform: visible ? "translateX(0)" : "translateX(-100%)" }}
    >
      <input
        ref={avatarInputRef}
        type="file"
        accept="image/*"
        className="hidden"
        onChange={handleAvatarChange}
      />
      <div className="relative flex-1 overflow-y-auto scrollbar-hide">
        {/* Background image: 仅在 user 加载完成后渲染，避免弱网图片错误 */}
        {!loading && (
          <div className="absolute inset-x-0 top-0 h-[380px] sm:h-[440px] overflow-hidden">
            <img
              src={profileBackgroundUrl}
              alt=""
              className="absolute inset-0 w-full h-full object-cover"
            />
            {/* Blurred layer for natural transition */}
            <div
              className="absolute inset-0 bg-cover bg-center scale-110"
              style={{
                backgroundImage: `url(${profileBackgroundUrl})`,
                WebkitMaskImage:
                  "linear-gradient(to bottom, transparent 0%, transparent 30%, black 100%)",
                maskImage:
                  "linear-gradient(to bottom, transparent 0%, transparent 30%, black 100%)",
                filter: "blur(20px)",
              }}
            />
            {/* Gradient fade to white */}
            <div className="absolute inset-0 bg-gradient-to-b from-white/0 via-white/30 via-[60%] to-white" />
          </div>
        )}

        <ProfileTopBar mood={profile.mood} onClose={onClose} onEditClick={() => setEditVisible(true)} />
        {loading ? (
          <ProfileSkeleton />
        ) : (
          <div className="relative z-10 px-4 pb-6 space-y-4">
            <ProfileCard profile={profile} onAvatarClick={openAvatarPicker} />
            <MyShareCard post={mySharePost} />
            <ProfileFunctionList />
          </div>
        )}
      </div>
      <ProfileBottomBar onSettingsClick={onSettingsClick} />

      <EditProfilePage visible={editVisible} onClose={() => setEditVisible(false)} />
    </div>
  );
}
