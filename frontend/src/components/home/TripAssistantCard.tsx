import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import tripIcon from "@/assets/trip-icon.svg";
import { fetchTripAssistant } from "@/lib/api";

interface TripAssistantCardProps {
  onClick?: () => void;
}

/**
 * 「我的旅程」功能入口卡片：头像 / 名称 + 「行程安全」标签 + 行程消息徽标。
 * 名称下方展示最近创建的旅程，前缀 [行程助手]：，与 Porten 伙伴入口卡片并列展示。
 *
 * 徽标数与最新旅程摘要来自 /trips/assistant（API 模式）或 mock 引擎。
 */
export function TripAssistantCard({ onClick }: TripAssistantCardProps) {
  const navigate = useNavigate();
  const [count, setCount] = useState(0);
  const [lastMessage, setLastMessage] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    fetchTripAssistant()
      .then((data) => {
        if (!active) return;
        setCount(data.count);
        setLastMessage(data.lastMessage);
      })
      .catch(() => {
        if (!active) return;
        setCount(0);
        setLastMessage(null);
      });
    return () => {
      active = false;
    };
  }, []);

  return (
    <div
      className="flex items-center gap-3 px-4 py-3 bg-white active:bg-gray-50 transition-colors cursor-pointer"
      onClick={onClick ?? (() => navigate("/trip"))}
    >
      <div className="relative flex-shrink-0">
        <div className="w-12 h-12 rounded-full bg-[#FDF3E6] flex items-center justify-center overflow-hidden">
          <img
            src={tripIcon}
            alt="我的旅程"
            className="w-10 h-10 object-contain"
          />
        </div>
      </div>

      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2">
          <h3 className="min-w-0 text-base font-medium text-gray-900 truncate">
            我的旅程
          </h3>
          <span className="flex-shrink-0 rounded-md bg-green-500 text-white text-xs font-medium px-1.5 py-0.5">
            行程安全
          </span>
          <span className="flex-1" />
          {count > 0 && (
            <span
              aria-label={`${count} 条行程消息`}
              className="flex-shrink-0 h-[18px] px-1.5 min-w-[18px] rounded-full bg-red-500 text-white text-[11px] font-medium flex items-center justify-center"
            >
              {count > 99 ? "99+" : count}
            </span>
          )}
        </div>
        {lastMessage && (
          <p className="mt-0.5 text-sm text-gray-500 truncate">
            [行程助手]：{lastMessage}
          </p>
        )}
      </div>
    </div>
  );
}
