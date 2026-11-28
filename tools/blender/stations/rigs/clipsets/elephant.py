"""The elephants' own clips: slow, enormous, and all in the trunk and ears. Lengths and blow times are the game's (idle
loop 4.8 s, attack 0.95 s with the blow at 0.44, power 1.6 s with the blow at 0.92, hit 0.4 s, fall 1.2 s, win 1.6 s).
An elephant never has all four feet off the ground and never trots: it ambles, each foot down most of the stride.
Its trunk ("trunk": [curl up, sway]) and ears (ears(): fanned forward or laid back) lead every move and follow
through on springs."""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import rigpose as rp
from clipsets.quad import cyc, gait, span, TAU

SPRING = (1.6, 0.3)  # a trunk, ears and a rope of a tail: heavy, slow to follow, slow to settle
LOOP = 4.8


def ears(a, b=None):
    """Both ears fanned forward by a degrees (laid back when negative); the right one by b when given."""
    return {"ear_l": [0, -a], "ear_r": [0, a if b is None else b]}


# --- idles ----------------------------------------------------------------------------------------------------------
def idle_sway(t):  # weight from one side to the other, the ears fanning slowly, the trunk swinging like a pendulum
    sh = cyc(t, 4.8)
    return {"body": [0, 0.003 * cyc(t, 2.4), 0, 0, 1.6 * sh, 0.008 * sh], "spine": [1.2 * cyc(t, 2.4)],
            "neck": [0, 4 * cyc(t, 4.8, 0.1)], "head": [2 * cyc(t, 2.4, 0.2), 5 * cyc(t, 4.8, 0.15)],
            "trunk": [6 + 5 * cyc(t, 2.4), 18 * cyc(t, 4.8, 0.2)], **ears(8 + 12 * cyc(t, 2.4, 0.1)),
            "tail": [0, 16 * cyc(t, 1.6), 0]}


def idle_dust(t):  # curls its trunk down to the ground, then throws it up and back over its shoulder: a dust bath
    d = span(t, 0.6, 2.2)  # reaching down
    u = span(t, 2.2, 3.8)  # the throw
    return {"body": [0, 0.003 * cyc(t, 2.4) - 0.006 * d + 0.006 * u, -2 * d + 4 * u], "spine": [1.2 * cyc(t, 2.4)],
            "neck": [-6 * d + 8 * u, 6 * u], "head": [-8 * d + 14 * u, 8 * u, 6 * u],
            "trunk": [-10 * d + 110 * u, 20 * u], **ears(6 + 10 * cyc(t, 2.4) + 16 * u), "tail": [0, 14 * cyc(t, 1.6), 0]}


def idle_trumpet(t):  # stands easy; once a loop it lifts its head and trunk and trumpets, ears spread wide
    r = span(t, 1.5, 3.3)
    return {"body": [-0.008 * r, 0.003 * cyc(t, 2.4) + 0.008 * r, 6 * r], "spine": [1.2 * cyc(t, 2.4) + 4 * r],
            "neck": [10 * r, 4 * cyc(t, 4.8)], "head": [18 * r, 5 * cyc(t, 4.8, 0.1)],
            "trunk": [6 + 4 * cyc(t, 2.4) + 120 * r, 14 * cyc(t, 4.8, 0.2) * (1 - r)], **ears(8 + 10 * cyc(t, 2.4) + 30 * r),
            "tail": [10 * r, 16 * cyc(t, 1.6), 0]}


