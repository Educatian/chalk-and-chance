"""Offline composer for Chalk & Chance background music.

Renders seamless-looping stereo tracks with a tiny additive/subtractive synth
(e-piano, pad, bass, pluck, bell, drums, vinyl crackle) plus a synthetic-IR
reverb, then encodes OGG Vorbis into assets/audio/music/.

    python tools/compose_bgm.py            # all tracks
    python tools/compose_bgm.py hub        # one track

Deterministic (seeded) so re-running produces the same files.
"""
from __future__ import annotations

import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np
from scipy.signal import butter, fftconvolve, sosfilt

SR = 44100
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "audio" / "music"

NOTE = {n: i for i, n in enumerate(["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"])}


def hz(name: str) -> float:
    """'A4' -> 440.0, 'C#3' -> ..."""
    pitch, octave = name[:-1], int(name[-1])
    midi = 12 * (octave + 1) + NOTE[pitch]
    return 440.0 * 2 ** ((midi - 69) / 12)


def chord(root: str, quality: str, octave: int = 3) -> list[float]:
    shapes = {
        "maj7": [0, 4, 7, 11], "m7": [0, 3, 7, 10], "7": [0, 4, 7, 10], "maj": [0, 4, 7],
        "min": [0, 3, 7], "sus2": [0, 2, 7], "add9": [0, 4, 7, 14], "m9": [0, 3, 7, 10, 14],
        "maj9": [0, 4, 7, 11, 14], "m7b5": [0, 3, 6, 10],
    }
    base = 12 * (octave + 1) + NOTE[root]
    return [440.0 * 2 ** ((base + s - 69) / 12) for s in shapes[quality]]


# --- envelopes & oscillators ---------------------------------------------------------

def env_adsr(n: int, a: float, d: float, s: float, r: float) -> np.ndarray:
    a_n, d_n, r_n = int(a * SR), int(d * SR), int(r * SR)
    sus_n = max(0, n - a_n - d_n)
    e = np.concatenate([
        np.linspace(0, 1, max(1, a_n), endpoint=False),
        np.linspace(1, s, max(1, d_n), endpoint=False),
        np.full(sus_n, s),
    ])[:n]
    if len(e) < n:
        e = np.pad(e, (0, n - len(e)), constant_values=s)
    tail = s * np.exp(-np.linspace(0, 6, max(1, r_n)))
    return np.concatenate([e, tail])


def t_axis(n: int) -> np.ndarray:
    return np.arange(n) / SR


def lowpass(x: np.ndarray, cutoff: float, order: int = 2) -> np.ndarray:
    sos = butter(order, min(cutoff, SR * 0.45), "low", fs=SR, output="sos")
    return sosfilt(sos, x)


def highpass(x: np.ndarray, cutoff: float, order: int = 2) -> np.ndarray:
    sos = butter(order, cutoff, "high", fs=SR, output="sos")
    return sosfilt(sos, x)


def epiano(f: float, dur: float, vel: float = 0.7) -> np.ndarray:
    n = int(dur * SR)
    e = env_adsr(n, 0.004, 0.9, 0.25, 0.5)
    t = t_axis(len(e))
    decay = np.exp(-t * 2.2)
    # FM-flavoured tine: carrier + bell partial that fades fast
    mod = np.sin(2 * np.pi * f * 14 * t) * 0.8 * np.exp(-t * 14)
    x = np.sin(2 * np.pi * f * t + mod) * 0.7 + np.sin(2 * np.pi * f * 2 * t) * 0.18 * decay
    x *= 1 + 0.08 * np.sin(2 * np.pi * 4.8 * t)  # tremolo
    return x * e * vel


def pad(f: float, dur: float, vel: float = 0.5, bright: float = 1800) -> np.ndarray:
    n = int(dur * SR)
    e = env_adsr(n, 0.9, 0.5, 0.8, 1.6)
    t = t_axis(len(e))
    x = np.zeros_like(t)
    for det in (-0.12, 0.0, 0.11):
        ph = 2 * np.pi * f * (1 + det / 100) * t
        x += (2 * ((ph / (2 * np.pi)) % 1.0) - 1) * 0.33  # saw
    x = lowpass(x, bright)
    return x * e * vel


def bass(f: float, dur: float, vel: float = 0.8) -> np.ndarray:
    n = int(dur * SR)
    e = env_adsr(n, 0.006, 0.25, 0.55, 0.08)
    t = t_axis(len(e))
    tri = 2 * np.abs(2 * ((f * t) % 1.0) - 1) - 1
    x = tri * 0.6 + np.sin(2 * np.pi * f * t) * 0.6
    return lowpass(x, 900) * e * vel


