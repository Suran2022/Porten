import { cn } from "@/lib/utils";

interface AgreementCheckboxProps {
  checked: boolean;
  onChange: (checked: boolean) => void;
  onOpenAgreement: (id: string) => void;
}

export function AgreementCheckbox({
  checked,
  onChange,
  onOpenAgreement,
}: AgreementCheckboxProps) {
  return (
    <div className="flex items-start gap-1.5 mt-4">
      <button
        type="button"
        onClick={() => onChange(!checked)}
        className={cn(
          "relative flex-shrink-0 w-3 h-3 rounded-full border-[1.5px] transition-all duration-200 mt-[3px]",
          checked
            ? "border-transparent agreement-gradient"
            : "border-gray-300 bg-white"
        )}
        aria-checked={checked}
        role="checkbox"
      >
        {checked && (
          <svg
            className="absolute inset-0 w-full h-full p-[1px] text-white"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2.5"
            strokeLinecap="round"
            strokeLinejoin="round"
          >
            <polyline points="20 6 9 17 4 12" />
          </svg>
        )}
      </button>
      <p className="text-xs text-gray-500 leading-relaxed">
        我已阅读并遵守
        <span
          className="text-[#F5A9B8] underline underline-offset-2 cursor-pointer"
          onClick={() => onOpenAgreement("user")}
        >
          《用户协议》
        </span>
        ，
        <span
          className="text-[#F5A9B8] underline underline-offset-2 cursor-pointer"
          onClick={() => onOpenAgreement("trans")}
        >
          《跨性别资源》
        </span>
        ，
        <span
          className="text-[#F5A9B8] underline underline-offset-2 cursor-pointer"
          onClick={() => onOpenAgreement("privacy")}
        >
          《信息收集》
        </span>
        继续使用
      </p>
    </div>
  );
}
