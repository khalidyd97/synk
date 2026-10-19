"""Synthesizes SYNK's UI sound effects into assets/sfx/ as 16-bit mono WAV files.

Run from the repository root:  python tools/ui_sounds/generate.py
Only the standard library is used, so the sounds can be regenerated anywhere.
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 44100
OUT = Path(__file__).resolve().parents[2] / "assets" / "sfx"


def silence(seconds):
    return [0.0] * int(RATE * seconds)


def tone(start_hz, end_hz, seconds, attack=0.004, decay=6.0, harmonics=(1.0, 0.25, 0.08)):
    """Sine voice with a pitch glide, a short attack and an exponential tail."""
    samples = []
    phase = 0.0
    count = int(RATE * seconds)
    for i in range(count):
        t = i / RATE
        progress = i / max(1, count - 1)
        hz = start_hz * (end_hz / start_hz) ** progress
        phase += 2 * math.pi * hz / RATE
        envelope = min(1.0, t / attack) * math.exp(-decay * t / seconds)
        value = sum(weight * math.sin(phase * (n + 1)) for n, weight in enumerate(harmonics))
        samples.append(value * envelope)
    return samples


def mix(*layers):
    """Sums (offset_seconds, gain, samples) layers into one buffer."""
    length = max(int(offset * RATE) + len(samples) for offset, _, samples in layers)
    out = [0.0] * length
    for offset, gain, samples in layers:
        start = int(offset * RATE)
        for i, value in enumerate(samples):
            out[start + i] += value * gain
    return out


def whoosh(seconds, low_hz, high_hz, seed=7):
    """Filtered noise whose brightness rises and falls, for screen transitions."""
    rng = random.Random(seed)
    out = []
    state = 0.0
    count = int(RATE * seconds)
    for i in range(count):
        progress = i / count
        cutoff = low_hz + (high_hz - low_hz) * math.sin(math.pi * progress)
        alpha = 1.0 - math.exp(-2 * math.pi * cutoff / RATE)
        state += alpha * (rng.uniform(-1, 1) - state)
        out.append(state * math.sin(math.pi * progress) ** 1.5)
    return out


def write(name, samples, peak=0.7):
    # Short fade at the end avoids a click when the tail is cut.
    fade = int(RATE * 0.004)
    for i in range(fade):
        samples[-1 - i] *= i / fade
    loudest = max(abs(value) for value in samples) or 1.0
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes(b"".join(struct.pack("<h", int(value / loudest * peak * 32767)) for value in samples))


def main():
    # Secondary actions and cards: a short bright tick.
    write("click", mix((0, 1.0, tone(2100, 1500, 0.045, decay=5.0, harmonics=(1.0, 0.15))),
                       (0, 0.25, whoosh(0.012, 3000, 6000, seed=1))), peak=0.45)
    # Tool chips and toggles: a lighter, higher blip.
    write("toggle", tone(2600, 2200, 0.035, decay=5.0, harmonics=(1.0,)), peak=0.32)
    # Primary actions: two rising notes.
    write("confirm", mix((0, 1.0, tone(880, 880, 0.16, decay=4.0)),
                         (0.055, 1.0, tone(1318.5, 1318.5, 0.22, decay=4.5))), peak=0.55)
    # Recording: a lower, warmer rising pair.
    write("record", mix((0, 1.0, tone(523.3, 523.3, 0.16, decay=4.0, harmonics=(1.0, 0.45, 0.2))),
                        (0.06, 1.0, tone(784, 784, 0.22, decay=4.5, harmonics=(1.0, 0.45, 0.2)))), peak=0.55)
    # Back and navigation: a falling pair.
    write("back", mix((0, 1.0, tone(1318.5, 1318.5, 0.12, decay=4.5)),
                      (0.05, 1.0, tone(880, 880, 0.18, decay=5.0))), peak=0.42)
    # Delete and discard: a short low drop.
    write("danger", tone(330, 196, 0.16, decay=4.0, harmonics=(1.0, 0.5, 0.3, 0.15)), peak=0.5)
    # Big PLAY: a rising arpeggio with a shimmering tail.
    write("play", mix((0, 1.0, tone(659.3, 659.3, 0.35, decay=4.0)),
                      (0.06, 1.0, tone(987.8, 987.8, 0.35, decay=4.0)),
                      (0.12, 1.0, tone(1318.5, 1318.5, 0.5, decay=4.0)),
                      (0.12, 0.35, tone(2637, 2637, 0.5, decay=5.0, harmonics=(1.0,)))), peak=0.6)
    # Countdown: a clean tick for 3, 2, 1, then a bright rising "go" as the music starts.
    write("count", tone(987.8, 987.8, 0.14, decay=6.0, harmonics=(1.0, 0.3)), peak=0.5)
    write("go", mix((0, 1.0, tone(1318.5, 1318.5, 0.3, decay=4.0)),
                    (0.0, 0.7, tone(1975.5, 1975.5, 0.3, decay=4.5, harmonics=(1.0,)))), peak=0.55)
    # Screen changes: a soft airy sweep.
    write("transition", whoosh(0.32, 250, 2800), peak=0.32)
    # Gameplay hit sounds: very short and percussive so they sit on the beat, not over the music.
    # Tap: a crisp tick with a soft body.
    write("hit_tap", mix((0, 1.0, tone(1760, 1320, 0.05, attack=0.001, decay=7.0, harmonics=(1.0, 0.3))),
                         (0, 0.45, whoosh(0.03, 3000, 6000, seed=3))), peak=0.5)
    # Hold start: a rounder, lower tick.
    write("hit_hold", tone(988, 784, 0.07, attack=0.001, decay=6.5, harmonics=(1.0, 0.4, 0.15)), peak=0.48)
    # Flick: an airy upward snap.
    write("hit_flick", mix((0, 1.0, whoosh(0.07, 1200, 7000, seed=11)),
                           (0, 0.6, tone(1320, 2640, 0.06, attack=0.001, decay=6.0, harmonics=(1.0,)))), peak=0.5)


if __name__ == "__main__":
    main()