def pluck(f: float, dur: float, vel: float = 0.5, cutoff: float = 3200) -> np.ndarray:
    n = int(dur * SR)
    e = env_adsr(n, 0.002, 0.18, 0.0, 0.05)
    t = t_axis(len(e))
    sq = np.sign(np.sin(2 * np.pi * f * t)) * 0.5 + np.sin(2 * np.pi * f * 2 * t) * 0.2
    return lowpass(sq, cutoff) * e * vel


def bell(f: float, dur: float, vel: float = 0.4) -> np.ndarray:
    n = int(dur * SR)
    e = env_adsr(n, 0.002, 1.8, 0.0, 0.6)
    t = t_axis(len(e))
    x = (np.sin(2 * np.pi * f * t) + 0.5 * np.sin(2 * np.pi * f * 2.76 * t) * np.exp(-t * 3)
         + 0.25 * np.sin(2 * np.pi * f * 5.4 * t) * np.exp(-t * 6))
    return x * e * vel * 0.6


def kick(vel: float = 0.9) -> np.ndarray:
    n = int(0.35 * SR)
    t = t_axis(n)
    f = 120 * np.exp(-t * 18) + 45
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-t * 9) * vel


def snare(rng, vel: float = 0.5) -> np.ndarray:
    n = int(0.25 * SR)
    t = t_axis(n)
    noise = highpass(rng.standard_normal(n), 1400) * np.exp(-t * 16)
    tone = np.sin(2 * np.pi * 190 * t) * np.exp(-t * 25) * 0.5
    return lowpass(noise * 0.6 + tone, 7000) * vel


def hat(rng, vel: float = 0.25, open_: bool = False) -> np.ndarray:
    n = int((0.22 if open_ else 0.06) * SR)
    t = t_axis(n)
    x = highpass(rng.standard_normal(n), 7000) * np.exp(-t * (12 if open_ else 60))
    return x * vel


def crackle(rng, n: int, amount: float = 0.012) -> np.ndarray:
    x = lowpass(rng.standard_normal(n), 3000) * 0.0025  # hiss
    pops = rng.random(n) < 0.00018
    x[pops] += rng.uniform(-1, 1, pops.sum()) * 0.35
    return lowpass(x, 5000) * (amount / 0.012)


# --- mixing -----------------------------------------------------------------------------

class Track:
    def __init__(self, bpm: float, bars: int, beats_per_bar: int = 4, seed: int = 1):
        self.bpm = bpm
        self.beat = 60.0 / bpm
        self.length = int(bars * beats_per_bar * self.beat * SR)
        self.tail = int(4.0 * SR)
        self.L = np.zeros(self.length + self.tail)
        self.R = np.zeros(self.length + self.tail)
        self.rng = np.random.default_rng(seed)
        self.sends: dict[str, np.ndarray] = {}

    def add(self, x: np.ndarray, at_beat: float, gain: float = 1.0, pan: float = 0.0, swing: float = 0.0):
        # swing: delay off-beat 8ths by a fraction of an 8th
        frac = at_beat % 1.0
        if swing and abs(frac - 0.5) < 1e-6:
            at_beat += swing * 0.5
        start = int(at_beat * self.beat * SR)
        if start >= len(self.L):
            return
        end = min(len(self.L), start + len(x))
        seg = x[: end - start] * gain
        self.L[start:end] += seg * np.sqrt(0.5 * (1 - pan))
        self.R[start:end] += seg * np.sqrt(0.5 * (1 + pan))

    def render(self, reverb: float = 0.25, room: float = 2.2, master_lp: float = 12000) -> np.ndarray:
        ir_n = int(room * SR)
        t = t_axis(ir_n)
        ir_l = self.rng.standard_normal(ir_n) * np.exp(-t * 6.9 / room)
        ir_r = self.rng.standard_normal(ir_n) * np.exp(-t * 6.9 / room)
        ir_l, ir_r = lowpass(ir_l, 5000), lowpass(ir_r, 5000)
        ir_l /= np.sqrt(np.sum(ir_l ** 2)); ir_r /= np.sqrt(np.sum(ir_r ** 2))
        wet_l = fftconvolve(self.L, ir_l)[: len(self.L)]
        wet_r = fftconvolve(self.R, ir_r)[: len(self.R)]
        L = self.L + wet_l * reverb
        R = self.R + wet_r * reverb
        # Fold the tail back onto the start so the loop is seamless.
        L[: self.tail] += L[self.length:]
        R[: self.tail] += R[self.length:]
        L, R = L[: self.length], R[: self.length]
        # Circular filtering: run the loop twice and keep the second pass, so the
        # filter state at sample 0 matches the end of the loop (no click at the seam).
        n = self.length
        L = lowpass(np.concatenate([L, L]), master_lp)[n:]
        R = lowpass(np.concatenate([R, R]), master_lp)[n:]
        st = np.stack([L, R], axis=1)
        # gentle soft-clip + normalise to -1 dBFS
        st = np.tanh(st * 1.2) / np.tanh(1.2)
        st /= max(1e-9, np.max(np.abs(st))) / 0.89
        return st


