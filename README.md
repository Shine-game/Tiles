# Tiles — Godot / Android

Native GDScript puzzle for **Godot 4.7.2 stable official**. Open `project.godot` in that version, then press **F6** on `main.tscn` or **F5** to play. No web server, Node.js, plugins, or external game dependencies are required.

## Play

- A small green center motif begins a 9×9 garden, switchable to 11×11. The board and every control fit on a single screen without scrolling. The board uses the full available width when space permits, and shrinks to fit shorter screens. Landscape layouts place the controls beside the board. Fitting everything on screen takes priority over earlier control positions. The interface contains no title, captions, instructions, commentary, or help dialogs.
- Eleven shapes are available: the seven standard tetrominoes, a 1×1 square (Dot), a 1×2 domino, a straight three-square piece (I3), and an L-shaped three-square piece (L3). Generation first chooses a size category uniformly, then a fitting shape uniformly within that category. While all shapes fit, each size has a 25% chance: Dot 25%, Domino 25%, I3/L3 12.5% each, and each tetromino about 3.57%. Draws are independent, so repeats can occur.
- Shapes are eligible only if some rotation or reflection fits inside empty squares and touches the existing pattern at an edge or corner. Color and symmetry are deliberately ignored for this generation filter. If a size has no fitting shapes, its probability is shared equally among the remaining sizes. A physically fitting piece that destroys symmetry in every placement can still be generated. It remains draggable; confirming a symmetry-breaking placement ends the game.
- Pieces must touch the pattern along an edge or corner. They cannot overlap or leave the board. No lines clear.
- Drag the incoming piece from the upper right onto the field. Grab **any occupied square**, including when picking up a floating piece again. The grabbed square stays under the finger or mouse pointer. Empty space in a piece's bounding box is not a drag handle.
- Release to leave the piece hovering, whether the position is valid or invalid. Release never commits. The overlay remains visible even partly outside the board. The screen stays fixed even while dragging at an edge.
- **Place** activates when the piece is inside the board, avoids overlap, touches the pattern, and the previous growth animation has resolved. Press it to commit. The **Back** arrow, board-size toggle, and **+** reset are alongside it.
- Rotate clockwise with the rotation arrow or **R**, and mirror horizontally with **Flip** or **F**. Rotate after flipping for other reflected orientations. Flipping a symmetric shape leaves an equivalent shape.
- Choose green or yellow using the color swatches freely before any placement; **C** toggles colors on a keyboard. Color is no longer tied to piece shape. Your choice carries forward to the next piece. Invalid placement previews are dull gray; changing color or orientation immediately rechecks the preview. A symmetry conflict is gray but can still be physically placeable: pressing Place then ends the game.
- Two graphics at the top left summarize symmetry: a single square highlights each available vertical, horizontal, and diagonal reflection axis; a circular arrow lights when any rotational symmetry is possible. The graphics preview the hovered placement when it physically fits, and otherwise show the committed pattern. The incoming piece appears at the top right.
- **Back** retraces up to three recent placements, restores the board and chosen color, and rerolls the offered piece immediately. The reroll uses fresh randomness, excludes the outgoing offer when another shape fits, and still applies physical-fit filtering and balanced size selection. If only one shape fits, it repeats that shape. The rerolled piece starts in its default orientation.
- The **+** button starts a fresh pattern; the size button switches between 9×9 and 11×11. Both reset immediately without a dialog.
- There is no timer. Physically impossible placements are disabled. The game ends only after the player confirms a physically valid placement that breaks every remaining symmetry. A piece with no symmetry-preserving placement does not end play merely by appearing. A completely filled board ends with no new piece. Back remains available after either ending.

## Symmetry rule

The board may be asymmetric during play. For every central reflection (vertical, horizontal, both diagonals) and nonidentity square rotation (90°, 180°, 270°), cells are grouped into transformation orbits. A symmetry remains possible if no orbit contains both colors. Empty cells may be filled later. Quarter-turn checks inspect the entire four-cell orbit, including conflicts separated by empty cells. 90° and 270° have equivalent feasibility; the rotation graphic combines all three nonidentity rotations.

This prototype checks **color compatibility**, not whether every remaining gap can be filled with future whole pieces. All axes and centers are fixed to the garden's center. State is held in memory; restarting the app starts a fresh game. Positioned squares resolve into procedural flora; a snow visual theme remains a future option.

## Procedural growth

Placed cells keep their logical colors but lose their solid backgrounds. Curved vines, translucent veined leaves, four-way holding shoots, supported flowers, and stars leave the floor visible. The art uses softer sage and gold watercolor pigments while the piece controls retain clear logical colors. The palette is inverted: green networks have yellow flowers/stars; yellow networks have green accents. The stable numeric color IDs retain their original BLUE/CORAL names internally.

