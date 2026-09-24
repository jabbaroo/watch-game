#!/usr/bin/env python3
"""Generates the placeholder game sounds as 16-bit mono 44.1 kHz WAV files.

Run from anywhere: python3 Tools/generate_sounds.py
Replace the generated files with designed assets later; names and formats must stay the same.
"""
import math
import pathlib
import struct
import wave

RATE = 44_100
OUT_DIR = pathlib.Path(__file__).resolve().parent.parent / "WatchGame" / "Resources" / "Sounds"


def tone(freq_hz, length_ms, volume=0.6, attack_ms=3.0, decay_power=2.0, harmonics=(1.0,)):
    """A decaying tone with optional harmonics (amplitude per overtone)."""
    total = int(RATE * length_ms / 1000)
    attack = max(1, int(RATE * attack_ms / 1000))
    samples = []
    for i in range(total):
        t = i / RATE
        envelope = min(1.0, i / attack) * (1 - i / total) ** decay_power
        value = sum(amp * math.sin(2 * math.pi * freq_hz * (n + 1) * t) for n, amp in enumerate(harmonics))
        samples.append(volume * envelope * value / sum(harmonics))
    return samples


def sweep(start_hz, end_hz, length_ms, volume=0.5):
    total = int(RATE * length_ms / 1000)
    samples, phase = [], 0.0
    for i in range(total):
        freq = start_hz + (end_hz - start_hz) * i / total
        phase += 2 * math.pi * freq / RATE
        envelope = (1 - i / total) ** 1.5
        samples.append(volume * envelope * math.sin(phase))
    return samples


def silence(length_ms):
    return [0.0] * int(RATE * length_ms / 1000)


def write(name, samples):
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    path = OUT_DIR / f"{name}.wav"
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        clipped = (max(-1.0, min(1.0, s)) for s in samples)
        handle.writeframes(b"".join(struct.pack("<h", int(s * 32767)) for s in clipped))
    print(f"wrote {path.relative_to(OUT_DIR.parent.parent.parent)} ({len(samples) / RATE * 1000:.0f} ms)")


SOUNDS = {
    "wrong": tone(110, 180, volume=0.7, harmonics=(1.0, 0.6, 0.4), decay_power=1.2),
    "timeout": sweep(600, 180, 220),
    "roundStart": tone(660, 90) + tone(990, 170),
    "perfect": tone(523, 70) + tone(659, 70) + tone(784, 70) + tone(1047, 230, harmonics=(1.0, 0.3)),
    "runEnd": tone(784, 120) + tone(659, 120) + tone(523, 240, harmonics=(1.0, 0.4)),
}

# watchOS has no time-pitch unit, so the correct sound is rendered once per semitone.
for semitones in range(19):
    SOUNDS[f"correct-{semitones:02d}"] = tone(880 * 2 ** (semitones / 12), 110, harmonics=(1.0, 0.3))

if __name__ == "__main__":
    for name, samples in SOUNDS.items():
        write(name, samples)
