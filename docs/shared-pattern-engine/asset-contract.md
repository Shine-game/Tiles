# Proposed shared asset-set contract

Semantic contract defined in Step 1. The common loading/rendering subset is now
implemented in Step 4; see [the runtime format and example](assets-and-rendering.md).
Clockwork ordinary role/treatment mappings are now live in
[Step 5](clockwork-ordinary-sets.md). The remaining theme/role model below is the migration target; supplied legacy
manifests are unchanged and consumed through explicit adapters. See
[the inventory](theme-inventory.md) for what is available today and what still
needs a migration decision.

## 1. Theme and set hierarchy

A theme definition contains:

| Entry | Responsibility |
| --- | --- |
| Identity | Stable runtime theme ID, contract version, appearance version and title |
| Logical treatments | Map board values 1/2 to artwork variants; accents do not change connectivity |
| Tier 0 set | Isolated-cell composition and growth |
| Tier 1 set | Vines/connections, endpoint/bend/T/cross centerpieces, optional straight-run decoration |
| Tier 2 set | 2×2 formation composition, masks and growth dependencies |
| Tier 3 set | Project-owned behavior ID, referenced compositions/masks and behavior parameters |
| Environment | Full-screen background, empty ground, occupied ground and preview surface |
| UI appearance | Palette, button states, icons, board/menu frame and gallery appearance |
| Integration hooks | Registered motion/audio/effect hooks; ownership remains with the game |

Each logical treatment can select a different set: Zen's rakes and stepping
stones share a theme but have different Tier 1–3 compositions and behaviors.
Multiple roles can reference the same asset without copying the file. A set is
one cohesive description of a tier, not necessarily one image.

A resource slot explicitly declares `available`, `missing`, or `unused`.
A missing optional decoration draws nothing; missing artwork is never silently
borrowed from another theme. Existing procedural artwork counts as available
through a registered provider. The occupied ground can still render when a
feature's artwork is missing. Required missing fields/resources must produce
useful validation diagnostics before enabling a migrated set.

## 2. Shared topology

Connectivity is orthogonal contact between occupied cells of the same logical
color. Diagonal contacts and opposite colors do not create pattern connections.
This does not change the game's more permissive placement-contact rules.

Use one bit convention everywhere: N=1, E=2, S=4, W=8, with Y increasing downward.
Positive quarter turns are clockwise. Each occupied cell has exactly one classification:

| Shape | Masks | Target Tier 0/1 rule |
| --- | --- | --- |
| Isolated | 0 | Tier 0; no connecting vines |
| Endpoint | 1, 2, 4, 8 | One vine port and a centerpiece |
| Straight | 5, 10 | Two opposite ports, no centerpiece; eligible for straight-run decoration |
| Bend | 3, 6, 9, 12 | Two adjacent ports and the bend centerpiece |
| T | 7, 11, 13, 14 | Three ports and the T centerpiece |
| Cross | 15 | Four ports and the cross centerpiece |

Endpoint → straight removes only the no-longer-valid centerpiece. Straight →
bend/T/cross introduces its configured centerpiece. Surviving vines and other
parts retain their state. Distinct bend/T/cross roles can share the same assembly,
as Clockwork currently does, or add stages, as Zen's stone/cairn/bamboo does.

Every same-color 2×2 is eligible for Tier 2, including overlapping formations.
Identify it by its top-left cell. Two formations connect when their origins differ
by one orthogonal cell and their colors match. Thus a 2-row × 3-column or
3-row × 2-column occupied rectangle already triggers Tier 3. A long thin path
between distant formations does not itself create that formation connection.

Expose the formation graph and its connected components. A Tier 3 behavior can
consume each connection (chains/ponds) or a connected territory (Zen trees).
Territory centroids count each supporting cell once, not once per overlapping
formation. Boundary positions, shared bases and parent relationships come from
this geometry, never from sampling artwork colors.

## 3. Compositions, assets and placement

A set contains named compositions made of parts. A part declares:

- A local part ID and semantic role: centerpiece, vine, boundary join, decoration,
  landmark body, overlay, or behavior-specific detail.
