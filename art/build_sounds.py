"""Make the game's sound effects and music (DECISIONS 042).

Everything here is synthesised from scratch: sine, triangle and soft square
waves, plus filtered noise, shaped by envelopes. No samples, no recordings,
so there's nothing to license and nothing to download. The same idea as
art/build_ground.py: the script is the source, the files are its output.

Output:
  assets/audio/sfx/<name>.wav    short sounds, one per thing that happens
                                 (the names are the keys in
                                 data/audio/sound_bank.tres)
  assets/audio/music/<name>.ogg  two loops: farm.ogg and town.ogg

The music is written out note by note below (melody, chords) and rendered
"round the loop": a note that rings past the end of the tune wraps round to
its start, so the loop joins without a click or a gap.

Needs Python 3 with numpy, and ffmpeg on the PATH for the .ogg files.
Run from the project root:  python3 art/build_sounds.py
"""
import os
import subprocess
import wave

import numpy as np

RATE = 44100
SFX_DIR = "assets/audio/sfx"
MUSIC_DIR = "assets/audio/music"
rng = np.random.default_rng(42)  # fixed seed: the same sounds every run


# --- Building blocks ---------------------------------------------------------

def t_of(seconds: float) -> np.ndarray:
    return np.arange(int(seconds * RATE)) / RATE


def midi_hz(note: float) -> float:
    return 440.0 * 2 ** ((note - 69) / 12)


def sweep_phase(f0: float, f1: float, seconds: float, curve: float = 1.0) -> np.ndarray:
    """Phase of a tone gliding from f0 to f1 Hz (curve > 1 lingers near f0)."""
    t = t_of(seconds)
    f = f0 + (f1 - f0) * (t / seconds) ** curve
    return 2 * np.pi * np.cumsum(f) / RATE


def tone(phase: np.ndarray, shape: str = "sine") -> np.ndarray:
    """A wave from a phase. Square and triangle are built from a few
    harmonics only, so they're soft and never buzzy."""
    if shape == "sine":
        return np.sin(phase)
    if shape == "triangle":
        return sum(((-1) ** k) * np.sin((2 * k + 1) * phase) / (2 * k + 1) ** 2
                   for k in range(4)) * 0.81
    if shape == "square":
        return sum(np.sin((2 * k + 1) * phase) / (2 * k + 1) for k in range(5)) * 0.9
    if shape == "pulse":  # thinner, reedy: a 25% pulse, first harmonics only
        return sum(np.sin(n * np.pi * 0.25) * np.sin(n * phase) / n for n in range(1, 9)) * 1.1
    raise ValueError(shape)


def env(n: int, attack: float = 0.005, release: float = 0.1, hold: float = 0.0) -> np.ndarray:
    """Rise over `attack` s, stay up for `hold` s, then decay exponentially
    over the rest of the sound (`release` is roughly how long it rings)."""
    e = np.ones(n)
    a = max(1, int(attack * RATE))
    e[:a] = np.linspace(0, 1, a)
    h = a + int(hold * RATE)
    if h < n:
        e[h:] = np.exp(-np.arange(n - h) / (release * RATE) * 3.0)
    return e


def noise(seconds: float) -> np.ndarray:
    return rng.uniform(-1, 1, int(seconds * RATE))


def smooth(x: np.ndarray, width: int) -> np.ndarray:
    """A gentle low-pass: a moving average `width` samples wide."""
    if width <= 1:
        return x
    return np.convolve(x, np.ones(width) / width, mode="same")


def highpass(x: np.ndarray, width: int) -> np.ndarray:
    return x - smooth(x, width)


def at(seconds: float, sound: np.ndarray, total: float) -> np.ndarray:
    """`sound` placed `seconds` into a silence `total` seconds long."""
    out = np.zeros(int(total * RATE))
    i = int(seconds * RATE)
    n = min(len(sound), len(out) - i)
    out[i:i + n] += sound[:n]
    return out


def mix(*parts: np.ndarray) -> np.ndarray:
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def note(midi: float, seconds: float, shape: str = "square", release: float = 0.12,
         attack: float = 0.004, vibrato: float = 0.0) -> np.ndarray:
    t = t_of(seconds)
    f = midi_hz(midi) * (1 + vibrato * np.sin(2 * np.pi * 5.5 * t) * np.clip(t * 4, 0, 1))
    phase = 2 * np.pi * np.cumsum(f) / RATE
    return tone(phase, shape) * env(len(t), attack, release)


