"""The jackals' own clips: quick, wary, in and out before the answer comes. Lengths and blow times are the game's (idle
loop 4.8 s, attack 0.95 s with the blow at 0.44, power 1.6 s with the blow at 0.92, hit 0.4 s, fall 1.2 s, win 1.6 s).
A dog's body: it bites and howls, it does not swipe; its head and tail say most of what it means."""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import rigpose as rp
from clipsets.quad import cyc, gait, span, TAU

SPRING = (2.6, 0.28)  # a bushy tail: follows a beat late, a swing or two to settle
LOOP = 4.8
JUMP = [1, 1, 1, 1]


# --- idles ----------------------------------------------------------------------------------------------------------
def idle_alert(t):  # ears up and head high, it checks one side, then the other; the tail hangs and sways
    look = math.copysign(abs(cyc(t, 4.8)) ** 0.5, cyc(t, 4.8))
    return {"body": [0, 0.003 * cyc(t, 1.6), 2], "spine": [1.5 * cyc(t, 1.6)], "neck": [8, 18 * look],
            "head": [2 + 2 * cyc(t, 2.4, 0.2), 14 * look, 5 * cyc(t, 2.4, 0.3)], "tail": [-6, 14 * cyc(t, 2.4), 4]}


def idle_sniff(t):  # nose to the ground, casting from side to side for a scent, then up to test the air
    w = span(t, 0.5, 3.3)
    up = span(t, 3.4, 4.6)
    sw = math.sin(TAU * (t % LOOP - 0.5) / 0.93)
    return {"body": [0.006 * w, 0.003 * cyc(t, 1.6) - 0.008 * w, -5 * w + 3 * up], "spine": [-2 * w, 4 * sw * w],
            "neck": [-18 * w + 10 * up, 12 * sw * w], "head": [-14 * w + 14 * up + 2 * w * math.sin(TAU * t / 0.3), 10 * sw * w],
            "tail": [4 * w + 10 * up, 16 * cyc(t, 1.2), 2]}


def idle_howl(t):  # stands easy; once a loop it lifts its muzzle to the sky and howls, swaying with the note
    h = span(t, 1.4, 3.6)
    return {"body": [-0.008 * h, 0.003 * cyc(t, 1.6) + 0.006 * h, 7 * h], "spine": [1.5 * cyc(t, 1.6) + 5 * h],
            "neck": [3 + 18 * h, 4 * cyc(t, 4.8) + 3 * h * cyc(t, 1.1)], "head": [2 + 34 * h, 5 * cyc(t, 4.8, 0.1), 3 * h * cyc(t, 1.1)],
            "tail": [-4 + 14 * h, 12 * cyc(t, 2.4), 6]}


# --- walks and runs -------------------------------------------------------------------------------------------------
def walk_slink(t):  # the game's pace: a light, quick four-beat walk, head low and swinging, ready to bolt
    return gait(t, 0.72, {"hl": 0.0, "fl": 0.25, "hr": 0.5, "fr": 0.75}, 0.58, 0.09, 0.04,
                lambda c: {"body": [0, -0.008 + 0.004 * math.cos(2 * TAU * c + 0.5), -2, 2 * math.sin(TAU * c + 0.4),
                                    1.2 * math.sin(TAU * c + 0.4), 0.004 * math.sin(TAU * c + 0.4)],
                           "spine": [0, 5 * math.sin(TAU * c + 1.2)], "neck": [-8, -4 * math.sin(TAU * c + 0.4)],
                           "head": [4 + 2 * math.cos(2 * TAU * c + 1.5), -4 * math.sin(TAU * c + 0.4)],
                           "tail": [-8, 12 * math.sin(TAU * c - 0.6), 4]})


def run_trot(t):  # a jackal's all-day trot: diagonal pairs, the back level, the tail streaming
    return gait(t, 0.46, {"hl": 0.0, "fr": 0.02, "hr": 0.5, "fl": 0.52}, 0.44, 0.09, 0.055,
                lambda c: {"body": [0, 0.012 * abs(math.cos(TAU * c)), 0, 0, 2.5 * math.sin(TAU * c)],
                           "neck": [-2 + 1.5 * math.cos(2 * TAU * c)], "head": [2 * math.cos(2 * TAU * c + 0.5), -2 * math.sin(TAU * c)],
                           "tail": [6, 12 * math.sin(TAU * c), 4]})


