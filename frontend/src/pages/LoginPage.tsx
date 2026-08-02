import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import {
  HelpCircle,
  Lock,
  MoreHorizontal,
  UserPlus,
} from "lucide-react";
import { GradientLogo } from "@/components/GradientLogo";
import { CapsuleInput } from "@/components/CapsuleInput";
import { GradientButton } from "@/components/GradientButton";
import { AuthDivider } from "@/components/AuthDivider";
import { IconCircleButton } from "@/components/IconCircleButton";
import { LoginMethodSheet, LoginMethod } from "@/components/LoginMethodSheet";
import { useAuthStore } from "@/store/authStore";
import { useToastStore } from "@/store/toastStore";
import { cn } from "@/lib/utils";
import { AgreementCheckbox } from "@/components/AgreementCheckbox";
import { AgreementViewer } from "@/components/AgreementViewer";

const methodLabels: Record<LoginMethod, { placeholder: string; label: string }> = {
  email: { placeholder: "请输入邮箱", label: "邮箱" },
  phone: { placeholder: "请输入手机号", label: "手机号" },
  porten: { placeholder: "请输入 Porten 账号", label: "Porten 账号" },
};

// 判断是否为网络异常
function isNetworkError(msg: string): boolean {
  return /failed to fetch|networkerror|load failed|网络|timeout|超时/i.test(msg);
}

