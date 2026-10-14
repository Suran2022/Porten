/*
 * 邮箱工具（100% 移植 Web 端 frontend/src/lib/email.ts）：
 * 格式校验 + 验证码校验 + 脱敏结构（maskEmailForVerify / verifyEmailByMask）。
 *
 * 供 Porten 安全中心「绑定的邮箱」弹窗与「换绑邮箱」三步流程复用。
 */

/// 邮箱格式校验：通用 RFC 简化版。
final RegExp _kEmailRe =
    RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');

bool isValidEmail(String email) {
  if (email.isEmpty) return false;
  if (email.length > 254) return false;
  return _kEmailRe.hasMatch(email.trim());
}

/// 校验新邮箱（单次输入，不含二次确认）。返回 null 表示通过，否则为错误文案。
String? validateNewEmail(String email, [String? currentEmail]) {
  final String value = email.trim();
  if (value.isEmpty) return '请输入新邮箱';
  if (!isValidEmail(value)) return '邮箱格式不正确';
  if (currentEmail != null &&
      value.toLowerCase() == currentEmail.toLowerCase()) {
    return '新邮箱不能与当前邮箱相同';
  }
  if (value.length > 254) return '邮箱长度过长';
  return null;
}

/// 校验验证码。返回 null 表示通过，否则为错误文案。
String? validateVerificationCode(String code) {
  final String value = code.trim();
  if (value.isEmpty) return '请输入验证码';
  if (!RegExp(r'^\d{4,8}$').hasMatch(value)) return '验证码格式不正确';
  return null;
}

/// 脱敏输入类型：alnum = 字母数字/点等；any = 任意字符（含 @ . 等）。
enum MaskedInputType { alnum, any }

/// 脱敏结构（对齐 Web MaskedEmail）：
///   display : 展示到 UI 上的脱敏文本（含 * 和 @）
///   inputLen: 用户需要输入的字符数
///   inputType: 输入字符约束
///   restore : 把用户输入的字符串还原成完整原邮箱
///   hint    : 描述该邮箱的脱敏规则说明
class MaskedEmail {
  const MaskedEmail({
    required this.display,
    required this.inputLen,
    required this.inputType,
    required this.restore,
    required this.hint,
  });

  final String display;
  final int inputLen;
  final MaskedInputType inputType;
  final String Function(String input) restore;
  final String hint;
}

/// 生成脱敏结构（对齐 maskEmailForVerify）：
///   规则 1：local 1-2 字符 → 完整保留 local，脱敏整个 domain；
///   规则 2/3：local ≥ 3 → 保留首尾各 1，中间用 *。
MaskedEmail? maskEmailForVerify(String email) {
  if (email.isEmpty) return null;
  final String value = email.trim();
  final int atIndex = value.indexOf('@');
  if (atIndex <= 0) return null;
  final String local = value.substring(0, atIndex);
  final String domain = value.substring(atIndex); // 含 @

  if (local.isEmpty) return null;

  // 规则 1：local 1-2 字符
  if (local.length <= 2) {
    return MaskedEmail(
      display: '$local@***',
      inputLen: domain.length,
      inputType: MaskedInputType.any,
      restore: (String input) =>
          '$local${input.startsWith('@') ? input : '@$input'}',
      hint: '请输入 @ 后面的部分',
    );
  }

  // 规则 2 & 3：local ≥ 3
  final String head = local[0];
  final String tail = local[local.length - 1];
  final int middleLen = local.length - 2;
  return MaskedEmail(
    display: '$head${'*' * middleLen}$tail$domain',
    inputLen: middleLen,
    inputType: MaskedInputType.alnum,
    restore: (String input) => '$head$input$tail$domain',
    hint: '请输入 * 标记的脱敏部分',
  );
}

/// 脱敏校验结果。
class EmailVerifyResult {
  const EmailVerifyResult.ok(this.fullEmail) : message = null;
  const EmailVerifyResult.fail(this.message) : fullEmail = null;

  final String? fullEmail;
  final String? message;

  bool get isOk => fullEmail != null;
}

/// 把用户输入与脱敏结构拼回完整邮箱，并与注册邮箱比对。
EmailVerifyResult verifyEmailByMask(
  MaskedEmail masked,
  String userInput,
  String registeredEmail,
) {
  if (registeredEmail.isEmpty) {
    return const EmailVerifyResult.fail('当前账号未绑定邮箱');
  }
  final String input = userInput;
  if (input.length != masked.inputLen) {
    return const EmailVerifyResult.fail('原邮箱不正确');
  }
  if (masked.inputType == MaskedInputType.alnum &&
      !RegExp(r'^[A-Za-z0-9._%+-]+$').hasMatch(input)) {
    return const EmailVerifyResult.fail('原邮箱不正确');
  }
  final String fullEmail = masked.restore(input).trim();
  if (fullEmail.toLowerCase() != registeredEmail.trim().toLowerCase()) {
    return const EmailVerifyResult.fail('原邮箱不正确');
  }
  return EmailVerifyResult.ok(fullEmail);
}

/// 兼容旧调用：给「绑定的邮箱」弹窗脱敏用（对齐 maskEmail）。
String maskEmail(String email) {
  if (email.isEmpty) return '';
  final String trimmed = email.trim();
  final int atIndex = trimmed.indexOf('@');
  if (atIndex <= 0) return trimmed;
  final String local = trimmed.substring(0, atIndex);
  final String domain = trimmed.substring(atIndex);
  if (local.length <= 2) {
    return '${local.isNotEmpty ? local[0] : ''}***$domain';
  }
  final String head = local.substring(0, 2);
  return '$head***$domain';
}
