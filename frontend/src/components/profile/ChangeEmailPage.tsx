import { useEffect, useMemo, useRef, useState } from "react";
import { ArrowLeft } from "lucide-react";
import { cn } from "@/lib/utils";
import { SystemToast, ToastType } from "@/components/SystemToast";
import {
  isValidEmail,
  maskEmailForVerify,
  validateNewEmail,
  validateVerificationCode,
  verifyEmailByMask,
  type MaskedEmail,
} from "@/lib/email";
import { changeEmail, sendVerificationCode } from "@/lib/api";

interface ChangeEmailPageProps {
  visible: boolean;
  currentEmail: string;
  onClose: () => void;
  onSuccess: (newEmail: string) => void;
}

type Step = "verifyCurrent" | "oldCode" | "newEmail";

const COUNTDOWN_SECONDS = 60;
const TOAST_AUTO_HIDE_MS = 1500;

export function ChangeEmailPage({
  visible,
  currentEmail,
  onClose,
  onSuccess,
}: ChangeEmailPageProps) {
  const [shouldRender, setShouldRender] = useState(false);
  const [isEntering, setIsEntering] = useState(false);
  const [step, setStep] = useState<Step>("verifyCurrent");
  const [oldEmailInput, setOldEmailInput] = useState("");
  const [oldCode, setOldCode] = useState("");
  const [newEmail, setNewEmail] = useState("");
  const [newCode, setNewCode] = useState("");

  const [oldCountdown, setOldCountdown] = useState(0);
  const [newCountdown, setNewCountdown] = useState(0);
  const [sendingOld, setSendingOld] = useState(false);
  const [sendingNew, setSendingNew] = useState(false);
  const [submitting, setSubmitting] = useState(false);

  const [errors, setErrors] = useState<{
    oldEmailInput?: string;
    oldCode?: string;
    newEmail?: string;
    newCode?: string;
  }>({});

  const [toastVisible, setToastVisible] = useState(false);
  const [toastType, setToastType] = useState<ToastType>("loading");
  const [toastText, setToastText] = useState("");

  const oldTimerRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const newTimerRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const toastHideTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  // 当前账号原邮箱的脱敏结构
  const masked: MaskedEmail | null = useMemo(
    () => (visible ? maskEmailForVerify(currentEmail) : null),
    [visible, currentEmail]
  );

  useEffect(() => {
    if (visible) {
      setShouldRender(true);
      requestAnimationFrame(() => {
        requestAnimationFrame(() => setIsEntering(true));
      });
      // 进入时重置表单
      setStep("verifyCurrent");
      setOldEmailInput("");
      setOldCode("");
      setNewEmail("");
      setNewCode("");
      setErrors({});
    } else {
      setIsEntering(false);
    }
    return () => {
      if (oldTimerRef.current) clearInterval(oldTimerRef.current);
      if (newTimerRef.current) clearInterval(newTimerRef.current);
      if (toastHideTimerRef.current) clearTimeout(toastHideTimerRef.current);
    };
  }, [visible]);

  const handleTransitionEnd = () => {
    if (!visible) {
      setShouldRender(false);
    }
  };

  const showToast = (type: ToastType, text: string, autoHide = true) => {
    if (toastHideTimerRef.current) {
      clearTimeout(toastHideTimerRef.current);
      toastHideTimerRef.current = null;
    }
    setToastType(type);
    setToastText(text);
    setToastVisible(true);
    if (autoHide) {
      toastHideTimerRef.current = setTimeout(() => {
        setToastVisible(false);
        toastHideTimerRef.current = null;
      }, TOAST_AUTO_HIDE_MS);
    }
  };
  const hideToast = () => {
    if (toastHideTimerRef.current) {
      clearTimeout(toastHideTimerRef.current);
      toastHideTimerRef.current = null;
    }
    setToastVisible(false);
  };

  const startCountdown = (
    setter: React.Dispatch<React.SetStateAction<number>>,
    ref: React.MutableRefObject<ReturnType<typeof setInterval> | null>
  ) => {
    if (ref.current) clearInterval(ref.current);
    setter(COUNTDOWN_SECONDS);
    ref.current = setInterval(() => {
      setter((prev) => {
        if (prev <= 1) {
          if (ref.current) clearInterval(ref.current);
          ref.current = null;
          return 0;
        }
        return prev - 1;
      });
    }, 1000);
  };

  // 步骤 1：校验原邮箱脱敏输入
  const handleVerifyCurrent = () => {
    if (!masked) {
      setErrors((e) => ({ ...e, oldEmailInput: "当前账号未绑定邮箱" }));
      return;
    }
    const result = verifyEmailByMask(masked, oldEmailInput, currentEmail);
    if (result.ok !== true) {
      setErrors((e) => ({ ...e, oldEmailInput: result.message }));
      return;
    }
    setErrors((e) => ({ ...e, oldEmailInput: undefined }));
    setStep("oldCode");
  };

  // 步骤 2：发送原邮箱验证码
  const handleSendOldCode = async () => {
    if (!isValidEmail(currentEmail)) {
      showToast("error", "当前邮箱格式异常");
      return;
    }
    setSendingOld(true);
    try {
      await sendVerificationCode(currentEmail, "change_email_old");
      showToast("success", "验证码已发送至原邮箱");
      startCountdown(setOldCountdown, oldTimerRef);
    } catch (err) {
      const msg = err instanceof Error ? err.message : "发送失败，请稍后重试";
      showToast("error", msg);
    } finally {
      setSendingOld(false);
    }
  };

  // 步骤 2：提交原邮箱验证码
  const handleSubmitOldCode = () => {
    const err = validateVerificationCode(oldCode);
    if (err) {
      setErrors((e) => ({ ...e, oldCode: err }));
      return;
    }
    setErrors((e) => ({ ...e, oldCode: undefined }));
    setStep("newEmail");
  };

  // 步骤 3：发送新邮箱验证码
  const handleSendNewCode = async () => {
    const err = validateNewEmail(newEmail, currentEmail);
    if (err) {
      setErrors((e) => ({ ...e, newEmail: err }));
      return;
    }
    setErrors((e) => ({ ...e, newEmail: undefined }));
    setSendingNew(true);
    try {
      await sendVerificationCode(newEmail.trim(), "change_email_new");
      showToast("success", "验证码已发送至新邮箱");
      startCountdown(setNewCountdown, newTimerRef);
    } catch (e) {
      const msg = e instanceof Error ? e.message : "发送失败，请稍后重试";
      showToast("error", msg);
    } finally {
      setSendingNew(false);
    }
  };

  // 步骤 3：提交新邮箱 + 验证码
  const handleSubmitNewCode = async () => {
    const emailErr = validateNewEmail(newEmail, currentEmail);
    if (emailErr) {
      setErrors((e) => ({ ...e, newEmail: emailErr }));
      return;
    }
    const codeErr = validateVerificationCode(newCode);
    if (codeErr) {
      setErrors((e) => ({ ...e, newCode: codeErr }));
      return;
    }
    setErrors({});
    setSubmitting(true);
    try {
      await changeEmail({
        new_email: newEmail.trim(),
        old_code: oldCode,
        new_code: newCode,
      });
      showToast("loading", "邮箱换绑成功", false);
      setTimeout(() => {
        hideToast();
        onSuccess(newEmail.trim());
      }, 800);
    } catch (err) {
      const msg = err instanceof Error ? err.message : "换绑失败，请稍后重试";
      showToast("error", msg);
    } finally {
      setSubmitting(false);
    }
  };

  const stepTitle = useMemo(() => {
    if (step === "verifyCurrent") return "验证原邮箱";
    if (step === "oldCode") return "验证原邮箱";
    return "绑定新邮箱";
  }, [step]);
  const stepSubtitle = useMemo(() => {
    if (step === "verifyCurrent") {
      return "请输入原邮箱脱敏部分以验证账号所有权";
    }
    if (step === "oldCode") {
      return "请输入原邮箱收到的验证码";
    }
    return "请输入新的邮箱地址，并通过验证码完成换绑";
  }, [step]);

  if (!shouldRender) return null;

  return (
    <div
      className={cn(
        "fixed inset-0 z-[68] bg-[#f7f7f7] flex flex-col transition-transform duration-300 ease-[cubic-bezier(0.25,0.1,0.25,1)]",
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
          换绑邮箱
        </h1>
        <div className="w-8" />
      </div>

      {/* Content */}
      <div className="flex-1 overflow-y-auto">
        <div className="px-6 pt-8">
          <h2 className="text-2xl font-semibold text-gray-900 tracking-tight">
            {stepTitle}
          </h2>
          <p className="mt-2 text-sm text-gray-500 leading-6">
            {stepSubtitle}
          </p>
        </div>

        {step === "verifyCurrent" ? (
          <div className="px-6 mt-8 space-y-5">
            <div>
              <label className="block text-xs text-gray-500 mb-2">
                原邮箱
              </label>
              {masked ? (
                <>
                  <div className="w-full h-12 px-4 flex items-center text-base text-gray-700 font-mono tracking-wide">
                    {masked.display}
                  </div>
                  <p className="mt-2 text-xs text-gray-400">{masked.hint}</p>
                </>
              ) : (
                <div className="w-full h-12 px-4 flex items-center text-base text-gray-400">
                  当前账号未绑定邮箱
                </div>
              )}
            </div>

            <div>
              <label className="block text-xs text-gray-500 mb-2">
                脱敏部分
              </label>
              <input
                value={oldEmailInput}
                onChange={(e) => {
                  setOldEmailInput(e.target.value);
                  if (errors.oldEmailInput) {
                    setErrors((er) => ({ ...er, oldEmailInput: undefined }));
                  }
                }}
                maxLength={masked?.inputLen ?? 0}
                placeholder={
                  masked
                    ? `请输入 ${masked.inputLen} 个字符`
                    : "请先绑定邮箱"
                }
                disabled={!masked}
                className={cn(
                  "w-full h-12 px-4 bg-white border rounded-xl text-base text-gray-900 placeholder:text-gray-300 outline-none transition-colors",
                  errors.oldEmailInput
                    ? "border-red-400 focus:border-red-400"
                    : "border-gray-200 focus:border-blue-400",
                  !masked && "bg-gray-50 text-gray-400"
                )}
              />
              {errors.oldEmailInput && (
                <p className="mt-2 text-xs text-red-500">
                  {errors.oldEmailInput}
                </p>
              )}
            </div>

            <button
              type="button"
              onClick={handleVerifyCurrent}
              disabled={!masked}
              className={cn(
                "w-full h-12 rounded-full text-base font-medium transition-colors mt-4",
                !masked
                  ? "bg-gray-200 text-gray-400"
                  : "bg-blue-500 text-white active:bg-blue-600"
              )}
            >
              下一步
            </button>
          </div>
        ) : step === "oldCode" ? (
          <div className="px-6 mt-8 space-y-5">
            <div>
              <label className="block text-xs text-gray-500 mb-2">
                原邮箱
              </label>
              <div className="w-full h-12 px-4 flex items-center text-base text-gray-700 font-mono tracking-wide">
                {masked?.display ?? currentEmail}
              </div>
              <p className="mt-2 text-xs text-gray-400">
                验证码将发送至该邮箱
              </p>
            </div>

            <div>
              <label className="block text-xs text-gray-500 mb-2">
                验证码
              </label>
              <CodeInputRow
                value={oldCode}
                onChange={(v) => {
                  setOldCode(v);
                  if (errors.oldCode) {
                    setErrors((er) => ({ ...er, oldCode: undefined }));
                  }
                }}
                countdown={oldCountdown}
                sending={sendingOld}
                error={!!errors.oldCode}
                onSend={handleSendOldCode}
              />
              {errors.oldCode && (
                <p className="mt-2 text-xs text-red-500">{errors.oldCode}</p>
              )}
            </div>

            <button
              type="button"
              onClick={handleSubmitOldCode}
              className="w-full h-12 rounded-full bg-blue-500 text-white text-base font-medium active:bg-blue-600 transition-colors mt-4"
            >
              下一步
            </button>
          </div>
        ) : (
          <div className="px-6 mt-8 space-y-5">
            <div>
              <label className="block text-xs text-gray-500 mb-2">
                新邮箱
              </label>
              <input
                inputMode="email"
                autoCapitalize="off"
                autoComplete="email"
                value={newEmail}
                onChange={(e) => {
                  setNewEmail(e.target.value);
                  if (errors.newEmail) {
                    setErrors((er) => ({ ...er, newEmail: undefined }));
                  }
                }}
                placeholder="请输入新邮箱"
                className={cn(
                  "w-full h-12 px-4 bg-white border rounded-xl text-base text-gray-900 placeholder:text-gray-300 outline-none transition-colors",
                  errors.newEmail
                    ? "border-red-400 focus:border-red-400"
                    : "border-gray-200 focus:border-blue-400"
                )}
              />
              {errors.newEmail && (
                <p className="mt-2 text-xs text-red-500">{errors.newEmail}</p>
              )}
            </div>

            <div>
              <label className="block text-xs text-gray-500 mb-2">
                新邮箱验证码
              </label>
              <CodeInputRow
                value={newCode}
                onChange={(v) => {
                  setNewCode(v);
                  if (errors.newCode) {
                    setErrors((er) => ({ ...er, newCode: undefined }));
                  }
                }}
                countdown={newCountdown}
                sending={sendingNew}
                error={!!errors.newCode}
                disabled={!newEmail}
                onSend={handleSendNewCode}
              />
              {errors.newCode && (
                <p className="mt-2 text-xs text-red-500">{errors.newCode}</p>
              )}
            </div>

            <button
              type="button"
              onClick={handleSubmitNewCode}
              disabled={submitting}
              className={cn(
                "w-full h-12 rounded-full text-base font-medium transition-colors mt-4",
                submitting
                  ? "bg-blue-300 text-white/80"
                  : "bg-blue-500 text-white active:bg-blue-600"
              )}
            >
              {submitting ? "提交中..." : "确认换绑"}
            </button>
          </div>
        )}
      </div>

      <SystemToast
        visible={toastVisible}
        type={toastType}
        text={toastText}
      />
    </div>
  );
}

// 验证码输入行：输入框 + 内嵌右侧发送按钮，整体为一个圆角容器
function CodeInputRow({
  value,
  onChange,
  countdown,
  sending,
  error,
  disabled,
  onSend,
}: {
  value: string;
  onChange: (v: string) => void;
  countdown: number;
  sending: boolean;
  error?: boolean;
  disabled?: boolean;
  onSend: () => void;
}) {
  const sendingDisabled = sending || countdown > 0 || disabled;
  return (
    <div
      className={cn(
        "flex items-center w-full h-12 bg-white border rounded-xl overflow-hidden transition-colors",
        error ? "border-red-400" : "border-gray-200 focus-within:border-blue-400"
      )}
    >
      <input
        inputMode="numeric"
        maxLength={8}
        value={value}
        onChange={(e) => onChange(e.target.value.replace(/\D/g, ""))}
        placeholder="请输入验证码"
        className="flex-1 h-full px-4 bg-transparent text-base text-gray-900 placeholder:text-gray-300 outline-none"
      />
      <button
        type="button"
        onClick={onSend}
        disabled={sendingDisabled}
        className={cn(
          "h-full px-4 text-sm font-medium border-l transition-colors flex-shrink-0",
          sendingDisabled
            ? "text-gray-300 border-gray-100 cursor-not-allowed"
            : "text-blue-500 border-gray-100 active:bg-gray-50"
        )}
      >
        {sending ? "发送中" : countdown > 0 ? `${countdown}s` : "获取验证码"}
      </button>
    </div>
  );
}
