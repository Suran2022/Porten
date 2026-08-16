import { useEffect, useState } from "react";
import { ArrowLeft, Music2, X } from "lucide-react";
import { cn } from "@/lib/utils";

interface PortenAppBarPageProps {
  visible: boolean;
  onClose: () => void;
  /** PC 弹窗形态：顶部用右对齐关闭图标替代返回图标 */
  closeMode?: boolean;
  showMusic: boolean;
  onToggleMusic: (show: boolean) => void;
}

export function PortenAppBarPage({
  visible,
  onClose,
  closeMode = false,
  showMusic,
  onToggleMusic,
}: PortenAppBarPageProps) {
  const [shouldRender, setShouldRender] = useState(false);
  const [isEntering, setIsEntering] = useState(false);

  useEffect(() => {
    if (visible) {
      setShouldRender(true);
      requestAnimationFrame(() => {
        requestAnimationFrame(() => setIsEntering(true));
      });
    } else if (shouldRender) {
      setIsEntering(false);
    }
  }, [visible, shouldRender]);

  const handleTransitionEnd = (e: React.TransitionEvent<HTMLDivElement>) => {
    if (e.target !== e.currentTarget) return;
    if (!isEntering) {
      setShouldRender(false);
    }
  };

  if (!shouldRender) return null;

  return (
    <div
      onTransitionEnd={handleTransitionEnd}
      className={cn(
        "fixed inset-0 z-[65] bg-white flex flex-col",
        "transition-transform duration-300 ease-[cubic-bezier(0.25,0.1,0.25,1)]",
        isEntering ? "translate-x-0" : "translate-x-full"
      )}
    >
      {/* 顶部栏 - 复用通用样式，无分割线 */}
      <div className="flex-shrink-0 flex items-center px-4 pt-[max(0.75rem,env(safe-area-inset-top))] pb-3 bg-white z-10">
        {closeMode ? (
          <>
            <h1 className="flex-1 text-lg font-medium text-gray-900">应用栏管理</h1>
            <button
              onClick={onClose}
              className="p-1 -mr-1 text-gray-700 hover:text-gray-900 transition-colors"
              aria-label="关闭"
            >
              <X className="w-6 h-6" strokeWidth={1.8} />
            </button>
          </>
        ) : (
          <>
            <button
              onClick={onClose}
              className="p-1 -ml-1 text-gray-700 hover:text-gray-900 transition-colors"
            >
              <ArrowLeft className="w-6 h-6" strokeWidth={1.8} />
            </button>
            <h1 className="ml-3 text-lg font-medium text-gray-900">应用栏管理</h1>
          </>
        )}
      </div>

      {/* 内容区 - 无分割线 */}
      <div className="flex-1 overflow-y-auto bg-white">
        <p className="text-xs text-gray-400 mt-2 mb-2 px-4">
          开启后，底部菜单栏会展示对应入口
        </p>

        <div className="bg-white">
          <div className="flex items-center justify-between px-4 py-4">
            <div className="flex items-center gap-3 min-w-0">
              <div className="w-11 h-11 rounded-xl bg-gradient-to-br from-pink-100 to-blue-100 flex items-center justify-center flex-shrink-0">
                <Music2 className="w-5 h-5 text-gray-700" strokeWidth={1.8} />
              </div>
              <div className="flex flex-col min-w-0">
                <span className="text-[15px] text-gray-900 font-medium">
                  情绪音乐馆
                </span>
                <span className="text-xs text-gray-400 mt-0.5">
                  在底部栏展示「悦音乐」入口
                </span>
              </div>
            </div>
            <button
              type="button"
              role="switch"
              aria-checked={showMusic}
              onClick={() => onToggleMusic(!showMusic)}
              className={cn(
                "relative w-[52px] h-[30px] rounded-full transition-colors duration-200 flex-shrink-0",
                showMusic ? "porten-bg-gradient" : "bg-gray-300"
              )}
            >
              <span
                className={cn(
                  "absolute top-[2px] left-[2px] w-[26px] h-[26px] bg-white rounded-full shadow transition-transform duration-200",
                  showMusic && "translate-x-[22px]"
                )}
              />
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
