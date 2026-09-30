import { ReactNode, UIEvent } from "react";
import { ArrowDown } from "lucide-react";
import { cn } from "@/lib/utils";
import { usePullToRefresh } from "@/hooks/usePullToRefresh";

interface PullToRefreshProps {
  onRefresh: () => Promise<void> | void;
  /** 列表内容（不含滚动容器，滚动容器由本组件渲染） */
  children: ReactNode;
  /** 滚动容器附加类名（如学习列表的 padding-top 过渡） */
  scrollClassName?: string;
  /** 滚动事件透传（学习列表用于视频可见性计算与分类栏吸附） */
  onScroll?: (event: UIEvent<HTMLDivElement>) => void;
  /** 外部滚动容器 ref（与内部合并） */
  scrollRef?: { current: HTMLDivElement | null };
  /**
   * 提示条顶部基准偏移（px）：顶部有吸附式分类栏时让位其高度。
   * 提示内容居中于"基准线 ~ 主内容顶"之间，到上下的间距恒等。
   */
  indicatorOffset?: number;
  /** 滚动容器顶部内边距（px）：学习列表 pt-14 = 56，用于间距对称计算 */
  contentPaddingTop?: number;
  /** 刷新中文案覆盖 */
  refreshingText?: string;
}

/** 提示条高度（px），与文本行高一致；刷新中主内容整体下移该距离 */
const INDICATOR_HEIGHT = 56;

/**
 * 通用下拉刷新区域。
 *
 * 结构：外层裁剪容器（relative + overflow-hidden）
 *   ├─ 提示条（absolute 顶部透明浮层，内容垂直居中于下拉露出的可视区域，
 *   │        到顶部栏与到主内容的间距恒等；pointer-events-none 不挡交互）
 *   └─ 滚动容器（下拉/刷新中整体下移，露出顶部空白区域）
 *
 * 动效实现：跟手位移与阶段切换全部通过 transform/opacity 直写 DOM（合成层属性），
 * React 仅在阶段/文案变化时重渲，保证下拉全程流畅不卡顿。
 */
export function PullToRefresh({
  onRefresh,
  children,
  scrollClassName,
  onScroll,
  scrollRef: outerScrollRef,
  indicatorOffset = 0,
  contentPaddingTop = 0,
  refreshingText = "刷新中",
}: PullToRefreshProps) {
  const { phase, label, indicatorRef, scrollRef } = usePullToRefresh({
    onRefresh,
    scrollRef: outerScrollRef,
    indicatorHeight: INDICATOR_HEIGHT,
    indicatorOffset,
    contentPaddingTop,
  });

  const refreshing = phase === "refreshing" || phase === "done";

  return (
    <div className="relative h-full overflow-hidden">
      {/* 提示条：位于顶部栏与主内容之间，刷新中持续显示，完成后动画收起隐藏 */}
      <div
        ref={indicatorRef}
        style={{
          top: 0,
          height: INDICATOR_HEIGHT,
          willChange: "transform, opacity",
        }}
        className="pointer-events-none absolute inset-x-0 z-30 flex items-center justify-center gap-2"
      >
        {refreshing ? (
          // 刷新中：三圆点轮转动效（实现见 index.css 的 .ptr-loader）
          <span className="ptr-loader" aria-hidden />
        ) : (
          <ArrowDown
            className="h-5 w-5 text-gray-400 transition-transform duration-300"
            style={{ transform: `rotate(${label === "release" ? 180 : 0}deg)` }}
          />
        )}
        <span className="select-none text-sm leading-5 text-gray-400">
          {refreshing
            ? refreshingText
            : label === "release"
              ? "松开刷新"
              : "下拉刷新"}
        </span>
      </div>

      {/* 主内容：下拉/刷新中下移露出顶部空白，其余时间 transform 为 0 */}
      <div
        ref={scrollRef}
        onScroll={onScroll}
        style={{ willChange: "transform" }}
        className={cn("h-full overflow-y-auto scrollbar-hide", scrollClassName)}
      >
        {children}
      </div>
    </div>
  );
}
