#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
生成 Porten Android 启动器图标。

产物：
    1. Adaptive Icon（Android 8.0+ / API 26+）：前景矢量 + 品牌渐变背景 + mipmap-anydpi-v26 描述；
    2. 位图回退（API 24/25）：各 density 的 PNG —— 因为 minSdk=24 必须提供 mipmap PNG，
       否则低版本设备上会回退到系统默认图标。

品牌依据：
    前景为 Porten 航班图标（源自 Web 端 assets/splash-icon.svg，#D4237A）；
    背景为 Porten 品牌渐变（#5BCEFA → #F5A9B8），取自 design tokens。
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

VIEWPORT = 108.0
ICON_SAFE_SIZE = 66.0
SOURCE_VIEWBOX = 1024.0

ANDROID_NS = 'xmlns:android="http://schemas.android.com/apk/res/android"'

BRAND_BLUE = "#5BCEFA"
BRAND_PINK = "#F5A9B8"
BRAND_MAGENTA = "#D4237A"

# density 目录 → 像素尺寸（mdpi=48 基准）
DENSITY_SIZES = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}


def read_source_paths(svg_path: Path) -> list[tuple[str, str]]:
    import re

    paths = []
    for tag in re.findall(r"<path\b[^>]*>", svg_path.read_text(encoding="utf-8"), re.I):
        attrs = dict(re.findall(r'([a-zA-Z0-9:_-]+)\s*=\s*"([^"]*)"', tag))
        d = attrs.get("d")
        if d:
            paths.append((d.strip(), attrs.get("fill", BRAND_MAGENTA)))
    return paths


def write_foreground(res_root: Path, paths: list[tuple[str, str]]) -> None:
    offset = (VIEWPORT - ICON_SAFE_SIZE) / 2
    scale = ICON_SAFE_SIZE / SOURCE_VIEWBOX
    lines = [
        f'<vector {ANDROID_NS}',
        f'    android:width="{int(VIEWPORT)}dp"',
        f'    android:height="{int(VIEWPORT)}dp"',
        f'    android:viewportWidth="{int(VIEWPORT)}"',
        f'    android:viewportHeight="{int(VIEWPORT)}">',
        '    <group',
        f'        android:translateX="{offset}"',
        f'        android:translateY="{offset}"',
        f'        android:scaleX="{scale:.6f}"',
        f'        android:scaleY="{scale:.6f}">',
    ]
    for d, fill in paths:
        lines.append("        <path")
        lines.append(f'            android:pathData="{d}"')
        lines.append(f'            android:fillColor="{fill}" />')
    lines.append("    </group>")
    lines.append("</vector>")
    target = res_root / "drawable" / "ic_launcher_foreground.xml"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"[OK] {target}")


def write_background(res_root: Path) -> None:
    content = f"""<vector {ANDROID_NS}
    android:width="{int(VIEWPORT)}dp"
    android:height="{int(VIEWPORT)}dp"
    android:viewportWidth="{int(VIEWPORT)}"
    android:viewportHeight="{int(VIEWPORT)}">
    <path
        android:pathData="M0,0h{VIEWPORT:.0f}v{VIEWPORT:.0f}h-{VIEWPORT:.0f}z"
        android:fillColor="{BRAND_BLUE}" />
    <path
        android:pathData="M0,0h{VIEWPORT:.0f}v{VIEWPORT:.0f}h-{VIEWPORT:.0f}z"
        android:fillColor="{BRAND_PINK}"
        android:fillAlpha="0.65" />
</vector>
"""
    target = res_root / "drawable" / "ic_launcher_background.xml"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content, encoding="utf-8")
    print(f"[OK] {target}")


def write_adaptive_icons(res_root: Path) -> None:
    anydpi = res_root / "mipmap-anydpi-v26"
    anydpi.mkdir(parents=True, exist_ok=True)
    for names in ("ic_launcher", "ic_launcher_round"):
        content = f"""<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon {ANDROID_NS}>
    <background android:drawable="@drawable/ic_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
</adaptive-icon>
"""
        target = anydpi / f"{names}.xml"
        target.write_text(content, encoding="utf-8")
        print(f"[OK] {target}")


def write_legacy_pngs(res_root: Path, paths: list[tuple[str, str]], tmp_dir: Path) -> None:
    """渲染位图回退：把背景与前景合成为一张 SVG 后按 density 输出 PNG。"""
    offset = int(SOURCE_VIEWBOX * (1 - (ICON_SAFE_SIZE / VIEWPORT)) / 2)
    inner_paths = "\n".join(
        f'  <path d="{d}" fill="{fill}" transform="translate({offset} {offset}) '
        f'scale({ICON_SAFE_SIZE / VIEWPORT:.6f})" />'
        for d, fill in paths
    )
    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0%" stop-color="{BRAND_BLUE}" />
      <stop offset="100%" stop-color="{BRAND_PINK}" />
    </linearGradient>
  </defs>
  <rect width="1024" height="1024" fill="url(#bg)" />
  <g transform="translate({SOURCE_VIEWBOX * (1 - ICON_SAFE_SIZE / VIEWPORT) / 2:.2f} {SOURCE_VIEWBOX * (1 - ICON_SAFE_SIZE / VIEWPORT) / 2:.2f}) scale({ICON_SAFE_SIZE / VIEWPORT:.6f})">
{inner_paths}
  </g>
</svg>
"""
    tmp_dir.mkdir(parents=True, exist_ok=True)
    tmp_svg = tmp_dir / "launcher_composed.svg"
    tmp_svg.write_text(svg, encoding="utf-8")

    for density, size in DENSITY_SIZES.items():
        out_dir = res_root / f"mipmap-{density}"
        out_dir.mkdir(parents=True, exist_ok=True)
        png = out_dir / "ic_launcher.png"
        subprocess.run(
            ["rsvg-convert", "-w", str(size), "-h", str(size), "-o", str(png), str(tmp_svg)],
            check=True,
        )
        print(f"[OK] {png} ({size}x{size})")
        round_png = out_dir / "ic_launcher_round.png"
        round_png.write_bytes(png.read_bytes())
        print(f"[OK] {round_png}")


def main() -> int:
    project_root = Path(__file__).resolve().parents[2]
    res_root = project_root / "app" / "src" / "main" / "res"
    source_svg = project_root.parent / "frontend" / "src" / "assets" / "splash-icon.svg"
    if not source_svg.exists():
        print(f"[FAIL] 未找到品牌图标源文件：{source_svg}")
        return 1

    paths = read_source_paths(source_svg)
    write_background(res_root)
    write_foreground(res_root, paths)
    write_adaptive_icons(res_root)
    write_legacy_pngs(res_root, paths, tmp_dir=Path("/tmp/porten-icons"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
