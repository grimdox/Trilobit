#!/usr/bin/env python3
"""Synthesize ambient synthwave test tracks (numpy/scipy + ffmpeg -> Ogg Vorbis).

Usage: gen_music.py <repo>
Writes data/sound/Basic/music/*.ogg and the 'title' playlist in musicset.json
(the 'title' playlist is what the engine plays whenever no other music is active,
i.e. on the menu and while exploring).
"""
import json, os, subprocess, sys, tempfile
import numpy as np
from scipy.signal import lfilter, fftconvolve
from scipy.io import wavfile

SR = 44100
repo = sys.argv[1]
rng = np.random.default_rng(7)


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def lowpass(x, fc):
    a = np.exp(-2 * np.pi * fc / SR)
    return lfilter([1 - a], [1, -a], x)


def lp2(x, fc):
    return lowpass(lowpass(x, fc), fc)


def saw(f, n, ph=0.0):
    t = (np.arange(n) / SR * f + ph) % 1.0
    return 2 * t - 1


def env(n, a, d, s, r):
    e = np.ones(n)
    na, nd, nr = int(a * SR), int(d * SR), int(r * SR)
    na = min(na, n)
    e[:na] = np.linspace(0, 1, max(na, 1))
    nd2 = min(nd, n - na)
    e[na:na + nd2] = np.linspace(1, s, max(nd2, 1))
    e[na + nd2:] = s
    nr = min(nr, n)
    e[n - nr:] *= np.linspace(1, 0, max(nr, 1))
    return e


def pad(notes, dur, cutoff=1400):
    n = int(dur * SR)
    out = np.zeros(n)
    for m in notes:
        for det in (-0.12, 0.0, 0.1):
            f = hz(m) * 2 ** (det / 12)
            out += saw(f, n, rng.random())
    out = lp2(out, cutoff) / (len(notes) * 3)
    return out * env(n, 1.4, 0.5, 0.85, 1.8)


def pluck(m, dur, cutoff=3200, decay=0.25):
    n = int(dur * SR)
    x = saw(hz(m), n) + 0.6 * saw(hz(m) * 1.004, n)
    fe = np.exp(-np.arange(n) / SR / decay)
    # cheap filter sweep: blend of two lowpasses by envelope
    lo, hi = lowpass(x, 500), lowpass(x, cutoff)
    y = lo + (hi - lo) * fe
    return y * np.exp(-np.arange(n) / SR / (decay * 2.2)) * 0.5


def bass(m, dur):
    n = int(dur * SR)
    x = saw(hz(m), n) * 0.6 + np.sin(2 * np.pi * hz(m) * np.arange(n) / SR)
    return lowpass(x, 260) * env(n, 0.02, 0.1, 0.8, 0.15) * 0.6


def bell(m, dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * hz(m) * t) + 0.4 * np.sin(2 * np.pi * hz(m) * 2.76 * t) * np.exp(-t * 3)
    return x * np.exp(-t * 1.3) * 0.35


def kick(vol=1.0):
    n = int(0.35 * SR)
    t = np.arange(n) / SR
    f = 45 + 90 * np.exp(-t * 28)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-t * 9) * vol


def hat(vol=0.3):
    n = int(0.06 * SR)
    x = rng.standard_normal(n)
    x = x - lowpass(x, 6000)
    return x * np.exp(-np.arange(n) / SR / 0.012) * vol


def snare(vol=0.5):
    n = int(0.25 * SR)
    t = np.arange(n) / SR
    x = lowpass(rng.standard_normal(n), 5000) * np.exp(-t * 18)
    x += np.sin(2 * np.pi * 190 * t) * np.exp(-t * 25) * 0.5
    return x * vol


def put(buf, x, pos):
    pos = int(pos)
    if pos >= len(buf):
        return
    e = min(len(buf), pos + len(x))
    buf[pos:e] += x[:e - pos]


def delay(x, secs, fb=0.45, mix=0.4):
    d = int(secs * SR)
    y = x.copy()
    for k in range(1, 6):
        s = np.zeros_like(x)
        s[d * k:] = x[:len(x) - d * k] * (fb ** k) if d * k < len(x) else 0
        y += lowpass(s, 2500) * mix
    return y


def reverb(x, secs=3.2, mix=0.35):
    n = int(secs * SR)
    ir = rng.standard_normal(n) * np.exp(-np.arange(n) / SR / (secs / 4.5))
    ir = lowpass(ir, 4500)
    ir[: int(0.02 * SR)] *= np.linspace(0, 1, int(0.02 * SR))
    wet = fftconvolve(x, ir)[:len(x)]
    wet /= np.max(np.abs(wet)) + 1e-9
    return x * (1 - mix) + wet * mix * np.max(np.abs(x))