# --- walks ---------------------------------------------------------------------------------------------------------
def walk_amble(t):  # the game's pace: the amble, back foot then front foot of one side, each down for two thirds of
    # the stride; the head nods and the trunk and ears swing with it
    return gait(t, 1.0, {"hl": 0.0, "fl": 0.22, "hr": 0.5, "fr": 0.72}, 0.66, 0.1, 0.035,
                lambda c: {"body": [0, -0.003 + 0.004 * math.cos(2 * TAU * c + 0.5), 0.6 * math.sin(2 * TAU * c), 1.2 * math.sin(TAU * c + 0.4),
                                    2.0 * math.sin(TAU * c + 0.4), 0.006 * math.sin(TAU * c + 0.4)],
                           "spine": [0, 2 * math.sin(TAU * c + 1.2)], "neck": [-2 + 2 * math.cos(2 * TAU * c + 0.9)],
                           "head": [2.5 * math.cos(2 * TAU * c + 1.5), -2 * math.sin(TAU * c + 0.4)],
                           "trunk": [8 + 6 * math.cos(2 * TAU * c + 2.0), 14 * math.sin(TAU * c + 0.9)],
                           **ears(6 + 10 * math.cos(2 * TAU * c + 2.4)), "tail": [0, 14 * math.sin(TAU * c), 0]})


def run_charge(t):  # the charge: the same amble at twice the beat, ears spread wide, trunk tucked, head low
    return gait(t, 0.6, {"hl": 0.0, "fl": 0.2, "hr": 0.5, "fr": 0.7}, 0.56, 0.12, 0.05,
                lambda c: {"body": [0, 0.004 + 0.008 * math.cos(2 * TAU * c + 0.5), -3 + 1.5 * math.sin(2 * TAU * c), 0, 2.5 * math.sin(TAU * c + 0.4)],
                           "spine": [0, 2.5 * math.sin(TAU * c + 1.2)], "neck": [-6 + 2 * math.cos(2 * TAU * c)],
                           "head": [-4 + 3 * math.cos(2 * TAU * c + 0.6)], "trunk": [50 + 8 * math.cos(2 * TAU * c + 1.2), 6 * math.sin(TAU * c)],
                           **ears(34 + 8 * math.cos(2 * TAU * c + 2.0)), "tail": [30, 10 * math.sin(TAU * c), 0]})


def run_march(t):  # a parade march: each forefoot lifted high and set down with weight, the trunk held up
    return gait(t, 0.9, {"hl": 0.0, "fl": 0.25, "hr": 0.5, "fr": 0.75}, 0.6, 0.085, 0.075,
                lambda c: {"body": [0, 0.004 * math.cos(2 * TAU * c + 0.5), 2, 0, 2.2 * math.sin(TAU * c + 0.4), 0.005 * math.sin(TAU * c + 0.4)],
                           "neck": [4 + 2 * math.cos(2 * TAU * c + 0.9)], "head": [4 + 2 * math.cos(2 * TAU * c + 1.5)],
                           "trunk": [70 + 8 * math.cos(2 * TAU * c + 2.0), 6 * math.sin(TAU * c)],
                           **ears(14 + 10 * math.cos(2 * TAU * c + 2.4)), "tail": [10, 12 * math.sin(TAU * c), 0]})


