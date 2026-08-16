import { useEffect, useState } from "react";
import { useLocation, useNavigate } from "react-router-dom";
import {
  HelpCircle,
  LogIn,
  Mail,
  Phone,
  User,
  UserPlus,
} from "lucide-react";
import { GradientLogo } from "@/components/GradientLogo";
import { CapsuleInput } from "@/components/CapsuleInput";
import { GradientButton } from "@/components/GradientButton";
import { AgreementCheckbox } from "@/components/AgreementCheckbox";
import { AgreementViewer } from "@/components/AgreementViewer";
import { LoginMethod } from "@/components/LoginMethodSheet";
import { useAuthStore } from "@/store/authStore";
import { useToastStore } from "@/store/toastStore";
import { cn } from "@/lib/utils";

const methodLabels: Record<LoginMethod, { placeholder: string }> = {
  email: { placeholder: "请输入邮箱" },
  phone: { placeholder: "请输入手机号" },
  porten: { placeholder: "请输入 Porten 账号" },
};

const methodOptions: { key: LoginMethod; label: string; icon: React.ReactNode }[] = [
  { key: "email", label: "邮箱登录", icon: <Mail className="w-4 h-4" strokeWidth={1.8} /> },
  { key: "phone", label: "手机号登录", icon: <Phone className="w-4 h-4" strokeWidth={1.8} /> },
  { key: "porten", label: "Porten 账号", icon: <User className="w-4 h-4" strokeWidth={1.8} /> },
];

/* ============================= 左侧品牌区 ============================= */

function BrandPanel() {
  return (
    <div className="relative hidden lg:flex w-[52%] max-w-[760px] shrink-0 bg-[#fafbfd] flex-col justify-between p-12 xl:p-16 overflow-hidden">
      {/* 柔和渐变光斑（品牌色，缓慢漂浮） */}
      <div className="pointer-events-none absolute -top-32 -left-32 w-[440px] h-[440px] rounded-full auth-blob auth-blob-1" />
      <div className="pointer-events-none absolute -bottom-40 -right-24 w-[520px] h-[520px] rounded-full auth-blob auth-blob-2" />
      <div className="pointer-events-none absolute top-1/3 left-1/4 w-72 h-72 rounded-full auth-blob auth-blob-3" />

      <div className="relative">
        <GradientLogo />
      </div>

      <div className="relative max-w-md">
        <h2 className="text-[34px] leading-[1.35] font-bold text-gray-900 xl:text-4xl">
          一个为跨性别群体打造的
          <br />
          温暖通信与社区平台
        </h2>
        <p className="mt-5 text-[15px] leading-relaxed text-gray-500">
          安全 · 包容 · 连接 · 治愈
          <br />
          在理解你、尊重你的社区里，做最真实的自己。
        </p>
        <div className="mt-8 flex flex-wrap gap-3">
          {["即时通信", "情绪日记", "资源中心", "音乐治愈"].map((chip) => (
            <span
              key={chip}
              className="inline-flex items-center px-4 py-1.5 rounded-full border border-gray-200/80 bg-white/70 text-sm text-gray-600"
            >
              {chip}
            </span>
          ))}
        </div>
      </div>

      <p className="relative text-sm text-gray-400">
        Made with ❤️ by Porten Team
      </p>
    </div>
  );
}

/* ============================= 登录 / 注册切换（PC 专属） ============================= */

function AuthModeSwitch({
  isRegister,
  onChange,
}: {
  isRegister: boolean;
  onChange: (register: boolean) => void;
}) {
  return (
    <div className="relative grid grid-cols-2 rounded-full bg-gray-100/70 p-1">
      <span
        className="absolute top-1 bottom-1 left-1 rounded-full porten-bg-gradient transition-transform duration-300 ease-[cubic-bezier(0.25,0.1,0.25,1)]"
        style={{
          width: "calc(50% - 4px)",
          transform: isRegister ? "translateX(100%)" : "translateX(0%)",
        }}
      />
      {[
        { label: "登录", register: false },
        { label: "注册", register: true },
      ].map((item) => {
        const active = item.register === isRegister;
        return (
          <button
            key={item.label}
            type="button"
            onClick={() => onChange(item.register)}
            className={cn(
              "relative z-10 h-10 rounded-full text-sm font-medium transition-colors duration-300",
              active ? "text-white" : "text-gray-500 hover:text-gray-700"
            )}
          >
            {item.label}
          </button>
        );
      })}
    </div>
  );
}

