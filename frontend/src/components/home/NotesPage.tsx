import { useEffect, useRef, useState } from "react";
import {
  Archive,
  ArchiveRestore,
  Check,
  MoreHorizontal,
  Pencil,
  Plus,
  Trash2,
  X,
} from "lucide-react";
import { BackIcon } from "@/components/common/BackIcon";
import { cn } from "@/lib/utils";
import {
  createNote,
  deleteNote as removeNote,
  fetchNotes,
  updateNote,
} from "@/lib/api";
import type { NoteItem } from "@/lib/api";
import { useToastStore } from "@/store/toastStore";

interface NotesPageProps {
  visible: boolean;
  onClose: () => void;
}

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


export function NotesPage({ visible, onClose }: NotesPageProps) {
  const showToast = useToastStore((state) => state.show);
  const [shouldRender, setShouldRender] = useState(false);
  const [isEntering, setIsEntering] = useState(false);
  // 笔记列表：每次打开页面从 /notes 拉取（API 模式）或 mock 引擎读取
  const [notes, setNotes] = useState<NoteItem[]>([]);
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

  // 打开页面时拉取笔记列表；关闭期间的响应丢弃，避免竞态写入
  useEffect(() => {
    if (!visible) return;
    let active = true;
    fetchNotes()
      .then((items) => {
        if (active) setNotes(items);
      })
      .catch((err) => {
        if (active) {
          showToast(
            err instanceof Error ? err.message : "笔记加载失败",
            "error"
          );
        }
      });
    return () => {
      active = false;
    };
  }, [visible, showToast]);

  const openEditor = (note?: NoteItem) => {
    setEditingNote(note ?? null);
    setDraftContent(note?.content ?? "");
    setDraftTags(note?.tags.join("、") ?? "");
    setActiveMenuId(null);
    setEditorVisible(true);
  };

  const saveNote = async () => {
    const content = draftContent.trim();
    if (!content) return;
    const tags = draftTags
      .split(/[、,，\s]+/)
      .map((tag) => tag.trim())
      .filter(Boolean)
      .slice(0, 4);

    try {
      if (editingNote) {
        await updateNote(editingNote.id, { content, tags });
      } else {
        await createNote({ content, tags });
      }
      // time 由服务端生成，保存后重新拉取以拿到权威列表
      setNotes(await fetchNotes());
      setEditorVisible(false);
    } catch (err) {
      showToast(
        err instanceof Error ? err.message : "笔记保存失败",
        "error"
      );
    }
  };

  const deleteNote = async (noteId: number) => {
    try {
      await removeNote(noteId);
      setNotes((items) => items.filter((note) => note.id !== noteId));
    } catch (err) {
      showToast(
        err instanceof Error ? err.message : "笔记删除失败",
        "error"
      );
    }
    setActiveMenuId(null);
  };

  const toggleArchive = async (noteId: number) => {
    const note = notes.find((item) => item.id === noteId);
    if (!note) return;
    try {
      await updateNote(noteId, { archived: !note.archived });
      setNotes((items) =>
        items.map((item) =>
          item.id === noteId ? { ...item, archived: !item.archived } : item
        )
      );
    } catch (err) {
      showToast(err instanceof Error ? err.message : "操作失败", "error");
    }
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
          // mask-image 在垂直方向控制渐变尾部淡出，与白色背景自然融合；
          // 不使用 filter:blur，因为 NotesPage 外层 fixed inset-0 自带
          // transition-transform，filter:blur 的溢出会被 transform 祖先裁剪而不可见；
          // mask 只调整元素自身的 alpha 通道，不产生几何溢出，对 transform 容器免疫。
          WebkitMaskImage:
            "linear-gradient(180deg, #000 0%, #000 55%, rgba(0,0,0,0.6) 78%, rgba(0,0,0,0.25) 92%, transparent 100%)",
          maskImage:
            "linear-gradient(180deg, #000 0%, #000 55%, rgba(0,0,0,0.6) 78%, rgba(0,0,0,0.25) 92%, transparent 100%)",
        }}
      />

      <header className="relative z-20 flex h-16 flex-shrink-0 items-center px-4 pt-[env(safe-area-inset-top)]">
        <button
          type="button"
          onClick={onClose}
          className="flex h-9 w-9 -ml-2 items-center justify-center rounded-full text-gray-800 transition-colors active:bg-white/45"
          aria-label="返回"
        >
          <BackIcon className="w-7 h-7" />
        </button>

        <h1 className="pointer-events-none absolute left-1/2 -translate-x-1/2 text-lg font-semibold text-gray-900">
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
          <h2 className="absolute left-1/2 -translate-x-1/2 text-lg font-semibold text-gray-900">
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
