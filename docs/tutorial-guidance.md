# Event-driven guidance and scoped UI ownership (refactor step 6)

The tutorial coordinates lesson definitions, action policy, targets, highlights,
and presentation. Shared actions own game commands, isolated practice games own
history/counters, and shared gesture/geometry helpers own pointer interpretation.

## Progression

Successful `PlayerActions` results now include a transient `session_id` alongside
`source`. The tutorial subscribes to command completion and accepts only player
actions from its current practice game that are permitted by its lesson.
Scenario assembly, other game sessions, failed commands, and obsolete callbacks
cannot advance a lesson.

The completion handler applies returned transform presentation and moves to the
next definition. Teaching animations still finish before executing their command.
The request wrappers no longer independently advance the same lesson a second
time. These instance IDs are runtime routing data, not persisted progress keys.

## UI ownership and teardown

`scripts/tutorial_ui_scope.gd` captures the controls, named icons, source-piece
visibility, board process mode, and any final theme-menu overrides it owns.
Restore is idempotent and handles missing/freed controls safely.

Normal completion, End Tutorial, and unexpected removal share one release path:
cancel the gesture, restore pulse styles and owned UI state, disconnect host/action
signals, and release the host's active-tutorial reference. Normal completion
refreshes the game immediately; unexpected removal defers that refresh until tree
removal is finished. The host checks that no replacement tutorial has started
before applying a deferred refresh.

Unexpected removal preserves the unfinished progress checkpoint. Explicit exit
and successful completion retain their existing completion behavior. Deleting the
host during practice is safe; cleanup does not rebuild a host already being freed.

Main controls expose named `ControlIcon` children so tutorial ownership does not
depend on icon child order. The final Settings → Themes path uses the same scope
and normal menu code.

## Processing

The tutorial never writes `SceneTree.paused`. It freezes only existing board
artwork during practice and routes game input through the tutorial's action
policy. Other application nodes and ambience remain able to process. Any pause
set by another part of the application remains unchanged after tutorial exit.
The normal main-game pointer updater is inactive while guidance owns input.

Guidance updates when a lesson, action, selection, layout, or host interface state
changes. Symmetry states are cached for drawing. Idle pulse frames update pulse
brightness and the relevant drawing without repeating board symmetry scans or
rewriting button enablement. Host menu/style/save-state notifications invalidate
the cache when needed; normal play does not need a tutorial callback each frame.

## Verification

`tests/test_tutorial_lifecycle.gd` verifies 22 cases covering non-paused background
processing, idle caching, scoped completion events, external pauses, unexpected
removal, subscription cleanup, repeated exit, replacement before old-node removal,
menu restoration, host deletion, and live-session preservation.

The graphics-enabled tutorial regression retains its 1,256 checks, including
the real gallery image and all three theme choices. Additional passing suites:
2,019 layout/gesture checks, 36 action checks, 72 practice checks, 162 progress
checks, 25 interaction checks, and 18 session checks. The legacy broad UI suite's
pre-existing baseline failures remain documented in
[step 5](tutorial-interaction.md).

A verbose native shutdown check identified the remaining resource warnings as
Clockwork ambient/tier-3 Ogg playback references; it did not report leaked
tutorial scopes or UI nodes. Audio-engine shutdown cleanup is outside this step.

[Step 7](tutorial-save-flow.md) coordinates gallery success/failure and handoff.
Obsolete replay rendering and remaining legacy adapters are removed in step 8.
