# Tier 1 generation — step 4: decoration activation and lifecycle

`PatternSpriteGrowth` binds a step-3 placement plan to actual structural growth
fields. It produces decoration events consumed by the existing
PatternComponentState. It owns no animation clock and creates no render nodes.
The board will supply layouts/bindings during the rendering integration stage.

## Source bindings

A binding has an `event` dictionary and optional `u_range`, `stroke_seconds`,
`settled` and `replay` fields. Times use the same seconds/epoch as the game's
shared construction clock.

Supported source events:

- Coral/common: start, stroke, optional two_fronts=true and reverse.
- Clockwork: start, seconds and edge_start (a reverse front unless explicitly
  disabled with two_fronts=false).
- Vines/full edge: start_a, start_b, finish. Supply the full edge travel duration
  explicitly as stroke_seconds=TileGrowth.STEP. finish is the fronts' meeting
  time, not the travel duration.
- Instant/pop/direct stage: start with no travel field means every mapped point
  is reached at start; an optional end still describes structural completion.
- Multiple simultaneous sources: fronts=[{start, origin_u, seconds}, ...]. Each
  front spreads from its origin_u in [0,1]; seconds is travel time for a full
  unit of field distance. Different front speeds are allowed.

Explicit front arrays declare their own travel times and cannot also use a
binding-wide stroke_seconds. Provided end/finish must cover the last arrival of
the whole source field, including source portions beyond a cropped sprite.
A supplied completion tail is preserved for parent-lifetime bookkeeping; it is
not added to every anchor's arrival.

The earliest front reaching a point determines its activation. The shared
schedule now exposes field_arrival/field_end for arbitrary normalized fronts.
Completion is calculated from endpoints, source origins and valid affine-branch
intersections, rather than approximated with samples or a fixed frame rate.
Existing front_arrival, front_end, event_arrival and tier prerequisites keep their
original behavior.

## Mapping a base sprite onto a source

u_range defaults to [0,1] and maps the base's native growth_at to the source field.
[1,0] reverses native growth; [0,0.5] maps the first half of a full edge;
[1,0.5] maps its other half from that endpoint toward the meeting point. A
constant range such as [0.5,0.5] activates every selected anchor when that one
source threshold is reached.

The complete base rotation/reflection does not independently reverse this scalar
mapping. Native progress remains attached to the original source sprite. The
host supplies the relation between that native axis and the structural event.

## Compilation and the model bridge

```gdscript
const SpriteGrowth = preload("res://scripts/pattern/sprite_growth.gd")
const ThemeEvents = preload("res://scripts/pattern/theme_events.gd")

var timeline = SpriteGrowth.new() # retain with the construction owner
var bindings = {
    plan.component_id: {
        "event": structural_event,
        "u_range": [0.0, 1.0]
    }
}
var scheduled = model.schedule_sprite_growth(
    {plan.component_id: plan}, bindings, timeline, {
        "at": 0.0,
        "elapsed": previous_clock,
        "restart": true,
        "preserve": true
    })
if not scheduled.ok:
    # Report errors; prior attached events/history remain intact.
    return
var events = ThemeEvents.collect(model, theme_id, zen_visuals, workshop_visuals)
construction_state.reconcile(events, model.duration, 0.0, false, true, true)
```

The new common TileGrowth method is inherited by all four themes. It records
sprite_growth_events and sprite_visual_duration after structural scheduling.
ThemeEvents.collect appends these events after collecting structural/formation
prerequisites. It never overwrites a structural ID. Decoration events use the
reserved `sprite/` prefix; placement_id retains the planner's original ID for
render ownership. No theme-name-dependent timing branch is added.

The model's duration and its tier 2/3 event/dependency records stay unchanged.
Blocking decoration ends extend PatternComponentState's existing visual clock.
The shared clock may also be extended by other legacy construction/retirement
records. A caller must not clamp an extended clock back to model.duration during
a view refresh; live board integration will handle that when the renderer is
connected. No new timing path is automatically enabled by this data bridge.

