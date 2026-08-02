import { useCallback, useEffect, useRef } from "react";

export interface TouchInteractionOptions {
  onPressStart?: (e: TouchEvent | MouseEvent) => void;
  onPressEnd?: (e: TouchEvent | MouseEvent) => void;
  onPressCancel?: (e: TouchEvent | MouseEvent) => void;
  onPressMove?: (e: TouchEvent | MouseEvent) => void;
}

function getEventPoint(
  e: TouchEvent | MouseEvent
): { clientX: number; clientY: number } | null {
  if ("touches" in e && e.touches.length > 0) {
    return {
      clientX: e.touches[0].clientX,
      clientY: e.touches[0].clientY,
    };
  }
  if ("changedTouches" in e && e.changedTouches.length > 0) {
    return {
      clientX: e.changedTouches[0].clientX,
      clientY: e.changedTouches[0].clientY,
    };
  }
  if ("clientX" in e) {
    return {
      clientX: (e as MouseEvent).clientX,
      clientY: (e as MouseEvent).clientY,
    };
  }
  return null;
}

function isInsideElement(
  el: HTMLElement,
  point: { clientX: number; clientY: number }
): boolean {
  const rect = el.getBoundingClientRect();
  return (
    point.clientX >= rect.left &&
    point.clientX <= rect.right &&
    point.clientY >= rect.top &&
    point.clientY <= rect.bottom
  );
}

export function useTouchInteraction(
  elementRef: React.RefObject<HTMLElement | null>,
  options: TouchInteractionOptions
) {
  const optionsRef = useRef(options);
  const pressedRef = useRef(false);
  const activeIdentifierRef = useRef<number | null>(null);

  useEffect(() => {
    optionsRef.current = options;
  }, [options]);

  useEffect(() => {
    const el = elementRef.current;
    if (!el) return;

    const handleTouchStart = (e: TouchEvent) => {
      if (pressedRef.current) return;
      const touch = e.changedTouches[0];
      if (!touch) return;
      pressedRef.current = true;
      activeIdentifierRef.current = touch.identifier;
      e.preventDefault();
      e.stopPropagation();
      optionsRef.current.onPressStart?.(e);
    };

    const handleTouchEnd = (e: TouchEvent) => {
      if (!pressedRef.current) return;
      const touch = Array.from(e.changedTouches).find(
        (t) => t.identifier === activeIdentifierRef.current
      );
      if (!touch) return;
      pressedRef.current = false;
      activeIdentifierRef.current = null;
      e.preventDefault();
      optionsRef.current.onPressEnd?.(e);
    };

    const handleTouchCancel = (e: TouchEvent) => {
      if (!pressedRef.current) return;
      const touch = Array.from(e.changedTouches).find(
        (t) => t.identifier === activeIdentifierRef.current
      );
      if (!touch) return;
      pressedRef.current = false;
      activeIdentifierRef.current = null;
      e.preventDefault();
      optionsRef.current.onPressCancel?.(e);
    };

    const handleTouchMove = (e: TouchEvent) => {
      if (!pressedRef.current) return;
      const touch = Array.from(e.changedTouches).find(
        (t) => t.identifier === activeIdentifierRef.current
      );
      if (!touch) return;
      e.preventDefault();
      optionsRef.current.onPressMove?.(e);
    };

    const handleMouseDown = (e: MouseEvent) => {
      if (pressedRef.current) return;
      if (e.button !== 0) return;
      pressedRef.current = true;
      e.preventDefault();
      e.stopPropagation();
      optionsRef.current.onPressStart?.(e);
    };

    const handleMouseUp = (e: MouseEvent) => {
      if (!pressedRef.current) return;
      pressedRef.current = false;
      e.preventDefault();
      e.stopPropagation();
      optionsRef.current.onPressEnd?.(e);
    };

    const handleMouseLeave = (e: MouseEvent) => {
      if (!pressedRef.current) return;
      const point = getEventPoint(e);
      if (point && !isInsideElement(el, point)) {
        pressedRef.current = false;
        optionsRef.current.onPressCancel?.(e);
      }
    };

    const handleMouseMove = (e: MouseEvent) => {
      if (!pressedRef.current) return;
      optionsRef.current.onPressMove?.(e);
    };

    const handleContextMenu = (e: Event) => {
      e.preventDefault();
      e.stopPropagation();
    };

    // touchstart 在元素上捕获；touchend/touchcancel/touchmove 在 document 上捕获，
    // 保证手指滑出按钮后仍能正常结束录音。
    el.addEventListener("touchstart", handleTouchStart, { passive: false, capture: true });
    document.addEventListener("touchend", handleTouchEnd, { passive: false, capture: true });
    document.addEventListener("touchcancel", handleTouchCancel, { passive: false, capture: true });
    document.addEventListener("touchmove", handleTouchMove, { passive: false, capture: true });
    el.addEventListener("mousedown", handleMouseDown, { passive: false, capture: true });
    document.addEventListener("mouseup", handleMouseUp, { passive: false, capture: true });
    document.addEventListener("mouseleave", handleMouseLeave);
    document.addEventListener("mousemove", handleMouseMove);
    el.addEventListener("contextmenu", handleContextMenu);

    return () => {
      el.removeEventListener("touchstart", handleTouchStart, { passive: false, capture: true } as EventListenerOptions);
      document.removeEventListener("touchend", handleTouchEnd, { passive: false, capture: true } as EventListenerOptions);
      document.removeEventListener("touchcancel", handleTouchCancel, { passive: false, capture: true } as EventListenerOptions);
      document.removeEventListener("touchmove", handleTouchMove, { passive: false, capture: true } as EventListenerOptions);
      el.removeEventListener("mousedown", handleMouseDown, { passive: false, capture: true } as EventListenerOptions);
      document.removeEventListener("mouseup", handleMouseUp, { passive: false, capture: true } as EventListenerOptions);
      document.removeEventListener("mouseleave", handleMouseLeave);
      document.removeEventListener("mousemove", handleMouseMove);
      el.removeEventListener("contextmenu", handleContextMenu);
    };
  }, [elementRef]);

  return { pressedRef };
}
