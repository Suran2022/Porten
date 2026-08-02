import { useEffect, useMemo, useRef, useState } from "react";
import { ArrowLeft, Search, UsersRound } from "lucide-react";
import { cn } from "@/lib/utils";
import {
  searchUserByPortenId,
  searchUserByNickname,
  searchGroups,
  SearchUserResult,
  SearchGroupResult,
  ContactFriend,
  ContactGroup,
} from "@/lib/api";
import { useContactStore } from "@/store/contactStore";
import { useChatStore } from "@/store/chatStore";
import { FriendApplyPage } from "./FriendApplyPage";
import { GroupApplyPage } from "./GroupApplyPage";
import { CampAvatar } from "./CampAvatar";

type Tab = "user" | "group";

interface AddFriendPageProps {
  visible: boolean;
  onClose: () => void;
}

function normalizeText(text: string) {
  return text.toLowerCase().trim();
}

function escapeRegExp(text: string) {
  return text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function HighlightText({
  text,
  keyword,
}: {
  text: string;
  keyword: string;
}) {
  if (!keyword) return <>{text}</>;
  const parts = text.split(new RegExp(`(${escapeRegExp(keyword)})`, "gi"));
  const keywordLower = keyword.toLowerCase();
  return (
    <>
      {parts.map((part, index) =>
        part.toLowerCase() === keywordLower ? (
          <span key={index} className="text-[#F5A9B8]">
            {part}
          </span>
        ) : (
          <span key={index}>{part}</span>
        )
      )}
    </>
  );
}

function EmptyState({ text }: { text: string }) {
  return (
    <div className="flex flex-col items-center justify-center py-16 px-6">
      <div className="w-16 h-16 rounded-2xl border-2 border-dashed border-gray-300 flex items-center justify-center mb-4">
        <UsersRound className="w-8 h-8 text-gray-300" strokeWidth={1.5} />
      </div>
      <p className="text-sm text-gray-400 text-center">{text}</p>
    </div>
  );
}

function UserItem({
  avatar,
  nickname,
  portenId,
  onClick,
}: {
  avatar: string;
  nickname: string;
  portenId?: string;
  onClick?: () => void;
}) {
  return (
    <div
      className={cn(
        "flex items-center gap-3 px-4 py-3 bg-white active:bg-gray-50/50 transition-colors",
        onClick && "cursor-pointer"
      )}
      onClick={onClick}
    >
      <img
        src={avatar}
        alt={nickname}
        className="w-12 h-12 rounded-full object-cover bg-gray-100 flex-shrink-0"
      />
      <div className="flex-1 min-w-0">
        <p className="text-base text-gray-900 truncate">{nickname}</p>
        {portenId && (
          <p className="text-xs text-gray-400 truncate mt-0.5">{portenId}</p>
        )}
      </div>
    </div>
  );
}

function GroupItem({
  avatar,
  name,
  memberCount,
  campId,
  keyword,
  onClick,
}: {
  avatar: string;
  name: string;
  memberCount?: number;
  campId?: string;
  keyword?: string;
  onClick?: () => void;
}) {
  const normalizedKeyword = keyword ? keyword.toLowerCase().trim() : "";
  const campIdMatched =
    normalizedKeyword && campId
      ? campId.toLowerCase().includes(normalizedKeyword)
      : false;

  return (
    <div
      className={cn(
        "flex items-center gap-3 px-4 py-3 bg-white active:bg-gray-50/50 transition-colors",
        onClick && "cursor-pointer"
      )}
      onClick={onClick}
    >
      <CampAvatar src={avatar} name={name} size={48} />
      <div className="flex-1 min-w-0">
        <p className="text-base text-gray-900 truncate">
          <HighlightText text={name} keyword={normalizedKeyword} />
        </p>
        {campIdMatched && (
          <p className="text-xs text-gray-400 truncate mt-0.5">
            营地号：<HighlightText text={campId} keyword={normalizedKeyword} />
          </p>
        )}
        {memberCount !== undefined && (
          <p className="text-xs text-gray-400 truncate mt-0.5">{memberCount} 人</p>
        )}
      </div>
    </div>
  );
}

function sortByCreatedAtDesc<T>(items: T[]): T[] {
  return [...items].sort(
    (a, b) =>
      new Date(((b as unknown) as { created_at?: string }).created_at || 0).getTime() -
      new Date(((a as unknown) as { created_at?: string }).created_at || 0).getTime()
  );
}

export function AddFriendPage({ visible, onClose }: AddFriendPageProps) {
  const [activeTab, setActiveTab] = useState<Tab>("user");
  const [keyword, setKeyword] = useState("");
  const [isEntering, setIsEntering] = useState(false);
  const [selectedUser, setSelectedUser] = useState<SearchUserResult | null>(null);
  const [selectedGroup, setSelectedGroup] = useState<SearchGroupResult | null>(null);
  const [applyPageVisible, setApplyPageVisible] = useState(false);
  const [userResult, setUserResult] = useState<SearchUserResult | null>(null);
  const [groupResults, setGroupResults] = useState<SearchGroupResult[]>([]);

  const inputRef = useRef<HTMLInputElement>(null);
  const closeTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const searchTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const contacts = useContactStore((state) => state.contacts);
  const loadContacts = useContactStore((state) => state.loadContacts);
  const loadBadge = useContactStore((state) => state.loadBadge);

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
        setSelectedUser(null);
        setSelectedGroup(null);
        setApplyPageVisible(false);
        setUserResult(null);
        setGroupResults([]);
      }, 320);
    }
    return () => {
      if (closeTimerRef.current) {
        clearTimeout(closeTimerRef.current);
      }
    };
  }, [visible, loadContacts, loadBadge]);

  useEffect(() => {
    if (searchTimerRef.current) {
      clearTimeout(searchTimerRef.current);
      searchTimerRef.current = null;
    }

    const trimmed = keyword.trim();
    if (!trimmed) {
      setUserResult(null);
      setGroupResults([]);
      return;
    }

    searchTimerRef.current = setTimeout(async () => {
      try {
        if (activeTab === "user") {
          // Porten ID is numeric; any non-numeric input is treated as a nickname
          // search, which only returns the current user (self).
          const looksLikePortenId = /^\d+$/.test(trimmed);
          if (looksLikePortenId) {
            const result = await searchUserByPortenId(trimmed);
            setUserResult(result);
          } else {
            const result = await searchUserByNickname(trimmed);
            setUserResult(result);
          }
        } else {
          const result = await searchGroups(trimmed);
          setGroupResults(result || []);
        }
      } catch (err) {
        console.error("search failed", err);
        if (activeTab === "user") {
          setUserResult(null);
        } else {
          setGroupResults([]);
        }
      }
    }, 300);

    return () => {
      if (searchTimerRef.current) {
        clearTimeout(searchTimerRef.current);
      }
    };
  }, [keyword, activeTab]);

  const handleTabChange = (tab: Tab) => {
    setActiveTab(tab);
    setKeyword("");
    setUserResult(null);
    setGroupResults([]);
  };

  const normalizedKeyword = useMemo(() => normalizeText(keyword), [keyword]);
  const showSearchResult = normalizedKeyword.length > 0;

  const myFriends = useMemo(
    () => sortByCreatedAtDesc(contacts.friends),
    [contacts.friends]
  );
  const myGroups = useMemo(
    () => sortByCreatedAtDesc(contacts.groups),
    [contacts.groups]
  );

  const handleUserClick = (user: SearchUserResult) => {
    setSelectedUser(user);
    setApplyPageVisible(true);
  };

  const handleGroupClick = (group: SearchGroupResult) => {
    setSelectedGroup(group);
    setApplyPageVisible(true);
  };

  const handleApplyClose = () => {
    setApplyPageVisible(false);
    setTimeout(() => {
      setSelectedUser(null);
      setSelectedGroup(null);
    }, 320);
    // 申请页关闭后刷新当前搜索结果，确保营地人数等数据最新。
    const trimmed = keyword.trim();
    if (trimmed && activeTab === "group") {
      searchGroups(trimmed).then(setGroupResults).catch(() => {});
    }
  };

  const handleApplySent = () => {
    loadContacts();
    loadBadge();
    useChatStore.getState().loadConversations();
  };

  return (
    <div
      className={cn(
        "fixed inset-0 z-[70] bg-white flex flex-col transition-transform duration-300 ease-[cubic-bezier(0.25,0.1,0.25,1)]",
        isEntering ? "translate-x-0" : "-translate-x-full"
      )}
    >
      {/* Fixed top bar */}
      <div className="flex-shrink-0 flex items-center justify-between px-4 pt-[max(0.75rem,env(safe-area-inset-top))] pb-3 bg-white z-10">
        <button
          type="button"
          onClick={onClose}
          className="w-8 h-8 flex items-center justify-center -ml-2"
        >
          <ArrowLeft className="w-5 h-5 text-gray-900" strokeWidth={1.5} />
        </button>
        <h1 className="text-base font-medium text-gray-900">添加同胞/营地</h1>
        <div className="w-8" />
      </div>

      {/* Scrollable content */}
      <div className="flex-1 overflow-y-auto overflow-x-hidden scrollbar-hide">
        {/* Search box */}
        <div className="px-4 py-3 bg-white sticky top-0 z-10">
          <div className="flex items-center gap-2 h-10 px-3 rounded-md bg-gray-100/60 text-gray-900">
            <Search className="w-4 h-4 text-gray-400 flex-shrink-0" strokeWidth={1.8} />
            <input
              ref={inputRef}
              type="text"
              value={keyword}
              onChange={(e) => setKeyword(e.target.value)}
              placeholder={
                activeTab === "user"
                  ? "搜索用户Porten账号/自己的昵称"
                  : "搜索营地名称/营地号"
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

        {/* Tabs */}
        <div className="flex items-center px-4 pb-3 bg-white sticky top-[52px] z-10">
          <button
            type="button"
            onClick={() => handleTabChange("user")}
            className={cn(
              "relative text-sm font-medium px-1 py-1 transition-colors",
              activeTab === "user" ? "text-[#F5A9B8]" : "text-[#5BCEFA]"
            )}
          >
            搜用户
            {activeTab === "user" && (
              <span className="absolute left-0 right-0 bottom-0 h-0.5 rounded-full bg-[#F5A9B8]" />
            )}
          </button>
          <button
            type="button"
            onClick={() => handleTabChange("group")}
            className={cn(
              "relative text-sm font-medium px-1 py-1 ml-6 transition-colors",
              activeTab === "group" ? "text-[#F5A9B8]" : "text-[#5BCEFA]"
            )}
          >
            搜营地
            {activeTab === "group" && (
              <span className="absolute left-0 right-0 bottom-0 h-0.5 rounded-full bg-[#F5A9B8]" />
            )}
          </button>
        </div>

        {/* Content */}
        {activeTab === "user" && (
          <div className="pb-6">
            {showSearchResult ? (
              <>
                {userResult ? (
                  <div className="space-y-[1px]">
                    <UserItem
                      avatar={userResult.avatar_url}
                      nickname={userResult.nickname}
                      portenId={userResult.porten_id}
                      onClick={() => handleUserClick(userResult)}
                    />
                  </div>
                ) : (
                  <EmptyState text="未搜索到相关用户" />
                )}
              </>
            ) : (
              <>
                <div className="px-4 py-2">
                  <p className="text-xs text-gray-400">我的同胞</p>
                </div>
                {myFriends.length > 0 ? (
                  <div className="space-y-[1px]">
                    {myFriends.map((user: ContactFriend) => (
                      <UserItem
                        key={user.id}
                        avatar={user.avatar_url}
                        nickname={user.nickname}
                      />
                    ))}
                  </div>
                ) : (
                  <EmptyState text="还没有添加同胞" />
                )}
              </>
            )}
          </div>
        )}

        {activeTab === "group" && (
          <div className="pb-6">
            {showSearchResult ? (
              <>
                {groupResults.length > 0 ? (
                  <div className="space-y-[1px]">
                    {groupResults.map((group: SearchGroupResult) => (
                      <GroupItem
                        key={group.id}
                        avatar={group.avatar_url}
                        name={group.name}
                        memberCount={group.member_count}
                        campId={group.camp_id}
                        keyword={normalizedKeyword}
                        onClick={() => handleGroupClick(group)}
                      />
                    ))}
                  </div>
                ) : (
                  <EmptyState text="未搜索到相关营地" />
                )}
              </>
            ) : (
              <>
                <div className="px-4 py-2">
                  <p className="text-xs text-gray-400">我已加入的营地</p>
                </div>
                {myGroups.length > 0 ? (
                  <div className="space-y-[1px]">
                    {myGroups.map((group: ContactGroup) => (
                      <GroupItem
                        key={group.id}
                        avatar={group.avatar_url}
                        name={group.name}
                      />
                    ))}
                  </div>
                ) : (
                  <EmptyState text="还没有加入营地" />
                )}
              </>
            )}
          </div>
        )}
      </div>

      <FriendApplyPage
        visible={applyPageVisible && selectedUser !== null}
        user={selectedUser}
        onClose={handleApplyClose}
        onSent={handleApplySent}
      />

      <GroupApplyPage
        visible={applyPageVisible && selectedGroup !== null}
        group={selectedGroup}
        onClose={handleApplyClose}
        onSent={handleApplySent}
      />
    </div>
  );
}
