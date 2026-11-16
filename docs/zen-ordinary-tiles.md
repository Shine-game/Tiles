# Zen Garden in the game

Run the project normally with **F5** (`main.tscn`). Zen Garden is the startup
theme and the first entry in Settings → Themes. The separate ordinary-tile
preview interface has been removed. Existing controls and placement rules are
used throughout.

Implemented: full-screen sand, continuous four-UI-pixel occupied ground,
same-color rake connections, stepping stones, incoming plain sand tiles,
Undo/Erase reconciliation, the axes overlay and completed gallery saves.
The two button pigments distinguish the logical construction colors; both share
one sand material on the board. Existing themes remain available.

Bends carry one centered stone, T-junctions carry the three-stone cairn, and
crosses carry that cairn with bamboo behind it. All rotations share the same
screen-facing artwork. Source PNGs stay unchanged; a compositing shader blends
their aligned stages on one fixed canvas so the stone is drawn only once.
The center node persists when topology changes; only newly added stages fade in.
Undo/Erase restores the appropriate lower stage. The normalized canvas is 60%
of a cell, fitting the stone within the inner groove clearance.

Cells in unfinished 2×2 landmarks,
including overlapping formations, show plain sand without replacement artwork.
Ponds, trees and the decorative Zen frame have not been implemented. No Clockwork
or Coral art is substituted. The logical board still records both colors.

## Geometry and rendering

`scripts/zen_geometry.gd` uses Coral's N/E/S/W mask convention. Canonical motifs
rotate around (128,128). Every active edge has four grooves at 92/116/140/164 in
a 256-pixel cell; the last 32 pixels share an exact perpendicular cross-section.
Bends preserve groove ordering and smooth joins. T arches use monotonic cubic
curves, with stem branches merging along the outer arch tangent.

`zen_growth.gd` reuses Coral's wave timing and formation detection. `zen_visuals.gd`
renders only the available Zen ordinary artwork and plain placeholders. New
decoration fades in on the existing growth clock; the final rake reconstruction
animation is pending. Relief geometry is generated and cached, rather than
extracted from shaded reference paintings.

`zen_sand.gdshader` adapts the supplied relief lighting example, rotating normals
into screen space while keeping sand in board space. Top faces clip to the same
occupancy union as the sidewall and shadows. The ground source is unchanged;
mirrored sampling and mipmaps keep it continuous and legible. Imported PNGs and
hashes are in `art/themes/zen_garden/source-assets.json`.

## Checks

```sh
godot --headless --path . --script res://tests/test_zen_ordinary.gd
godot --headless --path . --script res://tests/test_zen_centerpieces.gd
godot --path . --script res://tests/render_zen_game.gd
```

The first verifies mask rotations, exact edge profiles, bend continuity,
T arch ordering/tangent joins and stone RGB/alpha joins. The second runs the
actual main game, including theme order, ordinary tiles, unfinished formations,
removal, theme switching and artwork saving. Captures go to `build/zen-game/`.
It creates no extra player interface.

Godot 4.7.2 / GL Compatibility is the reference runtime. Android export and
device performance have not been validated.
