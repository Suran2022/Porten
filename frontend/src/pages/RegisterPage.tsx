import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { LogIn } from "lucide-react";
import { CapsuleInput } from "@/components/CapsuleInput";
import { GradientButton } from "@/components/GradientButton";
import { AuthDivider } from "@/components/AuthDivider";
import { IconCircleButton } from "@/components/IconCircleButton";
import { cn } from "@/lib/utils";
import { sendVerificationCode } from "@/lib/api";
import { useAuthStore } from "@/store/authStore";
import { AgreementCheckbox } from "@/components/AgreementCheckbox";
import { AgreementViewer } from "@/components/AgreementViewer";

const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const COUNTDOWN_SECONDS = 60;

export default function RegisterPage() {
  const navigate = useNavigate();
  const { user, register } = useAuthStore();

  const [step, setStep] = useState<"form" | "code">("form");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [code, setCode] = useState("");
  const [countdown, setCountdown] = useState(0);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [agreementChecked, setAgreementChecked] = useState(false);
  const [viewerAgreementId, setViewerAgreementId] = useState<string | null>(null);
  const [agreementError, setAgreementError] = useState(false);

  useEffect(() => {
    if (user) {
      navigate("/home");
    }
  }, [user, navigate]);

  useEffect(() => {
    if (countdown <= 0) return;
    const timer = setInterval(() => {
      setCountdown((prev) => {
        if (prev <= 1) {
          clearInterval(timer);
          return 0;
        }
        return prev - 1;
      });
    }, 1000);
    return () => clearInterval(timer);
  }, [countdown]);

  const startCountdown = () => {
    setCountdown(COUNTDOWN_SECONDS);
  };

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
    try {
      await sendVerificationCode(email.trim(), "register");
      setStep("code");
      setCode("");
      startCountdown();
    } catch (err) {
      setError(err instanceof Error ? err.message : "发送验证码失败");
    } finally {
      setIsLoading(false);
    }
  };

  const handleResend = async () => {
    if (countdown > 0) return;
    setError(null);
    setIsLoading(true);
    try {
      await sendVerificationCode(email.trim(), "register");
      setCode("");
      startCountdown();
    } catch (err) {
      setError(err instanceof Error ? err.message : "发送验证码失败");
    } finally {
      setIsLoading(false);
    }
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
      navigate("/home");
    } catch (err) {
      setError(err instanceof Error ? err.message : "注册失败");
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-white flex flex-col">
      {/* Main content */}
      <div className="flex-1 flex flex-col items-center justify-center px-6 w-full max-w-md mx-auto pb-8">
        <div className="w-full flex flex-col items-center">
          {step === "form" && (
            <h1 className="text-5xl font-bold tracking-tight text-gray-900 select-none">
              注册 Porten
            </h1>
          )}

          <div className="w-full mt-12">
            <p className="text-sm text-gray-500 mb-3 pl-1">
              {step === "code" ? "输入代码完成身份创建" : "创建身份继续"}
            </p>

            {/* Step 1: account info */}
            <div
              className={cn(
                "overflow-hidden transition-all duration-300 ease-out",
                step === "form"
                  ? "max-h-80 opacity-100 mb-0"
                  : "max-h-0 opacity-0 mb-0"
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
                className="mb-3"
              />
              <CapsuleInput
                type="password"
                placeholder="设置密码"
                value={password}
                onChange={(e) => {
                  setPassword(e.target.value);
                  if (error) setError(null);
                }}
                className="mb-3"
              />
              <CapsuleInput
                type="password"
                placeholder="确认密码"
                value={confirmPassword}
                onChange={(e) => {
                  setConfirmPassword(e.target.value);
                  if (error) setError(null);
                }}
                className="mb-5"
              />
            </div>

            {/* Step 2: verification code */}
            <div
              className={cn(
                "overflow-hidden transition-all duration-300 ease-out",
                step === "code"
                  ? "max-h-40 opacity-100 mb-0"
                  : "max-h-0 opacity-0 mb-0"
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
                className="mb-2"
              />
              <div className="h-8 flex items-center justify-center">
                {countdown > 0 ? (
                  <span className="text-xs text-gray-400">
                    {countdown}s 重新获取验证码
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

            {error && (
              <p className="text-xs text-red-500 text-center mb-3">{error}</p>
            )}

            <GradientButton
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
              <p className="text-xs text-red-500 text-center mt-2">
                请阅读并同意相关协议后继续
              </p>
            )}
          </div>
        </div>
      </div>

      {/* Bottom actions */}
      <div className="w-full px-6 pb-8 max-w-md mx-auto">
        <AuthDivider text="去登录" />

        <div className="flex items-start justify-center mt-4">
          <IconCircleButton
            icon={<LogIn className="w-5 h-5" strokeWidth={1.8} />}
            label="去登录"
            onClick={() => navigate("/login")}
          />
        </div>
      </div>

      <AgreementViewer
        agreementId={viewerAgreementId}
        onClose={() => setViewerAgreementId(null)}
        onOpenAgreement={setViewerAgreementId}
      />
    </div>
  );
}
