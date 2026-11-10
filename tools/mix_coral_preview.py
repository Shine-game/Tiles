"""Reconstruct the captured game's Coral Reef event log for an offline review."""
import json
import subprocess
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
RATE = 48000
schedule = json.loads((ROOT / 'build/coral-audio-events.json').read_text())
meta = json.loads((ROOT / 'art/themes/coral_reef/theme.json').read_text())['audio']
assets = {asset['id']: asset for asset in meta['assets']}
length = round(schedule['duration'] * RATE)
times = np.arange(length) / RATE
mix = np.zeros((length, 2), dtype=np.float64)


def decode(identity):
    path = ROOT / assets[identity]['path'].removeprefix('res://')
    raw = subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(path),
                                   '-f', 'f32le', '-ar', str(RATE), '-ac', '2', '-'])
    return np.frombuffer(raw, dtype='<f4').reshape(-1, 2)


def add(identity, start, end=None):
    samples = decode(identity)
    first = round(start * RATE)
    last = min(length, round((end + 0.08) * RATE) if end is not None else first + len(samples))
    if last <= first:
        return
    indices = np.arange(last - first)
    db = np.full(len(indices), float(assets[identity]['gain_db']))
    if end is not None:
        elapsed = indices / RATE
        db = np.minimum(db, -60 + (db + 60) * np.minimum(1, elapsed / 0.025))
        release = np.clip((start + elapsed - end) / 0.08, 0, 1)
        db += (-60 - db) * release
    mix[first:last] += samples[indices % len(samples)] * (10 ** (db / 20))[:, None]


# Hold one duck envelope while any feature recording is sounding.
duck_on = np.zeros(length, dtype=bool)
start_growth = None
for event in schedule['events']:
    onset = schedule['placement_offset'] + event['clock']
    if event['kind'] == 'growth':
        start_growth = (event['asset'], onset)
    elif event['kind'] == 'growth_end' and start_growth:
        add(*start_growth, end=onset)
        start_growth = None
    elif event['kind'] in ('colony', 'anemone'):
        add(event['asset'], onset)
        end = min(length, round((onset + assets[event['asset']]['duration_seconds']) * RATE))
        duck_on[round(onset * RATE):end] = True
if start_growth:
    add(*start_growth, end=schedule['duration'])
duck = np.zeros(length)
value = 0.0
previous_target = 0.0
remaining = 0
for i, active in enumerate(duck_on):
    target = -2.0 if active else 0.0
    if target != previous_target:
        remaining = round((0.04 if active else 0.25) * RATE)
        step = (target - value) / remaining
        previous_target = target
    if remaining:
        value += step
        remaining -= 1
    duck[i] = value
ambience = decode('reef_ambience')
ambience_db = assets['reef_ambience']['gain_db'] - 60 * np.clip(1 - times / 1.5, 0, 1) + duck
# Review-only exit fade; in-game theme exit uses 600 ms.
ambience_db -= 60 * np.clip((times - schedule['duration'] + 0.2) / 0.2, 0, 1)
mix += ambience[np.arange(length) % len(ambience)] * (10 ** (ambience_db / 20))[:, None]
peak = float(np.max(np.abs(mix)))
ceiling = 10 ** (-1 / 20)
mix = np.clip(mix, -ceiling, ceiling)
output = ROOT / 'build/coral-audio.wav'
with wave.open(str(output), 'wb') as wav:
    wav.setparams((2, 2, RATE, 0, 'NONE', 'not compressed'))
    wav.writeframes((mix * 32767).astype('<i2').tobytes())
print(f'{output}: 48 kHz stereo; pre-limiter peak {20 * np.log10(max(peak, 1e-12)):.2f} dBFS')
