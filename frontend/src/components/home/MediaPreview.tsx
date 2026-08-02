import { useCallback, useEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";
import { X, Pause, Loader2 } from "lucide-react";
import { cn } from "@/lib/utils";

/** 圆角实心播放图标（三角形顶点圆角处理） */
function RoundedPlayIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 24 24" className={className} fill="currentColor">
      <path
        d="M7 5.5C7 5.2 7.35 5 7.65 5.2L18 11.6C18.3 11.8 18.3 12.2 18 12.4L7.65 18.8C7.35 19 7 18.8 7 18.5V5.5Z"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinejoin="round"
        fill="currentColor"
      />
    </svg>
  );
}

export interface MediaOriginRect {
  left: number;
  top: number;
  width: number;
  height: number;
}

interface MediaPreviewProps {
  visible: boolean;
  type: "image" | "video";
  url: string;
  poster?: string;
  // 缩略图位置，用于打开/关闭动画的起止点
  originRect: MediaOriginRect | null;
  onClose: () => void;
}

/**
 * 聊天图片/视频预览。
 * - 打开：从缩略图位置放大到全屏居中
 * - 关闭：从全屏缩小回缩略图位置
 * - 图片支持双指缩放与拖动
 * - 视频底部进度条（参考悦音乐）+ 大圆角播放按钮，单击继续/双击暂停
 */
export function MediaPreview({
  visible,
  type,
  url,
  poster,
  originRect,
  onClose,
}: MediaPreviewProps) {
  if (type === "image") {
    return (
      <ImagePreview
        visible={visible}
        url={url}
        originRect={originRect}
        onClose={onClose}
      />
    );
  }
  return (
    <VideoPreview
      visible={visible}
      url={url}
      poster={poster}
      originRect={originRect}
      onClose={onClose}
    />
  );
}

/* ============================ 图片预览 ============================ */