/* ============================= 登录方式切换（PC 专属） ============================= */

function LoginMethodPills({
  value,
  onChange,
}: {
  value: LoginMethod;
  onChange: (method: LoginMethod) => void;
}) {
  const activeIndex = methodOptions.findIndex((m) => m.key === value);
  return (
    <div className="relative grid grid-cols-3 rounded-full bg-gray-100/70 p-1">
      <span
        className="absolute top-1 bottom-1 left-1 rounded-full bg-white transition-transform duration-300 ease-[cubic-bezier(0.25,0.1,0.25,1)]"
        style={{
          width: "calc((100% - 8px) / 3)",
          transform: `translateX(${activeIndex * 100}%)`,
        }}
      />
      {methodOptions.map((option) => {
        const active = option.key === value;
        return (
          <button
            key={option.key}
            type="button"
            onClick={() => onChange(option.key)}
            className={cn(
              "relative z-10 h-10 rounded-full flex items-center justify-center gap-1.5 text-[13px] transition-colors duration-300",
              active
                ? "text-gray-900 font-medium"
                : "text-gray-500 hover:text-gray-700"
            )}
          >
            <span
              className={cn(
                "transition-colors duration-300",
                active ? "text-[#F5A9B8]" : "text-gray-400"
              )}
            >
              {option.icon}
            </span>
            {option.label}
          </button>
        );
      })}
    </div>
  );
}

/* ============================= 登录表单 ============================= */

function isNetworkError(msg: string): boolean {
  return /failed to fetch|networkerror|load failed|网络|timeout|超时/i.test(msg);
}

