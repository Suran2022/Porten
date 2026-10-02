import { useNavigate } from "react-router-dom";
import tripIcon from "@/assets/trip-icon.svg";

interface TripAssistantCardProps {
  onClick?: () => void;
}

/** 行程消息徽标数（示例数据：当前有 1 条行程消息）。 */
const TRIP_MESSAGE_COUNT = 1;

/** 名称下方的最新一条旅程消息，超长由 truncate 自动省略。 */
const TRIP_LAST_MESSAGE = "您有一条在2天后前往大连的旅程";

/**
 * 「我的旅程」功能入口卡片：头像 / 名称 + 「行程安全」标签 + 行程消息徽标。
 * 名称下方展示最近创建的旅程，前缀 [行程助手]：，与 Porten 伙伴入口卡片并列展示。
 */
export function TripAssistantCard({ onClick }: TripAssistantCardProps) {
  const navigate = useNavigate();

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
          {TRIP_MESSAGE_COUNT > 0 && (
            <span
              aria-label={`${TRIP_MESSAGE_COUNT} 条行程消息`}
              className="flex-shrink-0 h-[18px] px-1.5 min-w-[18px] rounded-full bg-red-500 text-white text-[11px] font-medium flex items-center justify-center"
            >
              {TRIP_MESSAGE_COUNT > 99 ? "99+" : TRIP_MESSAGE_COUNT}
            </span>
          )}
        </div>
        <p className="mt-0.5 text-sm text-gray-500 truncate">
          [行程助手]：{TRIP_LAST_MESSAGE}
        </p>
      </div>
    </div>
  );
}
