import { useEffect, useState } from "react";
import { createPortal } from "react-dom";
import { BackIcon } from "@/components/common/BackIcon";
import { cn } from "@/lib/utils";

/**
 * 底部弹出面板与创建旅程页共用的底部按钮样式
 * （取消 = 浅灰小圆角；确定 = 淡粉色不饱和小圆角、圆角圆润）。
 */
export const SHEET_BTN_CANCEL =
  "flex-1 py-3 rounded-xl bg-gray-100 text-gray-500 text-base font-medium transition-colors active:bg-gray-200";
export const SHEET_BTN_CONFIRM =
  "flex-1 py-3 rounded-xl bg-[#F7C5D0] text-white text-base font-medium transition-opacity active:opacity-80";

interface BottomSheetProps {
  visible: boolean;
  onClose: () => void;
  /** 面板顶部居中标题 */
  title: string;
  /** 面板高度类：城市选择占屏 90%（h-[90vh]），其余面板自适应 */
  heightClass?: string;
  /** 标题左侧返回按钮（机场选择第二步返回城市列表用） */
  onBack?: () => void;
  children: React.ReactNode;
}

/**
 * 通用底部弹出面板：遮罩淡入 + 面板自底部滑入/滑出。
 * 交互动画模式与全站已验证的 GenderPickerSheet 一致（renderVisible/isEntering 两态过渡）。
 * 通过 createPortal 挂到 body 下，z-[70] 高于页面根容器（z-[60]）。
 */
export function BottomSheet({
  visible,
  onClose,
  title,
  heightClass,
  onBack,
  children,
}: BottomSheetProps) {
  const [renderVisible, setRenderVisible] = useState(visible);
  const [isEntering, setIsEntering] = useState(false);

  useEffect(() => {
    if (visible) {
      setRenderVisible(true);
      setIsEntering(false);
      requestAnimationFrame(() => {
        requestAnimationFrame(() => setIsEntering(true));
      });
    } else if (renderVisible) {
      setIsEntering(false);
      const timer = setTimeout(() => setRenderVisible(false), 300);
      return () => clearTimeout(timer);
    }
  }, [visible, renderVisible]);

  if (!renderVisible) return null;

  return createPortal(
    <div className="fixed inset-0 z-[70] flex flex-col justify-end">
      {/* 遮罩：点击关闭 */}
      <button
        type="button"
        onClick={onClose}
        className={cn(
          "absolute inset-0 bg-black/40 transition-opacity duration-300",
          isEntering ? "opacity-100" : "opacity-0"
        )}
        aria-label="关闭"
      />

      {/* 面板：translate-y-full ↔ 0 滑入滑出 */}
      <div
        className={cn(
          "relative bg-white rounded-t-3xl flex flex-col overflow-hidden transition-transform duration-300 ease-[cubic-bezier(0.25,0.1,0.25,1)]",
          heightClass,
          isEntering ? "translate-y-0" : "translate-y-full"
        )}
      >
        {/* 拖拽手柄 */}
        <div className="flex justify-center pt-3 pb-1">
          <div className="w-9 h-1 rounded-full bg-gray-300" />
        </div>

        {/* 顶部居中标题（可带左侧返回按钮） */}
        <div className="relative flex items-center justify-center py-2.5 flex-shrink-0">
          {onBack && (
            <button
              type="button"
              onClick={onBack}
              className="absolute left-2 w-10 h-10 flex items-center justify-center"
              aria-label="返回"
            >
              <BackIcon className="w-7 h-7" />
            </button>
          )}
          <h2 className="text-base font-medium text-gray-900">{title}</h2>
        </div>

        {children}
      </div>
    </div>,
    document.body
  );
}
