"""The cheetahs' own clips: light, quick, all spine and tail. Lengths and blow times are the game's (idle loop 4.8 s,
attack 0.95 s with the blow at 0.44, power 1.6 s with the blow at 0.92, hit 0.4 s, fall 1.2 s, win 1.6 s).
Its wind-ups are short and its recoveries long: it is already moving when a heavier animal would still be coiling."""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import rigpose as rp
from clipsets.quad import cyc, gait, span, TAU

SPRING = (2.4, 0.22)  # a long rudder of a tail: it lashes and takes a while to settle
LOOP = 4.8
JUMP = [1, 1, 1, 1]


# --- idles ----------------------------------------------------------------------------------------------------------
def idle_scan(t):  # the lookout: upright and alert, the head snapping from one point to the next, the tail swishing
    look = math.copysign(abs(cyc(t, 4.8)) ** 0.35, cyc(t, 4.8))  # (it holds a look, then snaps to the next)
    return {"body": [0, 0.004 * cyc(t, 1.6), 2], "spine": [2 + 1.5 * cyc(t, 1.6)], "neck": [6, 20 * look],
            "head": [3, 14 * look], "tail": [2, 20 * cyc(t, 1.6), 6 + 8 * cyc(t, 0.8)]}


def idle_blocks(t):  # a sprinter in the blocks: low over its forepaws, haunches twitching, ready to go
    tw = span(t, 2.0, 2.6) + span(t, 3.4, 3.9)
    return {"body": [0.012, -0.045 + 0.003 * cyc(t, 1.2) - 0.006 * tw, -7 - 2 * tw, 0, 0, 0.006 * cyc(t, 2.4)],
            "spine": [-6 - 2 * tw, 3 * cyc(t, 2.4)], "neck": [-8, 5 * cyc(t, 4.8)], "head": [12, 4 * cyc(t, 4.8, 0.1)],
            "tail": [-6, 12 * cyc(t, 1.2) + 20 * tw * cyc(t, 0.3), 14]}


def idle_restless(t):  # cannot stand still: shifts its weight, paws once at the ground, lashes its tail
    paw = span(t, 2.6, 3.6)
    ph = TAU * (t % LOOP - 2.6) / 0.5
    sh = cyc(t, 2.4)
    return {"body": [0, 0.003 * cyc(t, 1.2), 1, 3 * sh, 2 * sh, 0.01 * sh], "spine": [1, 4 * cyc(t, 2.4, 0.2)],
            "neck": [2, -8 * sh], "head": [2 - 6 * paw, -6 * cyc(t, 2.4, 0.1)],
            "fl": [0, 0.035 * math.sin(ph) * paw, 0.03 * max(0.0, math.cos(ph)) * paw],
            "tail": [8, 26 * cyc(t, 1.2), 10 * cyc(t, 0.6)]}


# --- walks and runs -------------------------------------------------------------------------------------------------
def walk_stalk(t):  # the game's pace: a slinking four-beat walk, shoulder blades rolling, the head dead level
    return gait(t, 0.78, {"hl": 0.0, "fl": 0.25, "hr": 0.5, "fr": 0.75}, 0.58, 0.1, 0.04,
                lambda c: {"body": [0, -0.016 + 0.004 * math.cos(2 * TAU * c + 0.5), -2, 2.5 * math.sin(TAU * c + 0.4),
                                    1.2 * math.sin(TAU * c + 0.4), 0.005 * math.sin(TAU * c + 0.4)],
                           "spine": [-1, 7 * math.sin(TAU * c + 1.2)], "neck": [-7, -4 * math.sin(TAU * c + 0.4)],
                           "head": [6 + math.cos(2 * TAU * c + 1.5), -3 * math.sin(TAU * c + 0.4)],
                           "tail": [-6, 16 * math.sin(TAU * c - 0.7), 10]})


def run_sprint(t):  # the sprint: hind legs together, forelegs together, the spine folding like a spring
    return gait(t, 0.5, {"hl": 0.0, "hr": 0.03, "fl": 0.5, "fr": 0.53}, 0.3, 0.14, 0.1,
                lambda c: {"body": [0, 0.04 + 0.03 * math.cos(TAU * c), 9 * math.sin(TAU * c)],
                           "spine": [14 * math.sin(TAU * c + 0.4)], "neck": [-9 * math.sin(TAU * c)],
                           "head": [8 * math.sin(TAU * c + 0.2)], "tail": [-4, 6 * math.sin(TAU * c), 16 * math.sin(TAU * c + 1.2)]})


