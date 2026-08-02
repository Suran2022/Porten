import { useState } from "react";
import { cn } from "@/lib/utils";
import { UsersRound } from "lucide-react";

interface CampAvatarProps {
  src?: string | null;
  name?: string;
  size?: number;
  className?: string;
}

export function CampAvatar({
  src,
  name,
  size = 48,
  className,
}: CampAvatarProps) {
  const [error, setError] = useState(false);
  const showFallback = !src || error;
  const style = { width: size, height: size };

  if (showFallback) {
    return (
      <div
        className={cn(
          "rounded-full bg-gray-100 flex items-center justify-center flex-shrink-0",
          className
        )}
        style={style}
      >
        <UsersRound
          className="text-gray-400"
          style={{ width: size * 0.45, height: size * 0.45 }}
          strokeWidth={1.5}
        />
      </div>
    );
  }

  return (
    <img
      src={src}
      alt={name || "营地头像"}
      className={cn(
        "rounded-full object-cover bg-gray-100 flex-shrink-0",
        className
      )}
      style={style}
      loading="lazy"
      onError={() => setError(true)}
    />
  );
}
