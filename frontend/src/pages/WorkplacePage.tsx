import { useEffect, useState } from "react";
import { createPortal } from "react-dom";
import { useNavigate } from "react-router-dom";
import { Plus } from "lucide-react";
import { BackIcon } from "@/components/common/BackIcon";
import { cn } from "@/lib/utils";
import { useToastStore } from "@/store/toastStore";
import workplaceEmptyIcon from "@/assets/workplace-empty.svg";

/** 页面白底，状态栏同步为白色（与我的日程页一致）。 */
const PAGE_COLOR = "#FFFFFF";

/**
 * 跨儿职场独立页面（不包含底部导航栏）。
 * 顶部栏返回 + 居中"我的工作"；主内容区始终可滑动，
 * 空状态下居中显示职场插画与引导文案；
 * 右下角淡蓝色胶囊按钮为"添加工作"入口（页面暂未实现，点击给出提示）。
 */
export default function WorkplacePage() {
  const navigate = useNavigate();
  const showToast = useToastStore((state) => state.show);

  // 进入/退出交互：与全站页面统一的右侧滑入/滑出（同我的日程页模式）
  const [entered, setEntered] = useState(false);
  const [leaving, setLeaving] = useState(false);

  useEffect(() => {
    const raf = requestAnimationFrame(() => {
      requestAnimationFrame(() => setEntered(true));
    });
    return () => cancelAnimationFrame(raf);
  }, []);

  // 状态栏着色为白色（与我的日程页同模式）：
  // iOS Safari 15~18 / 安卓 Chrome 用 theme-color（移除旧节点重建以触发重绘）；
  // Safari 26 起由下方 createPortal 的取色源色块着色。
  useEffect(() => {
    const head = document.head;
    const existing = head.querySelector<HTMLMetaElement>(
      'meta[name="theme-color"]'
    );
    const previousContent = existing?.getAttribute("content") ?? null;
    existing?.remove();

    const meta = document.createElement("meta");
    meta.setAttribute("name", "theme-color");
    meta.setAttribute("content", PAGE_COLOR);
    head.appendChild(meta);

    return () => {
      meta.remove();
      if (existing) {
        if (previousContent !== null) {
          existing.setAttribute("content", previousContent);
        }
        head.appendChild(existing);
      }
    };
  }, []);

  const handleBack = () => {
    if (!leaving) setLeaving(true);
  };

  const handleTransitionEnd = () => {
    // 仅在滑出结束时卸载路由（滑入结束也会触发 transitionend，需守卫）
    if (leaving) navigate(-1);
  };

  return (
    <>
      {/* 状态栏取色源色块：portal 到 body 下、z-[1000] 成为视觉最顶层，
          供 iOS Safari 26 采样着色（与我的日程页已验证实现一致）。
          白色与页面白底一致，视觉上完全不可见。 */}
      {createPortal(
        <div
          className="fixed top-0 left-0 right-0 z-[1000] pointer-events-none"
          style={{
            height: "max(env(safe-area-inset-top, 0px), 15px)",
            backgroundColor: PAGE_COLOR,
          }}
        />,
        document.body
      )}

      <div
        className={cn(
          "fixed inset-0 z-[60] flex flex-col overflow-hidden bg-white transition-transform duration-300 ease-[cubic-bezier(0.25,0.1,0.25,1)]",
          entered && !leaving ? "translate-x-0" : "translate-x-full"
        )}
        onTransitionEnd={handleTransitionEnd}
      >
        {/* 顶部栏：返回图标 + 居中"我的工作" */}
        <div className="relative flex items-center justify-between px-4 pt-[max(0.75rem,env(safe-area-inset-top))] pb-3 flex-shrink-0">
          <button
            type="button"
            onClick={handleBack}
            className="w-10 h-10 flex items-center justify-center -ml-2"
            aria-label="返回"
          >
            <BackIcon className="w-7 h-7" />
          </button>
          <h1 className="text-lg font-medium text-gray-900">我的工作</h1>
          <div className="w-8" />
        </div>

        {/* 主内容区：始终挂载滚动容器（空状态下同样支持滑动） */}
        <div className="flex-1 min-h-0 overflow-y-auto scrollbar-hide overscroll-contain">
          {/* 空状态：职场插画 + 引导文案（撑满可视区垂直居中） */}
          <div className="min-h-full flex flex-col items-center justify-center px-8">
            <img
              src={workplaceEmptyIcon}
              alt=""
              className="w-36 h-36"
            />
            <p className="mt-4 text-sm text-gray-400 text-center">
              还没有工作哟，去添加现在的工作趴！
            </p>
          </div>
          {/* 底部滚动余量：内容不足一屏时也保留可滑动距离，并为悬浮按钮留出空间 */}
          <div className="h-24" aria-hidden />
        </div>

        {/* 底部右对齐：淡蓝色胶囊"添加工作"按钮
            （absolute 相对页面容器固定悬浮，不随内容区滚动；页面暂未实现，点击提示） */}
        <button
          type="button"
          onClick={() =>
            showToast("添加工作功能即将上线，敬请期待", "info", "center")
          }
          className="absolute right-5 bottom-6 z-[65] h-11 px-5 rounded-full flex items-center gap-1.5 bg-blue-100 transition-opacity active:opacity-80"
          aria-label="添加工作"
        >
          <Plus className="w-5 h-5 text-blue-500" strokeWidth={2} />
          <span className="text-sm font-medium text-blue-500">添加工作</span>
        </button>
      </div>
    </>
  );
}