def run_gallop(t):  # flat out, ears back
    return gait(t, 0.52, {"hl": 0.0, "hr": 0.1, "fl": 0.45, "fr": 0.55}, 0.36, 0.12, 0.08,
                lambda c: {"body": [0, 0.026 + 0.018 * math.cos(TAU * c), 5 * math.sin(TAU * c)],
                           "spine": [10 * math.sin(TAU * c + 0.6)], "neck": [-4 - 5 * math.sin(TAU * c)],
                           "head": [4 * math.sin(TAU * c + 0.3)], "tail": [10, 6 * math.sin(TAU * c), 8 * math.sin(TAU * c + 1)]})


# --- one-shots -----------------------------------------------------------------------------------------------------
ATTACKS = {
    "attack_snap": ("Snap and spring back", "Darts its head and shoulders in, snaps, and is back out of reach before the answer comes.", 0.95, [
        (0.0, {}),
        (0.18, {"body": [-0.03, -0.03, -4], "spine": [-5], "neck": [-8], "head": [10], "tail": [-10]}, "out"),
        (0.42, {"body": [0.11, -0.02, -4], "spine": [3], "neck": [-6], "head": [-10], "fl": [0, 0.09, 0], "fr": [0, 0.07, 0], "tail": [26, 0, 8]}, "in"),
        (0.48, {"body": [0.105, -0.014, -2], "neck": [4], "head": [14], "fl": [0, 0.09, 0], "fr": [0, 0.07, 0], "tail": [20, 10]}, "out"),
        (0.70, {"body": [-0.03, -0.02, 2], "spine": [-3], "neck": [4], "head": [6], "fl": [0, -0.01, 0], "fr": [0, -0.02, 0], "tail": [-6, -12]}, "out"),
        (0.95, {})]),
    "attack_lunge": ("Leap and worry", "Springs at the throat with all four feet off the ground, bites, and shakes what it has.", 0.95, [
        (0.0, {}),
        (0.20, {"body": [-0.03, -0.045, -6], "spine": [-8], "neck": [-8], "head": [10], "tail": [-10, 0, 8]}, "out"),
        (0.36, {"body": [0.07, 0.06, 12], "spine": [8], "carry": JUMP, "fl": [0, 0.06, 0.05], "fr": [0, 0.06, 0.05],
                "hl": [0, -0.05, 0.03], "hr": [0, -0.05, 0.03], "neck": [6], "head": [8], "tail": [16, 0, -8]}, "out"),
        (0.44, {"body": [0.11, -0.01, 2], "spine": [-3], "fl": [0, 0.13, 0], "fr": [0, 0.13, 0], "hl": [0, 0.05, 0], "hr": [0, 0.05, 0],
                "neck": [-4], "head": [-8], "tail": [28, 0, 8]}, "in"),
        (0.54, {"body": [0.105, -0.01, 0], "fl": [0, 0.13, 0], "fr": [0, 0.13, 0], "hl": [0, 0.05, 0], "hr": [0, 0.05, 0], "neck": [0, 10], "head": [-2, 14, 10], "tail": [18, -14]}),
        (0.64, {"body": [0.1, -0.01, 0], "fl": [0, 0.13, 0], "fr": [0, 0.13, 0], "hl": [0, 0.05, 0], "hr": [0, 0.05, 0], "neck": [0, -10], "head": [-2, -14, -10], "tail": [18, 14]}),
        (0.95, {})]),
    "attack_feint": ("Feint and bite", "A false start to one side, then the real bite from the other.", 0.95, [
        (0.0, {}),
        (0.16, {"body": [0.03, -0.015, -2, -8, -4, 0.03], "spine": [0, -6], "neck": [-4, -10], "head": [2, -12], "fl": [0.03, 0.03, 0], "tail": [4, 18]}, "out"),
        (0.30, {"body": [-0.01, -0.03, -4, 6, 4, -0.02], "spine": [-4, 5], "neck": [-8, 8], "head": [8, 8], "fl": [0.03, 0.03, 0], "tail": [-6, -16]}, "out"),
        (0.44, {"body": [0.1, -0.02, -3, 10, 0, -0.03], "spine": [2, 6], "neck": [-6, 10], "head": [-8, 12], "fl": [0, 0.08, 0], "fr": [-0.02, 0.09, 0], "tail": [24, -10, 8]}, "in"),
        (0.52, {"body": [0.095, -0.012, -1, 8, 0, -0.03], "neck": [4, 8], "head": [12, 8], "fl": [0, 0.08, 0], "fr": [-0.02, 0.09, 0], "tail": [16, 12]}, "out"),
        (0.76, {"body": [0.03, -0.004, 0], "fl": [0, 0.03, 0], "fr": [0, 0.03, 0], "head": [4]}),
        (0.95, {})]),
}

