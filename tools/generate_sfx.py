#!/usr/bin/env python3
"""Generate folk-horror sound effects for Redelka."""

from __future__ import annotations

import math
import random
import struct
import subprocess
import wave
from pathlib import Path

SAMPLE_RATE = 44100
OUTPUT_DIR = Path(__file__).resolve().parent.parent / "assets" / "audio" / "sfx"


def sine(freq: float, t: float, amp: float = 1.0) -> float:
    return amp * math.sin(2.0 * math.pi * freq * t)


def noise(amp: float = 1.0) -> float:
    return (random.random() * 2.0 - 1.0) * amp


def envelope(t: float, attack: float, release: float, duration: float, sustain: float = 1.0) -> float:
    if t < 0.0 or t > duration:
        return 0.0
    if t < attack:
        return t / attack if attack > 0.0 else 1.0
    if t > duration - release:
        return sustain * max(0.0, (duration - t) / release) if release > 0.0 else 0.0
    return sustain


def normalize(samples: list[float], peak: float = 0.92) -> list[float]:
    max_val = max(abs(sample) for sample in samples) or 1.0
    scale = peak / max_val
    return [max(-1.0, min(1.0, sample * scale)) for sample in samples]


def write_wav(path: Path, samples: list[float]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "w") as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(SAMPLE_RATE)
        frames = b"".join(struct.pack("<h", int(sample * 32767)) for sample in samples)
        wav_file.writeframes(frames)


def to_ogg(wav_path: Path) -> Path:
    ogg_path = wav_path.with_suffix(".ogg")
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav_path), "-c:a", "libvorbis", "-q:a", "4", str(ogg_path)],
        check=True,
    )
    wav_path.unlink()
    return ogg_path


def render(duration: float, builder) -> Path:
    total = max(1, int(duration * SAMPLE_RATE))
    samples = [0.0] * total
    builder(samples, total, duration)
    return total


def save(name: str, duration: float, builder) -> Path:
    total = max(1, int(duration * SAMPLE_RATE))
    samples = [0.0] * total
    builder(samples, total, duration)
    wav_path = OUTPUT_DIR / f"{name}.wav"
    write_wav(wav_path, normalize(samples))
    return to_ogg(wav_path)


def generate_walk_step() -> Path:
    def build(samples: list[float], total: int, duration: float) -> None:
        for index in range(total):
            t = index / SAMPLE_RATE
            env = envelope(t, 0.004, 0.06, duration, 1.0)
            thud = sine(90.0, t, 0.35) * math.exp(-t * 28.0)
            grit = noise(0.12) * math.exp(-t * 22.0)
            wood = sine(220.0, t, 0.04) * math.exp(-t * 35.0)
            samples[index] = (thud + grit + wood) * env

    return save("walk_step", 0.14, build)


def generate_battle_move() -> Path:
    def build(samples: list[float], total: int, duration: float) -> None:
        for index in range(total):
            t = index / SAMPLE_RATE
            env = envelope(t, 0.01, 0.08, duration, 0.85)
            scrape = noise(0.08) * math.exp(-t * 16.0)
            step = sine(110.0, t, 0.22) * math.exp(-t * 18.0)
            cloth = sine(180.0, t, 0.05) * math.exp(-t * 24.0)
            samples[index] = (scrape + step + cloth) * env

    return save("battle_move", 0.18, build)


def generate_attack() -> Path:
    def build(samples: list[float], total: int, duration: float) -> None:
        for index in range(total):
            t = index / SAMPLE_RATE
            whoosh = 0.0
            if t < 0.12:
                whoosh = noise(0.18 * (t / 0.12)) * (1.0 - t / 0.12)
            clang = 0.0
            if t > 0.08:
                local = t - 0.08
                clang = (
                    sine(420.0, local, 0.18)
                    + sine(880.0, local, 0.08)
                    + noise(0.06)
                ) * math.exp(-local * 14.0)
            ring = 0.0
            if t > 0.1:
                local = t - 0.1
                ring = sine(660.0, local, 0.05) * math.exp(-local * 8.0)
            samples[index] = whoosh + clang + ring

    return save("attack", 0.38, build)