def write_wav(path: str, x: np.ndarray, peak: float) -> None:
    """16-bit mono, scaled so its loudest point is `peak` (0..1). Each sound's
    peak is chosen by ear against the others, so the bank needs no volumes."""
    x = x / (np.max(np.abs(x)) or 1) * peak
    # A 3 ms fade at each end, so no sound starts or stops with a click.
    f = min(len(x) // 2, int(0.003 * RATE))
    x[:f] *= np.linspace(0, 1, f)
    x[-f:] *= np.linspace(1, 0, f)
    data = (np.clip(x, -1, 1) * 32767).astype("<i2").tobytes()
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)


# --- Sound effects -----------------------------------------------------------
# One function per sound. Short and quiet: they happen dozens of times a day.

def sfx_till():
    # A spade in soil: a low thud and a short gritty crunch.
    thud = tone(sweep_phase(110, 55, 0.14)) * env(int(0.14 * RATE), 0.002, 0.05)
    crunch = smooth(noise(0.09), 6) * env(int(0.09 * RATE), 0.001, 0.03)
    return mix(thud * 0.9, crunch * 0.7)


def sfx_water():
    # A splash of water: a soft rush of noise with three bubbles in it.
    n = int(0.42 * RATE)
    rush = smooth(noise(0.42), 3) - smooth(noise(0.42), 30)
    rush *= env(n, 0.02, 0.12, hold=0.05)
    parts = [rush * 0.5]
    for start, f0 in ((0.04, 700), (0.11, 950), (0.19, 820)):
        b = tone(sweep_phase(f0, f0 * 1.8, 0.05)) * env(int(0.05 * RATE), 0.002, 0.015)
        parts.append(at(start, b * 0.35, 0.42))
    return mix(*parts)


def sfx_plant():
    # A seed pressed in: a small soft "pip".
    pip = tone(sweep_phase(320, 520, 0.07)) * env(int(0.07 * RATE), 0.002, 0.025)
    pat = smooth(noise(0.04), 8) * env(int(0.04 * RATE), 0.001, 0.01)
    return mix(pip, pat * 0.4)


def sfx_harvest():
    # Pulled up: a pop, then two bright rising notes.
    pop = tone(sweep_phase(180, 760, 0.05)) * env(int(0.05 * RATE), 0.001, 0.02)
    a = note(84, 0.09, "square", 0.04)
    b = note(91, 0.22, "square", 0.08)
    return mix(pop * 0.8, at(0.04, a * 0.35, 0.3), at(0.1, b * 0.35, 0.36))


def sfx_coins():
    # Money changes hands: the classic two-note coin.
    a = note(83, 0.07, "square", 0.03)
    b = note(88, 0.32, "square", 0.1)
    return mix(a, at(0.065, b, 0.4))


def sfx_ship():
    # The bin lid: a wooden knock, then a lower coin.
    knock = tone(sweep_phase(200, 150, 0.08)) * env(int(0.08 * RATE), 0.001, 0.025)
    knock2 = smooth(noise(0.05), 4) * env(int(0.05 * RATE), 0.001, 0.012)
    a = note(76, 0.07, "square", 0.03)
    b = note(81, 0.28, "square", 0.09)
    return mix(knock, knock2 * 0.5, at(0.12, a * 0.45, 0.5), at(0.185, b * 0.45, 0.5))


def sfx_place():
    # Something set down on the grass: a soft thunk and a puff of dust.
    thunk = tone(sweep_phase(150, 80, 0.12)) * env(int(0.12 * RATE), 0.002, 0.04)
    dust = smooth(noise(0.15), 10) * env(int(0.15 * RATE), 0.01, 0.05)
    return mix(thunk, dust * 0.5)


def sfx_pick_up():
    # Picked back up: a quick upward blip.
    return tone(sweep_phase(380, 900, 0.09, 0.6)) * env(int(0.09 * RATE), 0.002, 0.04)


def sfx_talk():
    # Someone speaks: a little two-syllable burble.
    a = note(74, 0.06, "triangle", 0.02, vibrato=0.02)
    b = note(79, 0.09, "triangle", 0.03, vibrato=0.02)
    return mix(a, at(0.07, b, 0.2))