def run_gallop(t):  # a loose rotary gallop
    return gait(t, 0.56, {"hl": 0.0, "hr": 0.1, "fl": 0.45, "fr": 0.55}, 0.36, 0.13, 0.09,
                lambda c: {"body": [0, 0.03 + 0.02 * math.cos(TAU * c), 6 * math.sin(TAU * c)],
                           "spine": [10 * math.sin(TAU * c + 0.6)], "neck": [-6 * math.sin(TAU * c)],
                           "head": [5 * math.sin(TAU * c + 0.3)], "tail": [4, 8 * math.sin(TAU * c), 10 * math.sin(TAU * c + 1)]})


# --- one-shots -----------------------------------------------------------------------------------------------------
ATTACKS = {
    "attack_dash": ("Dash strike", "A blink of a crouch, then it is already there: a flat dash, both forepaws raking down.", 0.95, [
        (0.0, {}),
        (0.16, {"body": [-0.03, -0.045, -5], "spine": [-9], "neck": [-6], "head": [10], "tail": [-8, 0, 12]}, "out"),
        (0.36, {"body": [0.12, 0.02, 4], "spine": [9], "carry": JUMP, "fl": [0, 0.09, 0.05], "fr": [0, 0.1, 0.06],
                "hl": [0, -0.06, 0.02], "hr": [0, -0.06, 0.02], "head": [-4], "tail": [10, 0, -14]}, "out"),
        (0.44, {"body": [0.17, -0.03, -9], "spine": [-7], "fl": [0, 0.2, 0], "fr": [0, 0.2, 0], "hl": [0, 0.1, 0], "hr": [0, 0.1, 0],
                "neck": [-10], "head": [-6], "tail": [34, 0, 12]}, "in"),
        (0.52, {"body": [0.165, -0.016, -5], "fl": [0, 0.2, 0], "fr": [0, 0.2, 0], "hl": [0, 0.1, 0], "hr": [0, 0.1, 0], "head": [0], "tail": [18, 14, 6]}, "out"),
        (0.78, {"body": [0.07, -0.006, -1], "fl": [0, 0.09, 0], "fr": [0, 0.09, 0], "hl": [0, 0.04, 0], "hr": [0, 0.04, 0], "tail": [8, -10, 4]}),
        (0.95, {})]),
    "attack_sweep": ("Leg sweep", "Drops flat and whips a forepaw across at ankle height, its tail lashing the other way.", 0.95, [
        (0.0, {}),
        (0.18, {"body": [-0.01, -0.05, -6, 10], "spine": [-6, 6], "fr": [-0.08, 0.06, 0.05], "neck": [-6, 10], "head": [8, 12], "tail": [-4, -24]}, "out"),
        (0.44, {"body": [0.04, -0.055, -8, -14], "spine": [-6, -8], "fr": [0.13, 0.12, 0.012], "neck": [-8, -12], "head": [6, -22], "tail": [-4, 34]}, "in"),
        (0.52, {"body": [0.04, -0.05, -7, -17], "spine": [-5, -9], "fr": [0.14, 0.09, 0], "neck": [-8, -14], "head": [6, -26], "tail": [-2, 40]}, "out"),
        (0.76, {"body": [0.015, -0.02, -3, -6], "fr": [0.05, 0.04, 0], "head": [4, -8], "tail": [2, 12]}),
        (0.95, {})]),
    "attack_bite": ("Throat lunge", "Low, then up and in from underneath, jaws snapping shut at the top.", 0.95, [
        (0.0, {}),
        (0.18, {"body": [-0.02, -0.04, -5], "spine": [-5], "neck": [-10], "head": [6], "tail": [-6]}, "out"),
        (0.42, {"body": [0.1, -0.012, 6], "spine": [5], "neck": [8], "head": [18], "fl": [0, 0.08, 0], "fr": [0, 0.07, 0], "tail": [30, 0, 12]}, "in"),
        (0.50, {"body": [0.095, -0.004, 4], "neck": [2], "head": [4], "fl": [0, 0.08, 0], "fr": [0, 0.07, 0], "tail": [20, 12, 8]}, "out"),
        (0.76, {"body": [0.04, -0.004, 0], "fl": [0, 0.04, 0], "fr": [0, 0.035, 0], "head": [4]}),
        (0.95, {})]),
}

