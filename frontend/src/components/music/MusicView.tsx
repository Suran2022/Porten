import { useEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";
import { ArrowLeft, Repeat, SkipBack, SkipForward, Pause, Play, ListMusic, Music2, X, Share2 } from "lucide-react";
import { cn } from "@/lib/utils";
import { MusicTrack } from "@/data/music";

interface LyricLine {
  time: number; // 秒
  text: string;
}

// 解析 lrc 文件：支持 [mm:ss.ss] 标准格式 和 {"t":ms,"c":[...]} JSON 行
function parseLrc(content: string): LyricLine[] {
  const lines = content.split(/\r?\n/);
  const result: LyricLine[] = [];
  for (const raw of lines) {
    const line = raw.trim();
    if (!line) continue;
    // JSON 行：{"t":毫秒,"c":[{"tx":"..."}]}
    if (line.startsWith("{")) {
      try {
        const obj = JSON.parse(line);
        const time = (obj.t ?? 0) / 1000;
        const text = Array.isArray(obj.c)
          ? obj.c.map((seg: { tx?: string }) => seg.tx ?? "").join("")
          : "";
        if (text) result.push({ time, text });
      } catch {
        // 忽略解析失败的行
      }
      continue;
    }
    // 标准 [mm:ss.ss] 格式，可能一行多个时间戳
    const matches = line.match(/\[(\d{1,2}):(\d{1,2}(?:\.\d+)?)\]/g);
    if (!matches) continue;
    const text = line.replace(/\[\d{1,2}:\d{1,2}(?:\.\d+)?\]/g, "").trim();
    for (const m of matches) {
      const parts = m.match(/\[(\d{1,2}):(\d{1,2}(?:\.\d+)?)\]/);
      if (!parts) continue;
      const time = parseInt(parts[1], 10) * 60 + parseFloat(parts[2]);
      result.push({ time, text });
    }
  }
  result.sort((a, b) => a.time - b.time);
  return result;
}

interface MusicViewProps {
  visible: boolean;
  onClose: () => void;
  track: MusicTrack;
  isPlaying: boolean;
  onTogglePlay: () => void;
  onPrev: () => void;
  onNext: () => void;
  canPrev?: boolean; // 是否还有上一首（false 时点击提示暂无更多音乐）
  canNext?: boolean; // 是否还有下一首
  isFollowing?: boolean;
  onToggleFollow?: () => void;
  isLiked?: boolean;
  onToggleLike?: () => void;
  currentTime?: number; // 实时播放进度（秒），不传则用 track.currentTime
  duration?: number; // 实时总时长（秒），不传则用 track.duration
  onSeek?: (time: number) => void; // 进度条拖动跳转
  coverImage?: string; // 转盘中心封面图
  tracks?: MusicTrack[]; // 播放列表（用于播放列表弹窗）
  currentTrackIndex?: number; // 当前播放歌曲在列表中的索引
  onSelectTrack?: (index: number) => void; // 选择播放列表中的歌曲
}

function formatTime(seconds: number): string {
  const m = Math.floor(seconds / 60);
  const s = Math.floor(seconds % 60);
  return `${m.toString().padStart(2, "0")}:${s.toString().padStart(2, "0")}`;
}

export function MusicView({
  visible,
  onClose,
  track,
  isPlaying,
  onTogglePlay,
  onPrev,
  onNext,
  canPrev = true,
  canNext = true,
  isFollowing = false,
  onToggleFollow,
  isLiked = true,
  onToggleLike,
  currentTime,
  duration,
  onSeek,
  coverImage,
  tracks,
  currentTrackIndex,
  onSelectTrack,
}: MusicViewProps) {
  // 实时进度，优先用 props 传入的实时值，否则回退到 track 静态值
  const playTime = currentTime ?? track.currentTime;
  const totalTime = duration ?? track.duration;
  const [shouldRender, setShouldRender] = useState(false);
  const [isEntering, setIsEntering] = useState(false);
  // 歌词视图切换：点击转盘区域切换 转盘 <-> 滚动歌词
  const [showLyrics, setShowLyrics] = useState(false);
  const [lyrics, setLyrics] = useState<LyricLine[]>([]);
  const lyricsContainerRef = useRef<HTMLDivElement>(null);
  const activeLineRef = useRef<HTMLDivElement>(null);
  // 进度条拖动
  const [draggingProgress, setDraggingProgress] = useState<number | null>(null);
  const progressBarRef = useRef<HTMLDivElement>(null);
  // 暂无更多音乐 toast
  const [toastVisible, setToastVisible] = useState(false);
  const toastTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  // 情绪音乐馆文案轮播：每 3.5s 切换，上下顶出动画
  const moodTexts = ["情绪音乐馆：来自网易云", "情绪音乐馆：来自锦零"];
  const [moodIndex, setMoodIndex] = useState(0);
  const [moodAnim, setMoodAnim] = useState<"in" | "out">("in");
  useEffect(() => {
    if (!shouldRender) return;
    const timer = setInterval(() => {
      // 先执行退出动画，结束后切换文案并执行进入动画
      setMoodAnim("out");
      setTimeout(() => {
        setMoodIndex((i) => (i + 1) % moodTexts.length);
        setMoodAnim("in");
      }, 300);
    }, 3500);
    return () => clearInterval(timer);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [shouldRender]);

  // 分享文案池：每次分享随机选取一条，内容有变化
  const shareTexts = [
    "这首情绪音乐太好听了，快来 Porten 一起聆听吧～",
    "在 Porten 情绪音乐馆发现一首宝藏歌曲，分享给你！",
    "让音乐治愈心灵，来 Porten 情绪音乐馆一起感受～",
    "好听到单曲循环！来自 Porten 情绪音乐馆的推荐",
  ];

  // 分享：唤起设备默认分享渠道，分享内容随机变化，链接指向免登录分享页
  const handleShare = async () => {
    const text = shareTexts[Math.floor(Math.random() * shareTexts.length)];
    const shareUrl = `${window.location.origin}/share/music`;
    if (navigator.share) {
      try {
        await navigator.share({
          title: "Porten 情绪音乐馆",
          text,
          url: shareUrl,
        });
      } catch {
        // 用户取消分享，忽略
      }
    } else {
      // 不支持 Web Share API 时回退到复制链接
      try {
        await navigator.clipboard?.writeText(`${text} ${shareUrl}`);
      } catch {
        // 忽略
      }
    }
  };

  const showNoMoreToast = () => {
    setToastVisible(true);
    if (toastTimerRef.current) clearTimeout(toastTimerRef.current);
    toastTimerRef.current = setTimeout(() => setToastVisible(false), 2000);
  };

  // 播放列表弹窗：shouldRender 后才允许渲染，从底部滑入
  const [playlistVisible, setPlaylistVisible] = useState(false);
  const [playlistRendered, setPlaylistRendered] = useState(false);

  useEffect(() => {
    if (playlistVisible) {
      setPlaylistRendered(true);
      requestAnimationFrame(() => {
        requestAnimationFrame(() => {
          const el = document.getElementById("music-playlist-sheet");
          if (el) el.style.transform = "translateY(0)";
        });
      });
    } else if (playlistRendered) {
      const el = document.getElementById("music-playlist-sheet");
      if (el) el.style.transform = "translateY(100%)";
      const t = setTimeout(() => setPlaylistRendered(false), 300);
      return () => clearTimeout(t);
    }
  }, [playlistVisible, playlistRendered]);

  useEffect(() => {
    return () => {
      if (toastTimerRef.current) clearTimeout(toastTimerRef.current);
    };
  }, []);

  const handlePrev = () => {
    if (canPrev) {
      onPrev();
    } else {
      showNoMoreToast();
    }
  };

  const handleNext = () => {
    if (canNext) {
      onNext();
    } else {
      showNoMoreToast();
    }
  };
  // 保存一次性挂载时的原始状态，供卸载时恢复
  // 关键：切歌时不触发恢复，避免 cleanup→重新挂载导致的中间色闪动
  const mountRestoreRef = useRef<{
    htmlBg: string;
    bodyBg: string;
    htmlOverscroll: string;
    bodyOverscroll: string;
    rootDisplay: string | null;
    themeColor: string | null;
  } | null>(null);

  useEffect(() => {
    if (visible) {
      setShouldRender(true);
      requestAnimationFrame(() => {
        requestAnimationFrame(() => setIsEntering(true));
      });
    } else {
      setIsEntering(false);
    }
  }, [visible]);

  // 一次性挂载/卸载：隐藏主页、允许下拉、记录原始 theme-color
  // 仅在 shouldRender 变化时执行，切歌时不触发，避免 cleanup→重新挂载导致的中间色闪动
  useEffect(() => {
    if (!shouldRender) return;

    const html = document.documentElement;
    const body = document.body;
    const root = document.getElementById("root");
    const existingMeta = document.querySelector('meta[name="theme-color"]');

    mountRestoreRef.current = {
      htmlBg: html.style.backgroundColor,
      bodyBg: body.style.backgroundColor,
      htmlOverscroll: html.style.overscrollBehavior,
      bodyOverscroll: body.style.overscrollBehavior,
      rootDisplay: root?.style.display ?? null,
      themeColor: existingMeta?.getAttribute("content") ?? null,
    };

    // 允许下拉刷新（覆盖 index.css 的全局 overscroll-behavior: none）
    html.style.overscrollBehavior = "auto";
    body.style.overscrollBehavior = "auto";
    // 完全隐藏主页，避免白色背景和 fixed 占位干扰 body 滚动
    if (root) {
      root.style.display = "none";
    }

    return () => {
      const r = mountRestoreRef.current;
      if (!r) return;
      html.style.backgroundColor = r.htmlBg;
      body.style.backgroundColor = r.bodyBg;
      html.style.overscrollBehavior = r.htmlOverscroll;
      body.style.overscrollBehavior = r.bodyOverscroll;
      if (root) {
        root.style.display = r.rootDisplay ?? "";
      }
      // 恢复 theme-color：remove+create 强制 Safari 重新采样（关闭页面时无需担心闪动）
      const meta = document.querySelector('meta[name="theme-color"]');
      if (meta) meta.remove();
      if (r.themeColor) {
        const restoreMeta = document.createElement("meta");
        restoreMeta.name = "theme-color";
        restoreMeta.setAttribute("content", r.themeColor);
        document.head.appendChild(restoreMeta);
      }
      mountRestoreRef.current = null;
    };
  }, [shouldRender]);

  // 颜色静默更新：切歌时刷新状态栏/底部颜色
  // - html/body backgroundColor 直接设值（无中间状态）
  // - theme-color 用 remove+create：强制 Safari 重新采样状态栏颜色
  //   （setAttribute/cloneNode 在 iOS Safari 上不实时刷新，已被验证无效）
  // - 拆分 effect 后切歌不触发 cleanup（无中间恢复色），
  //   remove+create 是同步 DOM 操作，浏览器在同一事件循环内不渲染中间状态，不闪动
  useEffect(() => {
    if (!shouldRender) return;

    const html = document.documentElement;
    const body = document.body;
    const colorMatches = track.bgGradient.match(/#[0-9a-fA-F]{6}/g);
    const topColor = colorMatches && colorMatches.length > 0 ? colorMatches[0] : "#1a1108";

    html.style.backgroundColor = topColor;
    body.style.backgroundColor = topColor;

    // remove+create：强制 Safari 重新采样状态栏颜色
    const oldMeta = document.querySelector('meta[name="theme-color"]');
    if (oldMeta) {
      oldMeta.remove();
    }
    const newMeta = document.createElement("meta");
    newMeta.name = "theme-color";
    newMeta.setAttribute("content", topColor);
    document.head.appendChild(newMeta);
  }, [shouldRender, track.bgGradient]);

  // 加载歌词文件
  useEffect(() => {
    if (!shouldRender || !track.lrcSrc) {
      setLyrics([]);
      return;
    }
    let cancelled = false;
    fetch(track.lrcSrc)
      .then((res) => res.text())
      .then((text) => {
        if (!cancelled) setLyrics(parseLrc(text));
      })
      .catch(() => {
        if (!cancelled) setLyrics([]);
      });
    return () => {
      cancelled = true;
    };
  }, [shouldRender, track.lrcSrc]);

  // 计算当前歌词行索引（不超过当前播放时间的最后一行）
  const activeLyricIndex = (() => {
    if (lyrics.length === 0) return -1;
    let idx = -1;
    for (let i = 0; i < lyrics.length; i++) {
      if (lyrics[i].time <= playTime) idx = i;
      else break;
    }
    return idx;
  })();

  // 当前行变化时滚动到居中位置
  useEffect(() => {
    if (!showLyrics || activeLyricIndex < 0) return;
    const container = lyricsContainerRef.current;
    const active = activeLineRef.current;
    if (!container || !active) return;
    const containerHeight = container.clientHeight;
    const activeTop = active.offsetTop;
    const activeHeight = active.clientHeight;
    container.scrollTo({
      top: activeTop - containerHeight / 2 + activeHeight / 2,
      behavior: "smooth",
    });
  }, [showLyrics, activeLyricIndex]);

  const handleTransitionEnd = () => {
    if (!isEntering) {
      setShouldRender(false);
    }
  };

  // 根据触摸/点击位置计算进度比例（0-1）
  const calcProgressFromEvent = (clientX: number): number => {
    const bar = progressBarRef.current;
    if (!bar || totalTime <= 0) return 0;
    const rect = bar.getBoundingClientRect();
    const x = clientX - rect.left;
    return Math.min(1, Math.max(0, x / rect.width));
  };

  const handleProgressPointerDown = (e: React.PointerEvent) => {
    if (!onSeek) return;
    e.stopPropagation();
    const p = calcProgressFromEvent(e.clientX);
    setDraggingProgress(p);
    (e.target as HTMLElement).setPointerCapture?.(e.pointerId);
  };

  const handleProgressPointerMove = (e: React.PointerEvent) => {
    if (draggingProgress === null) return;
    const p = calcProgressFromEvent(e.clientX);
    setDraggingProgress(p);
  };

  const handleProgressPointerUp = (e: React.PointerEvent) => {
    if (draggingProgress === null) return;
    const p = calcProgressFromEvent(e.clientX);
    onSeek?.(p * totalTime);
    setDraggingProgress(null);
    (e.target as HTMLElement).releasePointerCapture?.(e.pointerId);
  };

  if (!shouldRender) return null;

  // 实际播放进度比例（0-1）
  const progress = totalTime > 0 ? Math.min(1, playTime / totalTime) : 0;
  // 拖动时显示拖动到的位置，否则显示实际播放进度
  const displayProgress = draggingProgress !== null ? draggingProgress : progress;

  // 通过 portal 渲染到 body，作为文档流元素撑开 body 高度，
  // 使 body 本身可滚动，从而触发 iOS Safari 地址栏/底部工具栏收缩，
  // 同时 body 背景色填满状态栏区域（Safari 工具栏半透明会采样 body 背景色）
  const colorMatches = track.bgGradient.match(/#[0-9a-fA-F]{6}/g);
  const topColor = colorMatches && colorMatches.length > 0 ? colorMatches[0] : "#1a1108";
  const bottomColor = colorMatches && colorMatches.length > 0
    ? colorMatches[colorMatches.length - 1]
    : "#1a1108";

  return (
    <>
      {/* 状态栏色块：iOS 26 Safari 采样 fixed 元素背景色着色状态栏
          采样条件（andesco/safari-color-tinting 验证）：
          - 距视口顶部 <5px（top:0 满足）
          - 宽度 >88%（left:0 right:0 = 100% 满足）
          - 高度 >2px（用 max(env,15px) 保证非刘海设备也满足）
          - z-index 高于 MusicView，确保被采样
          切歌时 backgroundColor 变化，Safari 重新采样 */}
      {createPortal(
        <div
          className="fixed top-0 left-0 right-0 z-[1000] pointer-events-none"
          style={{ height: "max(env(safe-area-inset-top, 0px), 15px)", backgroundColor: topColor }}
        />,
        document.body
      )}
      {/* 底部工具栏色块：距视口底部 <4px，宽度 >88%，高度 >2px */}
      {createPortal(
        <div
          className="fixed bottom-0 left-0 right-0 z-[1000] pointer-events-none"
          style={{ height: "max(env(safe-area-inset-bottom, 0px), 15px)", backgroundColor: bottomColor }}
        />,
        document.body
      )}
      {createPortal(
        <div
          className={cn(
            "fixed inset-0 z-[65] w-full flex flex-col overflow-hidden transition-transform duration-300 ease-[cubic-bezier(0.25,0.1,0.25,1)]",
            isEntering ? "translate-x-0" : "translate-x-full"
          )}
          style={{ background: track.bgGradient }}
          onTransitionEnd={handleTransitionEnd}
        >
      {/* 顶部栏：返回按钮左对齐 + 歌名居中 */}
      <div className="relative z-30 shrink-0 px-4 pt-3 pb-2">
        <button
          type="button"
          onClick={onClose}
          className="absolute left-4 top-3 text-white/90 active:scale-90 transition-transform p-1 -ml-1"
          aria-label="返回"
        >
          <ArrowLeft className="w-6 h-6" strokeWidth={2} />
        </button>
        <h1 className="text-white text-base font-medium text-center truncate px-12 py-1">
          {track.title}
          {track.subtitle ? (
            <span className="text-white/60 font-normal text-sm"> （{track.subtitle}）</span>
          ) : null}
        </h1>
      </div>

      {/* 暂无更多音乐 toast：胶囊状灰黑背景 + 悦音乐图标，顶部居中，自动消失 */}
      <div
        className={cn(
          "absolute left-1/2 -translate-x-1/2 top-14 z-40 flex items-center gap-1.5 px-4 py-2 rounded-full bg-black/75 backdrop-blur-sm text-white text-sm transition-all duration-300",
          toastVisible ? "opacity-100 translate-y-0" : "opacity-0 -translate-y-2 pointer-events-none"
        )}
      >
        <Music2 className="w-4 h-4" strokeWidth={2} />
        <span>暂无更多音乐</span>
      </div>

      {/* 主内容区 - flex-1 撑满，转盘 flex-1 居中，控制区贴底 */}
      <div className="relative z-10 flex flex-col flex-1 min-h-0">
        {/* 转盘/歌词切换区域 - 点击切换，转盘与歌词叠放淡入淡出 */}
        <div
          className="flex-1 relative min-h-0 px-8 py-4 cursor-pointer"
          onClick={() => setShowLyrics((v) => !v)}
        >
          {/* 黑胶唱片 */}
          <div
            className={cn(
              "absolute inset-0 flex items-center justify-center transition-all duration-500 ease-[cubic-bezier(0.25,0.1,0.25,1)]",
              showLyrics ? "opacity-0 scale-90 pointer-events-none" : "opacity-100 scale-100"
            )}
          >
            <VinylRecord
              vinylColor={track.vinylColor}
              coverLabel={track.coverLabel}
              coverImage={coverImage}
              spinning={isPlaying}
            />
          </div>
          {/* 滚动歌词 */}
          <div
            className={cn(
              "absolute inset-0 flex flex-col items-center justify-center transition-all duration-500 ease-[cubic-bezier(0.25,0.1,0.25,1)]",
              showLyrics ? "opacity-100 scale-100" : "opacity-0 scale-110 pointer-events-none"
            )}
          >
            {lyrics.length > 0 ? (
              <div
                ref={lyricsContainerRef}
                className="h-full w-full overflow-y-auto scrollbar-hide mask-lyric-fade"
              >
                <div className="min-h-full flex flex-col items-center justify-center gap-3 py-8">
                  {lyrics.map((line, i) => (
                    <div
                      key={i}
                      ref={i === activeLyricIndex ? activeLineRef : undefined}
                      className={cn(
                        "text-center text-[15px] leading-relaxed transition-colors duration-300 px-4",
                        i === activeLyricIndex
                          ? "text-white font-medium"
                          : "text-white/40"
                      )}
                    >
                      {line.text}
                    </div>
                  ))}
                </div>
              </div>
            ) : (
              <div className="text-white/50 text-sm">暂无歌词</div>
            )}
          </div>
        </div>

        {/* 音乐信息：歌名 + 情绪音乐馆轮播文案（每3.5s切换，上下顶出） */}
        <div className="flex-shrink-0 px-6 mb-3">
          <h2 className="text-white text-[22px] font-semibold leading-tight truncate">
            {track.title}
            {track.subtitle ? (
              <span className="text-white/70 font-normal text-[18px]">
                {" "}
                （{track.subtitle}）
              </span>
            ) : null}
          </h2>
          {/* 情绪音乐馆文案 + 分享图标：文案左对齐，分享右对齐，overflow-hidden 裁剪顶出动画 */}
          <div className="mt-2 flex items-center h-5">
            <div className="flex-1 overflow-hidden">
              <div
                key={moodIndex}
                className="text-white/70 text-sm"
                style={{
                  animation: `${moodAnim === "in" ? "moodTextIn" : "moodTextOut"} 300ms ease forwards`,
                }}
              >
                {moodTexts[moodIndex]}
              </div>
            </div>
            <button
              type="button"
              onClick={handleShare}
              className="ml-2 flex-shrink-0 text-white/70 active:scale-90 transition-transform p-1 rounded-lg"
              aria-label="分享"
            >
              <Share2 className="w-4 h-4" strokeWidth={1.8} />
            </button>
          </div>
        </div>

        {/* 进度条：细线 + 小圆点头部，圆点不被裁剪 */}
        <div className="flex-shrink-0 px-6 mb-3">
          <div
            ref={progressBarRef}
            className={cn(
              "relative h-1 rounded-full bg-white/15",
              onSeek ? "cursor-pointer" : ""
            )}
            onPointerDown={onSeek ? handleProgressPointerDown : undefined}
            onPointerMove={onSeek ? handleProgressPointerMove : undefined}
            onPointerUp={onSeek ? handleProgressPointerUp : undefined}
            onPointerCancel={onSeek ? handleProgressPointerUp : undefined}
          >
            <div
              className="absolute inset-y-0 left-0 bg-white/80 rounded-full"
              style={{ width: `${displayProgress * 100}%` }}
            />
            {/* 进度条头部小圆点 */}
            <div
              className="absolute top-1/2 w-2 h-2 rounded-full bg-white shadow-md -translate-y-1/2 pointer-events-none"
              style={{ left: `calc(${displayProgress * 100}% - 4px)` }}
            />
          </div>
          <div className="mt-1.5 flex items-center justify-between text-[11px] text-white/55">
            <span>{formatTime(draggingProgress !== null ? draggingProgress * totalTime : playTime)}</span>
            <span className="text-white/70">{track.quality}</span>
            <span>{formatTime(totalTime)}</span>
          </div>
        </div>

        {/* 播放控制：圆角空心图标风格 */}
        <div className="flex-shrink-0 px-6 pt-2">
          <div className="flex items-center justify-between">
            <button
              type="button"
              className="text-white/70 active:scale-95 transition-transform p-2"
              aria-label="循环模式"
            >
              <Repeat className="w-6 h-6" strokeWidth={1.6} />
            </button>
            <button
              type="button"
              onClick={handlePrev}
              className="text-white active:scale-90 transition-transform p-2"
              aria-label="上一首"
            >
              <SkipBack className="w-7 h-7" strokeWidth={1.8} />
            </button>
            <button
              type="button"
              onClick={onTogglePlay}
              className="active:scale-90 transition-transform p-2"
              aria-label={isPlaying ? "暂停" : "播放"}
            >
              {/* 播放/暂停切换：用 key 触发淡入缩放动画，自然过渡 */}
              {isPlaying ? (
                <Pause
                  key="pause"
                  className="w-12 h-12 text-white animate-[iconSwap_250ms_ease]"
                  strokeWidth={1.6}
                />
              ) : (
                <Play
                  key="play"
                  className="w-12 h-12 text-white animate-[iconSwap_250ms_ease]"
                  strokeWidth={1.6}
                />
              )}
            </button>
            <button
              type="button"
              onClick={handleNext}
              className="text-white active:scale-90 transition-transform p-2"
              aria-label="下一首"
            >
              <SkipForward className="w-7 h-7" strokeWidth={1.8} />
            </button>
            <button
              type="button"
              onClick={() => setPlaylistVisible(true)}
              className="text-white/70 active:scale-95 transition-transform p-2"
              aria-label="播放列表"
            >
              <ListMusic className="w-6 h-6" strokeWidth={1.6} />
            </button>
          </div>
        </div>
      </div>
    </div>,
        document.body
      )}
      {/* 播放列表弹窗：从底部滑入，居中显示，点击遮罩或歌曲后关闭 */}
      {playlistRendered &&
        createPortal(
          <div className="fixed inset-0 z-[90] flex items-end justify-center">
            {/* 遮罩 */}
            <div
              className="absolute inset-0 bg-black/50 transition-opacity duration-300"
              style={{ opacity: playlistVisible ? 1 : 0 }}
              onClick={() => setPlaylistVisible(false)}
            />
            {/* 弹窗主体 */}
            <div
              id="music-playlist-sheet"
              className="relative w-full max-w-md bg-[#1c1410] rounded-t-2xl pb-6 transition-transform duration-300 ease-[cubic-bezier(0.25,0.1,0.25,1)]"
              style={{ transform: "translateY(100%)", maxHeight: "60vh" }}
            >
              {/* 拖拽指示条 */}
              <div className="pt-2 pb-1 flex justify-center">
                <div className="w-10 h-1 rounded-full bg-white/25" />
              </div>
              {/* 标题 */}
              <div className="px-5 py-3 text-center">
                <h3 className="text-white text-base font-medium">播放列表</h3>
              </div>
              {/* 列表 */}
              <div className="overflow-y-auto px-3" style={{ maxHeight: "calc(60vh - 64px)" }}>
                {tracks && tracks.length > 0 ? (
                  tracks.map((t, i) => {
                    const active = i === currentTrackIndex;
                    return (
                      <button
                        key={t.id}
                        type="button"
                        onClick={() => {
                          onSelectTrack?.(i);
                          setPlaylistVisible(false);
                        }}
                        className={cn(
                          "w-full text-left px-3 py-3 rounded-xl mb-1 flex items-center justify-between transition-colors",
                          active ? "bg-white/15" : "bg-transparent active:bg-white/5"
                        )}
                      >
                        <div className="min-w-0 flex-1">
                          <div className={cn("truncate text-[15px]", active ? "text-white font-medium" : "text-white/85")}>
                            {t.title}
                            {t.subtitle ? (
                              <span className="text-white/55 font-normal text-[13px]"> （{t.subtitle}）</span>
                            ) : null}
                          </div>
                          <div className="truncate text-[12px] text-white/50 mt-0.5">{t.artist}</div>
                        </div>
                        {active && (
                          <span className="ml-2 flex-shrink-0 text-white/70 text-xs">播放中</span>
                        )}
                      </button>
                    );
                  })
                ) : (
                  <div className="text-center text-white/50 text-sm py-8">暂无播放列表</div>
                )}
                {/* 列表底部提示：没有更多音乐啦 */}
                <div className="text-center text-white/35 text-xs py-4">没有更多音乐啦</div>
              </div>
            </div>
          </div>,
          document.body
        )}
    </>
  );
}

interface VinylRecordProps {
  vinylColor: string;
  coverLabel: string;
  coverImage?: string;
  spinning: boolean;
}

function VinylRecord({ vinylColor, coverLabel, coverImage, spinning }: VinylRecordProps) {
  return (
    <div className="relative w-full max-w-[272px] aspect-square">
      {/* 黑胶外圈阴影 */}
      <div
        className="absolute inset-0 rounded-full"
        style={{
          background: `radial-gradient(circle at 50% 50%, ${vinylColor} 60%, #050505 100%)`,
          boxShadow: "0 30px 60px rgba(0,0,0,0.55), inset 0 0 30px rgba(255,255,255,0.04)",
        }}
      >
        {/* 黑胶纹路 - 3 圈，紧密排列在外缘 */}
        {Array.from({ length: 3 }).map((_, i) => {
          const inset = 6 + i * 4;
          return (
            <div
              key={i}
              className="absolute rounded-full border border-white/[0.05]"
              style={{ inset: `${inset}px` }}
            />
          );
        })}

        {/* 中心封面区 - 74% 直径，封面图填充 */}
        <div
          className={cn(
            "absolute rounded-full overflow-hidden flex items-center justify-center",
            spinning && "animate-spin-slow"
          )}
          style={{
            top: "13%",
            left: "13%",
            right: "13%",
            bottom: "13%",
            boxShadow:
              "inset 0 0 0 4px rgba(0,0,0,0.35), 0 0 0 2px rgba(255,255,255,0.08)",
          }}
        >
          {coverImage ? (
            <img
              src={coverImage}
              alt={coverLabel}
              className="w-full h-full object-cover"
              draggable={false}
            />
          ) : (
            <span className="text-white/70 text-[24px] font-light tracking-[0.2em] select-none">
              {coverLabel}
            </span>
          )}
          {/* 中心孔 */}
          <div
            className="absolute rounded-full bg-black"
            style={{
              top: "50%",
              left: "50%",
              width: 8,
              height: 8,
              transform: "translate(-50%, -50%)",
            }}
          />
        </div>
      </div>
    </div>
  );
}
