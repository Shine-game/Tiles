"""Rebuild the small original growth sounds; standard library only."""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 32000
ROOT = Path(__file__).resolve().parents[1]


def save(path, frames):
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), 'wb') as wav:
        wav.setparams((2, 2, RATE, 0, 'NONE', 'not compressed'))
        wav.writeframes(b''.join(struct.pack('<hh', *(round(max(-0.98, min(0.98, v)) * 32767) for v in frame)) for frame in frames))


def whisper():
    rng = random.Random(1927)
    smooth = [0.0, 0.0]
    low = [0.0, 0.0]
    frames = []
    duration = 1.4
    for i in range(round(RATE * duration)):
        t = i / RATE
        # Soft filtered air with irregular swells, no sharp leaf-crack transients.
        envelope = min(1, t / 0.065, (duration - t) / 0.09)
        envelope = max(0, envelope) ** 1.4
        breath = 0.55 + 0.20 * math.sin(t * 9.1) + 0.12 * math.sin(t * 23.7 + 1)
        frame = []
        for channel in range(2):
            noise = rng.uniform(-1, 1)
            smooth[channel] += 0.32 * (noise - smooth[channel])
            low[channel] += 0.035 * (smooth[channel] - low[channel])
            frame.append((smooth[channel] - low[channel]) * envelope * breath * 0.65)
        frames.append(tuple(frame))
    return frames


def bell():
    frames = []
    duration = 1.6
    fundamental = 523.2511306
    for i in range(round(RATE * duration)):
        t = i / RATE
        attack = 1 - math.exp(-t / 0.009)
        tail = min(1, (duration - t) / 0.10)
        frame = []
        for channel in range(2):
            detune = 1 + (channel * 2 - 1) * 0.0008
            value = 0.0
            for multiple, weight, decay in [(1, 0.82, 3.0), (2.002, 0.16, 4.6), (3.99, 0.055, 7.5), (6.97, 0.012, 10)]:
                value += weight * math.sin(math.tau * fundamental * multiple * detune * t) * math.exp(-t * decay)
            frame.append(value * attack * tail * 0.43)
        frames.append(tuple(frame))
    return frames


if __name__ == '__main__':
    save(ROOT / 'assets/audio/foliage.wav', whisper())
    save(ROOT / 'assets/audio/flower_bell.wav', bell())
    print('Generated original stereo foliage and bell sounds at 32 kHz.')
