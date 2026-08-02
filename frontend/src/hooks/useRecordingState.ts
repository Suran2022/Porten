import { useCallback, useMemo, useRef, useState } from "react";

export type RecordingState =
  | { type: "idle" }
  | { type: "pressing" }
  | { type: "requesting_permission" }
  | { type: "recording"; startTime: number }
  | { type: "recorded"; startTime: number }
  | { type: "finalizing" }
  | { type: "error"; message: string };

export interface RecordingMetrics {
  duration: number;
  startTime: number;
}

export function useRecordingState(maxDuration: number) {
  const [state, setState] = useState<RecordingState>({ type: "idle" });
  const stateTypeRef = useRef<RecordingState["type"]>("idle");
  const [duration, setDuration] = useState(0);
  const metricsRef = useRef<RecordingMetrics>({ duration: 0, startTime: 0 });
  const cancelledRef = useRef(false);

  const isActive =
    state.type === "pressing" ||
    state.type === "requesting_permission" ||
    state.type === "recording";

  const setStateSync = useCallback((next: RecordingState) => {
    stateTypeRef.current = next.type;
    setState(next);
  }, []);

  const startPressing = useCallback(() => {
    cancelledRef.current = false;
    metricsRef.current = { duration: 0, startTime: Date.now() };
    setDuration(0);
    setStateSync({ type: "pressing" });
  }, [setStateSync]);

  const setRequestingPermission = useCallback(() => {
    setStateSync({ type: "requesting_permission" });
  }, [setStateSync]);

  const startRecording = useCallback((startTime: number) => {
    metricsRef.current = { duration: 0, startTime };
    cancelledRef.current = false;
    setDuration(0);
    setStateSync({ type: "recording", startTime });
  }, [setStateSync]);

  const setRecorded = useCallback((startTime: number) => {
    setStateSync({ type: "recorded", startTime });
  }, [setStateSync]);

  const updateDuration = useCallback((nextDuration: number) => {
    const clamped = Math.min(nextDuration, maxDuration);
    metricsRef.current.duration = clamped;
    setDuration(clamped);
  }, [maxDuration]);

  const finalize = useCallback(() => {
    setStateSync({ type: "finalizing" });
  }, [setStateSync]);

  const cancel = useCallback(() => {
    cancelledRef.current = true;
    metricsRef.current = { duration: 0, startTime: 0 };
    setDuration(0);
    setStateSync({ type: "idle" });
  }, [setStateSync]);

  const reset = useCallback((errorMessage?: string) => {
    cancelledRef.current = false;
    metricsRef.current = { duration: 0, startTime: 0 };
    setDuration(0);
    setStateSync(errorMessage ? { type: "error", message: errorMessage } : { type: "idle" });
  }, [setStateSync]);

  const setError = useCallback((message: string) => {
    setStateSync({ type: "error", message });
  }, [setStateSync]);

  const clearError = useCallback(() => {
    if (stateTypeRef.current === "error") {
      setStateSync({ type: "idle" });
    }
  }, [setStateSync]);

  return useMemo(
    () => ({
      state,
      stateTypeRef,
      duration,
      metricsRef,
      cancelledRef,
      isActive,
      startPressing,
      setRequestingPermission,
      startRecording,
      setRecorded,
      updateDuration,
      finalize,
      cancel,
      reset,
      setError,
      clearError,
    }),
    [
      state,
      duration,
      isActive,
      startPressing,
      setRequestingPermission,
      startRecording,
      setRecorded,
      updateDuration,
      finalize,
      cancel,
      reset,
      setError,
      clearError,
    ]
  );
}
