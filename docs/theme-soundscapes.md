# Shared event soundscapes

Vines and Clockwork use the supplied ASMR WAVs through `scripts/theme_soundscape.gd`. Coral retains its existing soundscape. The old foliage whisper, flower bell, workshop ticking and workshop cue playback are suppressed for the two new soundscapes, so they cannot double up.

Each theme's `soundscape` object in `assets/themes/themes.json` defines an ambience path/gain and three tier paths/gains/coalescing intervals. Any theme with this configuration uses the shared engine. The original game WAVs are preserved in `assets/audio/vines_asmr` and `assets/audio/clockwork_asmr`, alongside the source README. Preview MP3s are not game assets. No preview gain boost or pitch alteration is applied.

The 72-second ambience loops continuously while its theme is selected, including idle periods. It stops on theme changes. Effects follow the board's visual clock: Vines tier one uses new growth-cell arrivals; Clockwork uses new T01 pipe assembly starts; tier two uses formation starts; tier three uses butterfly connection or chain starts. Settled boards do not replay cues. Canceled/undone construction clears pending effects; dismantling does not play forward construction sounds. Stable per-placement identities prevent duplicate cues during reconciliation.

Close events are coalesced per tier (1 second for tier one, 0.35 seconds for tier two/three). Each tier has one voice, allowing different tiers to overlap while an already playing one-shot finishes without being restarted. Same-tier cues that arrive while its voice is busy are consumed, not delayed to an unrelated later moment. This bounds dense-board audio volume and keeps sound tied to visible activity. Audio never extends construction or disables placement.

The existing **Background noises** setting mutes the ambience bus. **Special effects** independently mutes tier cues. Both use the same settings controls and buses already used elsewhere in the game; Coral routing is unchanged. Pausing the scene tree pauses players and prevents clock dispatch.

Validation: `tests/test_theme_soundscape.gd` covers both theme plans, three tier triggers, 72-second loops, bus routing, independent toggles, visual-clock dispatch, settled restoration, cancellation, no legacy doubling and switching to Coral. `tests/test_coral_audio.gd` verifies the existing reef soundscape still passes.
