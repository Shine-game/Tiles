# Tutorial acceptance baseline

Status: step 1 of the tutorial refactor; documentation only.

Historical baseline: commit `f3b0c3a`. Subsequent approved numbering and caption
amendments are recorded in [the step-2 progress document](tutorial-progress.md).
Its current eight-card presentation supersedes the nine-card table below.

Baseline: commit `f3b0c3a`. This document freezes the current intended player
experience before implementation changes. It does not make the current internal
stage numbers, duplicate controllers, or obsolete replay renderer requirements.
Items under “Audit gaps” describe unresolved behavior, not approved new features.

## Presentation and interaction contract

- Reuse the existing game UI and its button positions. Jokers remain visible;
  enable them only in their guided repair steps. Use the Settings position for
  disabled Forward navigation and the New Game position for End Tutorial.
  End Tutorial remains available throughout practice.
- Use bundled Lora Regular at 20 px, including the step counter. Use regular
  lettering, the theme's icon/text color, centered text, and single line breaks
  without added paragraph spacing. No bold markup.
- Center instructions horizontally and vertically between the upper button
  columns. Use a common caption area sufficient for the longest cue at the
  current width. Never shrink text or pieces to resolve overlap.
- Early exercises use simple colored tiles on a 5×5 field. Keep the frame and
  place the field in the normal board region, with the same bottom alignment.
  Reserve two tile rows above it for the offered piece.
- The 9×9 repair field, its frame, and the final artwork field match the normal
  game's field and frame geometry exactly. Handoff must not resize the board or
  move the bottom controls.
- Offered pieces lie horizontally and use the exercise board's cell size.
  Present them clear of the frame; rotation may extend over the field. In the
  large repair lesson, the normal-size piece may overlap the caption as already
  authorized. Dot, I3, and replacement Domino share one presentation center,
  with their unrotated bottom 4 logical pixels above the outside frame.
- The actual piece can be dragged freely before its configuration is correct.
  A stationary piece does not rotate automatically. Tapping rotates it where
  that action is allowed; Flip and Color act only when enabled.
- Targets never pick up or move the piece. Show them by pulsing the target tile
  background, not by a solid ghost piece or a surrounding highlight frame.
- Button highlights pulse the face from its normal color to white and back,
  with a 1.4-second cycle. Rotation, flip, and recolor teaching animations take
  0.32 seconds; advance only after the requested operation finishes.
- Accepting a correct placement advances immediately, without an added delay.
  Failed attempts never commit tiles or consume a joker.

## Lesson sequence and exact cues

The displayed sequence has nine cards. Internal IDs below are migration
references only. The first static introduction card and the separate animated
axes demonstration must not return.

| Card | Current internal ID | Exact cue | Required behavior |
| --- | --- | --- | --- |
| 1/9 | 2 | Tap the piece to rotate it. | Offer one stationary L. Allow rotation only; advance after one completed rotation. |
| 2/9 | 3 | Press Flip to mirror it. | Retain the same L and board. Pulse Flip; advance after its animation. |
| 3/9 | 4 | Press Color to choose its color. | Retain the same L and board. Pulse Color; change logical color 1 to 2 and advance after its animation. |
| 4/9 | 5 | Drag the piece into position and press Place. | Retain the prepared L and board. Pulse Place only at the exact solution. A wrong attempt leaves this card unchanged. |
| 5/9 | 6 | Complete the vertical symmetry. | New 5×5 exercise; allow rotation, flip, recolor, and dragging. |
| 6/9 | 7 | Complete the horizontal symmetry. | Same interaction rules, with the horizontal fixture. |
| 7/9 | 8 | Complete the rotational symmetry. | Same interaction rules, with the half-turn fixture. |
| 8/9 | 10 | See repair sequence below. | Full-size 9×9 exercise with real predictive axis feedback. |
| 9/9 | 11 | From simple tiles to intricate worlds. | Reveal the completed Vines pattern on the preceding Hint/Save press, save it, and hand control to the normal game. No timed construction replay or required reading pause. |

