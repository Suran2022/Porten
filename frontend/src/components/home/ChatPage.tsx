import {
  memo,
  useCallback,
  useEffect,
  useLayoutEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import {
  ArrowLeft,
  Phone,
  Video,
  MoreVertical,
  Play,
  Pause,
  PhoneCall,
  VideoIcon,
  FileText,
  Table,
  Package,
  Smartphone,
  Music,
  Image as ImageIcon,
  PenTool,
  File as FileIcon,
  Mic,
  Square,
  Check,
  Image,
  Paperclip,
  Heart,
  Music2,
  AlertCircle,
  Loader2,
  ChevronDown,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { ChatItem, ChatType } from "@/types/chat";
import { Message } from "@/types/message";
import { useAuthStore } from "@/store/authStore";
import { useChatStore } from "@/store/chatStore";
import { useMessageStore } from "@/store/messageStore";

import { useVoiceRecorder } from "@/hooks/useVoiceRecorder";
import { useIsDesktop } from "@/hooks/useIsDesktop";
import { MediaPreview } from "./MediaPreview";

const EMPTY_MESSAGES: Message[] = [];

interface ChatPageProps {
  chat: ChatItem | null;
  visible: boolean;
  onClose: () => void;
  onUserProfileClick?: (userId: number | string) => void;
  isDesktop?: boolean;
}

function formatChatTime(timeStr: string): string {
  if (!timeStr) return "";
  const normalized = /[Zz]|[+-]\d{2}:?\d{2}$/.test(timeStr)
    ? timeStr
    : `${timeStr}Z`;
  const date = new Date(normalized);
  if (isNaN(date.getTime())) return "";
  const now = new Date();
  const isSameDay =
    date.getFullYear() === now.getFullYear() &&
    date.getMonth() === now.getMonth() &&
    date.getDate() === now.getDate();
  const hours = date.getHours().toString().padStart(2, "0");
  const minutes = date.getMinutes().toString().padStart(2, "0");
  if (isSameDay) return `${hours}:${minutes}`;
  return `${date.toISOString().split("T")[0]} ${hours}:${minutes}`;
}

function normalizeTimestamp(timeStr: string): string {
  // Backend stores naive UTC datetimes; append Z when no timezone info.
  return /[Zz]|[+-]\d{2}:?\d{2}$/.test(timeStr) ? timeStr : `${timeStr}Z`;
}

function isSameTimeGroup(a: string, b: string): boolean {
  const ta = new Date(normalizeTimestamp(a)).getTime();
  const tb = new Date(normalizeTimestamp(b)).getTime();
  if (isNaN(ta) || isNaN(tb)) return false;
  return Math.abs(ta - tb) < 5 * 60 * 1000;
}

function formatDuration(seconds?: number) {
  if (!seconds) return "0\"";
  if (seconds < 60) return `${seconds}"`;
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  return `${m}:${s.toString().padStart(2, "0")}`;
}

function formatFileSize(bytes?: number) {
  if (bytes == null) return "";
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

function getMediaUrl(url?: string): string | undefined {
  if (!url) return undefined;
  if (/^(https?:|blob:|data:)/i.test(url)) return url;
  const base = (import.meta.env.VITE_API_BASE_URL as string) || "";
  const origin = base.startsWith("http")
    ? new URL(base).origin
    : window.location.origin;
  return `${origin}${url.startsWith("/") ? url : `/${url}`}`;
}

function getFileIcon(fileType: string) {
  const t = fileType.toLowerCase();
  const iconClass = "w-9 h-9";
  const stroke = 1.5;
  if (["doc", "docx", "txt", "md", "pdf"].includes(t)) {
    return <FileText className={iconClass} strokeWidth={stroke} />;
  }
  if (["xls", "xlsx", "csv"].includes(t)) {
    return <Table className={iconClass} strokeWidth={stroke} />;
  }
  if (["ppt", "pptx"].includes(t)) {
    return <PenTool className={iconClass} strokeWidth={stroke} />;
  }
  if (["zip", "rar", "7z", "tar"].includes(t)) {
    return <Package className={iconClass} strokeWidth={stroke} />;
  }
  if (["apk", "ipa"].includes(t)) {
    return <Smartphone className={iconClass} strokeWidth={stroke} />;
  }
  if (["mp3", "wav", "aac", "flac"].includes(t)) {
    return <Music className={iconClass} strokeWidth={stroke} />;
  }
  if (["mp4", "mov", "avi", "mkv"].includes(t)) {
    return <VideoIcon className={iconClass} strokeWidth={stroke} />;
  }
  if (["jpg", "jpeg", "png", "gif", "webp"].includes(t)) {
    return <ImageIcon className={iconClass} strokeWidth={stroke} />;
  }
  if (["fig", "sketch", "psd", "ai"].includes(t)) {
    return <PenTool className={iconClass} strokeWidth={stroke} />;
  }
  return <FileIcon className={iconClass} strokeWidth={stroke} />;
}

const URL_REGEX =
  /(https?:\/\/[^\s]+)|((?:\d{1,3}\.){3}\d{1,3}(?::\d{1,5})?)|((?:[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}(?::\d{1,5})?)/g;

function renderTextWithLinks(text: string, linkClassName?: string) {
  const parts: (string | JSX.Element)[] = [];
  let lastIndex = 0;
  let match;
  const regex = new RegExp(URL_REGEX.source, URL_REGEX.flags);
  while ((match = regex.exec(text)) !== null) {
    if (match.index > lastIndex) {
      parts.push(text.slice(lastIndex, match.index));
    }
    const url = match[0];
    let href = url;
    if (!/^https?:\/\//i.test(href)) {
      href = `https://${href}`;
    }
    parts.push(
      <a
        key={match.index}
        href={href}
        target="_blank"
        rel="noopener noreferrer"
        className={cn("underline break-all", linkClassName)}
        onClick={(e) => e.stopPropagation()}
      >
        {url}
      </a>
    );
    lastIndex = match.index + url.length;
  }
  if (lastIndex < text.length) {
    parts.push(text.slice(lastIndex));
  }
  return parts;
}

function TimeDivider({ time, isDesktop = false }: { time: string; isDesktop?: boolean }) {
  if (isDesktop) {
    return (
      <div className="flex items-center justify-center py-4">
        <span className="text-xs text-gray-400 bg-gray-100 px-3 py-1 rounded-full">
          {formatChatTime(time)}
        </span>
      </div>
    );
  }
  return (
    <div className="flex items-center justify-center py-4">
      <span className="text-xs text-gray-400">{formatChatTime(time)}</span>
    </div>
  );
}

function Avatar({ src, alt, onClick }: { src?: string; alt: string; onClick?: () => void }) {
  return (
    <img
      src={src || "https://api.dicebear.com/7.x/avataaars/svg?seed=" + alt}
      alt={alt}
      onClick={onClick}
      className={cn(
        "w-9 h-9 rounded-full object-cover bg-gray-100 flex-shrink-0",
        onClick ? "cursor-pointer" : ""
      )}
    />
  );
}

const WAVE_BAR_COUNT = 40;
// 文本消息单行最大宽度，语音气泡不应超过此值。
const TEXT_MESSAGE_MAX_WIDTH = 260;
const VOICE_BASE_WIDTH = 92;
const VOICE_TIER_1_SECONDS = 10;
const VOICE_TIER_1_PX_PER_SECOND = 1;
const VOICE_MAX_DURATION_SECONDS = 80;

function seededRandom(seed: string) {
  let h = 2166136261;
  for (let i = 0; i < seed.length; i++) {
    h ^= seed.charCodeAt(i);
    h += (h << 1) + (h << 4) + (h << 7) + (h << 8) + (h << 24);
  }
  return () => {
    h |= 0;
    h = (h + 0x6d2b79f5) | 0;
    let t = Math.imul(h ^ (h >>> 15), 1 | h);
    t ^= t + Math.imul(t ^ (t >>> 7), 61 | t);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function usePlaybackWaveform(seed: string, playing: boolean, count = 18) {
  const randRef = useRef(seededRandom(seed));
  const baseRef = useRef<number[]>([]);
  if (baseRef.current.length !== count) {
    baseRef.current = Array.from(
      { length: count },
      () => 22 + randRef.current() * 54
    );
  }
  const [bars, setBars] = useState(baseRef.current);

  useEffect(() => {
    if (!playing) {
      setBars(baseRef.current);
      return;
    }
    let id = 0;
    const tick = () => {
      setBars(
        baseRef.current.map((h) =>
          Math.max(12, Math.min(92, h + Math.random() * 50 - 25))
        )
      );
      id = window.setTimeout(tick, 100);
    };
    tick();
    return () => clearTimeout(id);
  }, [playing, count]);

  return bars;
}

function useVoiceWaveform() {
  const [bars, setBars] = useState<number[]>(
    Array.from({ length: WAVE_BAR_COUNT }, () => 20)
  );
  const requestRef = useRef<number | null>(null);
  const analyserRef = useRef<AnalyserNode | null>(null);
  const dataRef = useRef<Uint8Array | null>(null);
  const smoothedRef = useRef<number[]>(
    Array.from({ length: WAVE_BAR_COUNT }, () => 20)
  );
  // 给每个柱子独立的呼吸相位，避免所有柱子同起同落。
  const phaseRef = useRef<number[]>(
    Array.from({ length: WAVE_BAR_COUNT }, (_, i) => i * 0.35)
  );

  const start = useCallback((analyser?: AnalyserNode) => {
    if (!analyser) return;
    analyserRef.current = analyser;
    // 使用频域数据，对音量变化更敏感，更适合做波形可视化。
    dataRef.current = new Uint8Array(analyser.frequencyBinCount as number);
    smoothedRef.current = Array.from({ length: WAVE_BAR_COUNT }, () => 20);

    const tick = () => {
      if (dataRef.current && analyserRef.current) {
        const data = dataRef.current;
        analyserRef.current.getByteFrequencyData(data);
        const smoothing = 0.35;
        const breathSpeed = 0.12;
        const targets: number[] = [];

        // 计算整体音量，用于控制呼吸幅度。
        let total = 0;
        for (let j = 0; j < data.length; j++) {
          total += data[j];
        }
        const avg = total / data.length;
        const energy = avg / 255;

        for (let i = 0; i < WAVE_BAR_COUNT; i++) {
          // 低频到高频均匀采样，人声主要集中在中低频。
          const t = i / (WAVE_BAR_COUNT - 1);
          const from = Math.floor(t * t * data.length * 0.6);
          const to = Math.min(data.length, from + Math.max(1, Math.floor(data.length / WAVE_BAR_COUNT / 2)));
          let sum = 0;
          let count = 0;
          for (let j = from; j < to; j++) {
            sum += data[j];
            count++;
          }
          const raw = count > 0 ? sum / count / 255 : 0;
          // 增强增益，让轻声也有明显跳动。
          const base = Math.max(0, raw * 140 + energy * 50);
          // 叠加缓慢正弦呼吸，相位随索引错开，不说话时也有轻微起伏。
          phaseRef.current[i] += breathSpeed + energy * 0.25;
          const breath = (Math.sin(phaseRef.current[i]) * 0.5 + 0.5) * (18 + energy * 55);
          const target = Math.max(16, Math.min(96, base + breath));
          targets.push(target);
        }

        smoothedRef.current = smoothedRef.current.map(
          (prev, i) => prev + (targets[i] - prev) * smoothing
        );
        setBars([...smoothedRef.current]);
        requestRef.current = requestAnimationFrame(tick);
      }
    };
    requestRef.current = requestAnimationFrame(tick);
  }, []);

  const stop = useCallback(() => {
    if (requestRef.current) cancelAnimationFrame(requestRef.current);
    requestRef.current = null;
    analyserRef.current = null;
    dataRef.current = null;
    smoothedRef.current = Array.from({ length: WAVE_BAR_COUNT }, () => 20);
    setBars(Array.from({ length: WAVE_BAR_COUNT }, () => 20));
  }, []);

  useEffect(() => () => stop(), [stop]);

  return { bars, start, stop };
}

const VoiceWaveform = memo(
  function VoiceWaveform({
    bars,
    isPlaying,
    progress = 0,
    className,
    barCount = WAVE_BAR_COUNT,
  }: {
    bars?: number[];
    isPlaying?: boolean;
    progress?: number;
    className?: string;
    barCount?: number;
  }) {
    const displayBars =
      bars ?? Array.from({ length: barCount }, () => 20);
    const count = displayBars.length;
    const playIndex = Math.max(
      0,
      Math.min(count - 1, Math.floor(progress * count))
    );
    return (
      <div
        className={cn(
          "flex items-center gap-[3px] h-5 w-full",
          className
        )}
      >
        {displayBars.map((h, i) => {
          const played = isPlaying && i <= playIndex;
          return (
            <div
              key={i}
              className={cn(
                "flex-1 min-w-[2px] rounded-full bg-current transition-[height] duration-75",
                played && "opacity-60"
              )}
              style={{ height: `${h}%` }}
            />
          );
        })}
      </div>
    );
  },
  (prev, next) => {
    if (prev.isPlaying !== next.isPlaying) return false;
    if (prev.progress !== next.progress) return false;
    if (prev.barCount !== next.barCount) return false;
    if (prev.bars?.length !== next.bars?.length) return false;
    if (prev.bars && next.bars) {
      for (let i = 0; i < prev.bars.length; i++) {
        if (prev.bars[i] !== next.bars[i]) return false;
      }
    }
    return true;
  }
);

function voiceBubbleWidth(duration?: number, maxWidth?: number): string {
  const cap = maxWidth || TEXT_MESSAGE_MAX_WIDTH;
  const d = Math.max(0, duration || 0);
  // 1-10 秒每秒加 1px；超过 10 秒在剩余宽度内线性分配。
  let width = VOICE_BASE_WIDTH + Math.min(d, VOICE_TIER_1_SECONDS) * VOICE_TIER_1_PX_PER_SECOND;
  if (d > VOICE_TIER_1_SECONDS) {
    const remainingSeconds = d - VOICE_TIER_1_SECONDS;
    const remainingWidth = cap - width;
    width +=
      remainingSeconds *
      (remainingWidth / (VOICE_MAX_DURATION_SECONDS - VOICE_TIER_1_SECONDS));
  }
  width = Math.max(VOICE_BASE_WIDTH, Math.min(cap, width));
  return `${Math.round(width)}px`;
}

function Bubble({
  isMe,
  children,
  className,
  noPadding,
  forceWhite,
}: {
  isMe: boolean;
  children: React.ReactNode;
  className?: string;
  noPadding?: boolean;
  forceWhite?: boolean;
}) {
  const isGradientMe = !forceWhite && isMe;
  return (
    <div
      className={cn(
        "relative rounded-[9px] break-words min-w-fit",
        forceWhite
          ? "bg-white text-gray-900 border border-gray-100"
          : isMe
            ? "text-white"
            : "bg-[#FAFAFA] text-gray-900 border border-gray-100",
        !noPadding && "px-3 py-2",
        className
      )}
      style={
        isGradientMe
          ? {
              background:
                "linear-gradient(to bottom right, rgba(91, 206, 250, 0.88), rgba(245, 169, 184, 0.88))",
            }
          : undefined
      }
    >
      {children}
    </div>
  );
}

function TextMessage({ message, isMe }: { message: Message; isMe?: boolean }) {
  const linkClass = isMe
    ? "text-white"
    : "text-transparent bg-clip-text bg-gradient-to-r from-[#5BCEFA] to-[#F5A9B8]";
  return (
    <p className="text-sm leading-relaxed whitespace-pre-wrap">
      {message.content ? renderTextWithLinks(message.content, linkClass) : null}
    </p>
  );
}

function VoiceMessage({
  message,
  maxWidth,
}: {
  message: Message;
  maxWidth?: number;
}) {
  const [playing, setPlaying] = useState(false);
  const [progress, setProgress] = useState(0);
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const url = getMediaUrl(message.extra?.url || message.content);
  const waveformBars = usePlaybackWaveform(
    url || String(message.id) || String(message.localId),
    playing,
    18
  );

  useEffect(() => {
    if (!url) return;
    const audio = new Audio(url);
    audioRef.current = audio;
    const onEnded = () => {
      setPlaying(false);
      setProgress(0);
    };
    const onTimeUpdate = () => {
      const total = audio.duration || message.duration || 1;
      setProgress(total > 0 ? audio.currentTime / total : 0);
    };
    const onPause = () => setPlaying(false);
    const onPlay = () => setPlaying(true);
    audio.addEventListener("ended", onEnded);
    audio.addEventListener("timeupdate", onTimeUpdate);
    audio.addEventListener("pause", onPause);
    audio.addEventListener("play", onPlay);
    return () => {
      audio.pause();
      audio.src = "";
      audio.removeEventListener("ended", onEnded);
      audio.removeEventListener("timeupdate", onTimeUpdate);
      audio.removeEventListener("pause", onPause);
      audio.removeEventListener("play", onPlay);
      audioRef.current = null;
    };
  }, [url, message.duration]);

  const toggle = useCallback(() => {
    const audio = audioRef.current;
    if (!audio) return;
    if (audio.paused) {
      document
        .querySelectorAll("audio")
        .forEach((a) => (a !== audio ? a.pause() : null));
      audio.play().catch(() => {});
    } else {
      audio.pause();
    }
  }, []);

  return (
    <div
      className="flex items-center gap-2 max-w-full min-w-[96px]"
      style={{
        width: voiceBubbleWidth(message.duration, maxWidth),
        maxWidth: "100%",
      }}
    >
      <button
        type="button"
        onClick={toggle}
        className="w-7 h-7 rounded-full border border-current flex items-center justify-center flex-shrink-0"
      >
        {playing ? (
          <Pause className="w-3.5 h-3.5" strokeWidth={1.8} />
        ) : (
          <Play className="w-3.5 h-3.5 ml-0.5" strokeWidth={1.8} />
        )}
      </button>
      <div className="flex-1 min-w-0 pr-2 overflow-hidden">
        <VoiceWaveform
          bars={waveformBars}
          isPlaying={playing}
          progress={progress}
          barCount={18}
        />
      </div>
      <span className="text-xs opacity-80 flex-shrink-0">
        {formatDuration(message.duration)}
      </span>
    </div>
  );
}

function CallMessage({ message }: { message: Message }) {
  if (!message.callMeta) return null;
  const { callType, result, duration } = message.callMeta;
  const isVideo = callType === "video";
  const Icon = isVideo ? VideoIcon : PhoneCall;
  let text = "";
  if (result === "connected") {
    text = duration
      ? `${isVideo ? "视频通话" : "语音通话"} ${duration}`
      : isVideo
        ? "视频通话"
        : "语音通话";
  } else if (result === "missed") {
    text = isVideo ? "未接视频通话" : "未接语音通话";
  } else {
    text = isVideo ? "视频通话 对方拒绝" : "语音通话 对方拒绝";
  }
  return (
    <div className="flex items-center gap-2">
      <Icon className="w-5 h-5" strokeWidth={1.5} />
      <span className="text-sm">{text}</span>
    </div>
  );
}

function ExpiredPlaceholder({ label }: { label: string }) {
  return (
    <div className="flex flex-col items-center justify-center w-full h-full bg-gray-100 text-gray-400 rounded-[9px]">
      <AlertCircle className="w-8 h-8 mb-1" strokeWidth={1.5} />
      <span className="text-xs">{label}</span>
    </div>
  );
}

function MediaUploadOverlay({ progress }: { progress?: number }) {
  const pct = progress ?? 0;
  return (
    <div className="absolute inset-0 bg-black/50 flex items-center justify-center rounded-[9px]">
      <span className="text-sm font-medium text-white">{pct}%</span>
    </div>
  );
}

function ImageMessage({ message }: { message: Message }) {
  const [expired, setExpired] = useState(false);
  const url = getMediaUrl(message.extra?.url || message.content);
  // 缩略图优先用后端生成的小尺寸图，缺失时回退原图
  const thumbUrl = getMediaUrl(message.extra?.thumb_url) || url;
  const isSending = message.status === "sending";
  const thumbRef = useRef<HTMLImageElement>(null);
  const [preview, setPreview] = useState(false);
  const [originRect, setOriginRect] = useState<
    { left: number; top: number; width: number; height: number } | null
  >(null);
  // 根据原图横屏/竖屏比例同比缩放，避免裁剪成方形
  const [natSize, setNatSize] = useState<{ w: number; h: number } | null>(null);
  const MAX_W = 160;
  const MAX_H = 200;

  const openPreview = () => {
    if (isSending) return;
    const el = thumbRef.current;
    if (el) {
      const r = el.getBoundingClientRect();
      setOriginRect({ left: r.left, top: r.top, width: r.width, height: r.height });
    }
    setPreview(true);
  };

  const displayStyle = natSize
    ? (() => {
        const ratio = Math.min(MAX_W / natSize.w, MAX_H / natSize.h, 1);
        return { width: Math.round(natSize.w * ratio), height: Math.round(natSize.h * ratio) };
      })()
    : { width: MAX_W, height: MAX_H };

  if (expired || !url) {
    return (
      <div className="rounded-[9px] overflow-hidden" style={{ width: MAX_W, height: MAX_H }}>
        <ExpiredPlaceholder label="图片已被清理" />
      </div>
    );
  }

  return (
    <>
      <div
        className="relative rounded-[9px] overflow-hidden bg-gray-100 cursor-pointer active:opacity-90"
        style={displayStyle}
        onClick={openPreview}
      >
        <img
          ref={thumbRef}
          src={thumbUrl}
          alt="图片"
          className="w-full h-full object-cover"
          loading="lazy"
          onLoad={(e) => {
            const img = e.currentTarget;
            if (img.naturalWidth && img.naturalHeight) {
              setNatSize({ w: img.naturalWidth, h: img.naturalHeight });
            }
          }}
          onError={() => setExpired(true)}
        />
        {isSending && <MediaUploadOverlay progress={message.progress} />}
      </div>
      {preview && url && (
        <MediaPreview
          visible={preview}
          type="image"
          url={url}
          originRect={originRect}
          onClose={() => setPreview(false)}
        />
      )}
    </>
  );
}

function VideoMessage({ message }: { message: Message }) {
  const [expired, setExpired] = useState(false);
  const [poster, setPoster] = useState<string | undefined>(
    (message.extra?.poster as string) || undefined
  );
  const url = getMediaUrl(message.extra?.url || message.content);
  const isSending = message.status === "sending";
  const videoRef = useRef<HTMLVideoElement>(null);
  const thumbWrapRef = useRef<HTMLDivElement>(null);
  const prevIsSending = useRef(isSending);
  const playWhenReadyRef = useRef(false);
  const [preview, setPreview] = useState(false);
  const [originRect, setOriginRect] = useState<
    { left: number; top: number; width: number; height: number } | null
  >(null);

  useEffect(() => {
    if (!url || poster) return;
    let cancelled = false;
    const video = document.createElement("video");
    video.muted = true;
    video.playsInline = true;
    video.preload = "metadata";
    video.onloadedmetadata = () => {
      if (!video.videoWidth || !video.videoHeight) return;
      video.currentTime = 0.1;
    };
    video.onseeked = () => {
      if (cancelled) return;
      const canvas = document.createElement("canvas");
      canvas.width = video.videoWidth;
      canvas.height = video.videoHeight;
      const ctx = canvas.getContext("2d");
      if (!ctx) return;
      ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
      try {
        setPoster(canvas.toDataURL("image/jpeg", 0.8));
      } catch {
        // ignore
      }
    };
    video.onerror = () => {};
    video.src = url;
    video.load();
    return () => {
      cancelled = true;
      video.src = "";
      video.load();
    };
  }, [url, poster]);

  // Auto-play once the video finishes sending.
  useEffect(() => {
    if (prevIsSending.current && !isSending) {
      playWhenReadyRef.current = true;
      videoRef.current?.play().catch(() => {});
    }
    prevIsSending.current = isSending;
  }, [isSending]);

  const openPreview = () => {
    if (isSending) return;
    const el = thumbWrapRef.current;
    if (el) {
      const r = el.getBoundingClientRect();
      setOriginRect({ left: r.left, top: r.top, width: r.width, height: r.height });
    }
    // 暂停缩略图视频，避免与预览同时播放
    videoRef.current?.pause();
    setPreview(true);
  };

  if (expired || !url) {
    return (
      <div className="rounded-[9px] overflow-hidden max-w-[240px] aspect-video">
        <ExpiredPlaceholder label="视频已被清理" />
      </div>
    );
  }

  return (
    <>
      <div
        ref={thumbWrapRef}
        className="relative rounded-[9px] overflow-hidden max-w-[240px] bg-black cursor-pointer active:opacity-90"
        onClick={openPreview}
      >
        <video
          ref={videoRef}
          src={url}
          poster={poster}
          className="w-full h-auto object-cover"
          preload="metadata"
          muted
          playsInline
          onError={() => setExpired(true)}
          onCanPlay={() => {
            if (playWhenReadyRef.current) {
              videoRef.current?.play().catch(() => {});
              playWhenReadyRef.current = false;
            }
          }}
        />
        {isSending && <MediaUploadOverlay progress={message.progress} />}
      </div>
      {preview && url && (
        <MediaPreview
          visible={preview}
          type="video"
          url={url}
          poster={poster}
          originRect={originRect}
          onClose={() => setPreview(false)}
        />
      )}
    </>
  );
}

function FileMessage({ message }: { message: Message }) {
  const url = getMediaUrl(message.extra?.url as string | undefined);
  const name = (message.extra?.name as string) || message.content || "文件";
  const size = formatFileSize(message.extra?.size as number | undefined);
  const isSending = message.status === "sending";
  const isFailed = message.status === "failed";
  const isSent = message.status === "sent";
  const fileType = name.split(".").pop() || "";

  const statusLabel = isSending
    ? "发送中"
    : isFailed
      ? "发送失败"
      : isSent
        ? "已发送"
        : "";
  const progress = Math.max(message.progress ?? 0, 2);

  return (
    <a
      href={url}
      target="_blank"
      rel="noopener noreferrer"
      className="flex items-start gap-3 min-w-[180px] max-w-[260px]"
      onClick={(e) => !url && e.preventDefault()}
    >
      <div className="flex-shrink-0 text-[#5BCEFA]">{getFileIcon(fileType)}</div>
      <div className="flex-1 min-w-0 flex flex-col">
        <p className="text-sm font-medium text-gray-900 truncate">{name}</p>
        <p
          className={cn(
            "text-xs mt-0.5",
            isFailed ? "text-red-500" : "text-gray-500"
          )}
        >
          {size}
          {statusLabel && `/${statusLabel}`}
        </p>
        {isSending && (
          <div className="relative mt-auto pt-2 w-[96%] mx-auto h-2 rounded-full overflow-hidden">
            {/* Full-width flowing gradient track */}
            <div className="absolute inset-0 progress-flow" />
            {/* Gray overlay shrinks from right to reveal progress */}
            <div
              className="absolute top-0 right-0 h-full bg-gray-100 transition-[width] duration-200"
              style={{ width: `${100 - progress}%` }}
            />
          </div>
        )}
      </div>
    </a>
  );
}

function ShareMessage({ message }: { message: Message }) {
  const meta = message.shareMeta;
  if (!meta) return null;
  return (
    <div className="w-[240px] p-3 border border-gray-200 rounded-[10px] bg-white">
      {meta.cover && (
        <div className="rounded-lg overflow-hidden mb-2.5">
          <img
            src={meta.cover}
            alt={meta.title}
            className="w-full h-24 object-cover"
            loading="lazy"
          />
        </div>
      )}
      <h3 className="text-sm font-semibold text-gray-900 leading-tight line-clamp-2">
        {meta.title}
      </h3>
      {meta.desc && (
        <p className="mt-1 text-xs text-gray-500 leading-snug line-clamp-2">
          {meta.desc}
        </p>
      )}
      {meta.tags && meta.tags.length > 0 && (
        <div className="mt-2 flex flex-wrap gap-1.5">
          {meta.tags.map((tag) => (
            <span
              key={tag}
              className="inline-flex items-center px-2 py-0.5 rounded text-[10px] bg-gray-100 text-gray-600"
            >
              {tag}
            </span>
          ))}
        </div>
      )}
    </div>
  );
}

function NameCardMessage({ message }: { message: Message }) {
  const meta = message.nameCardMeta;
  if (!meta) return null;
  return (
    <div className="flex items-center gap-3 min-w-[160px] px-3 py-2 rounded-[9px] bg-white border border-gray-100">
      <img
        src={meta.avatar}
        alt={meta.nickname}
        className="w-10 h-10 rounded-full object-cover bg-gray-100 flex-shrink-0"
      />
      <span className="text-sm font-medium text-gray-900 truncate">{meta.nickname}</span>
    </div>
  );
}

function SystemMessage({
  message,
  currentUser,
}: {
  message: Message;
  currentUser?: { id?: string | number } | null;
}) {
  const extra = message.extra || {};

  // 组建营地提示：仅创建者可见
  if (extra.is_creation_notice && extra.creator_id != null) {
    if (String(extra.creator_id) !== String(currentUser?.id)) {
      return null;
    }
  }

  // 新人加入营地提示：申请者视角与他人视角区分
  const joinUserId = extra.join_user_id;
  const groupName = extra.group_name;
  let content = message.content;
  if (joinUserId != null && currentUser?.id != null) {
    const isMe = String(joinUserId) === String(currentUser.id);
    if (isMe && groupName) {
      content = `您已加入${groupName}营地，快来和大家分享您的故事趴！`;
    }
  }

  return (
    <div className="flex flex-col items-center py-2 px-4">
      <span className="text-xs text-gray-400 mb-2">
        {formatChatTime(message.timestamp)}
      </span>
      <span className="text-xs text-gray-500">{content}</span>
    </div>
  );
}

function MessageContent({
  message,
  currentUser,
}: {
  message: Message;
  currentUser?: { id?: string | number } | null;
}) {
  switch (message.type) {
    case "system":
      return <SystemMessage message={message} currentUser={currentUser} />;
    case "text":
    case "link":
      return <TextMessage message={message} isMe={message.isMe} />;
    case "voice":
      return <VoiceMessage message={message} />;
    case "call":
      return <CallMessage message={message} />;
    case "image":
      return <ImageMessage message={message} />;
    case "video":
      return <VideoMessage message={message} />;
    case "file":
      return <FileMessage message={message} />;
    case "share":
      return <ShareMessage message={message} />;
    case "nameCard":
      return <NameCardMessage message={message} />;
    default:
      return <TextMessage message={message} />;
  }
}

function ChatMessageItem({
  message,
  chatType,
  currentUser,
  onUserProfileClick,
  isDesktop = false,
}: {
  message: Message;
  chatType: ChatType;
  currentUser: { id?: string | number; avatar: string; nickname: string };
  onUserProfileClick?: (userId: number | string) => void;
  isDesktop?: boolean;
}) {
  if (message.type === "system") {
    return <SystemMessage message={message} currentUser={currentUser} />;
  }

  const isMe = message.isMe;
  const isGroup = chatType === "group";
  const isFile = message.type === "file";
  const isMedia = ["image", "video"].includes(message.type);
  const noBubble = ["image", "video", "share", "nameCard"].includes(message.type);
  const bubbleContent = <MessageContent message={message} currentUser={currentUser} />;

  const mediaFailed = isMedia && message.status === "failed";
  const mediaStatusNode = mediaFailed ? (
    <AlertCircle className="w-5 h-5 mt-1.5 text-red-500" />
  ) : null;

  // Sending spinner is shown outside the message bubble at the bottom-left.
  // File messages show their own progress bar instead.
  // Media failure is shown below the media thumbnail.
  const statusNode =
    isMe && message.status === "sending" && !isFile ? (
      <Loader2 className="w-5 h-5 text-gray-400 animate-spin flex-shrink-0" />
    ) : isMe && message.status === "failed" && !isMedia ? (
      <AlertCircle className="w-5 h-5 text-red-500 flex-shrink-0" />
    ) : null;

  const contentWrapper = isMedia ? (
    <div className={cn(
      "flex flex-col items-center",
      isDesktop ? "max-w-[600px]" : "max-w-[240px]"
    )}>
      {bubbleContent}
      {mediaStatusNode}
    </div>
  ) : noBubble ? (
    <div className={cn("max-w-[calc(100%-4.5rem)]", isDesktop && "max-w-[600px]")}>{bubbleContent}</div>
  ) : (
    <Bubble isMe={isMe} forceWhite={isFile} className={cn("max-w-[calc(100%-4.5rem)]", isDesktop && "max-w-[600px]")}>
      {bubbleContent}
    </Bubble>
  );

  if (isMe) {
    return (
      <div className={cn(
        "flex items-start justify-end gap-2",
        isDesktop ? "px-6 py-3" : "px-4 py-2"
      )}>
        <div className="flex flex-1 items-end justify-end gap-2">
          {statusNode}
          <div className={cn("max-w-[calc(100%-4.5rem)]", isDesktop && "max-w-[700px]")}>
            {contentWrapper}
          </div>
        </div>
        <Avatar src={currentUser.avatar} alt={currentUser.nickname} />
      </div>
    );
  }

  if (isGroup) {
    return (
      <div className={cn(
        "flex items-start gap-2",
        isDesktop ? "px-6 py-3" : "px-4 py-2"
      )}>
        <Avatar
          src={message.senderAvatar}
          alt={message.senderName}
          onClick={
            onUserProfileClick && message.senderId
              ? () => onUserProfileClick(message.senderId)
              : undefined
          }
        />
        <div className={cn("flex flex-col items-start max-w-[calc(100%-4.5rem)]", isDesktop && "max-w-[700px]")}>
          <span className="text-xs text-gray-400 mb-1">{message.senderName}</span>
          {contentWrapper}
        </div>
      </div>
    );
  }

  return (
    <div className={cn(
      "flex items-start gap-2",
      isDesktop ? "px-6 py-3" : "px-4 py-2"
    )}>
      <Avatar
        src={message.senderAvatar}
        alt={message.senderName}
        onClick={
          onUserProfileClick && message.senderId
            ? () => onUserProfileClick(message.senderId)
            : undefined
        }
      />
      <div className={cn("max-w-[calc(100%-4.5rem)]", isDesktop && "max-w-[700px]")}>
        {contentWrapper}
      </div>
    </div>
  );
}

export function ChatPage({ chat, visible, onClose, onUserProfileClick, isDesktop = false }: ChatPageProps) {
  const [isEntering, setIsEntering] = useState(false);
  const [inputValue, setInputValue] = useState("");
  const [keyboardHeight, setKeyboardHeight] = useState(0);
  const [voicePanelOpen, setVoicePanelOpen] = useState(false);
  const [sendMenuOpen, setSendMenuOpen] = useState(false);
  const [sendOnEnter, setSendOnEnter] = useState(true);
  const [inputHeight, setInputHeight] = useState(40);
  const scrollRef = useRef<HTMLDivElement>(null);
  const closeTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const imageInputRef = useRef<HTMLInputElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const sendMenuRef = useRef<HTMLDivElement>(null);
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  const currentUser = useAuthStore((state) => state.user);
  // chat.id 是 `${type}_${conversationId}` 的复合字符串，需要解析出数字 ID。
  const conversationId = chat
    ? Number(chat.id.split("_").pop()) || null
    : null;

  const messages = useMessageStore((state) => {
    if (!conversationId) return EMPTY_MESSAGES;
    return state.messagesByConversation[conversationId] ?? EMPTY_MESSAGES;
  });
  const loadMessages = useMessageStore((state) => state.loadMessages);
  const markRead = useChatStore((state) => state.markRead);
  const sendText = useMessageStore((state) => state.sendText);
  const sendImage = useMessageStore((state) => state.sendImage);
  const sendVideo = useMessageStore((state) => state.sendVideo);
  const sendFile = useMessageStore((state) => state.sendFile);
  const sendVoice = useMessageStore((state) => state.sendVoice);
  const connect = useMessageStore((state) => state.connect);
  const disconnect = useMessageStore((state) => state.disconnect);

  const voiceWaveform = useVoiceWaveform();
  const onRecordingStarted = useCallback(
    (analyser: AnalyserNode) => {
      voiceWaveform.start(analyser);
    },
    [voiceWaveform.start]
  );
  const voiceRecorder = useVoiceRecorder({
    conversationId,
    enabled: voicePanelOpen,
    maxDurationMs: 80_000,
    minDurationMs: 500,
    sendVoice,
    onRecordingStarted,
  });

  useEffect(() => {
    connect();
    return () => disconnect();
  }, [connect, disconnect]);

  useEffect(() => {
    if (!visible || !conversationId) return;
    markRead(conversationId);
    loadMessages(conversationId);
  }, [visible, conversationId, loadMessages, markRead]);

  const initialScrollLockRef = useRef(true);

  // Reset the lock every time the chat page becomes visible so each entry
  // starts pinned to the latest message (the bottom of the list).
  useEffect(() => {
    if (visible) {
      initialScrollLockRef.current = true;
    }
  }, [visible]);

  // Keep the list pinned to the bottom during the initial load window. This
  // ensures we land on the latest message even while images/videos are still
  // loading and expanding the scroll height.
  useLayoutEffect(() => {
    const el = scrollRef.current;
    if (!el || messages.length === 0 || !initialScrollLockRef.current) return;

    const lockToBottom = () => {
      if (!initialScrollLockRef.current || !el) return;
      el.scrollTop = el.scrollHeight;
    };

    lockToBottom();

    // Images and videos change the scroll height as they load; keep forcing
    // the view to the bottom until the initial window expires.
    const observer = new ResizeObserver(lockToBottom);
    observer.observe(el);

    const timer = window.setTimeout(() => {
      initialScrollLockRef.current = false;
      observer.disconnect();
    }, 1500);

    return () => {
      window.clearTimeout(timer);
      observer.disconnect();
    };
  }, [messages, visible]);

  useEffect(() => {
    if (visible) {
      if (closeTimerRef.current) {
        clearTimeout(closeTimerRef.current);
        closeTimerRef.current = null;
      }
      requestAnimationFrame(() => {
        requestAnimationFrame(() => setIsEntering(true));
      });
    } else {
      setIsEntering(false);
      closeTimerRef.current = setTimeout(() => {
        setInputValue("");
      }, 320);
    }
    return () => {
      if (closeTimerRef.current) clearTimeout(closeTimerRef.current);
    };
  }, [visible]);

  useEffect(() => {
    const vv = window.visualViewport;
    if (!vv) return;
    const handleResize = () => {
      const diff = window.innerHeight - vv.height;
      setKeyboardHeight(diff > 80 ? diff : 0);
    };
    vv.addEventListener("resize", handleResize);
    return () => vv.removeEventListener("resize", handleResize);
  }, []);

  useEffect(() => {
    const original = document.body.style.overflow;
    if (visible) {
      document.body.style.overflow = "hidden";
    } else {
      document.body.style.overflow = original;
    }
    return () => {
      document.body.style.overflow = original;
    };
  }, [visible]);

  useEffect(() => {
    const handleOutsideClick = (e: MouseEvent) => {
      if (sendMenuRef.current && !sendMenuRef.current.contains(e.target as Node)) {
        setSendMenuOpen(false);
      }
    };
    if (sendMenuOpen) {
      document.addEventListener('mousedown', handleOutsideClick);
    }
    return () => document.removeEventListener('mousedown', handleOutsideClick);
  }, [sendMenuOpen]);

  const handleInputChange = (e: React.ChangeEvent<HTMLTextAreaElement>) => {
    const value = e.target.value.slice(0, 500);
    setInputValue(value);
    
    // Auto-resize textarea height
    if (textareaRef.current) {
      const newHeight = Math.min(Math.max(40, textareaRef.current.scrollHeight), 70);
      setInputHeight(newHeight);
    }
  };

  const handleSend = async () => {
    const text = inputValue.trim();
    if (!text || !conversationId) return;
    setInputValue("");
    setInputHeight(40);
    await sendText(conversationId, text);
  };

  const handleKeyDown = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === "Enter") {
      if (sendOnEnter) {
        e.preventDefault();
        handleSend();
      } else if (e.ctrlKey) {
        e.preventDefault();
        handleSend();
      }
    }
  };

  const handleImageFileChange = (
    e: React.ChangeEvent<HTMLInputElement>
  ) => {
    const file = e.target.files?.[0];
    if (!file || !conversationId) return;
    if (file.type.startsWith("video/")) {
      sendVideo(conversationId, file);
    } else {
      sendImage(conversationId, file);
    }
    e.target.value = "";
  };

  const handleFileChange = (
    e: React.ChangeEvent<HTMLInputElement>,
    sender: (conversationId: number, file: File) => Promise<void>
  ) => {
    const file = e.target.files?.[0];
    if (!file || !conversationId) return;
    sender(conversationId, file);
    e.target.value = "";
  };

  const voiceReleaseRef = useRef(voiceRecorder.release);
  voiceReleaseRef.current = voiceRecorder.release;

  const handleVoiceClick = useCallback(() => {
    const type = voiceRecorder.state.type;
    if (type === "recording" || type === "requesting_permission") {
      voiceRecorder.stop();
    } else if (type === "recorded") {
      voiceRecorder.send();
    } else {
      voiceRecorder.start();
    }
  }, [voiceRecorder]);

  // 语音面板关闭时释放录音资源。
  useEffect(() => {
    if (!voicePanelOpen) {
      voiceReleaseRef.current();
    }
  }, [voicePanelOpen]);

  const isGroup = chat?.type === "group";
  const title = chat?.name || "";

  const noSelectStyle = {
    WebkitUserSelect: "none" as const,
    WebkitTouchCallout: "none" as const,
    userSelect: "none" as const,
  };

  const isRecording = voiceRecorder.state.type === "recording";
  const isRequesting = voiceRecorder.state.type === "requesting_permission";
  const isRecorded = voiceRecorder.state.type === "recorded";
  const recordingError =
    voiceRecorder.state.type === "error" ? voiceRecorder.state.message : null;
  const isPressed = voiceRecorder.isActive;

  const renderTopBarLeft = () => {
    if (isGroup) {
      return (
        <div className="flex items-center gap-2 flex-1 min-w-0">
          <button
            type="button"
            onClick={onClose}
            className="w-8 h-8 flex items-center justify-center -ml-2"
          >
            <ArrowLeft className="w-5 h-5 text-gray-900" strokeWidth={1.5} />
          </button>
          <div className="flex items-baseline gap-1 min-w-0">
            <h1 className="text-base font-medium text-gray-900 truncate">{title}</h1>
            {chat?.memberCount != null && (
              <span className="text-xs text-gray-400">({chat.memberCount})</span>
            )}
          </div>
        </div>
      );
    }
    return (
      <div className="flex items-center gap-2 flex-1 min-w-0">
        <button
          type="button"
          onClick={onClose}
          className="w-8 h-8 flex items-center justify-center -ml-2"
        >
          <ArrowLeft className="w-5 h-5 text-gray-900" strokeWidth={1.5} />
        </button>
        <button
          type="button"
          onClick={() => {
            if (onUserProfileClick && chat?.senderId) {
              onUserProfileClick(chat.senderId);
            }
          }}
          className="flex items-center gap-2 min-w-0 flex-1"
        >
          <h1 className="text-base font-medium text-gray-900 truncate text-left">
            {title}
          </h1>
        </button>
      </div>
    );
  };

  if (!chat) return null;

  return (
    <div
      className={cn(
        "fixed inset-0 z-[80] bg-white flex flex-col transition-transform duration-300 ease-[cubic-bezier(0.25,0.1,0.25,1)]",
        isEntering ? "translate-x-0" : "translate-x-full"
      )}
    >
      {/* Top bar */}
      {isDesktop ? (
        <div className="flex-shrink-0 flex items-center justify-between px-6 py-3 bg-white border-b border-gray-200">
          <div className="flex items-center gap-3">
            <button
              type="button"
              onClick={onClose}
              className="w-8 h-8 flex items-center justify-center rounded hover:bg-gray-100 transition-colors"
            >
              <ArrowLeft className="w-5 h-5 text-gray-700" strokeWidth={1.5} />
            </button>
            <div className="flex items-center gap-3">
              <Avatar src={chat.avatar} alt={chat.name} />
              <div>
                <h1 className="text-base font-semibold text-gray-900">{chat.name}</h1>
                {chat.type === "group" && (
                  <p className="text-xs text-gray-500">群聊 · {chat.memberCount}人</p>
                )}
              </div>
            </div>
          </div>
          <div className="flex items-center gap-2">
            {!isGroup && (
              <>
                <button type="button" className="w-8 h-8 flex items-center justify-center rounded hover:bg-gray-100 transition-colors">
                  <Phone className="w-4 h-4 text-gray-600" strokeWidth={1.5} />
                </button>
                <button type="button" className="w-8 h-8 flex items-center justify-center rounded hover:bg-gray-100 transition-colors">
                  <Video className="w-4 h-4 text-gray-600" strokeWidth={1.5} />
                </button>
              </>
            )}
            <button type="button" className="w-8 h-8 flex items-center justify-center rounded hover:bg-gray-100 transition-colors">
              <MoreVertical className="w-4 h-4 text-gray-600" strokeWidth={1.5} />
            </button>
          </div>
        </div>
      ) : (
        <div className="flex-shrink-0 flex items-center justify-between px-4 pt-[max(0.75rem,env(safe-area-inset-top))] pb-3 bg-white z-10">
          {renderTopBarLeft()}
          <div className="flex items-center gap-1">
            {!isGroup && (
              <>
                <button type="button" className="w-9 h-9 flex items-center justify-center rounded-full active:bg-gray-100 transition-colors">
                  <Phone className="w-5 h-5 text-gray-700" strokeWidth={1.5} />
                </button>
                <button type="button" className="w-9 h-9 flex items-center justify-center rounded-full active:bg-gray-100 transition-colors">
                  <Video className="w-5 h-5 text-gray-700" strokeWidth={1.5} />
                </button>
              </>
            )}
            <button type="button" className="w-9 h-9 flex items-center justify-center rounded-full active:bg-gray-100 transition-colors">
              <MoreVertical className="w-5 h-5 text-gray-700" strokeWidth={1.5} />
            </button>
          </div>
        </div>
      )}

      {/* Message list */}
      <div
        ref={scrollRef}
        className={cn(
          "flex-1 overflow-y-auto overflow-x-hidden",
          isDesktop ? "px-6 py-4 bg-gray-50" : "scrollbar-hide pt-4"
        )}
      >
        {messages.length === 0 ? (
          <div className="flex items-center justify-center py-12">
            <span className="text-xs text-gray-400">暂无消息</span>
          </div>
        ) : (
          messages.map((msg, index) => {
            const prevMsg = messages[index - 1];
            const showTime =
              msg.type !== "system" &&
              prevMsg &&
              !isSameTimeGroup(msg.timestamp, prevMsg.timestamp);
            return (
              <div key={msg.localId}>
                {showTime && <TimeDivider time={msg.timestamp} isDesktop={isDesktop} />}
                <ChatMessageItem
                  message={msg}
                  chatType={chat.type}
                  currentUser={{
                    id: currentUser?.id,
                    avatar: currentUser?.avatar || "",
                    nickname: currentUser?.nickname || "",
                  }}
                  onUserProfileClick={onUserProfileClick}
                  isDesktop={isDesktop}
                />
              </div>
            );
          })
        )}
        <div className={cn("h-4", isDesktop && "h-8")} />
      </div>

      {/* Backdrop to close voice panel when tapping blank area */}
      {voicePanelOpen && (
        <div
          className="absolute inset-0 z-[15] bg-transparent"
          onClick={() => setVoicePanelOpen(false)}
          aria-hidden="true"
        />
      )}

      {/* Bottom bar */}
      <div
        className={cn(
          "relative flex-shrink-0 z-20 transition-transform duration-200",
          isDesktop ? "bg-gray-50 px-6 py-3" : "bg-white"
        )}
        style={{ transform: `translateY(-${keyboardHeight}px)` }}
      >
        {isDesktop ? (
          <div className="max-w-[860px] mx-auto">
            <div className="bg-white border border-gray-200 rounded-2xl p-4 transition-all duration-200 relative group">
              <div className="absolute inset-0 rounded-2xl opacity-0 group-focus-within:opacity-100 pointer-events-none transition-opacity duration-200" style={{
                background: 'linear-gradient(to right, #5BCEFA, #F5A9B8)',
                padding: '1px',
                borderRadius: 'inherit'
              }}>
                <div className="bg-white rounded-2xl h-full w-full"></div>
              </div>
              <div className="relative">
                <div className="flex items-center gap-3 mb-3">
                  <div className="flex-1 flex items-center min-h-10 px-4 rounded-lg bg-white transition-all duration-200">
                    <textarea
                      ref={textareaRef}
                      value={inputValue}
                      onChange={handleInputChange}
                      onKeyDown={handleKeyDown}
                      placeholder="输入消息..."
                      className="flex-1 bg-transparent text-sm text-gray-900 outline-none placeholder:text-gray-400 resize-none overflow-hidden"
                      style={{ height: `${inputHeight}px`, minHeight: '40px', maxHeight: '70px' }}
                      rows={1}
                    />
                  </div>
                </div>
                <div className="flex items-center gap-3">
                  <button
                    type="button"
                    onClick={() => setVoicePanelOpen((v) => !v)}
                    className={cn(
                      "flex items-center gap-2 px-3 py-2 rounded-lg hover:bg-gray-100 transition-colors",
                      voicePanelOpen && "bg-gray-100"
                    )}
                  >
                    <Mic className="w-4 h-4 text-gray-600" strokeWidth={1.5} />
                    <span className="text-xs text-gray-600">语音</span>
                  </button>
                  <button
                    type="button"
                    onClick={() => imageInputRef.current?.click()}
                    className="flex items-center gap-2 px-3 py-2 rounded-lg hover:bg-gray-100 transition-colors"
                  >
                    <Image className="w-4 h-4 text-gray-600" strokeWidth={1.5} />
                    <span className="text-xs text-gray-600">图片</span>
                  </button>
                  <button
                    type="button"
                    onClick={() => fileInputRef.current?.click()}
                    className="flex items-center gap-2 px-3 py-2 rounded-lg hover:bg-gray-100 transition-colors"
                  >
                    <Paperclip className="w-4 h-4 text-gray-600" strokeWidth={1.5} />
                    <span className="text-xs text-gray-600">文件</span>
                  </button>
                  <button type="button" className="flex items-center gap-2 px-3 py-2 rounded-lg hover:bg-gray-100 transition-colors">
                    <Heart className="w-4 h-4 text-gray-600" strokeWidth={1.5} />
                    <span className="text-xs text-gray-600">表情</span>
                  </button>
                  <button type="button" className="flex items-center gap-2 px-3 py-2 rounded-lg hover:bg-gray-100 transition-colors">
                    <Music2 className="w-4 h-4 text-gray-600" strokeWidth={1.5} />
                    <span className="text-xs text-gray-600">音乐</span>
                  </button>
                  <div className="flex-1"></div>
                  <div className="relative">
                    <div className="flex items-center gap-1 rounded-lg bg-gradient-to-br from-[#5BCEFA] to-[#F5A9B8]">
                      <button
                        type="button"
                        onClick={handleSend}
                        className={cn(
                          "flex-shrink-0 h-10 px-4 text-sm font-medium text-white active:opacity-90 transition-all duration-200",
                          !inputValue.trim() && "opacity-50 cursor-not-allowed"
                        )}
                        disabled={!inputValue.trim()}
                      >
                        发送
                      </button>
                      <span className="text-white font-light">|</span>
                      <button
                        type="button"
                        onClick={(e) => { e.stopPropagation(); setSendMenuOpen(!sendMenuOpen); }}
                        className="h-10 w-8 flex items-center justify-center rounded-lg text-white transition-colors"
                      >
                        <ChevronDown className="w-4 h-4" strokeWidth={1.5} />
                      </button>
                    </div>
                    {sendMenuOpen && (
                      <div ref={sendMenuRef} className="absolute bottom-full right-0 mb-2 bg-white border border-gray-200 rounded-lg shadow-lg py-1 min-w-[160px] z-50">
                        <button
                          type="button"
                          onClick={() => { setSendOnEnter(true); setSendMenuOpen(false); }}
                          className={cn(
                            "w-full px-3 py-2 text-left text-sm hover:bg-gray-50 transition-colors flex items-center justify-between",
                            sendOnEnter && "bg-gray-50"
                          )}
                        >
                          <span className="text-gray-700">按Enter发送</span>
                          {sendOnEnter && <Check className="w-4 h-4 text-gray-600" strokeWidth={1.5} />}
                        </button>
                        <button
                          type="button"
                          onClick={() => { setSendOnEnter(false); setSendMenuOpen(false); }}
                          className={cn(
                            "w-full px-3 py-2 text-left text-sm hover:bg-gray-50 transition-colors flex items-center justify-between",
                            !sendOnEnter && "bg-gray-50"
                          )}
                        >
                          <span className="text-gray-700">按Ctrl+Enter发送</span>
                          {!sendOnEnter && <Check className="w-4 h-4 text-gray-600" strokeWidth={1.5} />}
                        </button>
                      </div>
                    )}
                  </div>
                </div>
              </div>
            </div>
          </div>
        ) : (
          <div className="px-4 pt-2 pb-3">
            <div className="flex items-center gap-2">
              <div className="flex-1 flex items-center h-10 px-3 rounded-md bg-gray-100/60 transition-all duration-200">
                <input
                  type="text"
                  value={inputValue}
                  onChange={(e) => setInputValue(e.target.value.slice(0, 500))}
                  onKeyDown={(e) => {
                    if (e.key === "Enter") {
                      const text = inputValue.trim();
                      if (!text || !conversationId) return;
                      setInputValue("");
                      sendText(conversationId, text);
                    }
                  }}
                  placeholder="说点什么…"
                  className="flex-1 bg-transparent text-sm text-gray-900 outline-none placeholder:text-gray-400"
                />
              </div>
              <button
                type="button"
                onClick={handleSend}
                className={cn(
                  "flex-shrink-0 h-10 px-4 rounded-lg text-sm font-medium text-white bg-gradient-to-br from-[#5BCEFA] to-[#F5A9B8] active:opacity-90 transition-all duration-200 overflow-hidden",
                  inputValue.trim()
                    ? "max-w-24 opacity-100 ml-0"
                    : "max-w-0 opacity-0 ml-0 px-0"
                )}
              >
                传达
              </button>
            </div>
            <div className="flex items-center justify-between mt-3 px-1">
              <button
                type="button"
                onClick={() => setVoicePanelOpen((v) => !v)}
                className={cn(
                  "w-9 h-9 flex items-center justify-center rounded-full active:bg-gray-100 transition-colors",
                  voicePanelOpen && "bg-gray-100"
                )}
              >
                <Mic className="w-5 h-5 text-gray-600" strokeWidth={1.5} />
              </button>
              <button
                type="button"
                onClick={() => imageInputRef.current?.click()}
                className="w-9 h-9 flex items-center justify-center rounded-full active:bg-gray-100 transition-colors"
              >
                <Image className="w-5 h-5 text-gray-600" strokeWidth={1.5} />
              </button>
              <button
                type="button"
                onClick={() => fileInputRef.current?.click()}
                className="w-9 h-9 flex items-center justify-center rounded-full active:bg-gray-100 transition-colors"
              >
                <Paperclip className="w-5 h-5 text-gray-600" strokeWidth={1.5} />
              </button>
              <button type="button" className="w-9 h-9 flex items-center justify-center rounded-full active:bg-gray-100 transition-colors">
                <Heart className="w-5 h-5 text-gray-600" strokeWidth={1.5} />
              </button>
              <button type="button" className="w-9 h-9 flex items-center justify-center rounded-full active:bg-gray-100 transition-colors">
                <Music2 className="w-5 h-5 text-gray-600" strokeWidth={1.5} />
              </button>
            </div>
          </div>
        )}

        {/* Voice panel */}
        <div
          className={cn(
            "overflow-hidden transition-all duration-300 ease-[cubic-bezier(0.25,0.1,0.25,1)] select-none",
            voicePanelOpen ? "max-h-64 opacity-100" : "max-h-0 opacity-0"
          )}
          style={{
            ...noSelectStyle,
            WebkitTapHighlightColor: "transparent",
          }}
        >
          <div
            className="px-4 pt-2 pb-5 select-none"
            style={{
              ...noSelectStyle,
              WebkitTapHighlightColor: "transparent",
            }}
          >
            <div className="flex flex-col items-center select-none" style={noSelectStyle}>
              <span className="text-sm text-gray-500 mb-4 select-none" style={noSelectStyle}>语音消息</span>
              {!navigator.mediaDevices?.getUserMedia && (
                <span className="text-xs text-red-500 mb-2 text-center px-4">
                  当前环境不支持录音（请用 Safari / Chrome 并允许麦克风权限）
                </span>
              )}

              <div className="relative -mx-4 w-[calc(100%+2rem)] h-20 flex items-center justify-center">
                {/* 左侧波形：从左边缘到圆左侧，留一点小间隙 */}
                <div className="flex-1 h-10 flex items-center justify-end overflow-hidden z-0 text-gray-300 pr-2">
                  {isRecording && (
                    <VoiceWaveform bars={voiceWaveform.bars} className="h-8 gap-[4px]" />
                  )}
                </div>

                {/* Recording button */}
                <div
                  role="button"
                  tabIndex={0}
                  aria-label={
                    isRecording || isRequesting
                      ? "停止录音"
                      : isRecorded
                        ? "发送语音"
                        : "点击录制语音"
                  }
                  className="relative z-10 flex-shrink-0 select-none outline-none cursor-pointer"
                  onClick={handleVoiceClick}
                  style={{
                    ...noSelectStyle,
                    WebkitTapHighlightColor: "transparent",
                    touchAction: "none",
                    pointerEvents: "auto",
                  }}
                >
                  <span
                    className={cn(
                      "w-16 h-16 rounded-full porten-bg-gradient flex items-center justify-center shadow-sm transition-all duration-150 select-none pointer-events-none",
                      isPressed && "scale-110"
                    )}
                    style={{
                      ...noSelectStyle,
                      WebkitTapHighlightColor: "transparent",
                      touchAction: "none",
                      opacity: isPressed ? 0.85 : 1,
                      transform: isPressed ? "scale(1.1)" : "scale(1)",
                    }}
                  >
                    {isRecording || isRequesting ? (
                      <Square
                        className="w-7 h-7 text-white pointer-events-none"
                        strokeWidth={1.8}
                      />
                    ) : isRecorded ? (
                      <Check
                        className="w-7 h-7 text-white pointer-events-none"
                        strokeWidth={1.8}
                      />
                    ) : (
                      <Mic
                        className="w-7 h-7 text-white pointer-events-none"
                        strokeWidth={1.8}
                      />
                    )}
                  </span>
                </div>

                {/* 右侧波形：从圆右侧到右边缘，留一点小间隙 */}
                <div className="flex-1 h-10 flex items-center justify-start overflow-hidden z-0 text-gray-300 pl-2">
                  {isRecording && (
                    <VoiceWaveform bars={voiceWaveform.bars} className="h-8 gap-[4px]" />
                  )}
                </div>
              </div>

              <div className="mt-4 text-xs h-4 text-center select-none" style={noSelectStyle}>
                {recordingError ? (
                  <span className="text-red-500 select-none" style={noSelectStyle}>{recordingError}</span>
                ) : isRecording ? (
                  <span className="text-gray-600 select-none" style={noSelectStyle}>
                    正在录制 · {formatDuration(voiceRecorder.duration)}
                  </span>
                ) : isRequesting ? (
                  <span className="text-gray-600 select-none" style={noSelectStyle}>正在开启麦克风…</span>
                ) : isRecorded ? (
                  <span className="text-gray-600 select-none" style={noSelectStyle}>点击发送语音</span>
                ) : (
                  <span className="text-gray-400 select-none" style={noSelectStyle}>点击录制语音</span>
                )}
              </div>
            </div>
          </div>
        </div>

        <div className="h-[max(0px,env(safe-area-inset-bottom))]" />
      </div>

      <input
        ref={imageInputRef}
        type="file"
        accept="image/*,video/*"
        className="hidden"
        onChange={handleImageFileChange}
      />
      <input
        ref={fileInputRef}
        type="file"
        className="hidden"
        onChange={(e) => handleFileChange(e, sendFile)}
      />
    </div>
  );
}
