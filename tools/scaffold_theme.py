#!/usr/bin/env python3
"""Create a Vines-based theme with named artwork slots and optional local preview."""
import argparse
import json
import re
import shutil
from fnmatch import fnmatchcase
from pathlib import Path
from tempfile import TemporaryDirectory

ROOT = Path(__file__).resolve().parents[1]
THEMES = ROOT / "assets/themes"


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def rename_references(text, theme_id):
    return text.replace("/themes/vines/", f"/themes/{theme_id}/").replace("vines_tier", f"{theme_id}_tier").replace(
        "vines_ui_", f"{theme_id}_ui_"
    ).replace("vines_ambient", f"{theme_id}_ambient").replace("vines_place_click", f"{theme_id}_place_click")


def scaffold(destination, preset, base_profile):
    theme_id = preset["id"]
    source = THEMES / "vines"
    manifest = read_json(source / "manifest.json")
    overlay = ROOT / "theme_drafts" / theme_id
    resource_root = f"res://assets/themes/{theme_id}/"
    omitted = preset.get("omit_placeholders", [])
    with TemporaryDirectory(dir=THEMES) as temporary:
        draft = Path(temporary) / theme_id
        draft.mkdir()
        for path in manifest["files"]:
            original = path.removeprefix("res://assets/themes/vines/")
            renamed = rename_references(path, theme_id)
            relative = renamed.removeprefix(resource_root)
            if (overlay / relative).is_file() or any(fnmatchcase(relative, pattern) for pattern in omitted):
                continue
            target = draft / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            if target.suffix == ".json":
                data = json.loads(rename_references((source / original).read_text(encoding="utf-8"), theme_id))
                if data.get("schema") == "tiles.sprite-catalog.v1":
                    data.update(theme_id=theme_id, artwork_theme=theme_id)
                write_json(target, data)
            else:
                shutil.copyfile(source / original, target)
        for artwork in sorted(overlay.rglob("*")):
            if not artwork.is_file():
                continue
            target = draft / artwork.relative_to(overlay)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(artwork, target)
        paths = sorted(resource_root + path.relative_to(draft).as_posix() for path in draft.rglob("*") if path.is_file())
        write_json(draft / "manifest.json", {"schema": manifest["schema"], "theme_id": theme_id, "files": paths})
        profile = json.loads(rename_references(json.dumps(base_profile), theme_id))
        profile.update(name=preset["name"], menu_name=preset["name"], menu_rank=100, version="0.1.0")
        profile["colors"] = preset.get("colors", [])
        profile["ui"].update(preset.get("ui", {}))
        profile["frame"]["appearance"] = f"{theme_id}-draft"
        profile.update(preset.get("profile_overrides", {}))
        write_json(draft / "draft_profile.json", profile)
        draft.rename(destination)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("id", help="Theme ID using lowercase letters, digits, and underscores")
    parser.add_argument("--name", help="Display name for a new theme without a preset")
    parser.add_argument("--preview", action="store_true", help="Register the draft in this local checkout")
    args = parser.parse_args()
    if not re.fullmatch(r"[a-z][a-z0-9_]*", args.id):
        parser.error("Invalid theme ID.")
    registry_path = THEMES / "themes.json"
    registry = read_json(registry_path)
    if args.id in registry["themes"]:
        parser.error("This theme is already registered.")
    preset_path = ROOT / "theme_drafts" / f"{args.id}.json"
    if preset_path.exists():
        preset = read_json(preset_path)
    elif args.name and args.name.strip():
        preset = {"id": args.id, "name": args.name.strip()}
    else:
        parser.error("Supply --name or add a theme preset.")
    if preset["id"] != args.id:
        parser.error("The preset ID must match the destination ID.")
    destination = THEMES / args.id
    if not destination.exists():
        scaffold(destination, preset, registry["themes"]["vines"])
    elif not args.preview or not (destination / "draft_profile.json").is_file():
        parser.error("The destination already exists. Use --preview to register an existing draft.")
    if args.preview:
        registry["themes"][args.id] = read_json(destination / "draft_profile.json")
        registry["order"].append(args.id)
        write_json(registry_path, registry)
    print(f"Theme files: {destination.relative_to(ROOT)}")
    print("Draft registered for local preview." if args.preview else "Draft prepared. Use --preview to register it in a local checkout.")


if __name__ == "__main__":
    main()
