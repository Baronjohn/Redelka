#!/usr/bin/env python3
"""Generate loopable folk-horror BGM for Redelka."""

from __future__ import annotations

import math
import random
import struct
import subprocess
import sys
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


def loop_freq(freq: float, loop_seconds: float) -> float:
    """Nudge a frequency so it completes whole cycles per loop (no click at the seam)."""
    return max(1.0, round(freq * loop_seconds)) / loop_seconds


def add_event(buffer: list[float], start: float, length: float, voice) -> None:
    """Render `voice(local_t)` into the buffer from `start`, wrapping past the loop end."""
    total = len(buffer)
    first = int(start * SAMPLE_RATE)
    count = int(length * SAMPLE_RATE)
    for offset in range(count):
        buffer[(first + offset) % total] += voice(offset / SAMPLE_RATE)


def bowed(freq: float, length: float, amp: float, attack: float = 0.8, release: float = 1.6,
          vibrato: float = 0.004, harmonics: int = 7):
    """Rough fiddle / hurdy-gurdy tone: a soft saw with slow swell and late vibrato."""

    def voice(t: float) -> float:
        env = min(1.0, t / attack) * min(1.0, max(0.0, (length - t) / release))
        vib_depth = vibrato * min(1.0, t / (attack * 1.5))
        phase = 2.0 * math.pi * freq * t + (vib_depth * freq / 5.2) * math.sin(2.0 * math.pi * 5.2 * t)
        value = 0.0
        for harmonic in range(1, harmonics + 1):
            value += math.sin(phase * harmonic) / (harmonic ** 1.3)
        return value * env * amp

    return voice


def bell(freq: float, amp: float, decay: float = 1.1):
    """Inharmonic struck bell (chapel bell or a small hand bell)."""
    partials = [(0.5, 0.6), (1.0, 1.0), (1.183, 0.5), (1.506, 0.35), (2.0, 0.3), (2.514, 0.2), (3.011, 0.12)]

    def voice(t: float) -> float:
        value = 0.0
        for ratio, weight in partials:
            value += weight * math.sin(2.0 * math.pi * freq * ratio * t) * math.exp(-t * decay * ratio)
        return value * amp * min(1.0, t / 0.004)

    return voice


def heartbeat(amp: float):
    """Two low, muffled thumps."""

    def thump(t: float) -> float:
        if t < 0.0 or t > 0.25:
            return 0.0
        freq = 48.0 + 30.0 * math.exp(-t * 25.0)
        return math.sin(2.0 * math.pi * freq * t) * math.exp(-t * 16.0)

    def voice(t: float) -> float:
        return amp * (thump(t) + 0.7 * thump(t - 0.28))

    return voice


def noise_swell(length: float, amp: float, smoothing: float = 0.02):
    """Filtered noise that rises and falls: wind through an awning, breath, a scrape."""
    state = {"value": 0.0}

    def voice(t: float) -> float:
        state["value"] += ((random.random() * 2.0 - 1.0) - state["value"]) * smoothing
        env = math.sin(math.pi * min(1.0, max(0.0, t / length))) ** 2
        return state["value"] * env * amp

    return voice


