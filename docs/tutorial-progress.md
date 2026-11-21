# Named tutorial lessons and progress (refactor step 2)

`scripts/tutorial_lessons.gd` owns the ordered lesson IDs, captions, permitted
actions, axis modes, fixture references, and transitions. Its repair definitions
also own headers, offer references, target types, and substep transitions.
The original behavior is recorded in
[the acceptance baseline](tutorial-acceptance.md). The regrouping and wording
below supersede its old nine-card numbering and the three changed captions;
other interaction and fixture requirements remain unchanged.

| Display | Stable lesson ID | Legacy stage |
| --- | --- | --- |
| 1/8 | `rotate` | 2 (also accepts removed stage 1) |
| 1/8 | `flip` | 3 |
| 1/8 | `color` | 4 |
| 1/8 | `place` | 5 |
| 2/8 | `vertical` | 6 |
| 3/8 | `horizontal` | 7 |
| 4/8 | `rotational` | 8 |
| 5–7/8 | `repair` | 10 (also accepts removed stage 9) |
| 8/8 | `reveal` | 11 |

## Current displayed captions

1. Successive instructions on one card: “Tap the piece to rotate it.” → “Press
   Flip to mirror it.” → “Press Color to choose its color.” → “Drag the piece
   into position and press Place.”
2. “Complete the vertical symmetry.”
3. “Complete the horizontal symmetry.”
4. “Complete the rotational symmetry.”
5. “The hint button shows achievable symmetries. Make an asymmetric placement
   and the game ends.”
6. Header “Save the pattern” with “Undo your last move.”; then “Erase a square.”;
   then “Get a different piece and place it.” The latter remains during replacement
   placement. The header still appears only on Undo.
7. “Bold axis! Your board is symmetrical right now. You can save a picture here
   if you want.” Hint/Save remains the required action, as confirmed by the user;
   only here does it pulse.
8. “Choose your theme and create intricate worlds.” This is an interactive
   card. After the Vines reveal and gallery save, Settings pulses. Opening it
   pulses the existing Themes button. Opening Themes offers the normal three
   available themes. Selecting one renders the completed board in that theme
   without resetting tiles, history, or the offered piece, then finishes the
   tutorial and restores normal play. No new-game confirmation appears.
   Closing or going back in the menu retains the card; relaunching resumes at
   its Settings prompt. The tutorial is marked complete only after theme choice
   (or explicit End Tutorial).

Display numbers are presentation metadata, not persisted keys. Combining the
first four operations does not unlock them all at once or replace their shared L.

Repair checkpoints, in order: `wrong_placement`, `undo`, `erase`, `replace`,
`place_replacement`, `save`. They map to legacy phases 2–7 only inside the adapter.
Resume restores the checkpoint's board, offer, caption, permitted controls, and
target. An unfinished drag or transform is intentionally reset to that
checkpoint's starting offer; pointer state is not persisted.

## Storage

The existing `user://introduction.cfg` path is retained. New writes use:

```ini
[intro]
version=2
started=true
lesson_id="repair"
checkpoint="place_replacement"
done=false
seed_index=0
```

Non-repair lessons use an empty checkpoint. `seed_index` remains only for old
interrupted final-design assembly compatibility. New progress never stores a
numeric `step`; the loader derives that field for the existing controller.

Loading an unversioned file maps its stage to a stable lesson. Old repair saves
start at `wrong_placement` because those files did not contain a substep. The
next successful checkpoint write replaces the legacy representation with v2.
Reading alone does not alter the file. Completion and old final-design cursors
survive migration.

Malformed types, unknown versions/IDs, invalid checkpoint combinations, or
out-of-range cursors fall back to an unstarted Rotate lesson. Rejected writes
leave the existing save intact. Valid writes use a temporary file and rename;
controller failures are reported as warnings.

## Scope boundary

The controller still uses numeric stages/phases for some rendering and guidance
conditions. These are transitional adapters; do not use them in new persisted
data. Gesture sharing, shared previews, lifecycle
cleanup, and obsolete replay rendering removal remain later refactor steps.
This step resolves the baseline's missing repair-checkpoint persistence; its
other audit gaps remain open.

The shared command interface is implemented in
[refactor step 3](tutorial-actions.md), and
[step 4](tutorial-practice.md) replaces its temporary fixture backend with an
isolated real practice game.

## Verification

`tests/test_tutorial_progress.gd` checks every old stage, every named checkpoint,
completion, malformed records, unsupported versions, transition references,
read-only migration, and rejected-write preservation. The graphics-enabled
`tests/test_introduction.gd` additionally checks startup resume at each repair
checkpoint, the unchanged lesson flow, UI handoff, and actual gallery output.

Verified on 2026-11-21 with Godot 4.6.3: 162 progress checks and 1,251
graphics-enabled tutorial checks, zero failures. The latter includes all eight
display numbers, repair-checkpoint restoration, the real gallery PNG save, and
native Settings → Themes → selection flows for all three available themes.
