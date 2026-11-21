# Shared player actions (refactor step 3)

`scripts/player_actions.gd` is the command entry point for `rotate`, `flip`,
`color`, `place`, `undo`, `erase`, and `skip`. The main game owns one instance;
normal controls and the tutorial use that same instance.

## Command contract

`execute(action, game, request, policy)` first checks that the action is
known, then evaluates the optional policy. Rejection changes no
game state, and emits no success event.

| Command | Request | Result/effect |
| --- | --- | --- |
| `rotate`, `flip` | `cells` | Return transformed cells without changing the input array. |
| `color` | `color`; optional `choice` | Return an explicit color, or toggle between 1 and 2. |
| `place` | `cells`, `anchor` | Call the real game's placement method. A physically valid symmetry-breaking move still succeeds and can end the game. |
| `undo` | none | Call real Undo, including its history and joker accounting. |
| `erase` | `cell` | Call real Erase, including recovery after game over. |
| `skip` | optional `replacement` | Call real Skip; an omitted replacement keeps the existing random draw behavior. |

Results include `ok` and `action`, plus command-specific fields and any domain
failure reason. Successful commands emit `completed(action, result)` once, with
a copied result. `source` defaults to `player`; final design assembly explicitly
uses `scenario`, so later guidance can distinguish setup from player input.
`session_id` identifies the runtime game that completed the command; tutorial
guidance filters events against its active practice session.

Transforms return presentation state: the caller applies the returned cells or
color to its active view/session. A completion event reports the command result;
it does not mean a rendered frame or later artwork animation has finished.

The executor receives the active game on every call. It does not cache a game
reference that could become stale after reset, session restore, or handoff.

## Main-game integration

Buttons, tap rotation, and keyboard actions enter through
`main.gd::_request_player_action`. Its policy blocks actions during saving and
enforces the existing placement/growth/tool constraints. The domain game still
owns physical validity, symmetry loss, history, counters, and random selection.

Choosing the erase tool is UI state, not an Erase command. Only choosing a square
executes the shared `erase` command. Board drawing, audio, gesture recognition,
and post-action refresh remain outside the executor.

## Tutorial integration and scope boundary

Tutorial lesson actions and required targets are policy gates before execution.
Rotate, Flip, and Color retain their 0.32-second teaching animations; the shared
command runs and emits completion only when that animation finishes. A rejected
early placement can reveal its target without committing any tiles.

The tutorial now uses an [isolated real practice game](tutorial-practice.md)
following step 4. The temporary backend hook and fixture-based mutations have
been removed. [Step 5](tutorial-interaction.md) now shares gestures and preview
geometry as well.

Card 8's Settings → Themes selection and the real gallery save from card 7 remain
the behavior described in [tutorial progress](tutorial-progress.md).

## Deterministic offers

`PlayerActions.offer(game, name, color)` uses `TileGame.offer_piece`, rather than
allowing tutorial UI code to edit queue internals. It validates the shape against
difficulty and physical availability, clears restored orientation state, and
updates availability. It consumes no move or joker and emits no player-action
completion event.

`TileGame.skip(replacement)` optionally accepts a named replacement for later
guided practice. It uses the real Skip counter and rejects unavailable shapes
or the same explicitly requested shape before changing the queue or RNG state.
Calling `skip()` without an argument preserves ordinary random behavior.

## Verification

`tests/test_player_actions.gd` checks policy rejection, result/event behavior,
input validation, deterministic offers, unchanged seeded random Skip behavior,
and the complete break → Undo → Erase → replacement → restore sequence using a
real game. The graphics-enabled tutorial suite checks delayed transform
completion through the shared executor and preserves the full existing flow,
gallery output, and all three theme choices.

Verified on 2026-11-21 with Godot 4.6.3: 35 action checks, 162 progress checks,
1,239 graphics-enabled tutorial checks, 721 rules checks, 18 session checks,
23 predictive-symmetry checks, and 75 preview/color checks; zero failures.
