# Tier 1 sprite rendering bridge — step 5

`PatternSpritePresenter` renders the step-3 plans against the step-4 timeline.
It was introduced as staged infrastructure in step 5 and is now active through
the board binding described in `theme-activation.md`.
No asset or metadata changes are required for this step.

## Host contract

Keep one presenter per board/gallery instance. Build plans and bindings, reconcile
`PatternSpriteGrowth`, then reconcile the resulting events into the host's existing
`PatternComponentState`. Call:

```gdscript
presenter.reconcile(plans, timeline.snapshot(), component_state, parent_node,
    cells_to_pixels, optional_base_fields)
```

`cells_to_pixels` is a full `Transform2D`, defaulting to 256 pixels per cell.
`optional_base_fields` maps component IDs to scalar texture asset descriptors or
Texture2D resources, with the same dimensions as the base artwork. R is native
source progress from zero to one. Supply this when a theme's path needs a curved,
radial or otherwise non-linear wave. Without an override, progress projects from
the metadata origin along native forward to the farthest occupied pixel.

Each frame, advance the host's existing component state once, then call
`presenter.advance(component_state)`. The presenter never advances time itself.
Use `set_view_transform` for view-only resizing and `clear` when disposing the view.
The host must retain plans/source bindings during retirement if it wants an exit
animation; removing a plan explicitly removes its presentation subtree.

## Placement and ownership

The existing `PatternComponentRenderer` owns all nodes. The presenter owns a
single root, with one transformed group per component. The base uses identity
inside its group; decorations use the planner's complete local matrices. This
preserves reflection, rotation and nonuniform affine view scaling together.
Metadata integer coordinates address pixel centers; the uncentered sprite quad
has offset `(-0.5, -0.5)`. Sprite flip flags remain false because reflection is
already in the matrix. Do not combine `source_transform` with legacy position,
pivot, scale or flip placement fields.

All decorations are overlays. Stable IDs reuse nodes across refreshes; component
IDs and growth position establish deterministic draw order. Individual material
instances prevent one decoration's progress from changing another's material.
Immutable arrival textures are cached, with a maximum of 64 entries. Absolute
clock rebases do not create new field textures when relative fronts are unchanged.

## Reveal and lifecycle

The shader clips source alpha; artwork never stretches. Progressive decorations
use their supplied linear or explicit scalar mask with shared lifecycle progress.
Direct decorations appear fully at activation. Waiting nodes are hidden, active
reveal nodes keep full opacity, and settled nodes discard the shader material.
Retirement freezes the last reveal fraction and fades the visible portion.

Bases use a floating-point arrival texture computed from all normalized incoming
fronts, so there is no fixed shader limit on front count. Arrival times are
relative to the earliest front; the shared clock is passed as a uniform. The
source end beyond the final arrival supplies the soft completion interval.
Finished and explicitly settled bases display their complete texture.

Resources, masks, source transforms and event/state revisions are checked before
live nodes are changed. A failed replacement returns false and leaves the previous
tree intact; inspect `presenter.diagnostics`. Inputs must be successful planner
outputs and matching growth snapshots, not arbitrary hand-written descriptors.

## Validation and next integration

Run `tests/test_sprite_presenter.gd` headlessly for all four real theme catalogs,
full transform composition, identity reuse, rejected replacements, mask lifecycle,
view changes, removal and shared-clock ownership. Run
`tests/test_sprite_reveal_render.gd` with a real graphics backend for pixel checks
of clipping, source color, reflection, timed fronts and soft completion.

Validation used Godot 4.6.3 and Mesa llvmpipe OpenGL compatibility; the project
target is Godot 4.7.2. Android pack validation proves resource availability, not
an APK/device run. Step 6 binds the board parts, source fields and retirement through
`PatternTier1Layer`; see `theme-activation.md`.
Zen rake artwork remains unavailable and its legacy path must remain in use.

The optional final `treatments` argument maps component IDs to `source_color` /
`target_color` Colors. These use the shared HSV palette shader and retain a
private completed-art treatment after the reveal material is cleared.