def write_ogg(name: str, stereo: np.ndarray, quality: int = 5) -> Path:
    OUT.mkdir(parents=True, exist_ok=True)
    pcm = (np.clip(stereo, -1, 1) * 32767).astype(np.int16)
    with tempfile.TemporaryDirectory() as td:
        wav_path = Path(td) / f"{name}.wav"
        with wave.open(str(wav_path), "wb") as w:
            w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        out = OUT / f"{name}.ogg"
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav_path), "-c:a", "libvorbis",
                        "-q:a", str(quality), str(out)], check=True)
    return out


# --- the tracks -----------------------------------------------------------------------

def track_hub() -> np.ndarray:
    """'Staff Room' - warm lo-fi, swung e-piano over a soft boom-bap."""
    tr = Track(bpm=78, bars=16, seed=11)
    prog = [("F", "maj9"), ("E", "m7"), ("D", "m9"), ("C", "maj9")] * 2 + \
           [("A#", "maj7"), ("A", "m7"), ("G", "m7"), ("C", "7")] + [("F", "maj9"), ("E", "m7"), ("D", "m9"), ("G", "7")]
    mel_scale = ["C5", "D5", "E5", "F5", "G5", "A5", "C6"]
    for bar, (root, q) in enumerate(prog):
        b0 = bar * 4
        notes = chord(root, q, 3)
        for i, f in enumerate(notes):
            tr.add(epiano(f, 3.2, 0.32), b0 + i * 0.02, pan=-0.25 + 0.15 * i)
        # off-beat stab
        for f in notes[1:]:
            tr.add(epiano(f * 2, 0.6, 0.12), b0 + 2.5, pan=0.3)
        tr.add(bass(chord(root, "maj", 1)[0], 1.6, 0.75), b0)
        tr.add(bass(chord(root, "maj", 1)[0] * (1.5 if bar % 2 else 1.0), 0.8, 0.55), b0 + 2.5, swing=0.28)
        # drums
        tr.add(kick(0.8), b0); tr.add(kick(0.55), b0 + 2.5, swing=0.28)
        tr.add(snare(tr.rng, 0.35), b0 + 1); tr.add(snare(tr.rng, 0.35), b0 + 3)
        for h in range(8):
            tr.add(hat(tr.rng, 0.10 if h % 2 else 0.16), b0 + h * 0.5, pan=0.35, swing=0.28)
        # sparse melody on the second half
        if bar >= 8 and bar % 2 == 0:
            for k in range(3):
                f = hz(mel_scale[int(tr.rng.integers(0, len(mel_scale)))])
                tr.add(bell(f, 1.4, 0.22), b0 + 0.5 + k * 1.0 + (0.5 if k == 2 else 0), pan=0.2, swing=0.28)
    tr.add(crackle(tr.rng, tr.length), 0, gain=1.0)
    return tr.render(reverb=0.28, room=2.0, master_lp=9000)


def track_cinematic() -> np.ndarray:
    """'First Bell' - soft pads, e-piano arpeggio, a hopeful bell line. No drums."""
    tr = Track(bpm=68, bars=16, seed=23)
    prog = [("C", "add9"), ("G", "maj"), ("A", "m7"), ("F", "maj9")] * 3 + \
           [("D", "m7"), ("G", "sus2"), ("E", "m7"), ("F", "maj7")]
    melody = ["E5", "G5", "A5", "G5", "E5", "D5", "C5", "D5", "E5", "G5", "C6", "B5", "A5", "G5", "E5", "D5"]
    for bar, (root, q) in enumerate(prog):
        b0 = bar * 4
        notes = chord(root, q, 3)
        for f in notes:
            tr.add(pad(f, 4.4, 0.16, bright=1400), b0, pan=tr.rng.uniform(-0.5, 0.5))
        tr.add(pad(notes[0] / 2, 4.4, 0.18, bright=500), b0)
        arp = notes + [notes[1] * 2]
        for s in range(8):
            tr.add(epiano(arp[s % len(arp)] * 2, 0.9, 0.16), b0 + s * 0.5, pan=0.4 * np.sin(s))
        if bar >= 4:
            tr.add(bell(hz(melody[bar]), 3.0, 0.28), b0 + 1.0, pan=0.15)
    tr.add(crackle(tr.rng, tr.length, amount=0.006), 0)
    return tr.render(reverb=0.45, room=3.2, master_lp=10000)


