/** 全站统一返回图标（左箭头），大小由 className 控制，颜色默认黑色、可自定义（如音乐页白色）。 */
export function BackIcon({
  className,
  color = "#1A1A1A",
}: {
  className?: string;
  color?: string;
}) {
  return (
    <svg
      viewBox="0 0 1024 1024"
      version="1.1"
      xmlns="http://www.w3.org/2000/svg"
      className={className}
      aria-hidden
    >
      <path
        d="M632.5248 734.9248a25.6 25.6 0 0 1-36.1984 0l-204.8-204.8a25.6 25.6 0 0 1 0-36.1984l204.8-204.8a25.6 25.6 0 0 1 36.1984 36.1984L445.7984 512l186.7264 186.6752a25.6 25.6 0 0 1 0 36.2496z"
        fill={color}
      />
    </svg>
  );
}
