# Step 5 — Clockwork ordinary sets

Clockwork Tier 0/1 now use production shared sets in the actual game. The migration
preserves artwork, shape rules, tube fronts, boundary joins, motion, retirement,
audio, gallery phases and appearance version. No preview interface was added.

## Live data and shared rules

- [Tier 0](../../art/themes/clockwork_workshop/sets/tier0.json): isolated socket,
  wheel and axle, assembled from C01/C02/C03.
- [Tier 1](../../art/themes/clockwork_workshop/sets/tier1.json): endpoint, bend, T
  and cross use that centerpiece assembly; straight explicitly selects no center.
  T01 is the vine and T03 is the once-per-edge boundary coupling.
- Both sets map logical colors 1/2 to copper/gunmetal. The common asset library
  validates and explicitly binds named artwork treatments, including mask variants
  when supplied. Unknown treatments do not substitute another color.
- Parts declare original source pivots, event bands, painter order, filtering,
  anchors, timing, material provider and reveal mask semantics. T01 declares its
  east-facing base port and existing south/west straight-tube shading flips.
- Long-run decoration remains explicitly unused: neither its artwork nor its
  spacing has been approved. T02 collars remain omitted. T03 is a coupling, not
  a newly invented straight-run decoration.

[`cell_sets.gd`](../../scripts/pattern/cell_sets.gd) selects compositions by the
shared topology's shape role and supplies cell-center/shared-edge anchors.
[`clockwork_sets.gd`](../../scripts/clockwork_sets.gd) loads those sets and binds
the existing project-owned rise/tube shaders. The growth adapter now consumes the
set's centerpiece parts, anchors, delays, travel, reveal-tail and emission timings.
Legacy timing constants remain compatibility mirrors for existing callers/tests;
ordinary scheduling uses the live set values.

The shared component renderer owns persistent ordinary sprites and applies their
set metadata. Existing Clockwork operation hooks still rotate wheels, coordinate
pressure fronts, emit sound and effects, preserve in-flight growth and retire
unsupported parts. Releasing a retiring node transfers disposal back to that
hook; surviving sprites keep their identities. Ordinary IDs stay stable so
higher-tier construction and motion can continue to reference supporting wheels.

## Boundaries

Tier 2/3 assemblies, chains, ground, pins, theme/UI configuration and specialized
pressure propagation remain in the existing adapters. Original `theme.json`, PNGs,
masks and shader sources are unchanged. The JSON export include filter explicitly
packages both production sets. Shading remains deferred.

## Verification

`tests/test_clockwork_sets.gd`: 528 checks covering both production sets, both
metals, all 16 shapes, exact source metadata/timing, declarative role selection,
variant binding, persistent node ownership, endpoint-to-straight removal and Undo.
The common asset/state suites also pass (155/232 checks).

All 580 recorded model fixtures remain byte-identical. Native real-board captures
for both metals, all 16 shapes and connected straight propagation at three growth
phases match all 102 pre-migration images pixel for pixel. Existing game suites
cover pressure arrivals, wheel selection, higher tiers and other themes.