LAND = {"fl": [0, 0.12, 0], "fr": [0, 0.12, 0], "hl": [0, 0.06, 0], "hr": [0, 0.06, 0]}
TUCK = {"carry": JUMP, "fl": [0, 0, 0.07], "fr": [0, 0, 0.07], "hl": [0, 0, 0.06], "hr": [0, 0, 0.06]}
POWERS = {
    "power_blitz": ("Blitz", "Feints left, feints right, then goes through the middle faster than either.", 1.6, [
        (0.0, {}),
        (0.16, {"body": [-0.02, -0.04, -4], "spine": [-7], "head": [8], "tail": [-8]}, "out"),
        (0.36, {"body": [0.03, -0.03, -3, -12, -8, 0.07], "spine": [-4, -8], "fl": [0.07, 0.04, 0], "fr": [0.06, 0.03, 0], "head": [6, 14], "tail": [6, 30]}, "in"),
        (0.58, {"body": [0.04, -0.03, -3, 12, 8, -0.07], "spine": [-4, 8], "fl": [-0.06, 0.05, 0], "fr": [-0.07, 0.04, 0], "hl": [-0.03, 0.02, 0], "head": [6, -14], "tail": [6, -30]}, "in"),
        (0.74, {"body": [-0.02, -0.05, -6], "spine": [-10], "fl": [0, 0.03, 0], "fr": [0, 0.03, 0], "head": [10], "tail": [-10, 0, 14]}, "out"),
        (0.92, {"body": [0.19, -0.03, -8], "spine": [-6], "fl": [0, 0.22, 0], "fr": [0, 0.22, 0], "hl": [0, 0.12, 0], "hr": [0, 0.12, 0], "neck": [-10], "head": [-4], "tail": [36, 0, 12]}, "in"),
        (1.02, {"body": [0.185, -0.016, -4], "fl": [0, 0.22, 0], "fr": [0, 0.22, 0], "hl": [0, 0.12, 0], "hr": [0, 0.12, 0], "tail": [18, 16, 6]}, "out"),
        (1.34, {"body": [0.07, -0.006, -1], "fl": [0, 0.09, 0], "fr": [0, 0.09, 0], "hl": [0, 0.05, 0], "hr": [0, 0.05, 0], "tail": [8, -10]}),
        (1.6, {})]),
    "power_whirl": ("Whirl", "Springs up and spins a full turn in the air, its tail a whip, and lands with both forepaws.", 1.6, [
        (0.0, {}),
        (0.26, {"body": [0, -0.05, -3], "spine": [-7, 6], "head": [6, 10], "tail": [-8, -24]}, "out"),
        (0.46, {"root": [0, 0, 0, 0.14, 60], **TUCK, "tail": [10, 30, 20]}, "out"),
        (0.80, {"root": [0, 0, 0, 0.16, 300], **TUCK, "tail": [10, 34, 20]}, "linear"),
        (0.92, {"root": [0, 0, 0, 0, 360], "body": [0.05, -0.04, -9], "spine": [-7], "fl": [0, 0.09, 0], "fr": [0, 0.09, 0], "neck": [-10], "head": [-4], "tail": [34, 0, 12]}, "in"),
        (1.02, {"root": [0, 0, 0, 0, 360], "body": [0.045, -0.02, -5], "fl": [0, 0.09, 0], "fr": [0, 0.09, 0], "tail": [18, 14]}, "out"),
        (1.6, {"root": [0, 0, 0, 0, 360]})]),
    "power_pounce": ("Sky pounce", "Coils, goes up twice its own height, hangs, and comes down forepaws first.", 1.6, [
        (0.0, {}),
        (0.30, {"body": [-0.03, -0.06, -6], "spine": [-11], "neck": [-10], "head": [10], "tail": [-12]}, "out"),
        (0.62, {"body": [0.03, 0.2, 24], "spine": [12], "carry": JUMP, "fl": [0, -0.02, 0.08], "fr": [0, -0.02, 0.08],
                "hl": [0, -0.04, 0.02], "hr": [0, -0.04, 0.02], "neck": [10], "head": [6], "tail": [20, 0, -12]}, "out"),
        (0.78, {"body": [0.06, 0.2, 6], "spine": [0], "carry": JUMP, "fl": [0, 0.04, 0.05], "fr": [0, 0.04, 0.05],
                "hl": [0, -0.02, 0.04], "hr": [0, -0.02, 0.04], "neck": [-4], "head": [-6], "tail": [30, 0, 4]}),
        (0.92, {"body": [0.1, -0.04, -14], "spine": [-10], **LAND, "neck": [-14], "head": [-6], "tail": [38, 0, 12]}, "in"),
        (1.02, {"body": [0.095, -0.024, -9], **LAND, "neck": [-8], "tail": [22, 10]}, "out"),
        (1.34, {"body": [0.04, -0.008, -2], "fl": [0, 0.05, 0], "fr": [0, 0.05, 0], "hl": [0, 0.02, 0], "hr": [0, 0.02, 0]}),
        (1.6, {})]),
}