def track_classroom() -> np.ndarray:
    """'Chalk Talk' - bright, light and busy but quiet enough to think over."""
    tr = Track(bpm=96, bars=16, seed=37)
    prog = [("D", "maj7"), ("B", "m7"), ("G", "maj7"), ("A", "7")] * 4
    scale = ["D5", "E5", "F#5", "A5", "B5", "D6"]
    for bar, (root, q) in enumerate(prog):
        b0 = bar * 4
        notes = chord(root, q, 3)
        for f in notes:
            tr.add(epiano(f, 1.8, 0.2), b0, pan=-0.2)
            tr.add(epiano(f, 1.2, 0.12), b0 + 2.0, pan=-0.2)
        pattern = [0, 2, 1, 3, 2, 1, 3, 0]
        for s, p in enumerate(pattern):
            tr.add(pluck(notes[p % len(notes)] * 2, 0.3, 0.16, cutoff=2600), b0 + s * 0.5, pan=0.45)
        r = chord(root, "maj", 1)[0]
        for s, mult in enumerate([1, 1, 1.5, 1, 2, 1.5, 1, 1.335]):
            tr.add(bass(r * mult, 0.45, 0.5), b0 + s * 0.5)
        tr.add(kick(0.55), b0); tr.add(kick(0.45), b0 + 2)
        tr.add(snare(tr.rng, 0.18), b0 + 1); tr.add(snare(tr.rng, 0.18), b0 + 3)
        for h in range(8):
            tr.add(hat(tr.rng, 0.07), b0 + h * 0.5, pan=0.3)
        if bar % 4 == 3:
            for k in range(4):
                tr.add(bell(hz(scale[int(tr.rng.integers(0, len(scale)))]), 0.8, 0.14), b0 + k * 0.75, pan=-0.3)
    return tr.render(reverb=0.2, room=1.6, master_lp=11000)


def track_tension() -> np.ndarray:
    """'Sideways' - A minor pulse, ticking clock, rising pad. For the capstone gym."""
    tr = Track(bpm=104, bars=16, seed=53)
    prog = [("A", "min"), ("A", "min"), ("F", "maj"), ("G", "maj"),
            ("A", "min"), ("D", "min"), ("E", "7"), ("E", "7")] * 2
    for bar, (root, q) in enumerate(prog):
        b0 = bar * 4
        notes = chord(root, q, 3)
        for f in notes:
            tr.add(pad(f, 4.3, 0.14, bright=900 + bar * 60), b0, pan=tr.rng.uniform(-0.4, 0.4))
        r = chord(root, "maj", 1)[0]
        for s in range(8):
            tr.add(bass(r, 0.32, 0.62 if s % 2 == 0 else 0.42), b0 + s * 0.5)
        tr.add(kick(0.7), b0); tr.add(kick(0.7), b0 + 2)
        if bar >= 4:
            tr.add(snare(tr.rng, 0.28), b0 + 1); tr.add(snare(tr.rng, 0.28), b0 + 3)
        for s in range(4):  # clock tick
            tr.add(pluck(hz("E6"), 0.05, 0.12, cutoff=6000), b0 + s, pan=0.6)
            tr.add(pluck(hz("B5"), 0.05, 0.08, cutoff=6000), b0 + s + 0.5, pan=-0.6)
        if bar >= 8:
            for s in range(16):
                tr.add(hat(tr.rng, 0.06), b0 + s * 0.25, pan=0.2)
    return tr.render(reverb=0.22, room=1.8, master_lp=9500)


TRACKS = {
    "hub": track_hub,
    "cinematic": track_cinematic,
    "classroom": track_classroom,
    "tension": track_tension,
}

if __name__ == "__main__":
    names = sys.argv[1:] or list(TRACKS)
    for name in names:
        audio = TRACKS[name]()
        path = write_ogg(name, audio)
        print(f"{name}: {len(audio) / SR:.1f}s -> {path.relative_to(ROOT)} ({path.stat().st_size // 1024} KB)")
