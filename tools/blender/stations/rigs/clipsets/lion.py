"""The lions' own clips: weight, pride and a cat's spine. Lengths and blow times are the game's (idle loop 4.8 s,
attack 0.95 s with the blow at 0.44, power 1.6 s with the blow at 0.92, hit 0.4 s, fall 1.2 s, win 1.6 s).
Each one-shot is keyed in four beats: anticipation (eases out into a held wind-up), commit (eases in, so the blow
lands at full speed), impact (a short overshoot past the pose), follow-through (settles; the tail is on a spring)."""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import rigpose as rp
from clipsets.quad import cyc, gait, span, TAU

SPRING = (2.2, 0.26)  # a long tail with a tuft: slow to follow, swings well past
LOOP = 4.8
JUMP = [1, 1, 1, 1]


# --- idles ----------------------------------------------------------------------------------------------------------
def idle_survey(t):  # the king's watch: head high, a slow look from side to side, the tail's tuft flicking
    look = cyc(t, 4.8)
    flick = max(0.0, cyc(t, 1.6)) ** 6
    return {"body": [0, 0.004 * cyc(t, 2.4), 3], "spine": [2 + 1.5 * cyc(t, 2.4)], "neck": [8, 16 * look],
            "head": [4 + 2 * cyc(t, 2.4, 0.2), 12 * cyc(t, 4.8, -0.08)], "tail": [4, 12 * cyc(t, 2.4), 6 + 30 * flick]}


def idle_prowl(t):  # low and coiled, its weight rolling from one shoulder to the other
    sh = cyc(t, 2.4)
    return {"body": [0.008, -0.035 + 0.004 * cyc(t, 1.2), -4, 2 * sh, 3 * sh, 0.012 * sh], "spine": [-3, 4 * cyc(t, 2.4, 0.15)],
            "neck": [-10, 8 * cyc(t, 4.8)], "head": [8, 6 * cyc(t, 4.8, 0.1)], "tail": [-8, 16 * cyc(t, 2.4, 0.3), 10]}


def idle_roar(t):  # stands easy; once a loop it throws its head back and roars, then shakes out its mane
    r = span(t, 1.5, 3.1)
    shake = span(t, 3.2, 4.0) * math.sin(TAU * t / 0.24)
    return {"body": [-0.012 * r, 0.004 * cyc(t, 2.4) + 0.008 * r, 8 * r], "spine": [1.5 * cyc(t, 2.4) + 6 * r],
            "neck": [3 + 17 * r, 4 * cyc(t, 4.8) + 6 * shake], "head": [2 + 30 * r, 6 * cyc(t, 4.8, 0.1) + 14 * shake, 12 * shake],
            "tail": [6 + 20 * r, 12 * cyc(t, 2.4), 8 + 10 * r]}


# --- walks and runs -------------------------------------------------------------------------------------------------
def walk_prowl(t):  # the game's pace: a cat's four-beat walk, low, the spine snaking and the head held level
    return gait(t, 0.85, {"hl": 0.0, "fl": 0.25, "hr": 0.5, "fr": 0.75}, 0.6, 0.095, 0.04,
                lambda c: {"body": [0, -0.012 + 0.004 * math.cos(2 * TAU * c + 0.5), -1, 2 * math.sin(TAU * c + 0.4),
                                    1.5 * math.sin(TAU * c + 0.4), 0.006 * math.sin(TAU * c + 0.4)],
                           "spine": [0, 5 * math.sin(TAU * c + 1.2)], "neck": [-5, -3 * math.sin(TAU * c + 0.4)],
                           "head": [3 + 1.5 * math.cos(2 * TAU * c + 1.5), -2 * math.sin(TAU * c + 0.4)],
                           "tail": [-4, 14 * math.sin(TAU * c - 0.6), 8]})


def run_gallop(t):  # a heavy rotary gallop: the spine folds and opens
    return gait(t, 0.62, {"hl": 0.0, "hr": 0.1, "fl": 0.45, "fr": 0.55}, 0.38, 0.12, 0.08,
                lambda c: {"body": [0, 0.026 + 0.018 * math.cos(TAU * c), 5 * math.sin(TAU * c)],
                           "spine": [9 * math.sin(TAU * c + 0.6)], "neck": [-5 * math.sin(TAU * c)],
                           "head": [4 * math.sin(TAU * c + 0.3)], "tail": [4, 8 * math.sin(TAU * c), 10 * math.sin(TAU * c + 1)]})


