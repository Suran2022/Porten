import { useEffect, useRef, useState } from "react";
import { cn } from "@/lib/utils";
import { ChatItem, ChatType } from "@/types/chat";
import { ResourceTab } from "@/types/resource";
import { KnowledgeTab, LearnCategory } from "@/types/knowledge";
import { MUSIC_TRACKS } from "@/data/music";
import { formatMessageTime } from "@/lib/utils";

import { PcDialog } from "@/components/desktop/PcDialog";
import { DesktopSidebar, DesktopNavKey } from "@/components/desktop/DesktopSidebar";
import { DesktopTopBar } from "@/components/desktop/DesktopTopBar";
import { DesktopMessagesColumn } from "@/components/desktop/DesktopMessagesColumn";
import { DesktopChatColumn } from "@/components/desktop/DesktopChatColumn";
import {
  DesktopKnowledgeContent,
  DesktopKnowledgePanel,
  DesktopResourceContent,
  DesktopResourcePanel,
} from "@/components/desktop/DesktopCatalogPanels";

import { ContactsPage } from "@/components/home/ContactsPage";
import { SearchPage } from "@/components/home/SearchPage";
import { AddFriendPage } from "@/components/home/AddFriendPage";
import { CreateGroupPage } from "@/components/home/CreateGroupPage";
import { GroupProfilePage } from "@/components/home/GroupProfilePage";
import { EmotionDiaryPage } from "@/components/home/EmotionDiaryPage";
import { NotesPage } from "@/components/home/NotesPage";
import { SystemMessagesPage } from "@/components/home/SystemMessagesPage";
import { PortenPartnerPage } from "@/components/home/PortenPartnerPage";
import { PortenAssistantDetailPage } from "@/components/home/PortenAssistantDetailPage";
import { ComradeProfilePage } from "@/components/profile/ComradeProfilePage";
import { ProfilePage } from "@/components/profile/ProfilePage";
import { SettingsPage } from "@/components/profile/SettingsPage";
import { PortenSecurityPage } from "@/components/profile/PortenSecurityPage";
import { PortenAppBarPage } from "@/components/profile/PortenAppBarPage";
import { MusicView } from "@/components/music/MusicView";
import { FloatingMusicWidget } from "@/components/music/FloatingMusicWidget";

import { useContactStore } from "@/store/contactStore";
import { useChatStore } from "@/store/chatStore";

const APP_BAR_CONFIG_KEY = "porten_app_bar_config";

function loadShowMusic(): boolean {
  try {
    const raw = window.localStorage.getItem(APP_BAR_CONFIG_KEY);
    if (!raw) return false;
    const parsed = JSON.parse(raw);
    return Boolean(parsed?.showMusic);
  } catch {
    return false;
  }
}

function saveShowMusic(show: boolean) {
  try {
    window.localStorage.setItem(
      APP_BAR_CONFIG_KEY,
      JSON.stringify({ showMusic: show })
    );
  } catch {
    // ignore
  }
}

/**
 * PC 端三栏布局：
 * - 第一栏：侧边栏（移动端底部菜单 + 设置，个人卡片与加号菜单）
 * - 第二栏：搜索框 + 消息列表 / 联系人 / 分类菜单
 * - 第三栏：聊天详情 / 资源与知识内容 / 空态
 */
