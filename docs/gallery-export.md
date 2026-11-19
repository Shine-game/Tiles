# Gallery photo export and sharing

The in-game Gallery offers Save to Photos and Share for its selected saved PNG. Original PNG/JSON files remain in `user://gallery`.

- Android 10+: MediaStore writes Pictures/Tiles using a pending item, publishing only after the entire PNG is written. Failed writes remove the partial item.
- Android 6–9: Save requests WRITE_EXTERNAL_STORAGE at runtime (manifest limits it to API 28), writes Pictures/Tiles and asks the media scanner to index it. Denial leaves Share available.
- Share copies the PNG to a temporary app cache directory. A non-exported, read-only content provider exposes only the selected temporary PNG through an explicit read grant, ClipData and ACTION_SEND (`image/png`). The chooser hands it to an installed receiving app; success here means the chooser opened, not that a post was published. No Instagram login, token or network API is used.
- Desktop: Save Image uses a PNG file chooser; Share is disabled with an Android-only tooltip. Empty galleries disable both actions. Errors and cancellation restore the controls without deleting the original artwork.

The native worker performs image copies away from the game/render thread. Android UI operations run on the UI thread; results are sent back to Godot on its render thread. Old shared copies are cleaned up after 24 hours when preparing another share.

## Android build

The editor addon `addons/tiles_gallery` is enabled in project.godot and packages its small v2 Android AAR. The Android preset has Gradle builds enabled. Install the Android build template matching Godot 4.7.2 using Project → Install Android Build Template, then export with the Android SDK/JDK settings described in the README. A precompiled APK export without Gradle cannot include this native plugin.

The Java source and manifest are in `native/android/gallery`. To rebuild the included AAR with JDK 17+:

```sh
python tools/build_gallery_plugin.py --android-jar /path/to/android-35/android.jar --godot-aar /path/to/godot-4.7.2.stable.aar
```

The build needs only Android API stubs and the Godot AAR classes; it does not bundle the engine or require third-party Android dependencies. The checked-in AAR was compiled against Android API 35 and Godot 4.7.2, targeting Java 17 bytecode. The export uses the project's current application ID for the provider authority, so changing the package name does not break sharing.

## Validation

`tests/test_gallery_export.gd` verifies byte-identical desktop export, image path validation, plugin handoff, busy/cancellation/error recovery, empty galleries and responsive Gallery layout. Android source is compiled to an AAR; editor import checks the v2 export addon.

A physical Android run is still required to check Photos visibility, the legacy permission dialog, the target apps offered by the chooser, and completing/canceling an Instagram handoff. This workspace has no Android SDK build-tools or connected device, so an APK/device run has not been performed. Check a release build as well, including the bundled consumer keep rules.

## Game resume

Game-state persistence is independent of Gallery image export. `scripts/game_session.gd` validates and atomically replaces `user://game_state.json`, retaining the prior valid snapshot as `.bak`. It encodes RNG state as text to avoid JSON integer precision loss and restores Undo records as integer cell vectors. A corrupt primary uses the backup; invalid snapshots never become game objects.

`tests/test_game_session.gd` exercises close/background snapshots and a fresh scene reopening, including a moved/rotated offer, active versus future presets, exact queue/RNG continuation, working Undo, retained leaf cores and edge flow, plus corruption recovery. Board construction resumes visually settled rather than replaying interrupted animations or sounds.