# --- one-shots -----------------------------------------------------------------------------------------------------
ATTACKS = {
    "attack_tusk": ("Tusk hook", "Drops its head, steps in and hooks its tusks up and through, ears snapping forward.", 0.95, [
        (0.0, {}),
        (0.24, {"body": [-0.02, -0.014, -5], "neck": [-10], "head": [-12], "trunk": [60, 0], **ears(-14), "tail": [-6]}, "out"),
        (0.44, {"body": [0.07, 0.006, 6], "spine": [3], "neck": [12], "head": [22], "fl": [0, 0.07, 0], "trunk": [90, 0], **ears(34), "tail": [24]}, "in"),
        (0.52, {"body": [0.066, 0.008, 8], "spine": [4], "neck": [15], "head": [27], "fl": [0, 0.07, 0], "trunk": [80, 0], **ears(26), "tail": [26]}, "out"),
        (0.76, {"body": [0.03, 0, 2], "neck": [4], "head": [6], "fl": [0, 0.03, 0], "trunk": [30, 0], **ears(10), "tail": [10]}),
        (0.95, {})]),
    "attack_trunk": ("Trunk lash", "Winds its trunk back over one shoulder and lashes it across like a whip.", 0.95, [
        (0.0, {}),
        (0.24, {"body": [-0.01, 0.004, 3, 8], "spine": [0, 5], "neck": [4, 12], "head": [6, 16], "trunk": [70, 50], **ears(10, -6), "tail": [0, -16]}, "out"),
        (0.44, {"body": [0.03, -0.006, -2, -10], "spine": [0, -6], "neck": [-4, -14], "head": [-4, -20], "fr": [0, 0.04, 0], "trunk": [40, -70], **ears(20, 30), "tail": [0, 26]}, "in"),
        (0.52, {"body": [0.03, -0.004, -1, -12], "spine": [0, -7], "neck": [-4, -16], "head": [-4, -24], "fr": [0, 0.04, 0], "trunk": [30, -80], **ears(14, 24), "tail": [0, 30]}, "out"),
        (0.76, {"body": [0.012, 0, 0, -4], "neck": [0, -5], "head": [0, -8], "fr": [0, 0.02, 0], "trunk": [14, -24], **ears(8)}),
        (0.95, {})]),
    "attack_stamp": ("Stamp", "Lifts a forefoot high and brings its whole weight down through it.", 0.95, [
        (0.0, {}),
        (0.26, {"body": [-0.01, 0.01, 5, 0, 5, -0.012], "spine": [3], "fl": [0, 0.03, 0.1], "neck": [4], "head": [8], "trunk": [50, 0], **ears(24), "tail": [14]}, "out"),
        (0.44, {"body": [0.03, -0.022, -5, 0, -3, 0.006], "spine": [-3], "fl": [0, 0.07, 0], "neck": [-8], "head": [-8], "trunk": [10, 0], **ears(-10), "tail": [30]}, "in"),
        (0.52, {"body": [0.028, -0.012, -3], "fl": [0, 0.07, 0], "neck": [-4], "head": [-2], "trunk": [0, 0], **ears(6), "tail": [16]}, "out"),
        (0.76, {"body": [0.012, -0.002, -1], "fl": [0, 0.03, 0], **ears(8)}),
        (0.95, {})]),
}