Cards 1–4 use one incomplete pattern. One rotation, one flip, and one color
change prepare its solution; do not substitute a new piece between those cards.
Their target is visible. Cards 5–7 initially have no target hint. A wrong Place
attempt reveals a fixed pulsing target while leaving the committed board intact.
Subsequent manipulation remains free. Only Place pulses at the exact solution;
Hint/Save never pulses in these exercises.

## Axes

- Cards 1–7 always display the requested teaching axis, including while the
  floating piece is incorrectly positioned. It is a fixed faint teaching guide,
  not a predictive hint. The symmetry button stays neutral.
- Card 8 uses all seven symmetry states and the same shared visual vocabulary
  as the game: faint/thin for possible, bold/thick for present, absent for
  impossible. Possibility never assumes that a joker will be used.
- Moving the floating piece updates card 8's prediction without changing the
  committed board. A colliding preview must not enable Place. Preserve the
  tutorial's visible-overlay feedback until the shared invalid-preview policy
  is explicitly resolved during the refactor.
- The Hint/Save button must not pulse anywhere before the final “Bold axis!”
  substep. Correct target placement alone pulses Place; no early Hint highlight.

## Card 8: destroy and repair

Coordinates below are zero-based `(column,row)` from the top left. Logical
colors 1 and 2 retain the theme's original tile colors. Keep the board colored
and interactive even after all possible axes disappear.

| Substep | Exact text | Action and result |
| --- | --- | --- |
| Wrong placement | The hint button shows achievable symmetries. Make an asymmetric placement and the game ends. | The wrong color-2 L is already placed. Offer the color-1 Dot. Allow free manipulation; enable and pulse Place only for `(6,2)` in color 1. Committing it removes every possible axis. |
| Undo | Header: Save the pattern; next line: Undo your last move. | Pulse and enable Undo. It removes only the Dot and consumes one Undo. The wrong L remains. This is the only occurrence of the header. |
| Erase | Erase a square. | Pulse and enable Erase. After activation, accept only the marked square `(1,1)`; remove it and consume one Erase. Do not add the deleted “Press Erase…” sentence. |
| Replacement | Get a different piece. | Present the unsuitable horizontal color-2 I3. Pulse and enable the replacement joker. Consuming it supplies the horizontal color-2 Domino. Do not add “Press the arrow joker.” |
| Place replacement | Get a different piece. | Keep the previous text. The Domino appears at the I3's exact center. Allow manipulation; enable and pulse Place only for the color-2 Domino at `(6,2)`. Hint does not pulse. |
| Save | Bold axis! Your board is symmetrical right now. Save a picture and continue playing. | The completed vertical symmetry is bold. Pulse Hint/Save and wait indefinitely for its press. No timer starts the reveal. |

Wrong L fixture: color 2 at `(1,1)`, `(1,2)`, `(2,2)`. This is present when
the card opens; the player is not asked to place it again. Each guided joker is
used once, reducing its counter from 3 to 2. Out-of-order actions and incorrect
targets do not advance the lesson.

## Canonical pattern fixtures

Keep these fixtures independent of the refactored controller's representation.
Current builders in `scripts/tutorial_model.gd` are useful comparison oracles,
not a requirement to retain their APIs.

- Cards 1–4: color-1 center `(2,2)` and color-2 cells `(0,1)`, `(0,2)`, `(1,2)`.
  The missing color-2 L occupies `(4,1)`, `(4,2)`, `(3,2)`.
- Card 5: color-1 center `(2,2)` and color-2 motif `(0,1)`, `(0,2)`, `(0,3)`,
  `(1,3)`. Complete its vertical reflection.
- Card 6: color-1 center `(2,2)` and color-2 motif `(1,0)`, `(2,0)`, `(3,0)`,
  `(1,1)`. Complete its horizontal reflection.
- Card 7: the card-5 starting motif and center, completed by a 180° rotation.
- Card 8 base: color-1 center `(4,4)`, followed by the nine placements below.
  Add the wrong L above before offering the Dot.