def track(name, bpm, prog, root_notes, arp_pat, beats_per_chord=8, bars_chords=2,
          drums=True, lead=None, minutes=1.7, cutoff=1300):
    beat = 60 / bpm
    chord_len = beats_per_chord * beat
    total_chords = int(minutes * 60 / chord_len)
    total = int((total_chords * chord_len + 6) * SR)
    L = np.zeros(total)
    R = np.zeros(total)
    pads = np.zeros(total)
    arp = np.zeros(total)
    bs = np.zeros(total)
    dr = np.zeros(total)
    ld = np.zeros(total)
    for ci in range(total_chords):
        ch = prog[ci % len(prog)]
        t0 = ci * chord_len * SR
        put(pads, pad(ch["pad"], chord_len + 2.5, cutoff), t0)
        # bass: root pulses
        for b in range(beats_per_chord * 2):
            if b % 2 == 0 or b % 8 == 7:
                put(bs, bass(ch["bass"], beat * 0.45), t0 + b * beat / 2 * SR)
        # arp
        step = beat / 2
        for i in range(beats_per_chord * 2):
            if ci >= 1 and arp_pat[i % len(arp_pat)] is not None:
                m = ch["arp"][arp_pat[i % len(arp_pat)] % len(ch["arp"])]
                put(arp, pluck(m, step * 2.5), t0 + i * step * SR)
        # drums (enter after first 2 chords, drop out every 8th chord for breathing)
        if drums and ci >= 2 and ci % 8 != 7:
            for b in range(beats_per_chord):
                pos = t0 + b * beat * SR
                if b % 2 == 0:
                    put(dr, kick(0.8), pos)
                if b % 4 == 2:
                    put(dr, snare(0.35), pos)
                put(dr, hat(0.18), pos + beat * 0.5 * SR)
        # sparse lead
        if lead and ci >= 3 and ci % 2 == 1:
            for k, (b, m) in enumerate(lead[ci % len(lead)]):
                put(ld, bell(m, 3.5), t0 + b * beat * SR)
    arp = delay(arp, beat * 0.75, 0.5, 0.5)
    ld = delay(ld, beat * 1.5, 0.55, 0.6)
    # sidechain-ish pump from kick positions is skipped; keep it gentle
    mix = pads * 0.85 + arp * 0.55 + bs * 0.7 + dr * 0.8 + ld * 0.6
    mix = reverb(mix, 3.4, 0.33)
    # stereo: slight haas + pad width
    wide = np.roll(mix, int(0.012 * SR))
    L = mix * 0.7 + wide * 0.3
    R = wide * 0.7 + mix * 0.3
    st = np.stack([L, R], 1)
    # fade
    n = len(st)
    fi, fo = int(3 * SR), int(5 * SR)
    st[:fi] *= np.linspace(0, 1, fi)[:, None]
    st[-fo:] *= np.linspace(1, 0, fo)[:, None]
    st = st / np.max(np.abs(st)) * 0.8
    return st


def write_ogg(st, path):
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        wavfile.write(f.name, SR, (st * 32767).astype(np.int16))
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", f.name, "-c:a", "libvorbis",
                        "-q:a", "3", path], check=True)
        os.unlink(f.name)


M = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def ch(root, kind, base=57):
    r = base + root
    third = 3 if kind == "m" else 4
    tri = [r, r + third, r + 7]
    return {"pad": [r - 12 + 12, r + third + 0, r + 7, r + 12 + third - 12 + 12],
            "bass": r - 24 + 12 - 12 + 12 - 12, "arp": [r + 12, r + 12 + third, r + 19, r + 24]}


def mkprog(spec, base=57):
    out = []
    for r, k in spec:
        c = ch(r, k, base)
        c["bass"] = base + r - 24
        out.append(c)
    return out


TRACKS = [
    # name, bpm, progression (semitone root from A, kind), arp pattern, lead
    ("neon_rain", 84, mkprog([(0, "m"), (8, "M"), (3, "M"), (10, "M")]),
     [0, 2, 1, 3, 2, 1, 3, 2], [[(0, 81), (3, 79)], [(1, 76), (5, 74)]]),
    ("chrome_district", 96, mkprog([(5, "m"), (1, "M"), (8, "M"), (3, "M")], 52),
     [0, 1, 2, 3, 2, 1, None, 2], [[(0, 74), (4, 77)], [(2, 72), (6, 69)]]),
    ("last_train", 72, mkprog([(7, "m"), (3, "M"), (10, "M"), (5, "M")], 55),
     [0, None, 2, None, 1, None, 3, None], [[(0, 79), (6, 83)], [(3, 76), (7, 74)]]),
]

out = os.path.join(repo, "data/sound/Basic/music")
os.makedirs(out, exist_ok=True)
files = []
for name, bpm, prog, pat, lead in TRACKS:
    st = track(name, bpm, prog, None, pat, lead=lead, drums=(name != "last_train"), minutes=1.6)
    p = os.path.join(out, name + ".ogg")
    write_ogg(st, p)
    files.append({"file": "music/" + name + ".ogg", "volume": 55})
    print(name, os.path.getsize(p) // 1024, "KB", round(len(st) / SR), "s")

ms = os.path.join(repo, "data/sound/Basic/musicset.json")
json.dump([{"type": "playlist", "playlists": []}] if os.environ.get("TRL_MUSIC") != "1" else [{"type": "playlist", "playlists": [{"id": "title", "shuffle": True, "files": files}]}],
          open(ms, "w"), indent=2)
print("playlist written")
