# Shared pattern engine — migration plan

Steps 1–5 delivered the specification/inventory, shared topology and construction
state, the common asset/component rendering foundation through adapters, and live
Clockwork Tier 0/1 sets. Step 6 has migrated Zen, Coral and Vines ordinary sets, including
the reviewed Zen endpoint composition and removal of Coral cores and Vines
holding motifs on straights.
Shading, game rules and the player interface remain unchanged.
Inventory baseline: commit `951568f` (all five themes inspected).

- [Asset-set contract](asset-contract.md): proposed shared data and behavior rules.
- [Step 2 implementation](topology.md): geometry API, adapters and verification.
- [Step 3 implementation](state-and-growth.md): persistent construction state, clock,
  dependencies, capture and restoration.
- [Step 4 implementation](assets-and-rendering.md): versioned set loading, shared
  sprite/atlas/procedural rendering and compatibility adapters.
- [Step 5 implementation](clockwork-ordinary-sets.md): live Clockwork sets,
  shared shape selection and persistent ordinary components.
- [Step 6 mapping review](remaining-ordinary-mappings.md): proposed remaining
  role assignments, visible changes and per-theme review order.
- [Zen Tier 0/1 implementation](zen-ordinary-sets.md): live sets and copied
  endpoint artwork, following the revised endpoint assignment.
- [Coral Tier 0/1 implementation](coral-ordinary-sets.md): live multipart port
  selection, core suppression on straights and preserved directional fields.
- [Canonical assembly correction](canonical-assembly.md): shared port rotation,
  all-theme directional audit and operation after redundant files are removed.
- [Vines Tier 0/1 implementation](vines-ordinary-sets.md): live procedural parts,
  shared role selection and persistent holding-motif construction records.
- [Existing-theme inventory](theme-inventory.md): baseline implementations, available
  resources, differences from the target contract, and migration checks.

## Agreed direction

Themes supply sets for Tier 0 (isolated tile), Tier 1 (connections, centerpieces,
and straight-run decoration), Tier 2 (2×2 formations), and Tier 3 (connected
formations). The engine shares topology, placement, identities, and growth
lifecycle. Theme configuration supplies artwork and timings. Specialized Tier 3
behaviors remain project-owned modules.

Endpoints retain a centerpiece, which disappears if a later connection makes the
cell straight. Bends, Ts, and crosses use their configured centerpieces; straights
have none. A centerpiece may be a multipart assembly rather than a single PNG.

Shading work is deferred. Existing shaders, painted shading, and shading-related
workarounds remain in place during this migration. Existing reveal and protection
masks still need explicit semantics; they are not lighting maps.

## Approval checkpoints

Each step requires its own approval before implementation. At its end, provide
what changed, relevant validation, visible differences and remaining gaps; pause
before starting the following step. Do not treat approval of this plan or Step 1
as authorization to implement the remaining steps.

| Step | Deliverable | Acceptance criterion | Status |
| --- | --- | --- | --- |
| 1 | Asset-set contract and inventory of all themes | Current behavior distinguished from target rules; gaps and exceptions listed; documentation only | Complete |
| 2 | Shared topology classification and formation graph | All 16 masks, colors, rotations, overlapping 2×2s, and 2×3 joins covered; adapters preserve current consumers | Complete |
| 3 | Persistent component state and growth scheduler | Stable identities, dependency timing, settled layers, removal, Undo/Erase and reset work across clock restarts | Complete |
| 4 | Common asset loading and component rendering | Sprites, multipart assemblies and registered procedural providers use explicit pivots, masks, layers and reveal rules | Complete |
| 5 | Clockwork Tier 0/1 pilot | Agreed wheel rule, tube arrivals, boundary couplings, motion, audio and gallery phases retained | Complete |
| 6 | Remaining themes' Tier 0/1 migration | Each theme has explicit set mappings; approved centerpiece/decor changes are identified; missing assets are not invented | Zen, Coral and Vines migrated; review before Labyrinth |
| 7 | Shared Tier 2 formations | Common origin, support, overlap and lifecycle rules; each theme retains its layering and timing | Awaiting approval |
| 8 | Shared Tier 3 integration points | Common connection graph drives specialized ponds, trees, chains, anemones, vines or benches; historical state preserved | Awaiting approval |
| 9 | Theme/UI configuration consolidation and cleanup | All themes pass runtime checks; obsolete code removed only after replacement; no competing active contracts | Awaiting approval |

Step 2 may introduce a shared topology module and thin adapters in the existing
engines. It must not switch artwork or impose the new centerpiece rule on themes
that do not implement it yet. The proposed module names and final serialization
format are not runtime interfaces until implemented in their approved step.

## Migration boundaries

- Preserve puzzle rules, logical colors 1/2, 9×9/11×11 boards, symmetry, helpers,
  controls, safe margins, source-piece presentation, and save eligibility.
- Record actual visual changes separately from structural refactoring. The target
  centerpiece rule is not a claim that every current theme already follows it.
- Do not change shading, author missing artwork, or create a preview application.
- Preserve existing audio and motion through project-owned hooks until migrated.
- Use the real game for rendering checks. Keep useful current tests and add
  focused checks for each shared responsibility as it is extracted.
- Keep older gallery PNGs readable. A refactor that preserves appearance should
  not force a new appearance version; an intentional visual change should.

## Relationship to existing theme handoffs

[The existing handoff guide](../theme-handoff/README.md) and its example remain
source-package documentation, not an already working shared-engine format.
Clockwork higher tiers and Coral still consume different legacy manifests; Zen, Vines and
Labyrinth have no equivalent runtime set manifest. This proposal does not rename
or reinterpret any of those files. Steps 4–5 introduced explicit adapters and the Clockwork ordinary sets before
Step 9 retires obsolete formats or consolidates the artist handoff.
