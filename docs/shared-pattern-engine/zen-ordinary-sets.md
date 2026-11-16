# Step 6 — Zen Garden ordinary sets and endpoint copies

Zen now loads separate Tier 0/1 sets for rakes and stepping stones through the
common asset library and shape selector. The endpoint mapping follows the user's
revision: reuse the Tier 0 core underneath an overlapping rake/path ending, with
an independently named source file for that endpoint core.

## Endpoint artwork

| Endpoint file | Copied from |
| --- | --- |
| `artwork/centers/raked_sand_endpoint_relief_256.res` | `artwork/cores/raked_sand_core_relief_256.res` |
| `artwork/centers/stepping_stone_endpoint_core_256.png` | `artwork/cores/stepping_stone_core_256.png` |

Paths are relative to `art/themes/zen_garden/`. The stone PNG is a byte-for-byte
copy. The rake core previously existed only as `ZenGeometry.height_image(0)`.
That exact floating-point relief is now saved as a Godot `ImageTexture` resource,
then copied to the endpoint resource. Its pixels match every original float;
no baked shading or lower-precision conversion was introduced. Both endpoint
files can now be replaced independently of the isolated artwork.

The rake overlap provider combines the copied core's grooves and the existing
north-facing endpoint grooves into one relief texture, then uses the same
canonical rotations and sand shader. Two opaque sand sprites would conceal one
another, so the provider combines their height fields before rendering. The
existing 32-pixel shared-edge profile is retained exactly in every rotation.
This changes endpoint geometry, not the shading algorithm. The stone endpoint
renders its copied core first, with the directional half-stone above it. Its
70% scale and shared-boundary anchor are unchanged.

The [canonical assembly correction](canonical-assembly.md) uses only the north
stone-path image with rotations and seam-preserving mirrors. Current version: `0.11`.

## Runtime sets

- [Rakes Tier 0](../../art/themes/zen_garden/sets/rakes-tier0.json): isolated relief.
- [Rakes Tier 1](../../art/themes/zen_garden/sets/rakes-tier1.json): endpoint overlap,
  procedural vines and existing flat-stone/cairn/bamboo stages on bends/Ts/crosses.
- [Stones Tier 0](../../art/themes/zen_garden/sets/stones-tier0.json): original core.
- [Stones Tier 1](../../art/themes/zen_garden/sets/stones-tier1.json): copied endpoint
  core and one canonical north-facing half-stone image.

[`zen_sets.gd`](../../scripts/zen_sets.gd) binds these families to logical colors
1/2. `PatternCellSets` selects shape roles and supplies shared anchors. The common
renderer creates ordinary sprites and owns persistent staged rake center nodes;
Zen retains its ordinary arrival fade and fixed-canvas stage addition hook.
The compatibility `stone_sprite()` entry point now reads the same live sets.

Straights keep their paths without a centerpiece. Endpoint-to-straight growth
removes the endpoint core; Undo/Erase restores it. No bend stone was added at
rake endpoints. Stepping-stone bend/T/cross center assignments remain explicitly
unused pending a separate assignment; their existing path modules still draw.
No long-run decoration was assigned. These declarations do not invent artwork.

Landmarks, pond sectors/shrub choices, seasonal historical trees, ground, UI,
existing shaders and logical placement rules retain their existing behavior.
Higher-tier rake-center suppression and persistent center promotion remain.
The appearance version is now `0.11` so new saves are distinct from older Zen
artwork. Existing gallery PNGs remain readable. Export includes all four JSON sets
and the recognized texture resources. Original uploaded assets are untouched.

## Verification

`test_zen_sets.gd` covers both live families, all 16 masks, independent source
copies, exact floating-point relief, endpoint overlaps, every rotated edge,
layer order, boundary anchors, endpoint removal/restoration, shared arrival fades,
common ownership/reset and export/version declarations. Existing Zen ordinary,
centerpiece, landmark, pond, tree, UI and shared asset/state suites pass.

Real-board native comparisons cover three growth phases for all shapes and both
families. All 72 non-endpoint cell captures match the pre-migration pixels;
endpoints are the intended visible change. Native main-game checks cover both
board sizes, theme switching, helpers and saved artwork. No new preview UI was
introduced.
