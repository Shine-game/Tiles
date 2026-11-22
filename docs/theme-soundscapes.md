# Audio design

Each active theme uses exactly two OGG files in `assets/audio/<theme>/`:
`<theme>_ambient.ogg` and `<theme>_place_click.ogg`.

The source is the user-supplied `audio.rar`. The three ambience recordings are
byte-for-byte unchanged, with their existing loop settings and gains: Clockwork
0 dB, Vines −9.52 dB, and Coral −5 dB with its 1.5-second fade-in. Coral's supplied
`coral_place_click.ogg` is named `coral_reef_place_click.ogg` for consistency.
The Vines MP3 click was converted to Vorbis quality 5. The other OGG clicks were
copied without processing. `docs/asset-inventory/audio-provenance.json` records SHA-256 hashes.

`ThemeAudio` owns one ambience player and one non-looping click player. It
listens to the shared player-action completion signal and clicks once for an
accepted `place` action from a player. Rejected placement, rotation, recoloring,
helpers, restore, gallery rendering, and scripted tutorial assembly are silent.
All growth/tier players, event schedulers, looping structure effects, fallback
libraries, old recordings, generators, and growth-audio audition tools have been
removed. Nested old libraries from the RAR are not imported.

Theme configuration in `assets/themes/themes.json` contains only `ambience` and
`place` paths/gains. Ambience and effects still use separate volume buses and
retain their saved mute/volume settings, including phone touch controls. Theme
changes stop the previous recordings; ordinary visual updates do not restart
ambience. Visual timing is independent of audio files: Vines retains its
three-second flower reveal and existing 0.2-second tier transitions.