function ImagePreview({
  visible,
  url,
  originRect,
  onClose,
}: {
  visible: boolean;
  url: string;
  originRect: MediaOriginRect | null;
  onClose: () => void;
}) {
  const imgRef = useRef<HTMLImageElement>(null);
  const [loaded, setLoaded] = useState(false);
  // entering=true 表示处于"已展开"状态；false 表示处于"缩回 originRect"状态
  const [entering, setEntering] = useState(false);
  // 初始 transform（从 originRect 位置开始）
  const [startTransform, setStartTransform] = useState<string>("");
  const [closing, setClosing] = useState(false);

  // 缩放与平移
  const [scale, setScale] = useState(1);
  const [translate, setTranslate] = useState({ x: 0, y: 0 });
  const pinchStart = useRef<{ dist: number; scale: number } | null>(null);
  const dragStart = useRef<{ x: number; y: number; tx: number; ty: number } | null>(null);

  // 计算从 originRect 到最终居中位置的初始 transform
  const computeStartTransform = useCallback(() => {
    if (!originRect || !imgRef.current) return "";
    const finalRect = imgRef.current.getBoundingClientRect();
    if (!finalRect.width || !finalRect.height) return "";
    const dx =
      originRect.left +
      originRect.width / 2 -
      (finalRect.left + finalRect.width / 2);
    const dy =
      originRect.top +
      originRect.height / 2 -
      (finalRect.top + finalRect.height / 2);
    const sx = originRect.width / finalRect.width;
    const sy = originRect.height / finalRect.height;
    return `translate(${dx}px, ${dy}px) scale(${sx}, ${sy})`;
  }, [originRect]);

  // 图片加载完成后启动进入动画
  useEffect(() => {
    if (!visible || !loaded) return;
    // 先设置初始位置（无过渡）
    const t = computeStartTransform();
    setStartTransform(t);
    setEntering(false);
    setClosing(false);
    // 下一帧切换到展开状态，触发过渡
    requestAnimationFrame(() => {
      requestAnimationFrame(() => setEntering(true));
    });
  }, [visible, loaded, computeStartTransform]);

  // 重置缩放
  useEffect(() => {
    if (visible) {
      setScale(1);
      setTranslate({ x: 0, y: 0 });
      setLoaded(false);
    }
  }, [visible, url]);

  // 关闭动画：先缩回 originRect，过渡结束后回调 onClose
  const handleClose = useCallback(() => {
    if (closing) return;
    const t = computeStartTransform();
    setStartTransform(t);
    setClosing(true);
    setEntering(false);
  }, [closing, computeStartTransform]);

  const handleTransitionEnd = () => {
    if (closing) {
      setClosing(false);
      onClose();
    }
  };

  // 双指缩放
  const handleTouchStart = (e: React.TouchEvent) => {
    if (e.touches.length === 2) {
      const dx = e.touches[0].clientX - e.touches[1].clientX;
      const dy = e.touches[0].clientY - e.touches[1].clientY;
      pinchStart.current = { dist: Math.hypot(dx, dy), scale };
      // 缩放时停止拖动
      dragStart.current = null;
    } else if (e.touches.length === 1 && scale > 1) {
      dragStart.current = {
        x: e.touches[0].clientX,
        y: e.touches[0].clientY,
        tx: translate.x,
        ty: translate.y,
      };
    }
  };

  const handleTouchMove = (e: React.TouchEvent) => {
    if (e.touches.length === 2 && pinchStart.current) {
      // 阻止浏览器默认的双指缩放整个页面
      e.preventDefault();
      e.stopPropagation();
      const dx = e.touches[0].clientX - e.touches[1].clientX;
      const dy = e.touches[0].clientY - e.touches[1].clientY;
      const dist = Math.hypot(dx, dy);
      const ratio = dist / pinchStart.current.dist;
      const next = Math.max(1, Math.min(4, pinchStart.current.scale * ratio));
      setScale(next);
      if (next === 1) setTranslate({ x: 0, y: 0 });
    } else if (
      e.touches.length === 1 &&
      dragStart.current &&
      scale > 1
    ) {
      // 拖动图片时也阻止页面滚动
      e.preventDefault();
      e.stopPropagation();
      const dx = e.touches[0].clientX - dragStart.current.x;
      const dy = e.touches[0].clientY - dragStart.current.y;
      setTranslate({ x: dragStart.current.tx + dx, y: dragStart.current.ty + dy });
    }
  };

  const handleTouchEnd = (e: React.TouchEvent) => {
    if (e.touches.length === 0) {
      pinchStart.current = null;
      dragStart.current = null;
    }
  };

  if (!visible) return null;

  return createPortal(
    <div
      className={cn(
        "fixed inset-0 z-[200] bg-black/90 transition-opacity duration-300",
        entering ? "opacity-100" : "opacity-0"
      )}
    >
      {/* 加载圆：图片未加载时屏幕正中显示 */}
      {!loaded && (
        <div className="absolute inset-0 flex items-center justify-center">
          <Loader2 className="w-10 h-10 text-white/80 animate-spin" strokeWidth={1.5} />
        </div>
      )}

      {/* 图片：全屏占满预览区，按原比例 contain（横屏图宽撑满，竖屏图高撑满） */}
      <div className="absolute inset-0 flex items-center justify-center overflow-hidden">
        <div
          style={{
            transform: entering ? "none" : startTransform,
            transition: closing
              ? "transform 280ms ease-in"
              : "transform 280ms cubic-bezier(0.25,0.1,0.25,1)",
          }}
          onTransitionEnd={handleTransitionEnd}
          className="w-screen h-screen flex items-center justify-center"
        >
          <div
            style={{
              transform: `translate(${translate.x}px, ${translate.y}px) scale(${scale})`,
              transition: "transform 120ms ease-out",
              touchAction: "none",
            }}
            onTouchStart={handleTouchStart}
            onTouchMove={handleTouchMove}
            onTouchEnd={handleTouchEnd}
            className="w-full h-full flex items-center justify-center"
          >
            <img
              ref={imgRef}
              src={url}
              alt="预览"
              onLoad={() => setLoaded(true)}
              className="w-full h-full object-contain select-none"
              draggable={false}
            />
          </div>
        </div>
      </div>

      {/* 右上角叉叉 */}
      <button
        type="button"
        onClick={handleClose}
        className={cn(
          "absolute top-[max(1rem,env(safe-area-inset-top))] right-4 w-10 h-10 rounded-full bg-white/15 backdrop-blur-sm flex items-center justify-center transition-opacity",
          entering ? "opacity-100" : "opacity-0"
        )}
        aria-label="关闭"
      >
        <X className="w-5 h-5 text-white" strokeWidth={2} />
      </button>
    </div>,
    document.body
  );
}

/* ============================ 视频预览 ============================ */

function formatTime(sec: number): string {
  if (!sec || isNaN(sec)) return "0:00";
  const m = Math.floor(sec / 60);
  const s = Math.floor(sec % 60);
  return `${m}:${s.toString().padStart(2, "0")}`;
}