def generate_intro_dawn() -> Path:
    """Doorway at grey dawn: open fifths, a lone fiddle line in D dorian, wind, a far bell."""
    tempo = 52.0
    bars = 16
    total = loop_samples(tempo, bars)
    loop_seconds = total / SAMPLE_RATE
    beat = 60.0 / tempo
    samples = [0.0] * total

    d2 = loop_freq(73.42, loop_seconds)
    a2 = loop_freq(110.0, loop_seconds)
    d2_detune = loop_freq(73.42 * 1.003, loop_seconds)
    breath = loop_freq(0.05, loop_seconds)
    for index in range(total):
        t = index / SAMPLE_RATE
        swell = 0.75 + 0.25 * math.sin(2.0 * math.pi * breath * t)
        samples[index] = swell * (
            0.07 * math.sin(2.0 * math.pi * d2 * t)
            + 0.035 * math.sin(2.0 * math.pi * d2_detune * t)
            + 0.04 * math.sin(2.0 * math.pi * a2 * t)
        )

    # Fiddle phrase (beat offset, length in beats, Hz). Long rests between phrases.
    d4, e4, f4, g4, a4, b4, c5 = 293.66, 329.63, 349.23, 392.0, 440.0, 493.88, 523.25
    phrase = [
        (4.0, 3.0, a4), (7.0, 1.0, g4), (8.0, 2.0, f4), (10.0, 4.0, e4),
        (24.0, 2.0, d4), (26.0, 1.0, e4), (27.0, 1.0, f4), (28.0, 3.0, g4), (31.0, 5.0, a4),
        (44.0, 2.0, c5), (46.0, 2.0, b4), (48.0, 2.0, a4), (50.0, 6.0, d4),
    ]
    for start_beat, length_beats, freq in phrase:
        length = length_beats * beat + 1.2
        add_event(samples, start_beat * beat, length, bowed(freq, length, 0.05))

    # A small bell somewhere across the market, twice per loop.
    for start_beat in (16.0, 48.0):
        add_event(samples, start_beat * beat, 6.0, bell(587.33, 0.025, decay=0.9))

    # Wind in the canvas.
    for start_beat in (0.0, 20.0, 38.0, 54.0):
        add_event(samples, start_beat * beat, 7.0, noise_swell(7.0, 0.05, smoothing=0.015))

    wav_path = OUTPUT_DIR / "intro_dawn.wav"
    write_wav(wav_path, normalize(samples, 0.38))
    return to_ogg(wav_path)


def generate_intro_lane() -> Path:
    """Chapel lane into the pines: a low tritone drone, a slow heartbeat, one tolling bell."""
    tempo = 60.0
    bars = 16
    total = loop_samples(tempo, bars)
    loop_seconds = total / SAMPLE_RATE
    beat = 60.0 / tempo
    samples = [0.0] * total

    root = loop_freq(55.0, loop_seconds)
    root_beat = loop_freq(55.0 * 1.006, loop_seconds)
    tritone = loop_freq(77.78, loop_seconds)
    unease = loop_freq(0.0625, loop_seconds)
    for index in range(total):
        t = index / SAMPLE_RATE
        rise = 0.5 + 0.5 * math.sin(2.0 * math.pi * unease * t)
        samples[index] = (
            0.08 * math.sin(2.0 * math.pi * root * t)
            + 0.05 * math.sin(2.0 * math.pi * root_beat * t)
            + 0.03 * rise * math.sin(2.0 * math.pi * tritone * t)
        )

    # Heartbeat that thins out, then returns.
    for start_beat in (0.0, 1.6, 3.2, 4.8, 8.0, 9.6, 16.0, 17.6, 19.2, 20.8, 32.0, 33.6, 40.0, 48.0, 49.6, 51.2, 52.8):
        add_event(samples, start_beat * beat, 0.6, heartbeat(0.16))

    # The chapel bell, far off: one toll per half loop.
    for start_beat in (12.0, 44.0):
        add_event(samples, start_beat * beat, 9.0, bell(146.83, 0.07, decay=0.45))

    # Low bowed note that slides in under the drone and never resolves.
    for start_beat, freq in ((24.0, 103.83), (56.0, 98.0)):
        add_event(samples, start_beat * beat, 7.0, bowed(freq, 7.0, 0.035, attack=2.5, release=3.0, harmonics=5))

    # Scrapes and breath.
    for start_beat in (6.0, 28.0, 36.0, 60.0):
        add_event(samples, start_beat * beat, 4.0, noise_swell(4.0, 0.035, smoothing=0.05))

    wav_path = OUTPUT_DIR / "intro_lane.wav"
    write_wav(wav_path, normalize(samples, 0.38))
    return to_ogg(wav_path)


def normalize(samples: list[float], peak_target: float) -> list[float]:
    peak = max(abs(sample) for sample in samples) or 1.0
    scale = peak_target / peak
    return [sample * scale for sample in samples]


GENERATORS = {
    "main_menu": generate_main_menu,
    "overworld": generate_overworld,
    "battle": generate_battle,
    "intro_dawn": generate_intro_dawn,
    "intro_lane": generate_intro_lane,
}


def main() -> None:
    """Generate every track, or only the ids passed on the command line."""
    selected = sys.argv[1:] or list(GENERATORS)
    for name in selected:
        if name not in GENERATORS:
            raise SystemExit(f"Unknown track {name!r}; choose from {', '.join(GENERATORS)}")
    random.seed(7)
    for name in selected:
        path = GENERATORS[name]()
        print(f"Generated {name}: {path}")


if __name__ == "__main__":
    main()