def run_lope(t):  # an easy three-beat lope, shoulders rolling
    return gait(t, 0.7, {"hl": 0.0, "hr": 0.28, "fl": 0.32, "fr": 0.6}, 0.45, 0.1, 0.06,
                lambda c: {"body": [0, 0.016 + 0.012 * math.cos(TAU * c + 0.4), 4 * math.sin(TAU * c)],
                           "spine": [5 * math.sin(TAU * c + 0.5), 2 * math.sin(TAU * c)], "neck": [-3 - 3 * math.sin(TAU * c)],
                           "head": [2 + 3 * math.sin(TAU * c + 0.3)], "tail": [2, 10 * math.sin(TAU * c), 8]})


# --- one-shots -----------------------------------------------------------------------------------------------------
FWD = {"fl": [0, 0.15, 0], "fr": [0, 0.15, 0], "hl": [0, 0.06, 0], "hr": [0, 0.06, 0]}  # all four after a leap forward
ATTACKS = {
    "attack_pounce": ("Pounce", "Sinks low and back, springs with all four paws off the ground, and slams both forepaws down.", 0.95, [
        (0.0, {}),
        (0.22, {"body": [-0.035, -0.055, -6], "spine": [-8], "neck": [-8], "head": [8], "tail": [-10, 0, 10]}, "out"),
        (0.36, {"body": [0.07, 0.07, 10], "spine": [8], "carry": JUMP, "fl": [0, 0.07, 0.04], "fr": [0, 0.07, 0.04],
                "hl": [0, -0.05, 0.03], "hr": [0, -0.05, 0.03], "head": [-4], "tail": [22, 0, -10]}, "out"),
        (0.44, {"body": [0.12, -0.035, -11], "spine": [-6], **FWD, "neck": [-10], "head": [-8], "tail": [32, 0, 10]}, "in"),
        (0.52, {"body": [0.115, -0.02, -7], **FWD, "neck": [-6], "head": [-2], "tail": [20, 10, 6]}, "out"),
        (0.72, {"body": [0.06, -0.008, -2], "fl": [0, 0.08, 0], "fr": [0, 0.08, 0], "hl": [0, 0.03, 0], "hr": [0, 0.03, 0], "tail": [10, 8, 4]}),
        (0.95, {})]),
    "attack_swipe": ("Claw swipe", "Rears a little and rakes its right forepaw across, its head and tail whipping after it.", 0.95, [
        (0.0, {}),
        (0.22, {"body": [-0.025, 0.02, 14, 8], "carry": [1, 0, 0, 0], "fl": [0, 0.02, 0.02], "fr": [-0.07, 0.08, 0.14],
                "neck": [4, 10], "head": [-4, 14], "tail": [10, -18]}, "out"),
        (0.44, {"body": [0.03, 0.005, 8, -12], "carry": [1, 0, 0, 0], "fl": [0, 0.03, 0.01], "fr": [0.11, 0.13, 0.04],
                "neck": [-4, -12], "head": [-8, -20], "tail": [10, 28]}, "in"),
        (0.52, {"body": [0.03, 0, 5, -15], "fl": [0, 0.03, 0], "fr": [0.12, 0.09, 0], "head": [-6, -24], "tail": [8, 34]}, "out"),
        (0.72, {"body": [0.012, 0, 2, -5], "fl": [0, 0.015, 0], "fr": [0.05, 0.04, 0], "head": [-3, -8], "tail": [6, 10]}),
        (0.95, {})]),
    "attack_bite": ("Lunge and shake", "Drops its head and lunges low, snaps its jaws up, and shakes what it caught.", 0.95, [
        (0.0, {}),
        (0.20, {"body": [-0.025, -0.02, -3], "neck": [-4], "head": [10], "tail": [-6]}, "out"),
        (0.42, {"body": [0.085, -0.03, -7], "spine": [-4], "neck": [-14], "head": [-6], "fl": [0, 0.06, 0], "tail": [36, 0, 10]}, "in"),
        (0.50, {"body": [0.08, -0.018, -3], "neck": [6], "head": [20], "fl": [0, 0.06, 0], "tail": [30, 10, 10]}, "out"),
        (0.60, {"body": [0.07, -0.016, -3], "neck": [2, 8], "head": [12, 12, 8], "fl": [0, 0.06, 0]}),
        (0.69, {"body": [0.06, -0.014, -2], "neck": [2, -8], "head": [12, -12, -8], "fl": [0, 0.05, 0]}),
        (0.95, {})]),
}

