# Tiles — Godot / Android

Native GDScript puzzle for **Godot 4.7.2 stable official**. Open `project.godot` in that version, then press **F6** on `main.tscn` or **F5** to play. No web server, Node.js, plugins, or external game dependencies are required.

## Play

- A bright blue center square begins a 9×9 garden, switchable to 11×11. The board and every control fit on a single screen without scrolling. The board uses the full available width when space permits, and shrinks to fit shorter screens. Landscape layouts place the controls beside the board. Fitting everything on screen takes priority over earlier control positions. The interface contains no title, captions, instructions, commentary, or help dialogs.
- Eleven shapes are available: the seven standard tetrominoes, a 1×1 square (Dot), a 1×2 domino, a straight three-square piece (I3), and an L-shaped three-square piece (L3). Generation first chooses a size category uniformly, then a fitting shape uniformly within that category. While all shapes fit, each size has a 25% chance: Dot 25%, Domino 25%, I3/L3 12.5% each, and each tetromino about 3.57%. Draws are independent, so repeats can occur.
- Shapes are eligible only if some rotation or reflection fits inside empty squares and touches the existing pattern at an edge or corner. Color and symmetry are deliberately ignored for this generation filter. If a size has no fitting shapes, its probability is shared equally among the remaining sizes. A physically fitting piece that destroys symmetry in every placement can still be generated. It remains draggable; confirming a symmetry-breaking placement ends the game.
- Pieces must touch the pattern along an edge or corner. They cannot overlap or leave the board. No lines clear.
- Drag the incoming piece from the upper right onto the field. Grab **any occupied square**, including when picking up a floating piece again. The grabbed square stays under the finger or mouse pointer. Empty space in a piece's bounding box is not a drag handle.
- Release to leave the piece hovering, whether the position is valid or invalid. Release never commits. The overlay remains visible even partly outside the board. The screen stays fixed even while dragging at an edge.
- **Place** activates when the piece is inside the board, avoids overlap, and touches the pattern. Press it to commit. The **Back** arrow, board-size toggle, and **+** reset are alongside it.
- Rotate clockwise with the rotation arrow or **R**, and mirror horizontally with **Flip** or **F**. Rotate after flipping for other reflected orientations. Flipping a symmetric shape leaves an equivalent shape.
- Choose vibrant blue or coral using the color swatches freely before any placement; **C** toggles colors on a keyboard. Color is no longer tied to piece shape. Your choice carries forward to the next piece. Invalid placement previews are dull gray; changing color or orientation immediately rechecks the preview. A symmetry conflict is gray but can still be physically placeable: pressing Place then ends the game.
- Two graphics at the top left summarize symmetry: a single square highlights each available vertical, horizontal, and diagonal reflection axis; a circular arrow lights when any rotational symmetry is possible. The graphics preview the hovered placement when it physically fits, and otherwise show the committed pattern. The incoming piece appears at the top right.
- **Back** retraces up to three recent placements, restores the board and chosen color, and rerolls the offered piece immediately. The reroll uses fresh randomness, excludes the outgoing offer when another shape fits, and still applies physical-fit filtering and balanced size selection. If only one shape fits, it repeats that shape. The rerolled piece starts in its default orientation.
- The **+** button starts a fresh pattern; the size button switches between 9×9 and 11×11. Both reset immediately without a dialog.
- There is no timer. Physically impossible placements are disabled. The game ends only after the player confirms a physically valid placement that breaks every remaining symmetry. A piece with no symmetry-preserving placement does not end play merely by appearing. A completely filled board ends with a completion message and no new piece. Back remains available after either ending.

## Symmetry rule

The board may be asymmetric during play. For every central reflection (vertical, horizontal, both diagonals) and nonidentity square rotation (90°, 180°, 270°), cells are grouped into transformation orbits. A symmetry remains possible if no orbit contains both colors. Empty cells may be filled later. Quarter-turn checks inspect the entire four-cell orbit, including conflicts separated by empty cells. 90° and 270° have equivalent feasibility; the rotation graphic combines all three nonidentity rotations.

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

The rules runner executes 691 checks covering both sizes, all eleven pieces, rotations, flips, reflection/orbit conflicts, placement constraints, color/flip rescues, game over, physical-fit filtering, balanced size frequencies, rerolls after undo, and the forced single-shape fallback. The UI runner executes 302 checks with engine-routed touch and mouse input, dragging from every occupied piece square, persistent valid/invalid hover, grab offsets, color selection, flips, the two symmetry summaries, the compact action controls, confirmed symmetry loss, undo, and non-scrolling portrait/landscape layouts from 240×320 through 844×390. On a graphical display it also writes `/tmp/tiles-godot.png`.

## Structure

- `scripts/rules.gd`: pure board, placement, and symmetry functions.
- `scripts/game.gd`: piece generation, progression, game over, and history.
- `scripts/main.gd`: native responsive controls and interactions.
- `scripts/palette.gd`: shared vibrant tile colors and dull gray invalid preview.
- `scripts/board_view.gd`, `piece_view.gd`, `floating_piece.gd`, `symmetry_icon.gd`: independent renderers, ready for later visual motifs.
- `main.tscn`: entry scene; `export_presets.cfg`: portable Android preset.

The earlier browser proof of concept remains available in Git history at commit `1552407`; this working tree is the native Godot implementation.