HITS = {
    "hit_skid": ("Skid", "Knocked back a pace, it digs its claws in and holds its ground.", 0.4, [
        (0.0, {}),
        (0.08, {"body": [-0.05, -0.012, 5], "spine": [4], "neck": [6], "head": [8], "fl": [0, -0.02, 0], "fr": [0, -0.025, 0], "tail": [16]}, "out"),
        (0.22, {"body": [-0.03, -0.022, -4], "spine": [-4], "fl": [0, -0.02, 0], "fr": [0, -0.025, 0], "head": [-2], "tail": [4, 10]}, "in"),
        (0.4, {})]),
    "hit_twist": ("Twist away", "Whips its whole body sideways from the blow and snaps back.", 0.4, [
        (0.0, {}),
        (0.08, {"body": [-0.02, 0.006, 2, -10, 10, 0.04], "spine": [0, -10], "neck": [0, -12], "head": [4, -10, 8], "tail": [6, 30]}, "out"),
        (0.22, {"body": [-0.008, -0.008, -1, 3, -3, 0.012], "spine": [0, 4], "head": [0, 6], "tail": [4, -16]}),
        (0.4, {})]),
}

FALLS = {
    "fall_tumble": ("Tumble", "Its legs go from under it mid-stride and it tumbles onto its side.", 1.2, [
        (0.0, {}),
        (0.20, {"body": [0.02, -0.02, -6, 0, -8], "spine": [-4], "head": [6, 0, -8]}, "out"),
        (0.75, {"root": [86, 0.08, 0, 0], "body": [0.03, 0, 0], "fl": [0, -0.02, 0.05], "fr": [0, -0.02, 0.06], "hl": [0, 0.02, 0.05], "hr": [0, 0.02, 0.06],
                "spine": [-6], "neck": [-6], "head": [-10], "tail": [-10, 24]}, "in"),
        (0.86, {"root": [80, 0.08, 0, 0], "body": [0.03, 0, 0], "fl": [0, -0.02, 0.06], "fr": [0, -0.02, 0.07], "hl": [0, 0.02, 0.06], "hr": [0, 0.02, 0.07],
                "neck": [-4], "head": [-6], "tail": [-6, 30]}, "out"),
        (1.2, {"root": [88, 0.08, 0, 0], "body": [0.03, 0, 0], "fl": [0, -0.03, 0.07], "fr": [0, -0.03, 0.08], "hl": [0, 0.03, 0.07], "hr": [0, 0.03, 0.08],
               "spine": [-4], "neck": [-8], "head": [-14], "tail": [-10, 26]}, "in")]),
    "fall_slump": ("Slump", "Its legs fold under it and it sinks onto its belly, its chin coming to rest on the ground.", 1.2, [
        (0.0, {}),
        (0.22, {"body": [0, -0.015, 4], "head": [8]}, "out"),
        (0.80, {"drop": [0.86], "body": [0, 0, -3], "spine": [-3], "neck": [-8], "head": [2], "tail": [-10, 10]}, "in"),
        (0.90, {"drop": [0.8], "body": [0, 0, -2], "neck": [-5], "head": [6]}, "out"),
        (1.2, {"drop": [0.88], "body": [0, 0, -3], "spine": [-3], "neck": [-9], "head": [4, 10, 10], "tail": [-12, 20]}, "in")]),
}

