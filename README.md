# Tiles — Godot / Android

Native GDScript puzzle for **Godot 4.7.2 stable official**. Open `project.godot` in that version, then press **F6** on `main.tscn` or **F5** to play. No web server, Node.js, plugins, or external game dependencies are required.

## Play

- A small center motif in the active palette begins a 9×9 garden, switchable to 11×11. The board and every control fit on a single screen without scrolling. The board uses the full available width when space permits, and shrinks to fit shorter screens. Landscape layouts place the controls beside the board. Fitting everything on screen takes priority over earlier control positions. The interface contains no title, captions, instructions, commentary, or help dialogs.
- Eleven shapes are available: the seven standard tetrominoes, a 1×1 square (Dot), a 1×2 domino, a straight three-square piece (I3), and an L-shaped three-square piece (L3). Generation first chooses a size category uniformly, then a fitting shape uniformly within that category. While all shapes fit, each size has a 25% chance: Dot 25%, Domino 25%, I3/L3 12.5% each, and each tetromino about 3.57%. Draws are independent, so repeats can occur.
- Shapes are eligible only if some rotation or reflection fits inside empty squares and touches the existing pattern at an edge or corner. Color and symmetry are deliberately ignored for this generation filter. If a size has no fitting shapes, its probability is shared equally among the remaining sizes. A physically fitting piece that destroys symmetry in every placement can still be generated. It remains draggable; confirming a symmetry-breaking placement ends the game.
- Pieces must touch the pattern along an edge or corner. They cannot overlap or leave the board. No lines clear. If Erase removes the last occupied square, a new piece can start anywhere.
- Drag the incoming piece from the top middle onto the field. It is drawn at 150% of its previous size, including tile spacing, and adapts to rotated shapes without clipping. Grab **any occupied square**, including when picking up a floating piece again. The grabbed square stays under the finger or mouse pointer. Empty space in a piece's bounding box is not a drag handle.
- A short tap (up to 0.25 s, with a 10 px movement tolerance) rotates the piece clockwise by 90°. Dragging moves it, including after a stationary hold. A stationary long hold does nothing. Use **Flip** to mirror the shape. Touch thresholds still need Android device testing.
- Release to leave the piece hovering, whether the position is valid or invalid. Release never commits. The overlay remains visible even partly outside the board. The screen stays fixed even while dragging at an edge.
- **Place** activates when the piece fits physically and the previous growth animation has resolved. It sits at the lower right, twice the normal button height. The two color swatches and Flip stack at the lower left; Undo, Skip, and Erase occupy the middle. Above the field are symmetry/save graphics, the incoming piece, and Settings.
- Rotate clockwise by tapping a piece or pressing **R**, and mirror horizontally with **Flip** or **F**. Rotate after flipping for other reflected orientations. Flipping a symmetric shape leaves an equivalent shape.
- Choose either color of the active pair using the color swatches freely before any placement; **C** toggles colors on a keyboard. Color is no longer tied to piece shape. Your choice carries forward to the next piece. Invalid placement previews are dull gray; changing color or orientation immediately rechecks the preview. A symmetry conflict is gray but can still be physically placeable: pressing Place then ends the game.
- Two graphics at the top left summarize **committed** symmetry. Possible axes/rotations stay dim; an exact existing symmetry lights brightly. Empty spaces and colors must match, but filling the entire board is unnecessary. Hover previews never change these indicators. Tap either graphic to save a nonempty symmetric garden after its growth resolves, including after filling the final square. A check mark confirms saving.
- Each game starts with **three Undo, three Skip, and three Erase uses**. Counts are independent and never refunded by Undo. Undo retracts the latest placement and returns that exact piece, orientation, and color to your hand. It does not reroll; the set-aside next offer stays next if it still fits. At most the last three placements are retained. Erasures of older squares are preserved when undoing a placement.
- Skip replaces the current offer with another physically fitting shape, without checking symmetry. It excludes the outgoing shape if another fits; if only one shape fits, it may repeat. Skip neither changes the garden nor creates an undo entry.
- Erase arms a square selection. Tap any occupied square, including the original center, to remove it. Disconnected fragments are allowed. Empty/outside selections cost nothing; tap the helper again or press Escape to cancel for free. Undo and Erase can reopen ended gardens. Erase does not restore a whole tile.
- The Settings button opens a Vines/Labyrinth theme switch, five vine palette choices, the 9×9/11×11 size switch, Restart, and Gallery. Palette changes preserve play; changing size or restarting begins a new game with fresh helper budgets. Menus and gallery pages fit without scrolling.
- There is no timer. Physically impossible placements are disabled. Confirming a physically valid placement that breaks every remaining symmetry ends play. A completely filled board ends with no new piece; saving and the applicable helpers remain accessible.

