// 邮箱工具：脱敏 + 校验

// 邮箱格式校验：通用 RFC 简化版
const EMAIL_RE = /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/;

export function isValidEmail(email: string): boolean {
  if (!email) return false;
  if (email.length > 254) return false;
  return EMAIL_RE.test(email.trim());
}

// 校验新邮箱（单次输入，不含二次确认）
export function validateNewEmail(
  email: string,
  currentEmail?: string
): string | null {
  const value = email.trim();
  if (!value) return "请输入新邮箱";
  if (!isValidEmail(value)) return "邮箱格式不正确";
  if (currentEmail && value.toLowerCase() === currentEmail.toLowerCase()) {
    return "新邮箱不能与当前邮箱相同";
  }
  if (value.length > 254) return "邮箱长度过长";
  return null;
}

// 校验验证码
export function validateVerificationCode(code: string): string | null {
  const value = code.trim();
  if (!value) return "请输入验证码";
  if (!/^\d{4,8}$/.test(value)) return "验证码格式不正确";
  return null;
}

// 脱敏结构：
//   display : 展示到 UI 上的脱敏文本（含 * 和 @）
//   inputLen: 用户需要输入的字符数
//   inputType: 'alnum' 表示字母或数字；'any' 表示任意字符（含 @ . 等）
//   restore : 把用户输入的字符串还原成完整原邮箱
//   hint    : 描述该邮箱的脱敏规则说明
export interface MaskedEmail {
  display: string;
  inputLen: number;
  inputType: "alnum" | "any";
  restore: (input: string) => string;
  hint: string;
}

export function maskEmailForVerify(email: string): MaskedEmail | null {
  if (!email) return null;
  const value = email.trim();
  const atIndex = value.indexOf("@");
  if (atIndex <= 0) return null;
  const local = value.slice(0, atIndex);
  const domain = value.slice(atIndex); // 含 @

  if (local.length <= 0) return null;

  // 规则 1：local 1-2 字符 → 完整保留 local，脱敏整个 domain
  if (local.length <= 2) {
    return {
      display: `${local}@***`,
      inputLen: domain.length,
      inputType: "any",
      restore: (input) => `${local}${input.startsWith("@") ? input : `@${input}`}`,
      hint: "请输入 @ 后面的部分",
    };
  }

  // 规则 2 & 3：local ≥ 3 → 保留首尾各 1，中间用 *
  const head = local[0];
  const tail = local[local.length - 1];
  const middleLen = local.length - 2;
  const maskedMiddle = "*".repeat(middleLen);
  return {
    display: `${head}${maskedMiddle}${tail}${domain}`,
    inputLen: middleLen,
    inputType: "alnum",
    restore: (input) => `${head}${input}${tail}${domain}`,
    hint: "请输入 * 标记的脱敏部分",
  };
}

// 把用户输入与脱敏结构拼回完整邮箱，并与注册邮箱比对
export function verifyEmailByMask(
  masked: MaskedEmail,
  userInput: string,
  registeredEmail: string
): { ok: true; fullEmail: string } | { ok: false; message: string } {
  if (!registeredEmail) {
    return { ok: false, message: "当前账号未绑定邮箱" };
  }
  const input = userInput ?? "";
  if (input.length !== masked.inputLen) {
    return { ok: false, message: "原邮箱不正确" };
  }
  if (masked.inputType === "alnum" && !/^[A-Za-z0-9._%+-]+$/.test(input)) {
    return { ok: false, message: "原邮箱不正确" };
  }
  const fullEmail = masked.restore(input).trim();
  if (fullEmail.toLowerCase() !== registeredEmail.trim().toLowerCase()) {
    return { ok: false, message: "原邮箱不正确" };
  }
  return { ok: true, fullEmail };
}

// 兼容旧调用：原 maskEmail 仍然保留，给"绑定的邮箱"弹窗脱敏用
export function maskEmail(email: string): string {
  if (!email) return "";
  const trimmed = email.trim();
  const atIndex = trimmed.indexOf("@");
  if (atIndex <= 0) return trimmed;
  const local = trimmed.slice(0, atIndex);
  const domain = trimmed.slice(atIndex);
  if (local.length <= 2) {
    return `${local[0] ?? ""}***${domain}`;
  }
  const head = local.slice(0, 2);
  return `${head}***${domain}`;
}
