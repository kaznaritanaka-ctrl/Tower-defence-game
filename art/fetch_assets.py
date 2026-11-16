#!/usr/bin/env python3
"""Restore only the pinned free source files listed in ASSET_MANIFEST.json."""

from __future__ import annotations

import argparse
import hashlib
import http.cookiejar
import io
import json
import re
import urllib.parse
import urllib.request
import zipfile
from pathlib import Path, PurePosixPath


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = Path(__file__).with_name("ASSET_MANIFEST.json")
MAX_DOWNLOAD_BYTES = 64 * 1024 * 1024


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def read_response(opener, request) -> bytes:
    with opener.open(request, timeout=60) as response:
        data = response.read(MAX_DOWNLOAD_BYTES + 1)
    if len(data) > MAX_DOWNLOAD_BYTES:
        raise RuntimeError("The download exceeds the size allowed by this helper.")
    return data


def csrf(html: str) -> str:
    match = re.search(r'name="csrf_token" value="([^"]+)"', html)
    if not match:
        raise RuntimeError("The publisher download page changed; review the source manually.")
    return match.group(1)


def post_json(opener, url: str, data: dict, referer: str) -> dict:
    request = urllib.request.Request(
        url,
        data=urllib.parse.urlencode(data).encode(),
        headers={"Referer": referer, "Content-Type": "application/x-www-form-urlencoded"},
    )
    response = json.loads(read_response(opener, request))
    if response.get("errors") or not response.get("url"):
        raise RuntimeError("The publisher did not offer this free download; no purchase was attempted.")
    return response


def fetch_free_itch_archive(info: dict) -> bytes:
    """Follow itch.io's public 'No thanks, just take me to the downloads' flow.

    No account, payment fields, private key, or quarantine override is used.
    The expected upload must still be offered on the resulting free download page.
    """
    page = info["product_url"]
    opener = urllib.request.build_opener(
        urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar())
    )
    html = read_response(opener, page).decode()
    generated = post_json(opener, page + "/download_url", {"csrf_token": csrf(html)}, page)
    download_page = generated["url"]
    html = read_response(opener, download_page).decode()
    offered = re.findall(r'data-upload_id="(\d+)".{0,500}?<strong[^>]*title="([^"]+)"', html)
    expected = (str(info["upload_id"]), info["label"])
    if expected not in offered:
        raise RuntimeError("The pinned free upload is no longer offered. Do not substitute a paid or newer pack.")
    endpoint = page + "/file/" + str(info["upload_id"]) + "?source=game_download"
    resolved = post_json(opener, endpoint, {"csrf_token": csrf(html)}, download_page)
    archive = read_response(opener, resolved["url"])
    if sha256(archive) != info["sha256"]:
        raise RuntimeError("The publisher archive differs from the pinned SHA-256.")
    return archive


def source_path(relative: str) -> Path:
    path = (ROOT / relative).resolve()
    if not path.is_relative_to((ROOT / "art/source-assets").resolve()):
        raise RuntimeError("Manifest destinations must remain under art/source-assets.")
    return path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify-only", action="store_true", help="Check existing files without network access")
    args = parser.parse_args()
    manifest = json.loads(MANIFEST.read_text())
    archives: dict[str, zipfile.ZipFile] = {}
    entries = manifest["assets"] + manifest["licenses"]
    try:
        for entry in entries:
            path = source_path(entry["path"])
            if path.exists():
                if sha256(path.read_bytes()) != entry["sha256"]:
                    raise RuntimeError(f"Existing source file differs: {entry['path']}. Preserve your changes before restoring.")
                print("OK", entry["path"])
                continue
            if args.verify_only:
                raise RuntimeError(f"Missing source file: {entry['path']}")
            archive_id = entry.get("archive_id")
            if archive_id:
                if archive_id not in archives:
                    info = manifest["archives"][archive_id]
                    archives[archive_id] = zipfile.ZipFile(io.BytesIO(fetch_free_itch_archive(info)))
                member = PurePosixPath(entry["archive_member"])
                if member.is_absolute() or ".." in member.parts:
                    raise RuntimeError("Invalid archive member path.")
                data = archives[archive_id].read(str(member))
            else:
                url = entry.get("download_url") or entry["source_url"]
                data = read_response(urllib.request.build_opener(), url)
            if sha256(data) != entry["sha256"]:
                raise RuntimeError(f"Source hash mismatch: {entry['path']}")
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
            print("FETCHED", entry["path"])
    finally:
        for archive in archives.values():
            archive.close()
    print(f"Verified {len(entries)} pinned files.")


if __name__ == "__main__":
    main()
