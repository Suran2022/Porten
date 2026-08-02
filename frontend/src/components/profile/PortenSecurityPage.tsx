import { useEffect, useState } from "react";
import { ArrowLeft, ChevronRight, ShieldCheck } from "lucide-react";
import { cn } from "@/lib/utils";
import { useAuthStore } from "@/store/authStore";
import { BoundEmailDialog } from "./BoundEmailDialog";
import { ChangeEmailCooldownDialog } from "./ChangeEmailCooldownDialog";
import { ChangeEmailPage } from "./ChangeEmailPage";

interface PortenSecurityPageProps {
  visible: boolean;
  onClose: () => void;
}

const securityOptions = [
  { id: "bound_email", label: "绑定的邮箱" },
  { id: "change_password", label: "修改登录密码" },
  { id: "device_management", label: "设备管理" },
  { id: "violation", label: "违规相关" },
  { id: "history_query", label: "历史查询" },
  { id: "emergency_freeze", label: "安全紧急冻结" },
  { id: "security_settings", label: "账号安全设置" },
] as const;

export function PortenSecurityPage({
  visible,
  onClose,
}: PortenSecurityPageProps) {
  const [shouldRender, setShouldRender] = useState(false);
  const [isEntering, setIsEntering] = useState(false);

  // 绑定的邮箱相关
  const [boundEmailDialog, setBoundEmailDialog] = useState(false);
  const [cooldownDialog, setCooldownDialog] = useState(false);
  const [changeEmailVisible, setChangeEmailVisible] = useState(false);
  // 用本地状态模拟当前绑定邮箱，方便测试时改动可见
  const [currentEmail, setCurrentEmail] = useState<string>("");

  const user = useAuthStore((state) => state.user);

  useEffect(() => {
    if (user?.email) {
      setCurrentEmail(user.email);
    }
  }, [user?.email]);

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

  if (!shouldRender) return null;

  // 点击"绑定的邮箱"卡片：直接弹出脱敏邮箱弹窗
  const handleBoundEmailClick = () => {
    if (!currentEmail) return;
    setBoundEmailDialog(true);
  };

  // 弹窗"换绑邮箱"按钮：先弹出 365 天冷却提示
  const handleRequestChange = () => {
    setBoundEmailDialog(false);
    // 静态入口演示：默认走"有冷却"分支
    setCooldownDialog(true);
  };

  // 冷却提示"继续换绑"：打开换绑流程
  const handleContinueChange = () => {
    setCooldownDialog(false);
    setChangeEmailVisible(true);
  };

  // 换绑成功
  const handleChangeSuccess = (newEmail: string) => {
    setCurrentEmail(newEmail);
    setChangeEmailVisible(false);
  };

  return (
    <div
      className={cn(
        "fixed inset-0 z-[65] bg-[#f7f7f7] flex flex-col transition-transform duration-300 ease-[cubic-bezier(0.25,0.1,0.25,1)]",
        isEntering ? "translate-x-0" : "translate-x-full"
      )}
      onTransitionEnd={handleTransitionEnd}
    >
      {/* Top bar - fixed */}
      <div className="flex-shrink-0 flex items-center px-4 pt-[max(0.75rem,env(safe-area-inset-top))] pb-3 bg-white z-10">
        <button
          type="button"
          onClick={onClose}
          className="w-8 h-8 flex items-center justify-center -ml-2"
        >
          <ArrowLeft className="w-5 h-5 text-gray-900" strokeWidth={1.5} />
        </button>
        <h1 className="flex-1 text-center text-base font-medium text-gray-900">
          Porten安全中心
        </h1>
        <button
          type="button"
          onClick={() => {
            // 反馈进度入口占位：仅做点击区域，无业务
          }}
          className="-mr-2 px-2 py-1 text-sm text-gray-500 active:text-gray-700 transition-colors"
        >
          反馈进度
        </button>
      </div>

      {/* Content */}
      <div className="flex-1 overflow-y-auto">
        <div className="pt-16 pb-8 flex flex-col items-center">
          <div className="relative w-20 h-20 flex items-center justify-center">
            {/* 外层波动光晕 */}
            <span className="absolute inset-0 rounded-full bg-blue-400/20 animate-ping" />
            <span className="absolute inset-2 rounded-full bg-blue-400/30 animate-pulse" />
            <ShieldCheck
              className="relative w-12 h-12 text-blue-500"
              strokeWidth={1.5}
            />
          </div>
          <p className="mt-4 text-sm text-gray-500">账号安全 由 Porten 守护</p>
        </div>

        <div className="w-full">
          {securityOptions.map((opt) => (
            <button
              key={opt.id}
              type="button"
              onClick={opt.id === "bound_email" ? handleBoundEmailClick : undefined}
              className="w-full flex items-center justify-between px-4 py-4 bg-white active:bg-gray-50/50 transition-colors"
            >
              <span className="text-base text-gray-900">{opt.label}</span>
              <ChevronRight
                className="w-4 h-4 text-gray-400"
                strokeWidth={1.5}
              />
            </button>
          ))}
        </div>
      </div>

      {/* 弹窗：绑定的邮箱（脱敏展示） */}
      <BoundEmailDialog
        visible={boundEmailDialog}
        email={currentEmail}
        onClose={() => setBoundEmailDialog(false)}
        onChangeEmail={handleRequestChange}
      />

      {/* 弹窗：365 天换绑冷却提示 */}
      <ChangeEmailCooldownDialog
        visible={cooldownDialog}
        remainingDays={0}
        onClose={() => setCooldownDialog(false)}
        onContinue={handleContinueChange}
      />

      {/* 页面：换绑邮箱流程 */}
      <ChangeEmailPage
        visible={changeEmailVisible}
        currentEmail={currentEmail}
        onClose={() => setChangeEmailVisible(false)}
        onSuccess={handleChangeSuccess}
      />
    </div>
  );
}
