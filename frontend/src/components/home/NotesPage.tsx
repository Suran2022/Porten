import { useEffect, useRef, useState } from "react";
import {
  Archive,
  ArchiveRestore,
  ArrowLeft,
  Check,
  MoreHorizontal,
  Pencil,
  Plus,
  Trash2,
  X,
} from "lucide-react";
import { cn } from "@/lib/utils";

interface NoteItem {
  id: number;
  content: string;
  time: string;
  tags: string[];
  archived?: boolean;
}

interface NotesPageProps {
  visible: boolean;
  onClose: () => void;
}

const MOCK_NOTES: NoteItem[] = [
  {
    id: 1,
    content: "今天把消息列表的交互流程重新梳理了一遍。优先让核心路径保持简单，再逐步补充细节和反馈。",
    time: "今天 10:24",
    tags: ["工作", "灵感"],
  },
  {
    id: 2,
    content: "周末想去城南的植物园走走，带上相机，顺便记录春天刚长出来的新叶和傍晚的光。",
    time: "昨天 21:16",
    tags: ["生活", "计划"],
  },
  {
    id: 3,
    content: "产品细节：动画不只是装饰，它应该帮助用户理解页面之间的空间关系，进入和退出必须保持方向一致。",
    time: "7月30日 16:08",
    tags: ["设计", "产品"],
  },
  {
    id: 4,
    content: "最近循环播放的歌单很适合夜晚写东西。舒缓的节奏能让思绪慢下来，也更容易专注。",
    time: "7月28日 23:42",
    tags: ["音乐", "日常"],
  },
  {
    id: 5,
    content: "下次社区分享会可以讨论如何建立更安全的表达空间，让每个人都能被认真倾听和温柔回应。",
    time: "7月26日 14:30",
    tags: ["社区", "想法"],
  },
  {
    id: 6,
    content: "阅读摘录：真正的勇敢并不是从不害怕，而是在理解自己的害怕之后，仍然愿意向前走一步。",
    time: "7月24日 09:12",
    tags: ["阅读", "摘录"],
  },
  {
    id: 7,
    content: "体检需要准备的材料：身份证、预约单、既往检查报告。提前半小时出门，避免早高峰。",
    time: "7月22日 18:05",
    tags: ["健康", "待办"],
  },
  {
    id: 8,
    content: "新功能的颜色尽量降低饱和度，蓝色与粉色不要直接硬切，用更大的渐变半径自然融入白色背景。",
    time: "7月20日 11:47",
    tags: ["设计", "灵感"],
  },
  {
    id: 9,
    content: "给未来的自己：不需要急着证明什么，按照自己的节奏生活，每一次认真选择都算数。",
    time: "7月18日 22:19",
    tags: ["心情", "给自己"],
  },
  {
    id: 10,
    content: "会议记录：先完成移动端消息体验，再统一桌面端布局；测试阶段重点关注弱网和离线状态。",
    time: "7月16日 15:36",
    tags: ["工作", "会议"],
  },
  {
    id: 11,
    content: "想学着做一道简单的番茄炖牛腩，少放一点糖，最后加几颗烤过的小番茄增加香气。",
    time: "7月14日 12:04",
    tags: ["生活", "美食"],
  },
];

const TAG_STYLES = [
  "bg-sky-100/80 text-sky-700",
  "bg-pink-100/80 text-pink-700",
  "bg-violet-100/80 text-violet-700",
  "bg-amber-100/80 text-amber-700",
  "bg-emerald-100/80 text-emerald-700",
  "bg-indigo-100/80 text-indigo-700",
];

function tagStyle(tag: string) {
  let hash = 0;
  for (const character of tag) hash += character.charCodeAt(0);
  return TAG_STYLES[hash % TAG_STYLES.length];
}

function currentTimeLabel() {
  return `今天 ${new Intl.DateTimeFormat("zh-CN", {
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).format(new Date())}`;
}

