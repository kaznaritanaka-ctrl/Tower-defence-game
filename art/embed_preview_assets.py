#!/usr/bin/env python3
"""既存のLv1プレビューに、ローカルPNGをネットワーク不要の形で埋め込む。

    python3 art/embed_preview_assets.py
    python3 art/embed_preview_assets.py --fragment /workspace/amber-dungeon-layout.html

ゲーム処理やHTMLレイアウトは変更しない。SPRITE_DATAのコメント範囲だけを更新する。
manifestにhitBoundsがない場合に限り、透過範囲の検出にPillowが必要。
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import math
from pathlib import Path
import re
import struct
import sys


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT / "prototypes/assets/lv1/sprites.json"
DEFAULT_TARGET = ROOT / "prototypes/landscape-ui.html"
MAX_HTML_BYTES = 1_000_000
PATTERN = re.compile(
    r"(/\* LV1_SPRITES_START \*/).*?(/\* LV1_SPRITES_END \*/)", re.S
)
REQUIRED = {"floor", "wall", "archer", "well", "deposit", "kobold", "mage", "trap"}


def number(value: object) -> bool:
    return type(value) in (int, float) and math.isfinite(value)


def hit_bounds(meta: dict, image_path: Path, width: int, height: int) -> list[int]:
    bounds = meta.get("hitBounds")
    if bounds is None:
        try:
            from PIL import Image
        except ImportError as error:
            raise ValueError(
                f"{image_path.name}: hitBoundsがありません。"
                "manifestを再生成するか、Pillowをインストールしてください。"
            ) from error
        with Image.open(image_path) as image:
            alpha = image.convert("RGBA").getchannel("A")
            bounds = alpha.point(lambda value: 255 if value >= 48 else 0).getbbox()
    if not isinstance(bounds, (list, tuple)) or len(bounds) != 4:
        raise ValueError(f"{image_path.name}: hitBoundsが不正です")
    if not all(type(value) is int for value in bounds):
        raise ValueError(f"{image_path.name}: hitBoundsは整数で指定してください")
    left, top, right, bottom = bounds
    if not (0 <= left < right <= width and 0 <= top < bottom <= height):
        raise ValueError(f"{image_path.name}: hitBoundsが画像範囲外です")
    return list(bounds)


def read_sprites(manifest_path: Path) -> tuple[dict, dict]:
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    records = manifest.get("sprites")
    if not isinstance(records, dict) or not REQUIRED.issubset(records):
        raise ValueError("manifestの必須スプライトが不足しています")
    directory = manifest_path.parent.resolve()
    embedded, hashes = {}, {}
    for key, meta in records.items():
        if not re.fullmatch(r"[a-z][a-z0-9_]*", key) or not isinstance(meta, dict):
            raise ValueError("スプライト名またはメタデータが不正です")
        filename = meta.get("file")
        if not isinstance(filename, str):
            raise ValueError(f"{key}: fileがありません")
        image_path = (directory / filename).resolve()
        if image_path.parent != directory or image_path.suffix.lower() != ".png":
            raise ValueError(f"{key}: manifestと同じフォルダーのPNGを指定してください")
        data = image_path.read_bytes()
        if len(data) < 24 or data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
            raise ValueError(f"{filename}: PNGではありません")
        width, height = struct.unpack(">II", data[16:24])
        if width != meta.get("width") or height != meta.get("height"):
            raise ValueError(f"{filename}: PNGとmanifestの寸法が一致しません")
        anchor, reference = meta.get("anchor"), meta.get("referenceTw")
        if not isinstance(anchor, list) or len(anchor) != 2 or not all(map(number, anchor)):
            raise ValueError(f"{filename}: anchorが不正です")
        if not number(reference) or reference <= 0:
            raise ValueError(f"{filename}: referenceTwが不正です")
        footprint = meta.get("footprint", [1, 1])
        if footprint != [1, 1]:
            raise ValueError(f"{filename}: このプレビューは1マスの施設に対応しています")
        embedded[key] = {
            "file": filename,
            "width": width,
            "height": height,
            "anchor": anchor,
            "referenceTw": reference,
            "footprint": footprint,
            "hitBounds": hit_bounds(meta, image_path, width, height),
            "src": "data:image/png;base64," + base64.b64encode(data).decode("ascii"),
        }
        hashes[key] = {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}
    return embedded, hashes


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--target", type=Path, default=DEFAULT_TARGET,
                        help="更新するHTML。省略時はprototypes/landscape-ui.html")
    parser.add_argument("--fragment", type=Path,
                        help="指定した場合は会話内の編集用fragmentも同じデータで更新")
    args = parser.parse_args()
    try:
        records, hashes = read_sprites(args.manifest.resolve())
        payload = json.dumps(records, ensure_ascii=False, separators=(",", ":"))
        targets = [args.target.resolve()]
        if args.fragment and args.fragment.resolve() not in targets:
            targets.append(args.fragment.resolve())
        outputs = []
        for target in targets:
            html = target.read_text(encoding="utf-8")
            if len(PATTERN.findall(html)) != 1:
                raise ValueError(f"{target}: SPRITE_DATAのコメント範囲が1か所ではありません")
            updated = PATTERN.sub(lambda match: match[1] + " " + payload + " " + match[2], html)
            size = len(updated.encode("utf-8"))
            if size >= MAX_HTML_BYTES:
                raise ValueError(f"{target}: {size:,} bytesで1MB制限を超えます")
            outputs.append((target, updated, size))
        # 全入力を検証してから更新。資源・研究・保存処理のコードは変更しない。
        for target, updated, size in outputs:
            target.write_text(updated, encoding="utf-8")
            print(f"更新: {target} ({size:,} bytes)")
        print(f"PNG: {len(hashes)}個 / {sum(item['bytes'] for item in hashes.values()):,} bytes")
        for key, item in hashes.items():
            print(f"{key}: SHA-256 {item['sha256']}")
        return 0
    except (OSError, ValueError, TypeError, json.JSONDecodeError) as error:
        print(f"埋め込み失敗: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
