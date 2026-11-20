# Existing themes mapped to the proposed sets

This is the historical Step 1 inventory. For current directional sources and
cleanup instructions, see [canonical assembly](canonical-assembly.md). Labyrinth
was subsequently removed; its source links below refer to Git history.

Inspected runtime source and manifests at `951568f`. This is an implementation
inventory, not a certification of artwork quality, complete shading maps or phone
performance. The mappings below describe available resources; no new manifest is
loaded and no behavior is changed by this document.

## Overview

| Theme/runtime ID | Logical treatments | Current Tier 0/1 | Tier 2 | Tier 3 | Target centerpiece rule today |
| --- | --- | --- | --- | --- | --- |
| `clockwork` | Copper/gunmetal with alternating accent layers | Multipart wheels, tube halves and shared couplings | Stacked mechanism | Chains and topology-selected caps | Implemented: endpoint/bend/T/cross retain wheels, straights omit them |
| `zen_garden` | Raked sand / stepping stones on common sand | Procedural rakes plus stone/cairn/bamboo; directional stone halves | Lanterns / four rock designs | Historical seasonal trees / connected ponds and shrubs | Partial: rake bends/T/cross have stages; endpoints have no centerpiece; stone paths lack explicit shape-center roles |
| `coral_reef` | Salmon/turquoise | Core on every cell, canonical arms, corner junction pieces | Multipart colony | Multipart anemone per adjacent colony pair | Not yet: straight cores remain; junction assemblies need role mapping |
| `vines` | Two logical pigments, five selectable palette pairs | Procedural holding fronds, curves, leaves and stars | Procedural flower | Flower-to-flower vine and stars | Not yet: holding motifs are drawn on all occupied cells |
| `labyrinth` | Two logical pigments on sand | Procedural center pyramids and hedge connections | Procedural tree | Shared wall opening and bench | Not yet: center pyramids are drawn on all occupied cells |

All themes use the same logical game board. Vines' palette variants are not extra
logical colors. Zen's sand surface does not erase its distinction between colors
1 and 2. Existing full-screen/ground rendering is separate from these tier roles.

## Clockwork — first Tier 0/1 migration candidate

