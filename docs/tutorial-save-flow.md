# Coordinated reveal, save, and handoff (refactor step 7)

Card 7 still requires Hint/Save. It assembles the matching pattern through
shared game commands and requests a real gallery save in the current theme.
Card 8 keeps the plain colored tiles visible and enables Settings → Themes only
after that save succeeds. Selecting a theme reveals its artwork, preserves the
board and move history, and resumes normal play. No theme is selected
automatically when entering card 8.

## Shared save API

Normal play and tutorial call `Main.save_current_design()`. This is an awaitable
operation returning a result dictionary. `design_save_finished(result)` reports
terminal attempts, with `ok`, `status`, `fingerprint`, `session_id`, and a gallery
`id` when saved. Duplicate requests return `busy` without another completion
event or capture; the active job continues normally.

`ArtworkCapture.render` owns clean 900×900 rendering, including the frame,
complete background, established leaf directions, construction state, and
theme-specific artwork ordering/motion. Its viewport is a child of the requesting
scene. Removing the owner cancels the capture and its temporary viewport.
Headless rendering fails explicitly instead of waiting forever for a draw.

Before writing, the main controller checks the current game instance and design
fingerprint against the capture snapshot. A reset or theme/board change cancels
an obsolete capture. It cannot mark a newer game saved or commit mismatched art.

Capture/storage failures release the busy state. Normal gameplay shows a short
failure dialog and permits another save. Unavailable actions and cancelled jobs
do not show a storage-error dialog. Save is disabled during growth, so its UI
does not invite a capture before the artwork is ready.

## Tutorial states

| State | Behavior |
| --- | --- |
| `waiting` | An earlier job owns the save slot. Wait for it to finish, then request the reveal's own capture. |
| `saving` | Reveal remains visible; Settings and theme completion stay blocked. |
| `failed` | Show “Couldn't save the picture. Press Save to retry.” Pulse the existing Hint/Save control. |
| `saved` | Mark the save indicator, restore the normal card-8 caption, and highlight Settings followed by Themes. |

Only a result for the expected session and fingerprint changes these states.
Closing the tutorial disconnects its listener; late results cannot resurrect
guidance. Explicit End Tutorial remains available as before.

Progress stays unfinished through failure, retry, and successful saving until a
theme is chosen (or the player explicitly ends the tutorial). Resume retains the
v2 lesson checkpoint and requests a save again; normal gallery fingerprint
deduplication reuses an already-saved entry. No save-status schema migration is
needed and no deleted cards return.

## Storage commit

Gallery writes a temporary PNG and temporary JSON metadata, flushes metadata,
and checks errors. It commits the PNG first and JSON last. JSON is the visible
entry marker, so interrupted or failed writes do not expose a half-written entry.
Known temporary files are removed on reported failures. Existing valid entries
still deduplicate, and successful metadata retains its original format.

This is the in-game gallery. Public phone-photo export and sharing retain their
separate existing controls.

## Verification

`tests/test_tutorial_save_flow.gd` injects storage and capture failures, exercises
real filesystem failure, retry, confirmed PNG/metadata persistence, busy requests,
stale snapshots, waiting behind an earlier job, exit during saving, and real
viewport-owner deletion. Headless tests use an explicit fixture image; the native
tests and full tutorial regression also exercise the actual renderer.

Additional native gallery-completion checks cover all three active themes at
9×9 and 11×11, opaque completed backgrounds, correct metadata, and deduplication.
The full tutorial regression retains its 1,256 checks, including actual gallery
images and theme selection. Gallery and gallery-export unit checks also pass.

Verified with Godot 4.6.3 on 2026-11-21: 27 native save-flow checks, 1,256 native
tutorial checks, 78 native gallery-completion checks, 19 gallery checks, 34
gallery-export checks, 22 lifecycle checks, 18 session checks, and 25 predictive
symmetry checks; zero assertion failures. Real capture-owner and main-scene
deletion were included, with no script errors on cancellation.

[Step 8](tutorial-cleanup.md) removes the obsolete replay renderer and runtime numeric adapters.
