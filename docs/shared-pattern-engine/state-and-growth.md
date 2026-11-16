# Step 3 — shared construction state and scheduling

The shared layer now drives the board's construction clock and maintains persistent
component records across placements. Existing artwork, shader logic, animation
constants, game rules and appearance versions remain unchanged.

## Modules

- [`growth_schedule.gd`](../../scripts/pattern/growth_schedule.gd): construction
  clock, duration/gate, pause/cancel, smooth progress, one/two-front arrival and
  completion, dependency thresholds/delays and partial-event rebasing.
- [`component_state.gd`](../../scripts/pattern/component_state.gd): identity-keyed
  persistent records, lifecycle transitions, retirement, stable component ordinals,
  deltas and independent settled capture copies.
- [`legacy_events.gd`](../../scripts/pattern/legacy_events.gd): translates current
  theme events into that common record format without loading a new asset format
  or rebuilding theme artwork. No nodes/textures enter the common records.

This is the state/scheduling foundation, not Step 4's common asset loader or
renderer. Private render-node registries, reveal shaders, pressure-wave policies,
feature-group painter order, geometry, audio and operating motion remain in their
current implementations. They can migrate onto the shared state through later
approved asset/rendering adapters.

## Component lifecycle

A descriptor has a namespaced stable ID and `start`, `end`, `old`, `owner` and
`retiring` fields. Optional revision/replay fields distinguish intentional new
construction on an existing role from a settled part being retained. Optional
`blocking: false` can exclude a future non-gating effect from construction duration;
current continuous operating motion is not registered as construction at all.

Records transition through:

1. `waiting`: a dependency/start time has not arrived.
2. `appearing`: construction is in progress.
3. `settled`: complete; a later placement's zero clock cannot hide it.
4. `retiring`: an unsupported part fades through its declared removal interval.
5. Removed: absent from the live table after immediate removal or completed retirement.

Surviving IDs retain the same record object and stable component ordinal. Removed
IDs retain their ordinal in game-owned history so Undo/rebuild can restore ordering;
reset clears both live records and that history. These ordinals do not replace the
existing renderers' layer/group ordering in this step.

`old` is explicit. A negative rebased start can mean partially completed work, not
settled work. This matters for Clockwork Undo during construction. Existing event
rebasing now uses the shared helper without changing travel durations or event
identity. Completed components do not replay unless their revision changes or
replay is explicitly requested.

## Clock and dependencies

`begin(duration, clock)` establishes a construction interval. Advancement clamps
negative deltas and the final time; pause freezes progress; cancel clears the
clock. The state table includes active part/retirement ends in the gate and retains
an explicit legacy-duration barrier for small effects that have not become separate
parts yet. Completed parts and operating gears/chains never extend that gate.

`board_view.gd` now uses this clock for every theme and its completion gate for
Place. The existing `clock`, `growing` and growth signals remain compatible.
Layout restyling resumes the current clock and wave rather than starting another
placement. Existing SceneTree pause behavior continues to suspend processing.

The dependency helper supports completion plus delay and arrival at a reveal-field
threshold. Two-front fields use earliest pixel arrival, including their reveal
tail. Clockwork and Coral keep their public timing methods as adapters; they now
share these calculations. Clockwork and Zen use the common smooth-progress helper.
Specialized pressure propagation, assembly sequences and reveal materials are
preserved; this step does not impose one universal speed or asset sequence.

## Theme adapters

| Theme | Registered construction |
| --- | --- |
| Clockwork | Live component events, ground/pins, chains and unsupported retiring parts, after existing partial-construction restoration |
| Coral | Existing keyed components, including colony/anemone parts, canonical arms and their reveal intervals |
| Zen | Ordinary patterns, individual centerpiece stages, landmarks, water sectors, shrubs, historical trunks and branches |
| Vines | Occupied-cell motifs, edges, flowers and flower-to-flower links |
| Labyrinth | Occupied-cell motifs, hedges, enclosure trees and wall-opening/bench intervals |

Stable IDs include the theme and existing feature identity. The adapter does not
make all tiers mutually exclusive, change centerpiece selection, move branches,
reroll variants, or reinterpret masks. New cells, changing supports and helpers
still select artwork through the current theme implementations.

Zen continues to inherit the current Coral scheduler during this step; avoiding
its discarded Coral visual-event construction remains follow-up migration work.
Shared timing helpers do not pretend that this dependency has already disappeared.

## Capture and reset

Gallery capture receives an independent settled copy of the live component table
and its ordinals. Existing visual-copy paths still preserve painter order, phases,
random shrub choices and historical seasonal branches. Continuous motion clocks
remain separate and are frozen by the existing capture hooks. Common records do
not reference live render nodes, and changing a captured record cannot mutate the
source. Reset/new game clears pending and historical common construction state.

No game-resume feature or save-format migration is introduced. Gallery appearance
fingerprints and theme versions remain unchanged because intended artwork is
unchanged.

## Verification

`tests/test_pattern_state.gd` checks lifecycle transitions, retained identity/order,
unrelated clock resets, partial negative starts, retirement, delay/field dependencies,
two-front completion, pause, snapshot isolation, helper restoration, reset, layout
refresh and actual board integration for all five themes.

All 580 pre-change model fixtures remain byte-identical, including component
ordering and numeric timing. Existing growth, Labyrinth, Clockwork, Coral, Zen and
UI suites pass. Native Clockwork/pond/tree tests also pass, including exact seasonal
gallery pixels and preservation of tree layers across unrelated placements.

Next approval: Step 4, common asset loading and component rendering. The proposed
asset contract is still a design contract; no new runtime theme manifests are
silently enabled by this state/scheduling change.
