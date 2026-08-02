import { useRef, useState } from "react";
import { ArrowLeft, ChevronRight } from "lucide-react";
import { cn } from "@/lib/utils";
import {
  compressImage,
  ProfileData,
  updateAvatar,
  updateBackground,
  updateProfile,
} from "@/lib/api";
import { useAuthStore, AuthUser } from "@/store/authStore";
import { getGenderLabel, GenderValue } from "@/types/profile";
import { EditNicknamePage } from "./EditNicknamePage";
import { GenderPickerSheet } from "./GenderPickerSheet";

interface EditProfilePageProps {
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

export function EditProfilePage({ visible, onClose }: EditProfilePageProps) {
  const { user, updateUser } = useAuthStore();
  const [nicknameVisible, setNicknameVisible] = useState(false);
  const [genderVisible, setGenderVisible] = useState(false);
  const [saving, setSaving] = useState(false);
  const backgroundInputRef = useRef<HTMLInputElement>(null);

  const handleClose = () => {
    if (saving) return;
    onClose();
  };

  const handleSave = () => {
    onClose();
  };

  const handleBackgroundChange = async (
    e: React.ChangeEvent<HTMLInputElement>
  ) => {
    const file = e.target.files?.[0];
    if (!file || !user) return;
    setSaving(true);
    try {
      const dataUrl = await compressImage(file, {
        maxWidth: 800,
        maxHeight: 800,
        quality: 0.7,
      });
      const profile = await updateBackground(dataUrl);
      updateUser(mapProfileDataToAuthUser(profile));
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error("背景图上传失败", err);
    } finally {
      setSaving(false);
      if (backgroundInputRef.current) {
        backgroundInputRef.current.value = "";
      }
    }
  };

  const handleGenderChange = async (value: GenderValue) => {
    if (!user) return;
    setSaving(true);
    try {
      const profile = await updateProfile({ gender: value });
      updateUser(mapProfileDataToAuthUser(profile));
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error("性别设置失败", err);
      alert(err instanceof Error ? err.message : "性别设置失败");
    } finally {
      setSaving(false);
    }
  };

  return (
    <div
      className={cn(
        "fixed inset-0 z-50 bg-[#f7f7f7] flex flex-col transition-transform duration-300 ease-[cubic-bezier(0.25,0.1,0.25,1)]",
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
        <h1 className="text-base font-medium text-gray-900">编辑资料</h1>
        <button
          type="button"
          onClick={handleSave}
          disabled={saving}
          className="text-sm font-medium text-gray-900 disabled:text-gray-400"
        >
          保存
        </button>
      </div>

      {/* Options */}
      <div className="flex-1 overflow-y-auto">
        <div className="space-y-[2px]">
          <button
            type="button"
            onClick={() => setNicknameVisible(true)}
            className="w-full flex items-center justify-between px-4 py-4 bg-white active:bg-gray-50/50 transition-colors"
          >
            <span className="text-base text-gray-900">修改昵称</span>
            <ChevronRight
              className="w-5 h-5 text-gray-400"
              strokeWidth={1.5}
            />
          </button>

          <button
            type="button"
            onClick={() => setGenderVisible(true)}
            className="w-full flex items-center justify-between px-4 py-4 bg-white active:bg-gray-50/50 transition-colors"
          >
            <span className="text-base text-gray-900">设置性别</span>
            <div className="flex items-center gap-1">
              <span className="text-sm text-gray-500">
                {getGenderLabel(user?.gender)}
              </span>
              <ChevronRight
                className="w-5 h-5 text-gray-400"
                strokeWidth={1.5}
              />
            </div>
          </button>

          <label className="w-full flex items-center justify-between px-4 py-4 bg-white active:bg-gray-50/50 transition-colors cursor-pointer">
            <span className="text-base text-gray-900">设置背景图</span>
            <ChevronRight
              className="w-5 h-5 text-gray-400"
              strokeWidth={1.5}
            />
            <input
              ref={backgroundInputRef}
              type="file"
              accept="image/*"
              className="hidden"
              onChange={handleBackgroundChange}
            />
          </label>
        </div>
      </div>

      <EditNicknamePage
        visible={nicknameVisible}
        onClose={() => setNicknameVisible(false)}
      />

      <GenderPickerSheet
        visible={genderVisible}
        selected={user?.gender as GenderValue | null | undefined}
        onSelect={handleGenderChange}
        onClose={() => setGenderVisible(false)}
      />
    </div>
  );
}

export function useAvatarInput() {
  const inputRef = useRef<HTMLInputElement>(null);
  const { user, updateUser } = useAuthStore();

  const openAvatarPicker = () => {
    inputRef.current?.click();
  };

  const handleChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file || !user) return;
    try {
      const dataUrl = await compressImage(file, {
        maxWidth: 300,
        maxHeight: 300,
        quality: 0.8,
      });
      const profile = await updateAvatar(dataUrl);
      updateUser(mapProfileDataToAuthUser(profile));
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error("头像上传失败", err);
    } finally {
      if (inputRef.current) {
        inputRef.current.value = "";
      }
    }
  };

  return { inputRef, openAvatarPicker, handleChange };
}
