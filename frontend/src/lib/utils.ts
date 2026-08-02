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
