import { useCallback, useRef } from "react";

function writeString(view: DataView, offset: number, string: string) {
  for (let i = 0; i < string.length; i++) {
    view.setUint8(offset + i, string.charCodeAt(i));
  }
}

function floatTo16BitPCM(
  input: Float32Array,
  output: DataView,
  offset: number
) {
  for (let i = 0; i < input.length; i++, offset += 2) {
    const s = Math.max(-1, Math.min(1, input[i]));
    output.setInt16(offset, s < 0 ? s * 0x8000 : s * 0x7fff, true);
  }
}

function encodeWav(
  buffers: Float32Array[],
  sampleRate: number,
  numChannels = 1
): Blob {
  let length = 0;
  buffers.forEach((b) => (length += b.length));
  const dataLength = length * numChannels * 2;
  const buffer = new ArrayBuffer(44 + dataLength);
  const view = new DataView(buffer);

  writeString(view, 0, "RIFF");
  view.setUint32(4, 36 + dataLength, true);
  writeString(view, 8, "WAVE");
  writeString(view, 12, "fmt ");
  view.setUint32(16, 16, true);
  view.setUint16(20, 1, true);
  view.setUint16(22, numChannels, true);
  view.setUint32(24, sampleRate, true);
  view.setUint32(28, sampleRate * numChannels * 2, true);
  view.setUint16(32, numChannels * 2, true);
  view.setUint16(34, 16, true);
  writeString(view, 36, "data");
  view.setUint32(40, dataLength, true);

  let offset = 44;
  buffers.forEach((b) => {
    floatTo16BitPCM(b, view, offset);
    offset += b.length * 2;
  });

  return new Blob([buffer], { type: "audio/wav" });
}

function detectIOS(): boolean {
  const ua = navigator.userAgent;
  return /iPad|iPhone|iPod/.test(ua) && !(window as any).MSStream;
}

export interface AudioRecorderOptions {
  maxDurationMs: number;
  onStarted?: (analyser: AnalyserNode) => void;
  onStopped?: (
    blob: Blob,
    fileName: string,
    fileType: string
  ) => void | Promise<void>;
  onError?: (err: Error) => void;
}