## Raised occupied platform

All themes share a raised occupied surface **24 source pixels thick per 256px cell**. Empty space stays flat white. A board-wide occupancy shader beneath the existing textures draws exposed lower sidewalls, a fine upper lip, and a narrow contact shadow. Shared edges vanish immediately, including between different player colors. Steps and holes receive the appropriate exposed boundaries.

Ground, wall, and shadow appear as soon as placement commits. Undo/Erase update the outline immediately; plant growth runs independently on the upper face. Coral keeps all six original rotating ground textures. The shader adds no background paper. Gallery captures include the platform and preserve older images separately. See [the platform implementation notes](docs/raised-platform.md).

## Labyrinth theme

The **Garden** entry in Settings cycles **Vines → Labyrinth → Coral Reef → Vines**. Switching themes preserves the board, offered piece, helper budgets, and running growth clock. The five original palettes remain available for Vines. Labyrinth uses two fixed identities: pure green hedges and green hedges filled with rose blossoms; source pieces and color swatches match those identities. Sandy ground remains visible to both sides of the thicker shrub walls, creating the appearance of paths. The surrounding screen stays white.

The same side-connected growth schedule extends hedges between matching-color square centers. Walls occupy about 24% of a cell width, with two staggered rows of roses on the flowering shrubs. Ordinary centers grow taller, faceted pyramid hedges with broader bases (36% of a cell width). A completed same-color 2×2 loop encloses a taller tree at its shared corner. Two orthogonally neighboring trees of the same color share one existing enclosure wall. Once both trees finish rising, that common wall recedes over 0.18 seconds, followed by a 0.22-second bench rise in its place. The outer walls remain. Four trees in a 3×3 block create four such openings/benches; diagonal and different-color neighbors never create one. Place waits for the entire sequence. Undo and Erase rebuild trees, walls, and benches from the resulting board.

Paths are visual sandy spaces; there is no player character or route-solving rule. The theme changes the drawing, not the puzzle's symmetry or placement rules. Growth whispers and bell accents accompany hedges and new trees.

## Coral Reef theme — redesign v2

Select **Coral Reef** with the Garden entry in Settings. The third theme uses the supplied redesigned salmon/turquoise coral with reciprocal accent fingers and a warm anemone disc. All artwork renders at its supplied scale: the ordinary body is 77px wide on a 256px cell canvas. The earlier scaling workaround is removed.

Six porous ivory ground textures appear immediately in occupied cells. A fixed board-coordinate hash chooses variant and quarter-turn rotation; piece rotation and undo do not reroll the ground. Empty squares and the surrounding screen stay white. The theme keeps its supplied material relief above the shared raised-platform shader; the earlier per-cell bevel/shadow renderer is removed.

Same-color 2×2 loops develop body/fold/finger colony layers. **Only immediate horizontal or vertical colony neighbors join**, with one anemone per pair. A filled 4×2 area has three colonies/two anemones; a filled 3×3 has four colonies/four anemones. Diagonal and longer-distance joins are removed. The foot, oral disc, and continuous curved crown reveal in stages through the supplied geodesic fields; the crown's eight regions share one clock.