def sfx_quest_done():
    # A request handed in: a rising arpeggio that settles.
    parts = []
    for i, m in enumerate((72, 76, 79, 84)):
        parts.append(at(i * 0.075, note(m, 0.12, "pulse", 0.05), 1.0))
    parts.append(at(0.3, note(88, 0.6, "pulse", 0.25, vibrato=0.004) * 0.9, 1.0))
    parts.append(at(0.3, note(84, 0.6, "triangle", 0.25) * 0.5, 1.0))
    return mix(*parts)


def sfx_chime():
    # A request taken on, or a step towards one: a single soft bell.
    a = note(81, 0.5, "sine", 0.18)
    b = note(88, 0.5, "sine", 0.14) * 0.4
    c = note(93, 0.5, "sine", 0.08) * 0.15
    return mix(a, b, c)


def sfx_door():
    # Through a door: a muffled whump and a latch click.
    whump = smooth(noise(0.25), 40) * env(int(0.25 * RATE), 0.02, 0.07)
    low = tone(sweep_phase(90, 60, 0.2)) * env(int(0.2 * RATE), 0.01, 0.06)
    click = highpass(noise(0.015), 3) * env(int(0.015 * RATE), 0.0005, 0.004)
    return mix(whump * 1.4, low * 0.6, at(0.16, click * 0.5, 0.3))


def sfx_collapse():
    # Out of energy: a slow sliding fall.
    t = t_of(0.7)
    f = 520 * (120 / 520) ** (t / 0.7)
    f *= 1 + 0.03 * np.sin(2 * np.pi * 6 * t)
    return tone(2 * np.pi * np.cumsum(f) / RATE, "triangle") * env(len(t), 0.01, 0.4, hold=0.2)


def sfx_sleep():
    # Into bed: three gentle bells going down, like a music box.
    parts = []
    for i, m in enumerate((79, 76, 72)):
        bell = note(m, 0.9, "sine", 0.35) + note(m + 12, 0.9, "sine", 0.15) * 0.25
        parts.append(at(i * 0.28, bell, 1.6))
    return mix(*parts)


def sfx_morning():
    # Dawn: a bird, three quick chirps and a trill.
    parts = []
    for start, f0, f1, d in ((0.0, 2600, 3900, 0.06), (0.1, 2800, 4100, 0.05),
                             (0.18, 3000, 4300, 0.05), (0.36, 4200, 3000, 0.12)):
        t = t_of(d)
        ph = sweep_phase(f0, f1, d, 0.7)
        trill = 1 + 0.5 * np.sin(2 * np.pi * 38 * t)
        parts.append(at(start, tone(ph) * env(len(t), 0.004, d / 2.5) * trill, 0.6))
    return mix(*parts)


def sfx_tick():
    # Moving along the hotbar: a tiny dry click.
    return mix(note(96, 0.03, "sine", 0.008), highpass(noise(0.008), 2) * 0.3)


def sfx_paper():
    # Reading the notice board: a rustle of paper.
    n = int(0.22 * RATE)
    x = highpass(noise(0.22), 6)
    flutter = 0.6 + 0.4 * np.sin(2 * np.pi * 23 * t_of(0.22))
    return x * env(n, 0.02, 0.08, hold=0.04) * flutter


def sfx_nope():
    # Nothing happened (an empty bin): two low notes going down.
    a = note(62, 0.08, "square", 0.03)
    b = note(58, 0.14, "square", 0.05)
    return mix(a, at(0.09, b, 0.3))


def sfx_menu():
    # Closing a screen: a soft confirming blip.
    return mix(note(88, 0.06, "triangle", 0.02), at(0.04, note(93, 0.08, "triangle", 0.03), 0.12))


SFX = {
    # name: (function, peak loudness)
    "till": (sfx_till, 0.55),
    "water": (sfx_water, 0.45),
    "plant": (sfx_plant, 0.45),
    "harvest": (sfx_harvest, 0.55),
    "coins": (sfx_coins, 0.4),
    "ship": (sfx_ship, 0.5),
    "place": (sfx_place, 0.55),
    "pick_up": (sfx_pick_up, 0.4),
    "talk": (sfx_talk, 0.45),
    "quest_done": (sfx_quest_done, 0.5),
    "chime": (sfx_chime, 0.4),
    "door": (sfx_door, 0.6),
    "collapse": (sfx_collapse, 0.5),
    "sleep": (sfx_sleep, 0.45),
    "morning": (sfx_morning, 0.25),
    "tick": (sfx_tick, 0.25),
    "paper": (sfx_paper, 0.35),
    "nope": (sfx_nope, 0.35),
    "menu": (sfx_menu, 0.3),
}


