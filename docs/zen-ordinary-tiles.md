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

Ordinary stepping stones are drawn at 70% scale. Each directional half scales
around its shared edge midpoint, preserving exact contact and matching profiles
with its neighboring half. Isolated stepping stones scale around their center.

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
Third-tier stone paths now flood when neighboring same-color 2×2 origins are
one cell apart, using the existing Coral formation-adjacency rule. Each connection
activates the facing watershed on both rock formations: a 3-row × 2-column
structure fills the upper south and lower north triangles; a 2-row × 3-column
structure fills the left east and right west triangles. Because these 2×2s overlap,
the masks are fitted at half depth on the connection axis, anchored at each
formation center. Their bases meet exactly halfway between centers, in the middle
of the shared row/column. They do not flood the exterior sides of the join. New rocks finish appearing
before the water fills inward from the connecting side; two sparse shoreline plant
groups per activated side grow afterward. Further connections add sectors while
existing water and plants remain visible and existing rocks retain their nodes,
positions and stacking order. Undo/Erase removes unsupported sectors and plants.

All four supplied `water_n/e/s/w` sets and `rock_occlusion` masks are used unchanged,
without source image edits, per the user's confirmation. The water masks receive
the shared-base runtime placement described above; exposed-rock protection stays
registered to the existing rock artwork. Water deliberately
covers low bedrock and portions of rock faces; the occlusion masks protect the
middle and selected exposed rocks. A shared offscreen mask combines active sectors
and protects all rock middles, so overlapping 2×2s share one board-space blue-grey
water surface rather than painting water over each other's peaks. Only the mask is
downsampled at runtime to 128 pixels per cell; source PNGs are untouched. Static
reflections preserve exact appearance in gallery captures. Mask rendering updates
on changes/growth, then stops. Empty ponds use a minimal 2×2 render target.
Each flooded triangle has one supplied shrub strip along each sloping lateral;
the shared base remains clear, including the full shrub sprite bounds. The supplied
unoccluded watershed outlines (02–04), or the original water boundary (01), locate
these laterals without confusing them with the central exposed-rock shoreline.
Shrub designs are randomly chosen from all six supplied plants on first creation.
Choices persist through growth and Undo/Erase reconstruction, reroll on a new game,
and are copied from the live board into the gallery capture. Plants use a fixed painter order so gallery
reconstruction matches the live board. Theme version 0.9 gives these saves a new
appearance identity without replacing older pictures. The active shrub choices
also contribute to the save identity; repeated saves of the same appearance still
deduplicate, while different random arrangements can be saved separately.

Raked third-tier clusters use the same 2×3 eligibility rule. Their centroid is the
mean of their unique supporting cell centers, not a count weighted by overlapping
2×2 formations. A small top-down woody trunk hub grows there, followed by sparse
supplied branch artwork revealing outward from its attachment point. The underlying
rake patterns and lanterns remain in place.

On expansion, the existing trunk is deleted. A thicker trunk grows at the
recalculated centroid while every established branch retains its node, artwork,
position, rotation and scale. Two or three larger branches grow from the new hub
toward the previous trunk position, with a slight angular spread; they do not try
to join the old geometry exactly. Further branches grow toward newly eligible
territory. Independent groves keep independent trees. Merging groves preserve both
sets of branches, replace both hubs with one new trunk, and grow transition limbs
toward the former centers. A topology-history cache restores the original canopy
and trunk through Undo; Erase removes unsupported branches/trees. Finished trunk
and branch animations become settled layers immediately; restarting the board
clock for an unrelated placement cannot hide or replay those completed layers.

Each new game snapshots the local month once: March–May sakura, June–August green
maple, September–November red maple, December–February bare branches with patchy
snow. Existing supplied source PNGs stay unchanged. Runtime atlas regions and
attachment pivots select usable individual branches and winter sheet regions;
a shader rejects semi-transparent sheet haze/fringes. The problematic short sakura
master is not used. Branches are clipped to rake territory, remain sparse, and use
lengths of roughly 0.35–1.5 cells. The trunk is a small procedural woody hub; no
upright tree or replacement interface is introduced. Historical branch geometry
and the frozen season are copied into gallery captures and included in the save
appearance identity (Zen version 0.9).

Missing pagoda/day-night variants and the decorative Zen frame remain pending. No Clockwork or Coral art is substituted.

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
godot --path . --script res://tests/test_zen_ponds.gd
godot --path . --script res://tests/test_zen_trees.gd
godot --path . --script res://tests/render_zen_game.gd
```

Checks cover mask rotations, exact edge profiles, bend and T continuity,
centerpiece progression, both types of overlapping 2×2 landmarks, helper
restoration and exact saved landmark stacking. Pond checks cover connection
eligibility, cumulative growth, protected dry-rock masks, actual Place/Undo/Erase
and water in saved artwork. Tree checks cover unique-cell centroids, fixed branch
transforms, trunk replacement/thickening, transition limbs, independent and merged
groves, Undo/Erase, seasonal snapshots and exact saved pixels in all four seasons.
Main-scene checks also cover
theme order, theme switching and artwork saving. Captures go to `build/zen-game/`,
`build/zen-landmarks/`, `build/zen-ponds/` and `build/zen-trees/`. They create no extra player interface.

Godot 4.7.2 / GL Compatibility is the reference runtime. Android export and
device performance have not been validated.
