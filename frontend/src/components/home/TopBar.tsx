import { useEffect, useState } from "react";
import { Mail, Users, Plus } from "lucide-react";
import { currentUser } from "@/data/mock";
import { useAuthStore } from "@/store/authStore";
import { useContactStore } from "@/store/contactStore";
import { useSystemMessageStore } from "@/store/systemMessageStore";
import { useChatStore } from "@/store/chatStore";
import { ChatItem } from "@/types/chat";
import { getMoodOption } from "@/types/emotionDiary";
import { formatMessageTime } from "@/lib/utils";
import { PlusMenu } from "./PlusMenu";
import { AddFriendPage } from "./AddFriendPage";
import { ContactsPage } from "./ContactsPage";
import { CreateGroupPage } from "./CreateGroupPage";
import { GroupProfilePage } from "./GroupProfilePage";
import { SystemMessagesPage } from "./SystemMessagesPage";
import { EmotionDiaryPage } from "./EmotionDiaryPage";

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
  const [plusOpen, setPlusOpen] = useState(false);
  const [addFriendVisible, setAddFriendVisible] = useState(false);
  const [contactsVisible, setContactsVisible] = useState(false);
  const [createGroupVisible, setCreateGroupVisible] = useState(false);
  const [groupProfileVisible, setGroupProfileVisible] = useState(false);
  const [groupProfileType, setGroupProfileType] = useState("");
  const [systemMessagesVisible, setSystemMessagesVisible] = useState(false);
  const [emotionDiaryVisible, setEmotionDiaryVisible] = useState(false);
  const loadConversations = useChatStore((state) => state.loadConversations);
  const { user } = useAuthStore();
  const badge = useContactStore((state) => state.badge);
  const startPolling = useContactStore((state) => state.startPolling);
  const stopPolling = useContactStore((state) => state.stopPolling);
  const systemUnreadCount = useSystemMessageStore((state) => state.unreadCount);
  const loadSystemUnreadCount = useSystemMessageStore(
    (state) => state.loadUnreadCount
  );

  useEffect(() => {
    loadSystemUnreadCount();
  }, [loadSystemUnreadCount]);

  useEffect(() => {
    onFullPageOpenChange?.(
      addFriendVisible ||
        contactsVisible ||
        createGroupVisible ||
        groupProfileVisible ||
        systemMessagesVisible ||
        emotionDiaryVisible
    );
  }, [
    addFriendVisible,
    contactsVisible,
    createGroupVisible,
    groupProfileVisible,
    systemMessagesVisible,
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
  const badgeCount = badge.friend_requests + badge.group_requests;

  return (
    <header className="fixed top-0 left-0 right-0 z-40 bg-white w-full">
      <div className="max-w-md mx-auto h-16 px-4 flex items-center justify-between relative">
        {/* Left: avatar, nickname, mood */}
        <button
          type="button"
          onClick={onProfileClick}
          className="flex items-center gap-3 text-left"
        >
          <img
            src={avatar}
            alt={nickname}
            className="w-10 h-10 rounded-full object-cover bg-gray-100"
          />
          <div className="flex flex-col">
            <span className="text-base font-semibold text-gray-900 leading-tight">
              {nickname}
            </span>
            <span className="text-xs text-gray-500 leading-tight mt-0.5">
              {mood}
            </span>
          </div>
        </button>

        {/* Right: private messages, contacts, plus menu */}
        <div className="flex items-center gap-1 relative">
          <button
            type="button"
            onClick={() => setSystemMessagesVisible(true)}
            className="relative w-10 h-10 flex items-center justify-center rounded-full text-gray-600 hover:bg-gray-100/50 transition-colors"
          >
            <Mail className="w-5 h-5" strokeWidth={1.8} />
            {systemUnreadCount > 0 && (
              <span className="absolute top-1.5 right-1.5 w-2 h-2 rounded-full bg-red-500" />
            )}
          </button>
          <button
            type="button"
            onClick={() => setContactsVisible(true)}
            className="relative w-10 h-10 flex items-center justify-center rounded-full text-gray-600 hover:bg-gray-100/50 transition-colors"
          >
            <Users className="w-5 h-5" strokeWidth={1.8} />
            <Badge count={badgeCount} />
          </button>
          <button
            type="button"
            onClick={() => setPlusOpen((prev) => !prev)}
            className="w-10 h-10 flex items-center justify-center rounded-full text-gray-600 hover:bg-gray-100/50 transition-colors"
          >
            <Plus className="w-5 h-5" strokeWidth={1.8} />
          </button>

          <PlusMenu
            open={plusOpen}
            onClose={() => setPlusOpen(false)}
            onAddFriend={() => setAddFriendVisible(true)}
            onCreateGroup={() => setCreateGroupVisible(true)}
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

      <SystemMessagesPage
        visible={systemMessagesVisible}
        onClose={() => setSystemMessagesVisible(false)}
      />

      <EmotionDiaryPage
        visible={emotionDiaryVisible}
        onClose={() => setEmotionDiaryVisible(false)}
      />
    </header>
  );
}