Place remains locked until the full sequence resolves. Undo/Erase preserve valid underlying coral and remove invalid features; reset cancels pending work. Gallery captures copy painter order and record reef version `2.0`, preserving older saved images while allowing the redesigned board to be saved separately.

See [the assessment](docs/coral-reef-analysis.md), [independent audit](docs/coral-reef-audit.json), and [supplied provenance](docs/coral-reef-rights.md). Runtime artwork, masks, manifest, and shader are copied unchanged from `Coral_Reef_Redesign_01.zip`. Source masters and review videos do not ship in the APK. Artwork and masks use lossless linear/clamped sampling without mipmaps, matching the validated ground seams. Device performance remains unverified, especially the 4,262-component worst-case 11×11 reef.

## Local gallery

Symmetric designs are stored as clean 900×900 PNG artwork and board/palette/theme/version JSON metadata in **`user://gallery`**. Captures omit placement guides, hovering pieces, and controls. Settings → Gallery opens the latest design with previous/next page buttons. Saves survive app restarts and game resets; saving the same board/palette/theme/version again does not duplicate it. The empty board cannot be saved. This is an app-private gallery and needs no Android photo/storage or Internet permission. It does not export to the system Photos app or resume a saved game.

## Symmetry rule

The board may be asymmetric during play. For every central reflection (vertical, horizontal, both diagonals) and nonidentity square rotation (90°, 180°, 270°), cells are grouped into transformation orbits. A symmetry remains possible if no orbit contains both colors. Empty cells may be filled later. Quarter-turn checks inspect the entire four-cell orbit, including conflicts separated by empty cells. 90° and 270° have equivalent feasibility; the rotation graphic combines all three nonidentity rotations.

This prototype checks **color compatibility**, not whether every remaining gap can be filled with future whole pieces. All axes and centers are fixed to the garden's center. State is held in memory; restarting the app starts a fresh game. Positioned squares resolve into procedural flora; a snow visual theme remains a future option.

## Palettes

The top-right two-color button opens a compact, non-scrolling list:

| Pair | Color 1 | Color 2 |
| --- | --- | --- |
| Rose / Violet (default) | `#ff3988` | `#903dff` |
| Blue / Snow | `#238bff` | `#ffffff` |
| Violet / Snow | `#aa44ff` | `#ffffff` |
| Rose / Snow | `#ff438f` | `#ffffff` |
| Blue / Rose | `#246bff` | `#ff45a0` |

Selecting a pair immediately recolors existing artwork, previews, swatches, symmetry graphics, controls, and the floor. It preserves the board's logical colors, legal moves, history, leaf directions, and in-progress growth. Snow palettes use a darker field so pure white remains visible. Clicking outside or pressing Escape closes the list; no scrolling is required. The current pair stays selected when starting a new pattern.

## Procedural growth

Placed cells keep their logical colors but lose their solid backgrounds. Curved vines, translucent veined leaves, four-way holding shoots, supported flowers, and stars leave the floor visible. Vines, petals, incoming pieces, and color controls use the same brighter, saturated palette; the watercolor brush retains translucency and vein detail. Snow-white pairs switch to a dark complementary field for contrast. Each pair is inverted between networks and accents: color 1 vines carry color 2 flowers/stars, and vice versa. The stable numeric cell IDs remain unchanged across palette selections.

