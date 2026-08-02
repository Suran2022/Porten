import { useEffect, useState } from "react";
import { fetchAssistants } from "@/lib/api";
import { partnerAvatar, partnerName } from "@/data/partnerMock";

interface PortenPartnerCardProps {
  onClick?: () => void;
}

/**
 * Porten 伙伴首页入口卡片：头像 / 名称 / 助手名称 + 未读徽标。
 * 助手名称与未读数从 /assistants 接口取第一个助手。
 */
export function PortenPartnerCard({ onClick }: PortenPartnerCardProps) {
  const [assistantName, setAssistantName] = useState<string>("");
  const [unread, setUnread] = useState<number>(0);

  useEffect(() => {
    let cancelled = false;
    fetchAssistants()
      .then((list) => {
        if (cancelled) return;
        setAssistantName(list[0]?.name ?? "");
        setUnread(list[0]?.unread_count ?? 0);
      })
      .catch(() => {
        if (!cancelled) {
          setAssistantName("");
          setUnread(0);
        }
      });
    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <div
      className="flex items-center gap-3 px-4 py-3 bg-white active:bg-gray-50 transition-colors cursor-pointer"
      onClick={onClick}
    >
      <div className="relative flex-shrink-0">
        {partnerAvatar ? (
          <img
            src={partnerAvatar}
            alt={partnerName}
            className="w-12 h-12 rounded-full object-cover bg-gray-100"
          />
        ) : (
          <div
            className="w-12 h-12 rounded-full bg-gradient-to-br from-[#F5A9B8] to-[#E48BA4] flex items-center justify-center text-white text-lg font-medium"
            aria-label={partnerName}
          >
            {partnerName.trim().charAt(0) || "P"}
          </div>
        )}
      </div>

      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2">
          <h3 className="flex-1 min-w-0 text-base font-medium text-gray-900 truncate">
            {partnerName}
          </h3>
          {unread > 0 ? (
            <span
              aria-label={`${unread} 条未读`}
              className="flex-shrink-0 h-[18px] px-1.5 min-w-[18px] rounded-full bg-red-500 text-white text-[11px] font-medium flex items-center justify-center"
            >
              {unread > 99 ? "99+" : unread}
            </span>
          ) : null}
        </div>
        {assistantName ? (
          <p className="mt-0.5 text-xs text-gray-400 truncate">
            {assistantName}
          </p>
        ) : null}
      </div>
    </div>
  );
}
