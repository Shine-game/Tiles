# Canonical orientation in the basic assembly

Directional instances now share the common
[`assembly.gd`](../../scripts/pattern/assembly.gd) transformations. A family needs
one source artwork per treatment and canonical shape, not four compass copies.
Masks in source-image coordinates follow the sprite rotation automatically.

## Common operations

- `rotation(spec)` reads the existing quarter-turn/radian placement convention.
  The shared component renderer uses it for both sprites and registered nodes.
- `rotated(part, turns, pivot_cells)` copies a part and rotates its position and
  orientation around a pivot (default: local cell center). Pixel positions and
  connection requirements rotate too. Source pivots/offsets remain local: the
  sprite transforms them once, together with its artwork and shader UVs.
- `on_port(part, cell, direction)` instances canonical center/edge artwork using
  `canonical_port` and `anchor`. Shared-edge offsets scale around the seam, not
  around an arbitrary canvas corner. `flip_h_ports` / `flip_v_ports` can explicitly
  preserve tangential border matching for asymmetric painted modules.
- Quarter-turn position arithmetic uses exact coordinate swaps/sign changes,
  avoiding cumulative drift. Callers with world-space positions supply their cell
  center as the rotation pivot.

A mask may still declare an explicit UV transform when its actual data needs it.
Canonical Coral fields now use zero compensation: artwork and field rotate together.
No additional source images, baked rotated copies or lighting algorithm are needed.

The built-in `linear_reveal` asset descriptor creates a cached 8-bit projection
field from `size_px`, `zero_px` and `one_px`, sampled at pixel centers. It rejects
invalid sizes and coincident endpoints. Coral uses `[128,128]` to `[128,0]` on a
256-pixel canvas, replacing its deleted ordinary arm mask with the exact visible
field. Junctions load the retained `junction_ne.png` mask in every direction.

## All-theme audit

| Theme/family | Direction source after correction |
| --- | --- |
| Coral arms | One `arm_n.png` per color; one generated canonical reveal field |
| Coral junctions | One `junction_ne.png` per color; one retained NE mask |
| Clockwork ordinary tubes/couplings | Existing canonical T01/T03 images per metal; shared rotation; T01's one east-facing field |
| Zen stepping-stone paths | One `half_stone_N_256.png`; shared edge placement, rotation and declared S/W tangential mirroring |
| Zen rake shapes | One procedural geometry/relief per canonical topology shape; shared rotation to all orientations |
| Vines | One procedural curve/foliage implementation follows the connection direction; no compass sprite pack |

Clockwork pressure/motion hooks and its existing straight-tube shading flips remain.
Zen's old four stone paintings differed internally, so E/S/W now deliberately reuse
the N painting. Opposing halves mirror the local tangent to preserve identical
border alpha and visible color at the shared seam. Their 70% scale is unchanged.
Rake center art, lanterns and rock peaks remain screen-facing as before.

Directional names do not always mean redundant art. Zen pond N/E/S/W masks select
different regions of asymmetrical rocks and protect distinct peaks; they remain
separate coverage data. Tree/season/rock variants and separate mechanism parts are
also different content, not compass copies. This change does not collapse those
masks/variants or migrate higher-tier policies.

Labyrinth was subsequently removed from the game; it is no longer an active
theme or a pending artwork migration.

## Cleanup and appearance

See [Coral's cleanup list](../coral-arm-assets.md). Zen no longer loads
`artwork/stone_paths/half_stone_E_256.png`, `half_stone_S_256.png` or
`half_stone_W_256.png`; their matching import files may also be removed. Retain N.
Original source-package hashes are historical provenance and are not edited.

The Coral appearance revision is `2.2` (canonical junction growth field), and Zen
is `0.11` (canonical stone paintings). Existing saved artwork remains readable.
Shading work stays deferred.

## Verification

`test_pattern_assembly.gd` checks source sharing, inverse transforms, pivot/offset
handling, shared-edge anchors, mirrors, canonical field pixels/cache/validation,
and Coral canonical arm/junction references. Updated native arm/junction checks
compare runtime rotation against rotated canonical references at three phases.
Zen's ordinary checks compare rotated/mirrored source edges and every transformed
border point; its endpoint and game tests exercise real placement and captures.

An isolated clean project is also imported and tested after removing all 22
obsolete ordinary Coral art/mask and Zen E/S/W path files. This reproduces the
owner's missing-file setup without relying on leftover imported textures.
