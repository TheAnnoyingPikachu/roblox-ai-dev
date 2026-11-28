"""The tortoises' own clips: slow, immovable, and a shell that never bends (no clip here turns the spine). Lengths and
blow times are the game's (idle loop 4.8 s, attack 0.95 s with the blow at 0.44, power 1.6 s with the blow at 0.92,
hit 0.4 s, fall 1.2 s, win 1.6 s). "pull": [d] draws its head and neck back into the shell (negative reaches out);
tucked legs are lifted with the body ("carry") while "drop" sets the shell on the ground."""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import rigpose as rp
from clipsets.quad import cyc, gait, span, TAU

SPRING = (3.2, 0.4)  # a stub of a tail
LOOP = 4.8
JUMP = [1, 1, 1, 1]
IN = 0.16  # the head fully inside the shell
TUCK = {"carry": JUMP, "fl": [0, 0.02, 0.05], "fr": [0, 0.02, 0.05], "hl": [0, -0.02, 0.05], "hr": [0, -0.02, 0.05]}  # legs drawn in


# --- idles ----------------------------------------------------------------------------------------------------------
def idle_plod(t):  # just standing: the shell rises and sinks with each slow breath, the head sways
    return {"body": [0, 0.004 * cyc(t, 2.4), 0.6 * cyc(t, 2.4), 0, 0.8 * cyc(t, 4.8)], "neck": [2 * cyc(t, 2.4, 0.2), 8 * cyc(t, 4.8)],
            "head": [3 * cyc(t, 2.4, 0.3), 10 * cyc(t, 4.8, 0.05)], "pull": [0.004 * cyc(t, 2.4)], "tail": [0, 10 * cyc(t, 1.6), 0]}


def idle_peer(t):  # stretches its neck right out and peers one way, then the other, then settles back
    s = span(t, 0.6, 4.2)
    return {"body": [0.004 * s, 0.004 * cyc(t, 2.4) + 0.004 * s, 3 * s], "neck": [8 * s, 16 * s * cyc(t, 2.2)],
            "head": [8 * s, 20 * s * cyc(t, 2.2, 0.05), 6 * s * cyc(t, 2.2)], "pull": [-0.03 * s], "tail": [0, 8 * cyc(t, 1.6), 0]}


def idle_hide(t):  # something startles it: the head shoots in, the shell settles; after a while one eye comes back out
    h = min(1.0, span(t, 1.0, 4.0) * 3.0)  # in fast, out slowly
    return {"drop": [0.5 * h], "body": [0, 0.004 * cyc(t, 2.4) * (1 - h), 0], "neck": [0, 6 * cyc(t, 4.8) * (1 - h)],
            "head": [0, 8 * cyc(t, 4.8, 0.05) * (1 - h)], "pull": [IN * h], "tail": [0, 8 * cyc(t, 1.6) * (1 - h), 0]}


# --- walks ---------------------------------------------------------------------------------------------------------
def walk_plod(t):  # the game's pace: one leg at a time, three always down; the shell rocks from side to side over them
    return gait(t, 1.0, {"hl": 0.0, "fl": 0.25, "hr": 0.5, "fr": 0.75}, 0.72, 0.045, 0.022,
                lambda c: {"body": [0, 0.003 * math.cos(2 * TAU * c + 0.5), 0.8 * math.sin(2 * TAU * c), 2.5 * math.sin(TAU * c + 0.4),
                                    3.5 * math.sin(TAU * c + 0.4), 0.008 * math.sin(TAU * c + 0.4)],
                           "neck": [2 * math.cos(2 * TAU * c + 0.9), -4 * math.sin(TAU * c + 0.4)],
                           "head": [3 * math.cos(2 * TAU * c + 1.5), -5 * math.sin(TAU * c + 0.4)], "pull": [0.006 * math.cos(2 * TAU * c)],
                           "tail": [0, 10 * math.sin(TAU * c), 0]})


