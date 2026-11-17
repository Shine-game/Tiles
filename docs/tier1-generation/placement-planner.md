# Tier 1 generation — step 3: deterministic placement planner

Step 2 is published in draft PR #1. This stage adds the shared placement planner;
it does not activate it in the board or change growth event timing/rendering.

## Calling the planner

```gdscript
const Assets = preload("res://scripts/pattern/asset_library.gd")
const Themes = preload("res://scripts/pattern/theme_registry.gd")
const Planner = preload("res://scripts/pattern/sprite_planner.gd")

var planner = Planner.new() # retain per construction/board owner
var catalog = Assets.load_sprite_catalog(
    Themes.sprite_catalog_path(theme_id), "res://", theme_id)
var result = planner.plan(catalog, family_id, logical_color,
    component_id, layout_seed, {
        "origin_cells": Vector2(3.5, 4.5),
        "target_forward": Vector2.RIGHT
    })
if not result.ok:
    # Report result.errors and retain the existing construction.
    return
```

`component_id` is a stable game construction identity, not a redraw count or
animation timestamp. Catalogs must be successfully loaded by the metadata layer.
Use family `stones` and logical color 2 for Zen. Other current catalogs use
`default` and their explicit logical-color bindings. The planner has no theme-name
branches.

Optional placement context:

| Field | Meaning |
| --- | --- |
| origin_cells | Where the base's marked pivot is placed; default [0,0]. |
| size_cells | Positive source-canvas extent before rotation; default [1,1]. |
| target_forward | Required transformed native direction; omit for free orientation. |
| allowed_rotations_deg | Candidate source rotations; default [0,90,180,270]. |
| required_connections | Complete expected socket layout; see below. |
| connection_tolerance_cells | Socket-position tolerance; default 0.01 cells. |
| world_light | Lighting direction in the output coordinate frame; default shared top-left. |
| base_path | Optional canonical metadata path to pin a base variant. |

For diagonally authored bases, explicitly supply compatible allowed angles.
Current base artwork has cardinal native directions. Screen resizing should
change the host's display mapping, not the seed. If a host rotates/projects board
coordinates, it must express the screen-fixed top-left light in this planner's
output coordinate frame. This stage does not read camera/view state.

## Base transforms and physical sockets

For every eligible base, enumerate permitted source reflections and allowed
rotations. Require transformed native forward to match the requested direction.
If socket requirements are present, their count, positions and outward directions
must match the base's marked connections one-to-one before lighting is scored.
A required socket is `{offset_cells: [x,y], outward: [dx,dy]}` relative to the
component pivot, with an optional `id` to select a particular source socket.
Matching can reassign ambiguous candidates; input order does not strand a later
explicitly named socket. Requiring sockets on artwork with no marked connections
fails rather than inventing geometry.

Choose among compatible base variants using the seed, then use that base's best
lighting transform. The configured lighting tie order determines equally good
reflection choices; allowed-angle order breaks remaining ties. Geometrically
identical transformations are deduplicated. Connections always have priority,
and unsupported policies asking to relax them are diagnosed.

All source coordinates use pixel centers. Source-to-cell scale uses each actual
canvas dimension (including 255px versus 256px). The returned Transform2D maps
source pixels directly into component/board cell coordinates and fixes the marked
pivot at origin_cells. Downstream rendering must apply this complete matrix,
including reflections, rather than independently flipping texture UVs and leaving
anchors untransformed.

## Anchor and decoration decisions

Stable per-purpose random streams derive from planner version, layout seed,
component identity, anchor identity and metadata identity. They do not use the
global RNG or depend on another component's construction order. Base/catalog and
anchor lists are canonically ordered before seeded choices. Each artwork's
selection weight is applied once, before choosing its mirrored form.

Sample the inclusive target count, shuffle anchors without replacement, and
choose weighted compatible decorations at each sufficiently spaced anchor. An
empty accepts list admits nothing; an omitted list admits any entry in the
supplied catalog. Retry compatible artwork candidates in a seeded weighted order
before abandoning an anchor. There is at most one decoration per anchor.

For every candidate, resolve the metadata layer's animation/orientation/variation
and restrictive constraints. Sample scale, angle/jitter and allowed independent
reflection. Relative/perpendicular/fixed modes compensate for the *reflected*
native direction; random mode samples the actual sprite rotation in its range.
Attachment remains fixed. A decoration with lighting chooses its best valid form;
otherwise reflection order is seeded and uniform among valid forms. Compose the
entire base transform last, so both base-driven and independent decoration
mirrors affect attachment, direction and later reveal coordinates consistently.

The result is a reproducible layout, not a new texture. No duplicate mirrored PNG
files or doubled catalog weights are created. Negative scale is internal matrix
composition, not an authored variation range.

## Footprint checks

`sprite_footprint.gd` rasterizes actual occupied source pixels using the loader's
alpha > 0.01 bitmaps. Every transformed pixel square contributes conservative
coverage; transparent padding is excluded. Radius measures transformed visible
pixel corners from the attachment. Checks occur in base-source pixels before
world placement:

- minimum distance between accepted attachment points;
- visible radius and tile edge margin;
- required attachment on occupied base alpha;
- collision with the selected base's actual alpha and Euclidean pixel-square gap;
- overlap with prior decorations when either participant requires separation.

