import { useEffect, useMemo, useRef, useState } from "react";
import { ArrowLeft, ChevronRight, Search } from "lucide-react";
import { cn } from "@/lib/utils";
import { ContactFriend, ContactGroup } from "@/lib/api";
import { useContactStore } from "@/store/contactStore";
import { NewFriendsPage } from "./NewFriendsPage";
import { NewGroupInvitesPage } from "./NewGroupInvitesPage";
import { CampAvatar } from "./CampAvatar";
import { pinyin } from "pinyin-pro";

type Tab = "user" | "group";

interface ContactsPageProps {
  visible: boolean;
  onClose: () => void;
  onUserClick?: (userId: number) => void;
}

function normalizeText(text: string) {
  return text.toLowerCase().trim();
}

function ContactCard({
  avatar,
  name,
  isGroup = false,
  onClick,
}: {
  avatar: string;
  name: string;
  isGroup?: boolean;
  onClick?: () => void;
}) {
  return (
    <div
      onClick={onClick}
      className="flex items-center gap-3 px-4 py-3 bg-white active:bg-gray-50/50 transition-colors"
    >
      {isGroup ? (
        <CampAvatar src={avatar} name={name} size={44} />
      ) : (
        <img
          src={avatar}
          alt={name}
          className="w-11 h-11 rounded-full object-cover bg-gray-100 flex-shrink-0"
        />
      )}
      <span className="flex-1 min-w-0 text-base text-gray-900 truncate">
        {name}
      </span>
    </div>
  );
}

function EmptyState({ text }: { text: string }) {
  return (
    <div className="flex flex-col items-center justify-center py-16 px-6">
      <p className="text-sm text-gray-400 text-center">{text}</p>
    </div>
  );
}

function Badge({ count }: { count: number }) {
  if (count <= 0) return null;
  return (
    <span className="ml-2 min-w-[1.25rem] h-5 px-1 rounded-full bg-red-500 text-white text-xs font-medium flex items-center justify-center">
      {count > 99 ? "99+" : count}
    </span>
  );
}

function sortByCreatedAtDesc<T>(items: T[]): T[] {
  return [...items].sort(
    (a, b) =>
      new Date(((b as unknown) as { created_at?: string }).created_at || 0).getTime() -
      new Date(((a as unknown) as { created_at?: string }).created_at || 0).getTime()
  );
}

const ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".split("");

function getFirstLetter(name: string): string {
  if (!name) return "#";
  const firstChar = name.charAt(0);
  if (/[a-zA-Z]/.test(firstChar)) {
    return firstChar.toUpperCase();
  }
  if (/[\u4e00-\u9fa5]/.test(firstChar)) {
    const py = pinyin(firstChar, { toneType: "none" });
    const letter = py.charAt(0).toUpperCase();
    if (/[A-Z]/.test(letter)) return letter;
  }
  return "#";
}

function groupByLetter<T extends { name?: string; nickname?: string }>(
  items: T[],
  getName: (item: T) => string
): { letter: string; items: T[] }[] {
  const map = new Map<string, T[]>();
  items.forEach((item) => {
    const letter = getFirstLetter(getName(item));
    if (!map.has(letter)) map.set(letter, []);
    map.get(letter)!.push(item);
  });
  const letters = Array.from(map.keys()).sort((a, b) => {
    const aIdx = ALPHABET.indexOf(a);
    const bIdx = ALPHABET.indexOf(b);
    if (a === "#") return 1;
    if (b === "#") return -1;
    if (aIdx !== -1 && bIdx !== -1) return aIdx - bIdx;
    return a.localeCompare(b);
  });
  return letters.map((letter) => ({ letter, items: map.get(letter)! }));
}

