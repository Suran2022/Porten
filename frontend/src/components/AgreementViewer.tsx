import { useEffect, useMemo, useRef, useState } from "react";
import { createPortal } from "react-dom";
import { ArrowLeft } from "lucide-react";
import { cn } from "@/lib/utils";
import { AgreementDocument, getAgreementById } from "@/data/agreements";
import { sendAgreementEmail } from "@/lib/api";

interface AgreementViewerProps {
  agreementId: string | null;
  onClose: () => void;
  onOpenAgreement?: (id: string) => void;
}

const titleToIdMap: Record<string, string> = {
  用户协议: "user",
  "《用户协议》": "user",
  跨性别资源: "trans",
  "《跨性别资源》": "trans",
  "跨性别用户权益保护与社区资源公约": "trans",
  "《跨性别用户权益保护与社区资源公约》": "trans",
  信息收集: "privacy",
  "《信息收集》": "privacy",
  "信息收集与隐私保护政策": "privacy",
  "《信息收集与隐私保护政策》": "privacy",
};

function useAnimatedVisibility(agreementId: string | null) {
  const [renderId, setRenderId] = useState<string | null>(null);
  const [isEntering, setIsEntering] = useState(false);
  const [isExiting, setIsExiting] = useState(false);

  useEffect(() => {
    if (agreementId) {
      setRenderId(agreementId);
      setIsExiting(false);
      setIsEntering(false);
      requestAnimationFrame(() => {
        requestAnimationFrame(() => setIsEntering(true));
      });
    } else if (renderId) {
      setIsEntering(false);
      setIsExiting(true);
      const timer = setTimeout(() => {
        setRenderId(null);
        setIsExiting(false);
      }, 320);
      return () => clearTimeout(timer);
    }
  }, [agreementId, renderId]);

  return { renderId, isEntering, isExiting };
}

function parseParagraphWithLinks(
  text: string,
  onOpen: (id: string) => void
): (string | JSX.Element)[] {
  const parts: (string | JSX.Element)[] = [];
  const regex = /(《[^《》]+》)/g;
  let lastIndex = 0;
  let match: RegExpExecArray | null;

  while ((match = regex.exec(text)) !== null) {
    if (match.index > lastIndex) {
      parts.push(text.slice(lastIndex, match.index));
    }
    const matched = match[0];
    const id = titleToIdMap[matched.slice(1, -1)] || titleToIdMap[matched];
    if (id) {
      parts.push(
        <button
          key={`${match.index}-${matched}`}
          type="button"
          onClick={() => onOpen(id)}
          className="p-0 m-0 bg-transparent border-0 align-baseline text-[#F5A9B8] underline underline-offset-2"
        >
          {matched}
        </button>
      );
    } else {
      parts.push(matched);
    }
    lastIndex = match.index + matched.length;
  }

  if (lastIndex < text.length) {
    parts.push(text.slice(lastIndex));
  }
  return parts;
}

function buildHtmlBody(agreement: AgreementDocument): string {
  const sectionsHtml = agreement.sections
    .map((section) => {
      const paragraphs = section.paragraphs
        .map((p) => `<p style="margin:0 0 12px 0;line-height:1.8;text-align:justify;">${p}</p>`)
        .join("");
      return section.title
        ? `<h2 style="font-size:16px;font-weight:600;margin:24px 0 12px;color:#111827;">${section.title}</h2>${paragraphs}`
        : paragraphs;
    })
    .join("");

  return `<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>${agreement.title}</title>
</head>
<body style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Helvetica,Arial,sans-serif;margin:0;padding:24px;color:#374151;background:#fff;">
  <div style="max-width:640px;margin:0 auto;">
    <h1 style="font-size:22px;font-weight:700;text-align:center;margin-bottom:8px;background:linear-gradient(90deg,#5BCEFA,#F5A9B8,#5BCEFA);background-size:200% 100%;-webkit-background-clip:text;background-clip:text;color:transparent;">${agreement.title}</h1>
    <div style="display:flex;justify-content:space-between;font-size:12px;color:#6B7280;margin-bottom:24px;">
      <span>修订时间：${agreement.revisionTime}</span>
      <span>生效时间：${agreement.effectiveTime}</span>
    </div>
    ${sectionsHtml}
    <div style="margin-top:32px;padding-top:16px;border-top:1px solid #E5E7EB;font-size:13px;color:#6B7280;">
      <p style="margin:0 0 6px 0;"><strong>Porten 通信平台</strong></p>
      <p style="margin:0 0 6px 0;">访问地址：your-domain.com</p>
      <p style="margin:0 0 6px 0;">团队联系邮箱：your_contact@email.com</p>
      <p style="margin:0;">联系 QQ：your_qq_number</p>
    </div>
  </div>
</body>
</html>`;
}