| Order | Color | Absolute cells |
| --- | --- | --- |
| 1 | 1 | `(3,3)`, `(4,3)`, `(3,4)` |
| 2 | 1 | `(5,3)`, `(5,4)` |
| 3 | 1 | `(3,5)`, `(4,5)`, `(5,5)` |
| 4 | 1 | `(4,1)`, `(4,2)` |
| 5 | 1 | `(2,1)`, `(3,1)` |
| 6 | 1 | `(5,1)`, `(6,1)` |
| 7 | 1 | `(4,6)`, `(4,7)` |
| 8 | 1 | `(1,7)`, `(2,7)`, `(3,7)` |
| 9 | 1 | `(5,7)`, `(6,7)`, `(7,7)` |

The final playable/artwork board is exactly this base plus color-2 cells
`(1,2)`, `(2,2)`, `(6,2)`, `(7,2)`. It has complete vertical symmetry and
same-color 2×2 formations. Both colors must survive the reveal.

## Reveal, save, and handoff

- Before the final Hint/Save press, remain on the colored repaired board.
- On that press, reveal the entire matching Vines artwork in one action using
  settled rendering, including eligible higher-tier artwork. No sequential
  placements, growth waiting periods, or red exercise backgrounds remain.
- Save the completed Vines board through the normal gallery capture path.
  Acceptance requires a readable 900×900 PNG and its gallery record with the
  exact board, Vines theme, and normal save fingerprint; calling a save method
  alone is insufficient. This means the in-game gallery, not automatic export
  to the phone's public photo library or a sharing application.
- Restore ordinary controls and their icons immediately at handoff. Normal
  physical-placement, game-over, joker-count, and save-in-progress restrictions
  still apply; “restore controls” does not bypass those restrictions.
- The final board becomes a valid, saveable/resumable normal 9×9 game. Settings
  opens, the next offered piece can be manipulated, and legal placement works.
- Exiting before the final reveal preserves the player's underlying game.
  Practice must not consume its jokers or mutate its committed tiles. Final
  reveal intentionally creates the demonstrated Vines game.

## Launch, compatibility, and audit gaps

Existing launch behavior: unfinished first-run introductions open automatically;
completed introductions do not. A returning player with an existing game and no
previous introduction record is not forced into it. Tutorial remains available
from Settings, opens directly on Rotate, and can be ended without finishing.

Preserve the meaning of old saved stages when migrating: old stage 1 opens
Rotate, old stage 9 opens the repair lesson, and stage 11 opens the final design.
Do not resurrect deleted cards to preserve numeric IDs.

The following are audit gaps to address in later steps, not behavior to freeze:

- Repair substeps currently restart at the beginning of card 8 after relaunch;
  exact checkpoint persistence is not yet implemented.
- Invalid-hover prediction differs between tutorial and normal gameplay. Keep
  the explicit early teaching-axis exception; define a shared invalid-hover
  policy before replacing either predictor.
- Touch cancellation, long-press behavior, unexpected teardown, and save failure
  recovery need targeted checks. Existing duplication is not an acceptance rule.
- Tutorial completion is currently recorded before gallery success. The success
  criterion above is real image persistence; failure/retry handling belongs to
  the later save-flow work.
- Old replay names, phase numbers, global tree pausing, and the unused underlay
  renderer can be removed without changing this player-facing contract.

## Verification gate for subsequent refactor steps

Use `tests/test_introduction.gd` as the existing regression suite. Its many
assertions are not a substitute for native rendering or actual touch coverage.
Keep the acceptance behavior above while replacing assertions tied only to
obsolete internals.

Verify layout at 320×568, 390×844, 540×825, and 720×1100 logical sizes. Check
mouse and touch, tray-to-board dragging, tap rotation, frame clearance, target
hit testing, pulse timing, fixed early axes, predictive repair axes, and immediate
placement response. Use a graphics-enabled run for the gallery PNG check;
headless tests alone cannot certify rendered image persistence.

Each later implementation step must leave the tutorial playable, preserve the
canonical final board, restore the real UI, and keep its source changes separate
from this documentation baseline.

Baseline verification on 2026-11-21: Godot 4.6.3, graphics-enabled X11 run of
`tests/test_introduction.gd`, 1,158 checks and zero failures, including the real
900×900 gallery PNG and metadata checks. The software graphics driver reported
unsupported V-Sync; this did not prevent rendering or saving. This run does not
close the separate touch, lifecycle, persistence, and failure-path audit gaps.
