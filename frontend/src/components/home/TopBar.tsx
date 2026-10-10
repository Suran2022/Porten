import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { Users, Plus } from "lucide-react";
import { currentUser } from "@/data/mock";
import { useAuthStore } from "@/store/authStore";
import { useContactStore } from "@/store/contactStore";
import { useToastStore } from "@/store/toastStore";
import { useChatStore } from "@/store/chatStore";
import { ChatItem } from "@/types/chat";
import { getMoodOption } from "@/types/emotionDiary";
import { formatMessageTime } from "@/lib/utils";
import { PlusMenu } from "./PlusMenu";
import { AddFriendPage } from "./AddFriendPage";
import { ContactsPage } from "./ContactsPage";
import { CreateGroupPage } from "./CreateGroupPage";
import { GroupProfilePage } from "./GroupProfilePage";
import { EmotionDiaryPage } from "./EmotionDiaryPage";
import { NotesPage } from "./NotesPage";

interface TopBarProps {
  onProfileClick?: () => void;
  onFullPageOpenChange?: (open: boolean) => void;
  onChatOpen?: (chat: ChatItem) => void;
  onUserClick?: (userId: number) => void;
}

function Badge({ count }: { count: number }) {
  if (count <= 0) return null;
  return (
    <span className="absolute -top-1 -right-1 min-w-[1.25rem] h-5 px-1 rounded-full bg-red-500 text-white text-xs font-medium flex items-center justify-center">
      {count > 99 ? "99+" : count}
    </span>
  );
}