export function AgreementViewer({
  agreementId,
  onClose,
  onOpenAgreement,
}: AgreementViewerProps) {
  const { renderId, isEntering, isExiting } = useAnimatedVisibility(agreementId);
  const contentRef = useRef<HTMLDivElement>(null);
  const contentInnerRef = useRef<HTMLDivElement>(null);
  const [isPdfLoading, setIsPdfLoading] = useState(false);
  const [isEmailSending, setIsEmailSending] = useState(false);

  const agreement = useMemo(
    () => (renderId ? getAgreementById(renderId) : undefined),
    [renderId]
  );

  useEffect(() => {
    if (renderId && contentRef.current) {
      contentRef.current.scrollTop = 0;
    }
  }, [renderId]);

  const handleOpenAgreement = (id: string) => {
    if (onOpenAgreement) {
      onOpenAgreement(id);
    }
  };

  const handleDownloadPDF = async () => {
    if (!agreement || !contentInnerRef.current) return;
    setIsPdfLoading(true);
    try {
      // 懒加载 html2pdf.js（含 jspdf + html2canvas + canvg，约 1.5MB）
      const { default: html2pdf } = await import("html2pdf.js");
      await html2pdf()
        .set({
          margin: 10,
          filename: `${agreement.title}.pdf`,
          image: { type: "jpeg", quality: 0.98 },
          html2canvas: {
            scale: 2,
            useCORS: true,
            backgroundColor: "#ffffff",
            logging: false,
          },
          jsPDF: {
            unit: "mm",
            format: "a4",
            orientation: "portrait",
          },
          pagebreak: { mode: "avoid-all" },
        } as any)
        .from(contentInnerRef.current)
        .save();
    } catch (err) {
      console.error("PDF download failed", err);
      alert("下载 PDF 失败，请稍后重试");
    } finally {
      setIsPdfLoading(false);
    }
  };

  const handleFeedback = () => {
    const subject = encodeURIComponent(`关于 ${agreement?.title || "Porten"} 的反馈`);
    const body = encodeURIComponent(
      "您好，我对 Porten 平台有以下反馈或建议：\n\n"
    );
    window.location.href = `mailto:your_contact@email.com?subject=${subject}&body=${body}`;
  };

  const handleSendToEmail = async () => {
    if (!agreement) return;
    const recipient = window.prompt("请输入接收协议的邮箱地址：");
    if (!recipient || !recipient.trim()) return;
    setIsEmailSending(true);
    try {
      const htmlBody = buildHtmlBody(agreement);
      await sendAgreementEmail(recipient.trim(), agreement.title, htmlBody);
      alert("协议已发送至您的邮箱，请查收");
    } catch (err) {
      console.error("Send agreement email failed", err);
      alert(err instanceof Error ? err.message : "发送失败，请稍后重试");
    } finally {
      setIsEmailSending(false);
    }
  };

  if (!agreement) return null;

  return createPortal(
    <div
      className={cn(
        "fixed inset-0 z-[80] bg-white flex flex-col transition-transform duration-300 ease-[cubic-bezier(0.25,0.1,0.25,1)]",
        isExiting ? "translate-x-full" : "translate-x-0"
      )}
      style={{
        transform: isExiting
          ? "translateX(100%)"
          : isEntering
          ? "translateX(0%)"
          : "translateX(100%)",
      }}
    >
      {/* Fixed top bar */}
      <div className="flex-shrink-0 flex items-center justify-between px-4 pt-[max(0.75rem,env(safe-area-inset-top))] pb-3 bg-white z-10 border-b border-gray-100 overflow-hidden">
        <button
          type="button"
          onClick={onClose}
          className="w-8 h-8 flex items-center justify-center -ml-2 flex-shrink-0"
        >
          <ArrowLeft className="w-5 h-5 text-gray-900" strokeWidth={1.5} />
        </button>
        <h1 className="text-base font-medium text-gray-900 truncate px-2 flex-1 min-w-0 text-center">
          {agreement.title}
        </h1>
        <button
          type="button"
          onClick={handleDownloadPDF}
          disabled={isPdfLoading}
          className="text-sm text-gray-600 disabled:opacity-50 -mr-2 px-2 flex-shrink-0"
        >
          {isPdfLoading ? (
            <span className="w-4 h-4 border-2 border-gray-300 border-t-gray-600 rounded-full animate-spin inline-block" />
          ) : (
            "下载"
          )}
        </button>
      </div>

      {/* Scrollable content */}
      <div
        ref={contentRef}
        className="flex-1 overflow-y-auto overflow-x-hidden bg-white"
      >
        <div ref={contentInnerRef} className="max-w-md mx-auto px-5 py-6 pb-12 min-w-0">
          {/* Logo */}
          <div className="flex justify-center mb-6">
            <h2 className="text-4xl font-bold tracking-tight porten-gradient select-none">
              Porten
            </h2>
          </div>

          {/* Times */}
          <div className="flex items-center justify-between text-xs text-gray-500 mb-8">
            <span>修订时间：{agreement.revisionTime}</span>
            <span>生效时间：{agreement.effectiveTime}</span>
          </div>

          {/* Agreement content */}
          <div className="space-y-5">
            {agreement.sections.map((section, sIndex) => (
              <div key={sIndex}>
                {section.title && (
                  <h3 className="text-base font-semibold text-gray-900 mb-3">
                    {section.title}
                  </h3>
                )}
                <div className="space-y-3">
                  {section.paragraphs.map((paragraph, pIndex) => (
                    <p
                      key={pIndex}
                      className="text-sm text-gray-700 leading-relaxed break-words"
                    >
                      {parseParagraphWithLinks(paragraph, handleOpenAgreement)}
                    </p>
                  ))}
                </div>
              </div>
            ))}
          </div>

          {/* Footer contact */}
          <div className="mt-10 pt-6 border-t border-gray-100 text-sm text-gray-600 space-y-2 break-words">
            <p className="font-medium text-gray-900">Porten 通信平台</p>
            <p>访问地址：your-domain.com</p>
            <p>
              团队联系邮箱：
              <button
                type="button"
                onClick={handleFeedback}
                className="p-0 m-0 bg-transparent border-0 align-baseline text-[#F5A9B8] underline underline-offset-2"
              >
                your_contact@email.com
              </button>
            </p>
            <p>联系 QQ：your_qq_number</p>
            <div className="pt-3 flex flex-wrap gap-3">
              <button
                type="button"
                onClick={handleFeedback}
                className="p-0 m-0 bg-transparent border-0 align-baseline text-sm text-[#F5A9B8] underline underline-offset-2"
              >
                反馈
              </button>
              <button
                type="button"
                onClick={handleSendToEmail}
                disabled={isEmailSending}
                className="p-0 m-0 bg-transparent border-0 align-baseline text-sm text-[#F5A9B8] underline underline-offset-2 disabled:opacity-60"
              >
                {isEmailSending ? "发送中…" : "发送至邮箱"}
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>,
    document.body
  );
}