export default function LoginPage() {
  const navigate = useNavigate();
  const {
    loginMethod,
    isPasswordMode,
    isCodeSent,
    countdown,
    isLoading,
    user,
    setLoginMethod,
    switchToPasswordMode,
    sendCode,
    login,
    clearError,
  } = useAuthStore();

  const [sheetOpen, setSheetOpen] = useState(false);
  const [account, setAccount] = useState("");
  const [password, setPassword] = useState("");
  const [code, setCode] = useState("");
  const [agreementChecked, setAgreementChecked] = useState(false);
  const [viewerAgreementId, setViewerAgreementId] = useState<string | null>(null);
  const showToast = useToastStore((state) => state.show);

  // Phone mock state (undeveloped backend)
  const [phoneCodeSent, setPhoneCodeSent] = useState(false);
  const [phoneCountdown, setPhoneCountdown] = useState(0);
  const [phoneLoading, setPhoneLoading] = useState(false);

  useEffect(() => {
    if (user) {
      navigate("/home");
    }
  }, [user, navigate]);

  useEffect(() => {
    if (phoneCountdown <= 0) return;
    const timer = setInterval(() => {
      setPhoneCountdown((prev) => (prev <= 1 ? 0 : prev - 1));
    }, 1000);
    return () => clearInterval(timer);
  }, [phoneCountdown]);

  useEffect(() => {
    setAccount("");
    setPassword("");
    setCode("");
    setPhoneCodeSent(false);
    setPhoneCountdown(0);
    clearError();
  }, [loginMethod, isPasswordMode, clearError]);

  const isPhone = loginMethod === "phone";
  const codeSent = isPhone ? phoneCodeSent : isCodeSent;
  const currentCountdown = isPhone ? phoneCountdown : countdown;
  const currentLoading = isPhone ? phoneLoading : isLoading;

  const handleSendCode = async () => {
    if (!account.trim()) return;
    clearError();
    if (!agreementChecked) {
      showToast("请先同意相关协议", "info");
      return;
    }
    if (isPhone) {
      setPhoneLoading(true);
      setTimeout(() => {
        setPhoneLoading(false);
        setPhoneCodeSent(true);
        setPhoneCountdown(60);
        showToast("验证码已发送", "success");
      }, 800);
      return;
    }
    await sendCode(account.trim());
    // sendCode 内部 catch 错误并 set error，不会 throw
    const err = useAuthStore.getState().error;
    if (err) {
      showToast(isNetworkError(err) ? "网络异常" : err, "error");
    } else {
      showToast("验证码已发送", "success");
    }
  };

  const handleResend = () => {
    if (currentCountdown > 0) return;
    handleSendCode();
  };

  const handleLogin = async () => {
    clearError();
    if (!agreementChecked) {
      showToast("请先同意相关协议", "info");
      return;
    }
    if (isPhone) {
      if (!code || code.length !== 6) return;
      showToast("登录成功", "success");
      navigate("/home");
      return;
    }
    try {
      if (loginMethod === "porten") {
        if (!account.trim() || !password) return;
        await login({ portenId: account.trim(), password });
      } else if (isPasswordMode) {
        if (!account.trim() || !password) return;
        await login({ email: account.trim(), password });
      } else {
        if (!account.trim() || !code || code.length !== 6) return;
        await login({ email: account.trim(), code });
      }
      showToast("登录成功", "success");
    } catch (err) {
      const msg = err instanceof Error ? err.message : "登录失败";
      showToast(isNetworkError(msg) ? "网络异常" : msg, "error");
    }
  };

  const handleMethodChange = (method: LoginMethod) => {
    setLoginMethod(method);
  };

  const accountPlaceholder = methodLabels[loginMethod].placeholder;
  const showPassword = isPasswordMode || loginMethod === "porten";
  const showCode = codeSent && !showPassword;

  return (
    <div className="min-h-screen bg-white flex flex-col relative">
      {/* Top help text */}
      <div className="w-full flex justify-end px-6 pt-6">
        <button
          type="button"
          className="flex items-center gap-1 text-xs text-gray-400 hover:text-gray-600 transition-colors"
        >
          <HelpCircle className="w-3.5 h-3.5" />
          <span>帮助</span>
        </button>
      </div>

      {/* Main content */}
      <div className="flex-1 flex flex-col items-center justify-center px-6 w-full max-w-md mx-auto pb-8">
        <div className="w-full flex flex-col items-center">
          <GradientLogo />

          <div className="w-full mt-12">
            <p className="text-sm text-gray-500 mb-3 pl-1">登录</p>

            <CapsuleInput
              type={loginMethod === "phone" ? "tel" : "text"}
              placeholder={accountPlaceholder}
              value={account}
              onChange={(e) => setAccount(e.target.value)}
              className="mb-3"
            />

            {/* Password input */}
            <div
              className={cn(
                "overflow-hidden transition-all duration-300 ease-out",
                showPassword ? "max-h-24 opacity-100 mb-3" : "max-h-0 opacity-0 mb-0"
              )}
            >
              <CapsuleInput
                type="password"
                placeholder="请输入密码"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
              <div className="flex justify-end mt-2 pr-1">
                <button
                  type="button"
                  className="text-xs text-gray-400 hover:text-gray-600 transition-colors"
                >
                  忘记密码？
                </button>
              </div>
            </div>

            {/* Verification code input */}
            <div
              className={cn(
                "overflow-hidden transition-all duration-300 ease-out",
                showCode ? "max-h-32 opacity-100 mb-3" : "max-h-0 opacity-0 mb-0"
              )}
            >
              <CapsuleInput
                type="text"
                inputMode="numeric"
                placeholder="请输入验证码"
                maxLength={6}
                value={code}
                onChange={(e) => setCode(e.target.value)}
              />
              <div className="h-8 flex items-center justify-center mt-2">
                {currentCountdown > 0 ? (
                  <span className="text-xs text-gray-400">
                    {currentCountdown}s 重新获取验证码
                  </span>
                ) : (
                  <button
                    type="button"
                    onClick={handleResend}
                    className="text-xs text-[#5BCEFA] hover:text-[#3bb5e5] transition-colors"
                  >
                    重新获取验证码
                  </button>
                )}
              </div>
            </div>

            <GradientButton
              onClick={showPassword || codeSent ? handleLogin : handleSendCode}
              loading={currentLoading}
            >
              {showPassword || codeSent ? "登录" : "获取验证码"}
            </GradientButton>

            <AgreementCheckbox
              checked={agreementChecked}
              onChange={(checked) => {
                setAgreementChecked(checked);
              }}
              onOpenAgreement={setViewerAgreementId}
            />
          </div>
        </div>
      </div>

      {/* Bottom actions */}
      <div className="w-full px-6 pb-8 max-w-md mx-auto">
        <AuthDivider text="注册/其他登录方式" />

        <div className="flex items-start justify-center gap-8 mt-4">
          <IconCircleButton
            icon={<UserPlus className="w-5 h-5" strokeWidth={1.8} />}
            label="注册"
            onClick={() => navigate("/register")}
          />
          <IconCircleButton
            icon={<Lock className="w-5 h-5" strokeWidth={1.8} />}
            label="密码登录"
            onClick={switchToPasswordMode}
          />
          <IconCircleButton
            icon={<MoreHorizontal className="w-5 h-5" strokeWidth={1.8} />}
            label="其他登录方式"
            onClick={() => setSheetOpen(true)}
          />
        </div>
      </div>

      <LoginMethodSheet
        open={sheetOpen}
        value={loginMethod}
        onChange={handleMethodChange}
        onClose={() => setSheetOpen(false)}
      />

      <AgreementViewer
        agreementId={viewerAgreementId}
        onClose={() => setViewerAgreementId(null)}
        onOpenAgreement={setViewerAgreementId}
      />
    </div>
  );
}
