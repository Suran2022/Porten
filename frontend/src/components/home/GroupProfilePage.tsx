import { useEffect, useRef, useState } from "react";
import { Camera, ChevronRight, X } from "lucide-react";
import { cn } from "@/lib/utils";
import { uploadImage, createGroup, CreateGroupPayload } from "@/lib/api";

interface GroupProfilePageProps {
  visible: boolean;
  groupType: string;
  onClose: () => void;
  /** PC 弹窗形态：顶部右对齐显示关闭图标（保留"上一步"） */
  closeMode?: boolean;
  onBack?: () => void;
  onCreated?: (payload: { conversationId: number; name: string; avatar: string | undefined; memberCount?: number }) => void;
}

const FEATURES = [
  "包容",
  "多元",
  "热爱",
  "友好",
  "互助",
  "专业",
  "支持",
  "组织",
  "医院",
  "校园",
];

const DISCOVER_METHODS = ["搜索营地名称", "搜索营地号", "不允许搜索"];
const SCALES = [200, 500, 1000, 1200, 1500, 2000];

type PopupType = "features" | "discover" | "scale" | null;

function BottomPopup({
  open,
  title,
  onClose,
  children,
}: {
  open: boolean;
  title: string;
  onClose: () => void;
  children: React.ReactNode;
}) {
  const [visible, setVisible] = useState(false);
  const [entering, setEntering] = useState(false);
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    if (open) {
      if (timerRef.current) clearTimeout(timerRef.current);
      setVisible(true);
      requestAnimationFrame(() => {
        requestAnimationFrame(() => setEntering(true));
      });
    } else {
      setEntering(false);
      timerRef.current = setTimeout(() => setVisible(false), 300);
    }
    return () => {
      if (timerRef.current) clearTimeout(timerRef.current);
    };
  }, [open]);

  if (!visible) return null;

  return (
    <div className="fixed inset-0 z-[80]">
      {/* Backdrop */}
      <div
        className="absolute inset-0 bg-black/40 transition-opacity duration-300"
        style={{ opacity: entering ? 1 : 0 }}
        onClick={onClose}
      />

      {/* Panel */}
      <div
        className="absolute left-0 right-0 bottom-0 bg-white rounded-t-3xl px-4 pt-4 pb-[max(1rem,env(safe-area-inset-bottom))] transition-transform duration-300 ease-[cubic-bezier(0.25,0.1,0.25,1)]"
        style={{
          transform: entering ? "translateY(0)" : "translateY(100%)",
        }}
      >
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-base font-medium text-gray-900">{title}</h3>
          <button
            type="button"
            onClick={onClose}
            className="w-8 h-8 flex items-center justify-center -mr-2"
          >
            <X className="w-5 h-5 text-gray-500" strokeWidth={1.5} />
          </button>
        </div>
        {children}
      </div>
    </div>
  );
}

function RequiredLabel({ label }: { label: string }) {
  return (
    <label className="block text-sm text-gray-700 mb-1.5">
      {label}
      <span className="text-red-500 ml-0.5">*</span>
    </label>
  );
}

function OptionalLabel({ label }: { label: string }) {
  return (
    <label className="block text-sm text-gray-700 mb-1.5">{label}</label>
  );
}

