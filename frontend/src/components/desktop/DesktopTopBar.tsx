import { useEffect, useRef, useState } from "react";
import {
  Heart,
  Mail,
  Plus,
  Search,
  StickyNote,
  UserPlus,
  Users,
} from "lucide-react";
import { useSystemMessageStore } from "@/store/systemMessageStore";
import { DesktopNavKey } from "./DesktopSidebar";

const plusItems = [
  { key: "add", label: "添加同胞/营地", icon: UserPlus },
  { key: "create", label: "创建营地", icon: Users },
  { key: "note", label: "记笔记", icon: StickyNote },
  { key: "mood", label: "情绪日记", icon: Heart },
];

const viewTitles: Record<DesktopNavKey, string> = {
  messages: "",
  contacts: "",
  resources: "资源中心",
  knowledge: "知识广场",
};

interface DesktopTopBarProps {
  active: DesktopNavKey;
  onSearchOpen: () => void;
  onSystemMessagesOpen: () => void;
  onAddFriendOpen: () => void;
  onCreateGroupOpen: () => void;
  onNotesOpen: () => void;
  onDiaryOpen: () => void;
}

function PlusDropdown({
  open,
  onClose,
  onAddFriend,
  onCreateGroup,
  onNotes,
  onDiary,
}: {
  open: boolean;
  onClose: () => void;
  onAddFriend: () => void;
  onCreateGroup: () => void;
  onNotes: () => void;
  onDiary: () => void;
}) {
  const [render, setRender] = useState(false);
  const [entering, setEntering] = useState(false);
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    if (open) {
      if (timerRef.current) clearTimeout(timerRef.current);
      setRender(true);
      requestAnimationFrame(() => {
        requestAnimationFrame(() => setEntering(true));
      });
    } else {
      setEntering(false);
      timerRef.current = setTimeout(() => setRender(false), 240);
    }
    return () => {
      if (timerRef.current) clearTimeout(timerRef.current);
    };
  }, [open]);

  if (!render) return null;

  const handle = (fn?: () => void) => {
    onClose();
    fn?.();
  };

  return (
    <>
      <div className="fixed inset-0 z-[70]" onClick={onClose} />
      <div
        className="absolute top-full right-0 mt-2 w-52 rounded-2xl bg-black py-2 z-[80]"
        style={{
          opacity: entering ? 1 : 0,
          transform: entering ? "scale(1)" : "scale(0.9)",
          transformOrigin: "top right",
          transition:
            "transform 240ms cubic-bezier(0.16, 1, 0.3, 1), opacity 200ms ease-out",
        }}
      >
        {/* 指向加号按钮的三角 */}
        <div className="absolute -top-1.5 w-3 h-3 bg-black rotate-45" style={{ right: "22px" }} />
        <div className="relative">
          {plusItems.map((item) => {
            const Icon = item.icon;
            return (
              <button
                key={item.key}
                type="button"
                className="w-full flex items-center gap-3 px-4 py-2.5 text-left text-white/90 hover:text-white hover:bg-white/10 transition-colors duration-200"
                onClick={() =>
                  handle(
                    item.key === "add"
                      ? onAddFriend
                      : item.key === "create"
                        ? onCreateGroup
                        : item.key === "note"
                          ? onNotes
                          : onDiary
                  )
                }
              >
                <Icon className="w-4 h-4 flex-shrink-0" strokeWidth={1.8} />
                <span className="text-sm">{item.label}</span>
              </button>
            );
          })}
        </div>
      </div>
    </>
  );
}

/** 第二、三栏合并的顶部栏：左侧为搜索/标题，右侧为加号菜单 + 系统消息。 */
export function DesktopTopBar({
  active,
  onSearchOpen,
  onSystemMessagesOpen,
  onAddFriendOpen,
  onCreateGroupOpen,
  onNotesOpen,
  onDiaryOpen,
}: DesktopTopBarProps) {
  const [plusOpen, setPlusOpen] = useState(false);
  const systemUnread = useSystemMessageStore((state) => state.unreadCount);
  const loadSystemUnreadCount = useSystemMessageStore(
    (state) => state.loadUnreadCount
  );

  useEffect(() => {
    loadSystemUnreadCount();
  }, [loadSystemUnreadCount]);

  const title = viewTitles[active];

  return (
    <header className="relative z-30 h-14 shrink-0 flex items-center justify-between px-4 bg-white border-b border-gray-100">
      {/* 左侧：消息视图显示全局搜索框，其余视图显示标题 */}
      <div className="flex items-center min-w-0">
        {active === "messages" ? (
          <button
            type="button"
            onClick={onSearchOpen}
            className="flex items-center gap-2 h-9 w-60 px-3 rounded-lg bg-gray-100/70 text-gray-400 hover:bg-gray-100 transition-colors duration-200 text-left"
          >
            <Search className="w-4 h-4 flex-shrink-0" strokeWidth={1.8} />
            <span className="text-sm truncate">搜索同胞/营地/图片…</span>
          </button>
        ) : title ? (
          <h1 className="text-base font-semibold text-gray-900 truncate">
            {title}
          </h1>
        ) : null}
      </div>

      {/* 右侧：加号菜单 + 系统消息 */}
      <div className="flex items-center gap-1 relative">
        <button
          type="button"
          onClick={() => setPlusOpen((v) => !v)}
          className="w-9 h-9 flex items-center justify-center rounded-full text-gray-600 hover:bg-gray-100/70 transition-colors duration-200"
          aria-label="更多"
        >
          <Plus className="w-5 h-5" strokeWidth={1.8} />
        </button>
        <button
          type="button"
          onClick={onSystemMessagesOpen}
          className="relative w-9 h-9 flex items-center justify-center rounded-full text-gray-600 hover:bg-gray-100/70 transition-colors duration-200"
          aria-label="系统通知"
        >
          <Mail className="w-5 h-5" strokeWidth={1.8} />
          {systemUnread > 0 && (
            <span className="absolute top-1.5 right-1.5 w-2 h-2 rounded-full bg-red-500" />
          )}
        </button>

        <PlusDropdown
          open={plusOpen}
          onClose={() => setPlusOpen(false)}
          onAddFriend={onAddFriendOpen}
          onCreateGroup={onCreateGroupOpen}
          onNotes={onNotesOpen}
          onDiary={onDiaryOpen}
        />
      </div>
    </header>
  );
}
