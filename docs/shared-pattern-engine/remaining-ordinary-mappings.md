# Step 6 — remaining ordinary-set mapping review

Status: Zen and Coral ordinary sets are implemented; Vines and Labyrinth remain
proposals. See [Zen](zen-ordinary-sets.md) and
[Coral](coral-ordinary-sets.md). The endpoint rows below reflect
the user's instruction to copy Tier 0 artwork and overlap the path ending.

## Proposed role assignments

Every row supplies a Tier 0 isolated role and Tier 1 endpoint/bend/T/cross roles.
Straight cells keep their connection artwork but omit their centerpiece. Shape
classification continues to use same-color neighbors only. Both logical colors
use their own treatment; no cross-theme artwork substitutions are proposed.

| Family | Tier 0: isolated | Tier 1: endpoint | Bend | T | Cross |
| --- | --- | --- | --- | --- | --- |
| Zen raked sand | Existing concentric rake pattern | Copied Tier 0 rings plus rake ending | Flat stone | Three-stone cairn | Cairn with bamboo |
| Zen stepping stones | Existing stepping-stone core | Copied Tier 0 core plus path ending | Unassigned | Unassigned | Unassigned |
| Coral Reef | Existing color-specific core | Same core | Core plus its applicable junction piece | Core plus its two applicable junction pieces | Core plus its four junction pieces |
| Vines | Existing holding/frond motif | Same procedural motif | Same motif | Same motif | Same motif |
| Labyrinth | Existing pyramid | Same pyramid | Same pyramid | Same pyramid | Same pyramid |

Reuse does not require separate copies of PNGs. Shape-specific compositions may
reference the same source artwork or procedural provider. Coral's multipart
center is one centerpiece composition even when it includes several junction
parts. Vines' motif still responds to open versus connected directions; mapping
it to a role does not freeze its geometry into a single image.

## Expected visible changes

- **Zen rakes (implemented):** endpoints now show a separately saved copy of the
  Tier 0 concentric relief overlapped by the existing rake ending. Isolated rakes,
  bends/Ts/crosses and ordinary-center suppression under 2×2 formations are unchanged.
- **Zen stepping stones (implemented):** endpoints now show a separately named
  copy of the Tier 0 core underneath the directional ending. Bend/T/cross center
  assignments remain unused; the existing directional modules still draw there.
- **Coral (implemented):** straight cells lose the decorative core; arms remain. Isolated,
  endpoint and branching cells retain the existing core/junction assemblies.
  Canonical image reuse and direction-specific mask handling are preserved.
  Native checks confirm both straight orientations remain continuous without a
  replacement core.
- **Vines:** straight cells lose their holding/frond motif. Their connection
  curves and existing edge leaves remain. Endpoints/bends/Ts/crosses retain the
  current direction-aware motif. Preserve the existing diffuse pigment wash,
  growth phases, leaf direction choices and transient edge stars.
- **Labyrinth:** straight cells lose the center pyramid. Their hedge connections
  remain. Isolated/endpoint/bend/T/cross pyramids keep the existing provider.

The user revised and approved the Zen endpoint assignments; these are now live.
Stepping-stone bend/T/cross center artwork remains a later assignment. Coral and
the two remaining themes reuse existing motifs, but their straight suppression is an
intentional appearance change. Update their runtime appearance versions when each
change is enabled; existing saved artwork PNGs remain readable.

## Vines, masks and providers

| Family | Preserve for Tier 1 migration |
| --- | --- |
| Zen rakes | Existing canonical procedural relief geometry, exact edge grooves, sand shader and staged fixed-canvas center addition |
| Zen stepping stones | Four explicitly directional half-stone PNGs, boundary-midpoint anchors, 70% scale and ordinary fade |
| Coral | Canonical arm image/rotation, two-front reveal, corner-specific junction masks/dependencies and persistent component ordering |
| Vines | Registered procedural curves, existing per-edge foliage and sound schedule; extract ordinary drawing from the board without rebuilding it |
| Labyrinth | Registered procedural hedge/pyramid providers; preserve wall visibility and existing higher-tier bench openings |

Existing leaves, coupling parts and mandatory junctions retain their current
roles. None becomes optional long-run decoration simply because it is small.
For this migration, every new `straight_run_decoration` slot is explicitly unused.
Coral's omitted tiny fingers stay omitted. A later decoration feature needs its
own approved artwork, minimum run length, spacing and clearance.

Shading stays deferred. Existing shaders and orientation workarounds remain.
No new artwork, preview application, Tier 2/3 policy or theme/UI restructuring is
included in Step 6.

## Implementation order and acceptance

After approval of these assignments, migrate **Zen Garden, Coral, Vines, then
Labyrinth**, with a separately reviewable result for each theme before enabling
the next. Each migration should:

1. Add live Tier 0/1 set definitions and explicit treatment/role/missing-slot data.
2. Route ordinary selection through `PatternCellSets` and loading/rendering through
   the existing shared services; retain specialized animation hooks where needed.
3. Check all 16 masks for both treatments, growth and settled views, endpoint to
   straight removal and restoration, Undo/Erase, capture and theme switching.
4. Check real-game 9×9/11×11 joins at phone scale and verify unaffected higher-tier
   layers/history. Distinguish intended appearance changes from regressions.
5. Update export inclusion, documentation and appearance version as applicable;
   run focused shared/theme checks and push the completed theme for review.

Coral is ready for review. Vines and Labyrinth retain their existing rendering
until their respective migrations are approved.