# --- Music -------------------------------------------------------------------
# A tune is a melody (MIDI note, length in eighths; None is a rest) over one
# chord per half-bar, and a few backing parts that follow the chords.

CHORDS = {  # chord name -> MIDI notes of a root-position triad, around middle C
    "F": (53, 57, 60), "Dm": (50, 53, 57), "Bb": (46, 50, 53), "C": (48, 52, 55),
    "Am": (45, 48, 52), "Gm": (43, 46, 50), "G": (43, 47, 50), "Em": (40, 43, 47),
    "D": (50, 54, 57), "Bm": (47, 50, 54),
}


def render_loop(bars: int, bpm: float, events: list) -> np.ndarray:
    """Mix (start_seconds, sound) pairs into a loop `bars` long. Anything that
    rings past the end wraps round to the start (see the docstring above)."""
    length = int(bars * 4 * 60 / bpm * RATE)
    out = np.zeros(length)
    for start, sound in events:
        i = int(start * RATE) % length
        while len(sound) > 0:
            n = min(len(sound), length - i)
            out[i:i + n] += sound[:n]
            sound = sound[n:]
            i = 0
    return out


def tune(bpm, melody, chords, lead_shape, lead_vol, bass_style, arp_vol, drums, swing=0.0):
    eighth = 60 / bpm / 2
    bars = len(chords) // 2
    events = []

    # Swing pushes every off-beat eighth a little later, for a lilt.
    def when(eighths: float) -> float:
        whole = int(eighths)
        return (whole + (swing if whole % 2 else 0.0) + (eighths - whole)) * eighth

    # Melody
    pos = 0
    for midi, length in melody:
        if midi is not None:
            snd = note(midi, length * eighth + 0.25, lead_shape, release=0.18 + length * 0.04,
                       attack=0.01, vibrato=0.006)
            events.append((when(pos), snd * lead_vol))
        pos += length
    assert pos == bars * 8, f"melody is {pos} eighths, chords want {bars * 8}"

    for half, name in enumerate(chords):
        root, third, fifth = CHORDS[name]
        start = half * 4  # in eighths
        # Bass
        if bass_style == "calm":   # root, then the fifth, on the beat
            for k, m in enumerate((root - 12, fifth - 12)):
                events.append((when(start + k * 2), note(m, eighth * 2.2, "triangle", 0.25) * 0.5))
        else:                      # bouncy: root-root-fifth-root in eighths
            for k, m in enumerate((root - 12, root, fifth - 12, root - 12)):
                events.append((when(start + k), note(m, eighth * 0.9, "triangle", 0.08) * 0.5))
        # Arpeggio: the chord broken up, quietly, an octave up
        for k, m in enumerate((root, third, fifth, third)):
            events.append((when(start + k), note(m + 12, eighth * 1.6, "pulse", 0.07) * arp_vol))
        # Drums
        for k in range(4):
            hit = start + k
            if drums.get("shaker") and k % 2 == 1:
                s = highpass(noise(0.05), 3) * env(int(0.05 * RATE), 0.004, 0.015)
                events.append((when(hit), s * drums["shaker"]))
            if drums.get("kick") and k == 0:
                s = tone(sweep_phase(140, 45, 0.16)) * env(int(0.16 * RATE), 0.002, 0.06)
                events.append((when(hit), s * drums["kick"]))
            if drums.get("snare") and k == 2 and half % 2 == 1:
                s = smooth(noise(0.12), 3) * env(int(0.12 * RATE), 0.002, 0.035)
                events.append((when(hit), s * drums["snare"]))
    out = render_loop(bars, bpm, events)
    # Round the very top off the whole mix, a little warmer.
    return smooth(out, 3)


