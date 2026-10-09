import { useEffect } from "react";
import { cn } from "@/lib/utils";
import splashIcon from "@/assets/splash-icon.svg";
import { GradientLogo } from "@/components/GradientLogo";

/** 开屏停留时长（ms），不允许跳过 */
const SPLASH_DURATION = 3000;
/** 淡出过渡时长（ms），需与容器 transition-duration 一致 */
const FADE_DURATION = 400;

interface SplashScreenProps {
  /** 停留结束后触发淡出 */
  onDone: () => void;
  /** 淡出结束后触发卸载 */
  onExited: () => void;
  fadingOut: boolean;
}

/**
 * 开屏页：屏幕正中央显示航班图标（缩小后保持原视觉中心位置），
 * 底部「静夜思云提供计算服务」上方显示蓝粉渐变 Porten 文本 Logo。
 * 停留 3 秒后淡出，期间全屏覆盖、不响应点击（不允许跳过）。
 */
export function SplashScreen({ onDone, onExited, fadingOut }: SplashScreenProps) {
  useEffect(() => {
    const timer = setTimeout(onDone, SPLASH_DURATION);
    return () => clearTimeout(timer);
  }, [onDone]);

  return (
    <div
      className={cn(
        "fixed inset-0 z-[2000] bg-white flex flex-col items-center justify-center select-none transition-opacity ease-out",
        fadingOut ? "opacity-0 pointer-events-none" : "opacity-100"
      )}
      style={{ transitionDuration: `${FADE_DURATION}ms` }}
      onTransitionEnd={() => {
        if (fadingOut) onExited();
      }}
    >
      {/* 中央：图标 Logo（外层平移补偿，保持原视觉中心位置） */}
      <div className="-translate-y-10">
        <img src={splashIcon} alt="" className="w-24 h-24 splash-icon-in" />
      </div>

      {/* 底部：文本 Logo + 服务声明 */}
      <div className="absolute bottom-[calc(env(safe-area-inset-bottom,0px)+1.75rem)] flex flex-col items-center">
        <div className="splash-fade-up">
          <GradientLogo size="text-3xl" />
        </div>
        <p className="splash-caption mt-2 text-xs text-gray-400">
          静夜思云提供计算服务
        </p>
      </div>
    </div>
  );
}
