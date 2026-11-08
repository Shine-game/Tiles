# Tiles — Godot / Android

Native GDScript puzzle for **Godot 4.7.2 stable official**. Open `project.godot` in that version, then press **F6** on `main.tscn` or **F5** to play. No web server, Node.js, plugins, or external game dependencies are required.

## Play

- A green center square begins a 9×9 garden, switchable to 11×11.
- Seven standard tetrominoes arrive in shuffled seven-piece bags. I/O/S are sage green; T/J/L/Z are marigold yellow.
- Pieces must touch the pattern along an edge or corner. They cannot overlap or leave the board. No lines clear.
- Tap a square to preview, then tap it again or press **Place piece**. The anchor is the top-left of the piece's bounding box; that square may itself be empty. The same controls work with a mouse.
- Rotate clockwise using the button or **R**. Mirror flips are not allowed.
- Small diagrams at the top left highlight possible symmetries; the incoming piece appears at the top right. An asterisk indicates a symmetry already achieved.
- **Back** retraces up to three recent placements, restoring the board and offered piece. Playing again starts a new history branch while preserving the generated piece sequence.
- New pattern and board-size changes ask before discarding the current game.
- There is no timer. An invalid move is rejected; the game ends when the incoming piece has no safe placement in any rotation. Back remains available after game over.

## Symmetry rule

The board may be asymmetric during play. For every central reflection (vertical, horizontal, both diagonals) and nonidentity square rotation (90°, 180°, 270°), cells are grouped into transformation orbits. A symmetry remains possible if no orbit contains both colors. Empty cells may be filled later. Quarter-turn checks inspect the entire four-cell orbit, including conflicts separated by empty cells. 90° and 270° have equivalent feasibility but appear separately.

This prototype checks **color compatibility**, not whether every remaining gap can be filled with future whole tetrominoes. All axes and centers are fixed to the garden's center. State is held in memory; restarting the app starts a fresh game. Decorative flower/leaf overlays are a later feature.

## Android export

The committed **Android** preset produces an ARM64 APK with the Compatibility renderer and a portrait interface. Default package ID: `org.shinegame.tiles`. The game requires no Internet permission.

1. Install the matching **4.7.2** export templates from Godot's **Editor → Manage Export Templates**.
2. Install a supported Java runtime/SDK (Godot recommends OpenJDK 17; higher versions are supported), Android SDK platform-tools, build-tools **36.0.0**, and platform **android-36**.
3. Set **Editor Settings → Export → Android → Java SDK Path / Android SDK Path**. These machine-local paths and signing keys are not committed.
4. Create the `build` directory. Export a debug APK from **Project → Export → Android**, or run:

```sh
godot --headless --path . --export-debug Android build/tiles-debug.apk
```

The standard APK export uses the precompiled engine templates, so compiling the engine, installing the NDK, and configuring Gradle are unnecessary for this prototype. Store distribution, AABs, custom Android plugins, and release signing require a separate release setup. Never commit signing keys or passwords.

Install a debug APK on an attached Android device with `adb install -r build/tiles-debug.apk`. Device testing remains necessary for touch feel, safe areas, lifecycle behavior, and performance.

## Tests

Use the **4.7.2** binary, not a different `godot` installation:

```sh
godot --headless --editor --path . --import --quit
godot --headless --path . --script tests/test_rules.gd
godot --headless --path . --script tests/test_ui.gd
```

The rules runner executes 483 checks covering both sizes, all pieces, rotations, reflection/orbit conflicts, placement constraints, game over, seeded piece bags, and undo. The UI runner exercises native screen-touch input, rotation, placement, undo, and board reset. On a graphical display it also writes `/tmp/tiles-godot.png`.

## Structure

- `scripts/rules.gd`: pure board, placement, and symmetry functions.
- `scripts/game.gd`: piece generation, progression, game over, and history.
- `scripts/main.gd`: native responsive controls and interactions.
- `scripts/board_view.gd`, `piece_view.gd`, `symmetry_icon.gd`: independent renderers, ready for later visual motifs.
- `main.tscn`: entry scene; `export_presets.cfg`: portable Android preset.

The earlier browser proof of concept remains available in Git history at commit `1552407`; this working tree is the native Godot implementation.
