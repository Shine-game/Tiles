"""Check that Godot's import cache contains only current source imports.

Read-only. Run after a completed editor import, with Godot's editor closed.
"""
from pathlib import Path
import argparse
import json
import os
import re

ROOT = Path(__file__).resolve().parents[1]


def inspect():
    expected = set()
    sidecars = []
    ignored = []
    for base, dirs, files in os.walk(ROOT):
        path = Path(base)
        if '.gdignore' in files:
            ignored.append(path.relative_to(ROOT).as_posix())
            dirs[:] = []
            continue
        dirs[:] = [d for d in dirs if d not in {'.git', '.godot', '__pycache__'}]
        for name in files:
            if not name.endswith('.import'): continue
            p = path / name
            sidecars.append(p.relative_to(ROOT).as_posix())
            expected.update(Path(p).name for p in re.findall(r'res://\.godot/imported/[^"\r\n]+', p.read_text()))
    cache = ROOT / '.godot/imported'
    actual = {p.name for p in cache.iterdir() if p.is_file()} if cache.is_dir() else set()
    checksums = set()
    for name in expected:
        match = re.match(r'(.+-[0-9a-f]{32})', name)
        if match: checksums.add(match[1] + '.md5')
    missing = sorted(expected - actual)
    orphans = sorted(actual - expected - checksums)
    return {'source_imports': len(sidecars), 'expected_artifacts': len(expected),
            'cache_file_count': len(actual), 'cache_bytes': sum((cache / p).stat().st_size for p in actual),
            'missing_artifacts': missing, 'orphan_files': orphans, 'ignored_folders': sorted(ignored),
            'ok': bool(expected) and not missing and not orphans}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', help='Optional JSON report, relative to the project root.')
    args = parser.parse_args()
    result = inspect()
    print(json.dumps(result, indent=2))
    if args.output: (ROOT / args.output).write_text(json.dumps(result, indent=2) + '\n')
    return 0 if result['ok'] else 1


if __name__ == '__main__': raise SystemExit(main())