- A provider: texture, texture-atlas region, or registered procedural provider.
  Configuration selects project-owned provider IDs; arbitrary supplied code is
  not automatically executed.
- Artwork/treatment references, source dimensions, optional atlas region,
  source-pixel pivot and attachment anchors.
- Placement anchor, display size in cell units, orientation policy, layer and
  feature owner. Texture bounds and logical support are separate fields.
- Reveal/composition rules, dependencies, optional masks and variant policy.

The common placement model uses cell units. One cell spans [0,1]², with center
(0.5,0.5) and ports N=(0.5,0), E=(1,0.5), S=(0.5,1), W=(0,0.5).
A formation at origin (x,y) has center (x+1,y+1). Existing 256-pixel calculations
can be adapted internally; a 1254-pixel master does not need destructive resizing.
Explicitly label source pixels, cell units, seconds and angles so they cannot be
confused. An atlas pivot is relative to its selected region, not the whole sheet.

Orientation policies include fixed/screen-facing, topology quarter turns and
behavior-controlled rotation. A component can supply one canonical asset or
explicit directional assets. Do not rotate asymmetric stepping-stone halves as
though they were identical. Preserve existing tube flips and materials while
shading work is deferred. Animation-driven spinning is separate from placement
orientation.

Parts can anchor to a cell center, directional port, shared edge midpoint,
formation center, connection or behavior-defined point. The lantern's pedestal
pivot and the endpoint of a branch are examples of explicit attachment anchors.

A semantic Tier 1 vine need not be a straight half-sprite. Zen's procedural rake
provider can emit a complete topology-specific motif while still using the shared
classification, ports, state and dependencies. Shared logic must not require
replacing generated geometry with painted tiles.

## 4. Layering and ownership

Tiers describe eligibility, not mutually exclusive pictures. A higher-tier
composition declares, for each affected lower role, whether to keep it, add over
it, hide it, or replace it. Removal restores lower roles when still supported.
Avoid an implicit rule that entering Tier 2 deletes all Tier 1 artwork.

Keep each multipart formation together in the painter order. Surviving formations
retain their established stacking order; newly added overlapping formations do
not cause existing ones to reshuffle. Shared overlays can combine masks across
features where necessary, as Zen ponds do. The field-axes overlay remains above
all artwork and absent from saves.

Identity ownership examples:

| Owner | Stable identity |
| --- | --- |
| Cell part | Theme/set, logical color, cell and local part role |
| Directional vine | Cell owner plus direction |
| Boundary join | Canonical unordered same-color neighboring-cell pair |
| Straight-run decoration | Fixed anchor plus decoration role; not a changing run length |
| Tier 2 formation | Logical color and top-left origin |
| Tier 3 pair feature | Canonical unordered formation pair and behavior role |
| Historical branch/trunk | Persisted behavior identity and explicit support membership |

A shape change must not blindly replace every cell part. A centroid is a placement
value, not the identity of a whole tree; moving a trunk must not move its branches.
Stable IDs must not depend on dictionary iteration order, node instance IDs or
frame time. Connected-component merges/splits require an explicit behavior policy,
not a newly sorted component index used as identity.

## 5. Mask semantics — shading deferred

Every mask reference declares purpose, channel, encoding, zero/one meaning,
source/atlas registration, transform and combination rule. Absence means a named
fallback such as whole-part fade, not an inferred grayscale interpretation.

| Purpose | Meaning to declare |
| --- | --- |
| Reveal field | Spatial arrival order, zero/one endpoints, forward/reversible and multiple-front behavior |
| Region activation | Pixels belonging to a named connection sector, plus activation trigger |
| Protection/occlusion | Exposed pixels excluded from an overlay; applied before or after combining regions |
| Coverage | Allowed visual footprint, including clipping to logical territory |
| Placement guide | Data for locating decorations; not automatically rendered or used as flood coverage |

Artwork alpha supplies its own coverage. Binary coverage is not interchangeable
with a gradient reveal field. Declare whether protection is already included in
a water mask, and whether an additional composed protection pass is required;
never apply an unknown mask twice by convention. Declare union/max, alpha union,
subtraction or another reviewed combination explicitly.

