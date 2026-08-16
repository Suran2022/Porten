import { useEffect, useRef, useState } from "react";
import { TopBar } from "@/components/home/TopBar";
import { SearchBar } from "@/components/home/SearchBar";
import { SearchPage } from "@/components/home/SearchPage";
import { MessageList } from "@/components/home/MessageList";
import { BottomNav } from "@/components/home/BottomNav";
import { ResourceTopBar } from "@/components/resource/ResourceTopBar";
import { ResourceView } from "@/components/resource/ResourceView";
import { KnowledgeTopBar } from "@/components/knowledge/KnowledgeTopBar";
import { KnowledgeView } from "@/components/knowledge/KnowledgeView";
import { LearnCategoryMenu } from "@/components/knowledge/LearnCategoryMenu";
import { ProfilePage } from "@/components/profile/ProfilePage";
import { ComradeProfilePage } from "@/components/profile/ComradeProfilePage";
import { SettingsPage } from "@/components/profile/SettingsPage";
import { PortenSecurityPage } from "@/components/profile/PortenSecurityPage";
import { PortenAppBarPage } from "@/components/profile/PortenAppBarPage";
import { ChatPage } from "@/components/home/ChatPage";
import { PortenPartnerPage } from "@/components/home/PortenPartnerPage";
import { PortenAssistantDetailPage } from "@/components/home/PortenAssistantDetailPage";
import { MusicView } from "@/components/music/MusicView";
import { FloatingMusicWidget } from "@/components/music/FloatingMusicWidget";
import { MUSIC_TRACKS } from "@/data/music";
import { ResourceTab } from "@/types/resource";
import { KnowledgeTab, LearnCategory } from "@/types/knowledge";
import { ChatItem, ChatType } from "@/types/chat";
import { cn } from "@/lib/utils";
import { useContactStore } from "@/store/contactStore";
import { useChatStore } from "@/store/chatStore";
import { formatMessageTime } from "@/lib/utils";
import { useIsDesktop } from "@/hooks/useIsDesktop";
import HomePageDesktop from "@/pages/HomePageDesktop";

const APP_BAR_CONFIG_KEY = "porten_app_bar_config";