function VideoPreview({
  visible,
  url,
  poster,
  originRect,
  onClose,
}: {
  visible: boolean;
  url: string;
  poster?: string;
  originRect: MediaOriginRect | null;
  onClose: () => void;
}) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const wrapRef = useRef<HTMLDivElement>(null);
  const [loaded, setLoaded] = useState(false);
  const [entering, setEntering] = useState(false);
  const [startTransform, setStartTransform] = useState<string>("");
  const [closing, setClosing] = useState(false);

  const [isPlaying, setIsPlaying] = useState(false);
  const [showCenterIcon, setShowCenterIcon] = useState(true);
  const [centerIconType, setCenterIconType] = useState<"play" | "pause">("play");
  const [waiting, setWaiting] = useState(false);
  const [progress, setProgress] = useState(0); // 0-1
  const [duration, setDuration] = useState(0);
  const [currentTime, setCurrentTime] = useState(0);
  const [draggingProgress, setDraggingProgress] = useState<number | null>(null);
  const progressBarRef = useRef<HTMLDivElement>(null);
  const hideIconTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const clickTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  // 视频双指缩放（只缩放视频，不影响整个页面）
  const [videoScale, setVideoScale] = useState(1);
  const [videoTranslate, setVideoTranslate] = useState({ x: 0, y: 0 });
  const pinchStart = useRef<{ dist: number; scale: number } | null>(null);
  const dragStart = useRef<{ x: number; y: number; tx: number; ty: number } | null>(null);

  const handleVideoTouchStart = (e: React.TouchEvent) => {
    if (e.touches.length === 2) {
      const dx = e.touches[0].clientX - e.touches[1].clientX;
      const dy = e.touches[0].clientY - e.touches[1].clientY;
      pinchStart.current = { dist: Math.hypot(dx, dy), scale: videoScale };
      dragStart.current = null;
    } else if (e.touches.length === 1 && videoScale > 1) {
      dragStart.current = {
        x: e.touches[0].clientX,
        y: e.touches[0].clientY,
        tx: videoTranslate.x,
        ty: videoTranslate.y,
      };
    }
  };

  const handleVideoTouchMove = (e: React.TouchEvent) => {
    if (e.touches.length === 2 && pinchStart.current) {
      e.preventDefault();
      e.stopPropagation();
      const dx = e.touches[0].clientX - e.touches[1].clientX;
      const dy = e.touches[0].clientY - e.touches[1].clientY;
      const dist = Math.hypot(dx, dy);
      const ratio = dist / pinchStart.current.dist;
      const next = Math.max(1, Math.min(4, pinchStart.current.scale * ratio));
      setVideoScale(next);
      if (next === 1) setVideoTranslate({ x: 0, y: 0 });
    } else if (
      e.touches.length === 1 &&
      dragStart.current &&
      videoScale > 1
    ) {
      e.preventDefault();
      e.stopPropagation();
      const dx = e.touches[0].clientX - dragStart.current.x;
      const dy = e.touches[0].clientY - dragStart.current.y;
      setVideoTranslate({
        x: dragStart.current.tx + dx,
        y: dragStart.current.ty + dy,
      });
    }
  };

  const handleVideoTouchEnd = (e: React.TouchEvent) => {
    if (e.touches.length === 0) {
      pinchStart.current = null;
      dragStart.current = null;
    }
  };

  const computeStartTransform = useCallback(() => {
    if (!originRect || !wrapRef.current) return "";
    const finalRect = wrapRef.current.getBoundingClientRect();
    if (!finalRect.width || !finalRect.height) return "";
    const dx =
      originRect.left +
      originRect.width / 2 -
      (finalRect.left + finalRect.width / 2);
    const dy =
      originRect.top +
      originRect.height / 2 -
      (finalRect.top + finalRect.height / 2);
    const sx = originRect.width / finalRect.width;
    const sy = originRect.height / finalRect.height;
    return `translate(${dx}px, ${dy}px) scale(${sx}, ${sy})`;
  }, [originRect]);

  useEffect(() => {
    if (!visible) return;
    setLoaded(false);
    setEntering(false);
    setClosing(false);
    setProgress(0);
    setCurrentTime(0);
    setDuration(0);
    setIsPlaying(false);
    setShowCenterIcon(true);
    setCenterIconType("play");
    // 重置视频缩放
    setVideoScale(1);
    setVideoTranslate({ x: 0, y: 0 });
    pinchStart.current = null;
    dragStart.current = null;
    // 等待视频元素挂载后测量并启动动画
    const t = setTimeout(() => {
      const tr = computeStartTransform();
      setStartTransform(tr);
      requestAnimationFrame(() => {
        requestAnimationFrame(() => setEntering(true));
      });
    }, 30);
    return () => clearTimeout(t);
  }, [visible, computeStartTransform]);

  useEffect(() => {
    if (!visible) return;
    return () => {
      if (hideIconTimer.current) clearTimeout(hideIconTimer.current);
      if (clickTimer.current) clearTimeout(clickTimer.current);
    };
  }, [visible]);

  const handleClose = useCallback(() => {
    if (closing) return;
    const v = videoRef.current;
    if (v) v.pause();
    const tr = computeStartTransform();
    setStartTransform(tr);
    setClosing(true);
    setEntering(false);
  }, [closing, computeStartTransform]);

  const handleTransitionEnd = () => {
    if (closing) {
      setClosing(false);
      onClose();
    }
  };

  // 短暂显示中央图标后隐藏（播放中）
  const flashCenterIcon = (type: "play" | "pause") => {
    setCenterIconType(type);
    setShowCenterIcon(true);
    if (hideIconTimer.current) clearTimeout(hideIconTimer.current);
    hideIconTimer.current = setTimeout(() => {
      // 播放中才隐藏；暂停时持续显示
      if (type === "pause" && videoRef.current && !videoRef.current.paused) {
        setShowCenterIcon(false);
      }
    }, 2000);
  };

  const togglePlay = () => {
    const v = videoRef.current;
    if (!v) return;
    if (v.paused) {
      v.play().catch(() => {});
    } else {
      v.pause();
    }
  };

  const handleVideoClick = () => {
    // 区分单击/双击：单击继续播放（暂停→播放），双击暂停
    if (clickTimer.current) {
      clearTimeout(clickTimer.current);
      clickTimer.current = null;
      // 双击：暂停
      const v = videoRef.current;
      if (v && !v.paused) v.pause();
      return;
    }
    clickTimer.current = setTimeout(() => {
      clickTimer.current = null;
      // 单击：继续播放（如果暂停则播放），播放中则暂停
      togglePlay();
    }, 250);
  };

  // 进度条交互（参考悦音乐）
  const calcProgressFromEvent = (clientX: number): number => {
    const bar = progressBarRef.current;
    if (!bar) return 0;
    const rect = bar.getBoundingClientRect();
    const p = (clientX - rect.left) / rect.width;
    return Math.max(0, Math.min(1, p));
  };

  const handleProgressPointerDown = (e: React.PointerEvent) => {
    const p = calcProgressFromEvent(e.clientX);
    setDraggingProgress(p);
    (e.target as HTMLElement).setPointerCapture?.(e.pointerId);
  };
  const handleProgressPointerMove = (e: React.PointerEvent) => {
    if (draggingProgress === null) return;
    setDraggingProgress(calcProgressFromEvent(e.clientX));
  };
  const handleProgressPointerUp = (e: React.PointerEvent) => {
    if (draggingProgress === null) return;
    const p = calcProgressFromEvent(e.clientX);
    setDraggingProgress(null);
    const v = videoRef.current;
    if (v && duration > 0) {
      v.currentTime = p * duration;
    }
  };

  const displayProgress = draggingProgress !== null ? draggingProgress : progress;

  if (!visible) return null;

  return createPortal(
    <div
      className={cn(
        "fixed inset-0 z-[200] bg-black/90 transition-opacity duration-300",
        entering ? "opacity-100" : "opacity-0"
      )}
    >
      {/* 加载等待圆：视频 waiting 或未加载时正中显示 */}
      {(waiting || !loaded) && (
        <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
          <Loader2 className="w-10 h-10 text-white/80 animate-spin" strokeWidth={1.5} />
        </div>
      )}

      {/* 视频主体：全屏占满预览区，按原比例 contain（横屏宽撑满，竖屏高撑满） */}
      <div className="absolute inset-0 flex items-center justify-center overflow-hidden">
        <div
          ref={wrapRef}
          style={{
            transform: entering ? "none" : startTransform,
            transition: closing
              ? "transform 280ms ease-in"
              : "transform 280ms cubic-bezier(0.25,0.1,0.25,1)",
          }}
          onTransitionEnd={handleTransitionEnd}
          className="w-screen h-screen flex items-center justify-center"
        >
          <div
            style={{
              transform: `translate(${videoTranslate.x}px, ${videoTranslate.y}px) scale(${videoScale})`,
              transition: "transform 120ms ease-out",
              touchAction: "none",
            }}
            onTouchStart={handleVideoTouchStart}
            onTouchMove={handleVideoTouchMove}
            onTouchEnd={handleVideoTouchEnd}
            className="w-full h-full flex items-center justify-center"
          >
            <video
              ref={videoRef}
              src={url}
              poster={poster}
              className="w-full h-full object-contain"
              playsInline
              preload="auto"
              onClick={handleVideoClick}
              onLoadedMetadata={(e) => {
                setLoaded(true);
                setDuration(e.currentTarget.duration || 0);
                // 预览打开后自动播放（用户点击触发的上下文，允许 play）
                e.currentTarget.play().catch(() => {});
              }}
              onCanPlay={() => setLoaded(true)}
              onPlay={() => {
                setIsPlaying(true);
                flashCenterIcon("pause");
              }}
              onPause={() => {
                setIsPlaying(false);
                flashCenterIcon("play");
              }}
              onWaiting={() => setWaiting(true)}
              onPlaying={() => setWaiting(false)}
              onCanPlayThrough={() => setWaiting(false)}
              onTimeUpdate={(e) => {
                const v = e.currentTarget;
                setCurrentTime(v.currentTime);
                if (v.duration > 0) {
                  setProgress(v.currentTime / v.duration);
                }
              }}
            />
          </div>
        </div>
      </div>

      {/* 中央播放/暂停图标（暂停时持续显示，播放时2s后隐藏） */}
      {showCenterIcon && (
        <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
          <div className="w-16 h-16 rounded-full bg-black/40 backdrop-blur-sm flex items-center justify-center">
            {centerIconType === "play" ? (
              <RoundedPlayIcon className="w-8 h-8 text-white ml-1" />
            ) : (
              <Pause className="w-8 h-8 text-white" fill="currentColor" strokeWidth={0} />
            )}
          </div>
        </div>
      )}

      {/* 右上角叉叉 */}
      <button
        type="button"
        onClick={handleClose}
        className={cn(
          "absolute top-[max(1rem,env(safe-area-inset-top))] right-4 w-10 h-10 rounded-full bg-white/15 backdrop-blur-sm flex items-center justify-center transition-opacity",
          entering ? "opacity-100" : "opacity-0"
        )}
        aria-label="关闭"
      >
        <X className="w-5 h-5 text-white" strokeWidth={2} />
      </button>

      {/* 底部播放控件：圆角播放图标（左，无背景色）+ 进度条（右），两者严格垂直居中对齐 */}
      <div
        className={cn(
          "absolute bottom-[max(1.5rem,env(safe-area-inset-bottom))] left-0 right-0 px-6 transition-opacity duration-300",
          entering ? "opacity-100" : "opacity-0"
        )}
      >
        {/* 图标 + 进度条同一行，items-center 保证垂直对齐；进度条行高与图标一致 */}
        <div className="flex items-center gap-4">
          <button
            type="button"
            onClick={togglePlay}
            className="flex items-center justify-center w-7 h-7 flex-shrink-0 active:scale-90 transition-transform"
            aria-label={isPlaying ? "暂停" : "播放"}
          >
            {isPlaying ? (
              <Pause
                key="pause"
                className="w-7 h-7 text-white animate-[iconSwap_250ms_ease]"
                fill="currentColor"
                strokeWidth={0}
              />
            ) : (
              <RoundedPlayIcon
                key="play"
                className="w-7 h-7 text-white animate-[iconSwap_250ms_ease]"
              />
            )}
          </button>

          {/* 进度条容器：固定高度与图标一致(28px)，进度条垂直居中 */}
          <div className="flex-1 min-w-0 h-7 flex items-center">
            <div
              ref={progressBarRef}
              className="relative h-1 w-full rounded-full bg-white/20 cursor-pointer"
              onPointerDown={handleProgressPointerDown}
              onPointerMove={handleProgressPointerMove}
              onPointerUp={handleProgressPointerUp}
              onPointerCancel={handleProgressPointerUp}
            >
              <div
                className="absolute inset-y-0 left-0 bg-white/80 rounded-full"
                style={{ width: `${displayProgress * 100}%` }}
              />
              <div
                className="absolute top-1/2 w-2.5 h-2.5 rounded-full bg-white shadow-md -translate-y-1/2 pointer-events-none"
                style={{ left: `calc(${displayProgress * 100}% - 5px)` }}
              />
            </div>
          </div>
        </div>
        {/* 时间标签独立一行，避免影响图标与进度条的对齐 */}
        <div className="mt-1 flex items-center justify-between text-[11px] text-white/55">
          <span>
            {formatTime(draggingProgress !== null ? draggingProgress * duration : currentTime)}
          </span>
          <span>{formatTime(duration)}</span>
        </div>
      </div>
    </div>,
    document.body
  );
}
