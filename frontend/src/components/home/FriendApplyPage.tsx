import { useEffect, useRef, useState } from "react";
import { ArrowLeft } from "lucide-react";
import { cn } from "@/lib/utils";
import { SearchUserResult } from "@/lib/api";
import { useContactStore } from "@/store/contactStore";

interface FriendApplyPageProps {
  visible: boolean;
  user: SearchUserResult | null;
  onClose: () => void;
  onSent: () => void;
}

export function FriendApplyPage({ visible, user, onClose, onSent }: FriendApplyPageProps) {
  const [isEntering, setIsEntering] = useState(false);
  const [message, setMessage] = useState("");
  const [sending, setSending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const closeTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const sendFriendRequest = useContactStore((state) => state.sendFriendRequest);

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
        setMessage("");
      }, 320);
    }
    return () => {
      if (closeTimerRef.current) {
        clearTimeout(closeTimerRef.current);
      }
    };
  }, [visible]);

  const handleSend = async () => {
    if (!user || sending) return;
    setSending(true);
    setError(null);
    try {
      await sendFriendRequest(user.porten_id, message.trim() || undefined);
      onSent();
      onClose();
    } catch (err) {
      console.error("send friend request failed", err);
      setError(err instanceof Error ? err.message : "发送失败，请重试");
    } finally {
      setSending(false);
    }
  };

  return (
    <div
      className={cn(
        "fixed inset-0 z-[70] bg-white flex flex-col transition-transform duration-300 ease-[cubic-bezier(0.25,0.1,0.25,1)]",
        isEntering ? "translate-x-0" : "-translate-x-full"
      )}
    >
      {/* Top bar */}
      <div className="flex-shrink-0 flex items-center justify-between px-4 pt-[max(0.75rem,env(safe-area-inset-top))] pb-3 bg-white z-10">
        <button
          type="button"
          onClick={onClose}
          className="w-8 h-8 flex items-center justify-center -ml-2"
        >
          <ArrowLeft className="w-5 h-5 text-gray-900" strokeWidth={1.5} />
        </button>
        <h1 className="text-base font-medium text-gray-900">建立同胞关系</h1>
        <button
          type="button"
          onClick={handleSend}
          disabled={sending || !user}
          className={cn(
            "text-sm font-medium px-3 py-1 rounded-md transition-colors",
            sending || !user ? "text-gray-400" : "text-[#5BCEFA]"
          )}
        >
          {sending ? "发送中" : "传达"}
        </button>
      </div>

      {/* Main content - fixed, not scrollable */}
      <div className="flex-1 overflow-hidden flex flex-col items-center px-6 pt-10">
        {user && (
          <>
            <img
              src={user.avatar_url}
              alt={user.nickname}
              className="w-24 h-24 rounded-full object-cover bg-gray-100 flex-shrink-0"
            />
            <h2 className="mt-5 text-xl font-medium text-gray-900">{user.nickname}</h2>
            <p className="mt-1 text-sm text-gray-400">Porten ID：{user.porten_id}</p>

            <div className="w-full mt-8">
              <textarea
                value={message}
                onChange={(e) => setMessage(e.target.value)}
                maxLength={200}
                autoComplete="off"
                placeholder="请输入申请留言（选填）"
                className="w-full h-32 p-4 rounded-xl bg-gray-50 text-base text-gray-900 placeholder:text-gray-400 outline-none resize-none"
              />
              <p className="mt-2 text-xs text-gray-400 text-right">{message.length}/200</p>
              {error && (
                <p className="mt-2 text-xs text-red-500 text-center">{error}</p>
              )}
            </div>
          </>
        )}
      </div>
    </div>
  );
}
