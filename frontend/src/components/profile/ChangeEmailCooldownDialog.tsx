import { CenterDialog } from "@/components/common/CenterDialog";
import { CalendarClock } from "lucide-react";

interface ChangeEmailCooldownDialogProps {
  visible: boolean;
  remainingDays: number;
  onClose: () => void;
  onContinue: () => void;
}

// 用于"换绑频率限制"提示：365 天内只能换绑一次
// 换绑周期仅从本次实际换绑操作时间起算，不包含用户首次注册账号的时间
export function ChangeEmailCooldownDialog({
  visible,
  remainingDays,
  onClose,
  onContinue,
}: ChangeEmailCooldownDialogProps) {
  return (
    <CenterDialog visible={visible} onClose={onClose}>
      <div className="px-6 pt-6 pb-2">
        <div className="flex justify-center">
          <div className="w-12 h-12 rounded-full bg-amber-50 flex items-center justify-center">
            <CalendarClock
              className="w-6 h-6 text-amber-500"
              strokeWidth={1.5}
            />
          </div>
        </div>
        <h3 className="mt-3 text-base font-semibold text-gray-900 text-center">
          365 天之内只能换绑一次邮箱
        </h3>
        <p className="mt-3 text-sm text-gray-500 text-center leading-6">
          为保障账号安全，每次换绑后
          <span className="text-gray-900 font-medium"> 365 天 </span>
          内仅可再次换绑一次。
          {"\n"}换绑周期仅从本次实际换绑操作时间起算，不包含账号首次注册时间。
          {"\n"}是否仍要继续换绑？
        </p>
      </div>
      <div className="flex border-t border-gray-100 mt-4">
        <button
          type="button"
          onClick={onClose}
          className="flex-1 h-12 text-sm text-gray-600 active:bg-gray-50 transition-colors"
        >
          取消
        </button>
        <div className="w-px bg-gray-100 my-2" />
        <button
          type="button"
          onClick={onContinue}
          className="flex-1 h-12 text-sm font-medium text-blue-500 active:bg-gray-50 transition-colors"
        >
          继续换绑
        </button>
      </div>
    </CenterDialog>
  );
}
