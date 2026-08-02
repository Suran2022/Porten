import { useCallback, useEffect, useRef } from "react";

export interface PointerInteractionOptions {
  onPointerDown?: (e: PointerEvent) => void;
  onPointerUp?: (e: PointerEvent) => void;
  onPointerCancel?: (e: PointerEvent) => void;
  onPointerMove?: (e: PointerEvent) => void;
  onPointerLeave?: (e: PointerEvent) => void;
}

export function usePointerInteraction(
  elementRef: React.RefObject<HTMLElement | null>,
  options: PointerInteractionOptions
) {
  const activePointerIdRef = useRef<number | null>(null);
  const optionsRef = useRef(options);

  useEffect(() => {
    optionsRef.current = options;
  }, [options]);

  const isMatchingPointer = useCallback((e: PointerEvent) => {
    return (
      activePointerIdRef.current === null ||
      e.pointerId === activePointerIdRef.current
    );
  }, []);

  useEffect(() => {
    const el = elementRef.current;
    if (!el) return;

    const handlePointerDown = (e: PointerEvent) => {
      if (activePointerIdRef.current !== null) return;
      activePointerIdRef.current = e.pointerId;
      e.preventDefault();
      e.stopPropagation();
      optionsRef.current.onPointerDown?.(e);
    };

    const handlePointerUp = (e: PointerEvent) => {
      if (!isMatchingPointer(e)) return;
      activePointerIdRef.current = null;
      e.stopPropagation();
      optionsRef.current.onPointerUp?.(e);
    };

    const handlePointerCancel = (e: PointerEvent) => {
      if (!isMatchingPointer(e)) return;
      activePointerIdRef.current = null;
      e.stopPropagation();
      optionsRef.current.onPointerCancel?.(e);
    };

    const handlePointerMove = (e: PointerEvent) => {
      if (!isMatchingPointer(e)) return;
      optionsRef.current.onPointerMove?.(e);
    };

    const handlePointerLeave = (e: PointerEvent) => {
      if (!isMatchingPointer(e)) return;
      activePointerIdRef.current = null;
      optionsRef.current.onPointerLeave?.(e);
    };

    const handleContextMenu = (e: Event) => {
      e.preventDefault();
      e.stopPropagation();
    };

    el.addEventListener("pointerdown", handlePointerDown, { passive: false });
    document.addEventListener("pointerup", handlePointerUp, { passive: false });
    document.addEventListener("pointercancel", handlePointerCancel, { passive: false });
    document.addEventListener("pointermove", handlePointerMove, { passive: false });
    el.addEventListener("pointerleave", handlePointerLeave);
    el.addEventListener("contextmenu", handleContextMenu);

    return () => {
      el.removeEventListener("pointerdown", handlePointerDown, { passive: false } as EventListenerOptions);
      document.removeEventListener("pointerup", handlePointerUp, { passive: false } as EventListenerOptions);
      document.removeEventListener("pointercancel", handlePointerCancel, { passive: false } as EventListenerOptions);
      document.removeEventListener("pointermove", handlePointerMove, { passive: false } as EventListenerOptions);
      el.removeEventListener("pointerleave", handlePointerLeave);
      el.removeEventListener("contextmenu", handleContextMenu);
    };
  }, [elementRef, isMatchingPointer]);

  return { activePointerIdRef };
}
