import { useRef, useState } from "react";
import { useNavigate } from "react-router-dom";
import splashIcon from "@/assets/splash-icon.svg";
import { CapsuleInput } from "@/components/CapsuleInput";
import { GradientButton } from "@/components/GradientButton";
import { useToastStore } from "@/store/toastStore";
import { cn } from "@/lib/utils";

/** 卡片视图：输入表单卡片 / 验证方式选择卡片 */
type CardView = "form" | "method";

/**
 * 找回 Porten 账号独立页面（登录页「忘记密码？」进入）：
 * 无顶部栏，主内容区为 96% 宽圆角细边框表单卡片（无阴影，高度由表单内容决定）；
 * 点击「更换验证方式」/ 验证方式选项时，顶部分割线以 1.5px 蓝粉渐变播放
 * 3s 慢快慢（ease-in-out）加载动画，动画期间主内容区覆盖浅灰透明遮罩，
 * 动画结束后遮罩隐藏并切换卡片；验证方式选项随当前方式联动（默认邮箱，
 * 提供另一种方式），验证方式选择卡片高度与输入表单卡片保持一致。
 */
export default function ForgotPasswordPage() {
  const navigate = useNavigate();
  const showToast = useToastStore((state) => state.show);

  /** 当前卡片视图 */
  const [view, setView] = useState<CardView>("form");
  /** 验证方式：邮箱 / 手机号（选择后表单输入框随之切换） */
  const [verifyType, setVerifyType] = useState<"email" | "phone">("email");
  /** 账号输入值 */
  const [account, setAccount] = useState("");
  /** 是否处于卡片切换加载中（顶部分割线播放进度动画，期间锁定交互） */
  const [switching, setSwitching] = useState(false);
  /** 进度条动画 key：每次触发递增，强制重放动画 */
  const [progressKey, setProgressKey] = useState(0);
  /** 动画结束后待执行的卡片切换动作 */
  const pendingApply = useRef<(() => void) | null>(null);

  /** 播放顶部加载动画（3s），onAnimationEnd 后执行切换 */
  const playProgressAndSwitch = (apply: () => void) => {
    if (switching) return;
    pendingApply.current = apply;
    setProgressKey((key) => key + 1);
    setSwitching(true);
  };

  /** 顶部进度动画播放完毕：执行卡片切换并复位进度条 */
  const handleProgressEnd = () => {
    pendingApply.current?.();
    pendingApply.current = null;
    setSwitching(false);
  };

  /** 表单卡片 → 验证方式选择卡片 */
  const goMethodCard = () => {
    playProgressAndSwitch(() => setView("method"));
  };

  /** 选择验证方式 → 切回输入表单卡片（输入框随验证方式切换） */
  const chooseMethod = (type: "email" | "phone") => {
    playProgressAndSwitch(() => {
      setVerifyType(type);
      setAccount("");
      setView("form");
    });
  };

  /** 下一步（添加工作页面暂未实现，先做非空校验 + 占位提示） */
  const handleNext = () => {
    if (!account.trim()) {
      showToast(verifyType === "phone" ? "请输入手机号" : "请输入邮箱", "info");
      return;
    }
    showToast("找回账号功能即将上线，敬请期待", "info", "center");
  };

  return (
    <div className="fixed inset-0 bg-white flex flex-col relative overflow-hidden">
      {/* 顶部分割线：卡片切换时以 1.5px 粗度显示蓝粉渐变加载进度（慢快慢 3s） */}
      {switching && (
        <div
          key={progressKey}
          className="auth-progress absolute top-0 left-0 z-10"
          onAnimationEnd={handleProgressEnd}
        />
      )}

      {/* 主内容区：表单卡片垂直居中（卡片直接占页面宽度 96%） */}
      <div className="flex-1 flex flex-col justify-center pb-10 relative">
        {/* 卡片切换动画期间：主内容区浅灰色透明遮罩层（动画结束后随 switching 复位隐藏） */}
        {switching && (
          <div className="forgot-mask absolute inset-0 z-20 bg-gray-200/50" />
        )}
        <div className="relative w-[96%] mx-auto rounded-2xl border border-gray-200 bg-white">
          {/* 输入表单卡片：正常渲染撑起容器高度（验证方式卡片与它恒等高） */}
          <div className={cn("p-6", view === "method" && "invisible")}>
            {/* 第一行：开屏图标 + 标题 */}
            <div className="flex items-center gap-2.5">
              <img src={splashIcon} alt="" className="w-9 h-9" />
              <h1 className="text-lg font-semibold text-gray-900">
                找回Porten账号
              </h1>
            </div>

            {/* 第二行：身份验证提示 */}
            <p className="mt-4 text-xs text-gray-400 leading-relaxed">
              通过你的注册信息验证身份（我们需要收集你提供的一些信息来判断你的本次申请是否通过，为了防止账户滥用我们必须确定你是账号所有者）
            </p>

            {/* 第三行：账号输入框（复用登录页胶囊输入框，风格一致） */}
            <div className="mt-6">
              <CapsuleInput
                type={verifyType === "phone" ? "tel" : "text"}
                placeholder={verifyType === "phone" ? "请输入手机号" : "请输入邮箱"}
                value={account}
                onChange={(e) => setAccount(e.target.value)}
              />
            </div>

            {/* 下一步按钮（复用登录页渐变按钮样式） */}
            <GradientButton className="mt-3" onClick={handleNext}>
              下一步
            </GradientButton>

            {/* 底部操作行：左「去登录」右「更换验证方式」 */}
            <div className="mt-6 flex items-center justify-between">
              <button
                type="button"
                onClick={() => navigate("/login")}
                className="text-xs text-[#5BCEFA] hover:text-[#3bb5e5] transition-colors"
              >
                去登录
              </button>
              <button
                type="button"
                onClick={goMethodCard}
                disabled={switching}
                className="text-xs text-[#5BCEFA] hover:text-[#3bb5e5] transition-colors disabled:opacity-60"
              >
                更换验证方式
              </button>
            </div>
          </div>

          {/* 验证方式选择卡片：absolute 铺满容器，高度与输入表单卡片保持一致 */}
          <div
            className={cn(
              "absolute inset-0 p-6 flex flex-col",
              view === "form" && "invisible"
            )}
          >
            {/* 顶部左对齐标题 */}
            <h2 className="text-sm font-medium text-gray-900">
              可用的验证方式
            </h2>

            {/* 验证方式选项：卡片正中间显示，蓝色文本（随当前验证方式联动，默认提供另一种方式） */}
            <div className="flex-1 flex items-center justify-center">
              <button
                type="button"
                onClick={() =>
                  chooseMethod(verifyType === "email" ? "phone" : "email")
                }
                disabled={switching}
                className="text-sm text-[#5BCEFA] hover:text-[#3bb5e5] transition-colors disabled:opacity-60"
              >
                {verifyType === "email" ? "手机号验证" : "通过邮箱验证"}
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
