import {
  useCallback,
  useEffect,
  useLayoutEffect,
  useRef,
  useState,
} from "react";
import { useToastStore } from "@/store/toastStore";

/** 下拉刷新阶段：静默 → 跟手下拉 → 刷新中（提示条保持显示）→ 完成复位 */
export type PullPhase = "idle" | "pulling" | "refreshing" | "done";

/** 提示条文案状态：下拉刷新 / 松开刷新 / 刷新中 */
export type PullLabel = "pull" | "release" | "refreshing";

interface UsePullToRefreshOptions {
  onRefresh: () => Promise<void> | void;
  /** 触发刷新的下拉阈值（px） */
  threshold?: number;
  /** 跟手最大位移（px），超出后进入阻尼区间 */
  maxPull?: number;
  /** 提示条高度（px），也是刷新中主内容整体下移的距离 */
  indicatorHeight?: number;
  /** 刷新动效最短展示时长（ms），避免数据过快导致动画闪跳 */
  minDuration?: number;
  /** 外部持有的滚动容器 ref（如 LearnView 的视频可见性计算），与内部 ref 合并 */
  scrollRef?: { current: HTMLDivElement | null };
  /** 是否启用手势监听 */
  enabled?: boolean;
  /**
   * 提示条顶部基准偏移（px）：顶部有吸附式分类栏时让位其高度（学习列表 = 48）。
   * 提示内容将垂直居中于"分类栏底 ~ 主内容顶"之间的露出区域，上下间距对称。
   */
  indicatorOffset?: number;
  /** 滚动容器的顶部内边距（px）：学习列表为分类栏让位的 pt-14（56），其他页面为 0 */
  contentPaddingTop?: number;
}

/** 松手后的过渡曲线：快速启动 + 柔和落定，接近原生 App 手感 */
const SNAP_EASING = "transform 320ms cubic-bezier(0.32, 0.72, 0, 1)";
/** 提示条过渡：位移与透明度一起平滑过渡 */
const INDICATOR_SNAP_EASING =
  "transform 320ms cubic-bezier(0.32, 0.72, 0, 1), opacity 320ms ease";
const RESET_MS = 340;