LAND = {"fl": [0, 0.12, 0], "fr": [0, 0.12, 0], "hl": [0, 0.06, 0], "hr": [0, 0.06, 0]}
POWERS = {
    "power_howl": ("Death howl", "Plants its feet, fills its chest and throws its muzzle to the sky; the howl goes out and it leans into it.", 1.6, [
        (0.0, {}),
        (0.25, {"body": [-0.01, -0.03, -4], "neck": [-10], "head": [-6], "tail": [-10]}, "out"),
        (0.70, {"body": [-0.03, 0.01, 8], "spine": [6], "neck": [14], "head": [20], "tail": [10, 0, 6]}, "out"),
        (0.84, {"body": [-0.035, 0.012, 9], "spine": [7], "neck": [16], "head": [26], "tail": [12, 0, 6]}),
        (0.92, {"body": [0.02, 0.004, 12], "spine": [8], "neck": [22], "head": [40], "fl": [0, 0.02, 0], "fr": [0, 0.02, 0], "tail": [22, 0, 10]}, "in"),
        (1.02, {"body": [0.016, 0.002, 10], "spine": [7], "neck": [20, 4], "head": [36, 4], "fl": [0, 0.02, 0], "fr": [0, 0.02, 0], "tail": [18, 8]}, "out"),
        (1.30, {"body": [0.014, 0.002, 9], "spine": [6], "neck": [18, -4], "head": [32, -4], "fl": [0, 0.02, 0], "fr": [0, 0.02, 0], "tail": [16, -8]}),
        (1.6, {})]),
    "power_pounce": ("Carrion pounce", "Sinks to a crawl, wriggles, then arcs high and comes down muzzle first, like a jackal on a mouse.", 1.6, [
        (0.0, {}),
        (0.30, {"body": [-0.02, -0.05, -6], "spine": [-9], "neck": [-12], "head": [12], "tail": [-12]}, "out"),
        (0.54, {"body": [-0.025, -0.055, -7, 0, 0, 0.006], "spine": [-9, 3], "neck": [-12], "head": [13], "tail": [-12, 18]}),
        (0.78, {"body": [0.03, 0.17, 4], "spine": [10], "carry": JUMP, "fl": [0, 0.02, 0.07], "fr": [0, 0.02, 0.07],
                "hl": [0, -0.03, 0.03], "hr": [0, -0.03, 0.03], "neck": [-10], "head": [-20], "tail": [26, 0, -10]}, "out"),
        (0.92, {"body": [0.08, -0.03, -16], "spine": [-8], **LAND, "neck": [-16], "head": [-12], "tail": [38, 0, 10]}, "in"),
        (1.02, {"body": [0.075, -0.018, -10], **LAND, "neck": [-8], "head": [-2], "tail": [22, 10]}, "out"),
        (1.32, {"body": [0.03, -0.006, -2], "fl": [0, 0.05, 0], "fr": [0, 0.05, 0], "hl": [0, 0.02, 0], "hr": [0, 0.02, 0]}),
        (1.6, {})]),
    "power_harry": ("Harry", "Three bites in a breath: left, right, and the last one through the middle with everything behind it.", 1.6, [
        (0.0, {}),
        (0.16, {"body": [-0.02, -0.03, -4], "spine": [-5], "head": [8], "tail": [-8]}, "out"),
        (0.32, {"body": [0.07, -0.02, -3, -10, 0, 0.04], "spine": [2, -6], "neck": [-6, -10], "head": [-6, -12], "fl": [0.03, 0.07, 0], "fr": [0.02, 0.05, 0], "tail": [18, 16]}, "in"),
        (0.44, {"body": [-0.01, -0.02, -2, 4, 0, 0.01], "neck": [2], "head": [8], "fl": [0.01, 0.01, 0], "fr": [0.01, 0.01, 0], "tail": [-4, -10]}, "out"),
        (0.60, {"body": [0.07, -0.02, -3, 10, 0, -0.04], "spine": [2, 6], "neck": [-6, 10], "head": [-6, 12], "fl": [-0.02, 0.05, 0], "fr": [-0.03, 0.07, 0], "tail": [18, -16]}, "in"),
        (0.74, {"body": [-0.03, -0.045, -6], "spine": [-8], "neck": [-8], "head": [10], "fl": [0, 0.01, 0], "fr": [0, 0.01, 0], "tail": [-10, 0, 8]}, "out"),
        (0.92, {"body": [0.14, -0.02, -4], "spine": [4], "neck": [-6], "head": [-10], "fl": [0, 0.15, 0], "fr": [0, 0.15, 0], "hl": [0, 0.07, 0], "hr": [0, 0.07, 0], "tail": [30, 0, 10]}, "in"),
        (1.00, {"body": [0.135, -0.012, -2], "neck": [4], "head": [14], "fl": [0, 0.15, 0], "fr": [0, 0.15, 0], "hl": [0, 0.07, 0], "hr": [0, 0.07, 0], "tail": [20, 12]}, "out"),
        (1.32, {"body": [0.05, -0.004, 0], "fl": [0, 0.06, 0], "fr": [0, 0.06, 0], "hl": [0, 0.03, 0], "hr": [0, 0.03, 0]}),
        (1.6, {})]),
}

