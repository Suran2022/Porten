import { useEffect, useState } from "react";
import { createPortal } from "react-dom";
import { useNavigate } from "react-router-dom";
import { Plus } from "lucide-react";
import { BackIcon } from "@/components/common/BackIcon";
import { cn } from "@/lib/utils";
import { useToastStore } from "@/store/toastStore";
import workplaceEmptyIcon from "@/assets/workplace-empty.svg";

/** 页面白底，状态栏同步为白色（与跨儿职场页一致）。 */
const PAGE_COLOR = "#FFFFFF";

/**
 * 创建约定独立页面（不包含底部导航栏）。
 * 顶部栏左侧返回图标、右侧"创建约定"胶囊按钮（浅粉不饱和底、无阴影）；
 * 主内容区为两个分区：「管理我的约定」与「和同胞的记忆归档」，
 * 均以胶囊粗竖条 + 标题开头，当前暂无数据，展示空状态引导文案
 * （空状态图标复用跨儿职场页面的插画）。
 */
export default function AgreementPage() {
  const navigate = useNavigate();
  const showToast = useToastStore((state) => state.show);

  // 进入/退出交互：与全站页面统一的右侧滑入/滑出（同跨儿职场页模式）
  const [entered, setEntered] = useState(false);
  const [leaving, setLeaving] = useState(false);

  useEffect(() => {
    const raf = requestAnimationFrame(() => {
      requestAnimationFrame(() => setEntered(true));
    });
    return () => cancelAnimationFrame(raf);
  }, []);

  // 状态栏着色为白色（与跨儿职场页同模式）：
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
          供 iOS Safari 26 采样着色（与跨儿职场页已验证实现一致）。
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
        {/* 顶部栏：左对齐返回图标 + 右对齐"创建约定"胶囊按钮（浅粉不饱和底、无阴影） */}
        <div className="relative flex items-center justify-between px-4 pt-[max(0.75rem,env(safe-area-inset-top))] pb-3 flex-shrink-0">
          <button
            type="button"
            onClick={handleBack}
            className="w-10 h-10 flex items-center justify-center -ml-2"
            aria-label="返回"
          >
            <BackIcon className="w-7 h-7" />
          </button>
          <button
            type="button"
            onClick={() =>
              showToast("创建约定功能即将上线，敬请期待", "info", "center")
            }
            className="h-9 px-4 rounded-full flex items-center gap-1.5 bg-pink-100 transition-opacity active:opacity-80"
            aria-label="创建约定"
          >
            <Plus className="w-4 h-4 text-pink-500" strokeWidth={2} />
            <span className="text-sm font-medium text-pink-500">创建约定</span>
          </button>
        </div>

        {/* 主内容区：始终挂载滚动容器（空状态下同样支持滑动） */}
        <div className="flex-1 min-h-0 overflow-y-auto scrollbar-hide overscroll-contain">
          <div className="px-4 pt-3">
            {/* 第一分区：粉色胶囊粗竖条 + 标题（竖条样式与行程卡片标题行一致） */}
            <div className="flex items-center gap-2.5">
              <span className="flex-shrink-0 w-1.5 h-5 rounded-full bg-pink-500" />
              <h2 className="text-lg font-semibold text-gray-900">
                管理我的约定
              </h2>
            </div>
            {/* 空状态：复用跨儿职场页插画 + 引导文案 */}
            <div className="mt-8 flex flex-col items-center">
              <img
                src={workplaceEmptyIcon}
                alt=""
                className="w-28 h-28"
              />
              <p className="mt-4 text-sm text-gray-400 text-center">
                还没有和同胞有过约定哟
              </p>
            </div>

            {/* 第二分区：蓝色胶囊粗竖条 + 标题 */}
            <div className="mt-10 flex items-center gap-2.5">
              <span className="flex-shrink-0 w-1.5 h-5 rounded-full bg-blue-500" />
              <h2 className="text-lg font-semibold text-gray-900">
                和同胞的记忆归档
              </h2>
            </div>
            {/* 空状态：复用跨儿职场页插画 + 引导文案 */}
            <div className="mt-8 flex flex-col items-center">
              <img
                src={workplaceEmptyIcon}
                alt=""
                className="w-28 h-28"
              />
              <p className="mt-4 text-sm text-gray-400 text-center">
                还没有约定的记忆归档哟
              </p>
            </div>
          </div>
          {/* 底部滚动余量：内容不足一屏时也保留可滑动距离 */}
          <div className="h-24" aria-hidden />
        </div>
      </div>
    </>
  );
}
