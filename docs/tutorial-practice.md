# Isolated real practice sessions (refactor step 4)

The tutorial now owns a separate `TileGame` during practice. The player's live
`host.game` remains untouched until the intentional final artwork reveal.
Practice uses the shared `PlayerActions` executor with the same real placement,
Undo, Erase, and Skip implementations as ordinary play. The temporary command
backend and simulated board/joker transitions have been removed.

## Session setup

`TileGame` accepts an optional initial board, copies its rows, and computes its
ordinary game state from that board. Its existing three-argument constructor
retains the normal starting-core behavior.

`TutorialModel.practice_session` creates deterministic scenario sessions:

- The preparation operations share one 5×5 session. Rotation/flip retain their
  presentation orientation; color updates the practice game's selected color.
- Each subsequent symmetry exercise starts its own 5×5 session from the lesson
  fixture. Its piece is identified from the existing Rules shape catalog, and
  its solution passes real contact and symmetry checks.
- The repair exercise starts from the canonical 9×9 base and places the wrong L
  through the real game. Its history then contains the L before the player
  places the Dot. A fixed RNG seed keeps checkpoint reconstruction deterministic.

Practice uses the normal Hard rules, including contact, to support the exercises'
four-cell pieces. Lesson policy restricts permitted operations and exact targets;
it does not weaken the normal game's placement rules.

## Interaction and resume

During repair, the same game instance survives every action. Placing the Dot
really sets game-over/lost state. Undo removes its last history record and
restores its color/orientation. Erase removes the marked L square. An explicit
scenario offer supplies I3, then real `skip("Domino")` spends the Skip joker and
provides the replacement. Placing it restores the canonical vertical symmetry.

The UI reads real joker counters. The board displayed by the existing tutorial
renderer is a snapshot of the practice board, not a board synthesized for each
phase. Failed lesson placements can reveal a target but never execute a game
mutation or consume a helper.

Only initial entry or resume builds a checkpoint. Resume replays real scenario
actions to reconstruct its board, history, loss state, selected offer, and joker
usage. Normal advancement updates presentation from the existing session.
The named checkpoints and v2 progress format are unchanged.

## Isolation and handoff

Practice never passes its 5×5 game to normal session persistence and never replaces
the live board, queue, difficulty, history, counters, or random state. Ending
practice restores the existing game. The deliberate final reveal still creates
the demonstrated normal 9×9 Vines game, saves its artwork, and guides Settings →
Themes selection before resuming play in the chosen theme.

[Gesture/preview sharing](tutorial-interaction.md) is implemented in step 5.
[Tutorial lifecycle cleanup](tutorial-guidance.md) is implemented in step 6.
[Save-result coordination](tutorial-save-flow.md) is implemented in step 7.
[Step 8](tutorial-cleanup.md) removes the obsolete replay renderer and runtime numeric adapters.

## Verification

`tests/test_tutorial_practice.gd` checks source-board isolation, every early
solution against real rules, all repair checkpoint states/counters, and a full
repair on one game instance while protecting every field of a separate live
game. The native tutorial suite checks the same instance across player actions,
real loss/history/counters, checkpoint reconstruction, live-session preservation,
gallery saving, and all three final theme choices.

Verified on 2026-11-21 with Godot 4.6.3: 72 practice checks, 1,251
graphics-enabled tutorial checks, 35 shared-action checks, 162 progress checks,
721 rules checks, and 18 session checks; zero failures.
