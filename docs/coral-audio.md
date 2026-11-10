# Coral Reef audio

Integrated from `Coral_Reef_Audio_01.zip`. The archive's integration notes informed the event mapping; its scripts were not executed. All 27 supplied checksums verified. The nine runtime Ogg files are unchanged; source recordings and supplied review media are not exported. See [audit](coral-audio-audit.json) and the supplied [rights/provenance note](coral-audio-rights.md).

| Event | Assets | Gain and envelope |
| --- | --- | --- |
| Coral theme active, including idle | `reef_ambience` | −5 dB; loop, 1.5 s entrance / 600 ms exit |
| First through last visible ordinary component | `growth_01…03` | −3 dB; loop, 25 ms entrance / 80 ms exit |
| New colony body begins | `bubble_short_01…03` | −2 dB; one shot |
| New anemone foot begins | `bubble_long_01…02` | −2 dB; one shot |

Metadata lives under `audio` in `art/themes/coral_reef/theme.json`. Growth chooses placement ID modulo three. Feature cues use unsigned FNV-1a over newline-separated sorted feature keys, avoiding immediate variant repeats. Same-kind feature starts within 120 ms of a group's first start coalesce, with no onset delay. Both player colors share the sounds.

The pool allows one ambience, two growth and two feature voices. Anemones can replace colony cues with a 30 ms fade; other excess cues are dropped. Features duck ambience once by 2 dB, with 40 ms attack and 250 ms release. A private theme bus feeds Master and adds a −1 dB limiter only if Master has none. Existing Master routing and other themes' foliage/bells remain intact.

Undo/erase settle surviving visuals, cancel ordinary construction and future cues, and preserve playing feature tails while any coalesced member remains valid. Invalid feature tails fade over 80 ms. Reset and theme changes invalidate delayed replacements and fade out theme voices. Entering a settled reef starts ambience without replaying construction. Pause freezes players and dispatch together. Audio never changes the visual clock or Place gate; bubble tails can continue afterward.

Run `tests/test_coral_audio.gd` with Godot 4.7.2 and Dummy audio for state, scheduling, cancellation, pause and cleanup checks. This does not measure Android audio latency or phone speaker balance.

For a graphical review, run `tests/render_coral.gd` on a display, then `python3 tools/mix_coral_preview.py`. The latter reconstructs audio from the game's dispatched event log and unchanged clips; it is an offline review mix, not a device audio recording. Mux `build/coral-audio.wav` with the captured 30 fps PNG sequence. Preview tools and outputs are excluded from Android export.