UP = {"carry": [1, 1, 0, 0], "fl": [0, 0, 0.06], "fr": [0, 0.01, 0.07]}
DOWN = {"fl": [0, 0.06, 0], "fr": [0, 0.06, 0]}
POWERS = {
    "power_quake": ("Earthquake", "Rears until its forefeet leave the ground, hangs there, and comes down with everything it weighs.", 1.6, [
        (0.0, {}),
        (0.30, {"body": [-0.01, -0.02, -4], "neck": [-8], "head": [-8], "trunk": [20, 0], **ears(-10), "tail": [-6]}, "out"),
        (0.66, {"body": [-0.04, 0.03, 20], "spine": [7], **UP, "neck": [8], "head": [12], "trunk": [110, 0], **ears(36), "tail": [26]}, "out"),
        (0.82, {"body": [-0.04, 0.034, 22], "spine": [8], **UP, "neck": [10], "head": [16], "trunk": [120, 8], **ears(40), "tail": [30, 8]}),
        (0.92, {"body": [0.03, -0.03, -8], "spine": [-5], **DOWN, "neck": [-12], "head": [-10], "trunk": [10, 0], **ears(-16), "tail": [40, 0, 10]}, "in"),
        (1.02, {"body": [0.03, -0.014, -3], "spine": [-2], **DOWN, "neck": [-4], "head": [-2], "trunk": [0, 0], **ears(10), "tail": [22]}, "out"),
        (1.32, {"body": [0.014, -0.004, 0], "fl": [0, 0.03, 0], "fr": [0, 0.03, 0], "head": [3], **ears(8)}),
        (1.6, {})]),
    "power_charge": ("Stampede", "Ears out like sails, it rocks back, then drives forward and throws its tusks up through whatever is there.", 1.6, [
        (0.0, {}),
        (0.22, {"body": [-0.01, -0.006, -2], "neck": [-4], "head": [-6], "trunk": [30, 0], **ears(40)}, "out"),
        (0.50, {"body": [-0.05, -0.016, -5], "spine": [-3], "neck": [-10], "head": [-14], "trunk": [60, 0], **ears(46), "tail": [24]}, "out"),
        (0.72, {"body": [-0.055, -0.018, -6], "spine": [-3], "neck": [-12], "head": [-16], "trunk": [64, 0], **ears(48), "tail": [28]}),
        (0.92, {"body": [0.12, 0.004, 6], "spine": [4], "neck": [12], "head": [24], "fl": [0, 0.12, 0], "fr": [0, 0.1, 0], "hl": [0, 0.08, 0], "hr": [0, 0.1, 0],
                "trunk": [100, 0], **ears(10), "tail": [36]}, "in"),
        (1.02, {"body": [0.115, 0.008, 8], "spine": [5], "neck": [15], "head": [30], "fl": [0, 0.12, 0], "fr": [0, 0.1, 0], "hl": [0, 0.08, 0], "hr": [0, 0.1, 0],
                "trunk": [90, 0], **ears(26), "tail": [38]}, "out"),
        (1.32, {"body": [0.06, 0, 1], "head": [6], "fl": [0, 0.06, 0], "fr": [0, 0.05, 0], "hl": [0, 0.04, 0], "hr": [0, 0.05, 0], "trunk": [30, 0], **ears(10)}),
        (1.6, {})]),
    "power_trumpet": ("War trumpet", "Draws breath with its trunk coiled, then throws head and trunk forward and trumpets, the blast shaking its ears.", 1.6, [
        (0.0, {}),
        (0.28, {"body": [-0.01, -0.01, -3], "neck": [-6], "head": [-8], "trunk": [80, 0], **ears(-12), "tail": [-6]}, "out"),
        (0.70, {"body": [-0.04, 0.008, 7], "spine": [5], "neck": [10], "head": [14], "trunk": [150, 0], **ears(20), "tail": [14]}, "out"),
        (0.84, {"body": [-0.045, 0.01, 8], "spine": [6], "neck": [12], "head": [18], "trunk": [160, 0], **ears(24), "tail": [16]}),
        (0.92, {"body": [0.04, -0.01, -2], "spine": [-2], "neck": [2], "head": [6], "fl": [0, 0.03, 0], "fr": [0, 0.03, 0], "trunk": [95, 0], **ears(50), "tail": [30]}, "in"),
        (1.02, {"body": [0.036, -0.006, -1], "neck": [3], "head": [8], "fl": [0, 0.03, 0], "fr": [0, 0.03, 0], "trunk": [100, 8], **ears(40), "tail": [24, 8]}, "out"),
        (1.28, {"body": [0.032, -0.006, -1], "neck": [3], "head": [7], "fl": [0, 0.03, 0], "fr": [0, 0.03, 0], "trunk": [96, -8], **ears(46), "tail": [22, -8]}),
        (1.6, {})]),
}

HITS = {
    "hit_brace": ("Brace", "Takes it on the forehead: its head drops, its ears clap back, and it leans into the blow.", 0.4, [
        (0.0, {}),
        (0.08, {"body": [-0.016, -0.008, -3], "neck": [-6], "head": [-8], "trunk": [20, 0], **ears(-24), "tail": [14]}, "out"),
        (0.22, {"body": [0.006, -0.004, -1], "head": [-2], "trunk": [6, 0], **ears(10)}, "in"),
        (0.4, {})]),
    "hit_shake": ("Head shake", "Rocked sideways, it shakes its great head once, ears cracking like sails.", 0.4, [
        (0.0, {}),
        (0.08, {"body": [-0.012, 0, 0, -5, 6, 0.014], "neck": [0, -8], "head": [2, -10, 10], "trunk": [10, 30], **ears(-20, 30), "tail": [0, 20]}, "out"),
        (0.22, {"body": [-0.004, 0, 0, 2, -3], "neck": [0, 5], "head": [0, 6, -8], "trunk": [6, -24], **ears(26, -16), "tail": [0, -14]}),
        (0.4, {})]),
}