def run_trundle(t):  # in a hurry: diagonal pairs, the shell bouncing, neck stretched out ahead
    return gait(t, 0.56, {"hl": 0.0, "fr": 0.04, "hr": 0.5, "fl": 0.54}, 0.56, 0.05, 0.03,
                lambda c: {"body": [0, 0.008 * abs(math.cos(TAU * c)), -2, 0, 3 * math.sin(TAU * c)],
                           "neck": [4 + 2 * math.cos(2 * TAU * c)], "head": [4 + 3 * math.cos(2 * TAU * c + 0.5), -3 * math.sin(TAU * c)],
                           "pull": [-0.02], "tail": [10, 8 * math.sin(TAU * c), 0]})


def run_slide(t):  # tucks everything in and skates along on its belly plate, spinning slowly
    c = (t / 0.8) % 1
    return {"drop": [0.92], **TUCK, "body": [0, 0.004 * abs(math.sin(TAU * c * 2)), 0, 0, 3 * math.sin(TAU * c)], "root": [0, 0, 0, 0, 360 * c], "pull": [IN]}


# --- one-shots -----------------------------------------------------------------------------------------------------
ATTACKS = {
    "attack_snap": ("Snap", "Draws its head half in, then shoots its neck out to full reach and bites.", 0.95, [
        (0.0, {}),
        (0.26, {"body": [-0.012, -0.004, 2], "neck": [4], "head": [6], "pull": [0.06], "tail": [-6]}, "out"),
        (0.44, {"body": [0.03, -0.004, -3], "neck": [-4], "head": [-8], "pull": [-0.045], "fl": [0, 0.02, 0], "fr": [0, 0.02, 0], "tail": [14]}, "in"),
        (0.50, {"body": [0.028, -0.002, -2], "neck": [2], "head": [10], "pull": [-0.04], "fl": [0, 0.02, 0], "fr": [0, 0.02, 0], "tail": [10]}, "out"),
        (0.74, {"body": [0.01, 0, 0], "head": [3], "pull": [0.01], "fl": [0, 0.01, 0], "fr": [0, 0.01, 0]}),
        (0.95, {})]),
    "attack_ram": ("Shell ram", "Tucks its head in and drives the rim of its shell forward like a battering ram.", 0.95, [
        (0.0, {}),
        (0.26, {"body": [-0.03, -0.008, 3], "pull": [0.05], "hl": [0, -0.01, 0], "hr": [0, -0.01, 0], "tail": [-6]}, "out"),
        (0.44, {"body": [0.08, -0.004, -6], "pull": [IN], "fl": [0, 0.07, 0], "fr": [0, 0.07, 0], "hl": [0, 0.04, 0], "hr": [0, 0.04, 0], "tail": [16]}, "in"),
        (0.52, {"body": [0.074, 0, -3], "pull": [IN], "fl": [0, 0.07, 0], "fr": [0, 0.07, 0], "hl": [0, 0.04, 0], "hr": [0, 0.04, 0], "tail": [10]}, "out"),
        (0.78, {"body": [0.03, 0, 0], "pull": [0.02], "fl": [0, 0.03, 0], "fr": [0, 0.03, 0], "hl": [0, 0.015, 0], "hr": [0, 0.015, 0]}),
        (0.95, {})]),
    "attack_stamp": ("Stamp", "Heaves its front end up and drops both forefeet together.", 0.95, [
        (0.0, {}),
        (0.28, {"body": [-0.01, 0.014, 12], "carry": [1, 1, 0, 0], "fl": [0, 0.01, 0.035], "fr": [0, 0.01, 0.045], "neck": [4], "head": [8], "pull": [-0.01], "tail": [-8]}, "out"),
        (0.44, {"body": [0.02, -0.012, -5], "fl": [0, 0.03, 0], "fr": [0, 0.03, 0], "neck": [-6], "head": [-8], "pull": [0.02], "tail": [16]}, "in"),
        (0.52, {"body": [0.018, -0.004, -2], "fl": [0, 0.03, 0], "fr": [0, 0.03, 0], "head": [-2], "pull": [0.01], "tail": [8]}, "out"),
        (0.76, {"body": [0.008, 0, 0], "fl": [0, 0.015, 0], "fr": [0, 0.015, 0]}),
        (0.95, {})]),
}

