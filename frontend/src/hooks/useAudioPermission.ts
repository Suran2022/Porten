import { useCallback, useEffect, useRef, useState } from "react";

export type PermissionStatus = "unknown" | "granted" | "denied" | "prompt";

export function useAudioPermission(enabled: boolean) {
  const [status, setStatus] = useState<PermissionStatus>("unknown");
  const requestedRef = useRef(false);

  const request = useCallback(async () => {
    if (!navigator.mediaDevices?.getUserMedia) {
      setStatus("denied");
      return "denied" as const;
    }
    if (requestedRef.current && status === "granted") {
      return "granted" as const;
    }

    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      stream.getTracks().forEach((t) => t.stop());
      requestedRef.current = true;
      setStatus("granted");
      return "granted" as const;
    } catch (err) {
      requestedRef.current = true;
      if (err instanceof DOMException) {
        if (err.name === "NotAllowedError" || err.name === "PermissionDeniedError") {
          setStatus("denied");
        } else if (err.name === "NotFoundError" || err.name === "DevicesNotFoundError") {
          setStatus("denied");
        } else {
          setStatus("denied");
        }
      } else {
        setStatus("denied");
      }
      return "denied" as const;
    }
  }, [status]);

  // 当语音面板打开时预请求一次权限。
  useEffect(() => {
    if (!enabled) return;
    if (requestedRef.current) return;
    request();
  }, [enabled, request]);

  return { status, request };
}
