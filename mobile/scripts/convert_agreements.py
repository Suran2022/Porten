#!/usr/bin/env python3
"""把 frontend/src/data/agreements.ts 精确转换为 Dart 常量文件。

策略：逐行做 TS 对象字面量 → Dart map 字面量的机械转换，
不重排、不改写任何文案内容（100% 保真）。
"""
import re, sys

SRC = "/workspace/Porten/frontend/src/data/agreements.ts"
DST = ("/workspace/Porten/mobile/flutter/porten_flutter/lib/"
       "core/data/agreements.dart")

lines = open(SRC, encoding="utf-8").read().splitlines()

out = []
out.append("/*")
out.append(" * 协议文档 mock 数据（100% 移植自 Web 端 frontend/src/data/agreements.ts）。\n"
           " *\n"
           " * 由 scripts/convert_agreements.py 机械转换生成，禁止手改文案；\n"
           " * 如 Web 端协议更新，重跑脚本同步。\n"
           " */\n")
out.append("/// 协议章节。")
out.append("class AgreementSection {")
out.append("  const AgreementSection(this.title, this.paragraphs);")
out.append("  final String? title;")
out.append("  final List<String> paragraphs;")
out.append("}\n")
out.append("/// 协议文档。")
out.append("class AgreementDocument {")
out.append("  const AgreementDocument({")
out.append("    required this.id,")
out.append("    required this.title,")
out.append("    required this.shortTitle,")
out.append("    required this.revisionTime,")
out.append("    required this.effectiveTime,")
out.append("    required this.sections,")
out.append("  });")
out.append("  final String id;")
out.append("  final String title;")
out.append("  final String shortTitle;")
out.append("  final String revisionTime;")
out.append("  final String effectiveTime;")
out.append("  final List<AgreementSection> sections;\n")
out.append("  /// 全部段落（标题段落拼平，供检索/分享用）。")
out.append("  List<String> get allParagraphs =>")
out.append("      sections.expand((AgreementSection s) => s.paragraphs).toList();")
out.append("}\n")

# 逐块解析
docs = {}
cur_name = None
cur = None          # dict: id/title/.../sections(list of (title, [paras]))
in_sections = False
sec = None
in_paras = False

skip_header = True
for raw in lines:
    line = raw.rstrip()
    if skip_header:
        if line.startswith("export const"):
            skip_header = False
        else:
            continue
    m = re.match(r"export const (\w+): AgreementDocument = \{", line)
    if m:
        cur_name = m.group(1)
        cur = {"sections": []}
        continue
    if line.startswith("export const agreementsMap"):
        break
    if cur is None:
        continue
    s = line.strip()
    if s.startswith("id:") or s.startswith("title:") or s.startswith(
            "shortTitle:") or s.startswith("revisionTime:") or s.startswith(
                "effectiveTime:"):
        key, val = s.split(":", 1)
        cur[key.strip()] = val.strip().rstrip(",")
    elif s == "sections: [":
        in_sections = True
    elif s.startswith("title:") and in_sections and sec is not None and not sec.get("_closed"):
        sec["title"] = s.split(":", 1)[1].strip().rstrip(",")
    elif s == "paragraphs: [":
        sec = sec or {"title": None, "paras": []}
        in_paras = True
    elif s == "],":
        if in_paras:
            in_paras = False
            cur["sections"].append(sec)
            sec = {"title": None, "paras": [], "_closed": True}
        # sections 结束的 ], 也可能；用下一行判断
    elif s == "],":
        pass
    elif s.startswith('"'):
        text = s
        if text.endswith(","):
            text = text[:-1]
        sec.setdefault("paras", []).append(text)
    elif s == "},":
        # section 或 document 结束
        if in_paras:
            in_paras = False
            cur["sections"].append(sec)
            sec = None
        elif sec is not None and sec.get("paras"):
            cur["sections"].append(sec)
            sec = None
        elif in_sections:
            in_sections = False
            docs[cur_name] = cur
            cur = None
    elif s == "};":
        if cur is not None:
            docs[cur_name] = cur
            cur = None

# 上面状态机对嵌套 {} 的处理不够稳，改用更简单可靠的二次解析：
# 直接用 regex 抓每个文档块，再在块内抓 title/rev/effective 与 (title?, paragraphs) 组。
docs = {}
blocks = re.split(r"export const (\w+): AgreementDocument = ", open(SRC, encoding="utf-8").read())
for i in range(1, len(blocks) - 0, 2):
    name, body = blocks[i], blocks[i + 1]
    # 截断到下一个 export 或结尾
    body = body.split("export const")[0].split("export function")[0]
    head = dict(re.findall(
        r'^\s{2}(id|title|shortTitle|revisionTime|effectiveTime): "(.*)",$',
        body, re.M))
    sections = []
    for sm in re.finditer(r"title: (\"(?:[^\"\\]|\\.)*\")?,?\n(?:\s*)?paragraphs: \[\n(.*?)\n\s{6}\],", body, re.S):
        t = sm.group(1)
        title = None if t is None else t.rstrip(",").strip('"')
        paras = re.findall(r'^\s{8}"((?:[^"\\]|\\.)*)",$', sm.group(2), re.M)
        sections.append((title, paras))
    docs[name] = (head, sections)

# 生成 Dart
for name, (head, sections) in docs.items():
    var = name[0].lower() + name[1:]
    out.append(f"/// {head.get('title', name)}")
    out.append(f"const AgreementDocument {var}Doc = AgreementDocument(")
    out.append(f"  id: '{head.get('id', '')}',")
    out.append(f"  title: '{head.get('title', '')}',")
    out.append(f"  shortTitle: '{head.get('shortTitle', '')}',")
    out.append(f"  revisionTime: '{head.get('revisionTime', '')}',")
    out.append(f"  effectiveTime: '{head.get('effectiveTime', '')}',")
    out.append("  sections: <AgreementSection>[")
    for title, paras in sections:
        if title is None:
            out.append("    AgreementSection(null, <String>[")
        else:
            out.append(f"    AgreementSection('{title}', <String>[")
        for p in paras:
            esc = p.replace("\\", "\\\\").replace("'", r"\'").replace("$", r"\$")
            out.append(f"      '{esc}',")
        out.append("    ]),")
    out.append("  ],")
    out.append(");\n")

out.append("/// 协议 ID → 文档映射（对齐 Web 端 agreementsMap）。")
out.append("const Map<String, AgreementDocument> agreementsMap = <String, AgreementDocument>{")
out.append("  'user': userAgreementDoc,")
out.append("  'trans': transProtectionAgreementDoc,")
out.append("  'privacy': privacyAgreementDoc,")
out.append("};\n")
out.append("/// 按 ID 取协议（对齐 Web 端 getAgreementById）。")
out.append("AgreementDocument? getAgreementById(String id) => agreementsMap[id];")

open(DST, "w", encoding="utf-8").write("\n".join(out) + "\n")
print("docs:", {k: (len(v[1]), sum(len(p) for _, p in v[1])) for k, v in docs.items()})
print("written:", DST)