Do not infer directional mask names from arbitrary image rotation. Coral currently
has shared canonical arm/junction artwork but not identical mask reuse for every
junction. Adapters must preserve the exact artwork-and-mask pairing.

Zen's unchanged supplied water sectors are fitted at half depth along the
connection axis around their formation centers. For vertically overlapping 2×2s,
the upper south and lower north bases meet at the middle of their shared row;
for horizontal ones, left east and right west meet in the shared column. Protection
remains registered to the rock artwork. This placement belongs to the pond behavior,
not a universal transform for every Tier 3 composition.

No neutral-color conversion, new shading maps, light-direction system or lighting
shader replacement is authorized here. Preserve existing shading as-is. A future
material contract can be approved separately without changing these mask meanings.

## 6. Growth, motion and restoration

Parts refer to shared semantic events: cell reached, port reached, edge connected,
part complete, formation ready and formation connection ready. Dependencies name
an owner/part/event, optional field threshold and delay. Timing can differ by set;
do not make Clockwork pressure propagation or Zen's pattern-before-landmark order
universal constants.

The common lifecycle is appearing → settled → retiring/removed. Once settled, a
part cannot become hidden because the next placement starts a clock at zero.
Track placement/growth ownership separately from continuous motion. Wheels and
chains may keep running after construction; that operation must not keep Place
locked. Only genuine new/retiring construction contributes to the gate duration.

Retain surviving components, transforms, painter order, chosen variants and motion
phases. Undo/Erase removes unsupported parts and restores required lower roles;
a theme can configure an existing retirement animation without changing the
logical helper result. Reset cancels pending work and clears game-owned history.

A theme supplies explicit policies for live growth, settled entry, layout refresh,
Undo/Erase, reset, theme changes, pause, disposal and capture. These are distinct
operations; do not interpret every redraw as a new game or completed animation.

Random choices are either stable by declared anchor/seed or sampled once and
persisted. Gallery capture copies actual live choices, historical branch geometry,
season, painter order and motion phase; it does not invent a fresh canonical tree.
Appearance fingerprints include visible variation, not removed cached components.
Existing gallery PNGs remain readable; this document does not add game resume.

## 7. Straight-run decoration

A straight run consists of consecutive same-color straight cells on one axis,
bounded by endpoints, turns, branches, color changes or the board boundary.
Decorations belong to eligible run positions without centerpieces.

The proposed policy fields are minimum run length, spacing, stable anchor/phase,
variant selection, footprint clearance and interactions with higher-tier artwork.
Use fixed cell/edge anchors so extending a run does not recenter existing decoration.
Classify decorations by role: an obligatory tube boundary coupling is not the same
thing as optional decoration for an otherwise empty straight run.

No shared numeric minimum or spacing has been approved yet. Dedicated artwork is
also not declared for every theme. Step 6 must present those choices; this step
does not arbitrarily assign an interval or repurpose existing art.

## 8. Environment and UI set

A theme references full-screen background, empty and occupied ground, preview
surface, board/menu frame, palette and control-state styling. Shared UI layout and
input stay outside the pattern engine. Buttons keep their agreed tinted outlines;
do not introduce decorative frames around every button. Missing board-frame art
remains explicitly missing, with the current fallback preserved.

Audio/motion hooks stay project-owned and observe the existing sound toggles.
They are not embedded imperative instructions in an artwork manifest.

## 9. Validation required during later steps

Check all 16 connection masks and rotations, same/opposite colors, edge ports,
endpoint-to-straight removal and reverse promotion, unsupported assets, stable
straight-run anchors, overlapping formations, both 2×3 orientations, layering,
multiple growth fronts, unrelated short placements, helper restoration, reset,
scene pause/theme switches and saved appearance. Use the actual game for native
renders, including 9×9 and 11×11; no additional player preview interface.

An adapter must distinguish current behavior from the target behavior before it
is enabled. Missing role assignments are migration work, not evidence of missing
files. See the per-theme inventory and the separate approval checkpoints.
