# Final tutorial cleanup (refactor step 8)

All eight refactor steps are implemented. The eight-card player flow, captions,
fixtures, button gates, and final theme selection remain unchanged.

## Runtime and compatibility boundary

`TutorialLessons` defines named lessons and repair checkpoints. The controller,
main UI integration, and practice factory use those names directly; displayed
card numbers are presentation only. Numeric stages and replay cursors are read
only by the progress loader for old saves. New v2 writes contain neither.

An interrupted old final assembly resumes by building the complete canonical
9×9 two-color design through `PlayerActions`, revealing settled artwork, and
requesting the same real gallery save. There is no incremental replay cursor,
second renderer, or partial-board handoff to maintain. Completion still waits
for successful image persistence and the user's theme selection.

Removed paths include the deleted opening-card fixture, unreachable Forward
transition, unused automatic on-board offer placement, old numeric controller
adapters, and tutorial underlay rendering in both BoardView and VinesSets.
Ordinary occupied platforms and theme surfaces now render directly.

## Verification strategy

Tests target the current behavior using named lessons/checkpoints. Legacy stage
numbers occur only in migration fixtures. The native tutorial suite retains
real mouse button input, touch dragging, immediate placement, transformation
animation gates, fixed teaching axes, predictive axes, all helper actions,
multiple phone layouts, real PNG persistence, resume, and three-theme handoff.
The save-flow suite covers old partial-assembly migration as well as failures,
retry, duplicate requests, stale captures, and owner removal.

The broad UI suite now checks the actual Settings → Themes flow and direct
pre-game theme application. It retains authored pale tile backgrounds and allows
a hidden gallery scroll container. Button wiring is exercised directly under
headless Godot and with native clicks in graphics-enabled runs. Existing native
tutorial tests continue to cover button refresh/press behavior separately.

Shared modules own gestures, geometry, previews, domain actions, artwork capture,
and gallery persistence. The tutorial retains its teaching fixtures, captions,
policy gates, guidance rendering, and temporary UI ownership.

## Validation

Verified with Godot 4.6.3 on 2026-11-21:

| Suite | Mode | Checks | Failures |
| --- | --- | ---: | ---: |
| Full interactive introduction | X11, real rendering/input | 1,255 | 0 |
| General UI and gestures | X11 | 485 | 0 |
| Save failures, retry, migration, lifecycle | X11 | 30 | 0 |
| Gallery completion, all available themes, 9×9/11×11 | X11 | 78 | 0 |
| Named progress and legacy migration | Headless | 162 | 0 |
| Practice sessions | Headless | 72 | 0 |
| Tutorial lifecycle | Headless | 22 | 0 |
| Shared player actions | Headless | 36 | 0 |
| Shared piece interaction | Headless | 25 | 0 |
| UI layout and gestures | Headless | 2,019 | 0 |
| Preview colors | Headless | 75 | 0 |
| Predictive symmetry | Headless | 25 | 0 |
| Board frame | Headless | 61 | 0 |
| Domain rules | Headless | 721 | 0 |
| Game session persistence | Headless | 18 | 0 |

The general UI suite also passes its headless branch (496 checks). Real image
persistence is verified with a graphical display, not inferred from headless
runs. The known Godot audio-resource shutdown warnings remain; these runs have
no script errors or failed assertions. `git diff --check` passes.