`SpriteGrowth.compile(plan, binding, settled=false)` is a pure one-plan compiler
for callers that do not need retained history. `timeline.reconcile(plans,
bindings, options)` handles a whole construction replacement atomically. Every
plan needs a matching component identity and source binding; an invalid member
rejects the entire replacement before publishing events or history changes.

## Reveal duration and progress

Progressive start is source arrival at growth_at; end is start+duration_sec.
A late anchor gets its full duration even if its base has already completed.
Direct decorations have start=end and become fully visible exactly at activation;
there is no implicit 1ms tween or scale animation.

Each event includes its parent/placement IDs, revision, growth_at, mode, duration,
old/replay flags, and a copy of the current layout (matrices and reveal data).
SpriteGrowth.progress(event, clock) gives the same smooth progressive reveal as
component state, or the exact direct-placement step. The renderer must use that
progress with the selected reveal field; this stage does not animate pixels.

## Interruption, refresh, restoration and cancellation

Options:

- at: current time in the replacement clock (default 0).
- elapsed: amount removed from the previous clock origin (default 0). Old time
  equals new time+elapsed. It is not a new reveal duration or frame delta.
- restart: false for a same-clock view refresh; elapsed must then be zero.
- preserve: retain matching construction timing; false starts a fresh ledger.
- settled: restore/capture everything complete, with no active visual tail.
- structural_duration: baseline gate. The common model bridge always supplies
  its actual structural duration, overriding an external value.

Reconciliation and ComponentState must receive consistent at/settled/preserve/
restart options. Pausing belongs to the existing shared schedule; the timing
ledger has no independently advancing clock. Snapshotting is a copy of live
history, not a full historical recording for arbitrary backward scrubbing.

For an unchanged decoration revision:

- Active reveals retain their start/end interval, shifted only by elapsed.
- A surviving board-old parent that was still under construction retains its
  previous normalized source field. Waiting anchors and new selections on that
  partial parent cannot become instantly settled.
- A valid newly arriving front may bring a waiting anchor forward. Once visible,
  the decoration always finishes its own interval.
- Completed decorations stay settled during subsequent placements and do not
  prolong the new gate.
- Updated view transforms/color artwork adopt current layout data while retaining
  timing; revision excludes display transforms and color treatment.

The revision includes native placement, source identities, threshold and reveal
policy. An intentional binding replay=true selects the incoming field and reaches
the shared state's replay flag. Replay is a one-shot action; it is not inherited
by the next partial-parent continuation. For a replay, supply the desired active
source event; an explicitly old source still means settled artwork.

Explicit old=true or settled restoration marks events complete. Negative times,
even a value equal to the historical -100 sentinel, are not treated as old without
that flag: rebased construction can legitimately be partially visible at time 0.

Removing a plan removes its pending/active events on the next reconciliation.
Recreating it later starts from the new source. reset() clears the ledger.
Returned events and snapshot() dictionaries are independent of private history.
Existing theme retirement effects remain in their legacy owners; this stage does
not invent a separate decorative fade/removal policy.

## Verification

The timing runner covers canonical and legacy fields, reverse/cropped mappings,
multi-front arrival/completion, full durations, direct switching, partial rebases,
partial board-old parents, incoming fronts, pause/refresh, replay, cancellation,
settled captures, atomic errors and independent snapshots. It compiles actual
planner output and attaches timing through real Coral, Clockwork, Vines and Zen
models. It verifies structural events/prerequisites byte-for-byte and runs through
the existing state clock.

See timing-validation.json for totals. The timing runner also runs against an
exported Android resource pack from an empty project directory. Existing growth,
pattern-state, tier 2 and tier 3 tests guard the unchanged legacy behavior. Tested
with Godot 4.6.3; project target remains 4.7.2. No APK/device test is claimed.