POWERS = {
    "power_quake": ("Shell quake", "Rises on straightened legs, hangs, then lets its whole weight fall flat on its belly plate.", 1.6, [
        (0.0, {}),
        (0.30, {"drop": [0.3], "body": [0, 0, 0], "pull": [0.03], "tail": [-6]}, "out"),
        (0.66, {"body": [0, 0.03, 4], "neck": [6], "head": [8], "pull": [-0.02], "tail": [10]}, "out"),
        (0.82, {"body": [0, 0.034, 5], "neck": [7], "head": [10], "pull": [-0.02], "tail": [12]}),
        (0.92, {"drop": [1.0], "body": [0, 0, -1], "pull": [IN], "fl": [0.02, 0.02, 0, 1], "fr": [-0.02, 0.02, 0, 1], "hl": [0.02, -0.02, 0, 1], "hr": [-0.02, -0.02, 0, 1], "tail": [20]}, "in"),
        (1.02, {"drop": [0.85], "body": [0, 0, 0], "pull": [IN], "fl": [0.02, 0.02, 0, 1], "fr": [-0.02, 0.02, 0, 1], "hl": [0.02, -0.02, 0, 1], "hr": [-0.02, -0.02, 0, 1], "tail": [10]}, "out"),
        (1.32, {"drop": [0.3], "pull": [0.03], "fl": [0.01, 0.01, 0, 1], "fr": [-0.01, 0.01, 0, 1], "hl": [0.01, -0.01, 0, 1], "hr": [-0.01, -0.01, 0, 1]}),
        (1.6, {})]),
    "power_spin": ("Spinning shell", "Pulls everything in, drops, and spins on its belly plate like a top before it stops dead.", 1.6, [
        (0.0, {}),
        (0.26, {"drop": [0.9], "pull": [IN], **TUCK}, "out"),
        (0.40, {"drop": [0.92], "pull": [IN], **TUCK, "root": [0, 0, 0, 0, 40]}, "in"),
        (0.92, {"drop": [0.92], "pull": [IN], **TUCK, "root": [0, 0, 0, 0.012, 1040], "body": [0, 0, 0, 0, 5]}, "linear"),
        (1.10, {"drop": [0.92], "pull": [IN], **TUCK, "root": [0, 0, 0, 0, 1080]}, "out"),
        (1.36, {"drop": [0.3], "pull": [0.03], "root": [0, 0, 0, 0, 1080]}),
        (1.6, {"root": [0, 0, 0, 0, 1080]})]),
    "power_bulwark": ("Bulwark", "Braces, lowers its shell like a shield, and shoves forward a whole body length.", 1.6, [
        (0.0, {}),
        (0.28, {"body": [-0.03, -0.01, 4], "pull": [0.04], "hl": [0, -0.015, 0], "hr": [0, -0.015, 0], "tail": [-8]}, "out"),
        (0.70, {"body": [-0.05, -0.016, 6], "pull": [IN], "hl": [0, -0.02, 0], "hr": [0, -0.02, 0], "tail": [-10]}, "out"),
        (0.92, {"body": [0.13, -0.008, -7], "pull": [IN], "fl": [0, 0.12, 0], "fr": [0, 0.11, 0], "hl": [0, 0.08, 0], "hr": [0, 0.09, 0], "tail": [20]}, "in"),
        (1.02, {"body": [0.124, -0.002, -3], "pull": [IN], "fl": [0, 0.12, 0], "fr": [0, 0.11, 0], "hl": [0, 0.08, 0], "hr": [0, 0.09, 0], "tail": [12]}, "out"),
        (1.34, {"body": [0.06, 0, 0], "pull": [0.02], "fl": [0, 0.06, 0], "fr": [0, 0.055, 0], "hl": [0, 0.04, 0], "hr": [0, 0.045, 0]}),
        (1.6, {})]),
}

