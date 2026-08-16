import { useState } from "react";
import { ArrowLeft, ChevronRight, X } from "lucide-react";
import { cn } from "@/lib/utils";
import { useAuthStore } from "@/store/authStore";
import { SystemToast, ToastType } from "@/components/SystemToast";

interface SettingsPageProps {
  visible: boolean;
  onClose: () => void;
  /** PC 弹窗形态：顶部用右对齐关闭图标替代返回图标 */
  closeMode?: boolean;
  onPortenSecurityClick?: () => void;
  onAppBarClick?: () => void;
}

export function SettingsPage({
  visible,
  onClose,
  closeMode = false,
  onPortenSecurityClick,
  onAppBarClick,
}: SettingsPageProps) {
  const { logout } = useAuthStore();
  const [toastVisible, setToastVisible] = useState(false);
  const [toastType, setToastType] = useState<ToastType>("loading");
  const [toastText, setToastText] = useState("");

  const showToast = (type: ToastType, text: string) => {
    setToastType(type);
    setToastText(text);
    setToastVisible(true);
  };

  const hideToast = () => {
    setToastVisible(false);
  };

  const handleLogout = async () => {
    showToast("loading", "正在退出登录");
    try {
      await logout();
      showToast("success", "已退出登录");
      // Give the success toast a moment to be seen before navigating.
      setTimeout(() => {
        hideToast();
        window.location.href = "/login";
      }, 800);
    } catch {
      showToast("error", "登出失败");
      setTimeout(() => {
        hideToast();
      }, 2000);
    }
  };

  return (
    <div
      className={cn(
        "fixed inset-0 z-[55] bg-[#f7f7f7] flex flex-col transition-transform duration-300 ease-[cubic-bezier(0.25,0.1,0.25,1)]",
        visible ? "translate-x-0" : "translate-x-full"
      )}
    >
      {/* Top bar */}
      <div className="flex items-center px-4 pt-[max(0.75rem,env(safe-area-inset-top))] pb-3 bg-white">
        {closeMode ? (
          <>
            <h1 className="flex-1 text-left text-base font-medium text-gray-900">
              设置
            </h1>
            <button
              type="button"
              onClick={onClose}
              className="w-8 h-8 flex items-center justify-center -mr-2"
              aria-label="关闭"
            >
              <X className="w-5 h-5 text-gray-900" strokeWidth={1.8} />
            </button>
          </>
        ) : (
          <>
            <button
              type="button"
              onClick={onClose}
              className="w-8 h-8 flex items-center justify-center -ml-2"
            >
              <ArrowLeft className="w-5 h-5 text-gray-900" strokeWidth={1.5} />
            </button>
            <h1 className="flex-1 text-center text-base font-medium text-gray-900 -ml-8">
              设置
            </h1>
          </>
        )}
      </div>

      {/* Options */}
      <div className="flex-1 overflow-y-auto">
        <button
          type="button"
          onClick={onPortenSecurityClick}
          className="w-full flex items-center justify-between px-4 py-4 bg-white active:bg-gray-50/50 transition-colors"
        >
          <span className="text-base text-gray-900">Porten安全</span>
          <ChevronRight
            className="w-4 h-4 text-gray-400"
            strokeWidth={1.5}
          />
        </button>
        <button
          type="button"
          onClick={onAppBarClick}
          className="w-full flex items-center justify-between px-4 py-4 bg-white active:bg-gray-50/50 transition-colors"
        >
          <span className="text-base text-gray-900">应用栏管理</span>
          <ChevronRight
            className="w-4 h-4 text-gray-400"
            strokeWidth={1.5}
          />
        </button>
      </div>

      {/* Logout button */}
      <div className="flex-shrink-0 px-6 py-6 bg-[#f7f7f7]">
        <button
          type="button"
          onClick={handleLogout}
          className="w-full h-11 rounded-full bg-gray-200/50 text-red-500 text-base font-medium active:bg-gray-300/50 transition-colors"
        >
          退出登录
        </button>
      </div>

      <SystemToast visible={toastVisible} type={toastType} text={toastText} />
    </div>
  );
}