FALLS = {
    "fall_kneel": ("Kneel and settle", "Its front knees go first; it sinks onto its chest, then its hindquarters follow and its trunk uncurls on the ground.", 1.2, [
        (0.0, {}),
        (0.22, {"body": [0, 0.004, 3], "head": [8], "trunk": [30, 0], **ears(20)}, "out"),
        (0.58, {"drop": [0.5], "body": [0.01, 0, -12], "spine": [-4], "neck": [4], "head": [8], "trunk": [20, 0], **ears(-10), "tail": [10]}, "in"),
        (0.66, {"drop": [0.45], "body": [0.01, 0, -10], "neck": [6], "head": [12], "trunk": [26, 0], **ears(6)}, "out"),
        (0.98, {"drop": [0.88], "body": [0.01, 0, -4, 0, 5], "spine": [-3], "neck": [6], "head": [10, 6, 8], "trunk": [40, 10], **ears(-14), "tail": [-10, 14]}, "in"),
        (1.2, {"drop": [0.9], "body": [0.01, 0, -4, 0, 6], "spine": [-3], "neck": [7], "head": [12, 8, 10], "trunk": [50, 14], **ears(-8), "tail": [-12, 16]}, "out")]),
    "fall_topple": ("Topple", "Sways, then goes over onto its side like a wall coming down.", 1.2, [
        (0.0, {}),
        (0.28, {"body": [0, 0, 0, 0, -5], "head": [5, 0, -6], "trunk": [10, -20], **ears(16)}, "out"),
        (0.86, {"root": [88, 0.14, 0, 0], "fl": [0, -0.02, 0.04], "fr": [0, -0.02, 0.05], "hl": [0, 0.02, 0.04], "hr": [0, 0.02, 0.05],
                "neck": [-6], "head": [-10], "trunk": [20, 0], **ears(-16), "tail": [-10, 20]}, "in"),
        (0.96, {"root": [84, 0.14, 0, 0], "fl": [0, -0.02, 0.05], "fr": [0, -0.02, 0.06], "hl": [0, 0.02, 0.05], "hr": [0, 0.02, 0.06],
                "neck": [-4], "head": [-6], "trunk": [30, 0], **ears(10), "tail": [-6, 24]}, "out"),
        (1.2, {"root": [88, 0.14, 0, 0], "fl": [0, -0.03, 0.06], "fr": [0, -0.03, 0.07], "hl": [0, 0.03, 0.06], "hr": [0, 0.03, 0.07],
               "neck": [-8], "head": [-14], "trunk": [24, 0], **ears(-8), "tail": [-10, 25]}, "in")]),
}