HITS = {
    "hit_tuck": ("Tuck", "Its head snaps into the shell and it sits down on its plate until the blow has passed.", 0.4, [
        (0.0, {}),
        (0.07, {"drop": [0.55], "body": [-0.01, 0, 2], "pull": [IN], "tail": [14]}, "out"),
        (0.24, {"drop": [0.4], "pull": [0.07]}),
        (0.4, {})]),
    "hit_rock": ("Rock", "The blow rocks its shell up on two legs; it thumps back down.", 0.4, [
        (0.0, {}),
        (0.09, {"body": [-0.008, 0.008, 0, 0, 10, 0.01], "head": [0, 0, -8], "pull": [0.04], "tail": [0, 16]}, "out"),
        (0.22, {"body": [-0.004, -0.004, 0, 0, -3], "pull": [0.02], "tail": [0, -8]}, "in"),
        (0.4, {})]),
}

FALLS = {
    "fall_flip": ("On its back", "Tips up and over onto its back, rocks on the dome of its shell, and lies there with its legs in the air.", 1.2, [
        (0.0, {}),
        (0.26, {"body": [0, 0.004, 0, 0, -8], "head": [4, 0, -8], "pull": [0.02]}, "out"),
        (0.80, {"root": [172, 0.15, 0.23, 0], "carry": JUMP, "fl": [0, 0.01, 0.01], "fr": [0, 0.01, 0.02], "hl": [0, -0.01, 0.01], "hr": [0, -0.01, 0.02], "pull": [0.03], "tail": [0, 14]}, "in"),
        (0.92, {"root": [188, 0.15, 0.23, 0], "carry": JUMP, "fl": [0, 0.02, 0.02], "fr": [0, 0, 0.01], "hl": [0, 0, 0.02], "hr": [0, -0.02, 0.01], "pull": [0.02], "tail": [0, -10]}, "out"),
        (1.06, {"root": [176, 0.15, 0.23, 0], "carry": JUMP, "fl": [0, 0, 0.01], "fr": [0, 0.02, 0.02], "hl": [0, -0.02, 0.01], "hr": [0, 0, 0.02], "pull": [0.03], "tail": [0, 8]}),
        (1.2, {"root": [180, 0.15, 0.23, 0], "carry": JUMP, "fl": [0, 0.01, 0.01], "fr": [0, 0.01, 0.01], "hl": [0, -0.01, 0.01], "hr": [0, -0.01, 0.01], "pull": [0.04]}, "out")]),
    "fall_shut": ("Shut up shop", "Legs, tail and head go in one after another and the shell drops to the ground: nobody home.", 1.2, [
        (0.0, {}),
        (0.22, {"body": [0, 0.004, 2], "head": [8], "pull": [-0.01]}, "out"),
        (0.50, {"drop": [0.5], "carry": [0, 0, 1, 1], "hl": [0, -0.02, 0.04], "hr": [0, -0.02, 0.04], "body": [0, 0, 5], "pull": [0.02], "tail": [-20]}, "in"),
        (0.78, {"drop": [1.0], **TUCK, "body": [0, 0, 0], "pull": [0.04], "tail": [-30]}, "in"),
        (0.86, {"drop": [0.9], **TUCK, "pull": [0.05], "tail": [-30]}, "out"),
        (1.2, {"drop": [1.0], **TUCK, "pull": [IN], "tail": [-30]}, "in")]),
}