PAWS = {"fl": [0, 0.1, 0], "fr": [0, 0.1, 0]}
POWERS = {
    "power_roar": ("King's roar", "Draws a great breath with its chest up, then throws the roar forward with its whole body and holds it.", 1.6, [
        (0.0, {}),
        (0.25, {"body": [-0.02, -0.03, -4], "neck": [-8], "head": [6], "tail": [-8]}, "out"),
        (0.70, {"body": [-0.05, 0.012, 9], "spine": [6], "neck": [12], "head": [16], "tail": [24, 0, 10]}, "out"),
        (0.84, {"body": [-0.055, 0.014, 10], "spine": [7], "neck": [14], "head": [20], "tail": [26, 0, 10]}),
        (0.92, {"body": [0.05, -0.028, -6], "spine": [-4], "neck": [-4], "head": [10], "fl": [0, 0.04, 0], "fr": [0, 0.03, 0], "tail": [40, 0, -8]}, "in"),
        (1.00, {"body": [0.045, -0.02, -4], "neck": [-2], "head": [14], "fl": [0, 0.04, 0], "fr": [0, 0.03, 0], "tail": [30, 8]}, "out"),
        (1.25, {"body": [0.04, -0.018, -4], "neck": [-2, 5], "head": [13, 6, 4], "fl": [0, 0.04, 0], "fr": [0, 0.03, 0], "tail": [26, -8]}),
        (1.6, {})]),
    "power_leap": ("Pride's fall", "Coils, wriggling its haunches, leaps high with its forelegs raised and crashes both forepaws into the ground.", 1.6, [
        (0.0, {}),
        (0.30, {"body": [-0.03, -0.06, -6], "spine": [-10], "neck": [-10], "head": [8], "tail": [-12]}, "out"),
        (0.52, {"body": [-0.035, -0.065, -7, 0, 0, 0.008], "spine": [-10, 3], "neck": [-10], "head": [9], "tail": [-12, 16]}),
        (0.76, {"body": [0.04, 0.16, 22], "spine": [12], "carry": JUMP, "fl": [0, -0.02, 0.08], "fr": [0, -0.02, 0.08],
                "hl": [0, -0.04, 0.02], "hr": [0, -0.04, 0.02], "neck": [10], "head": [8], "tail": [25, 0, -10]}, "out"),
        (0.92, {"body": [0.09, -0.04, -14], "spine": [-10], "fl": [0, 0.11, 0], "fr": [0, 0.11, 0], "hl": [0, 0.05, 0], "hr": [0, 0.05, 0],
                "neck": [-14], "head": [-6], "tail": [36, 0, 12]}, "in"),
        (1.02, {"body": [0.085, -0.025, -9], "fl": [0, 0.11, 0], "fr": [0, 0.11, 0], "hl": [0, 0.05, 0], "hr": [0, 0.05, 0], "neck": [-8], "tail": [22]}, "out"),
        (1.30, {"body": [0.04, -0.01, -3], "fl": [0, 0.05, 0], "fr": [0, 0.05, 0], "hl": [0, 0.02, 0], "hr": [0, 0.02, 0]}),
        (1.6, {})]),
    "power_maul": ("Royal maul", "A left swipe, a right swipe, then it rears and brings both forepaws down together.", 1.6, [
        (0.0, {}),
        (0.18, {"body": [-0.02, 0.02, 12, -6], "carry": [0, 1, 0, 0], "fr": [0, 0.02, 0.02], "fl": [0.07, 0.08, 0.13], "head": [-4, -12]}, "out"),
        (0.34, {"body": [0.02, 0.008, 8, 10], "carry": [0, 1, 0, 0], "fl": [-0.1, 0.12, 0.04], "fr": [0, 0.03, 0.01], "head": [-8, 18], "tail": [10, -24]}, "in"),
        (0.46, {"body": [0, 0.02, 13, 8], "carry": [1, 0, 0, 0], "fl": [0, 0.03, 0.02], "fr": [-0.07, 0.08, 0.14], "head": [-4, 14]}, "out"),
        (0.62, {"body": [0.03, 0.008, 8, -11], "carry": [1, 0, 0, 0], "fl": [0, 0.03, 0.01], "fr": [0.11, 0.13, 0.04], "head": [-8, -20], "tail": [10, 26]}, "in"),
        (0.80, {"body": [0, 0.04, 22], "spine": [8], "carry": [1, 1, 0, 0], "fl": [0, 0, 0.07], "fr": [0, 0, 0.07], "neck": [10], "head": [12], "tail": [30]}, "out"),
        (0.92, {"body": [0.07, -0.035, -10], "spine": [-6], **PAWS, "neck": [-12], "head": [-6], "tail": [38, 0, 10]}, "in"),
        (1.02, {"body": [0.065, -0.02, -6], **PAWS, "neck": [-6], "tail": [22]}, "out"),
        (1.30, {"body": [0.03, -0.006, -2], "fl": [0, 0.05, 0], "fr": [0, 0.05, 0]}),
        (1.6, {})]),
}

