import { clsx, type ClassValue } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

export function formatMessageTime(timeStr: string): string {
  if (!timeStr) return "";
  // Backend stores naive UTC datetimes in MySQL; append Z when no timezone info.
  const normalized =
    /[Zz]|[+-]\d{2}:?\d{2}$/.test(timeStr) ? timeStr : `${timeStr}Z`;
  const date = new Date(normalized);
  if (isNaN(date.getTime())) return "";

  const now = new Date();
  const diffMs = now.getTime() - date.getTime();
  const diffSec = Math.floor(diffMs / 1000);
  const diffMin = Math.floor(diffSec / 60);
  const diffHour = Math.floor(diffMin / 60);
  const diffDay = Math.floor(diffHour / 24);

  if (diffMin < 1) return "刚刚";

  const isSameDay =
    date.getFullYear() === now.getFullYear() &&
    date.getMonth() === now.getMonth() &&
    date.getDate() === now.getDate();

  if (isSameDay) {
    const hours = date.getHours().toString().padStart(2, "0");
    const minutes = date.getMinutes().toString().padStart(2, "0");
    return `${hours}:${minutes}`;
  }

  if (diffDay === 1) return "1天前";
  if (diffDay > 1 && diffDay < 7) return `${diffDay}天前`;

  return date.toISOString().split("T")[0];
}

/* ============================= 日程工具 ============================= */

function pad2(n: number): string {
  return String(n).padStart(2, "0");
}

/** 日期转 YYYY-MM-DD。 */
export function toDateKey(date: Date): string {
  return `${date.getFullYear()}-${pad2(date.getMonth() + 1)}-${pad2(date.getDate())}`;
}

/** Date 转当天分钟数表达（供时间线定位/拖拽计算）。 */
export function hmmToMinutes(hhmm: string): number {
  const [h, m] = hhmm.split(":").map(Number);
  return h * 60 + m;
}

/** 分钟数转 HH:mm；1440 表示当天结束，显示为 24:00。 */
export function minutesToHHmm(minutes: number): string {
  if (minutes >= 24 * 60) return "24:00";
  return `${pad2(Math.floor(minutes / 60))}:${pad2(minutes % 60)}`;
}

/** Date 转 HH:mm。 */
export function formatHHmm(date: Date): string {
  return `${pad2(date.getHours())}:${pad2(date.getMinutes())}`;
}

/** Date 转中文日期时间展示：2026年10月4日 14:30。 */
export function formatDateTimeCn(date: Date): string {
  return `${date.getFullYear()}年${date.getMonth() + 1}月${date.getDate()}日 ${formatHHmm(date)}`;
}