WINS = {
    "win_trumpet": ("Victory trumpet", "Throws its trunk straight up, ears spread, and trumpets at the sky.", 1.6, [
        (0.0, {}),
        (0.26, {"body": [-0.006, -0.008, -2], "neck": [-4], "head": [-6], "trunk": [40, 0], **ears(-8)}, "out"),
        (0.62, {"body": [-0.02, 0.01, 8], "spine": [5], "neck": [12], "head": [20], "trunk": [170, 0], **ears(44), "tail": [20]}, "out"),
        (1.0, {"body": [-0.02, 0.012, 9], "spine": [5], "neck": [13, 5], "head": [22, 6], "trunk": [176, 10], **ears(36), "tail": [22, 10]}),
        (1.28, {"body": [-0.006, 0.002, 3], "neck": [5], "head": [8], "trunk": [70, 0], **ears(14), "tail": [8]}, "in"),
        (1.6, {"body": [0, 0.004, 3], "spine": [2], "neck": [6], "head": [6], "trunk": [20, 0], **ears(12)}, "out")]),
    "win_rear": ("Rear and stamp", "Rears with its forefeet pawing the air, then stamps them down one after the other.", 1.6, [
        (0.0, {}),
        (0.28, {"body": [-0.01, -0.016, -3], "neck": [-6], "head": [-6], "trunk": [20, 0], **ears(-8)}, "out"),
        (0.60, {"body": [-0.04, 0.03, 18], "spine": [6], **UP, "neck": [8], "head": [12], "trunk": [120, 0], **ears(36), "tail": [24]}, "out"),
        (0.86, {"body": [-0.04, 0.032, 19], "spine": [6], "carry": [1, 1, 0, 0], "fl": [0, 0.01, 0.07], "fr": [0, 0, 0.05], "neck": [9], "head": [14], "trunk": [130, 8], **ears(40), "tail": [26, 8]}),
        (1.02, {"body": [0.01, -0.012, 2, 0, 3], "carry": [0, 1, 0, 0], "fl": [0, 0.04, 0], "fr": [0, 0.02, 0.05], "head": [2], "trunk": [50, 0], **ears(10), "tail": [16]}, "in"),
        (1.16, {"body": [0.016, -0.02, -4], "fl": [0, 0.04, 0], "fr": [0, 0.04, 0], "neck": [-4], "head": [-4], "trunk": [14, 0], **ears(-10), "tail": [26]}, "in"),
        (1.6, {"body": [0.01, 0.004, 3], "spine": [2], "fl": [0, 0.04, 0], "fr": [0, 0.04, 0], "neck": [6], "head": [6], "trunk": [20, 0], **ears(12)}, "out")]),
    "win_salute": ("Salute", "Lifts its trunk in a slow S, fans its ears once, and bows its head.", 1.6, [
        (0.0, {}),
        (0.40, {"body": [0, 0.006, 4], "spine": [3], "neck": [8], "head": [10], "trunk": [130, 0], **ears(30)}, "out"),
        (0.80, {"body": [0, 0.006, 4], "spine": [3], "neck": [8, 6], "head": [10, 8], "trunk": [140, 16], **ears(-6), "tail": [0, 14]}),
        (1.20, {"body": [0.006, -0.008, -4], "neck": [-8], "head": [-10], "trunk": [50, 0], **ears(26), "tail": [0, -10]}, "in"),
        (1.6, {"body": [0, 0.004, 3], "spine": [2], "neck": [6], "head": [6], "trunk": [20, 0], **ears(12)}, "out")]),
}

CLIPS = {
    "idle_sway": ("Sway", "idle", "Its weight goes from side to side, ears fanning slowly, trunk swinging like a pendulum.", LOOP, idle_sway, True),
    "idle_dust": ("Dust bath", "idle", "Reaches its trunk to the ground, then throws it up and back over its shoulder.", LOOP, idle_dust, True),
    "idle_trumpet": ("Trumpet", "idle", "Stands easy; once a loop it lifts head and trunk and trumpets, ears spread wide.", LOOP, idle_trumpet, True),
    "walk_amble": ("Amble", "run", "The game's pace: back foot then front foot of one side, the head nodding, trunk and ears swinging.", 1.0, walk_amble, True),
    "run_charge": ("Charge", "run", "The amble at twice the beat, ears spread wide, trunk tucked, head low.", 0.6, run_charge, True),
    "run_march": ("March", "run", "A parade march: each forefoot lifted high and set down with weight, trunk held up.", 0.9, run_march, True),
}
for kind, table in (("attack", ATTACKS), ("power", POWERS), ("hit", HITS), ("fall", FALLS), ("win", WINS)):
    for k, (name, desc, secs, keys) in table.items():
        CLIPS[k] = (name, kind, desc, secs, rp.keyed(keys), False)