HITS = {
    "hit_flinch": ("Flinch", "Jolts back from the blow, head snapping up and away, then braces.", 0.4, [
        (0.0, {}),
        (0.08, {"body": [-0.035, 0.008, 5, 7, -5], "neck": [7, 9], "head": [9, 11], "tail": [10, -20]}, "out"),
        (0.22, {"body": [-0.018, -0.008, -2, 3], "head": [-4, 4], "tail": [4, -8]}),
        (0.4, {})]),
    "hit_snarl": ("Snarl", "Rocked back onto its haunches, it snaps its head round at whatever struck it.", 0.4, [
        (0.0, {}),
        (0.08, {"body": [-0.04, -0.012, 4], "spine": [3], "neck": [6], "head": [10], "tail": [14]}, "out"),
        (0.20, {"body": [-0.012, -0.014, -4], "neck": [-8, -8], "head": [4, -12, -6], "tail": [6, 16]}, "in"),
        (0.4, {})]),
}

FALLS = {
    "fall_slump": ("Slump", "Its legs fold under it and it sinks onto its belly, its chin coming to rest on the ground.", 1.2, [
        (0.0, {}),
        (0.22, {"body": [0, -0.015, 4], "head": [8]}, "out"),
        (0.80, {"drop": [0.86], "body": [0, 0, -3], "spine": [-3], "neck": [-8], "head": [2], "tail": [-10, 10]}, "in"),
        (0.90, {"drop": [0.8], "body": [0, 0, -2], "neck": [-5], "head": [6]}, "out"),
        (1.2, {"drop": [0.88], "body": [0, 0, -3], "spine": [-3], "neck": [-9], "head": [4, 10, 10], "tail": [-12, 20]}, "in")]),
    "fall_roll": ("Topple", "Sways, then goes over onto its side, legs folding as it lands.", 1.2, [
        (0.0, {}),
        (0.28, {"body": [0, 0, 0, 0, -6], "head": [6, 0, -6]}, "out"),
        (0.85, {"root": [84, 0.1, 0, 0], "fl": [0, -0.02, 0.05], "fr": [0, -0.02, 0.06], "hl": [0, 0.02, 0.05], "hr": [0, 0.02, 0.06],
                "neck": [-6], "head": [-10], "tail": [-10, 20]}, "in"),
        (0.95, {"root": [80, 0.1, 0, 0], "fl": [0, -0.02, 0.06], "fr": [0, -0.02, 0.07], "hl": [0, 0.02, 0.06], "hr": [0, 0.02, 0.07],
                "neck": [-4], "head": [-6], "tail": [-6, 24]}, "out"),
        (1.2, {"root": [88, 0.1, 0, 0], "fl": [0, -0.03, 0.07], "fr": [0, -0.03, 0.08], "hl": [0, 0.03, 0.07], "hr": [0, 0.03, 0.08],
               "neck": [-8], "head": [-14], "tail": [-10, 25]}, "in")]),
}