export function ContactsPage({ visible, onClose, onUserClick }: ContactsPageProps) {
  const [activeTab, setActiveTab] = useState<Tab>("user");
  const [keyword, setKeyword] = useState("");
  const [isEntering, setIsEntering] = useState(false);
  const [newFriendsVisible, setNewFriendsVisible] = useState(false);
  const [newGroupInvitesVisible, setNewGroupInvitesVisible] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);
  const closeTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const scrollRef = useRef<HTMLDivElement>(null);
  const sectionRefs = useRef<Record<string, HTMLDivElement | null>>({});

  const contacts = useContactStore((state) => state.contacts);
  const badge = useContactStore((state) => state.badge);
  const loadContacts = useContactStore((state) => state.loadContacts);
  const loadBadge = useContactStore((state) => state.loadBadge);
  const loadFriendRequests = useContactStore((state) => state.loadFriendRequests);
  const loadGroupRequests = useContactStore((state) => state.loadGroupRequests);
  const markRead = useContactStore((state) => state.markRead);

  useEffect(() => {
    if (visible) {
      if (closeTimerRef.current) {
        clearTimeout(closeTimerRef.current);
        closeTimerRef.current = null;
      }
      requestAnimationFrame(() => {
        requestAnimationFrame(() => setIsEntering(true));
      });
      setTimeout(() => inputRef.current?.focus(), 320);
      loadContacts();
      loadBadge();
    } else {
      setIsEntering(false);
      closeTimerRef.current = setTimeout(() => {
        setKeyword("");
        setActiveTab("user");
      }, 320);
    }
    return () => {
      if (closeTimerRef.current) clearTimeout(closeTimerRef.current);
    };
  }, [visible, loadContacts, loadBadge]);

  const normalizedKeyword = useMemo(() => normalizeText(keyword), [keyword]);

  const filteredUsers = useMemo(() => {
    const list = sortByCreatedAtDesc(contacts.friends);
    if (!normalizedKeyword) return list;
    return list.filter(
      (u) =>
        normalizeText(u.nickname).includes(normalizedKeyword) ||
        normalizeText(String(u.user_id)).includes(normalizedKeyword)
    );
  }, [contacts.friends, normalizedKeyword]);

  const filteredGroups = useMemo(() => {
    const list = sortByCreatedAtDesc(contacts.groups);
    if (!normalizedKeyword) return list;
    return list.filter((g) =>
      normalizeText(g.name).includes(normalizedKeyword)
    );
  }, [contacts.groups, normalizedKeyword]);

  const groupedUsers = useMemo(
    () => groupByLetter(filteredUsers, (u) => u.nickname),
    [filteredUsers]
  );

  const groupedGroups = useMemo(
    () => groupByLetter(filteredGroups, (g) => g.name),
    [filteredGroups]
  );

  const handleOpenNewFriends = async () => {
    await markRead("friend");
    await loadFriendRequests();
    setNewFriendsVisible(true);
  };

  const handleOpenNewGroupInvites = async () => {
    await markRead("group");
    await loadGroupRequests();
    setNewGroupInvitesVisible(true);
  };

  const scrollToLetter = (letter: string) => {
    const el = sectionRefs.current[letter];
    if (el && scrollRef.current) {
      const top = el.offsetTop - scrollRef.current.offsetTop;
      scrollRef.current.scrollTo({ top, behavior: "smooth" });
    }
  };

  const renderGroupedList = (
    grouped: { letter: string; items: (ContactFriend | ContactGroup)[] }[],
    isGroup: boolean
  ) => {
    if (grouped.length === 0) {
      return (
        <EmptyState
          text={
            normalizedKeyword
              ? `未搜索到相关${isGroup ? "营地" : "同胞"}`
              : `还没有${isGroup ? "加入营地" : "添加同胞"}`
          }
        />
      );
    }
    return (
      <div className="pb-6 space-y-[1px]">
        {grouped.map(({ letter, items }) => (
          <div
            key={letter}
            ref={(el) => {
              sectionRefs.current[letter] = el;
            }}
          >
            <div className="sticky top-0 px-4 py-1.5 bg-white text-xs text-gray-500 font-medium z-[1]">
              {letter}
            </div>
            {items.map((item) =>
              isGroup ? (
                <ContactCard
                  key={(item as ContactGroup).id}
                  avatar={(item as ContactGroup).avatar_url}
                  name={(item as ContactGroup).name}
                  isGroup
                />
              ) : (
                <ContactCard
                  key={(item as ContactFriend).id}
                  avatar={(item as ContactFriend).avatar_url}
                  name={(item as ContactFriend).nickname}
                  onClick={
                    onUserClick
                      ? () => onUserClick((item as ContactFriend).user_id)
                      : undefined
                  }
                />
              )
            )}
          </div>
        ))}
      </div>
    );
  };

  return (
    <div
      className={cn(
        "fixed inset-0 z-[70] bg-white flex flex-col transition-transform duration-300 ease-[cubic-bezier(0.25,0.1,0.25,1)]",
        isEntering ? "translate-x-0" : "-translate-x-full"
      )}
    >
      {/* Top bar */}
      <div className="flex-shrink-0 flex items-center justify-between px-4 pt-[max(0.75rem,env(safe-area-inset-top))] pb-3 bg-white z-10">
        <button
          type="button"
          onClick={onClose}
          className="w-8 h-8 flex items-center justify-center -ml-2"
        >
          <ArrowLeft className="w-5 h-5 text-gray-900" strokeWidth={1.5} />
        </button>
        <h1 className="text-base font-medium text-gray-900">联系人</h1>
        <div className="w-8" />
      </div>

      {/* Search box */}
      <div className="flex-shrink-0 px-4 py-3 bg-white">
        <div className="flex items-center gap-2 h-10 px-3 rounded-md bg-gray-100/60 text-gray-900">
          <Search
            className="w-4 h-4 text-gray-400 flex-shrink-0"
            strokeWidth={1.8}
          />
          <input
            ref={inputRef}
            type="text"
            value={keyword}
            onChange={(e) => setKeyword(e.target.value)}
            placeholder={
              activeTab === "user"
                ? "搜索同胞昵称/Porten账号"
                : "搜索营地名称"
            }
            className="flex-1 bg-transparent text-sm outline-none placeholder:text-gray-400"
          />
          {keyword && (
            <button
              type="button"
              onClick={() => {
                setKeyword("");
                inputRef.current?.focus();
              }}
              className="text-xs text-gray-400 px-1"
            >
              清空
            </button>
          )}
        </div>
      </div>

      {/* Function entries */}
      <div className="flex-shrink-0 px-4 space-y-0 bg-white">
        <button
          type="button"
          onClick={handleOpenNewFriends}
          className="w-full flex items-center justify-between h-12 text-left active:bg-gray-50/50 transition-colors"
        >
          <span className="flex items-center text-base text-gray-900">
            新的同胞
            <Badge count={badge.friend_requests} />
          </span>
          <ChevronRight
            className="w-4 h-4 text-gray-400"
            strokeWidth={1.5}
          />
        </button>
        <button
          type="button"
          onClick={handleOpenNewGroupInvites}
          className="w-full flex items-center justify-between h-12 text-left active:bg-gray-50/50 transition-colors"
        >
          <span className="flex items-center text-base text-gray-900">
            新营地邀请
            <Badge count={badge.group_requests} />
          </span>
          <ChevronRight
            className="w-4 h-4 text-gray-400"
            strokeWidth={1.5}
          />
        </button>
      </div>

      {/* 6px gap */}
      <div className="flex-shrink-0 h-1.5 bg-gray-50" />

      {/* Tabs */}
      <div className="flex-shrink-0 flex items-center px-4 pb-3 bg-white">
        <button
          type="button"
          onClick={() => setActiveTab("user")}
          className={cn(
            "relative text-sm font-medium px-1 py-1 transition-colors",
            activeTab === "user" ? "text-[#F5A9B8]" : "text-[#5BCEFA]"
          )}
        >
          同胞
          {activeTab === "user" && (
            <span className="absolute left-0 right-0 bottom-0 h-0.5 rounded-full bg-[#F5A9B8]" />
          )}
        </button>
        <button
          type="button"
          onClick={() => setActiveTab("group")}
          className={cn(
            "relative text-sm font-medium px-1 py-1 ml-6 transition-colors",
            activeTab === "group" ? "text-[#F5A9B8]" : "text-[#5BCEFA]"
          )}
        >
          营地
          {activeTab === "group" && (
            <span className="absolute left-0 right-0 bottom-0 h-0.5 rounded-full bg-[#F5A9B8]" />
          )}
        </button>
      </div>

      {/* List area */}
      <div className="flex-1 relative overflow-hidden bg-white">
        <div
          ref={scrollRef}
          className="absolute inset-0 overflow-y-auto overflow-x-hidden scrollbar-hide"
        >
          {activeTab === "user" && renderGroupedList(groupedUsers, false)}
          {activeTab === "group" && renderGroupedList(groupedGroups, true)}
        </div>

        {/* Alphabet index */}
        {!normalizedKeyword && (
          <div className="absolute right-1 top-0 bottom-0 flex flex-col items-center justify-center py-2 z-10">
            <div className="flex flex-col items-center py-1 px-0.5">
              {ALPHABET.map((letter) => (
                <button
                  key={letter}
                  type="button"
                  onClick={() => scrollToLetter(letter)}
                  className="w-5 h-4 text-[10px] text-gray-400 font-medium flex items-center justify-center active:text-gray-900"
                >
                  {letter}
                </button>
              ))}
            </div>
          </div>
        )}
      </div>

      <NewFriendsPage
        visible={newFriendsVisible}
        onClose={() => setNewFriendsVisible(false)}
      />

      <NewGroupInvitesPage
        visible={newGroupInvitesVisible}
        onClose={() => setNewGroupInvitesVisible(false)}
      />
    </div>
  );
}
