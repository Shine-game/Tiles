"""Mix the game's captured sound-event schedule into a preview WAV."""
import json
import math
import struct
import sys
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RATE = 32000
prefix = sys.argv[1] if len(sys.argv) > 1 else 'dense-growth'
events = json.loads((ROOT / 'build' / (prefix + '-audio-events.json')).read_text())


def load(name):
    with wave.open(str(ROOT / 'assets/audio' / name), 'rb') as wav:
        assert wav.getframerate() == RATE and wav.getnchannels() == 2
        samples = struct.unpack('<' + 'h' * wav.getnframes() * 2, wav.readframes(wav.getnframes()))
        return [(samples[i] / 32768, samples[i + 1] / 32768) for i in range(0, len(samples), 2)]


mix = [[0.0, 0.0] for _ in range(round(events['duration'] * RATE))]
whisper = load('foliage.wav')
bell = load('flower_bell.wav')
for i, output in enumerate(mix):
    time = i / RATE
    t = time - events['whisper_start']
    if t < 0 or time >= events['whisper_stop'] + 0.12:
        continue
    db = events['whisper_db']
    if t < 0.06:
        db = -50 + (db + 50) * t / 0.06
    if time > events['whisper_stop']:
        db += (-50 - db) * (time - events['whisper_stop']) / 0.12
    gain = 10 ** (db / 20)
    sample = whisper[round(t * RATE) % len(whisper)]
    output[0] += sample[0] * gain
    output[1] += sample[1] * gain
last = {}
for event in sorted(events['bells'], key=lambda item: item['time']):
    ratio = event['pitch']
    if event['time'] - last.get(ratio, -100) < 0.085:
        continue
    last[ratio] = event['time']
    start = round(event['time'] * RATE)
    gain = 10 ** (events['bell_db'] / 20)
    for j in range(min(round(len(bell) / ratio), len(mix) - start)):
        position = j * ratio
        low = int(position)
        high = min(len(bell) - 1, low + 1)
        blend = position - low
        for channel in range(2):
            mix[start + j][channel] += (bell[low][channel] * (1 - blend) + bell[high][channel] * blend) * gain
peak = max(abs(value) for frame in mix for value in frame)
assert peak < 0.95, 'Preview mix would clip'
path = ROOT / 'build' / (prefix + '-audio.wav')
with wave.open(str(path), 'wb') as wav:
    wav.setparams((2, 2, RATE, 0, 'NONE', 'not compressed'))
    wav.writeframes(b''.join(struct.pack('<hh', *(round(value * 32767) for value in frame)) for frame in mix))
print(f'{path.name}: stereo sound preview mixed without clipping, peak {peak:.3f}')
