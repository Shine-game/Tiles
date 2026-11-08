# Tiles — Godot / Android

Native GDScript puzzle for **Godot 4.7.2 stable official**. Open `project.godot` in that version, then press **F6** on `main.tscn` or **F5** to play. No web server, Node.js, plugins, or external game dependencies are required.

## Play

- A bright blue center square begins a 9×9 garden, switchable to 11×11. The square board spans the full phone viewport width. On shorter screens, swipe vertically to reach the surrounding controls; the board is never shrunk to fit the screen height.
- Eleven shapes are available: the seven standard tetrominoes, a 1×1 square (Dot), a 1×2 domino, a straight three-square piece (I3), and an L-shaped three-square piece (L3). Generation first chooses a size category uniformly, then a fitting shape uniformly within that category. While all shapes fit, each size has a 25% chance: Dot 25%, Domino 25%, I3/L3 12.5% each, and each tetromino about 3.57%. Draws are independent, so repeats can occur.
- Shapes are eligible only if some rotation or reflection fits inside empty squares and touches the existing pattern at an edge or corner. Color and symmetry are deliberately ignored for this generation filter. If a size has no fitting shapes, its probability is shared equally among the remaining sizes. A physically fitting piece that destroys symmetry in every placement can still be generated and end the game.
- Pieces must touch the pattern along an edge or corner. They cannot overlap or leave the board. No lines clear.
- Tap a square to preview, then tap it again or press **Place piece**. The anchor is the top-left of the piece's bounding box; that square may itself be empty. The same controls work with a mouse.
- Rotate clockwise with **Rotate** or **R**, and mirror horizontally with **Flip** or **F**. Rotate after flipping for other reflected orientations. Flipping a symmetric shape leaves an equivalent shape.
- Choose vibrant **Blue** or **Coral** freely before any placement; **C** toggles colors on a keyboard. Color is no longer tied to piece shape. Your choice carries forward to the next piece. Invalid placement previews are dull gray; changing color or orientation immediately rechecks the preview.
- Small diagrams at the top left highlight possible symmetries; the incoming piece appears at the top right. An asterisk indicates a symmetry already achieved.
- **Back** retraces up to three recent placements, restoring the board, offered piece, chosen color, and placed orientation. Replaying the same move reproduces the next draw. A different history branch regenerates the next piece against its resulting board, so an old draw cannot become physically impossible.
- New pattern and board-size changes ask before discarding the current game.
- There is no timer. An invalid move is rejected; the game ends when the incoming piece has no safe placement across either color and every rotation and reflection. A completely filled board ends with a completion message and no new piece. Back remains available after either ending.

## Symmetry rule

The board may be asymmetric during play. For every central reflection (vertical, horizontal, both diagonals) and nonidentity square rotation (90°, 180°, 270°), cells are grouped into transformation orbits. A symmetry remains possible if no orbit contains both colors. Empty cells may be filled later. Quarter-turn checks inspect the entire four-cell orbit, including conflicts separated by empty cells. 90° and 270° have equivalent feasibility but appear separately.

This prototype checks **color compatibility**, not whether every remaining gap can be filled with future whole pieces. All axes and centers are fixed to the garden's center. State is held in memory; restarting the app starts a fresh game. Decorative flower/leaf overlays are a later feature.

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

The rules runner executes 684 checks covering both sizes, all eleven pieces, rotations, flips, reflection/orbit conflicts, placement constraints, color/flip rescues, game over, physical-fit filtering, balanced size frequencies, deterministic replay, and undo. The UI runner exercises native screen-touch input, color selection, flips, gray invalid previews, rotation, placement, undo, and board reset. On a graphical display it also writes `/tmp/tiles-godot.png`.

## Structure

- `scripts/rules.gd`: pure board, placement, and symmetry functions.
- `scripts/game.gd`: piece generation, progression, game over, and history.
- `scripts/main.gd`: native responsive controls and interactions.
- `scripts/palette.gd`: shared vibrant tile colors and dull gray invalid preview.
- `scripts/board_view.gd`, `piece_view.gd`, `symmetry_icon.gd`: independent renderers, ready for later visual motifs.
- `main.tscn`: entry scene; `export_presets.cfg`: portable Android preset.

The earlier browser proof of concept remains available in Git history at commit `1552407`; this working tree is the native Godot implementation.
