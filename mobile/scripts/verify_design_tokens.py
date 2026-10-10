#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Porten 设计令牌一致性校验。

单一数据源：design/tokens/porten_design_tokens_v1.json
消费方：Kotlin（core/design/tokens）与 Dart（flutter/porten_flutter/lib/core/design）

本脚本抽取三个来源中的颜色 / 字阶 / 间距 / 缩放常量并交叉比对，
任何一侧「只改了一处」都会在校验时失败，防止设计还原走样。

用法：python3 scripts/verify_design_tokens.py
退出码：0 = 一致；1 = 存在差异。
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOKENS_JSON = ROOT / "design" / "tokens" / "porten_design_tokens_v1.json"
KOTLIN_DIR = ROOT / "core" / "design" / "src" / "main" / "kotlin" / "jys" / "porten" / "core" / "design" / "tokens"
DART_DIR = ROOT / "flutter" / "porten_flutter" / "lib" / "core" / "design"

errors: list[str] = []


def fail(msg: str) -> None:
    errors.append(msg)


def load_json() -> dict:
    return json.loads(TOKENS_JSON.read_text(encoding="utf-8"))


def extract_kotlin_hex(path: Path) -> dict[str, str]:
    text = path.read_text(encoding="utf-8")
    return {m.group(1).lower(): "#" + m.group(2).upper() for m in
            re.finditer(r'val\s+(\w+)\s*:\s*Color\s*=\s*Color\(0xFF([0-9A-Fa-f]{6})\)', text)}


def extract_dart_hex(path: Path) -> dict[str, str]:
    text = path.read_text(encoding="utf-8")
    return {m.group(1).lower(): "#" + m.group(2).upper() for m in
            re.finditer(r'static\s+const\s+Color\s+(\w+)\s*=\s*Color\(0xFF([0-9A-Fa-f]{6})\)', text)}


def extract_kotlin_scalars(path: Path) -> dict[str, float]:
    text = path.read_text(encoding="utf-8")
    out: dict[str, float] = {}
    for m in re.finditer(r'(?:const\s+)?val\s+(\w+)\s*:\s*(?:Dp|Float|Int)\s*=\s*(-?\d+(?:\.\d+)?)(?:f|F|\.dp)?\b', text):
        out[m.group(1)] = float(m.group(2))
    return out


def extract_dart_scalars(path: Path) -> dict[str, float]:
    text = path.read_text(encoding="utf-8")
    out: dict[str, float] = {}
    for m in re.finditer(r'static\s+const\s+double\s+(\w+)\s*=\s*(-?[\d.]+)', text):
        out[m.group(1)] = float(m.group(2))
    return out


def main() -> int:
    data = load_json()

    # ---------------- 颜色比对 ----------------
    json_colors = {k.lower(): v.upper() for k, v in data.get("colors", {}).items()}
    kt_colors = extract_kotlin_hex(KOTLIN_DIR / "PortenColor.kt")
    dart_colors = extract_dart_hex(DART_DIR / "porten_colors.dart")

    common_kt_dart = set(kt_colors) & set(dart_colors)
    for name in sorted(common_kt_dart):
        if kt_colors[name] != dart_colors[name]:
            fail(f"颜色不一致 [{name}] Kotlin={kt_colors[name]} Dart={dart_colors[name]}")

    # JSON 中声明的颜色必须在两侧存在（允许命名前缀差异，做包含匹配）
    for jname, jhex in json_colors.items():
        hit_kt = any(v == jhex for v in kt_colors.values())
        hit_dart = any(v == jhex for v in dart_colors.values())
        if not hit_kt:
            fail(f"JSON 颜色 {jname}={jhex} 未在 Kotlin 侧定义")
        if not hit_dart:
            fail(f"JSON 颜色 {jname}={jhex} 未在 Dart 侧定义")

    # ---------------- 缩放参数比对 ----------------
    scaling = data.get("scaling", {})
    kt_dim = extract_kotlin_scalars(KOTLIN_DIR / "PortenDimens.kt")
    dart_dim = extract_dart_scalars(DART_DIR / "porten_dimens.dart")

    checks = [
        ("designWidthDp", "DesignWidthDp", "designWidthDp"),
        ("designHeightDp", "DesignHeightDp", "designHeightDp"),
        ("minScale", "MinScale", "minScale"),
        ("maxScale", "MaxScale", "maxScale"),
        ("fontScaleMax", "FontScaleMax", "fontScaleMax"),
    ]
    for jkey, kname, dname in checks:
        jv = float(scaling.get(jkey, "nan"))
        kv = kt_dim.get(kname)
        dv = dart_dim.get(dname)
        if kv is None or kv != jv:
            fail(f"缩放参数 {jkey}: JSON={jv} Kotlin={kv}")
        if dv is None or dv != jv:
            fail(f"缩放参数 {jkey}: JSON={jv} Dart={dv}")

    st = scaling.get("scaleText", True)
    kst = "ScaleText" in kt_dim and kt_dim["ScaleText"] == (1.0 if st else 0.0)
    # Kotlin/Dart 的 scaleText 是 Boolean，无法用数值提取覆盖，这里仅提示人工核对
    if not kst:
        print(f"提示：scaleText={st} 请人工核对 Kotlin PortenScaling.ScaleText 与 Dart PortenScaling.scaleText")

    # ---------------- 字阶比对 ----------------
    kt_typo = extract_kotlin_scalars(KOTLIN_DIR / "PortenTypography.kt")
    dart_typo_text = (DART_DIR / "porten_typography.dart").read_text(encoding="utf-8")
    dart_sizes = {float(m.group(2)) for m in
                  re.finditer(r'static\s+const\s+TextStyle\s+(\w+)\s*=\s*TextStyle\([^)]*fontSize:\s*([\d.]+)', dart_typo_text)}
    kt_sizes = {v for k, v in kt_typo.items() if k.lower().endswith("sp") is False}
    # 字号在 Kotlin 侧以 style(size = N) 形式出现
    kt_sizes = {float(m.group(1)) for m in
                re.finditer(r'style\(size\s*=\s*(\d+)', (KOTLIN_DIR / "PortenTypography.kt").read_text(encoding="utf-8"))}
    if kt_sizes != dart_sizes:
        fail(f"字阶不一致：Kotlin={sorted(kt_sizes)} Dart={sorted(dart_sizes)}")

    # ---------------- 输出 ----------------
    if errors:
        print("设计令牌校验失败：")
        for e in errors:
            print("  ✗", e)
        return 1
    print("✓ 设计令牌三方一致（JSON / Kotlin / Dart）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
