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

Every same-color 2×2 creates a landmark, including overlapping formations:
raked sand receives the supplied stone lantern, and stepping stones receive one
of four rock formations. Rock choice is deterministic per origin. Surviving
landmarks retain their nodes, positions and stacking order as the board grows.
Undo/Erase removes only unsupported landmarks and restores ordinary motifs.
Gallery captures preserve the live stacking order. Rocks fill a two-cell square.
The lantern is half that height, with its pedestal center anchored to the 2×2
center. Its four-cell rake pattern remains visible underneath: the sand pattern
finishes first, pauses briefly, then the lantern appears above it. Rock formations
follow the same sequence: the ordinary stepping-stone pattern finishes first,
then the 2×2 rock artwork appears above it. Both underlying patterns remain in
place through the overlay animation and in saved artwork. Both types retain
their aspect ratio and screen-facing lighting.
Missing pagoda/day-night variants, ponds, trees and the
decorative Zen frame are still pending. No Clockwork or Coral art is substituted.

## Geometry and rendering

`scripts/zen_geometry.gd` uses Coral's N/E/S/W mask convention. Canonical motifs
rotate around (128,128). Every active edge has four grooves at 92/116/140/164 in
a 256-pixel cell; the last 32 pixels share an exact perpendicular cross-section.
Bends preserve groove ordering and smooth joins. T arches use monotonic cubic
curves, with stem branches merging along the outer arch tangent.

`zen_growth.gd` reuses Coral's wave timing and formation detection. `zen_visuals.gd`
renders the supplied Zen ordinary artwork and landmarks. New
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
godot --path . --script res://tests/test_zen_landmarks.gd
godot --path . --script res://tests/render_zen_game.gd
```

Checks cover mask rotations, exact edge profiles, bend and T continuity,
centerpiece progression, both types of overlapping 2×2 landmarks, helper
restoration and exact saved landmark stacking. Main-scene checks also cover
theme order, theme switching and artwork saving. Captures go to `build/zen-game/`
and `build/zen-landmarks/`. They create no extra player interface.

Godot 4.7.2 / GL Compatibility is the reference runtime. Android export and
device performance have not been validated.
