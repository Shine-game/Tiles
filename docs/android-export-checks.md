# Android startup checks

Keep Gradle enabled for the native gallery/share plugin. Imported audio must be
checked with `ResourceLoader.exists()`, not `FileAccess.file_exists()`: an exported
OGG is remapped to an imported resource, so the original raw file may be absent.

Export a resource pack using the Android preset, then run both checks from an
empty directory outside the source checkout. Use absolute paths for the pack and
test scripts:

```sh
godot --headless --path /absolute/path/to/Tiles --export-pack Android /tmp/tiles-check.pck
mkdir -p /tmp/tiles-isolated-check
cd /tmp/tiles-isolated-check
godot --headless --main-pack /tmp/tiles-check.pck --script /absolute/path/to/Tiles/tools/verify_exported_assets.gd
godot --headless --main-pack /tmp/tiles-check.pck --script /absolute/path/to/Tiles/tools/test_exported_startup.gd
```

Testing inside the checkout can silently find source files that are absent from
the export. Both checks reject that setup. The asset check includes hidden import
artifacts; the startup check loads all themes, sounds, fonts, icons, button styles,
and tutorial captions. Run the startup check without `--headless` for rendered UI
screenshots. These checks do not replace an on-device APK test.

The reported black/white Android tutorial was reproduced using the uploaded APK
assets: all six valid imported recordings were rejected by raw-file validation,
preventing the theme registry and palette from initializing. Replacing only the
validator in those assets resolved startup. Both that reproduction and a fresh
export passed 100 startup/UI checks, with all six raw recordings absent as expected.
