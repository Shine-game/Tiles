"""Original quiet clockwork samples; deterministic, no external recordings."""
from pathlib import Path
import wave
import numpy as np

RATE = 32000
ROOT = Path(__file__).resolve().parents[1] / 'assets/audio/clockwork'
ROOT.mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(7319)


def save(name, signal):
    stereo = np.column_stack([signal, signal * 0.97])
    assert np.max(np.abs(stereo)) < 1
    with wave.open(str(ROOT / (name + '.wav')), 'wb') as out:
        out.setparams((2, 2, RATE, 0, 'NONE', 'not compressed'))
        out.writeframes((stereo * 32767).astype('<i2').tobytes())


def click(seconds, frequency):
    t = np.arange(round(seconds * RATE)) / RATE
    env = (1 - np.exp(-t * 6000)) * np.exp(-t * 85)
    noise = rng.normal(0, 1, len(t))
    noise = np.convolve(noise, np.ones(4) / 4, mode='same')
    return (np.sin(2 * np.pi * frequency * t) * 0.20 + noise * 0.16) * env


tick = np.zeros(RATE)
a, b = click(0.12, 1800), click(0.12, 1300)
tick[:len(a)] = a
tick[RATE // 2:RATE // 2 + len(b)] = b * 0.85
save('tick', tick)
save('click', click(0.12, 2200))
t = np.arange(round(0.32 * RATE)) / RATE
clunk = (np.sin(2 * np.pi * 170 * t) * 0.26 + np.sin(2 * np.pi * 413 * t) * 0.10) * (1 - np.exp(-t * 2000)) * np.exp(-t * 19)
clunk += rng.normal(0, 0.07, len(t)) * np.exp(-t * 100)
save('clunk', clunk)
t = np.arange(round(0.30 * RATE)) / RATE
noise = np.convolve(rng.normal(0, 1, len(t)), np.ones(5) / 5, mode='same')
save('steam', noise * np.sin(np.pi * t / 0.30) ** 2 * 0.24)
print('Created four original stereo samples at 32 kHz')
