import { CenterDialog } from "@/components/common/CenterDialog";
import { maskEmail } from "@/lib/email";

interface BoundEmailDialogProps {
  visible: boolean;
  email: string;
  onClose: () => void;
  onChangeEmail: () => void;
}

export function BoundEmailDialog({
  visible,
  email,
  onClose,
  onChangeEmail,
}: BoundEmailDialogProps) {
  return (
    <CenterDialog visible={visible} onClose={onClose}>
      <div className="px-6 pt-6 pb-2">
        <h3 className="text-base font-semibold text-gray-900 text-center">
          绑定的邮箱
        </h3>
        <div className="mt-4 px-4 py-5 bg-gray-50 rounded-xl text-center">
          <p className="text-lg font-medium text-gray-900 tracking-wide">
            {maskEmail(email)}
          </p>
          <p className="mt-2 text-xs text-gray-400">
            为保障账号安全，已对邮箱进行脱敏展示
          </p>
        </div>
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
          onClick={onChangeEmail}
          className="flex-1 h-12 text-sm font-medium text-blue-500 active:bg-gray-50 transition-colors"
        >
          换绑邮箱
        </button>
      </div>
    </CenterDialog>
  );
}
