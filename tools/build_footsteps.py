"""Deterministic, original soft earth/boot contacts; no external audio sources."""
import math
from pathlib import Path
import random
import struct
import wave


def build():
    destination = Path(__file__).resolve().parents[1] / 'assets/audio'
    destination.mkdir(parents=True, exist_ok=True)
    rate = 22050
    for index, (duration, tone) in enumerate(((.16, 95), (.14, 112), (.18, 83)), 1):
        rng = random.Random(640 + index)
        low = 0.0
        samples = []
        for frame in range(int(rate * duration)):
            t = frame / rate
            noise = rng.uniform(-1, 1)
            low += .19 * (noise - low)
            attack = min(1, t / .004)
            tail = max(0, 1 - t / duration) ** 2
            sole = math.sin(math.tau * tone * t) * math.exp(-t * 48)
            grit = (low * .55 + noise * .035) * math.exp(-t * 17)
            samples.append(int(32767 * (sole * .20 + grit) * attack * tail))
        path = destination / f'footstep-{index}.wav'
        with wave.open(str(path), 'wb') as output:
            output.setparams((1, 2, rate, 0, 'NONE', 'not compressed'))
            output.writeframes(struct.pack(f'<{len(samples)}h', *samples))
        print(f'{path.name}: {len(samples)} samples')


if __name__ == '__main__':
    build()
