# Raised occupied ground

The board is the flat base plane: white in Vines/Labyrinth, and a pale lagoon in Coral Reef. Occupied cells share a top surface exactly **24 source pixels above it per 256px cell**. This applies to Vines, Labyrinth, and Coral Reef. The existing starting seed counts as occupied; erasing the last square leaves the whole field flat.

`occupied_platform.gd` maintains a board-size R8 occupancy texture with nearest sampling. Values depend only on occupancy, never player color. The texture updates synchronously when the board changes, including placement, Undo, Erase, and Reset. Palette changes, resizing, hovering, and growth-clock advances do not rebuild the occupancy mask.

A single board-wide ColorRect uses `occupied_platform.gdshader` beneath the ground and decoration layers. The shader supplies the flat-colored top, rounded convex outer corners, bevel and extruded sidewall. Incoming and hovering squares use this exact renderer with a one-cell mask, so thickness, corner radius, lip and shadow follow the same rules. A vertical sweep of the occupancy footprint creates exposed lower sidewalls, including steps and inward edges around holes. Occupied neighbors occlude their shared wall regardless of color. The wall gradient uses the ground family's color; Coral Reef uses an ivory matched to its six supplied textures.

A fine upper lip blends the face into the side. Coral ground sprites use the same shared geometry include to clip their exposed corners and apply that lip over the original texture. A soft offset contact shadow fades to full transparency. There is no additional background-paper image or opaque shader rectangle. The GPU distance search only visits the local 3×3 occupancy neighborhood, with exposed-edge checks that prevent internal lips on shared cell boundaries.

All ground and growth use the same top origin. The coral textures retain their six original variants and coordinate-selected rotations without baked borders or directional lighting. Vines/Labyrinth use their existing continuous top fill; their old per-cell bevels and shadows are removed. Empty-only grid segments remain visible on the base plane; occupied/shared segments disappear immediately, independent of growth.

The board inset grows slightly at larger sizes to contain the raised north edge and shadow in the board and 900px gallery capture. Hover, drag, and erase input use that same computed origin. Piece thickness also uses the exact 24/256 ratio. Floating pieces remain explicitly placed through Place, and the existing growth gate remains intact.

Gallery records identify the rounded appearance with surface revision `rounded24-v2`; Coral Reef uses `lagoon24-v3` to include its continuous water environment. Existing images are preserved, and saving an identical board with the raised appearance can create a new image instead of returning an older flat capture.

## Verification

- `tests/test_platform.gd`: empty board, color-independent merging, lower-wall depth, steps, holes, immediate board/helper changes, clock-independent masks, all three themes, and capture bounds.
- `tests/render_platform.gd`: native shader alpha/color assertions, transparent empty areas, matching isolated placed/unplaced surfaces within one 8-bit quantization level, rounded corners, wall gradient, soft shadow, shared-edge elimination, hole filling, board-edge clipping, and actual all-theme layer stacking. Writes `build/platform-<theme>.png` and `build/platform-edge-validation.png`.
- Existing gameplay, input, gallery, art, and audio runners remain regression checks. Android performance still needs device testing.

Coral Reef retains the shared thickness and rounding but reduces the upper rim, softens wall shading, and applies a shorter, lighter blue-green shadow. Its original ground textures remain unchanged. See `reef-environment.md`.