The exact minimum gap is allowed; smaller gaps are rejected. Conservative
rasterization can reject an otherwise close-fitting rotated shape. Rules are
never weakened to reach the requested count. A shortfall is a successful partial
plan with a warning and aggregated rejection reasons, not an invalid base.

Footprint work is bounded to an estimated one million covered cells per candidate.
Unreasonably large/non-finite transforms are diagnosed as rejected candidates.
This protects generation from malformed extreme scale inputs. Tiny direct-placement
textures are allowed. Source-vector precision and count/RNG limits are validated
by the metadata layer. Runtime StringName dictionary keys produced by GDScript
property assignment are accepted as object keys alongside JSON string keys.

## Result and lifecycle

`result.base` includes metadata/image paths, selected color, actual canvas,
marked origin, full source-to-cell `transform`, rotation, reflection flags and
lighting score. Each decoration has:

- a stable component/anchor ID and source metadata/image identity;
- `local_transform` from its source image into the base's source frame;
- `transform` composed through the full base placement;
- attachment, angle, scale, independent reflection flags and light score;
- source footprint/radius, growth_at and resolved animation/constraint rules;
- a selected reveal asset descriptor for progressive artwork.

The planner does not assign activation times. Step 4 will use growth_at against
actual forward/reverse/multi-front growth events and retain the full decoration
duration. Step 5 will consume the matrices and reveal descriptors in the existing
component renderer. Source reveal masks follow the same full transform as their
artwork.

Decorations are ordered by growth threshold then anchor ID for stable overlay
painting. `fingerprint` identifies local artwork/variation choices, excluding
translation/display scale; `planner_version` permits future versioned layout
migrations. Save the seed and stable component IDs when persistence is integrated.
Reconciliation should retain surviving plans rather than creating new identities.

Plans are copied on return. Retain the planner to reuse its bounded caches (512
plans, 128 transformed footprints); source occupancy resources are reused.
`forget(component_id)` releases that construction's plan entries; `clear()` also
releases the planner's geometry caches. Metadata caches have their own explicit
invalidation. Deterministic regeneration survives cache eviction. Changes to
source art in an editor require texture reimport and cache invalidation.

## Verification

`tests/test_sprite_planner.gd` exercises all four production catalogs and colors
through quarter-turns; fixed attachment alignment; source geometry and lighting
priority; ambiguous and impossible sockets; seeded stability, ordering, translation
and scale; independent mirrors and decoration lighting; weighted selection;
orientation rules; radius/spacing/tile/alpha/overlap/gap constraints; diagnostics
and cache isolation. It also runs against a resource pack from an empty project
directory. Validation totals and engine limitations are in planner-validation.json.

The [growth timing bridge](growth-timing.md) now binds these layouts to structural waves. Live renderer/board activation remains the next stage.

## Optional anchor group counts

A base can reserve an exact number of decorations on a named subset of anchors.
For example, coral keeps its total count at 4–6 while reserving two on the spine:

```json
"spawn": {
  "count": [4, 6],
  "minimum_spacing_px": 20,
  "group_counts": {"spine": 2}
}
```

The six existing central anchors A02, A05, A08, A11, A14 and A17 carry
`"group": "spine"`. Their positions are [125,116], [125,96], [125,76],
[126,56], [125,36] and [125,16]. Their orientation is `relative`, angle 0,
jitter 0, so their native growth directions align exactly with the stem. The
remaining twelve anchors retain perpendicular growth with ±10° variation.
Both coral color sidecars contain the same settings and coordinates.

`spawn.group_counts` is optional and belongs only on a base. Values are
nonnegative integers; their sum must fit the minimum total count, and each
reservation must have enough authored anchors. The planner considers reserved
groups first, in sorted group-name order, with seeded anchor selection within
each group. It then fills the remaining total from anchors outside the reserved
groups. A zero quota excludes that group. An anchor group without a declared
quota remains eligible for ordinary selection. One decoration per anchor still
applies. Spacing, attachment, alpha and overlap constraints remain in force;
infeasible groups report shortfalls rather than bypassing constraints.

Plans with reservations return the actual `group_counts`; grouped decorations
carry `anchor_group`. Bases that omit quotas keep their existing selection order.
The rule is universal and contains no coral-specific planner logic.

Vines use `spawn.group_count_ranges: {"upper":[5,6], "lower":[5,6]}`
for independently seeded per-side counts. Fixed and ranged quotas cannot share a
name. Range minima must fit the minimum total and maxima must fit the maximum.
When all anchors belong to ranged groups, the total is the sum of the sampled
group counts. Vines retain ten candidate anchors on each side; spacing is zero
so these requested counts are available on the existing closely spaced pairs.

Optional `variation.growth_scale: [width, length]` stretches decoration geometry
across and along its marked native growth axis, about its attachment point,
before orientation. Vines use `[2,1.5]` on both colors, retaining the existing
random uniform size factor. The complete matrix also carries masks and alpha
checks. Upper leaves angle 0–30 degrees clockwise from outward perpendicular;
lower leaves angle 0–30 degrees counterclockwise, so both lean toward native
stem growth without leaning backward.
