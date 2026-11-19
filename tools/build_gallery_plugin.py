#!/usr/bin/env python3
"""Build the small Android AAR with JDK 17+, android.jar (API 29+) and a Godot AAR."""
import argparse
import io
import os
from pathlib import Path
import subprocess
import tempfile
from zipfile import ZipFile, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parents[1]

def archive(paths, base):
    data = io.BytesIO()
    with ZipFile(data, 'w', ZIP_DEFLATED) as output:
        for path in sorted(paths):
            output.writestr(str(path.relative_to(base)), path.read_bytes())
    return data.getvalue()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--android-jar', required=True, type=Path)
    parser.add_argument('--godot-aar', required=True, type=Path)
    args = parser.parse_args()
    with tempfile.TemporaryDirectory() as tmp:
        folder = Path(tmp)
        with ZipFile(args.godot_aar) as dependency:
            (folder / 'godot.jar').write_bytes(dependency.read('classes.jar'))
        classes = folder / 'classes'
        classes.mkdir()
        subprocess.run(['java', 'com.sun.tools.javac.Main', '-source', '17', '-target', '17', '-classpath',
                        str(args.android_jar.resolve()) + os.pathsep + str(folder / 'godot.jar'),
                        '-d', str(classes), *map(str, (ROOT / 'native/android/gallery/src').rglob('*.java'))], check=True)
        target = ROOT / 'addons/tiles_gallery/bin/tiles-gallery.aar'
        target.parent.mkdir(parents=True, exist_ok=True)
        with ZipFile(target, 'w', ZIP_DEFLATED) as aar:
            aar.writestr('AndroidManifest.xml', (ROOT / 'native/android/gallery/AndroidManifest.xml').read_bytes())
            aar.writestr('classes.jar', archive(classes.rglob('*.class'), classes))
            aar.writestr('proguard.txt', '-keep class org.shinegame.tiles.gallery.** { *; }\n')
            aar.writestr('R.txt', '')
        print(f'Built {target} ({target.stat().st_size} bytes)')

if __name__ == '__main__':
    main()
