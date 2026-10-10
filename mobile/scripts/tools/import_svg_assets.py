#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
把 React Web 端的 SVG 资产迁移为 Android VectorDrawable。

设计目的：
    Porten 要求移动端 UI 100% 还原 Web 端，图标必须同源。
    手工转写 path 数据极易出错且无法重复执行，因此提供脚本化的资产迁移通道。

用法：
    python3 scripts/tools/import_svg_assets.py --src ../frontend/src/assets/splash-icon.svg --name ic_splash_logo
    python3 scripts/tools/import_svg_assets.py --batch assets-mapping.json

说明：
    - 资源命名遵循 Android 官方规范：drawable 使用 ic_ / img_ / bg_ 前缀，小写下划线；
    - 输出为 app/src/main/res/drawable/<name>.xml；如需位图（如桌面图标多档 resolution），
      可通过 rsvg-convert 等工具另行渲染，不在本脚本范围内；
    - 同时把原始 SVG 复制到 Flutter 的 assets 目录，保证两端图标同源。
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
from pathlib import Path
from typing import Dict, List, Tuple

ANDROID_NS = 'xmlns:android="http://schemas.android.com/apk/res/android"'

PATH_RE = re.compile(r"<path\b[^>]*>", re.I)
ATTR_RE = re.compile(r'([a-zA-Z0-9:_-]+)\s*=\s*"([^"]*)"')


def parse_paths(svg_text: str) -> List[Tuple[str, str]]:
    """提取所有 <path> 的 d 与 fill（fill 缺省时回退到 #000000）。"""
    result: List[Tuple[str, str]] = []
    for tag in PATH_RE.findall(svg_text):
        attrs: Dict[str, str] = dict(ATTR_RE.findall(tag))
        d = attrs.get("d", "").strip()
        if not d:
            continue
        fill = attrs.get("fill", "#000000").strip()
        if fill.lower() in ("none", "transparent"):
            continue
        result.append((d, normalize_color(fill)))
    return result


def normalize_color(color: str) -> str:
    """把 CSS 颜色规范化为 Android 可用的 #RRGGBB / #AARRGGBB。"""
    color = color.strip()
    if color.startswith("#"):
        hex_body = color[1:]
        if len(hex_body) == 3:
            hex_body = "".join(ch * 2 for ch in hex_body)
        if len(hex_body) == 6:
            return "#FF" + hex_body.upper()
        return "#" + hex_body.upper()
    return color


def extract_view_box(svg_text: str) -> Tuple[float, float, float, float]:
    match = re.search(r'viewBox\s*=\s*"([^"]+)"', svg_text, re.I)
    if not match:
        raise ValueError("SVG 缺少 viewBox，无法换算视口尺寸")
    parts = [float(p) for p in match.group(1).replace(",", " ").split()]
    if len(parts) != 4:
        raise ValueError(f"viewBox 格式异常：{match.group(1)}")
    return parts[0], parts[1], parts[2], parts[3]


def normalize_path_data(d: str) -> str:
    """
    规范化 path 命令：确保命令字母与数字之间以空格分隔，并去掉多余空白。

    必要性：部分设计工具导出的 SVG 会出现 `z m483.2-395.84` 这类粘连写法，
    Android 的 pathData 解析器容忍度低于浏览器，不规范化会导致资源编译失败或图形失真。
    注意排除科学计数法中的指数符号 e/E，避免误拆。
    """
    spaced = re.sub(r"([a-df-zA-DF-Za-z])(?=-?\d)", r"\1 ", d)
    spaced = re.sub(r"(\d)(?=[a-df-zA-DF-Za-z])", r"\1 ", spaced)
    return re.sub(r"\s+", " ", spaced).strip()


