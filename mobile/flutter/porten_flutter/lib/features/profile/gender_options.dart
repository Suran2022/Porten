/*
 * 性别选项（100% 移植 Web 端 frontend/src/types/profile.ts 的
 * GenderValue / GENDER_OPTIONS / getGenderLabel）。
 */

/// 性别选项（value 与 Web 端字符串严格一致，便于后续接后端）。
class GenderOption {
  const GenderOption(this.value, this.label);

  final String value;
  final String label;
}

/// 14 个性別选项（顺序对齐 Web GENDER_OPTIONS）。
const List<GenderOption> kGenderOptions = <GenderOption>[
  GenderOption('trans_female', '跨性别女生'),
  GenderOption('trans_male', '跨性别男生'),
  GenderOption('cis_female', '女生'),
  GenderOption('cis_male', '男生'),
  GenderOption('non_binary', '非二元性别'),
  GenderOption('genderqueer', '性别酷儿'),
  GenderOption('genderfluid', '性别流动'),
  GenderOption('agender', '无性别'),
  GenderOption('bigender', '双性别'),
  GenderOption('pangender', '泛性别'),
  GenderOption('questioning', '探索中'),
  GenderOption('intersex', '间性人'),
  GenderOption('prefer_not_to_say', '不愿透露'),
  GenderOption('other', '其他'),
];

/// 取性别展示文案（对齐 Web getGenderLabel：空值「未设置」，
/// 未知值回退原值）。
String genderLabelOf(String? value) {
  if (value == null || value.isEmpty) return '未设置';
  for (final GenderOption option in kGenderOptions) {
    if (option.value == value) return option.label;
  }
  return value;
}
