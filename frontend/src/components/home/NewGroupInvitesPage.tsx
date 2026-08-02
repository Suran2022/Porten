import { useEffect, useRef, useState } from "react";
import { ArrowLeft, ChevronRight } from "lucide-react";
import { cn } from "@/lib/utils";
import { GroupRequestItem } from "@/lib/api";
import { useContactStore } from "@/store/contactStore";
import { CampAvatar } from "./CampAvatar";

interface NewGroupInvitesPageProps {
  visible: boolean;
  onClose: () => void;
}

function InvitationCard({ invitation }: { invitation: GroupRequestItem }) {
  const [open, setOpen] = useState(false);
  const [processing, setProcessing] = useState(false);
  const handleGroupRequest = useContactStore((state) => state.handleGroupRequest);

  const handleAction = async (action: "accept" | "reject") => {
    if (processing) return;
    setProcessing(true);
    try {
      await handleGroupRequest(invitation.id, action);
    } catch (err) {
      console.error("handle group request failed", err);
    } finally {
      setProcessing(false);
      setOpen(false);
    }
  };

  return (
    <div className="px-4 py-3 bg-white active:bg-gray-50/50 transition-colors">
      <div className="flex items-start gap-3">
        <CampAvatar
          src={invitation.group_avatar_url}
          name={invitation.group_name}
          size={44}
        />
        <div className="flex-1 min-w-0">
          <p className="text-base font-medium text-gray-900 truncate">
            {invitation.group_name}
          </p>
          <p className="text-sm text-gray-600 mt-1 leading-relaxed">
            申请者：{invitation.user_nickname}
          </p>
          <p className="text-sm text-gray-600 mt-1 leading-relaxed">
            {invitation.message}
          </p>
          <p className="text-xs text-gray-400 mt-1 truncate">
            申请加入营地
          </p>
        </div>
        <button
          type="button"
          onClick={() => setOpen((prev) => !prev)}
          className="flex items-center gap-1 text-sm text-gray-600 flex-shrink-0 mt-0.5"
        >
          <span>处理请求</span>
          <ChevronRight
            className={cn(
              "w-4 h-4 text-gray-400 transition-transform duration-200 ease-out",
              open && "rotate-90"
            )}
            strokeWidth={1.5}
          />
        </button>
      </div>

      {/* Expandable options */}
      <div
        className={cn(
          "grid transition-all duration-200 ease-out",
          open ? "grid-rows-[1fr] mt-3" : "grid-rows-[0fr]"
        )}
      >
        <div className="overflow-hidden">
          <div className="flex items-center justify-end gap-3">
            <button
              type="button"
              disabled={processing}
              onClick={() => handleAction("accept")}
              className="px-4 py-1.5 rounded-full text-sm text-white bg-[#F5A9B8] active:opacity-90 transition-opacity disabled:opacity-50"
            >
              接受
            </button>
            <button
              type="button"
              disabled={processing}
              onClick={() => handleAction("reject")}
              className="px-4 py-1.5 rounded-full text-sm text-[#5BCEFA] border border-[#5BCEFA] active:bg-blue-50/50 transition-colors disabled:opacity-50"
            >
              拒绝
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

function EmptyState() {
  return (
    <div className="flex flex-col items-center justify-center py-16 px-6">
      <p className="text-sm text-gray-400 text-center">暂无新营地邀请或申请</p>
    </div>
  );
}

export function NewGroupInvitesPage({ visible, onClose }: NewGroupInvitesPageProps) {
  const [isEntering, setIsEntering] = useState(false);
  const closeTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const groupRequests = useContactStore((state) => state.groupRequests);
  const loadGroupRequests = useContactStore((state) => state.loadGroupRequests);

  useEffect(() => {
    if (visible) {
      if (closeTimerRef.current) {
        clearTimeout(closeTimerRef.current);
        closeTimerRef.current = null;
      }
      requestAnimationFrame(() => {
        requestAnimationFrame(() => setIsEntering(true));
      });
      loadGroupRequests();
    } else {
      setIsEntering(false);
      closeTimerRef.current = setTimeout(() => {}, 320);
    }
    return () => {
      if (closeTimerRef.current) clearTimeout(closeTimerRef.current);
    };
  }, [visible, loadGroupRequests]);

  const pendingRequests = groupRequests.filter(
    (r) => r.status === "pending" || r.status === "unhandled"
  );

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
        <h1 className="text-base font-medium text-gray-900">新营地邀请</h1>
        <div className="w-8" />
      </div>

      {/* Scrollable card list */}
      <div className="flex-1 relative overflow-hidden bg-white">
        <div className="absolute inset-0 overflow-y-auto overflow-x-hidden scrollbar-hide">
          {pendingRequests.length === 0 ? (
            <EmptyState />
          ) : (
            <div className="pb-6 space-y-[1px]">
              {pendingRequests.map((invitation) => (
                <InvitationCard key={invitation.id} invitation={invitation} />
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
