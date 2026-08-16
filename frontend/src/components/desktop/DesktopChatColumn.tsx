import { MessageSquare } from "lucide-react";
import { ChatPage } from "@/components/home/ChatPage";
import { ChatItem } from "@/types/chat";

interface DesktopChatColumnProps {
  chat: ChatItem | null;
  onClose: () => void;
  onUserProfileClick?: (userId: number | string) => void;
}

/** 空会话占位：品牌渐变背景 + 引导文案。 */
function ChatPlaceholder() {
  return (
    <div className="h-full flex flex-col items-center justify-center relative overflow-hidden">
      {/* 柔和品牌渐变光斑 */}
      <div className="pointer-events-none absolute -top-20 -right-20 w-80 h-80 rounded-full opacity-[0.08] blur-3xl auth-blob auth-blob-1" />
      <div className="pointer-events-none absolute -bottom-24 -left-16 w-80 h-80 rounded-full opacity-[0.08] blur-3xl auth-blob auth-blob-2" />

      <div className="relative flex flex-col items-center">
        <div className="w-16 h-16 rounded-full bg-gray-100/80 flex items-center justify-center">
          <MessageSquare className="w-7 h-7 text-gray-300" strokeWidth={1.5} />
        </div>
        <p className="mt-5 text-sm text-gray-400">选择会话开始聊天</p>
        <p className="mt-1.5 text-xs text-gray-300">
          与同胞即时通信，分享图片、语音与文件
        </p>
      </div>
    </div>
  );
}

/** 第三栏：聊天详情（复用移动端 ChatPage，按会话 remount 触发滑入动画）。 */
export function DesktopChatColumn({
  chat,
  onClose,
  onUserProfileClick,
}: DesktopChatColumnProps) {
  if (!chat) {
    return <ChatPlaceholder />;
  }
  return (
    <div key={chat.id} className="h-full">
      <ChatPage
        chat={chat}
        visible
        onClose={onClose}
        onUserProfileClick={onUserProfileClick}
      />
    </div>
  );
}