Sources: [`theme.json`](https://github.com/Shine-game/Tiles/blob/951568f/art/themes/clockwork_workshop/theme.json),
[`clockwork_growth.gd`](../../scripts/clockwork_growth.gd),
[`clockwork_visuals.gd`](../../scripts/clockwork_visuals.gd),
[implementation notes](../clockwork-workshop.md).
Runtime ID `clockwork` differs from directory `clockwork_workshop` and manifest ID
`clockwork-workshop`; the adapter must declare that mapping, not rename files.
Runtime appearance version is 1.1; the supplied manifest's version/status strings
are source-package metadata, not the current runtime verification status.

- **Tier 0:** `C01` socket/rim + `C02` wheel + `C03` axle cap. No tubes.
- **Tier 1 centerpieces:** reuse that multipart assembly at endpoints, bends, Ts
  and crosses. `has_wheel()` suppresses it only for masks 5/10. No separate shape
  PNGs are required to retain the current rule.
- **Vines and joins:** `T01` half-tube with `masks/clockwork_tier1_mask_from_core_e_color0_1.png`, quarter
  turns and two-front arrival; `T03` coupling at each shared boundary. `T02`
  tube-to-wheel collars exist in the source package but are intentionally unused.
- **Straight-run decoration gap:** `T03` is a required boundary join today, not a
  declared optional long-run decoration. Reusing it or another part as optional
  run decoration requires an explicit mapping/spacing decision.
- **Tier 2:** `L01`, `L02`, `L03`, `H00_plain_hatch`, with supporting core-wheel
  rise. Preserve fixed pivots, lower/upper metal alternation and assembly timing.
- **Tier 3:** `CH01_link` batched into two counter-moving strips, junction housing
  and caps selected from `H00`–`H03`. Shutters, puffs, powering and cap transitions
  require a dedicated behavior/motion hook, not a generic static sprite swap.
- **Environment/UI:** two ground plates, sidewall/lip, perimeter pins, drafting
  paper and supplied walnut frame. Button styling comes from shared UI code.

Preserve core/edge arrivals, pressure/emission delays, tube orientation workarounds,
wheel and gear phases, chain motion, compressed dismantling, audio cues, and frozen
capture phases. The common schema must adapt `assets`, `canvas`, `pivot`,
`growth_field` and numeric layer metadata from this manifest.

Checks to retain: `test_clockwork_wheel_rule.gd`, `test_clockwork_arrivals.gd`,
`test_clockwork.gd`, `test_clockwork_native.gd`, `test_clockwork_palette.gd`.

## Zen Garden — two different set families in one theme

Sources: [`zen_visuals.gd`](../../scripts/zen_visuals.gd),
[`zen_growth.gd`](../../scripts/zen_growth.gd),
[implementation notes](../zen-ordinary-tiles.md),
[source asset hashes](../../art/themes/zen_garden/source-assets.json).
Current runtime appearance version: 0.9. There is no runtime theme/set manifest;
roles, source pivots, timing and variants are currently spread across scripts.
`zen_growth.gd` currently subclasses Coral growth, discards its visual events and
reuses its waves/formation detection. Shared topology should remove that accidental
dependency on Coral-specific scheduling and manifest data.

### Raked-sand family (logical color 1)

- **Tier 0:** procedural concentric rake relief over the shared sand material.
- **Tier 1 vine:** `zen_geometry.gd` generates canonical isolated, endpoint,
  straight, bend, T and cross motifs with four exact edge grooves. Geometry and
  relief textures are procedural providers; a new engine must preserve them.
- **Tier 1 centers:** `zen_tier2_one_flat_top_stone_color0_1.png` for bends,
  `zen_tier2_three_stone_cairn_color0_1.png` for Ts, and
  `zen_tier2_tall_bamboo_behind_cairn_visual_color0_1.png` for crosses. Stages composite on a fixed
  canvas and persist through topology changes. Endpoints currently have no
  center decoration. Reusing the bend stone is an available candidate, not an
  already approved endpoint assignment.
- **Straight-run decoration:** no separate role/art mapping is declared.
- **Tier 2:** `zen_tier2_stone_lantern_color0_1.png`, with pedestal-centered pivot at half
  the original displayed height. Rake pattern completes first and stays beneath
  the lantern. Ordinary center stones are suppressed in supported formations.
- **Tier 3:** `zen_trees.gd`, `zen_tree_art.gd`, `zen_tree_trunk.gd` and branch/trunk
  shaders. Available imported art: two usable sakura branches, two green branches,
  three red branches, and regions of the winter bare/snow branch sheet. Trunks
  are procedural. The problematic short sakura master is not imported/used.

Keep unique-cell centroids, frozen local-month season, historical branch transforms,
replacement thicker trunks and 2–3 large limbs toward each old trunk. Preserve
independent/merged grove behavior, topology snapshots, settled animation state and
exact live canopy capture. Do not reconstruct the canopy from the final board only.

### Stepping-stone family (logical color 2)

- **Tier 0:** `cores/zen_tier0_stepping_stone_core_color0_1.png`.
- **Tier 1 vine:** four `stone_paths/half_stone_N/E/S/W_256.png` modules at 70%
  scale, anchored at boundary midpoints so opposing halves still meet. They are
  explicit directional assets, not copies of one rotated canonical sprite.
- **Tier 1 centers/decor gap:** no endpoint/bend/T/cross center compositions or
  dedicated straight-run decorations are currently declared for this family.
  The isolated core is available, but assigning it to other roles needs review.
- **Tier 2:** four `rock_formations/rock_0N_peak_and_low_bedrock_visual.png` designs,
  deterministic by origin, drawn above preserved stepping stones after their
  ordinary animation finishes. Surviving rock nodes and painter order persist.
- **Tier 3:** `zen_pond.gd`; all four unchanged `water_n/e/s/w` + `rock_occlusion`
  sets, unoccluded `watershed_*` guides for designs 02–04, and six supplied shrub
  strips. The 01 lateral guide uses its water boundary. These are flood/protection/
  placement masks, not lighting maps. Both 2×3 orientations activate facing
  triangles whose bases meet in the shared row/column, with half-depth placement.
  Shrubs follow the two laterals, keep the shared base clear, and choose randomly
  once from the pool. Choices survive helpers and are copied into captures.

**Environment/UI:** supplied common sand texture, four-display-unit raised ground
and plain-sand incoming piece. Dedicated Zen frame/rake-corner artwork and daytime
pagoda artwork remain unavailable; no Clockwork/Coral substitution is authorized.
Existing relief shading stays as-is.

Checks to retain: `test_zen_ordinary.gd`, `test_zen_centerpieces.gd`,
`test_zen_landmarks.gd`, `test_zen_ponds.gd`, `test_zen_trees.gd`,
`render_zen_game.gd`. The tree suite includes unrelated-move clock-reset checks.

## Coral Reef

Sources: [`theme.json`](https://github.com/Shine-game/Tiles/blob/951568f/art/themes/coral_reef/theme.json),
[`coral_growth.gd`](../../scripts/coral_growth.gd),
[`coral_visuals.gd`](../../scripts/coral_visuals.gd),
[arm artwork reuse](../coral-arm-assets.md), [environment](../reef-environment.md).
Runtime appearance version: 2.0. The manifest stores a component array, unlike
Clockwork's keyed dictionary, and uses different field names.

- **Tier 0:** color-specific `core` with its reveal field.
- **Tier 1:** `core` still appears on every occupied cell, including straights.
  Four arms use one canonical `arm_n.png` and its mask with placement rotation.
  `junction_ne/es/sw/wn` share canonical junction artwork with direction-specific
  mask handling. Bend/T/cross center assemblies need an explicit mapping from
  the existing core + applicable junction parts. Endpoint can reuse the core.
- **Decoration:** directional `fingers_*` artwork/masks exist, but tiny ordinary
  path fingers are intentionally omitted at runtime for phone readability. They
  are candidates for the new run-decoration role, not an authorized reactivation.
- **Tier 2:** colony body, two fold parts and two finger parts; own masks and
  dependency timing; multipart formations preserve painter-group order.
- **Tier 3:** anemone foot, eight regions and oral disc per immediately adjacent
  colony pair. Preserve connection identity, masks, rotation and growth order.
- **Environment/UI:** six stable ground choices, shared occupied-platform handling,
  reef water/light environment and supplied bleached-timber frame. Preserve reef
  audio through its existing hook. No new lighting work in this migration.

The target no-center-on-straights rule changes Coral's current appearance. Present
that difference at its migration checkpoint rather than concealing it in a loader
refactor. Keep canonical artwork reuse without accidentally treating every
junction's mask as identical.

Checks to retain: `test_coral.gd`, `test_coral_arm_rotation.gd`,
`test_reef_water.gd`, `test_coral_audio.gd`, plus gallery/theme-switch checks.

## Vines

Sources: [`growth.gd`](../../scripts/growth.gd),
[`board_view.gd`](../../scripts/board_view.gd) (`_draw_edge`, `_draw_holding_motif`,
`_draw_flower`, `_draw_link`), [`botanical_brush.gd`](../../scripts/botanical_brush.gd),
[`palette.gd`](../../scripts/palette.gd). No standalone set manifest or source
sprite pack for these motifs; geometry and the leaf texture are generated.

- **Tier 0:** holding motif/fronds, leaves and terminal stars around an isolated
  occupied cell, colored through the selected palette.
- **Tier 1:** procedural connection curves and leaf sprouts; holding motifs remain
  on all occupied cells. Explicit endpoint/bend/T/cross compositions and suppression
  on straights are not implemented. Map existing motifs before deciding which
  portions become centerpieces versus vine decoration.
- **Straight-run decoration:** leaves/stars exist procedurally but currently use
  edge growth/flow placement, not a run-length-and-spacing policy.
- **Tier 2:** procedural flower at every same-color 2×2 center.
- **Tier 3:** connecting vine and stars between immediately adjacent flower centers.
- **Environment/UI:** five palette pairs, palette floor/terrace and generated
  artwork. Dedicated decorative frame/full-screen painted background are not
  supplied. Current palette fallbacks remain valid.

Retain simultaneous independent growth, earliest arrival from old neighbors,
foliage attachment direction, persistent direction choices, flower/foliage audio
and shared ground across both colors. Procedural providers are required to migrate
without commissioning a replacement sprite pack.

Checks to retain: `test_growth.gd`, `render_growth.gd`, `test_ui.gd`, and relevant
rule/preview/gallery tests.

## Labyrinth

Sources: [`labyrinth_growth.gd`](https://github.com/Shine-game/Tiles/blob/1f5feed/scripts/labyrinth_growth.gd),
[`labyrinth_renderer.gd`](https://github.com/Shine-game/Tiles/blob/1f5feed/scripts/labyrinth_renderer.gd), base
[`growth.gd`](../../scripts/growth.gd). Artwork is procedural; no standalone set
manifest or sprite pack.

- **Tier 0:** center pyramid in an isolated occupied cell.
- **Tier 1:** hedge connections and a center pyramid on every occupied cell,
  including straights. Endpoint/bend/T/cross may share the pyramid provider;
  removing it on straights will be an explicit visual change.
- **Straight-run decoration:** no dedicated configurable role is declared; existing
  hedge detail is not automatically a long-run decoration.
- **Tier 2:** tree at the center of each same-color 2×2 enclosure.
- **Tier 3:** after neighboring trees are ready, their shared hedge recedes and a
  bench appears. The opening lies perpendicular to the tree-pair direction;
  preserve this geometry instead of applying Zen's flood-sector transform.
- **Environment/UI:** sand floor, colored hedge/pyramid/tree/bench geometry and
  palette-derived controls. Dedicated frame/background artwork is unavailable.

Retain opening visibility, wall-recede/bench timing, helper restoration and
underlying color/connectivity rules. Vines and Labyrinth share base graph logic,
but their drawing should become separate registered providers rather than theme
conditionals inside a common renderer.

Checks to retain: `test_labyrinth.gd`, `render_labyrinth.gd`, `test_growth.gd`,
`test_ui.gd` and shared gallery/theme-switch checks.

## Shared environment/UI ownership

Today `board_view.gd` dispatches growth models and renderers by theme flags;
`palette.gd` owns color branches; `main.gd` builds controls, styles buttons and
selects screen backgrounds. `occupied_platform.gd` owns fused occupied surfaces;
At this inventory baseline, `board_frame.gd` and `assets/frames/frames.json` owned shared frame geometry and
available frame art. Source/hovered pieces and field axes have their own rendering.

Step 9 should reference these responsibilities from the consolidated theme
configuration. It must preserve centered board layout, safe control margins,
full-screen backgrounds, menu frames and outlined buttons. No set manifest should
redefine input, helper budgets, difficulty, save eligibility or layout positions.

## Decisions to present at later checkpoints

1. Endpoint-center assignments for both Zen families and shape-role mappings for
   Coral, Vines and Labyrinth. Identify reuse options separately from missing art.
2. Straight-run decoration assets/providers, minimum length, spacing and clearance
   for each set. There is no approved universal numerical default.
3. Whether a non-Clockwork migration is enabled one theme at a time within Step 6;
   each visible change must be reviewable before enabling the next.
4. Final runtime serialization/validation format and adapter boundaries in Step 4.
   Existing supplied manifests and their metadata must not be silently rewritten.

These are not blockers for Step 2's shared topology extraction. Shading and new
artwork production remain outside this migration's currently approved scope.