REAR = {"carry": [1, 1, 0, 0], "spine": [8]}
WINS = {
    "win_roar": ("Victory roar", "Rears onto its hind legs with a forepaw raised and roars at the sky, then drops and stands proud.", 1.6, [
        (0.0, {}),
        (0.25, {"body": [-0.01, -0.03, -4], "neck": [-6], "head": [4], "tail": [-8]}, "out"),
        (0.55, {"body": [-0.03, 0.03, 24], **REAR, "fl": [0, 0.02, 0.07], "fr": [0, -0.02, 0.03], "neck": [12], "head": [20], "tail": [34, 0, 16]}, "out"),
        (0.95, {"body": [-0.03, 0.032, 26], **REAR, "fl": [0, 0.03, 0.08], "fr": [0, -0.02, 0.03], "neck": [16, 6], "head": [28, 6, 4], "tail": [36, 12, 16]}),
        (1.15, {"body": [0.02, -0.02, -5], "fl": [0, 0.04, 0], "fr": [0, 0.04, 0], "neck": [-6], "head": [-2], "tail": [18]}, "in"),
        (1.6, {"body": [0.01, 0.006, 5], "spine": [4], "fl": [0, 0.04, 0], "fr": [0, 0.04, 0], "neck": [10], "head": [8], "tail": [26, 0, 18]}, "over")]),
    "win_proud": ("Proud stance", "Draws itself up, chest out, and looks slowly across the field, tail curled high.", 1.6, [
        (0.0, {}),
        (0.35, {"body": [0, 0.008, 5], "spine": [4], "neck": [10, -10], "head": [8, -14], "tail": [24, -10, 16]}, "out"),
        (0.95, {"body": [0, 0.009, 6], "spine": [4], "neck": [11, 10], "head": [9, 16], "tail": [26, 12, 18]}),
        (1.25, {"body": [0, 0.004, 3], "spine": [2], "neck": [5], "head": [-2], "tail": [18, 0, 12]}, "in"),
        (1.6, {"body": [0, 0.008, 5], "spine": [4], "neck": [10], "head": [8], "tail": [26, 0, 18]}, "over")]),
    "win_stretch": ("Lazy stretch", "A long cat stretch, forepaws far forward and chest to the ground, then it stands as if nothing happened.", 1.6, [
        (0.0, {}),
        (0.50, {"body": [0.02, -0.02, -11], "spine": [-10], "fl": [0, 0.12, 0], "fr": [0, 0.12, 0], "neck": [8], "head": [12], "tail": [40, 0, 20]}, "out"),
        (0.95, {"body": [0.024, -0.024, -12], "spine": [-11], "fl": [0, 0.12, 0], "fr": [0, 0.12, 0], "neck": [10], "head": [14], "tail": [40, 15, 20]}),
        (1.6, {"body": [0.01, 0.008, 5], "spine": [4], "fl": [0, 0.05, 0], "fr": [0, 0.05, 0], "neck": [10], "head": [8], "tail": [25, 0, 20]}, "out")]),
}

CLIPS = {
    "idle_survey": ("King's watch", "idle", "Head high, a slow look from side to side, the tuft of its tail flicking.", LOOP, idle_survey, True),
    "idle_prowl": ("Coiled", "idle", "Low and ready, its weight rolling from one shoulder to the other.", LOOP, idle_prowl, True),
    "idle_roar": ("Roar and shake", "idle", "Stands easy; once a loop it throws its head back and roars, then shakes out its mane.", LOOP, idle_roar, True),
    "walk_prowl": ("Prowl", "run", "The game's pace: a cat's four-beat walk, low, the spine snaking and the head held level.", 0.85, walk_prowl, True),
    "run_gallop": ("Gallop", "run", "A heavy gallop: hind legs together, then the forelegs, the spine folding and opening.", 0.62, run_gallop, True),
    "run_lope": ("Lope", "run", "An easy three-beat lope with the shoulders rolling.", 0.7, run_lope, True),
}
for kind, table in (("attack", ATTACKS), ("power", POWERS), ("hit", HITS), ("fall", FALLS), ("win", WINS)):
    for k, (name, desc, secs, keys) in table.items():
        CLIPS[k] = (name, kind, desc, secs, rp.keyed(keys), False)