WINS = {
    "win_spin": ("Victory spin", "Hops and turns a full circle on the spot, landing with its chest up and its tail high.", 1.6, [
        (0.0, {}),
        (0.2, {"body": [0, -0.04, -2], "tail": [-8]}, "out"),
        (0.42, {"root": [0, 0, 0, 0.1, 90], "carry": JUMP, "fl": [0, 0, 0.04], "fr": [0, 0, 0.04], "hl": [0, 0, 0.03], "hr": [0, 0, 0.03], "tail": [20, 24, 10]}, "out"),
        (0.72, {"root": [0, 0, 0, 0.1, 290], "carry": JUMP, "fl": [0, 0, 0.04], "fr": [0, 0, 0.04], "hl": [0, 0, 0.03], "hr": [0, 0, 0.03], "tail": [20, 24, 10]}, "linear"),
        (0.9, {"root": [0, 0, 0, 0, 360], "body": [0, -0.03, 0]}, "in"),
        (1.6, {"root": [0, 0, 0, 0, 360], "body": [0, 0.008, 7], "spine": [5], "neck": [10], "head": [8], "tail": [30, 0, 25]}, "over")]),
    "win_prance": ("Prance", "Bounces twice on its forepaws, head tossing, too pleased with itself to keep still.", 1.6, [
        (0.0, {}),
        (0.16, {"body": [0, -0.02, -3], "head": [-4]}, "out"),
        (0.36, {"body": [0, 0.03, 12], "spine": [6], "carry": [1, 1, 0, 0], "fl": [0, 0.01, 0.05], "fr": [0, 0.02, 0.06], "neck": [8], "head": [12, 8], "tail": [28, 14, 12]}, "out"),
        (0.52, {"body": [0, -0.018, -4], "fl": [0, 0.01, 0], "fr": [0, 0.02, 0], "head": [-4], "tail": [10]}, "in"),
        (0.74, {"body": [0, 0.034, 13], "spine": [6], "carry": [1, 1, 0, 0], "fl": [0, 0.02, 0.06], "fr": [0, 0.01, 0.05], "neck": [8], "head": [12, -8], "tail": [28, -14, 12]}, "out"),
        (0.92, {"body": [0, -0.018, -4], "fl": [0, 0.02, 0], "fr": [0, 0.01, 0], "head": [-4], "tail": [10]}, "in"),
        (1.6, {"body": [0, 0.008, 6], "spine": [4], "fl": [0, 0.02, 0], "fr": [0, 0.01, 0], "neck": [10], "head": [8], "tail": [28, 0, 22]}, "over")]),
    "win_stretch": ("Lazy stretch", "A long cat stretch, forepaws far forward and chest to the ground, then it stands as if nothing happened.", 1.6, [
        (0.0, {}),
        (0.50, {"body": [0.02, -0.02, -11], "spine": [-10], "fl": [0, 0.12, 0], "fr": [0, 0.12, 0], "neck": [8], "head": [12], "tail": [40, 0, 20]}, "out"),
        (0.95, {"body": [0.024, -0.024, -12], "spine": [-11], "fl": [0, 0.12, 0], "fr": [0, 0.12, 0], "neck": [10], "head": [14], "tail": [40, 15, 20]}),
        (1.6, {"body": [0.01, 0.008, 5], "spine": [4], "fl": [0, 0.05, 0], "fr": [0, 0.05, 0], "neck": [10], "head": [8], "tail": [25, 0, 20]}, "out")]),
}

CLIPS = {
    "idle_scan": ("Lookout", "idle", "Upright and alert, its head snapping from one point to the next, its tail swishing.", LOOP, idle_scan, True),
    "idle_blocks": ("In the blocks", "idle", "Low over its forepaws like a sprinter, haunches twitching, ready to go.", LOOP, idle_blocks, True),
    "idle_restless": ("Restless", "idle", "Cannot stand still: shifts its weight, paws once at the ground, lashes its tail.", LOOP, idle_restless, True),
    "walk_stalk": ("Stalk", "run", "The game's pace: a slinking four-beat walk, shoulders rolling, the head dead level.", 0.78, walk_stalk, True),
    "run_sprint": ("Sprint", "run", "Hind legs together, forelegs together, the spine folding like a spring.", 0.5, run_sprint, True),
    "run_gallop": ("Gallop", "run", "A loose rotary gallop.", 0.56, run_gallop, True),
}
for kind, table in (("attack", ATTACKS), ("power", POWERS), ("hit", HITS), ("fall", FALLS), ("win", WINS)):
    for k, (name, desc, secs, keys) in table.items():
        CLIPS[k] = (name, kind, desc, secs, rp.keyed(keys), False)
