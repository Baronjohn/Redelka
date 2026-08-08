#!/usr/bin/env python3
"""Generate loopable folk-horror BGM for Redelka."""

from __future__ import annotations

import math
import random
import struct
import subprocess
import wave
from pathlib import Path

SAMPLE_RATE = 44100
OUTPUT_DIR = Path(__file__).resolve().parent.parent / "assets" / "audio" / "bgm"


def bar_seconds(tempo_bpm: float, bars: int, beats_per_bar: int = 4) -> float:
    return bars * beats_per_bar * 60.0 / tempo_bpm


def loop_samples(tempo_bpm: float, bars: int) -> int:
    return int(round(bar_seconds(tempo_bpm, bars) * SAMPLE_RATE))


def sine(freq: float, phase: float, amp: float = 1.0) -> float:
    return amp * math.sin(phase)


def pluck(freq: float, t: float, start: float, decay: float = 4.5, amp: float = 0.22) -> float:
    if t < start:
        return 0.0
    local_t = t - start
    value = 0.0
    for harmonic in range(1, 9):
        value += sine(freq * harmonic, 2.0 * math.pi * freq * harmonic * local_t, amp / harmonic)
    return value * math.exp(-local_t * decay)


def noise_burst(t: float, start: float, length: float, amp: float = 0.08) -> float:
    if t < start or t > start + length:
        return 0.0
    local_t = t - start
    envelope = 1.0 - local_t / length
    return (random.random() * 2.0 - 1.0) * amp * envelope * envelope


def kick(t: float, beat_time: float, amp: float = 0.35) -> float:
    if t < beat_time:
        return 0.0
    local_t = t - beat_time
    if local_t > 0.18:
        return 0.0
    freq = 90.0 * math.exp(-local_t * 18.0) + 42.0
    return sine(freq, 2.0 * math.pi * freq * local_t, amp) * math.exp(-local_t * 9.0)


def frame_drum(t: float, hit_time: float, amp: float = 0.16) -> float:
    if t < hit_time:
        return 0.0
    local_t = t - hit_time
    if local_t > 0.09:
        return 0.0
    tone = sine(180.0, 2.0 * math.pi * 180.0 * local_t, amp * 0.45)
    noise = (random.random() * 2.0 - 1.0) * amp * math.exp(-local_t * 40.0)
    return tone + noise


def lfo(t: float, rate: float, depth: float) -> float:
    return 1.0 + depth * math.sin(2.0 * math.pi * rate * t)


def mix_tracks(tracks: list[list[float]]) -> list[float]:
    length = max(len(track) for track in tracks)
    mixed = [0.0] * length
    for track in tracks:
        for index, sample in enumerate(track):
            mixed[index] += sample
    peak = max(abs(sample) for sample in mixed) or 1.0
    scale = 0.92 / peak
    return [sample * scale for sample in mixed]


def write_wav(path: Path, samples: list[float]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "w") as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(SAMPLE_RATE)
        frames = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, sample)) * 32767)) for sample in samples)
        wav_file.writeframes(frames)


def to_ogg(wav_path: Path) -> Path:
    ogg_path = wav_path.with_suffix(".ogg")
    subprocess.run(
        [
            "ffmpeg",
            "-y",
            "-loglevel",
            "error",
            "-i",
            str(wav_path),
            "-c:a",
            "libvorbis",
            "-q:a",
            "5",
            str(ogg_path),
        ],
        check=True,
    )
    wav_path.unlink()
    return ogg_path


