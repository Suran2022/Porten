import { useEffect, useState } from "react";
import { ArrowLeft } from "lucide-react";
import { cn } from "@/lib/utils";
import { ProfileData, updateNickname } from "@/lib/api";
import { useAuthStore, AuthUser } from "@/store/authStore";

interface EditNicknamePageProps {
  visible: boolean;
  onClose: () => void;
}

function mapProfileDataToAuthUser(data: ProfileData): AuthUser {
  return {
    id: data.id,
    email: data.email,
    portenId: data.porten_id,
    nickname: data.nickname,
    avatar: data.avatar_url,
    backgroundUrl: data.background_url,
    role: data.role,
    gender: data.gender ?? null,
    friendCount: data.friend_count ?? 0,
    transDays: data.trans_days ?? 0,
  };
}

export function EditNicknamePage({ visible, onClose }: EditNicknamePageProps) {
  const { user, updateUser } = useAuthStore();
  const [nickname, setNickname] = useState(user?.nickname || "");
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (visible) {
      setNickname(user?.nickname || "");
    }
  }, [visible, user?.nickname]);

  const handleClose = () => {
    if (saving) return;
    onClose();
  };

  const handleSave = async () => {
    const trimmed = nickname.trim();
    if (!trimmed || !user) return;
    setSaving(true);
    try {
      const profile = await updateNickname(trimmed);
      updateUser(mapProfileDataToAuthUser(profile));
      onClose();
    } catch {
      // ignore
    } finally {
      setSaving(false);
    }
  };

  return (
    <div
      className={cn(
        "fixed inset-0 z-[60] bg-[#f7f7f7] flex flex-col transition-transform duration-300 ease-[cubic-bezier(0.25,0.1,0.25,1)]",
        visible ? "translate-x-0" : "-translate-x-full"
      )}
    >
      {/* Top bar */}
      <div className="flex items-center justify-between px-4 pt-[max(0.75rem,env(safe-area-inset-top))] pb-3 bg-white">
        <button
          type="button"
          onClick={handleClose}
          className="w-8 h-8 flex items-center justify-center -ml-2"
        >
          <ArrowLeft className="w-5 h-5 text-gray-900" strokeWidth={1.5} />
        </button>
        <h1 className="text-base font-medium text-gray-900">修改昵称</h1>
        <button
          type="button"
          onClick={handleSave}
          disabled={saving || !nickname.trim()}
          className="text-sm font-medium text-gray-900 disabled:text-gray-400"
        >
          修改
        </button>
      </div>

      {/* Input card */}
      <div className="flex-1 overflow-y-auto">
        <div className="bg-white px-4 py-4">
          <p className="text-xs text-gray-400 mb-2">新昵称</p>
          <input
            type="text"
            value={nickname}
            onChange={(e) => setNickname(e.target.value)}
            onBlur={(e) => setNickname(e.target.value)}
            placeholder="请输入新昵称"
            maxLength={50}
            className="w-full text-base text-gray-900 placeholder:text-gray-400 bg-transparent outline-none"
            autoFocus={visible}
          />
        </div>
      </div>
    </div>
  );
}
