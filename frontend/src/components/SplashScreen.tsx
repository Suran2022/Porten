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
 * 开屏页：屏幕正中央显示航班图标 + 蓝粉渐变 Porten 文本 Logo，
 * 底部显示「静夜思云提供计算服务」小字。
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
      {/* 中央：图标 + 文本 Logo */}
      <div className="flex flex-col items-center">
        <img src={splashIcon} alt="" className="w-32 h-32 splash-icon-in" />
        <div className="mt-5 splash-fade-up">
          <GradientLogo size="text-6xl" />
        </div>
      </div>

      {/* 底部小字 */}
      <p className="splash-caption absolute bottom-[calc(env(safe-area-inset-bottom,0px)+1.75rem)] text-xs text-gray-400">
        静夜思云提供计算服务
      </p>
    </div>
  );
}
