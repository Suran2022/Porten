import { X, SmilePlus, Pencil } from "lucide-react";

interface ProfileTopBarProps {
  mood: string | null;
  onClose: () => void;
  onEditClick: () => void;
}

export function ProfileTopBar({ mood, onClose, onEditClick }: ProfileTopBarProps) {
  // 顺性别 mood 是中文标签（开心/焦虑 等），跨性别可能也是中文
  const moodLabel = mood
    ? MOOD_LABELS[mood as MoodValue] ?? mood
    : null;
  return (
    <div className="relative z-10 flex items-center justify-between gap-3 px-4 pt-3 pt-[max(0.75rem,env(safe-area-inset-top))] pb-3">
      <button
        type="button"
        onClick={onClose}
        className="w-8 h-8 rounded-full bg-black/20 flex items-center justify-center backdrop-blur-sm"
      >
        <X className="w-5 h-5 text-white" strokeWidth={1.8} />
      </button>

      <div className="flex items-center gap-2">
        {moodLabel ? (
          <button
            type="button"
            className="flex items-center gap-1.5 h-8 px-3 rounded-full bg-black/10"
          >
            <SmilePlus className="w-4 h-4 text-white" strokeWidth={1.8} />
            <span className="text-sm font-medium text-white">{moodLabel}</span>
          </button>
        ) : null}

        <button
          type="button"
          onClick={onEditClick}
          className="flex items-center gap-1.5 h-8 px-4 rounded-full bg-black/10"
        >
          <Pencil className="w-4 h-4 text-white" strokeWidth={1.8} />
          <span className="text-sm font-medium text-white">编辑资料</span>
        </button>
      </div>
    </div>
  );
}

const MOOD_LABELS: Record<string, string> = {
  happy: "开心",
  calm: "平静",
  sad: "难过",
  anxious: "焦虑",
  angry: "愤怒",
  tired: "疲惫",
  grateful: "感恩",
  lonely: "孤独",
  hopeful: "充满希望",
  confused: "迷茫",
};

type MoodValue = keyof typeof MOOD_LABELS;