export function usePullToRefresh(options: UsePullToRefreshOptions) {
  const {
    onRefresh,
    threshold = 70,
    maxPull = 150,
    indicatorHeight = 56,
    minDuration = 600,
    scrollRef: outerScrollRef,
    enabled = true,
    indicatorOffset = 0,
    contentPaddingTop = 0,
  } = options;

  const [phase, setPhase] = useState<PullPhase>("idle");
  const [label, setLabel] = useState<PullLabel>("pull");

  const phaseRef = useRef<PullPhase>("idle");
  const indicatorElRef = useRef<HTMLDivElement | null>(null);
  const scrollElRef = useRef<HTMLDivElement | null>(null);

  const startYRef = useRef(0);
  const startXRef = useRef(0);
  const startScrollTopRef = useRef(0);
  /** 当前手势类型：touch（移动端）| mouse（桌面拖拽演示） */
  const gestureTypeRef = useRef<"touch" | "mouse" | null>(null);
  /** 本次手势是否产生了实际下拉位移（用于拦截手势后的误触 click） */
  const gestureMovedRef = useRef(false);
  /** 最近一次手势结束时间戳（ms），之后的短暂 click 一律拦截 */
  const lastGestureEndRef = useRef(0);
  const offsetRef = useRef(0);
  const rafRef = useRef<number | null>(null);
  /** 刷新流程代数：防止快速重复触发时旧流程污染状态 */
  const refreshIdRef = useRef(0);

  const setPhaseBoth = useCallback((next: PullPhase) => {
    phaseRef.current = next;
    setPhase(next);
  }, []);

  /** 跟手位移曲线：阈值内 1:1 跟手，超出后阻尼递减，顶部反馈自然 */
  const rubber = useCallback(
    (raw: number) => {
      if (raw <= threshold) return raw;
      const extra = raw - threshold;
      return Math.min(maxPull, threshold + extra * 0.25);
    },
    [threshold, maxPull]
  );

  /**
   * 直接写 DOM transform / opacity（合成层属性，不触发重排/React 渲染），
   * 这是下拉全程保持 60fps 流畅的关键。
   *
   * 提示内容始终垂直居中于"下拉露出的可视区域"（顶部栏底 ~ 主内容顶），
   * 使其到顶部栏与到主内容的间距恒等，不会一宽一窄：
   *   露出高度 visibleH = contentPaddingTop + offset - indicatorOffset
   *   内容中心 y        = indicatorOffset + visibleH / 2
   */
  const applyOffset = useCallback(
    (offset: number, withTransition: boolean) => {
      const indicator = indicatorElRef.current;
      const scroll = scrollElRef.current;
      if (!indicator || !scroll) return;
      const indicatorTransition = withTransition ? INDICATOR_SNAP_EASING : "none";
      const scrollTransition = withTransition ? SNAP_EASING : "none";
      indicator.style.transition = indicatorTransition;
      scroll.style.transition = scrollTransition;
      const visibleHeight = Math.max(0, contentPaddingTop + offset - indicatorOffset);
      const centerY = indicatorOffset + visibleHeight / 2 - indicatorHeight / 2;
      indicator.style.transform = `translateY(${centerY}px)`;
      // 静默态完全隐藏，下拉过程中随露出高度渐显
      indicator.style.opacity = String(Math.max(0, Math.min(1, offset / 48)));
      scroll.style.transform = `translateY(${offset}px)`;
    },
    [contentPaddingTop, indicatorHeight, indicatorOffset]
  );

  const cancelScheduled = useCallback(() => {
    if (rafRef.current !== null) {
      cancelAnimationFrame(rafRef.current);
      rafRef.current = null;
    }
  }, []);

  /** rAF 合帧写 transform：一次触摸移动至多一次样式写入 */
  const scheduleOffset = useCallback(
    (rawOffset: number) => {
      if (rafRef.current !== null) return;
      rafRef.current = requestAnimationFrame(() => {
        rafRef.current = null;
        offsetRef.current = rawOffset;
        applyOffset(rawOffset, false);
      });
    },
    [applyOffset]
  );

  const resetGesture = useCallback(() => {
    if (gestureTypeRef.current) {
      lastGestureEndRef.current = Date.now();
    }
    gestureTypeRef.current = null;
    document.body.style.userSelect = "";
  }, []);

  /** 刷新中 → 完成：正中间提示"刷新成功"，随后动画复位并隐藏提示条 */
  const startRefresh = useCallback(async () => {
    const refreshId = ++refreshIdRef.current;
    cancelScheduled();
    offsetRef.current = indicatorHeight;
    setPhaseBoth("refreshing");
    setLabel("refreshing");
    applyOffset(indicatorHeight, true);

    const minShowDelay = new Promise((resolve) => setTimeout(resolve, minDuration));
    try {
      await Promise.all([Promise.resolve(onRefresh()), minShowDelay]);
    } catch {
      // 刷新失败也照常复位，不阻塞交互
    }
    if (refreshIdRef.current !== refreshId) return;

    useToastStore.getState().show("刷新成功", "success", "center");

    // 复位：提示条上滑隐藏、主内容回落，动画结束后回到静默态
    setPhaseBoth("done");
    applyOffset(0, true);
    offsetRef.current = 0;
    setTimeout(() => {
      if (refreshIdRef.current !== refreshId) return;
      setPhaseBoth("idle");
      setLabel("pull");
    }, RESET_MS);
  }, [
    applyOffset,
    cancelScheduled,
    indicatorHeight,
    minDuration,
    onRefresh,
    setPhaseBoth,
  ]);

  /** 松手：达到阈值进入刷新，否则回弹复位 */
  const finishGesture = useCallback(() => {
    cancelScheduled();
    const offset = offsetRef.current;
    if (offset >= threshold) {
      void startRefresh();
    } else {
      setPhaseBoth("idle");
      setLabel("pull");
      applyOffset(0, true);
      offsetRef.current = 0;
    }
    resetGesture();
  }, [applyOffset, cancelScheduled, resetGesture, setPhaseBoth, startRefresh, threshold]);

  /** 退出下拉态（未松手就拖回顶部/向上）时回弹 */
  const cancelGesture = useCallback(() => {
    cancelScheduled();
    setPhaseBoth("idle");
    setLabel("pull");
    applyOffset(0, true);
    offsetRef.current = 0;
    resetGesture();
  }, [applyOffset, cancelScheduled, resetGesture, setPhaseBoth]);

  // 首帧绘制前把提示条定位到容器上方（完全隐藏），避免闪烁
  useLayoutEffect(() => {
    applyOffset(0, false);
  }, [applyOffset]);

  useEffect(() => {
    const scrollEl = scrollElRef.current;
    if (!scrollEl || !enabled) return;

    // ---------- 触摸（移动端 / 模拟器）：passive 监听，不阻塞原生滚动 ----------
    const onTouchStart = (e: TouchEvent) => {
      if (phaseRef.current !== "idle" || e.touches.length !== 1) return;
      startYRef.current = e.touches[0].clientY;
      startXRef.current = e.touches[0].clientX;
      startScrollTopRef.current = scrollEl.scrollTop;
      gestureMovedRef.current = false;
      gestureTypeRef.current = "touch";
    };

    const onTouchMove = (e: TouchEvent) => {
      if (gestureTypeRef.current !== "touch") return;
      if (phaseRef.current === "refreshing" || phaseRef.current === "done") return;

      const dy = e.touches[0].clientY - startYRef.current;
      const dx = e.touches[0].clientX - startXRef.current;

      if (phaseRef.current !== "pulling") {
        // 未进入下拉态：仅在列表位于顶部且为纯垂直向下拖时启动
        if (startScrollTopRef.current > 0 || scrollEl.scrollTop > 0) return;
        if (dy <= 8 || dy <= Math.abs(dx)) return;
        gestureMovedRef.current = true;
        setPhaseBoth("pulling");
      }

      // 已处于下拉态：拖回顶部以上则取消并回弹
      if (dy <= 0 || scrollEl.scrollTop > 0) {
        cancelGesture();
        return;
      }
      scheduleOffset(rubber(dy));
      const nextLabel: PullLabel = offsetRef.current >= threshold || rubber(dy) >= threshold ? "release" : "pull";
      setLabel((prev) => (prev === nextLabel ? prev : nextLabel));
    };

    const onTouchEnd = () => {
      if (gestureTypeRef.current !== "touch") return;
      if (phaseRef.current === "pulling") {
        finishGesture();
      } else {
        resetGesture();
      }
    };

    // ---------- 鼠标拖拽（桌面演示）：非 passive，可阻止文本选中与图片/视频原生拖拽 ----------
    const onPointerDown = (e: PointerEvent) => {
      if (e.pointerType !== "mouse" || e.button !== 0) return;
      if (phaseRef.current !== "idle" || scrollEl.scrollTop > 0) return;
      // 阻止在图片/视频上按下时的原生拖拽与文本选中，避免劫持下拉手势
      e.preventDefault();
      startYRef.current = e.clientY;
      startXRef.current = e.clientX;
      startScrollTopRef.current = scrollEl.scrollTop;
      gestureMovedRef.current = false;
      gestureTypeRef.current = "mouse";
    };

    const onPointerMove = (e: PointerEvent) => {
      if (gestureTypeRef.current !== "mouse") return;
      if (phaseRef.current === "refreshing" || phaseRef.current === "done") return;

      const dy = e.clientY - startYRef.current;
      const dx = e.clientX - startXRef.current;

      if (phaseRef.current !== "pulling") {
        if (dy <= 8 || dy <= Math.abs(dx)) return;
        e.preventDefault();
        document.body.style.userSelect = "none";
        gestureMovedRef.current = true;
        setPhaseBoth("pulling");
      } else {
        e.preventDefault();
      }

      if (dy <= 0) {
        cancelGesture();
        return;
      }
      scheduleOffset(rubber(dy));
      const nextLabel: PullLabel = rubber(dy) >= threshold ? "release" : "pull";
      setLabel((prev) => (prev === nextLabel ? prev : nextLabel));
    };

    const onPointerUp = () => {
      if (gestureTypeRef.current !== "mouse") return;
      if (phaseRef.current === "pulling") {
        finishGesture();
      } else {
        resetGesture();
      }
    };

    // 拖拽手势结束后的短暂窗口内拦截 click，避免误触列表项（如打开聊天页）
    const onClickCapture = (e: MouseEvent) => {
      if (
        gestureMovedRef.current &&
        Date.now() - lastGestureEndRef.current < 350
      ) {
        e.preventDefault();
        e.stopPropagation();
      }
    };

    scrollEl.addEventListener("touchstart", onTouchStart, { passive: true });
    scrollEl.addEventListener("touchmove", onTouchMove, { passive: true });
    scrollEl.addEventListener("touchend", onTouchEnd, { passive: true });
    scrollEl.addEventListener("touchcancel", onTouchEnd, { passive: true });
    scrollEl.addEventListener("pointerdown", onPointerDown);
    scrollEl.addEventListener("pointermove", onPointerMove);
    scrollEl.addEventListener("pointerup", onPointerUp);
    scrollEl.addEventListener("pointercancel", onPointerUp);
    scrollEl.addEventListener("click", onClickCapture, { capture: true });

    return () => {
      scrollEl.removeEventListener("touchstart", onTouchStart);
      scrollEl.removeEventListener("touchmove", onTouchMove);
      scrollEl.removeEventListener("touchend", onTouchEnd);
      scrollEl.removeEventListener("touchcancel", onTouchEnd);
      scrollEl.removeEventListener("pointerdown", onPointerDown);
      scrollEl.removeEventListener("pointermove", onPointerMove);
      scrollEl.removeEventListener("pointerup", onPointerUp);
      scrollEl.removeEventListener("pointercancel", onPointerUp);
      scrollEl.removeEventListener("click", onClickCapture, { capture: true });
    };
  }, [
    enabled,
    rubber,
    scheduleOffset,
    threshold,
    finishGesture,
    cancelGesture,
    resetGesture,
    setPhaseBoth,
  ]);

  /** 指示条节点 ref：挂到提示条元素 */
  const indicatorRef = useCallback((el: HTMLDivElement | null) => {
    indicatorElRef.current = el;
  }, []);

  /** 滚动容器节点 ref：与外部 ref 合并（hook 挂事件 + 外部业务 ref） */
  const scrollRef = useCallback(
    (el: HTMLDivElement | null) => {
      scrollElRef.current = el;
      if (outerScrollRef) outerScrollRef.current = el;
    },
    [outerScrollRef]
  );

  return { phase, label, indicatorRef, scrollRef };
}