def build_vector_drawable(name: str, paths: List[Tuple[str, str]], view_box: Tuple[float, float, float, float]) -> str:
    _x, _y, width, height = view_box
    # 固有尺寸统一按 24dp（Android VectorDrawable 官方推荐基准）保持宽高比输出，
    # 实际显示大小由调用方（Modifier.size / ImageView 尺寸）决定。
    intrinsic_w, intrinsic_h = intrinsic_size(width, height)
    lines = [
        f'<vector {ANDROID_NS}',
        f'    android:width="{fmt(intrinsic_w)}dp"',
        f'    android:height="{fmt(intrinsic_h)}dp"',
        f'    android:viewportWidth="{fmt(width)}"',
        f'    android:viewportHeight="{fmt(height)}">',
    ]
    for d, fill in paths:
        lines.append("    <path")
        lines.append(f'        android:pathData="{normalize_path_data(d)}"')
        lines.append(f'        android:fillColor="{fill}" />')
    lines.append("</vector>")
    lines.append("")
    return "\n".join(lines)


def intrinsic_size(width: float, height: float) -> Tuple[float, float]:
    """把任意 viewBox 等比换算到 24dp 基准的固有尺寸。"""
    base = 24.0
    if width <= 0 or height <= 0:
        return base, base
    scale = base / max(width, height)
    return width * scale, height * scale


def fmt(value: float) -> str:
    return str(int(value)) if value.is_integer() else str(value)


def copy_to_flutter_assets(svg_path: Path, name: str, flutter_root: Path) -> Path:
    """把原始 SVG 复制到 Flutter 模块 assets/icons 目录，保持两端同源。"""
    target_dir = flutter_root / "assets" / "icons"
    target_dir.mkdir(parents=True, exist_ok=True)
    target = target_dir / f"{name}.svg"
    shutil.copyfile(svg_path, target)
    return target


def convert(src: Path, name: str, drawable_dir: Path, flutter_root: Path) -> None:
    svg_text = src.read_text(encoding="utf-8")
    paths = parse_paths(svg_text)
    if not paths:
        raise ValueError(f"{src} 中未解析到可迁移的 path")
    view_box = extract_view_box(svg_text)

    drawable_dir.mkdir(parents=True, exist_ok=True)
    out = drawable_dir / f"{name}.xml"
    out.write_text(build_vector_drawable(name, paths, view_box), encoding="utf-8")
    flutter_target = copy_to_flutter_assets(src, name, flutter_root)
    print(f"[OK] {src.name} -> {out}  (path:{len(paths)}, viewport:{view_box[2]}x{view_box[3]})")
    print(f"[OK] 同步到 Flutter：{flutter_target}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Web SVG → Android VectorDrawable 迁移工具")
    parser.add_argument("--src", help="源 SVG 路径")
    parser.add_argument("--name", help="输出资源名（不含扩展名，snake_case，带 ic_/img_/bg_ 前缀）")
    parser.add_argument("--batch", help="批量映射 JSON：[{\"src\":\"...\",\"name\":\"...\"}]")
    parser.add_argument("--res-module", default="core/ui",
                        help="目标资源模块（默认 core/ui：跨模块共享；宿主专属资源传 app）")
    args = parser.parse_args()

    project_root = Path(args.project_root).resolve() if args.project_root else Path(__file__).resolve().parents[2]
    drawable_dir = project_root / args.res_module / "src" / "main" / "res" / "drawable"
    flutter_root = project_root / "flutter" / "porten_flutter"

    jobs: List[Tuple[Path, str]] = []
    if args.batch:
        mapping = json.loads(Path(args.batch).read_text(encoding="utf-8"))
        jobs = [(Path(item["src"]).resolve(), item["name"]) for item in mapping]
    elif args.src and args.name:
        jobs = [(Path(args.src).resolve(), args.name)]
    else:
        parser.error("需要同时提供 --src 与 --name，或使用 --batch")

    for src, name in jobs:
        if not src.exists():
            print(f"[FAIL] 源文件不存在：{src}")
            return 1
        convert(src, name, drawable_dir, flutter_root)
    return 0


if __name__ == "__main__":
    sys.exit(main())