HITS = {
    "hit_yelp": ("Yelp", "Jerks back from the blow with its head thrown aside and its tail clamped down.", 0.4, [
        (0.0, {}),
        (0.08, {"body": [-0.04, -0.008, 4, 8, -5], "spine": [2, 6], "neck": [6, 12], "head": [8, 14, 8], "tail": [-24, -10]}, "out"),
        (0.22, {"body": [-0.02, -0.014, -2, 3], "head": [-4, 4], "tail": [-16]}),
        (0.4, {})]),
    "hit_snarl": ("Snarl", "Rocked back, it drops its head between its shoulders and bares its teeth at whatever struck it.", 0.4, [
        (0.0, {}),
        (0.08, {"body": [-0.035, -0.01, 4], "spine": [3], "neck": [6], "head": [8], "tail": [10]}, "out"),
        (0.20, {"body": [-0.012, -0.022, -5], "spine": [-3], "neck": [-12], "head": [10, -8, -6], "tail": [-4, 14]}, "in"),
        (0.4, {})]),
}

FALLS = {
    "fall_slump": ("Slump", "Its legs fold under it and it sinks onto its belly, its chin coming to rest on the ground.", 1.2, [
        (0.0, {}),
        (0.22, {"body": [0, -0.015, 4], "head": [8]}, "out"),
        (0.80, {"drop": [0.86], "body": [0, 0, -3], "spine": [-3], "neck": [-8], "head": [2], "tail": [-10, 10]}, "in"),
        (0.90, {"drop": [0.8], "body": [0, 0, -2], "neck": [-5], "head": [6]}, "out"),
        (1.2, {"drop": [0.88], "body": [0, 0, -3], "spine": [-3], "neck": [-9], "head": [4, 10, 10], "tail": [-12, 20]}, "in")]),
    "fall_roll": ("Topple", "Staggers a step, then goes over onto its side with its legs out.", 1.2, [
        (0.0, {}),
        (0.26, {"body": [-0.01, -0.01, 0, 0, -8, -0.01], "head": [6, 0, -8], "tail": [-10]}, "out"),
        (0.80, {"root": [86, 0.08, 0, 0], "fl": [0, -0.02, 0.05], "fr": [0, -0.02, 0.06], "hl": [0, 0.02, 0.05], "hr": [0, 0.02, 0.06],
                "neck": [-6], "head": [-10], "tail": [-10, 20]}, "in"),
        (0.90, {"root": [81, 0.08, 0, 0], "fl": [0, -0.02, 0.06], "fr": [0, -0.02, 0.07], "hl": [0, 0.02, 0.06], "hr": [0, 0.02, 0.07],
                "neck": [-4], "head": [-6], "tail": [-6, 24]}, "out"),
        (1.2, {"root": [88, 0.08, 0, 0], "fl": [0, -0.03, 0.07], "fr": [0, -0.03, 0.08], "hl": [0, 0.03, 0.07], "hr": [0, 0.03, 0.08],
               "neck": [-8], "head": [-14], "tail": [-10, 25]}, "in")]),
}

