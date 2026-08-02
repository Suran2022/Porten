import { useCallback, useEffect, useMemo, useRef } from "react";
import { useAudioRecorder } from "./useAudioRecorder";
import { useRecordingState } from "./useRecordingState";

export interface UseVoiceRecorderOptions {
  conversationId: number | null;
  enabled: boolean;
  maxDurationMs: number;
  minDurationMs: number;
  sendVoice: (conversationId: number, file: File, duration: number) => void;
  onRecordingStarted?: (analyser: AnalyserNode) => void;
}

function getErrorMessage(err: unknown): string {
  if (err instanceof DOMException) {
    if (err.name === "NotAllowedError" || err.name === "PermissionDeniedError") {
      return "请允许麦克风权限后重试";
    }
    if (err.name === "NotFoundError" || err.name === "DevicesNotFoundError") {
      return "未找到麦克风设备";
    }
    return `录音启动失败：${err.message}`;
  }
  if (err instanceof Error) {
    return `录音启动失败：${err.message}`;
  }
  return "录音启动失败";
}

export function useVoiceRecorder(options: UseVoiceRecorderOptions) {
  const { conversationId, enabled, maxDurationMs, minDurationMs, sendVoice, onRecordingStarted } = options;

  const recordingState = useRecordingState(maxDurationMs / 1000);
  const durationTimerRef = useRef<number | null>(null);
  const recordedBlobRef = useRef<{ blob: Blob; fileName: string; fileType: string } | null>(null);

  const stopDurationTimer = useCallback(() => {
    if (durationTimerRef.current) {
      window.clearInterval(durationTimerRef.current);
      durationTimerRef.current = null;
    }
  }, []);

  const startDurationTimer = useCallback(() => {
    stopDurationTimer();
    durationTimerRef.current = window.setInterval(() => {
      const elapsed = recordingState.metricsRef.current.startTime
        ? Math.floor(
            (Date.now() - recordingState.metricsRef.current.startTime) / 1000
          )
        : 0;
      recordingState.updateDuration(elapsed);
    }, 250);
  }, [recordingState.metricsRef, recordingState.updateDuration, stopDurationTimer]);

  const recorder = useAudioRecorder({
    maxDurationMs,
    onStarted: (analyser) => {
      recordingState.startRecording(Date.now());
      onRecordingStarted?.(analyser);
    },
    onStopped: (blob, fileName, fileType) => {
      stopDurationTimer();
      recordedBlobRef.current = { blob, fileName, fileType };
      recordingState.setRecorded(recordingState.metricsRef.current.startTime || Date.now());
    },
    onError: (err) => {
      stopDurationTimer();
      recordedBlobRef.current = null;
      recordingState.reset(getErrorMessage(err));
    },
  });

  const start = useCallback(() => {
    if (!conversationId || !navigator.mediaDevices?.getUserMedia) {
      recordingState.setError("无法访问麦克风");
      return;
    }
    const currentType = recordingState.stateTypeRef.current;
    if (currentType === "recording" || currentType === "requesting_permission") {
      return;
    }
    // 从 error / recorded / idle 都可以重新进入录制。
    recordingState.reset();
    recordedBlobRef.current = null;
    recordingState.setRequestingPermission();

    navigator.mediaDevices
      .getUserMedia({ audio: true })
      .then((stream) => {
        if (recordingState.stateTypeRef.current !== "requesting_permission") {
          stream.getTracks().forEach((t) => t.stop());
          return;
        }
        return recorder.start(stream);
      })
      .then(() => {
        startDurationTimer();
      })
      .catch((err) => {
        recordingState.reset(getErrorMessage(err));
      });
  }, [
    conversationId,
    recordingState,
    recorder,
    startDurationTimer,
  ]);

  const stop = useCallback(() => {
    if (recordingState.stateTypeRef.current !== "recording") return;
    recorder.stop();
  }, [recorder, recordingState.stateTypeRef]);

  const send = useCallback(async () => {
    const recorded = recordedBlobRef.current;
    if (!recorded || !conversationId) return;

    const usedDuration = recordingState.metricsRef.current.duration;
    const durationSeconds = Math.round(usedDuration);
    if (durationSeconds < minDurationMs / 1000) {
      recordedBlobRef.current = null;
      recordingState.reset("录音时间太短，已取消");
      return;
    }

    const file = new File([recorded.blob], recorded.fileName, { type: recorded.fileType });
    try {
      await sendVoice(conversationId, file, durationSeconds);
      recordedBlobRef.current = null;
      recordingState.reset();
    } catch {
      recordedBlobRef.current = null;
      recordingState.reset("录音保存失败");
    }
  }, [conversationId, minDurationMs, recordingState.metricsRef, recordingState.reset, sendVoice]);

  const cancel = useCallback(
    (reason?: string) => {
      stopDurationTimer();
      recordedBlobRef.current = null;
      recordingState.cancel();
      recorder.cleanup();
      if (reason) {
        recordingState.setError(reason);
      }
    },
    [
      recordingState.cancel,
      recordingState.setError,
      recorder.cleanup,
      stopDurationTimer,
    ]
  );

  const release = useCallback(() => {
    stopDurationTimer();
    recordedBlobRef.current = null;
    recorder.cleanup();
    recordingState.reset();
  }, [recorder.cleanup, recordingState.reset, stopDurationTimer]);

  useEffect(() => {
    return () => {
      release();
    };
  }, [release]);

  return useMemo(
    () => ({
      state: recordingState.state,
      stateTypeRef: recordingState.stateTypeRef,
      duration: recordingState.duration,
      metricsRef: recordingState.metricsRef,
      cancelledRef: recordingState.cancelledRef,
      isActive: recordingState.isActive,
      start,
      stop,
      send,
      cancel,
      release,
    }),
    [
      recordingState.state,
      recordingState.stateTypeRef,
      recordingState.duration,
      recordingState.metricsRef,
      recordingState.cancelledRef,
      recordingState.isActive,
      start,
      stop,
      send,
      cancel,
      release,
    ]
  );
}