- **Place** starts a deterministic, frame-rate-independent growth schedule. An existing same-color side neighbor sends growth into the new piece. Every crossed center-to-center connection takes 0.14 seconds; multiple contacts launch fronts simultaneously. Four-way, star-tipped holding shoots awaken when a center is reached.
- A newly independent same-color component awakens all its centers at once. Its outward fronts meet at shared-side midpoints. Different colors and corner-only contacts never connect.
- Lines wave while extending and form smooth curved joins. Larger, paired leaves unfold root-to-tip in the direction of each growth front; opposed fronts carry opposed leaf directions. Existing directions survive later placements and Back. Small complementary stars pop off completed vines. Stems are thicker, and disconnected ends develop longer, fuller fronds toward their own cell borders, narrowing the visual gaps between separate colors without connecting them.
- Every occupied center has four delicate shoots with tiny buds/stars pointing up, down, left, and right. Unconnected directions extend farther with two pairs of larger leaves. They remain within the cell and do not create logical connections into empty or different-color neighbors.
- Every completed same-color 2×2 loop opens an eight-petal flower at its common corner. The maximum petal reach is one-third of a cell. A stem and two pairs of leaves sprout from underneath to support the flower, within the four participating corner quarters. Petals and foliage use a reusable, procedurally generated watercolor texture with directional veins.
- Horizontally/vertically neighboring flowers develop a connecting vine with popping stars. Four flowers in a 2×2 arrangement create a ring. Existing flowers and connections are preserved, with no locks or exclusive cell ownership.
- The faint placement grid remains on empty white space. Ground and its outline replace guides adjacent to occupied cells immediately; shared filled edges never retain separation lines.
- **Place remains disabled until centers, vines, flowers, and stars finish.** The next piece can still be dragged, flipped, rotated, and recolored meanwhile; its preview never participates in committed growth.
- Back, board-size changes, and reset cancel pending animation and rebuild the restored board as a settled pattern. There are no delayed callbacks that can decorate an obsolete board.

`tests/test_growth.gd` runs 100 checks covering travel times, multiple sources, independent pieces, side-midpoint meetings, corner/color isolation, loop timing, inverted palettes, flower bounds, flowering rings, preservation, resolution, cancellation, forward/reverse leaf direction, retained directions after undo, and local grid fading/restoration.

To capture a reproducible graphical preview, run `godot --path . --script tests/render_growth.gd` on a graphical display. It presses Place on a prepared board and writes 90 frames, a sound-event schedule, and a settled PNG under the ignored `build/` directory. Add `-- --dense --palette=1` to capture the blue/snow pair, or `-- --dense` for the default rose/violet pair on an 11×11 near-filled example with separate neighboring colors, sparse pockets, and isolated centers; those outputs use the `dense-growth` prefix. It is a development tool and is excluded from Android export. To create the matching sound track, run `python3 tools/mix_growth_preview.py dense-growth`, then mux `build/dense-growth-audio.wav` with the captured frames. All preview and tool files are excluded from the APK.

## Sound and shallow depth

Vines and Labyrinth growth have a soft, original stereo foliage whisper. Each new flower produces a quiet bell note when its petals begin opening; established flowers stay silent. Five pentatonic pitches keep simultaneous blooms harmonious, with per-note rate limiting and bounded polyphony. The whisper fades out when the visual growth resolves; bell tails decay naturally without delaying Place. Back, reset, and scene exit stop active sounds. These two themes remain silent while the board is idle. Coral Reef uses the supplied looping reef ambience, three growth textures, three short colony bubbles and two long anemone bubbles. Cues follow the visual timeline, coalesce nearby feature starts and fade safely on cancellation. See [Coral audio integration](docs/coral-audio.md) for levels, routing and provenance.

`assets/audio/foliage.wav` and `flower_bell.wav` are small original PCM samples, reproducible with `python3 tools/synthesize_growth_audio.py`. They use no external assets or network service. Phone speakers/headphones still need listening validation.

The surrounding screen stays white in all palettes. The field sits directly below the header, and Place has twice the height of the other action buttons. Filled cells form one raised surface with a board-wide edge shader. Placed cells have square edges that merge without internal seams. Adjacent filled cells share one surface regardless of color; unfilled cells stay lower. Plants are drawn on the elevated surface. Incoming and hovering pieces have thicker slabs with softly rounded corners, a matching colored face, darker underside, and soft shadow. Depth changes neither legal positions nor the grid footprint, and raised rims retain correct drag hit testing.

