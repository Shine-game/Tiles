# Shared gestures, geometry, and previews (refactor step 5)

The main game and tutorial now use the same interaction primitives. The tutorial
retains its lesson policies, captions, targets, flat tiles, and teaching axes.

## Pointer handling

`scripts/piece_gesture.gd` owns mouse/touch normalization and one active pointer.
Both views use its `handle` method, supplying a view-specific target picker and
consuming its result through the shared player-action interface.

- Tap: release within 0.25 seconds without crossing the 10-pixel drag threshold.
- Hold: staying still beyond that limit does not rotate. Moving afterwards still
  starts a drag.
- Drag: preserve the grabbed cell's offset; release leaves a floating piece and
  never places it automatically.
- Touch cancellation never rotates or performs a final movement/erase. A second
  pointer cannot steal or release an active gesture. Any first touch ID works.
- Touch-emulated mouse input and non-left mouse buttons are ignored.
- Erase: select on press and confirm on release over the same square. The real
  game/lesson policy then decides whether erasure is permitted.

Buttons have priority over piece pickup. Empty cells, targets, and piece holes
cannot pick up a piece. Only context picking, board-coordinate conversion, and
lesson/normal-game UI responses remain view-specific.

## Piece presentation and geometry

`scripts/piece_geometry.gd` owns extent, horizontal offer orientation, tray layout,
cell hit tests, floor rounding, and anchor offsets. `PieceView`, `FloatingPiece`,
the main controller, and tutorial use these functions.

Tall rotations keep the normal cell size and can extend down over the board.
Dragging may leave an invalid floating anchor in either mode; it does not clamp
the piece into a different position. Raised game tiles still account for their
surface lift when mapping input. Tutorial tiles remain flat.

`TileSurface.draw_piece` supports the tutorial's flat mode using the same cell
geometry; its normal raised renderer is unchanged. Pulsing target tiles use the
same flat-tile primitive.

## One preview policy

`scripts/placement_preview.gd` overlays visible floating cells onto a copy of the
committed board. Overlap uses the floating color, and out-of-board cells are
clipped. This resolves the audit's divergent invalid-hover behavior: the main
game now matches the tutorial's visible-overlay prediction.

Prediction does not permit placement or saving. Real physical rules and the
committed board remain authoritative. Removing hover or entering normal erase
mode restores committed-board prediction. Early tutorial exercises deliberately
keep their fixed faint teaching axis; predictive axes start in the later lesson.

## Verification

Verified with Godot 4.6.3 on 2026-11-21:

- 25 focused interaction checks: geometry, mouse/touch, pointer identity,
  cancellation, long holds, erase release, and nonmutating clipped previews.
- 1,256 graphics-enabled tutorial checks, including native nonzero touch IDs,
  cancellation, long holds, the real gallery save, and all three theme choices.
- 2,019 layout/gesture checks, 75 preview/color checks, 25 predictive-symmetry
  checks, 61 frame checks, and 19 sound/depth checks: zero failures.

The older `tests/test_ui.gd` headless run has 492 checks and 25 failures. An
isolated run of the pushed baseline `e4ce98a` produced the exact same failure
messages in the same order. These pre-existing menu/palette/native-button test
failures were not changed or concealed as part of this refactor.

[Step 6](tutorial-guidance.md) implements lesson/event coordination and lifecycle
cleanup. [Step 7](tutorial-save-flow.md) coordinates save results. Obsolete
rendering removal remains the final refactor step.

The obsolete broad UI expectations described above were replaced in
[step 8](tutorial-cleanup.md); both native and headless UI runs now pass.