WINS = {
    "win_proud": ("Head high", "Stretches its neck up as far as it will go and looks down its nose at the field.", 1.6, [
        (0.0, {}),
        (0.5, {"body": [0, 0.012, 6], "neck": [14, -8], "head": [12, -12], "pull": [-0.04], "tail": [10]}, "out"),
        (1.1, {"body": [0, 0.014, 7], "neck": [15, 8], "head": [13, 14], "pull": [-0.04], "tail": [10, 8]}),
        (1.6, {"body": [0, 0.01, 5], "neck": [12], "head": [10], "pull": [-0.03], "tail": [8]}, "out")]),
    "win_stomp": ("Stomp", "Stamps its forefeet one after the other, the shell rocking, then nods.", 1.6, [
        (0.0, {}),
        (0.20, {"body": [0, 0.006, 3, 0, 6, -0.008], "fl": [0, 0.005, 0.04], "head": [4, -8]}, "out"),
        (0.32, {"body": [0, -0.006, -2, 0, -2, 0.004], "fl": [0, 0.01, 0], "head": [-4, -4]}, "in"),
        (0.54, {"body": [0, 0.006, 3, 0, -6, 0.008], "fl": [0, 0.01, 0], "fr": [0, 0.005, 0.04], "head": [4, 8]}, "out"),
        (0.66, {"body": [0, -0.006, -2, 0, 2, -0.004], "fl": [0, 0.01, 0], "fr": [0, 0.01, 0], "head": [-4, 4]}, "in"),
        (1.10, {"body": [0, 0.008, 4], "fl": [0, 0.01, 0], "fr": [0, 0.01, 0], "neck": [10], "head": [10], "pull": [-0.03]}, "out"),
        (1.34, {"body": [0, 0.004, 1], "fl": [0, 0.01, 0], "fr": [0, 0.01, 0], "neck": [-4], "head": [-8], "pull": [-0.02]}, "in"),
        (1.6, {"body": [0, 0.008, 4], "fl": [0, 0.01, 0], "fr": [0, 0.01, 0], "neck": [8], "head": [8], "pull": [-0.03]}, "out")]),
    "win_twirl": ("Victory twirl", "Tucks in and spins once on its shell, then pops its head out with a look of great satisfaction.", 1.6, [
        (0.0, {}),
        (0.24, {"drop": [0.9], "pull": [IN], **TUCK}, "out"),
        (0.36, {"drop": [0.92], "pull": [IN], **TUCK, "root": [0, 0, 0, 0, 20]}, "in"),
        (0.96, {"drop": [0.92], "pull": [IN], **TUCK, "root": [0, 0, 0, 0, 345]}, "out"),
        (1.20, {"drop": [0.3], "pull": [0.03], "root": [0, 0, 0, 0, 360]}),
        (1.6, {"root": [0, 0, 0, 0, 360], "body": [0, 0.01, 5], "neck": [10], "head": [10], "pull": [-0.03]}, "over")]),
}

CLIPS = {
    "idle_plod": ("Standing", "idle", "The shell rises and sinks with each slow breath; the head sways.", LOOP, idle_plod, True),
    "idle_peer": ("Peer", "idle", "Stretches its neck right out and peers one way, then the other.", LOOP, idle_peer, True),
    "idle_hide": ("Startle", "idle", "Its head shoots in and the shell settles; after a while it comes back out.", LOOP, idle_hide, True),
    "walk_plod": ("Plod", "run", "The game's pace: one leg at a time, the shell rocking from side to side.", 1.0, walk_plod, True),
    "run_trundle": ("Trundle", "run", "In a hurry: diagonal pairs, the shell bouncing, neck stretched out ahead.", 0.56, run_trundle, True),
    "run_slide": ("Shell slide", "run", "Tucks everything in and skates along on its belly plate, spinning slowly.", 0.8, run_slide, True),
}
for kind, table in (("attack", ATTACKS), ("power", POWERS), ("hit", HITS), ("fall", FALLS), ("win", WINS)):
    for k, (name, desc, secs, keys) in table.items():
        CLIPS[k] = (name, kind, desc, secs, rp.keyed(keys), False)