function loadShowMusic(): boolean {
  if (typeof window === "undefined") return false;
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
  if (typeof window === "undefined") return;
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
 * 首页入口：桌面宽度使用 PC 三栏布局，窄屏保持移动端布局不变。
 */
export default function HomePage() {
  const isDesktop = useIsDesktop();
  if (isDesktop) {
    return <HomePageDesktop />;
  }
  return <HomePageMobile />;
}

function HomePageMobile() {
  const [activeView, setActiveView] = useState(0);
  const [resourceTab, setResourceTab] = useState<ResourceTab>("hospital");
  const [knowledgeTab, setKnowledgeTab] = useState<KnowledgeTab>("share");
  const [knowledgeCategory, setKnowledgeCategory] = useState<LearnCategory>("community");
  const [knowledgeMenuFixed, setKnowledgeMenuFixed] = useState(false);
  const [profileVisible, setProfileVisible] = useState(false);
  const [settingsVisible, setSettingsVisible] = useState(false);
  const [securityVisible, setSecurityVisible] = useState(false);
  const [appBarVisible, setAppBarVisible] = useState(false);
  const [showMusic, setShowMusic] = useState<boolean>(() => loadShowMusic());
  const [musicVisible, setMusicVisible] = useState(false);
  const [floatingWidgetVisible, setFloatingWidgetVisible] = useState(false);
  const [trackIndex, setTrackIndex] = useState(0);
  // 未打开悦音乐前不自动播放；用户首次打开悦音乐后才开始播放
  const [isPlaying, setIsPlaying] = useState(false);
  const hasUserOpenedMusicRef = useRef(false);
  const [isLiked, setIsLiked] = useState(true);
  const [isFollowing, setIsFollowing] = useState(false);
  // 实时播放进度（秒），由 audio 元素 timeupdate 事件驱动
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(0);
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const currentTrack = MUSIC_TRACKS[trackIndex];
  const [partnerVisible, setPartnerVisible] = useState(false);
  const [searchVisible, setSearchVisible] = useState(false);
  const [homeFullPageOpen, setHomeFullPageOpen] = useState(false);
  const [selectedChat, setSelectedChat] = useState<ChatItem | null>(null);
  const [chatVisible, setChatVisible] = useState(false);
  // 同胞资料页
  const [comradeProfileVisible, setComradeProfileVisible] = useState(false);
  const [viewingUserId, setViewingUserId] = useState<number | string | null>(null);
  const [assistantDetailVisible, setAssistantDetailVisible] = useState(false);
  const [assistantDetailId, setAssistantDetailId] = useState<string | null>(
    null
  );
  const [assistantDetailName, setAssistantDetailName] = useState<string>("");

  const handleAssistantClick = (assistantId: string, assistantName: string) => {
    setAssistantDetailId(assistantId);
    setAssistantDetailName(assistantName);
    setAssistantDetailVisible(true);
  };

  const handleAssistantDetailClose = () => {
    setAssistantDetailVisible(false);
  };

  const handleKnowledgeTabChange = (tab: KnowledgeTab) => {
    setKnowledgeTab(tab);
    setKnowledgeMenuFixed(false);
  };

  const handleKnowledgeCategoryChange = (category: LearnCategory) => {
    setKnowledgeCategory(category);
    setKnowledgeMenuFixed(false);
  };

  const handleChatOpen = (item: ChatItem) => {
    if (item.type === "system") return;
    setSelectedChat(item);
    setChatVisible(true);
  };

  const handleChatClose = () => {
    setChatVisible(false);
  };

  // 打开同胞资料页
  const handleOpenComradeProfile = (userId: number | string) => {
    setViewingUserId(userId);
    setComradeProfileVisible(true);
  };

  // 同胞资料页"传达消息"：关闭资料页，根据 userId 定位会话并打开聊天页
  const conversations = useChatStore((state) => state.conversations);
  const loadConversations = useChatStore((state) => state.loadConversations);

  const handleSendMessage = async (userId: number | string) => {
    setComradeProfileVisible(false);
    const numericId = Number(userId);
    const matched = conversations.find(
      (c) => c.type === "friend" && c.friend_user_id === numericId
    );
    if (matched) {
      const chatItem: ChatItem = {
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
      };
      setSelectedChat(chatItem);
      setChatVisible(true);
      return;
    }
    // 本地未命中则刷新会话列表后再次尝试
    await loadConversations();
    const latest = useChatStore.getState().conversations;
    const rematch = latest.find(
      (c) => c.type === "friend" && c.friend_user_id === numericId
    );
    if (rematch) {
      const chatItem: ChatItem = {
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
      };
      setSelectedChat(chatItem);
      setChatVisible(true);
    }
  };

  const startPolling = useContactStore((state) => state.startPolling);
  const stopPolling = useContactStore((state) => state.stopPolling);

  useEffect(() => {
    startPolling();
    return () => {
      stopPolling();
    };
  }, [startPolling, stopPolling]);

  useEffect(() => {
    if (activeView !== 2) {
      setKnowledgeMenuFixed(false);
    }
  }, [activeView]);

  // 创建全局唯一 audio 元素并绑定事件
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

  // 切歌：加载新音源，重置进度，按 isPlaying 状态自动播放
  useEffect(() => {
    const audio = audioRef.current;
    if (!audio) return;
    const src = currentTrack.audioSrc;
    if (src) {
      audio.src = src;
      audio.load();
      setCurrentTime(0);
      if (isPlaying) {
        audio.play().catch(() => {
          // 自动播放被拦截，标记为暂停
          setIsPlaying(false);
        });
      }
    } else {
      // 无音源：清空 audio，进度用静态数据兜底
      audio.removeAttribute("src");
      audio.load();
      setCurrentTime(currentTrack.currentTime);
      setDuration(currentTrack.duration);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [trackIndex]);

  // 播放/暂停控制
  useEffect(() => {
    const audio = audioRef.current;
    if (!audio || !currentTrack.audioSrc) return;
    if (isPlaying) {
      audio.play().catch(() => setIsPlaying(false));
    } else {
      audio.pause();
    }
  }, [isPlaying, currentTrack.audioSrc]);

  // 进度跳转（供 MusicView 拖动进度条调用）
  const handleSeek = (time: number) => {
    const audio = audioRef.current;
    if (audio && currentTrack.audioSrc) {
      audio.currentTime = time;
      setCurrentTime(time);
    }
  };

  // 音乐页打开时，骨架背景透明，让 body 渐变透出，与 MusicView 共用同一渐变层，无分割
  return (
    <div className={cn("fixed inset-0", !musicVisible && "bg-white")} style={musicVisible ? { backgroundColor: "transparent" } : undefined}>
      {activeView === 0 && (
        <TopBar
          onProfileClick={() => setProfileVisible(true)}
          onFullPageOpenChange={setHomeFullPageOpen}
          onChatOpen={handleChatOpen}
          onUserClick={handleOpenComradeProfile}
        />
      )}
      {activeView === 1 && (
        <ResourceTopBar activeTab={resourceTab} onTabChange={setResourceTab} />
      )}
      {activeView === 2 && (
        <>
          <KnowledgeTopBar
            activeTab={knowledgeTab}
            onTabChange={handleKnowledgeTabChange}
            buttonsVisible={!knowledgeMenuFixed}
          />
          {knowledgeTab === "learn" && (
            <LearnCategoryMenu
              activeCategory={knowledgeCategory}
              onCategoryChange={handleKnowledgeCategoryChange}
              className={cn(
                "fixed left-0 right-0 z-50 transition-all duration-300",
                knowledgeMenuFixed ? "top-0" : "top-16"
              )}
            />
          )}
        </>
      )}

      <main className="fixed left-0 right-0 top-16 bottom-16">
        <div
          className="flex h-full w-[300%] transition-transform duration-500 ease-[cubic-bezier(0.25,0.1,0.25,1)] overflow-hidden"
          style={{ transform: `translateX(-${activeView * 33.333}%)` }}
        >
          <div className="h-full w-1/3 overflow-y-auto">
            <div className="max-w-md mx-auto">
              <SearchBar onClick={() => setSearchVisible(true)} />
              <MessageList
                onChatClick={handleChatOpen}
                onPartnerClick={() => setPartnerVisible(true)}
              />
            </div>
          </div>
          <div className="h-full w-1/3 overflow-y-auto">
            <div className="max-w-md mx-auto">
              <ResourceView activeTab={resourceTab} />
            </div>
          </div>
          <div className="h-full w-1/3 overflow-hidden">
            <div className="max-w-md mx-auto h-full">
              <KnowledgeView
                activeTab={knowledgeTab}
                activeCategory={knowledgeCategory}
                menuFixed={knowledgeMenuFixed}
                onMenuFixedChange={setKnowledgeMenuFixed}
              />
            </div>
          </div>
        </div>
      </main>

      {!profileVisible && !settingsVisible && !securityVisible && !appBarVisible && !partnerVisible && !assistantDetailVisible && !homeFullPageOpen && !musicVisible && !comradeProfileVisible && (
        <BottomNav
          activeIndex={activeView}
          onChange={setActiveView}
          showMusic={showMusic}
          onMusicClick={() => {
            // 首次打开悦音乐时开始播放，后续打开保持当前播放状态
            if (!hasUserOpenedMusicRef.current) {
              hasUserOpenedMusicRef.current = true;
              setIsPlaying(true);
            }
            setMusicVisible(true);
          }}
        />
      )}

      <PortenPartnerPage
        visible={partnerVisible}
        onClose={() => setPartnerVisible(false)}
        onAssistantClick={handleAssistantClick}
      />

      {/* Overlay behind profile page */}
      <div
        className={cn(
          "fixed inset-0 z-30 bg-black/30 transition-opacity duration-300",
          profileVisible ? "opacity-100" : "opacity-0 pointer-events-none"
        )}
        onClick={() => setProfileVisible(false)}
      />

      <ProfilePage
        visible={profileVisible}
        onClose={() => setProfileVisible(false)}
        onSettingsClick={() => setSettingsVisible(true)}
      />

      <SettingsPage
        visible={settingsVisible}
        onClose={() => setSettingsVisible(false)}
        onPortenSecurityClick={() => setSecurityVisible(true)}
        onAppBarClick={() => setAppBarVisible(true)}
      />

      <PortenSecurityPage
        visible={securityVisible}
        onClose={() => setSecurityVisible(false)}
      />

      <PortenAppBarPage
        visible={appBarVisible}
        onClose={() => setAppBarVisible(false)}
        showMusic={showMusic}
        onToggleMusic={(show) => {
          setShowMusic(show);
          saveShowMusic(show);
        }}
      />

      <PortenPartnerPage
        visible={partnerVisible}
        onClose={() => setPartnerVisible(false)}
        onAssistantClick={handleAssistantClick}
      />

      <PortenAssistantDetailPage
        visible={assistantDetailVisible}
        assistantId={assistantDetailId}
        assistantName={assistantDetailName}
        onClose={handleAssistantDetailClose}
      />

      <SearchPage
        visible={searchVisible}
        onClose={() => setSearchVisible(false)}
      />

      <ChatPage
        chat={selectedChat}
        visible={chatVisible}
        onClose={handleChatClose}
        onUserProfileClick={handleOpenComradeProfile}
      />

      <ComradeProfilePage
        visible={comradeProfileVisible}
        userId={viewingUserId}
        onClose={() => setComradeProfileVisible(false)}
        onSendMessage={() => {
          if (viewingUserId) handleSendMessage(viewingUserId);
        }}
      />

      <MusicView
        visible={musicVisible}
        onClose={() => {
          // 退出悦音乐：隐藏全屏页，显示悬浮窗，音乐继续播放
          setMusicVisible(false);
          setFloatingWidgetVisible(true);
        }}
        track={MUSIC_TRACKS[trackIndex]}
        isPlaying={isPlaying}
        onTogglePlay={() => setIsPlaying((v) => !v)}
        onPrev={() => setTrackIndex((i) => Math.max(0, i - 1))}
        onNext={() => setTrackIndex((i) => Math.min(MUSIC_TRACKS.length - 1, i + 1))}
        canPrev={trackIndex > 0}
        canNext={trackIndex < 0}
        isLiked={isLiked}
        onToggleLike={() => setIsLiked((v) => !v)}
        isFollowing={isFollowing}
        onToggleFollow={() => setIsFollowing((v) => !v)}
        currentTime={currentTrack.audioSrc ? currentTime : undefined}
        duration={currentTrack.audioSrc ? duration : undefined}
        onSeek={currentTrack.audioSrc ? handleSeek : undefined}
        coverImage="/music-cover.webp"
        tracks={MUSIC_TRACKS.filter((t) => t.audioSrc)}
        currentTrackIndex={MUSIC_TRACKS.filter((t) => t.audioSrc).findIndex((t) => t.id === currentTrack.id)}
        onSelectTrack={(i) => {
          const playable = MUSIC_TRACKS.filter((t) => t.audioSrc);
          const selected = playable[i];
          if (selected) {
            const originalIndex = MUSIC_TRACKS.findIndex((t) => t.id === selected.id);
            if (originalIndex >= 0) setTrackIndex(originalIndex);
          }
        }}
      />

      {/* 悬浮音乐窗：退出悦音乐后显示，点击重新打开，叉叉关闭并停止播放 */}
      <FloatingMusicWidget
        visible={floatingWidgetVisible}
        spinning={isPlaying}
        coverImage="/music-cover.webp"
        onClick={() => {
          setFloatingWidgetVisible(false);
          setMusicVisible(true);
        }}
        onClose={() => {
          setFloatingWidgetVisible(false);
          setIsPlaying(false);
        }}
      />
    </div>
  );
}
