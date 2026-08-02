import { useEffect, useMemo, useRef, useState } from "react";
import { ArrowLeft, Bell } from "lucide-react";
import { cn } from "@/lib/utils";
import { useSystemMessageStore } from "@/store/systemMessageStore";
import { SystemMessageItem } from "@/lib/api";

interface SystemMessagesPageProps {
  visible: boolean;
  onClose: () => void;
}

function formatMessageDate(dateStr: string): string {
  // Backend stores naive UTC datetimes; append Z when no timezone info.
  const normalized =
    /[Zz]|[+-]\d{2}:?\d{2}$/.test(dateStr) ? dateStr : `${dateStr}Z`;
  const date = new Date(normalized);
  if (isNaN(date.getTime())) return "";

  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const target = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  const diffDays = Math.round(
    (today.getTime() - target.getTime()) / (1000 * 60 * 60 * 24)
  );

  if (diffDays === 0) return "今天";
  if (diffDays === 1) return "昨天";
  if (diffDays === 2) return "前天";

  const year = date.getFullYear();
  const month = date.getMonth() + 1;
  const day = date.getDate();

  if (year === now.getFullYear()) {
    return `${month}月${day}日`;
  }
  return `${year}年${month}月${day}日`;
}

function formatTitle(message: SystemMessageItem): string {
  const typeLabel =
    message.message_type === "fix" ? "修复功能问题" : "功能更新";
  return `${message.version} ${typeLabel}`;
}

const URL_RE = /(https?:\/\/[A-Za-z0-9\-._~:/?#[\]@!$&'()*+,;=%]+)/;

function LinkifiedContent({ text }: { text: string }) {
  const parts = text.split(URL_RE);
  return (
    <p className="mt-2 text-sm text-gray-600 leading-relaxed whitespace-pre-wrap">
      {parts.map((part, index) =>
        URL_RE.test(part) ? (
          <a
            key={index}
            href={part}
            target="_blank"
            rel="noopener noreferrer"
            className="inline break-all underline decoration-1 underline-offset-2 decoration-[#F5A9B8] bg-gradient-to-r from-[#5BCEFA] via-[#F5A9B8] to-[#5BCEFA] bg-clip-text text-transparent"
          >
            {part}
          </a>
        ) : (
          <span key={index}>{part}</span>
        )
      )}
    </p>
  );
}

function groupMessagesByDate(
  messages: SystemMessageItem[]
): { date: string; items: SystemMessageItem[] }[] {
  const groups = new Map<string, SystemMessageItem[]>();
  for (const message of messages) {
    const label = formatMessageDate(message.created_at);
    if (!label) continue;
    if (!groups.has(label)) {
      groups.set(label, []);
    }
    groups.get(label)!.push(message);
  }
  return Array.from(groups.entries()).map(([date, items]) => ({ date, items }));
}

function SystemMessageCard({
  message,
  onClick,
}: {
  message: SystemMessageItem;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="w-full text-left bg-white px-4 py-4 active:bg-gray-50 transition-colors"
    >
      <div className="flex items-start justify-between gap-3">
        <div className="flex-1 min-w-0">
          <p className="text-sm font-bold text-gray-900 leading-snug">
            {message.is_custom_title ? message.title : formatTitle(message)}
          </p>
          <LinkifiedContent text={message.content} />
        </div>
        <span
          className={cn(
            "text-xs flex-shrink-0 mt-0.5",
            message.is_read ? "text-gray-400" : "text-red-500"
          )}
        >
          {message.is_read ? "已读" : "未读"}
        </span>
      </div>
    </button>
  );
}

export function SystemMessagesPage({
  visible,
  onClose,
}: SystemMessagesPageProps) {
  const [isEntering, setIsEntering] = useState(false);
  const closeTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const messages = useSystemMessageStore((state) => state.messages);
  const unreadCount = useSystemMessageStore((state) => state.unreadCount);
  const loading = useSystemMessageStore((state) => state.loading);
  const loadMessages = useSystemMessageStore((state) => state.loadMessages);
  const markAsRead = useSystemMessageStore((state) => state.markAsRead);
  const markAllAsRead = useSystemMessageStore((state) => state.markAllAsRead);

  const groupedMessages = useMemo(
    () => groupMessagesByDate(messages),
    [messages]
  );

  useEffect(() => {
    if (visible) {
      loadMessages();
      if (closeTimerRef.current) {
        clearTimeout(closeTimerRef.current);
        closeTimerRef.current = null;
      }
      requestAnimationFrame(() => {
        requestAnimationFrame(() => setIsEntering(true));
      });
    } else {
      setIsEntering(false);
    }
    return () => {
      if (closeTimerRef.current) clearTimeout(closeTimerRef.current);
    };
  }, [visible, loadMessages]);

  const handleMarkAllAsRead = () => {
    if (unreadCount === 0) return;
    markAllAsRead();
  };

  return (
    <div
      className={cn(
        "fixed inset-0 z-[90] bg-[#F5F5F5] flex flex-col transition-transform duration-300 ease-[cubic-bezier(0.25,0.1,0.25,1)]",
        isEntering ? "translate-x-0" : "translate-x-full"
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
        <h1 className="text-base font-medium text-gray-900">官方系统</h1>
        <button
          type="button"
          onClick={handleMarkAllAsRead}
          disabled={unreadCount === 0}
          className={cn(
            "text-sm",
            unreadCount > 0
              ? "text-gray-900 active:text-gray-600"
              : "text-gray-400 cursor-default"
          )}
        >
          全部已读
        </button>
      </div>

      {/* Message list */}
      <div className="flex-1 overflow-y-auto overflow-x-hidden">
        {loading && messages.length === 0 && (
          <div className="flex items-center justify-center py-12">
            <span className="text-xs text-gray-400">加载中…</span>
          </div>
        )}

        {!loading && messages.length === 0 && (
          <div className="flex flex-col items-center justify-center py-20">
            <Bell className="w-12 h-12 text-gray-200 mb-3" strokeWidth={1.5} />
            <span className="text-xs text-gray-400">暂无系统消息</span>
          </div>
        )}

        {groupedMessages.map((group) => (
          <div key={group.date} className="mt-4">
            <div className="px-4 py-2">
              <span className="text-xs text-gray-400">{group.date}</span>
            </div>
            <div className="bg-white">
              {group.items.map((message, index) => (
                <div key={message.id}>
                  {index > 0 && (
                    <div className="mx-4 h-px bg-gray-100" />
                  )}
                  <SystemMessageCard
                    message={message}
                    onClick={() => markAsRead(message.id)}
                  />
                </div>
              ))}
            </div>
          </div>
        ))}

        <div className="h-6" />
      </div>
    </div>
  );
}