def generate_main_menu() -> Path:
    tempo = 66.0
    bars = 8
    total = loop_samples(tempo, bars)
    beat = 60.0 / tempo
    e2, b2, g2 = 82.41, 123.47, 98.0
    melody_notes = [
        (0.0, 329.63),
        (2.0, 392.0),
        (4.0, 349.23),
        (6.0, 293.66),
        (10.0, 329.63),
        (14.0, 261.63),
        (18.0, 293.66),
        (22.0, 246.94),
        (26.0, 220.0),
    ]
    samples = [0.0] * total
    for index in range(total):
        t = index / SAMPLE_RATE
        phase_e = 2.0 * math.pi * e2 * t
        phase_b = 2.0 * math.pi * b2 * t
        phase_g = 2.0 * math.pi * g2 * t
        drone = (
            sine(e2, phase_e, 0.11 * lfo(t, 0.07, 0.08))
            + sine(e2 * 1.002, phase_e * 1.002, 0.05)
            + sine(b2, phase_b, 0.045 * lfo(t, 0.05, 0.06))
            + sine(g2, phase_g, 0.04)
        )
        pulse = kick(t, (t // beat) * beat, 0.06) if int(t / beat) % 4 == 0 else 0.0
        melody = 0.0
        for start_beat, freq in melody_notes:
            melody += pluck(freq, t, start_beat * beat, decay=3.2, amp=0.09)
        wind = (random.random() * 2.0 - 1.0) * 0.012 * (0.6 + 0.4 * math.sin(2.0 * math.pi * 0.3 * t))
        samples[index] = drone + pulse + melody + wind
    wav_path = OUTPUT_DIR / "main_menu.wav"
    write_wav(wav_path, samples)
    return to_ogg(wav_path)


def generate_overworld() -> Path:
    tempo = 84.0
    bars = 8
    total = loop_samples(tempo, bars)
    beat = 60.0 / tempo
    e2, a2, d3 = 82.41, 110.0, 146.83
    pluck_pattern = [0, 1.5, 2, 3.5, 4, 5.5, 6, 7.5, 8, 9.5, 10, 11.5, 12, 13.5, 14, 15.5]
    pluck_freqs = [220.0, 246.94, 293.66, 329.63, 349.23, 392.0, 349.23, 293.66]
    samples = [0.0] * total
    for index in range(total):
        t = index / SAMPLE_RATE
        beat_index = int(t / beat)
        beat_time = beat_index * beat
        drone = (
            sine(e2, 2.0 * math.pi * e2 * t, 0.09)
            + sine(a2, 2.0 * math.pi * a2 * t, 0.05)
            + sine(d3, 2.0 * math.pi * d3 * t, 0.035)
        )
        rhythm = kick(t, beat_time, 0.14 if beat_index % 4 in (0, 2) else 0.0)
        rhythm += frame_drum(t, beat_time + beat * 0.5, 0.07 if beat_index % 2 == 0 else 0.04)
        plucks = 0.0
        for cycle in range(bars):
            for step, beat_offset in enumerate(pluck_pattern):
                freq = pluck_freqs[step % len(pluck_freqs)]
                start = (beat_offset + cycle * 16.0) * beat
                if start < total / SAMPLE_RATE:
                    plucks += pluck(freq, t, start, decay=5.0, amp=0.07)
        samples[index] = drone + rhythm + plucks
    wav_path = OUTPUT_DIR / "overworld.wav"
    write_wav(wav_path, samples)
    return to_ogg(wav_path)


def generate_battle() -> Path:
    tempo = 108.0
    bars = 8
    total = loop_samples(tempo, bars)
    beat = 60.0 / tempo
    e2, bb2, fs2 = 82.41, 116.54, 92.5
    samples = [0.0] * total
    for index in range(total):
        t = index / SAMPLE_RATE
        beat_index = int(t / beat)
        beat_time = beat_index * beat
        tension = (
            sine(e2, 2.0 * math.pi * e2 * t, 0.1)
            + sine(bb2, 2.0 * math.pi * bb2 * t, 0.07)
            + sine(fs2 * 1.5, 2.0 * math.pi * fs2 * 1.5 * t, 0.05 * lfo(t, 0.25, 0.35))
        )
        pattern = beat_index % 8
        rhythm = kick(t, beat_time, 0.22)
        rhythm += frame_drum(t, beat_time + beat * 0.5, 0.12 if pattern in (1, 3, 5, 7) else 0.08)
        rhythm += frame_drum(t, beat_time + beat * 0.75, 0.06 if pattern in (2, 6) else 0.0)
        rhythm += noise_burst(t, beat_time + beat * 0.25, 0.04, 0.05 if pattern in (0, 4) else 0.0)
        stab_beats = [0, 2.5, 4, 6.5, 8, 10.5, 12, 14.5]
        stabs = 0.0
        stab_freqs = [164.81, 174.61, 185.0, 196.0]
        for cycle in range(bars):
            for step, beat_offset in enumerate(stab_beats):
                start = (beat_offset + cycle * 16.0) * beat
                freq = stab_freqs[step % len(stab_freqs)]
                stabs += pluck(freq, t, start, decay=6.5, amp=0.11)
        samples[index] = tension + rhythm + stabs
    wav_path = OUTPUT_DIR / "battle.wav"
    write_wav(wav_path, samples)
    return to_ogg(wav_path)


def main() -> None:
    random.seed(7)
    tracks = {
        "main_menu": generate_main_menu(),
        "overworld": generate_overworld(),
        "battle": generate_battle(),
    }
    for name, path in tracks.items():
        print(f"Generated {name}: {path}")


if __name__ == "__main__":
    main()