function DesktopLoginForm() {
  const navigate = useNavigate();
  const {
    loginMethod,
    isPasswordMode,
    isCodeSent,
    countdown,
    isLoading,
    setLoginMethod,
    switchToPasswordMode,
    switchToCodeMode,
    sendCode,
    login,
    loginAsMock,
    clearError,
  } = useAuthStore();
  const showToast = useToastStore((state) => state.show);

  const [account, setAccount] = useState("");
  const [password, setPassword] = useState("");
  const [code, setCode] = useState("");
  const [agreementChecked, setAgreementChecked] = useState(false);
  const [viewerAgreementId, setViewerAgreementId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  // 手机号登录的本地 mock 状态
  const [phoneCodeSent, setPhoneCodeSent] = useState(false);
  const [phoneCountdown, setPhoneCountdown] = useState(0);
  const [phoneLoading, setPhoneLoading] = useState(false);

  useEffect(() => {
    setAccount("");
    setPassword("");
    setCode("");
    setError(null);
    setPhoneCodeSent(false);
    setPhoneCountdown(0);
    clearError();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [loginMethod, isPasswordMode]);

  useEffect(() => {
    if (phoneCountdown <= 0) return;
    const timer = setInterval(() => {
      setPhoneCountdown((prev) => (prev <= 1 ? 0 : prev - 1));
    }, 1000);
    return () => clearInterval(timer);
  }, [phoneCountdown]);

  const isPhone = loginMethod === "phone";
  const codeSent = isPhone ? phoneCodeSent : isCodeSent;
  const currentCountdown = isPhone ? phoneCountdown : countdown;
  const currentLoading = isPhone ? phoneLoading : isLoading;
  const showPassword = isPasswordMode || loginMethod === "porten";
  const showCode = codeSent && !showPassword;

  const handleSendCode = async () => {
    if (!account.trim()) return;
    setError(null);
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
    showToast("验证码已发送", "success");
  };

  const handleLogin = async () => {
    setError(null);
    clearError();
    if (!agreementChecked) {
      showToast("请先同意相关协议", "info");
      return;
    }
    if (isPhone) {
      if (!account.trim() || !code || code.length !== 6) return;
      loginAsMock(account.trim());
      showToast("登录成功", "success");
      navigate("/home", { replace: true });
      return;
    }
    if (!account.trim()) return;
    try {
      if (loginMethod === "porten") {
        if (!password) return;
        await login({ portenId: account.trim(), password });
      } else if (isPasswordMode) {
        if (!password) return;
        await login({ email: account.trim(), password });
      } else {
        if (!code || code.length !== 6) return;
        await login({ email: account.trim(), code });
      }
      showToast("登录成功", "success");
      navigate("/home", { replace: true });
    } catch (err) {
      const msg = err instanceof Error ? err.message : "登录失败";
      setError(isNetworkError(msg) ? "网络异常" : msg);
    }
  };

  return (
    <div>
      <h2 className="text-[28px] font-bold text-gray-900">欢迎回来</h2>
      <p className="mt-1.5 text-sm text-gray-500">登录 Porten，继续你的社区旅程</p>

      <LoginMethodPills
        value={loginMethod}
        onChange={(method) => setLoginMethod(method)}
      />

      <div className="mt-6 space-y-3">
        <CapsuleInput
          type={isPhone ? "tel" : "text"}
          placeholder={methodLabels[loginMethod].placeholder}
          value={account}
          onChange={(e) => {
            setAccount(e.target.value);
            if (error) setError(null);
          }}
        />

        {/* 密码输入 */}
        <div
          className={cn(
            "overflow-hidden transition-all duration-300 ease-out",
            showPassword ? "max-h-24 opacity-100" : "max-h-0 opacity-0"
          )}
        >
          <CapsuleInput
            type="password"
            placeholder="请输入密码"
            value={password}
            onChange={(e) => {
              setPassword(e.target.value);
              if (error) setError(null);
            }}
          />
        </div>

        {/* 验证码输入 */}
        <div
          className={cn(
            "overflow-hidden transition-all duration-300 ease-out",
            showCode ? "max-h-32 opacity-100" : "max-h-0 opacity-0"
          )}
        >
          <CapsuleInput
            type="text"
            inputMode="numeric"
            placeholder="请输入验证码"
            maxLength={6}
            value={code}
            onChange={(e) => {
              setCode(e.target.value);
              if (error) setError(null);
            }}
          />
          <div className="h-8 flex items-center justify-end">
            {currentCountdown > 0 ? (
              <span className="text-xs text-gray-400">
                {currentCountdown}s 重新获取验证码
              </span>
            ) : (
              <button
                type="button"
                onClick={handleSendCode}
                className="text-xs text-[#5BCEFA] hover:text-[#3bb5e5] transition-colors"
              >
                重新获取验证码
              </button>
            )}
          </div>
        </div>
      </div>

      {/* 密码 / 验证码模式切换（PC 专属：内联链接式） */}
      <div className="mt-2 flex items-center justify-between">
        {loginMethod === "email" ? (
          <button
            type="button"
            onClick={showPassword ? switchToCodeMode : switchToPasswordMode}
            className="text-xs text-gray-500 hover:text-gray-700 transition-colors"
          >
            {showPassword ? "使用验证码登录" : "使用密码登录"}
          </button>
        ) : (
          <span />
        )}
        {showPassword && (
          <button
            type="button"
            className="text-xs text-gray-400 hover:text-gray-600 transition-colors"
          >
            忘记密码？
          </button>
        )}
      </div>

      {error && (
        <p className="mt-3 text-xs text-red-500 text-center">{error}</p>
      )}

      <GradientButton
        className="mt-4"
        onClick={showPassword || codeSent ? handleLogin : handleSendCode}
        loading={currentLoading}
      >
        {showPassword || codeSent ? "登录" : "获取验证码"}
      </GradientButton>

      <AgreementCheckbox
        checked={agreementChecked}
        onChange={(checked) => setAgreementChecked(checked)}
        onOpenAgreement={setViewerAgreementId}
      />

      <AgreementViewer
        agreementId={viewerAgreementId}
        onClose={() => setViewerAgreementId(null)}
        onOpenAgreement={setViewerAgreementId}
      />
    </div>
  );
}

/* ============================= 注册表单 ============================= */

const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const REGISTER_COUNTDOWN_SECONDS = 60;

function DesktopRegisterForm() {
  const navigate = useNavigate();
  const { register } = useAuthStore();
  const showToast = useToastStore((state) => state.show);

  const [step, setStep] = useState<"form" | "code">("form");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [code, setCode] = useState("");
  const [countdown, setCountdown] = useState(0);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [agreementChecked, setAgreementChecked] = useState(false);
  const [agreementError, setAgreementError] = useState(false);
  const [viewerAgreementId, setViewerAgreementId] = useState<string | null>(null);

  useEffect(() => {
    if (countdown <= 0) return;
    const timer = setInterval(() => {
      setCountdown((prev) => (prev <= 1 ? 0 : prev - 1));
    }, 1000);
    return () => clearInterval(timer);
  }, [countdown]);

  const validateForm = () => {
    if (!email.trim() || !EMAIL_REGEX.test(email)) {
      setError("请输入正确的邮箱地址");
      return false;
    }
    if (password.length < 8) {
      setError("密码长度不能少于 8 位");
      return false;
    }
    if (!/[A-Za-z]/.test(password) || !/\d/.test(password)) {
      setError("密码需同时包含字母和数字");
      return false;
    }
    if (password !== confirmPassword) {
      setError("两次输入的密码不一致");
      return false;
    }
    return true;
  };

  const handleNext = async () => {
    setError(null);
    if (!agreementChecked) {
      setAgreementError(true);
      return;
    }
    setAgreementError(false);
    if (!validateForm()) return;
    setIsLoading(true);
    // Mock 模式下任意邮箱即可直接进入下一步
    setTimeout(() => {
      setIsLoading(false);
      setStep("code");
      setCode("");
      setCountdown(REGISTER_COUNTDOWN_SECONDS);
      showToast("验证码已发送", "success");
    }, 600);
  };

  const handleRegister = async () => {
    setError(null);
    if (!agreementChecked) {
      setAgreementError(true);
      return;
    }
    setAgreementError(false);
    if (code.length !== 6) {
      setError("请输入 6 位验证码");
      return;
    }
    setIsLoading(true);
    try {
      await register({ email: email.trim(), password, code });
      showToast("注册成功", "success");
      navigate("/home", { replace: true });
    } catch (err) {
      setError(err instanceof Error ? err.message : "注册失败");
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div>
      <h2 className="text-[28px] font-bold text-gray-900">创建 Porten 身份</h2>
      <p className="mt-1.5 text-sm text-gray-500">
        {step === "code" ? "输入代码完成身份创建" : "几分钟，开启你的社区之旅"}
      </p>

      <div className="mt-8 space-y-3">
        {/* Step 1 */}
        <div
          className={cn(
            "overflow-hidden transition-all duration-300 ease-out space-y-3",
            step === "form" ? "max-h-96 opacity-100" : "max-h-0 opacity-0"
          )}
        >
          <CapsuleInput
            type="email"
            placeholder="请输入邮箱"
            value={email}
            onChange={(e) => {
              setEmail(e.target.value);
              if (error) setError(null);
            }}
          />
          <CapsuleInput
            type="password"
            placeholder="设置密码（至少 8 位，含字母和数字）"
            value={password}
            onChange={(e) => {
              setPassword(e.target.value);
              if (error) setError(null);
            }}
          />
          <CapsuleInput
            type="password"
            placeholder="确认密码"
            value={confirmPassword}
            onChange={(e) => {
              setConfirmPassword(e.target.value);
              if (error) setError(null);
            }}
          />
        </div>

        {/* Step 2 */}
        <div
          className={cn(
            "overflow-hidden transition-all duration-300 ease-out",
            step === "code" ? "max-h-40 opacity-100" : "max-h-0 opacity-0"
          )}
        >
          <CapsuleInput
            type="text"
            inputMode="numeric"
            placeholder="请输入验证码"
            maxLength={6}
            value={code}
            onChange={(e) => {
              setCode(e.target.value);
              if (error) setError(null);
            }}
          />
          <div className="h-8 flex items-center justify-end">
            {countdown > 0 ? (
              <span className="text-xs text-gray-400">
                {countdown}s 重新获取验证码
              </span>
            ) : (
              <button
                type="button"
                onClick={() => {
                  setCode("");
                  setCountdown(REGISTER_COUNTDOWN_SECONDS);
                  showToast("验证码已发送", "success");
                }}
                className="text-xs text-[#5BCEFA] hover:text-[#3bb5e5] transition-colors"
              >
                重新获取验证码
              </button>
            )}
          </div>
        </div>
      </div>

      {error && (
        <p className="mt-3 text-xs text-red-500 text-center">{error}</p>
      )}

      <GradientButton
        className="mt-4"
        onClick={step === "form" ? handleNext : handleRegister}
        loading={isLoading}
      >
        {step === "form" ? "下一步" : "立即注册"}
      </GradientButton>

      <AgreementCheckbox
        checked={agreementChecked}
        onChange={(checked) => {
          setAgreementChecked(checked);
          if (checked) setAgreementError(false);
        }}
        onOpenAgreement={setViewerAgreementId}
      />

      {agreementError && (
        <p className="mt-2 text-xs text-red-500 text-center">
          请阅读并同意相关协议后继续
        </p>
      )}

      <p className="mt-6 text-center text-sm text-gray-500">
        已有账号？
        <button
          type="button"
          onClick={() => navigate("/login", { replace: true })}
          className="ml-1 text-[#5BCEFA] hover:text-[#3bb5e5] transition-colors"
        >
          去登录
        </button>
      </p>

      <AgreementViewer
        agreementId={viewerAgreementId}
        onClose={() => setViewerAgreementId(null)}
        onOpenAgreement={setViewerAgreementId}
      />
    </div>
  );
}

/* ============================= 页面主体 ============================= */

export default function AuthPageDesktop() {
  const location = useLocation();
  const navigate = useNavigate();
  const user = useAuthStore((state) => state.user);
  const isRegister = location.pathname === "/register";

  useEffect(() => {
    if (user) {
      navigate("/home", { replace: true });
    }
  }, [user, navigate]);

  return (
    <div className="fixed inset-0 flex bg-white overflow-hidden">
      <BrandPanel />

      {/* 右侧表单区 */}
      <div className="flex-1 flex flex-col relative overflow-hidden">
        {/* 顶部帮助 */}
        <div className="absolute top-6 right-8 z-10 flex items-center gap-5">
          <button
            type="button"
            className="flex items-center gap-1.5 text-xs text-gray-400 hover:text-gray-600 transition-colors"
          >
            <HelpCircle className="w-4 h-4" />
            <span>帮助</span>
          </button>
          <button
            type="button"
            onClick={() => navigate(isRegister ? "/login" : "/register", { replace: true })}
            className="flex items-center gap-1.5 text-xs text-gray-400 hover:text-gray-600 transition-colors"
          >
            {isRegister ? (
              <LogIn className="w-4 h-4" />
            ) : (
              <UserPlus className="w-4 h-4" />
            )}
            <span>{isRegister ? "登录" : "注册"}</span>
          </button>
        </div>

        <div className="flex-1 overflow-y-auto desktop-scroll">
          <div className="min-h-full flex items-center justify-center px-10 py-14">
            <div className="w-full max-w-[400px]">
              <AuthModeSwitch
                isRegister={isRegister}
                onChange={(register) =>
                  navigate(register ? "/register" : "/login", { replace: true })
                }
              />
              <div
                key={isRegister ? "register" : "login"}
                className="animate-content-in mt-10"
              >
                {isRegister ? <DesktopRegisterForm /> : <DesktopLoginForm />}
              </div>
            </div>
          </div>
        </div>

        <div className="pb-5 text-center text-xs text-gray-300">
          Porten · 安全 · 包容 · 连接 · 治愈
        </div>
      </div>
    </div>
  );
}