export function useAudioRecorder(options: AudioRecorderOptions) {
  const optionsRef = useRef(options);
  optionsRef.current = options;

  const audioContextRef = useRef<AudioContext | null>(null);
  const analyserRef = useRef<AnalyserNode | null>(null);
  const mediaRecorderRef = useRef<MediaRecorder | null>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const chunksRef = useRef<Blob[]>([]);
  const mimeTypeRef = useRef<string>("");
  const timerRef = useRef<number | null>(null);
  const trackEndedHandlerRef = useRef<(() => void) | null>(null);

  const recordingRef = useRef(false);
  const pcmBuffersRef = useRef<Float32Array[]>([]);
  const processorRef = useRef<ScriptProcessorNode | null>(null);
  const silenceGainRef = useRef<GainNode | null>(null);
  const usePcmOnlyRef = useRef(false);

  const cleanup = useCallback(() => {
    recordingRef.current = false;
    if (timerRef.current) {
      window.clearTimeout(timerRef.current);
      timerRef.current = null;
    }
    if (mediaRecorderRef.current) {
      try {
        if (mediaRecorderRef.current.state !== "inactive") {
          mediaRecorderRef.current.stop();
        }
      } catch {
        // ignore
      }
      mediaRecorderRef.current = null;
    }
    if (processorRef.current) {
      try {
        processorRef.current.disconnect();
      } catch {
        // ignore
      }
      processorRef.current = null;
    }
    if (silenceGainRef.current) {
      try {
        silenceGainRef.current.disconnect();
      } catch {
        // ignore
      }
      silenceGainRef.current = null;
    }
    if (streamRef.current) {
      if (trackEndedHandlerRef.current) {
        streamRef.current
          .getAudioTracks()
          .forEach((t) => t.removeEventListener("ended", trackEndedHandlerRef.current!));
        trackEndedHandlerRef.current = null;
      }
      streamRef.current.getTracks().forEach((t) => t.stop());
      streamRef.current = null;
    }
    if (audioContextRef.current && audioContextRef.current.state !== "closed") {
      audioContextRef.current.close().catch(() => {});
      audioContextRef.current = null;
    }
    analyserRef.current = null;
    chunksRef.current = [];
    pcmBuffersRef.current = [];
    mimeTypeRef.current = "";
    usePcmOnlyRef.current = false;
  }, []);

  const finalize = useCallback(
    (fallbackToWav = false) => {
      if (timerRef.current) {
        window.clearTimeout(timerRef.current);
        timerRef.current = null;
      }

      const actualMimeType =
        mimeTypeRef.current ||
        mediaRecorderRef.current?.mimeType ||
        "audio/webm";
      const mrBlob = new Blob(chunksRef.current, { type: actualMimeType });

      if (
        fallbackToWav &&
        audioContextRef.current &&
        pcmBuffersRef.current.length > 0
      ) {
        const wavBlob = encodeWav(
          pcmBuffersRef.current,
          audioContextRef.current.sampleRate,
          1
        );
        optionsRef.current.onStopped?.(
          wavBlob,
          `voice-${Date.now()}.wav`,
          wavBlob.type
        );
        return;
      }

      const ext = actualMimeType.includes("mp4")
        ? "mp4"
        : actualMimeType.includes("aac")
          ? "aac"
          : actualMimeType.includes("webm")
            ? "webm"
            : actualMimeType.includes("wav")
              ? "wav"
              : "bin";
      optionsRef.current.onStopped?.(
        mrBlob,
        `voice-${Date.now()}.${ext}`,
        mrBlob.type
      );
    },
    [optionsRef, timerRef, mimeTypeRef, mediaRecorderRef, chunksRef, pcmBuffersRef, audioContextRef]
  );

  const stop = useCallback(() => {
    recordingRef.current = false;
    if (timerRef.current) {
      window.clearTimeout(timerRef.current);
      timerRef.current = null;
    }
    if (mediaRecorderRef.current) {
      const recorder = mediaRecorderRef.current;
      try {
        if (recorder.state !== "inactive") {
          recorder.stop();
        }
      } catch {
        // ignore
      }
      // 兜底：如果 onstop 5 秒内没触发，强制清理。
      timerRef.current = window.setTimeout(() => {
        cleanup();
      }, 5000);
    } else {
      // 纯 PCM 模式：直接 finalize 并清理。
      finalize(true);
      cleanup();
    }
  }, [cleanup, finalize]);

  const start = useCallback(
    (stream: MediaStream) => {
      cleanup();
      recordingRef.current = true;
      streamRef.current = stream;

      try {
        const isIOS = detectIOS();
        usePcmOnlyRef.current = isIOS;

        // iOS 上 MediaRecorder 经常能启动但生成空/损坏文件，因此直接走 PCM -> WAV。
        // 其他平台尝试 MediaRecorder，同时录制 PCM 兜底。
        const candidates = [
          "audio/webm;codecs=opus",
          "audio/webm",
          "audio/mp4",
          "audio/aac",
          "audio/wav",
        ];
        const mimeType = isIOS
          ? ""
          : candidates.find((t) => MediaRecorder.isTypeSupported(t)) || "";
        mimeTypeRef.current = mimeType;

        if (mimeType) {
          const recorder = new MediaRecorder(stream, { mimeType });
          mediaRecorderRef.current = recorder;
          chunksRef.current = [];

          recorder.ondataavailable = (e) => {
            if (e.data.size > 0) chunksRef.current.push(e.data);
          };

          recorder.onstop = () => {
            const mrBlob = new Blob(chunksRef.current, {
              type: mimeTypeRef.current || recorder.mimeType || "audio/webm",
            });
            finalize(mrBlob.size < 1024);
          };

          recorder.onerror = () => {
            if (pcmBuffersRef.current.length > 0) {
              finalize(true);
            } else {
              optionsRef.current.onError?.(new Error("MediaRecorder error"));
              cleanup();
            }
          };
        }

        // 监听轨道异常结束（如 iOS 后台回收麦克风），及时清理并提示。
        trackEndedHandlerRef.current = () => {
          optionsRef.current.onError?.(new Error("麦克风被系统中断"));
          stop();
        };
        stream.getAudioTracks().forEach((t) => {
          t.addEventListener("ended", trackEndedHandlerRef.current!);
        });

        // 先立即创建 AudioContext 并启动录音，保证在用户手势上下文内。
        let audioContext = audioContextRef.current;
        if (!audioContext) {
          audioContext = new AudioContext();
          audioContextRef.current = audioContext;
        }
        if (audioContext.state === "suspended") {
          audioContext.resume().catch(() => {});
        }

        const source = audioContext.createMediaStreamSource(stream);

        // 分析仪与录音处理并联，避免串链导致 analyser 数据被节流或优化掉。
        const analyser = audioContext.createAnalyser();
        analyser.fftSize = 1024;
        analyser.smoothingTimeConstant = 0.25;
        analyser.minDecibels = -70;
        analyser.maxDecibels = -10;
        analyserRef.current = analyser;

        // 录制 PCM 用于 iOS WAV 输出或兜底。
        const processor = audioContext.createScriptProcessor(4096, 1, 1);
        const silence = audioContext.createGain();
        silence.gain.value = 0;
        processor.onaudioprocess = (e) => {
          if (!recordingRef.current) return;
          const channel = e.inputBuffer.getChannelData(0);
          pcmBuffersRef.current.push(new Float32Array(channel));
        };
        source.connect(analyser);
        source.connect(processor);
        processor.connect(silence);
        silence.connect(audioContext.destination);
        processorRef.current = processor;
        silenceGainRef.current = silence;

        if (mediaRecorderRef.current) {
          // 使用 1000ms 切片，避免部分浏览器长时间不触发 dataavailable。
          mediaRecorderRef.current.start(1000);
        }

        optionsRef.current.onStarted?.(analyser);

        // 兜底：超过最大时长自动停止。
        timerRef.current = window.setTimeout(() => {
          stop();
        }, optionsRef.current.maxDurationMs);
      } catch (err) {
        cleanup();
        optionsRef.current.onError?.(
          err instanceof Error ? err : new Error(String(err))
        );
      }
    },
    [cleanup, stop, finalize]
  );

  return {
    start,
    stop,
    cleanup,
    analyserRef,
    mediaRecorderRef,
  };
}
