# Shared event soundscapes

Vines and Clockwork use the supplied ASMR WAVs through `scripts/theme_soundscape.gd`. Coral retains its existing soundscape. The old foliage whisper, flower bell, workshop ticking and workshop cue playback are suppressed for the two new soundscapes, so they cannot double up.

Each theme's `soundscape` object in `assets/themes/themes.json` defines an ambience path/gain and three tier paths/gains/coalescing intervals. Any theme with this configuration uses the shared engine. The original game WAVs are preserved in `assets/audio/vines_asmr` and `assets/audio/clockwork_asmr`, alongside the source README. Preview MP3s are not game assets. No preview gain boost or pitch alteration is applied.

Each supplied ambience loops continuously while its theme is selected, including idle periods. It stops on theme changes. Effects follow the board's visual clock: Vines tier one uses new growth-cell arrivals; Clockwork uses new T01 pipe assembly starts; tier two uses formation starts; tier three uses butterfly connection or chain starts. Settled boards do not replay cues. Canceled/undone construction clears pending effects; dismantling does not play forward construction sounds. Stable per-placement identities prevent duplicate cues during reconciliation.

Close events are coalesced per tier (1 second for tier one, 0.35 seconds for tier two/three). Each tier has one voice, allowing different tiers to overlap while an already playing one-shot finishes without being restarted. Same-tier cues that arrive while its voice is busy are consumed, not delayed to an unrelated later moment. This bounds dense-board audio volume and keeps sound tied to visible activity. Audio never extends construction or disables placement.

The existing **Background noises** setting mutes the ambience bus. **Special effects** independently mutes tier cues. Both use the same settings controls and buses already used elsewhere in the game; Coral routing is unchanged. Pausing the scene tree pauses players and prevents clock dispatch.

Validation: `tests/test_theme_soundscape.gd` covers both theme plans, three tier triggers, 72-second loops, bus routing, independent toggles, visual-clock dispatch, settled restoration, cancellation, no legacy doubling and switching to Coral. `tests/test_coral_audio.gd` verifies the existing reef soundscape still passes.

## Updated vines recordings and per-theme timing

Vines now selects the five OGG recordings supplied in `Vines_Sound_Effects.zip`. Their original bytes are retained in `assets/audio/vines_effects`. The 15-second OGG ambience loops through the same background bus; the generic player also accepts WAV and MP3 loops.

`loudness.json` records FFmpeg integrated-loudness and true-peak measurements. Runtime gains balance individual effects to approximately −24 LUFS and ambience to −30 LUFS, capped for at least 3 dB of peak headroom. This raises the particularly quiet butterfly chime without boosting the ambience over the effects. No frequency equalization or pitch shift is applied.

The uploaded combined recording contains the bloom at 0 seconds and the butterfly sound at 1.98 seconds (verified against the separate clips). Existing visual timing is preserved: flowers fade in over 0.25 seconds and the butterfly follows. `Vines_Bloom_Butterflies_aligned.wav` reconstructs that same bloom/chime combination from the supplied component recordings, balances their individual loudness, and moves the chime to 0.25 seconds. The original combined OGG is kept unchanged.

Each tier supports `offset_seconds` (visual-event to playback delay), `seek_seconds` (skip leading audio) and `coalesce_seconds`, in addition to `path` and `gain_db`. An optional `combined` object adds those fields plus `tier3_offset_seconds` and `tolerance_seconds`. The main scheduler only replaces a related bloom/butterfly pair with the combined clip if their scheduled timing matches its internal marker. Otherwise it plays the individual effects on their own visual events. The combined cue replaces both separate cues, avoiding doubled bloom/chime playback. `connection_origin_offset` maps connection members to formation origins; Vines uses [1,1], Clockwork defaults to [0,0].

The active vines configuration uses a 0.25-second internal marker and 0.05-second tolerance. Combined cues use their own effects voice and the same effects mute bus. Tests in `test_soundscape_combined.gd` verify matching pairs, mismatched timing, unrelated formations, and actual tier-three onset against model timing. Clockwork remains on its existing individual files, and Coral retains its existing audio engine.

## Sound settings volume controls

Sound Settings contains independent **Ambience volume** and **Effects volume** sliders from 0 to 100%, with live percentage readouts. They adjust the existing shared background/effects buses for every theme, including Coral, rather than changing individual clips' calibrated gains. 100% preserves the balanced mix; 0% is silent. Existing on/off buttons remain independent and retain the selected level when toggled.

Levels and mute flags persist in `user://sound_settings.cfg`. The volume APIs accept linear values between 0 and 1 and clamp out-of-range inputs. `tests/test_sound_volume.gd` verifies bus gain, mute/zero interactions, settings restoration and the UI callbacks.

## Coral short-bubble bursts

Tier three now selects only `bubble_long_02`. Tier two retains the three short-bubble source variants but plays a seeded 5–6-shot asynchronous mix over the colony animation. Each burst starts with the first visible colony pixels, avoids consecutive identical clips, distributes irregular onsets across the animation window, and fades out over 40 ms at its visual end. Simultaneous nearby colonies retain the existing coalescing policy and share a burst spanning their combined visual window.

Each existing feature voice can mix up to six overlapping shots through `AudioStreamPolyphonic`, at a −6 dB mix gain plus the source clip gain. It retains the Coral limiter and routes through the effects volume/mute bus. Short clips do not restart each other, burst tails do not extend placement, and cancellation clears future shots. The timing plan uses colony completion, including the radial petals. Pause uses the visual clock and pauses the same player. Tests in `test_coral_bubble_bursts.gd` verify counts, variations, stagger, bounded timing, overlapping playback and completion for both colors.

## Rustle duration follows tier-one growth

Vines tier one uses `stop_at_tier_end: true` and `fade_out_seconds: 0.04`. The shared scheduler calculates tier one's actual end from new stem edges, cell arrivals and the authored sprite-decoration growth events. It fades the rustle over the last 40 ms of that visual interval and stops it at the end, even if the original recording is longer. Tier-two/three animation and ambience do not prolong it. This is a runtime trim; the supplied source recording remains unchanged. Clockwork keeps its existing one-shot behavior because the option is enabled only for Vines.

`tests/test_vines_rustle_duration.gd` covers short, medium and long patterns, the fade envelope, exact cutoff, and continued later-tier animation/ambience.
