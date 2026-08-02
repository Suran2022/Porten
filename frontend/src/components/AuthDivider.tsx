interface AuthDividerProps {
  text: string;
}

export function AuthDivider({ text }: AuthDividerProps) {
  return (
    <div className="relative flex items-center justify-center w-full py-2">
      <div className="fade-divider absolute inset-x-0" />
      <span className="relative z-10 px-3 text-xs text-gray-400 bg-white">
        {text}
      </span>
    </div>
  );
}
