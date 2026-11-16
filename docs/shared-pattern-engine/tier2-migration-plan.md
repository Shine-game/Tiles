# Step 7 — shared Tier 2 formation migration proposal

Status: approved and implemented. See the [implementation and verification](tier2-assembly.md). Labyrinth was removed at the owner's request, completing Step 6
for Zen Garden, Clockwork, Vines and Coral Reef.

The next change should consolidate how same-color 2×2 formations are assembled.
It should preserve the current appearance and sequence, including every eligible
overlapping square. No new artwork assignment is needed for this step.

## Existing mappings to preserve

| Theme | Tier 2 set | Current assembly/readiness |
| --- | --- | --- |
| Zen rakes | Stone lantern over the existing four-cell rake pattern | Finish the ordinary pattern, hold for 0.10 s, then fade the lantern for 0.45 s; retain its half-size canvas and pedestal-centered source pivot |
| Zen stepping stones | Four deterministic rock variants over the existing paths | Same pattern/hold/fade order; origin selects the current rock variant, with stable node identity and painter order |
| Clockwork | L01, L02, L03 and plain hatch | Wait for supporting core wheels and internal tube halves, then use the existing offsets 0/0.85/1.20/1.70 s and durations 0.40/0.35/0.50/0.25 s; complete at 1.95 s; L03 retains the opposite metal |
| Coral Reef | Colony body, two folds and two finger parts | Wait for the four-cell internal arms; body and dependent parts retain their current reveal masks, timing and feature-group order |
| Vines | Procedural flower | Start after the four perimeter edges meet; retain the 0.36 s petal pop, color, leaf/flower layering and existing sound cue |

A 2×3 has two overlapping formations; a 3×3 has four. Both board colors follow
the same eligibility rule. Neighboring different colors do not share a formation.
The common representation uses a top-left origin, four supporting cells and the
shared cell-space center (`origin + (1,1)`). Existing corner-based public model
keys can remain adapters until their consumers migrate.

## Proposed implementation sequence

1. **Common formation assembly record.** Build on the existing topology and
   construction-state modules. Consolidate origin, center, supports, logical color,
   persistent identity, before/after eligibility and supported lower-tier parts.
   Removing a support cell retires only the affected formations; helpers restore
   the appropriate underlying ordinary artwork.
2. **Live Tier 2 sets.** Add a Tier 2 definition for each active theme/family,
   reusing current textures or registered procedural providers. Move artwork,
   variants, explicit pivots, layers and mask semantics into those sets. Keep
   theme-owned pressure/reveal/operation callbacks where their behavior differs.
   Missing shading maps stay deferred; do not synthesize them.
3. **Migrate assembly and scheduling.** Use the common record/renderer with each
   theme's existing prerequisite and phase policy. Preserve Clockwork supporting
   wheel rise/motion and metal alternation, Zen's pattern-first layering and
   lantern base anchor, Coral's multipart feature ordering, and Vines' petals,
   edge direction choices and flower sounds.
4. **Verify and deliver for review.** Compare the actual game before/after for
   both colors, 9×9/11×11 boards, isolated/overlapping/dense formations and multiple
   growth phases. Check Undo, Erase, unrelated moves, theme switches, growth gates,
   sound and saved artwork. Push the finished Step 7 result before Step 8.

The goal is a structural migration, so no appearance-version bump is planned if
pixel comparisons confirm the intended behavior is unchanged.

## Boundaries for this step

Tier 3 policies stay in their existing modules. Their current input records,
formation identities and trigger times must remain compatible: ponds must still
flood the facing shared-base sectors; tree branch/trunk history must survive;
chains, anemones and flower links must retain their current behavior. In
particular, Vines currently overlaps the flower/link animation rather than waiting
for every petal to finish; defining a common formation completion time must not
silently postpone its Tier 3 trigger.

No new preview UI, layout work, puzzle-rule changes, shading work or replacement
artwork is included. The migration will be tested in the normal game, using the
existing shared asset, rotation, construction and rendering services.
