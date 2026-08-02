import { Bell } from "lucide-react";
import { getGenderLabel, UserProfile } from "@/types/profile";

interface ProfileCardProps {
  profile: UserProfile;
  onAvatarClick?: () => void;
  hideNotificationButton?: boolean;
}

export function ProfileCard({ profile, onAvatarClick, hideNotificationButton = false }: ProfileCardProps) {
  const genderText = getGenderLabel(profile.gender);

  return (
    <div className="p-5">
      <div className="flex items-start gap-4">
        <button
          type="button"
          onClick={onAvatarClick}
          className="w-20 h-20 rounded-full object-cover bg-gray-100 flex-shrink-0 overflow-hidden"
        >
          <img
            src={profile.avatar}
            alt={profile.nickname}
            className="w-full h-full object-cover"
          />
        </button>
        <div className="flex-1 min-w-0 pt-1">
          <h2 className="text-xl font-semibold text-gray-900 truncate">
            {profile.nickname}
          </h2>
          <p className="text-sm text-gray-500 mt-1">
            Porten 账号：{profile.portenId}
          </p>
        </div>
      </div>

      <div className="grid grid-cols-3 gap-3 mt-5">
        <div className="text-center">
          <p className="text-lg font-semibold text-gray-900">{profile.friendCount}</p>
          <p className="text-xs text-gray-500 mt-0.5">同胞数</p>
        </div>
        <div className="text-center">
          <p className="text-lg font-semibold text-gray-900">{genderText}</p>
          <p className="text-xs text-gray-500 mt-0.5">性别</p>
        </div>
        <div className="text-center">
          <p className="text-lg font-semibold text-gray-900">{profile.transDays}天</p>
          <p className="text-xs text-gray-500 mt-0.5">跨儿时常</p>
        </div>
      </div>

      <div className="mt-5">
        <p className="text-xs text-gray-400 mb-1.5">最新日记</p>
        {profile.latestDiary ? (
          <p className="text-sm text-gray-700 leading-relaxed line-clamp-1">
            {profile.latestDiary}
          </p>
        ) : (
          <p className="text-sm text-gray-400 leading-relaxed">
            还没有记录过情绪哦
          </p>
        )}
      </div>

      {/* 接收同胞通知按钮：同胞资料页不显示 */}
      {!hideNotificationButton && (
        <button
          type="button"
          className="mt-5 w-full flex items-center justify-center gap-2 h-10 rounded-full border border-gray-700 bg-white text-gray-700"
        >
          <Bell className="w-4 h-4 rounded-full" strokeWidth={1.8} />
          <span className="text-sm font-medium">接收同胞通知</span>
        </button>
      )}
    </div>
  );
}