export function GroupProfilePage({ visible, groupType, onClose, closeMode = false, onBack, onCreated }: GroupProfilePageProps) {
  const [isEntering, setIsEntering] = useState(false);
  const [name, setName] = useState("");
  const [intro, setIntro] = useState("");
  const [selectedFeatures, setSelectedFeatures] = useState<string[]>([]);
  const [discoverMethod, setDiscoverMethod] = useState("");
  const [scale, setScale] = useState(200);
  const [agreed, setAgreed] = useState(false);
  const [popup, setPopup] = useState<PopupType>(null);
  const [avatarPreview, setAvatarPreview] = useState<string | null>(null);
  const [avatarFile, setAvatarFile] = useState<File | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const closeTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const scrollRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (visible) {
      if (closeTimerRef.current) {
        clearTimeout(closeTimerRef.current);
        closeTimerRef.current = null;
      }
      requestAnimationFrame(() => {
        requestAnimationFrame(() => setIsEntering(true));
      });
    } else {
      setIsEntering(false);
      closeTimerRef.current = setTimeout(() => {
        setName("");
        setIntro("");
        setSelectedFeatures([]);
        setDiscoverMethod("");
        setScale(200);
        setAgreed(false);
        setAvatarPreview(null);
        setAvatarFile(null);
        setSubmitting(false);
      }, 320);
    }
    return () => {
      if (closeTimerRef.current) clearTimeout(closeTimerRef.current);
    };
  }, [visible]);

  const toggleFeature = (feature: string) => {
    setSelectedFeatures((prev) => {
      if (prev.includes(feature)) {
        return prev.filter((f) => f !== feature);
      }
      if (prev.length >= 5) return prev;
      return [...prev, feature];
    });
  };

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      const url = URL.createObjectURL(file);
      setAvatarPreview(url);
      setAvatarFile(file);
    }
  };

  const discoverMethodMap: Record<string, string> = {
    "搜索营地名称": "name",
    "搜索营地号": "id",
    "不允许搜索": "none",
  };

  const handleSubmit = async () => {
    if (!canSubmit || submitting) return;
    setSubmitting(true);
    try {
      let avatarUrl: string | undefined;
      if (avatarFile) {
        const result = await uploadImage(avatarFile, undefined, true);
        avatarUrl = result.url;
      }
      const payload: CreateGroupPayload = {
        name: name.trim(),
        group_type: groupType,
        description: intro.trim() || undefined,
        avatar_url: avatarUrl,
        tags: selectedFeatures,
        discoverable_by: discoverMethodMap[discoverMethod] || "name",
        max_members: scale,
      };
      const result = await createGroup(payload);
      onCreated?.({
        conversationId: result.conversation_id,
        name: result.name,
        avatar: result.avatar_url || undefined,
        memberCount: result.member_count,
      });
    } finally {
      setSubmitting(false);
    }
  };

  const canSubmit =
    name.trim().length > 0 && discoverMethod.length > 0 && scale > 0 && agreed;

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
          onClick={onBack}
          className="w-16 text-left text-sm text-gray-600 active:text-gray-900 transition-colors"
        >
          上一步
        </button>
        <h1 className="text-base font-medium text-gray-900">营地资料完善</h1>
        {closeMode ? (
          <button
            type="button"
            onClick={onClose}
            className="w-16 flex justify-end text-gray-600 active:text-gray-900 transition-colors"
            aria-label="关闭"
          >
            <X className="w-5 h-5 text-gray-900" strokeWidth={1.8} />
          </button>
        ) : (
          <div className="w-16" />
        )}
      </div>

      {/* Scrollable content */}
      <div
        ref={scrollRef}
        className="flex-1 overflow-y-auto overflow-x-hidden scrollbar-hide"
      >
        <div className="px-6 py-6 pb-40">
          {/* Avatar */}
          <div className="flex justify-center mb-8">
            <label className="relative cursor-pointer">
              <input
                ref={fileInputRef}
                type="file"
                accept="image/*"
                className="hidden"
                onChange={handleFileChange}
              />
              <div className="w-24 h-24 rounded-2xl bg-gray-100/80 flex items-center justify-center overflow-hidden">
                {avatarPreview ? (
                  <img
                    src={avatarPreview}
                    alt="avatar"
                    className="w-full h-full object-cover"
                  />
                ) : (
                  <Camera className="w-8 h-8 text-gray-400" strokeWidth={1.5} />
                )}
              </div>
            </label>
          </div>

          {/* Name */}
          <div className="mb-5">
            <RequiredLabel label="营地昵称" />
            <div className="relative">
              <input
                type="text"
                value={name}
                onChange={(e) => setName(e.target.value.slice(0, 30))}
                placeholder="请输入营地昵称"
                className="w-full h-11 px-3 rounded-[7px] bg-gray-100/60 text-sm text-gray-900 placeholder:text-gray-400 outline-none"
              />
              <span className="absolute right-3 top-1/2 -translate-y-1/2 text-xs text-gray-400">
                {name.length}/30
              </span>
            </div>
          </div>

          {/* Intro */}
          <div className="mb-5">
            <OptionalLabel label="营地介绍" />
            <div className="relative">
              <textarea
                value={intro}
                onChange={(e) => setIntro(e.target.value.slice(0, 120))}
                placeholder="请输入营地介绍"
                rows={4}
                className="w-full px-3 py-2.5 rounded-[7px] bg-gray-100/60 text-sm text-gray-900 placeholder:text-gray-400 outline-none resize-none"
              />
              <span className="absolute right-3 bottom-2.5 text-xs text-gray-400">
                {intro.length}/120
              </span>
            </div>
          </div>

          {/* Features */}
          <div className="mb-5">
            <OptionalLabel label="营地特色" />
            <button
              type="button"
              onClick={() => setPopup("features")}
              className="w-full flex items-center justify-between h-11 px-3 rounded-[7px] bg-gray-100/60 text-sm text-left"
            >
              <span
                className={cn(
                  "truncate",
                  selectedFeatures.length > 0 ? "text-gray-900" : "text-gray-400"
                )}
              >
                {selectedFeatures.length > 0
                  ? selectedFeatures.join("、")
                  : "请选择营地特色（最多5个）"}
              </span>
              <ChevronRight className="w-4 h-4 text-gray-400 flex-shrink-0" strokeWidth={1.5} />
            </button>
          </div>

          {/* Discover method */}
          <div className="mb-5">
            <RequiredLabel label="可发现营地的方式" />
            <button
              type="button"
              onClick={() => setPopup("discover")}
              className="w-full flex items-center justify-between h-11 px-3 rounded-[7px] bg-gray-100/60 text-sm text-left"
            >
              <span className={cn(discoverMethod ? "text-gray-900" : "text-gray-400")}>
                {discoverMethod || "请选择可发现营地的方式"}
              </span>
              <ChevronRight className="w-4 h-4 text-gray-400 flex-shrink-0" strokeWidth={1.5} />
            </button>
          </div>

          {/* Scale */}
          <div className="mb-5">
            <RequiredLabel label="营地规模" />
            <button
              type="button"
              onClick={() => setPopup("scale")}
              className="w-full flex items-center justify-between h-11 px-3 rounded-[7px] bg-gray-100/60 text-sm text-left"
            >
              <span className="text-gray-900">{scale}人</span>
              <ChevronRight className="w-4 h-4 text-gray-400 flex-shrink-0" strokeWidth={1.5} />
            </button>
          </div>
        </div>
      </div>

      {/* Bottom bar */}
      <div className="flex-shrink-0 px-6 py-4 pb-[max(1rem,env(safe-area-inset-bottom))] bg-white border-t border-gray-100">
        <label className="flex items-center gap-2 mb-4 cursor-pointer">
          <input
            type="checkbox"
            checked={agreed}
            onChange={(e) => setAgreed(e.target.checked)}
            className="w-4 h-4 rounded border-gray-300 text-[#F5A9B8] focus:ring-0 focus:ring-offset-0"
          />
          <span className="text-xs text-gray-600">
            我已知晓并遵守《Porten营地组织共建管理》
          </span>
        </label>
        <button
          type="button"
          disabled={!canSubmit || submitting}
          onClick={handleSubmit}
          className={cn(
            "w-full h-11 rounded-full text-sm font-medium transition-colors",
            canSubmit && !submitting
              ? "bg-[#F5A9B8] text-white active:opacity-90"
              : "bg-gray-200 text-gray-400 cursor-not-allowed"
          )}
        >
          {submitting ? "组建中…" : "组建"}
        </button>
      </div>

      {/* Features popup */}
      <BottomPopup
        open={popup === "features"}
        title="选择营地特色"
        onClose={() => setPopup(null)}
      >
        <div className="mb-2 text-xs text-gray-400">
          最多选择 5 个（已选 {selectedFeatures.length}/5）
        </div>
        <div className="flex flex-wrap gap-2 mb-6">
          {FEATURES.map((feature) => {
            const selected = selectedFeatures.includes(feature);
            return (
              <button
                key={feature}
                type="button"
                onClick={() => toggleFeature(feature)}
                className={cn(
                  "px-4 py-1.5 rounded-full text-sm border transition-colors",
                  selected
                    ? "bg-[#F5A9B8] border-[#F5A9B8] text-white"
                    : "bg-white border-gray-200 text-gray-700 active:bg-gray-50"
                )}
              >
                {feature}
              </button>
            );
          })}
        </div>
        <button
          type="button"
          onClick={() => setPopup(null)}
          className="w-full h-11 rounded-full bg-[#F5A9B8] text-white text-sm font-medium active:opacity-90 transition-opacity"
        >
          确定
        </button>
      </BottomPopup>

      {/* Discover method popup */}
      <BottomPopup
        open={popup === "discover"}
        title="可发现营地的方式"
        onClose={() => setPopup(null)}
      >
        <div className="space-y-1 mb-6">
          {DISCOVER_METHODS.map((method) => (
            <button
              key={method}
              type="button"
              onClick={() => {
                setDiscoverMethod(method);
                setPopup(null);
              }}
              className={cn(
                "w-full flex items-center justify-between h-12 px-3 rounded-lg text-sm transition-colors",
                discoverMethod === method
                  ? "bg-pink-50 text-[#F5A9B8]"
                  : "bg-white text-gray-700 active:bg-gray-50"
              )}
            >
              <span>{method}</span>
              {discoverMethod === method && (
                <span className="w-2 h-2 rounded-full bg-[#F5A9B8]" />
              )}
            </button>
          ))}
        </div>
      </BottomPopup>

      {/* Scale popup */}
      <BottomPopup
        open={popup === "scale"}
        title="选择营地规模"
        onClose={() => setPopup(null)}
      >
        <div className="grid grid-cols-3 gap-3 mb-6">
          {SCALES.map((s) => (
            <button
              key={s}
              type="button"
              onClick={() => {
                setScale(s);
                setPopup(null);
              }}
              className={cn(
                "h-11 rounded-lg text-sm font-medium transition-colors",
                scale === s
                  ? "bg-[#F5A9B8] text-white"
                  : "bg-gray-100/60 text-gray-700 active:bg-gray-100"
              )}
            >
              {s}
            </button>
          ))}
        </div>
      </BottomPopup>
    </div>
  );
}
