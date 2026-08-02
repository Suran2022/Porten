import { useEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";
import { SkipBack, SkipForward, Pause, Play, Share2 } from "lucide-react";
import { cn } from "@/lib/utils";
import { MUSIC_TRACKS, MusicTrack } from "@/data/music";

interface LyricLine {
  time: number;
  text: string;
}

// 解析 lrc 文件（与 MusicView 一致）
function parseLrc(content: string): LyricLine[] {
  const lines = content.split(/\r?\n/);
  const result: LyricLine[] = [];
  for (const raw of lines) {
    const line = raw.trim();
    if (!line) continue;
    if (line.startsWith("{")) {
      try {
        const obj = JSON.parse(line);
        const time = (obj.t ?? 0) / 1000;
        const text = Array.isArray(obj.c)
          ? obj.c.map((seg: { tx?: string }) => seg.tx ?? "").join("")
          : "";
        if (text) result.push({ time, text });
      } catch {
        // 忽略
      }
      continue;
    }
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

function formatTime(seconds: number): string {
  const m = Math.floor(seconds / 60);
  const s = Math.floor(seconds % 60);
  return `${m.toString().padStart(2, "0")}:${s.toString().padStart(2, "0")}`;
}

export default function ShareMusicPage() {
  // 分享页固定展示第一首（眉间雪，唯一有音源的歌曲）
  const playableTracks = MUSIC_TRACKS.filter((t) => t.audioSrc);
  const [trackIndex, setTrackIndex] = useState(0);
  const track: MusicTrack = playableTracks[trackIndex] ?? MUSIC_TRACKS[0];

  const [isPlaying, setIsPlaying] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(track.duration);
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const hasStartedRef = useRef(false);

  // 歌词
  const [lyrics, setLyrics] = useState<LyricLine[]>([]);
  const [showLyrics, setShowLyrics] = useState(false);
  const lyricsContainerRef = useRef<HTMLDivElement>(null);
  const activeLineRef = useRef<HTMLDivElement>(null);

  // 情绪音乐馆文案轮播
  const moodTexts = ["情绪音乐馆：来自网易云", "情绪音乐馆：来自锦零"];
  const [moodIndex, setMoodIndex] = useState(0);
  const [moodAnim, setMoodAnim] = useState<"in" | "out">("in");

  // 分享文案池
  const shareTexts = [
    "这首情绪音乐太好听了，快来 Porten 一起聆听吧～",
    "在 Porten 情绪音乐馆发现一首宝藏歌曲，分享给你！",
    "让音乐治愈心灵，来 Porten 情绪音乐馆一起感受～",
    "好听到单曲循环！来自 Porten 情绪音乐馆的推荐",
  ];

  // 播放 10s 引导弹窗（接收方才弹）
  const [inviteVisible, setInviteVisible] = useState(false);
  const inviteShownRef = useRef(false);

  // 创建 audio 元素
  useEffect(() => {
    const audio = new Audio();
    audio.preload = "metadata";
    audioRef.current = audio;

    const onTimeUpdate = () => setCurrentTime(audio.currentTime);
    const onLoadedMeta = () => setDuration(audio.duration || 0);
    const onEnded = () => setIsPlaying(false);

    audio.addEventListener("timeupdate", onTimeUpdate);
    audio.addEventListener("loadedmetadata", onLoadedMeta);
    audio.addEventListener("ended", onEnded);

    return () => {
      audio.pause();
      audio.removeEventListener("timeupdate", onTimeUpdate);
      audio.removeEventListener("loadedmetadata", onLoadedMeta);
      audio.removeEventListener("ended", onEnded);
      audioRef.current = null;
    };
  }, []);

  // 切歌：加载音源
  useEffect(() => {
    const audio = audioRef.current;
    if (!audio) return;
    const src = track.audioSrc;
    if (src) {
      audio.src = src;
      audio.load();
      setCurrentTime(0);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [trackIndex]);

  // 播放/暂停控制
  useEffect(() => {
    const audio = audioRef.current;
    if (!audio || !track.audioSrc) return;
    if (isPlaying) {
      audio.play().catch(() => setIsPlaying(false));
    } else {
      audio.pause();
    }
  }, [isPlaying, track.audioSrc]);

  // 情绪音乐馆文案轮播
  useEffect(() => {
    const timer = setInterval(() => {
      setMoodAnim("out");
      setTimeout(() => {
        setMoodIndex((i) => (i + 1) % moodTexts.length);
        setMoodAnim("in");
      }, 300);
    }, 3500);
    return () => clearInterval(timer);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // 加载歌词
  useEffect(() => {
    if (!track.lrcSrc) {
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
  }, [track.lrcSrc]);

  const playTime = currentTime;
  const totalTime = duration;
  const activeLyricIndex = (() => {
    if (lyrics.length === 0) return -1;
    let idx = -1;
    for (let i = 0; i < lyrics.length; i++) {
      if (lyrics[i].time <= playTime) idx = i;
      else break;
    }
    return idx;
  })();

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

  // 播放 10s 弹引导框（只弹一次）
  useEffect(() => {
    if (inviteShownRef.current) return;
    if (playTime >= 10) {
      inviteShownRef.current = true;
      setInviteVisible(true);
    }
  }, [playTime]);

  // 分享：接收方也可再次分享
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
        // 忽略
      }
    } else {
      try {
        await navigator.clipboard?.writeText(`${text} ${shareUrl}`);
      } catch {
        // 忽略
      }
    }
  };

  const handleTogglePlay = () => {
    hasStartedRef.current = true;
    setIsPlaying((v) => !v);
  };

  const handlePrev = () => {
    setTrackIndex((i) => Math.max(0, i - 1));
  };
  const handleNext = () => {
    setTrackIndex((i) => Math.min(playableTracks.length - 1, i + 1));
  };

  const progress = totalTime > 0 ? Math.min(1, playTime / totalTime) : 0;

  const colorMatches = track.bgGradient.match(/#[0-9a-fA-F]{6}/g);
  const topColor = colorMatches && colorMatches.length > 0 ? colorMatches[0] : "#1a1108";

  // 设置 body 背景色
  useEffect(() => {
    document.documentElement.style.backgroundColor = topColor;
    document.body.style.backgroundColor = topColor;
    return () => {
      document.documentElement.style.backgroundColor = "";
      document.body.style.backgroundColor = "";
    };
  }, [topColor]);

  return (
    <div
      className="fixed inset-0 z-[65] w-full flex flex-col overflow-hidden"
      style={{ background: track.bgGradient }}
    >
      {/* 顶部栏：歌名居中（分享页无返回按钮） */}
      <div className="relative z-30 shrink-0 px-4 pt-3 pb-2">
        <h1 className="text-white text-base font-medium text-center truncate py-1">
          {track.title}
          {track.subtitle ? (
            <span className="text-white/60 font-normal text-sm"> （{track.subtitle}）</span>
          ) : null}
        </h1>
      </div>

      {/* 主内容区 */}
      <div className="relative z-10 flex flex-col flex-1 min-h-0">
        {/* 转盘/歌词切换 */}
        <div
          className="flex-1 relative min-h-0 px-8 py-4 cursor-pointer"
          onClick={() => setShowLyrics((v) => !v)}
        >
          {/* 黑胶唱片占位（简化版，用封面图） */}
          <div
            className={cn(
              "absolute inset-0 flex items-center justify-center transition-all duration-500 ease-[cubic-bezier(0.25,0.1,0.25,1)]",
              showLyrics ? "opacity-0 scale-90 pointer-events-none" : "opacity-100 scale-100"
            )}
          >
            <div
              className="relative w-full max-w-[272px] aspect-square rounded-full"
              style={{
                background: `radial-gradient(circle at 50% 50%, ${track.vinylColor} 60%, #050505 100%)`,
                boxShadow: "0 30px 60px rgba(0,0,0,0.55), inset 0 0 30px rgba(255,255,255,0.04)",
              }}
            >
              {/* 黑胶纹路 */}
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
              {/* 中心封面区：占比 74%，大于转盘边缘黑色区域 */}
              <div
                className={cn(
                  "absolute rounded-full overflow-hidden flex items-center justify-center",
                  isPlaying && "animate-spin-slow"
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
                <img
                  src="/music-cover.webp"
                  alt={track.title}
                  className="w-full h-full object-cover"
                  draggable={false}
                />
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
                        i === activeLyricIndex ? "text-white font-medium" : "text-white/40"
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

        {/* 音乐信息：歌名 + 情绪音乐馆轮播文案 + 分享图标 */}
        <div className="flex-shrink-0 px-6 mb-3">
          <h2 className="text-white text-[22px] font-semibold leading-tight truncate">
            {track.title}
            {track.subtitle ? (
              <span className="text-white/70 font-normal text-[18px]"> （{track.subtitle}）</span>
            ) : null}
          </h2>
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

        {/* 进度条 */}
        <div className="flex-shrink-0 px-6 mb-3">
          <div className="relative h-1 rounded-full bg-white/15">
            <div
              className="absolute inset-y-0 left-0 bg-white/80 rounded-full"
              style={{ width: `${progress * 100}%` }}
            />
            <div
              className="absolute top-1/2 w-2 h-2 rounded-full bg-white shadow-md -translate-y-1/2 pointer-events-none"
              style={{ left: `calc(${progress * 100}% - 4px)` }}
            />
          </div>
          <div className="mt-1.5 flex items-center justify-between text-[11px] text-white/55">
            <span>{formatTime(playTime)}</span>
            <span className="text-white/70">{track.quality}</span>
            <span>{formatTime(totalTime)}</span>
          </div>
        </div>

        {/* 播放控制 */}
        <div className="flex-shrink-0 px-6 pt-2 pb-6">
          <div className="flex items-center justify-between">
            <div className="w-10" />
            <button
              type="button"
              onClick={handlePrev}
              className="text-white active:scale-90 transition-transform p-2 disabled:opacity-30"
              disabled={trackIndex === 0}
              aria-label="上一首"
            >
              <SkipBack className="w-7 h-7" strokeWidth={1.8} />
            </button>
            <button
              type="button"
              onClick={handleTogglePlay}
              className="active:scale-90 transition-transform p-2"
              aria-label={isPlaying ? "暂停" : "播放"}
            >
              {isPlaying ? (
                <Pause key="pause" className="w-12 h-12 text-white" strokeWidth={1.6} />
              ) : (
                <Play key="play" className="w-12 h-12 text-white" strokeWidth={1.6} />
              )}
            </button>
            <button
              type="button"
              onClick={handleNext}
              className="text-white active:scale-90 transition-transform p-2 disabled:opacity-30"
              disabled={trackIndex >= playableTracks.length - 1}
              aria-label="下一首"
            >
              <SkipForward className="w-7 h-7" strokeWidth={1.8} />
            </button>
            <div className="w-10" />
          </div>
        </div>
      </div>

      {/* 播放 10s 引导提示框：快来Porten和同伴们一起探索趴 */}
      {inviteVisible &&
        createPortal(
          <div className="fixed inset-0 z-[110] flex items-center justify-center px-8">
            <div
              className="absolute inset-0 bg-black/60 backdrop-blur-sm"
              onClick={() => setInviteVisible(false)}
            />
            <div className="relative w-full max-w-xs bg-[#1c1410] rounded-2xl px-6 py-7 text-center">
              <p className="text-white text-[17px] font-medium leading-relaxed">
                快来Porten和同伴们一起探索趴！
              </p>
              <div className="mt-6 flex gap-3">
                <button
                  type="button"
                  onClick={() => setInviteVisible(false)}
                  className="flex-1 py-2.5 rounded-xl bg-white/10 text-white/80 text-sm font-medium active:scale-95 transition-transform"
                >
                  我想想
                </button>
                <button
                  type="button"
                  onClick={() => {
                    setInviteVisible(false);
                    window.location.href = "/register";
                  }}
                  className="flex-1 py-2.5 rounded-xl bg-white text-[#1c1410] text-sm font-semibold active:scale-95 transition-transform"
                >
                  去Porten
                </button>
              </div>
            </div>
          </div>,
          document.body
        )}
    </div>
  );
}