`tests/test_sound_and_depth.gd` runs 29 checks for idle silence, growth whispers, bell timing, duplicate suppression, cancellation, audio fade races, raised surfaces, stable placement coordinates, and raised-rim dragging.

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
godot --headless --audio-driver Dummy --path . --script tests/test_sound_and_depth.gd
godot --headless --audio-driver Dummy --path . --script tests/test_coral_audio.gd
godot --headless --path . --script tests/test_ui.gd
godot --headless --path . --script tests/test_gallery.gd
godot --headless --path . --script tests/test_labyrinth.gd
godot --headless --path . --script tests/test_coral.gd
godot --headless --path . --script tests/test_platform.gd
```

The runners cover generation, symmetry orbits, placement, independent helper budgets, exact-piece Undo, non-refunding erasures, recovery from empty/finished gardens, routed touch and mouse gestures, committed symmetry indicators, the growth gate, audio, and non-scrolling portrait/landscape layouts from 240×320 through 844×390. On a graphical display `tests/test_ui.gd` also writes `/tmp/tiles-godot.png`.

Run `tests/test_gallery.gd` on a graphical display to additionally test real clean artwork capture, repeated-save deduplication, gallery navigation, and saving a 100% filled board. It writes `build/helpers-preview.png`, `build/gallery-artwork-preview.png`, and `build/gallery-browser-preview.png` for visual review. Tests use isolated temporary gallery directories and remove only their own records.
Run `tests/render_labyrinth.gd` on a graphical display to capture a real Place-driven hedge/tree/bench sequence to `build/labyrinth-frames/`, `build/labyrinth-preview.png`, and clean gallery artwork at `build/labyrinth-artwork.png`.

Run `tests/render_coral.gd` on a graphical display for the real supplied shader, Place-driven colony/anemone growth, clean gallery capture, and undo reconciliation. It writes `build/coral-frames/`, `build/coral-preview.png`, `build/coral-artwork.png`, and `build/coral-redesign-9x9.png`/`build/coral-redesign-11x11.png`.

Run `tests/render_platform.gd` on a graphical display for shader assertions and all-theme stepped/hole previews.

## Structure

- `scripts/rules.gd`: pure board, placement, and symmetry functions.
- `scripts/game.gd`: piece generation, progression, game over, history, and limited helpers.
- `scripts/coral_growth.gd`: directional multi-source reveal schedule and derived colony/shelf events.
- `scripts/coral_visuals.gd`: persistent keyed sprites, feature order, texture cache, and private active reveal materials.
- `scripts/gallery.gd`: persistent local artwork and metadata storage.
- `scripts/labyrinth_growth.gd`: shared-wall openings and bench timing after tree growth.
- `scripts/labyrinth_renderer.gd`: full green/rose shrub walls, broad pyramid centers, taller trees, and wooden benches.
- `scripts/main.gd`: native responsive controls, drag interactions, and placement gating.
- `scripts/growth.gd`: deterministic propagation, directional leaf events, and bloom schedule, separate from rendering.
- `scripts/growth_audio.gd`: synchronized foliage and flower sounds.
- `scripts/occupied_platform.gd` and `shaders/occupied_platform.gdshader`: board-wide occupancy, raised outline, lip, and transparent contact shadow.
- `scripts/tile_surface.gd`: shallow depth for draggable pieces.
- `scripts/botanical_brush.gd`: a cached, tintable watercolor brush with root-to-tip leaf veins.
- `scripts/palette.gd`: five pure color pairs, adaptive field/control colors, and dull gray invalid previews.
- `scripts/palette_choice.gd`: the palette button and pair swatches.
- `scripts/board_view.gd`, `piece_view.gd`, `floating_piece.gd`, `symmetry_icon.gd`: independent procedural renderers.
- `main.tscn`: entry scene; `export_presets.cfg`: portable Android preset.

The earlier browser proof of concept remains available in Git history at commit `1552407`; this working tree is the native Godot implementation.