export function NotesPage({ visible, onClose }: NotesPageProps) {
  const [shouldRender, setShouldRender] = useState(false);
  const [isEntering, setIsEntering] = useState(false);
  const [notes, setNotes] = useState<NoteItem[]>(MOCK_NOTES);
  const [activeMenuId, setActiveMenuId] = useState<number | null>(null);
  const [editingNote, setEditingNote] = useState<NoteItem | null>(null);
  const [editorVisible, setEditorVisible] = useState(false);
  const [draftContent, setDraftContent] = useState("");
  const [draftTags, setDraftTags] = useState("");
  const closeTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    if (visible) {
      if (closeTimerRef.current) clearTimeout(closeTimerRef.current);
      setShouldRender(true);
      requestAnimationFrame(() => {
        requestAnimationFrame(() => setIsEntering(true));
      });
      return;
    }

    setIsEntering(false);
    setActiveMenuId(null);
    closeTimerRef.current = setTimeout(() => setShouldRender(false), 320);
    return () => {
      if (closeTimerRef.current) clearTimeout(closeTimerRef.current);
    };
  }, [visible]);

  const openEditor = (note?: NoteItem) => {
    setEditingNote(note ?? null);
    setDraftContent(note?.content ?? "");
    setDraftTags(note?.tags.join("、") ?? "");
    setActiveMenuId(null);
    setEditorVisible(true);
  };

  const saveNote = () => {
    const content = draftContent.trim();
    if (!content) return;
    const tags = draftTags
      .split(/[、,，\s]+/)
      .map((tag) => tag.trim())
      .filter(Boolean)
      .slice(0, 4);

    if (editingNote) {
      setNotes((items) =>
        items.map((note) =>
          note.id === editingNote.id
            ? { ...note, content, tags, time: currentTimeLabel() }
            : note
        )
      );
    } else {
      setNotes((items) => [
        {
          id: Date.now(),
          content,
          time: currentTimeLabel(),
          tags: tags.length ? tags : ["随记"],
        },
        ...items,
      ]);
    }
    setEditorVisible(false);
  };

  const deleteNote = (noteId: number) => {
    setNotes((items) => items.filter((note) => note.id !== noteId));
    setActiveMenuId(null);
  };

  const toggleArchive = (noteId: number) => {
    setNotes((items) =>
      items.map((note) =>
        note.id === noteId ? { ...note, archived: !note.archived } : note
      )
    );
    setActiveMenuId(null);
  };

  if (!shouldRender) return null;

  return (
    <div
      className={cn(
        "fixed inset-0 z-[95] flex flex-col overflow-hidden bg-white transition-transform duration-300 ease-[cubic-bezier(0.25,0.1,0.25,1)]",
        isEntering ? "translate-x-0" : "translate-x-full"
      )}
      onClick={() => setActiveMenuId(null)}
    >
      <div
        className="pointer-events-none absolute left-0 top-0 w-full"
        style={{
          height: "39%",
          background:
            "linear-gradient(145deg, rgba(91,206,250,0.30) 0%, rgba(139,204,238,0.27) 22%, rgba(245,169,184,0.30) 52%, rgba(248,198,209,0.18) 72%, rgba(255,255,255,0) 100%)",
        }}
      />

      <header className="relative z-20 flex h-16 flex-shrink-0 items-center px-4 pt-[env(safe-area-inset-top)]">
        <button
          type="button"
          onClick={onClose}
          className="flex h-9 w-9 -ml-2 items-center justify-center rounded-full text-gray-800 transition-colors active:bg-white/45"
          aria-label="返回"
        >
          <ArrowLeft className="h-5 w-5" strokeWidth={1.6} />
        </button>

        <h1 className="pointer-events-none absolute left-1/2 -translate-x-1/2 text-base font-semibold text-gray-900">
          我的笔记
        </h1>

        <button
          type="button"
          onClick={() => openEditor()}
          className="ml-auto flex h-9 items-center gap-1.5 rounded-full bg-gray-500/10 px-3 text-sm font-medium text-gray-700 backdrop-blur-sm transition-colors active:bg-gray-500/20"
        >
          <Plus className="h-4 w-4" strokeWidth={1.8} />
          <span>添加笔记</span>
        </button>
      </header>

      <main className="relative z-10 flex-1 overflow-y-auto overflow-x-hidden scrollbar-hide">
        <div className="mx-auto max-w-md space-y-3 px-4 pb-[max(2rem,env(safe-area-inset-bottom))] pt-3">
          {notes.map((note) => (
            <article
              key={note.id}
              className={cn(
                "relative rounded-[6px] bg-white px-4 py-3.5",
                note.archived && "opacity-65"
              )}
            >
              <div className="flex items-start gap-3">
                <p
                  className="min-w-0 flex-1 overflow-hidden text-[15px] leading-6 text-gray-800"
                  style={{
                    display: "-webkit-box",
                    WebkitBoxOrient: "vertical",
                    WebkitLineClamp: 3,
                  }}
                >
                  {note.content}
                </p>

                <button
                  type="button"
                  onClick={(event) => {
                    event.stopPropagation();
                    setActiveMenuId((current) =>
                      current === note.id ? null : note.id
                    );
                  }}
                  className="-mr-2 -mt-1 flex h-8 w-8 flex-shrink-0 items-center justify-center rounded-full text-gray-400 transition-colors active:bg-gray-100"
                  aria-label="笔记操作"
                >
                  <MoreHorizontal className="h-5 w-5" strokeWidth={1.7} />
                </button>
              </div>

              <div className="mt-3 flex items-center gap-2">
                <time className="mr-auto text-xs text-gray-400">{note.time}</time>
                {note.archived && (
                  <span className="rounded-full bg-gray-100 px-2 py-0.5 text-[11px] text-gray-500">
                    已归档
                  </span>
                )}
                {note.tags.map((tag) => (
                  <span
                    key={tag}
                    className={cn(
                      "rounded-full px-2 py-0.5 text-[11px] font-medium",
                      tagStyle(tag)
                    )}
                  >
                    {tag}
                  </span>
                ))}
              </div>

              {activeMenuId === note.id && (
                <div
                  className="absolute right-3 top-10 z-30 w-36 overflow-hidden rounded-xl bg-white py-1 ring-1 ring-black/5"
                  onClick={(event) => event.stopPropagation()}
                >
                  <button
                    type="button"
                    onClick={() => openEditor(note)}
                    className="flex w-full items-center gap-2.5 px-3 py-2.5 text-left text-sm text-gray-700 active:bg-gray-50"
                  >
                    <Pencil className="h-4 w-4" strokeWidth={1.7} />
                    编辑笔记
                  </button>
                  <button
                    type="button"
                    onClick={() => toggleArchive(note.id)}
                    className="flex w-full items-center gap-2.5 px-3 py-2.5 text-left text-sm text-gray-700 active:bg-gray-50"
                  >
                    {note.archived ? (
                      <ArchiveRestore className="h-4 w-4" strokeWidth={1.7} />
                    ) : (
                      <Archive className="h-4 w-4" strokeWidth={1.7} />
                    )}
                    {note.archived ? "取消归档" : "归档笔记"}
                  </button>
                  <button
                    type="button"
                    onClick={() => deleteNote(note.id)}
                    className="flex w-full items-center gap-2.5 px-3 py-2.5 text-left text-sm text-red-500 active:bg-red-50/60"
                  >
                    <Trash2 className="h-4 w-4" strokeWidth={1.7} />
                    删除笔记
                  </button>
                </div>
              )}
            </article>
          ))}
        </div>
      </main>

      <div
        className={cn(
          "absolute inset-0 z-40 flex flex-col bg-white transition-transform duration-300 ease-[cubic-bezier(0.25,0.1,0.25,1)]",
          editorVisible ? "translate-x-0" : "translate-x-full pointer-events-none"
        )}
        onClick={(event) => event.stopPropagation()}
      >
        <header className="flex h-16 flex-shrink-0 items-center px-4 pt-[env(safe-area-inset-top)]">
          <button
            type="button"
            onClick={() => setEditorVisible(false)}
            className="flex h-9 w-9 -ml-2 items-center justify-center rounded-full text-gray-700 active:bg-gray-100"
            aria-label="关闭编辑"
          >
            <X className="h-5 w-5" strokeWidth={1.7} />
          </button>
          <h2 className="absolute left-1/2 -translate-x-1/2 text-base font-semibold text-gray-900">
            {editingNote ? "编辑笔记" : "添加笔记"}
          </h2>
          <button
            type="button"
            onClick={saveNote}
            disabled={!draftContent.trim()}
            className="ml-auto flex h-9 items-center gap-1.5 rounded-full bg-gray-900 px-3 text-sm text-white disabled:bg-gray-200 disabled:text-gray-400"
          >
            <Check className="h-4 w-4" strokeWidth={1.8} />
            完成
          </button>
        </header>

        <div className="flex-1 overflow-y-auto px-4 pb-8 pt-3">
          <textarea
            value={draftContent}
            onChange={(event) => setDraftContent(event.target.value)}
            placeholder="记录此刻的想法……"
            autoFocus={editorVisible}
            className="min-h-[240px] w-full resize-none rounded-[6px] bg-gray-50/80 p-4 text-[15px] leading-7 text-gray-800 outline-none placeholder:text-gray-300"
          />
          <label className="mt-5 block text-xs text-gray-500">标签</label>
          <input
            value={draftTags}
            onChange={(event) => setDraftTags(event.target.value)}
            placeholder="多个标签使用空格或顿号分隔"
            className="mt-2 h-11 w-full rounded-[6px] bg-gray-50/80 px-4 text-sm text-gray-700 outline-none placeholder:text-gray-300"
          />
        </div>
      </div>
    </div>
  );
}
