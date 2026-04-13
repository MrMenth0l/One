#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
RESOURCES_DIR = REPO_ROOT / "ios/OneClient/Sources/OneClient/Resources"
RAW_EXPORTS_DIR = RESOURCES_DIR / "StreamlineExports"
ASSET_CATALOG_DIR = RESOURCES_DIR / "OneIconAssets.xcassets"
MANIFEST_PATH = RESOURCES_DIR / "streamline-lucide-manifest.json"
BRAND_MARK_IMAGESET = ASSET_CATALOG_DIR / "brand-mark.imageset"
BRAND_MARK_FILE = BRAND_MARK_IMAGESET / "brand-mark.png"


def load_manifest() -> dict[str, dict[str, dict[str, str]]]:
    return json.loads(MANIFEST_PATH.read_text())


def asset_name(raw_key: str) -> str:
    return raw_key.replace(".", "-")


def ensure_raw_exports(manifest: dict[str, dict[str, dict[str, str]]], lucide_source_dir: Path | None) -> None:
    RAW_EXPORTS_DIR.mkdir(parents=True, exist_ok=True)

    if lucide_source_dir is None:
        return

    for section in ("semantic", "ui"):
        for entry in manifest[section].values():
            source = entry.get("source")
            if not source:
                continue
            source_path = lucide_source_dir / source
            target_path = RAW_EXPORTS_DIR / source
            if not source_path.exists():
                raise FileNotFoundError(f"Missing Lucide source icon: {source_path}")
            if not target_path.exists() or source_path.read_text() != target_path.read_text():
                shutil.copyfile(source_path, target_path)


def write_imageset(imageset_dir: Path, source_path: Path) -> None:
    imageset_dir.mkdir(parents=True, exist_ok=True)
    target_name = f"{imageset_dir.stem}.svg"
    shutil.copyfile(source_path, imageset_dir / target_name)
    contents = {
        "images": [
            {
                "filename": target_name,
                "idiom": "universal"
            }
        ],
        "info": {
            "author": "xcode",
            "version": 1
        },
        "properties": {
            "preserves-vector-representation": True,
            "template-rendering-intent": "template"
        }
    }
    (imageset_dir / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")


def rebuild_asset_catalog(manifest: dict[str, dict[str, dict[str, str]]]) -> None:
    ASSET_CATALOG_DIR.mkdir(parents=True, exist_ok=True)
    (ASSET_CATALOG_DIR / "Contents.json").write_text(
        json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n"
    )

    for child in ASSET_CATALOG_DIR.glob("*.imageset"):
        if child.name == BRAND_MARK_IMAGESET.name:
            continue
        shutil.rmtree(child)

    for section in ("semantic", "ui"):
        for raw_key, entry in manifest[section].items():
            if entry.get("mode") == "preserve":
                continue
            source_name = entry.get("source")
            if not source_name:
                raise ValueError(f"Missing source mapping for {raw_key}")
            source_path = RAW_EXPORTS_DIR / source_name
            if not source_path.exists():
                raise FileNotFoundError(
                    f"Missing raw export for {raw_key}: {source_path}. "
                    "Populate StreamlineExports or pass --lucide-source-dir."
                )
            imageset_dir = ASSET_CATALOG_DIR / f"{asset_name(raw_key)}.imageset"
            write_imageset(imageset_dir, source_path)

    if not BRAND_MARK_FILE.exists():
        raise FileNotFoundError(f"Expected preserved brand mark asset at {BRAND_MARK_FILE}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Sync Streamline/Lucide icons into the One iOS asset catalog.")
    parser.add_argument(
        "--lucide-source-dir",
        type=Path,
        help="Optional Lucide icons directory used to populate StreamlineExports before syncing."
    )
    args = parser.parse_args()

    manifest = load_manifest()
    ensure_raw_exports(manifest, args.lucide_source_dir)
    rebuild_asset_catalog(manifest)


if __name__ == "__main__":
    main()