def generate_item_use() -> Path:
    def build(samples: list[float], total: int, duration: float) -> None:
        for index in range(total):
            t = index / SAMPLE_RATE
            rustle = noise(0.07) * envelope(t, 0.02, 0.12, 0.18, 0.7)
            chime = 0.0
            if t > 0.08:
                local = t - 0.08
                chime = (
                    sine(523.25, local, 0.08)
                    + sine(659.25, local, 0.05)
                ) * math.exp(-local * 6.0)
            glug = 0.0
            if 0.12 < t < 0.28:
                glug = sine(140.0 + 40.0 * math.sin(t * 40.0), t, 0.06)
            samples[index] = rustle + chime + glug

    return save("item_use", 0.42, build)


def generate_menu_nav() -> Path:
    def build(samples: list[float], total: int, duration: float) -> None:
        for index in range(total):
            t = index / SAMPLE_RATE
            env = envelope(t, 0.001, 0.04, duration, 1.0)
            click = sine(320.0, t, 0.16) * math.exp(-t * 55.0)
            wood = sine(180.0, t, 0.05) * math.exp(-t * 40.0)
            samples[index] = (click + wood) * env

    return save("menu_nav", 0.07, build)


def generate_menu_confirm() -> Path:
    def build(samples: list[float], total: int, duration: float) -> None:
        for index in range(total):
            t = index / SAMPLE_RATE
            env = envelope(t, 0.002, 0.05, duration, 1.0)
            thud = sine(210.0, t, 0.2) * math.exp(-t * 30.0)
            bell = sine(784.0, t, 0.06) * math.exp(-t * 18.0)
            samples[index] = (thud + bell) * env

    return save("menu_confirm", 0.11, build)


def generate_pickup() -> Path:
    def build(samples: list[float], total: int, duration: float) -> None:
        for index in range(total):
            t = index / SAMPLE_RATE
            rustle = noise(0.1) * envelope(t, 0.01, 0.08, 0.16, 0.8)
            coin = 0.0
            if t > 0.05:
                local = t - 0.05
                coin = (
                    sine(880.0, local, 0.07)
                    + sine(1320.0, local, 0.04)
                ) * math.exp(-local * 12.0)
            samples[index] = rustle + coin

    return save("pickup", 0.24, build)


def generate_door_open() -> Path:
    def build(samples: list[float], total: int, duration: float) -> None:
        for index in range(total):
            t = index / SAMPLE_RATE
            creak = noise(0.09) * envelope(t, 0.04, 0.2, duration, 0.55) * (0.4 + 0.6 * math.sin(t * 18.0))
            latch = 0.0
            if 0.08 < t < 0.14:
                latch = sine(260.0, t - 0.08, 0.12) * math.exp(-(t - 0.08) * 40.0)
            low = sine(70.0 + 20.0 * t, t, 0.05) * envelope(t, 0.05, 0.25, duration, 0.4)
            samples[index] = creak + latch + low

    return save("door_open", 0.65, build)


def generate_closet_open() -> Path:
    def build(samples: list[float], total: int, duration: float) -> None:
        for index in range(total):
            t = index / SAMPLE_RATE
            groan = noise(0.11) * envelope(t, 0.05, 0.25, duration, 0.65) * (0.5 + 0.5 * math.sin(t * 11.0))
            wood = sine(55.0, t, 0.08) * envelope(t, 0.03, 0.3, duration, 0.5)
            scrape = noise(0.06) * envelope(t, 0.2, 0.15, duration, 0.4)
            samples[index] = groan + wood + scrape

    return save("closet_open", 0.75, build)


def main() -> None:
    random.seed(13)
    generators = {
        "walk_step": generate_walk_step,
        "battle_move": generate_battle_move,
        "attack": generate_attack,
        "item_use": generate_item_use,
        "menu_nav": generate_menu_nav,
        "menu_confirm": generate_menu_confirm,
        "pickup": generate_pickup,
        "door_open": generate_door_open,
        "closet_open": generate_closet_open,
    }
    for name, generator in generators.items():
        path = generator()
        print(f"Generated {name}: {path}")


if __name__ == "__main__":
    main()