def farm_tune() -> np.ndarray:
    """Calm, in F major, 84 bpm: a section played twice, a middle, and the
    first again. About a minute and a half before it repeats."""
    r = None
    A = [(69, 2), (72, 2), (77, 3), (76, 1),
         (74, 4), (72, 2), (69, 2),
         (70, 2), (74, 2), (77, 2), (74, 2),
         (72, 6), (r, 2),
         (69, 2), (72, 2), (77, 2), (79, 2),
         (81, 3), (79, 1), (77, 2), (74, 2),
         (74, 2), (72, 2), (76, 2), (79, 2),
         (77, 6), (r, 2)]
    B = [(77, 2), (74, 2), (70, 4),
         (72, 2), (76, 2), (79, 4),
         (81, 2), (79, 2), (76, 2), (72, 2),
         (74, 6), (r, 2),
         (70, 2), (74, 2), (79, 2), (77, 2),
         (76, 2), (72, 2), (67, 4),
         (69, 2), (72, 2), (77, 2), (81, 2),
         (79, 4), (76, 2), (72, 2)]
    a_chords = ["F", "F", "Dm", "Dm", "Bb", "Bb", "C", "C",
                "F", "F", "Dm", "Dm", "Bb", "C", "F", "F"]
    b_chords = ["Bb", "Bb", "C", "C", "Am", "Am", "Dm", "Dm",
                "Gm", "Gm", "C", "C", "F", "F", "C", "C"]
    return tune(84, A + A + B + A, a_chords * 2 + b_chords + a_chords,
                "triangle", 0.42, "calm", 0.07, {"shaker": 0.05})


def town_tune() -> np.ndarray:
    """Busier, in G major, 108 bpm with a little swing: two sections, each
    played twice. About 70 seconds."""
    r = None
    A = [(74, 1), (r, 1), (71, 1), (74, 1), (79, 2), (78, 1), (76, 1),
         (76, 2), (71, 2), (67, 2), (71, 2),
         (72, 1), (r, 1), (76, 1), (79, 1), (76, 2), (72, 2),
         (74, 2), (78, 2), (81, 3), (r, 1),
         (83, 2), (81, 1), (79, 1), (74, 2), (71, 2),
         (76, 1), (78, 1), (79, 2), (76, 2), (71, 2),
         (72, 2), (76, 2), (74, 2), (78, 2),
         (79, 4), (74, 2), (r, 2)]
    B = [(76, 2), (79, 2), (72, 2), (76, 2),
         (78, 2), (81, 2), (74, 2), (78, 2),
         (74, 2), (71, 1), (74, 1), (78, 2), (74, 2),
         (76, 6), (r, 2),
         (72, 1), (74, 1), (76, 1), (79, 1), (81, 2), (79, 2),
         (78, 2), (76, 2), (74, 2), (69, 2),
         (71, 2), (74, 2), (79, 2), (83, 2),
         (81, 4), (78, 2), (74, 2)]
    a_chords = ["G", "G", "Em", "Em", "C", "C", "D", "D",
                "G", "G", "Em", "Em", "C", "D", "G", "G"]
    b_chords = ["C", "C", "D", "D", "Bm", "Bm", "Em", "Em",
                "C", "C", "D", "D", "G", "G", "D", "D"]
    return tune(108, A + A + B + B, a_chords * 2 + b_chords * 2,
                "pulse", 0.3, "bouncy", 0.08, {"shaker": 0.06, "kick": 0.35, "snare": 0.12},
                swing=0.18)


def write_ogg(path: str, x: np.ndarray, peak: float) -> None:
    tmp = path + ".tmp.wav"
    write_wav_raw(tmp, x / (np.max(np.abs(x)) or 1) * peak)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp,
                    "-c:a", "libvorbis", "-q:a", "4", path], check=True)
    os.remove(tmp)


def write_wav_raw(path: str, x: np.ndarray) -> None:
    """Like write_wav, but without the fades: a loop's ends must meet."""
    data = (np.clip(x, -1, 1) * 32767).astype("<i2").tobytes()
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)


def main() -> None:
    os.makedirs(SFX_DIR, exist_ok=True)
    os.makedirs(MUSIC_DIR, exist_ok=True)
    for name, (make, peak) in SFX.items():
        write_wav(f"{SFX_DIR}/{name}.wav", make(), peak)
        print("sfx", name)
    write_ogg(f"{MUSIC_DIR}/farm.ogg", farm_tune(), 0.6)
    print("music farm")
    write_ogg(f"{MUSIC_DIR}/town.ogg", town_tune(), 0.6)
    print("music town")


if __name__ == "__main__":
    main()
