import { useEffect, useState } from "react";
import { X, SmilePlus, Phone, MessageCircle } from "lucide-react";
import { ProfileCard } from "./ProfileCard";
import { MyShareCard } from "./MyShareCard";
import { ProfileSkeleton } from "./ProfileSkeleton";
import { mySharePost } from "@/data/profileMock";
import { fetchComradeProfile } from "@/lib/api";
import { UserProfile } from "@/types/profile";
import { useToastStore } from "@/store/toastStore";
import { cn } from "@/lib/utils";

interface ComradeProfilePageProps {
  visible: boolean;
  userId: number | string | null;
  onClose: () => void;
  onSendMessage?: () => void;
  onVoiceCall?: () => void;
}

const defaultBackgroundUrl =
  "https://haowallpaper.com/link/common/file/previewFileImg/18601605145677184";

const MOOD_LABELS: Record<string, string> = {
  happy: "开心",
  calm: "平静",
  sad: "难过",
  anxious: "焦虑",
  angry: "愤怒",
  tired: "疲惫",
  grateful: "感恩",
  lonely: "孤独",
  hopeful: "充满希望",
  confused: "迷茫",
};

export function ComradeProfilePage({
  visible,
  userId,
  onClose,
  onSendMessage,
  onVoiceCall,
}: ComradeProfilePageProps) {
  const [shouldRender, setShouldRender] = useState(false);
  const [isEntering, setIsEntering] = useState(false);
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [loading, setLoading] = useState(false);
  const showToast = useToastStore((state) => state.show);

  // 语音通话：暂时无法唤起，弹出通用提示
  const handleVoiceCall = () => {
    showToast("暂时无法唤起哦！", "call");
    onVoiceCall?.();
  };

  // 进出场动画：从右侧滑入，z-[85] 覆盖在聊天页(z-80)之上
  useEffect(() => {
    if (visible) {
      setShouldRender(true);
      requestAnimationFrame(() => {
        requestAnimationFrame(() => setIsEntering(true));
      });
    } else {
      setIsEntering(false);
    }
  }, [visible]);

  const handleTransitionEnd = () => {
    if (!visible) {
      setShouldRender(false);
    }
  };

  // 按 userId 拉取同胞公开资料
  useEffect(() => {
    if (!shouldRender || !userId) return;
    setLoading(true);
    fetchComradeProfile(userId)
      .then((data) => {
        setProfile({
          id: String(data.id),
          nickname: data.nickname,
          avatar: data.avatar_url,
          backgroundUrl: data.background_url || defaultBackgroundUrl,
          portenId: data.porten_id,
          followers: data.friend_count,
          gender: (data.gender as UserProfile["gender"]) ?? null,
          friendCount: data.friend_count,
          transDays: data.trans_days,
          latestDiary: data.latest_diary ?? null,
          mood: data.mood ?? null,
          notificationEnabled: false,
        });
      })
      .catch(() => {
        setProfile(null);
      })
      .finally(() => setLoading(false));
  }, [shouldRender, userId]);

  if (!shouldRender) return null;

  const profileBackgroundUrl = profile?.backgroundUrl || defaultBackgroundUrl;
  const moodLabel = profile?.mood ? MOOD_LABELS[profile.mood as keyof typeof MOOD_LABELS] ?? profile.mood : null;

  return (
    <div
      className={cn(
        "fixed inset-0 z-[85] bg-white flex flex-col transition-transform duration-300 ease-[cubic-bezier(0.25,0.1,0.25,1)]",
        isEntering ? "translate-x-0" : "translate-x-full"
      )}
      onTransitionEnd={handleTransitionEnd}
    >
      <div className="relative flex-1 overflow-y-auto scrollbar-hide">
        {/* 背景图：仅在加载完成且有 profile 时渲染，避免弱网下图片错误与骨架屏混合 */}
        {!loading && profile && (
          <div className="absolute inset-x-0 top-0 h-[380px] sm:h-[440px] overflow-hidden">
            <img
              src={profileBackgroundUrl}
              alt=""
              className="absolute inset-0 w-full h-full object-cover"
            />
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
            <div className="absolute inset-0 bg-gradient-to-b from-white/0 via-white/30 via-[60%] to-white" />
          </div>
        )}

        {/* 顶部栏：仅保留叉叉 + 情绪状态（无编辑资料按钮） */}
        <div className="relative z-10 flex items-center justify-between gap-3 px-4 pt-3 pt-[max(0.75rem,env(safe-area-inset-top))] pb-3">
          <button
            type="button"
            onClick={onClose}
            className="w-8 h-8 rounded-full bg-black/20 flex items-center justify-center backdrop-blur-sm"
          >
            <X className="w-5 h-5 text-white" strokeWidth={1.8} />
          </button>
          {moodLabel ? (
            <div className="flex items-center gap-1.5 h-8 px-3 rounded-full bg-black/10">
              <SmilePlus className="w-4 h-4 text-white" strokeWidth={1.8} />
              <span className="text-sm font-medium text-white">{moodLabel}</span>
            </div>
          ) : null}
        </div>

        {loading ? (
          <ProfileSkeleton />
        ) : profile ? (
          <div className="relative z-10 px-4 pb-6 space-y-4">
            {/* 同胞资料卡：隐藏接收同胞通知按钮，头像不可点击编辑 */}
            <ProfileCard profile={profile} hideNotificationButton />
            {/* ta的分享：去除外层白色背景包裹 */}
            <MyShareCard post={mySharePost} title="ta的分享" flat />
          </div>
        ) : (
          <div className="relative z-10 flex items-center justify-center py-32">
            <span className="text-sm text-gray-400">暂无资料</span>
          </div>
        )}
      </div>

      {/* 底部栏：语音通话 + 传达消息 */}
      <div className="flex-shrink-0 h-[4.6875rem] sm:h-[5.1875rem] w-full bg-white border-t border-gray-100 flex items-center justify-center gap-4 px-4 sm:px-6">
        <button
          type="button"
          onClick={handleVoiceCall}
          className="flex-1 max-w-[10rem] h-11 rounded-full bg-gray-100 text-gray-700 text-sm font-medium flex items-center justify-center gap-2 active:scale-95 transition-transform"
        >
          <Phone className="w-4 h-4" strokeWidth={1.8} />
          语音通话
        </button>
        <button
          type="button"
          onClick={onSendMessage}
          className="flex-1 max-w-[10rem] h-11 rounded-full bg-gray-900 text-white text-sm font-medium flex items-center justify-center gap-2 active:scale-95 transition-transform"
        >
          <MessageCircle className="w-4 h-4" strokeWidth={1.8} />
          传达消息
        </button>
      </div>
    </div>
  );
}