WINS = {
    "win_howl": ("Victory howl", "Sits back on its haunches a little, muzzle to the sky, and howls the news.", 1.6, [
        (0.0, {}),
        (0.25, {"body": [-0.01, -0.02, -3], "neck": [-6], "head": [-4], "tail": [-6]}, "out"),
        (0.65, {"body": [-0.03, -0.012, 14], "spine": [8], "neck": [20], "head": [38], "hl": [0, 0.03, 0], "hr": [0, 0.03, 0], "tail": [10, 0, 6]}, "out"),
        (1.05, {"body": [-0.03, -0.01, 15], "spine": [8], "neck": [22, 6], "head": [40, 6, 4], "hl": [0, 0.03, 0], "hr": [0, 0.03, 0], "tail": [12, 10, 6]}),
        (1.35, {"body": [-0.01, -0.004, 5], "spine": [3], "neck": [8], "head": [10], "hl": [0, 0.015, 0], "hr": [0, 0.015, 0], "tail": [8, -8]}, "in"),
        (1.6, {"body": [0, 0.004, 3], "spine": [2], "neck": [8], "head": [6], "tail": [6, 0, 6]}, "out")]),
    "win_shake": ("Shake it off", "Shakes itself from nose to tail like a dog out of a river, then stands with its head up.", 1.6, [
        (0.0, {}),
        (0.20, {"body": [0, -0.012, -3], "neck": [-8], "head": [-6]}, "out"),
        (0.36, {"body": [0, -0.012, -3, 0, 7], "spine": [0, 0, 8], "neck": [-8, 0], "head": [-6, 0, 22], "tail": [0, 24]}),
        (0.50, {"body": [0, -0.012, -3, 0, -7], "spine": [0, 0, -8], "neck": [-8, 0], "head": [-6, 0, -22], "tail": [0, -24]}),
        (0.64, {"body": [0, -0.012, -3, 0, 7], "spine": [0, 0, 8], "neck": [-8, 0], "head": [-6, 0, 20], "tail": [0, 24]}),
        (0.78, {"body": [0, -0.012, -3, 0, -6], "spine": [0, 0, -7], "neck": [-8, 0], "head": [-6, 0, -18], "tail": [0, -24]}),
        (0.92, {"body": [0, -0.01, -2, 0, 4], "spine": [0, 0, 4], "head": [-4, 0, 10], "tail": [0, 14]}),
        (1.6, {"body": [0, 0.005, 4], "spine": [3], "neck": [10], "head": [6], "tail": [10, 0, 8]}, "over")]),
    "win_bow": ("Play bow", "Drops its chest to the ground with its rump in the air, tail going, then springs up.", 1.6, [
        (0.0, {}),
        (0.34, {"body": [0.02, -0.02, -12], "spine": [-9], "fl": [0, 0.1, 0], "fr": [0, 0.1, 0], "neck": [10], "head": [14], "tail": [36, 20, 10]}, "out"),
        (0.56, {"body": [0.022, -0.022, -13], "spine": [-10], "fl": [0, 0.1, 0], "fr": [0, 0.1, 0], "neck": [10, 8], "head": [14, 8, 8], "tail": [36, -22, 10]}),
        (0.78, {"body": [0.02, -0.02, -12], "spine": [-9], "fl": [0, 0.1, 0], "fr": [0, 0.1, 0], "neck": [10, -8], "head": [14, -8, -8], "tail": [36, 22, 10]}),
        (1.02, {"body": [0, 0.04, 8], "spine": [5], "carry": JUMP, "fl": [0, 0.02, 0.04], "fr": [0, 0.02, 0.04], "hl": [0, 0, 0.03], "hr": [0, 0, 0.03], "neck": [8], "head": [8], "tail": [24, 0, 10]}, "out"),
        (1.20, {"body": [0, -0.016, -3], "fl": [0, 0.03, 0], "fr": [0, 0.03, 0], "head": [-2], "tail": [10]}, "in"),
        (1.6, {"body": [0, 0.005, 4], "spine": [3], "fl": [0, 0.03, 0], "fr": [0, 0.03, 0], "neck": [10], "head": [6], "tail": [12, 0, 8]}, "over")]),
}

CLIPS = {
    "idle_alert": ("On watch", "idle", "Ears up and head high, it checks one side, then the other; its tail hangs and sways.", LOOP, idle_alert, True),
    "idle_sniff": ("On the scent", "idle", "Nose to the ground, casting from side to side, then up to test the air.", LOOP, idle_sniff, True),
    "idle_howl": ("Howl", "idle", "Stands easy; once a loop it lifts its muzzle to the sky and howls.", LOOP, idle_howl, True),
    "walk_slink": ("Slink", "run", "The game's pace: a light, quick four-beat walk, head low and swinging.", 0.72, walk_slink, True),
    "run_trot": ("Trot", "run", "An all-day trot: diagonal pairs, the back level, the tail streaming.", 0.46, run_trot, True),
    "run_gallop": ("Gallop", "run", "Flat out, the spine folding and opening.", 0.52, run_gallop, True),
}
for kind, table in (("attack", ATTACKS), ("power", POWERS), ("hit", HITS), ("fall", FALLS), ("win", WINS)):
    for k, (name, desc, secs, keys) in table.items():
        CLIPS[k] = (name, kind, desc, secs, rp.keyed(keys), False)