export function TopBar({ onProfileClick, onFullPageOpenChange, onChatOpen, onUserClick }: TopBarProps) {
  const navigate = useNavigate();
  const [plusOpen, setPlusOpen] = useState(false);
  const [addFriendVisible, setAddFriendVisible] = useState(false);
  const [contactsVisible, setContactsVisible] = useState(false);
  const [createGroupVisible, setCreateGroupVisible] = useState(false);
  const [groupProfileVisible, setGroupProfileVisible] = useState(false);
  const [groupProfileType, setGroupProfileType] = useState("");
  const [notesVisible, setNotesVisible] = useState(false);
  const [emotionDiaryVisible, setEmotionDiaryVisible] = useState(false);
  const loadConversations = useChatStore((state) => state.loadConversations);
  const { user } = useAuthStore();
  const badge = useContactStore((state) => state.badge);
  const startPolling = useContactStore((state) => state.startPolling);
  const stopPolling = useContactStore((state) => state.stopPolling);

  useEffect(() => {
    onFullPageOpenChange?.(
      addFriendVisible ||
        contactsVisible ||
        createGroupVisible ||
        groupProfileVisible ||
        notesVisible ||
        emotionDiaryVisible
    );
  }, [
    addFriendVisible,
    contactsVisible,
    createGroupVisible,
    groupProfileVisible,
    notesVisible,
    emotionDiaryVisible,
    onFullPageOpenChange,
  ]);

  useEffect(() => {
    startPolling();
    return () => {
      stopPolling();
    };
  }, [startPolling, stopPolling]);

  const avatar = user?.avatar || currentUser.avatar;
  const nickname = user?.nickname || currentUser.nickname;
  const moodOption = getMoodOption(user?.mood);
  const mood = moodOption
    ? `${moodOption.emoji} ${moodOption.label}`
    : currentUser.mood;
  const latestDiary = user?.latestDiary ?? null;
  const badgeCount = badge.friend_requests + badge.group_requests;

  return (
    <header className="fixed top-0 left-0 right-0 z-40 bg-white w-full">
      <div className="max-w-md mx-auto h-16 px-4 flex items-center justify-between relative">
        {/* Left: avatar, nickname, mood, latest diary
            （items-end：文本列底与头像底对齐，日记行底部即成为右侧图标的对齐基准线） */}
        <button
          type="button"
          onClick={onProfileClick}
          className="flex items-end gap-3 text-left flex-1 min-w-0"
        >
          <img
            src={avatar}
            alt={nickname}
            className="w-10 h-10 rounded-full object-cover bg-gray-100 flex-shrink-0"
          />
          <div className="flex flex-col flex-1 min-w-0">
            <span className="text-base font-semibold text-gray-900 leading-tight">
              {nickname}
            </span>
            <div className="flex items-center mt-0.5 min-w-0">
              <span className="text-xs text-gray-500 leading-tight flex-shrink-0">
                {mood}
              </span>
              {latestDiary ? (
                <>
                  <span
                    aria-hidden
                    className="mx-1.5 text-xs text-gray-300 leading-tight flex-shrink-0 select-none"
                  >
                    ｜
                  </span>
                  <span className="text-xs text-gray-500 leading-tight truncate">
                    {latestDiary}
                  </span>
                </>
              ) : null}
            </div>
          </div>
        </button>

        {/* Right: contacts, plus menu
            （-mr-1.5：Plus 图形右缘与搜索框右缘对齐；ml-2 保证与日记文本间距 ≥ 8px） */}
        <div className="flex items-center gap-1 relative ml-2 -mr-1.5 flex-shrink-0">
          <button
            type="button"
            onClick={() => setContactsVisible(true)}
            className="relative w-10 h-10 flex items-center justify-center rounded-full text-gray-600 hover:bg-gray-100/50 transition-colors"
          >
            {/* 下移抵消按钮内居中空隙（(40-24)/2=8px），使图形底部与日记行底线对齐 */}
            <Users className="w-6 h-6 translate-y-2" strokeWidth={1.8} />
            <Badge count={badgeCount} />
          </button>
          <button
            type="button"
            onClick={() => setPlusOpen((prev) => !prev)}
            className="w-10 h-10 flex items-center justify-center rounded-full text-gray-600 hover:bg-gray-100/50 transition-colors"
          >
            {/* 下移抵消按钮内居中空隙（(40-28)/2=6px），使图形底部与日记行底线对齐 */}
            <Plus className="w-7 h-7 translate-y-1.5" strokeWidth={1.8} />
          </button>

          <PlusMenu
            open={plusOpen}
            onClose={() => setPlusOpen(false)}
            onAddFriend={() => setAddFriendVisible(true)}
            onCreateGroup={() => setCreateGroupVisible(true)}
            onCreateAgreement={() => navigate("/agreement")}
            onCreateJourney={() => navigate("/trip/create")}
            onSchedule={() => navigate("/schedule")}
            onWorkplace={() => navigate("/workplace")}
            onScan={() =>
              useToastStore
                .getState()
                .show("扫一扫功能即将上线，敬请期待", "info", "center")
            }
            onPlaceholder={(label) =>
              useToastStore
                .getState()
                .show(`${label}功能即将上线，敬请期待`, "info", "center")
            }
            onNote={() => setNotesVisible(true)}
            onMoodDiary={() => setEmotionDiaryVisible(true)}
          />
        </div>
      </div>

      <AddFriendPage
        visible={addFriendVisible}
        onClose={() => setAddFriendVisible(false)}
      />

      <ContactsPage
        visible={contactsVisible}
        onClose={() => setContactsVisible(false)}
        onUserClick={onUserClick}
      />

      <CreateGroupPage
        visible={createGroupVisible}
        onClose={() => setCreateGroupVisible(false)}
        onSelectCategory={(category) => {
          setGroupProfileType(category);
          setGroupProfileVisible(true);
        }}
      />

      <GroupProfilePage
        visible={groupProfileVisible}
        groupType={groupProfileType}
        onClose={() => {
          setGroupProfileVisible(false);
          setCreateGroupVisible(false);
          setGroupProfileType("");
        }}
        onBack={() => {
          setGroupProfileVisible(false);
          setGroupProfileType("");
        }}
        onCreated={async ({ conversationId, name, avatar, memberCount }) => {
            setGroupProfileVisible(false);
            setCreateGroupVisible(false);
            setGroupProfileType("");
            await loadConversations();
            const nowStr = new Date().toISOString();
            onChatOpen?.({
              id: `group_${conversationId}`,
              type: "group",
              name,
              avatar,
              lastMessage: `您已成功组建${name}营地`,
              lastMessageTime: formatMessageTime(nowStr),
              timestamp: nowStr,
              unreadCount: 0,
              memberCount,
            });
          }}
      />

      <NotesPage
        visible={notesVisible}
        onClose={() => setNotesVisible(false)}
      />

      <EmotionDiaryPage
        visible={emotionDiaryVisible}
        onClose={() => setEmotionDiaryVisible(false)}
      />
    </header>
  );
}