export default function HomePageDesktop() {
  const [activeNav, setActiveNav] = useState<DesktopNavKey>("messages");
  const [selectedChat, setSelectedChat] = useState<ChatItem | null>(null);

  const [resourceTab, setResourceTab] = useState<ResourceTab>("hospital");
  const [knowledgeTab, setKnowledgeTab] = useState<KnowledgeTab>("share");
  const [knowledgeCategory, setKnowledgeCategory] = useState<LearnCategory>("community");

  // 弹窗状态
  const [searchOpen, setSearchOpen] = useState(false);
  const [profileOpen, setProfileOpen] = useState(false);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [securityOpen, setSecurityOpen] = useState(false);
  const [appBarOpen, setAppBarOpen] = useState(false);
  const [addFriendOpen, setAddFriendOpen] = useState(false);
  const [groupDialogOpen, setGroupDialogOpen] = useState(false);
  const [groupType, setGroupType] = useState("");
  const [diaryOpen, setDiaryOpen] = useState(false);
  const [notesOpen, setNotesOpen] = useState(false);
  const [systemMessagesOpen, setSystemMessagesOpen] = useState(false);
  const [partnerOpen, setPartnerOpen] = useState(false);
  const [assistantOpen, setAssistantOpen] = useState(false);
  const [assistantId, setAssistantId] = useState<string | null>(null);
  const [assistantName, setAssistantName] = useState("");
  const [comradeOpen, setComradeOpen] = useState(false);
  const [viewingUserId, setViewingUserId] = useState<number | string | null>(null);

  // 悦音乐
  const [showMusic, setShowMusic] = useState<boolean>(() => loadShowMusic());
  const [musicOpen, setMusicOpen] = useState(false);
  const [floatingWidgetVisible, setFloatingWidgetVisible] = useState(false);
  const [trackIndex, setTrackIndex] = useState(0);
  const [isPlaying, setIsPlaying] = useState(false);
  const hasUserOpenedMusicRef = useRef(false);
  const [isLiked, setIsLiked] = useState(true);
  const [isFollowing, setIsFollowing] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(0);
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const currentTrack = MUSIC_TRACKS[trackIndex];

  const conversations = useChatStore((state) => state.conversations);
  const loadConversations = useChatStore((state) => state.loadConversations);
  const startPolling = useContactStore((state) => state.startPolling);
  const stopPolling = useContactStore((state) => state.stopPolling);

  useEffect(() => {
    startPolling();
    return () => {
      stopPolling();
    };
  }, [startPolling, stopPolling]);

  // 全局唯一 audio 元素（与移动端一致）
  useEffect(() => {
    const audio = new Audio();
    audio.preload = "metadata";
    audioRef.current = audio;

    const onTimeUpdate = () => setCurrentTime(audio.currentTime);
    const onLoadedMeta = () => setDuration(audio.duration || 0);
    const onEnded = () => setIsPlaying(false);

    audio.addEventListener("timeupdate", onTimeUpdate);
    audio.addEventListener("loadedmetadata", onLoadedMeta);
    audio.addEventListener("ended", onEnded);

    return () => {
      audio.pause();
      audio.removeEventListener("timeupdate", onTimeUpdate);
      audio.removeEventListener("loadedmetadata", onLoadedMeta);
      audio.removeEventListener("ended", onEnded);
      audioRef.current = null;
    };
  }, []);

  useEffect(() => {
    const audio = audioRef.current;
    if (!audio) return;
    const src = currentTrack.audioSrc;
    if (src) {
      audio.src = src;
      audio.load();
      setCurrentTime(0);
      if (isPlaying) {
        audio.play().catch(() => setIsPlaying(false));
      }
    } else {
      audio.removeAttribute("src");
      audio.load();
      setCurrentTime(currentTrack.currentTime);
      setDuration(currentTrack.duration);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [trackIndex]);

  useEffect(() => {
    const audio = audioRef.current;
    if (!audio || !currentTrack.audioSrc) return;
    if (isPlaying) {
      audio.play().catch(() => setIsPlaying(false));
    } else {
      audio.pause();
    }
  }, [isPlaying, currentTrack.audioSrc]);

  const handleSeek = (time: number) => {
    const audio = audioRef.current;
    if (audio && currentTrack.audioSrc) {
      audio.currentTime = time;
      setCurrentTime(time);
    }
  };

  /* ---------------- 会话打开 / 同胞资料 ---------------- */

  const handleChatOpen = (item: ChatItem) => {
    if (item.type === "system") return;
    setSelectedChat(item);
  };

  const handleOpenComradeProfile = (userId: number | string) => {
    setViewingUserId(userId);
    setComradeOpen(true);
  };

  const handleSendMessage = async (userId: number | string) => {
    setComradeOpen(false);
    setActiveNav("messages");
    const numericId = Number(userId);
    const matched = conversations.find(
      (c) => c.type === "friend" && c.friend_user_id === numericId
    );
    if (matched) {
      setSelectedChat({
        id: `${matched.type}_${matched.id}`,
        type: matched.type as ChatType,
        name: matched.name,
        avatar: matched.avatar,
        lastMessage: matched.last_message,
        lastMessageTime: formatMessageTime(matched.last_message_time),
        timestamp: matched.last_message_time || "",
        unreadCount: matched.unread_count,
        memberCount: matched.member_count,
        senderId: matched.last_message_sender_id,
        senderName: matched.last_message_sender_name,
      });
      return;
    }
    await loadConversations();
    const latest = useChatStore.getState().conversations;
    const rematch = latest.find(
      (c) => c.type === "friend" && c.friend_user_id === numericId
    );
    if (rematch) {
      setSelectedChat({
        id: `${rematch.type}_${rematch.id}`,
        type: rematch.type as ChatType,
        name: rematch.name,
        avatar: rematch.avatar,
        lastMessage: rematch.last_message,
        lastMessageTime: formatMessageTime(rematch.last_message_time),
        timestamp: rematch.last_message_time || "",
        unreadCount: rematch.unread_count,
        memberCount: rematch.member_count,
        senderId: rematch.last_message_sender_id,
        senderName: rematch.last_message_sender_name,
      });
    }
  };

  /* ---------------- 第二栏内容 ---------------- */

  const renderColumn2 = () => {
    if (activeNav === "contacts") {
      return (
        <ContactsPage
          visible
          onClose={() => setActiveNav("messages")}
          onUserClick={handleOpenComradeProfile}
        />
      );
    }
    if (activeNav === "resources") {
      return (
        <DesktopResourcePanel
          activeTab={resourceTab}
          onTabChange={setResourceTab}
        />
      );
    }
    if (activeNav === "knowledge") {
      return (
        <DesktopKnowledgePanel
          activeTab={knowledgeTab}
          activeCategory={knowledgeCategory}
          onTabChange={setKnowledgeTab}
          onCategoryChange={setKnowledgeCategory}
        />
      );
    }
    return (
      <DesktopMessagesColumn
        onChatOpen={handleChatOpen}
        onPartnerOpen={() => setPartnerOpen(true)}
      />
    );
  };

  /* ---------------- 第三栏内容 ---------------- */

  const renderColumn3 = () => {
    if (activeNav === "resources") {
      return <DesktopResourceContent activeTab={resourceTab} />;
    }
    if (activeNav === "knowledge") {
      return (
        <DesktopKnowledgeContent
          activeTab={knowledgeTab}
          activeCategory={knowledgeCategory}
        />
      );
    }
    return (
      <DesktopChatColumn
        chat={activeNav === "contacts" ? null : selectedChat}
        onClose={() => setSelectedChat(null)}
        onUserProfileClick={handleOpenComradeProfile}
      />
    );
  };

  const playableTracks = MUSIC_TRACKS.filter((t) => t.audioSrc);

  return (
    <div className="fixed inset-0 bg-white flex overflow-hidden">
      <DesktopSidebar
        active={activeNav}
        onNavChange={setActiveNav}
        onProfileOpen={() => setProfileOpen(true)}
        onSettingsOpen={() => setSettingsOpen(true)}
        onMusicOpen={() => {
          if (!hasUserOpenedMusicRef.current) {
            hasUserOpenedMusicRef.current = true;
            setIsPlaying(true);
          }
          setMusicOpen(true);
        }}
        showMusic={showMusic}
      />

      {/* 第二、三栏合并的顶部栏 + 下方两栏内容 */}
      <div className="flex-1 min-w-0 flex flex-col">
        <DesktopTopBar
          active={activeNav}
          onSearchOpen={() => setSearchOpen(true)}
          onSystemMessagesOpen={() => setSystemMessagesOpen(true)}
          onAddFriendOpen={() => setAddFriendOpen(true)}
          onCreateGroupOpen={() => {
            setGroupType("");
            setGroupDialogOpen(true);
          }}
          onNotesOpen={() => setNotesOpen(true)}
          onDiaryOpen={() => setDiaryOpen(true)}
        />

        <div className="flex-1 min-h-0 flex">
          {/* 第二栏：消息列表 / 联系人 / 分类菜单（transform 收敛内部 fixed 页面） */}
          <div
            className="relative h-full w-[320px] shrink-0 border-r border-gray-100 overflow-hidden"
            style={{ transform: "translateZ(0)" }}
          >
            <div
              key={activeNav}
              className={cn(
                "h-full",
                activeNav !== "contacts" && "animate-content-in"
              )}
            >
              {renderColumn2()}
            </div>
          </div>

          {/* 第三栏：聊天详情 / 内容 */}
          <div
            className="relative h-full flex-1 min-w-0 overflow-hidden bg-white"
            style={{ transform: "translateZ(0)" }}
          >
            <div
              key={`${activeNav}-${activeNav === "messages" ? selectedChat?.id ?? "empty" : ""}`}
              className={cn(
                "h-full",
                activeNav !== "messages" && "animate-content-in"
              )}
            >
              {renderColumn3()}
            </div>
          </div>
        </div>
      </div>

      {/* ============ 弹窗层 ============ */}

      <PcDialog open={searchOpen} onClose={() => setSearchOpen(false)} width={640} height={640}>
        <SearchPage visible closeMode onClose={() => setSearchOpen(false)} />
      </PcDialog>

      <PcDialog open={profileOpen} onClose={() => setProfileOpen(false)} width={420} height={720}>
        <ProfilePage
          visible
          onClose={() => setProfileOpen(false)}
          onSettingsClick={() => {
            setProfileOpen(false);
            setSettingsOpen(true);
          }}
        />
      </PcDialog>

      <PcDialog open={settingsOpen} onClose={() => setSettingsOpen(false)} width={420} height={560}>
        <SettingsPage
          visible
          closeMode
          onClose={() => setSettingsOpen(false)}
          onPortenSecurityClick={() => {
            setSettingsOpen(false);
            setSecurityOpen(true);
          }}
          onAppBarClick={() => {
            setSettingsOpen(false);
            setAppBarOpen(true);
          }}
        />
      </PcDialog>

      <PcDialog open={securityOpen} onClose={() => { setSecurityOpen(false); setSettingsOpen(true); }} width={420} height={640}>
        <PortenSecurityPage visible onClose={() => { setSecurityOpen(false); setSettingsOpen(true); }} />
      </PcDialog>

      <PcDialog open={appBarOpen} onClose={() => { setAppBarOpen(false); setSettingsOpen(true); }} width={420} height={560}>
        <PortenAppBarPage
          visible
          closeMode
          onClose={() => { setAppBarOpen(false); setSettingsOpen(true); }}
          showMusic={showMusic}
          onToggleMusic={(show) => {
            setShowMusic(show);
            saveShowMusic(show);
          }}
        />
      </PcDialog>

      <PcDialog open={addFriendOpen} onClose={() => setAddFriendOpen(false)} width={440} height={640}>
        <AddFriendPage visible closeMode onClose={() => setAddFriendOpen(false)} />
      </PcDialog>

      {/* 组建营地：分类选择 → 营地资料（同一弹窗内切换） */}
      <PcDialog open={groupDialogOpen} onClose={() => { setGroupDialogOpen(false); setGroupType(""); }} width={440} height={640}>
        <CreateGroupPage
          visible={!groupType}
          onClose={() => { setGroupDialogOpen(false); setGroupType(""); }}
          onSelectCategory={(category) => setGroupType(category)}
        />
        {groupType && (
          <GroupProfilePage
            visible
            closeMode
            groupType={groupType}
            onClose={() => { setGroupDialogOpen(false); setGroupType(""); }}
            onBack={() => setGroupType("")}
            onCreated={async ({ conversationId, name, avatar, memberCount }) => {
              setGroupDialogOpen(false);
              setGroupType("");
              setActiveNav("messages");
              await loadConversations();
              const nowStr = new Date().toISOString();
              setSelectedChat({
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
        )}
      </PcDialog>

      <PcDialog open={diaryOpen} onClose={() => setDiaryOpen(false)} width={420} height={700}>
        <EmotionDiaryPage visible onClose={() => setDiaryOpen(false)} />
      </PcDialog>

      <PcDialog open={notesOpen} onClose={() => setNotesOpen(false)} width={420} height={640}>
        <NotesPage visible onClose={() => setNotesOpen(false)} />
      </PcDialog>

      <PcDialog open={systemMessagesOpen} onClose={() => setSystemMessagesOpen(false)} width={420} height={640}>
        <SystemMessagesPage visible onClose={() => setSystemMessagesOpen(false)} />
      </PcDialog>

      <PcDialog open={comradeOpen} onClose={() => setComradeOpen(false)} width={420} height={720}>
        <ComradeProfilePage
          visible
          userId={viewingUserId}
          onClose={() => setComradeOpen(false)}
          onSendMessage={() => {
            if (viewingUserId) handleSendMessage(viewingUserId);
          }}
        />
      </PcDialog>

      <PcDialog open={partnerOpen} onClose={() => setPartnerOpen(false)} width={420} height={700}>
        <PortenPartnerPage
          visible
          closeMode
          onClose={() => setPartnerOpen(false)}
          onAssistantClick={(id, name) => {
            setAssistantId(id);
            setAssistantName(name);
            setAssistantOpen(true);
          }}
        />
      </PcDialog>

      <PcDialog open={assistantOpen} onClose={() => setAssistantOpen(false)} width={420} height={720}>
        <PortenAssistantDetailPage
          visible
          closeMode
          assistantId={assistantId}
          assistantName={assistantName}
          onClose={() => setAssistantOpen(false)}
        />
      </PcDialog>

      {/* 悦音乐（PC 弹窗形态） */}
      <PcDialog
        open={musicOpen}
        onClose={() => {
          setMusicOpen(false);
          setFloatingWidgetVisible(true);
        }}
        width={420}
        height={760}
      >
        <MusicView
          visible
          onClose={() => {
            setMusicOpen(false);
            setFloatingWidgetVisible(true);
          }}
          track={currentTrack}
          isPlaying={isPlaying}
          onTogglePlay={() => setIsPlaying((v) => !v)}
          onPrev={() => setTrackIndex((i) => Math.max(0, i - 1))}
          onNext={() => setTrackIndex((i) => Math.min(MUSIC_TRACKS.length - 1, i + 1))}
          canPrev={trackIndex > 0}
          canNext={trackIndex < MUSIC_TRACKS.length - 1}
          isLiked={isLiked}
          onToggleLike={() => setIsLiked((v) => !v)}
          isFollowing={isFollowing}
          onToggleFollow={() => setIsFollowing((v) => !v)}
          currentTime={currentTrack.audioSrc ? currentTime : undefined}
          duration={currentTrack.audioSrc ? duration : undefined}
          onSeek={currentTrack.audioSrc ? handleSeek : undefined}
          coverImage="/music-cover.webp"
          tracks={playableTracks}
          currentTrackIndex={playableTracks.findIndex((t) => t.id === currentTrack.id)}
          onSelectTrack={(i) => {
            const selected = playableTracks[i];
            if (selected) {
              const originalIndex = MUSIC_TRACKS.findIndex((t) => t.id === selected.id);
              if (originalIndex >= 0) setTrackIndex(originalIndex);
            }
          }}
        />
      </PcDialog>

      <FloatingMusicWidget
        visible={floatingWidgetVisible}
        spinning={isPlaying}
        coverImage="/music-cover.webp"
        onClick={() => {
          setFloatingWidgetVisible(false);
          setMusicOpen(true);
        }}
        onClose={() => {
          setFloatingWidgetVisible(false);
          setIsPlaying(false);
        }}
      />
    </div>
  );
}