- **Place** starts a deterministic, frame-rate-independent growth schedule. An existing same-color side neighbor sends growth into the new piece. Every crossed center-to-center connection takes 0.14 seconds; multiple contacts launch fronts simultaneously. Four-way, star-tipped holding shoots awaken when a center is reached.
- A newly independent same-color component awakens all its centers at once. Its outward fronts meet at shared-side midpoints. Different colors and corner-only contacts never connect.
- Lines wave while extending and form smooth curved joins. Larger, paired leaves unfold root-to-tip in the direction of each growth front; opposed fronts carry opposed leaf directions. Existing directions survive later placements and Back. Small complementary stars pop off completed vines. Stems are thicker, and disconnected ends develop longer, fuller fronds toward their own cell borders, narrowing the visual gaps between separate colors without connecting them.
- Every occupied center has four delicate shoots with tiny buds/stars pointing up, down, left, and right. Unconnected directions extend farther with two pairs of larger leaves. They remain within the cell and do not create logical connections into empty or different-color neighbors.
- Every completed same-color 2×2 loop opens an eight-petal flower at its common corner. The maximum petal reach is one-third of a cell. A stem and two pairs of leaves sprout from underneath to support the flower, within the four participating corner quarters. Petals and foliage use a reusable, procedurally generated watercolor texture with directional veins.
- Horizontally/vertically neighboring flowers develop a connecting vine with popping stars. Four flowers in a 2×2 arrangement create a ring. Existing flowers and connections are preserved, with no locks or exclusive cell ownership.
- The faint placement grid is drawn as individual cell-boundary segments. A segment fades only after same-color growth crosses it. Guides around empty cells, different-color networks, and the outer edge stay visible; Back restores guides in newly cleared spaces.
- **Place remains disabled until centers, vines, flowers, and stars finish.** The next piece can still be dragged, flipped, rotated, and recolored meanwhile; its preview never participates in committed growth.
- Back, board-size changes, and reset cancel pending animation and rebuild the restored board as a settled pattern. There are no delayed callbacks that can decorate an obsolete board.

`tests/test_growth.gd` runs 100 checks covering travel times, multiple sources, independent pieces, side-midpoint meetings, corner/color isolation, loop timing, inverted palettes, flower bounds, flowering rings, preservation, resolution, cancellation, forward/reverse leaf direction, retained directions after undo, and local grid fading/restoration.

To capture a reproducible graphical preview, run `godot --path . --script tests/render_growth.gd` on a graphical display. It presses Place on a prepared board and writes 48 frames plus a settled PNG under the ignored `build/` directory. Add `-- --dense` to capture an 11×11 near-filled example with separate neighboring colors, sparse pockets, and isolated centers; those outputs use the `dense-growth` prefix. It is a development tool and is excluded from Android export.

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
godot --headless --path . --script tests/test_growth.gd
godot --headless --path . --script tests/test_ui.gd
```

The rules runner executes 691 checks covering both sizes, all eleven pieces, rotations, flips, reflection/orbit conflicts, placement constraints, color/flip rescues, game over, physical-fit filtering, balanced size frequencies, rerolls after undo, and the forced single-shape fallback. The UI runner executes 309 checks with engine-routed touch and mouse input, dragging from every occupied piece square, persistent valid/invalid hover, grab offsets, color selection, flips, the two symmetry summaries, the compact action controls, confirmed symmetry loss, undo, the Place growth gate, cancellation on Back, and non-scrolling portrait/landscape layouts from 240×320 through 844×390. On a graphical display it also writes `/tmp/tiles-godot.png`.

## Structure

- `scripts/rules.gd`: pure board, placement, and symmetry functions.
- `scripts/game.gd`: piece generation, progression, game over, and history.
- `scripts/main.gd`: native responsive controls, drag interactions, and placement gating.
- `scripts/growth.gd`: deterministic propagation, directional leaf events, and bloom schedule, separate from rendering.
- `scripts/botanical_brush.gd`: a cached, tintable watercolor brush with root-to-tip leaf veins.
- `scripts/palette.gd`: shared green/yellow network colors and dull gray invalid preview.
- `scripts/board_view.gd`, `piece_view.gd`, `floating_piece.gd`, `symmetry_icon.gd`: independent procedural renderers.
- `main.tscn`: entry scene; `export_presets.cfg`: portable Android preset.

The earlier browser proof of concept remains available in Git history at commit `1552407`; this working tree is the native Godot implementation.
