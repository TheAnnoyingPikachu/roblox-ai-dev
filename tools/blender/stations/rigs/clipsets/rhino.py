"""The rhinos' own clips: heavy, head-first, horn-led. Lengths and contact times are the game's (idle loop 4.8 s,
attack 0.95 s with the blow at 0.44, power 1.6 s with the blow at 0.92, hit 0.4 s, fall 1.2 s).
Each one-shot is keyed in four beats: anticipation (eases out into a held wind-up), commit (eases in, so the blow
lands at full speed), impact (a short overshoot past the pose), follow-through (settles; the tail is on a spring)."""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import rigpose as rp
from clipsets.quad import cyc, gait, span, TAU

SPRING = (3.0, 0.3)  # a short, stiff tail: quick to swing, quick to settle
LOOP = 4.8


# --- idles ----------------------------------------------------------------------------------------------------------
def idle_paw(t):
    w = span(t, 1.2, 3.6)
    ph = TAU * (t % LOOP - 1.2) / 1.2  # two scrapes
    return {"body": [0.006 * w, 0.003 * cyc(t, 2.4), -2.5 * w], "spine": [1.2 * cyc(t, 2.4)],
            "neck": [-9 * w, 3 * cyc(t, 4.8)], "head": [-10 * w + 3 * w * math.sin(ph), 4 * cyc(t, 4.8, 0.2)],
            "fr": [0, 0.04 * math.sin(ph) * w, 0.028 * max(0.0, math.cos(ph)) * w],
            "tail": [10 * w, 14 * cyc(t, 1.2) * w, 0]}


def idle_whet(t):
    w = span(t, 0.6, 4.0)
    sw = math.sin(TAU * (t % LOOP - 0.6) / 1.1333)  # three sweeps
    return {"body": [0.004 * w, 0.003 * cyc(t, 2.4) - 0.006 * w, -3 * w], "spine": [1.2 * cyc(t, 2.4), 3 * sw * w],
            "neck": [-13 * w, 9 * sw * w], "head": [-12 * w, 16 * sw * w, 5 * sw * w], "tail": [4, 10 * cyc(t, 2.4), 0]}


def idle_guard(t):
    look, snort = cyc(t, 4.8), span(t, 3.0, 3.7)
    return {"body": [0, 0.003 * cyc(t, 2.4), snort, 0, 1.2 * look, 0.006 * look], "spine": [1.5 * cyc(t, 2.4)],
            "neck": [2 + 4 * snort, 12 * look], "head": [2 + 8 * snort, 10 * cyc(t, 4.8, -0.06)],
            "tail": [6, 16 * cyc(t, 1.6), 4]}


# --- runs -----------------------------------------------------------------------------------------------------------
def run_charge(t):  # a gallop with the head down and the horn out in front, tail up stiff
    return gait(t, 0.56, {"hl": 0.0, "hr": 0.12, "fl": 0.5, "fr": 0.62}, 0.4, 0.075, 0.055,
                lambda c: {"body": [0, 0.012 + 0.012 * math.cos(TAU * c), -3 + 3.5 * math.sin(TAU * c)],
                           "spine": [4 * math.sin(TAU * c + 0.6)], "neck": [-9 - 3 * math.sin(TAU * c)],
                           "head": [-9 + 3 * math.sin(TAU * c + 0.4)], "tail": [28, 6 * math.sin(TAU * c), -6]})


def run_trot(t):  # a rhino's working pace: diagonal pairs, the back level, the head nodding
    return gait(t, 0.5, {"hl": 0.0, "fr": 0.02, "hr": 0.5, "fl": 0.52}, 0.46, 0.06, 0.04,
                lambda c: {"body": [0, 0.01 * abs(math.cos(TAU * c)), 0, 0, 2 * math.sin(TAU * c)],
                           "neck": [-3 + 1.5 * math.cos(2 * TAU * c)], "head": [-2 + 2 * math.cos(2 * TAU * c + 0.5), -2 * math.sin(TAU * c)],
                           "tail": [14, 10 * math.sin(TAU * c), 4]})


def walk_heavy(t):  # the game's pace (about 0.4 of its length a second): four beats, back left, front left, back right,
    # front right, each foot down for 62 % of the stride; it rolls onto the planted side, dips at each footfall, its
    # head nods against the dip and its tail swishes
    return gait(t, 0.75, {"hl": 0.0, "fl": 0.25, "hr": 0.5, "fr": 0.75}, 0.62, 0.09, 0.042,
                lambda c: {"body": [0, -0.003 + 0.005 * math.cos(2 * TAU * c + 0.5), 0.8 * math.sin(2 * TAU * c), 1.5 * math.sin(TAU * c + 0.4),
                                    2.2 * math.sin(TAU * c + 0.4), 0.005 * math.sin(TAU * c + 0.4)],
                           "spine": [0, 2.5 * math.sin(TAU * c + 1.2)], "neck": [-4 + 2 * math.cos(2 * TAU * c + 0.9), -1.5 * math.sin(TAU * c + 0.4)],
                           "head": [-2 + 2.5 * math.cos(2 * TAU * c + 1.5), -2 * math.sin(TAU * c + 0.4)],
                           "tail": [6, 12 * math.sin(TAU * c), 4]})


def run_canter(t):  # a rolling three-beat canter: the whole body rocks like a boat
    return gait(t, 0.66, {"hl": 0.0, "hr": 0.3, "fl": 0.33, "fr": 0.62}, 0.45, 0.07, 0.05,
                lambda c: {"body": [0, 0.014 + 0.012 * math.cos(TAU * c + 0.4), 4.5 * math.sin(TAU * c)],
                           "spine": [3 * math.sin(TAU * c + 0.5)], "neck": [-4 - 4 * math.sin(TAU * c)],
                           "head": [-3 + 3 * math.sin(TAU * c + 0.5)], "tail": [18, 8 * math.sin(TAU * c), 0]})


# --- attacks (the blow at 0.44) ------------------------------------------------------------------------------------------
ATTACKS = {
    "attack_gore": ("Horn gore", "Rocks back with its head low, then drives forward and rips its horn up through the target.", 0.95, [
        (0.0, {}),
        (0.18, {"body": [-0.035, -0.012, -4], "neck": [-13], "head": [-15], "tail": [18], "fr": [0, -0.02, 0]}, "out"),
        (0.30, {"body": [-0.04, -0.014, -5], "neck": [-15], "head": [-17], "tail": [22], "fr": [0, -0.02, 0]}),
        (0.44, {"body": [0.06, 0.004, 6], "spine": [4], "neck": [15], "head": [24], "fl": [0, 0.05, 0], "fr": [0, 0.04, 0], "tail": [30, 0, -8]}, "in"),
        (0.52, {"body": [0.065, 0.006, 7], "spine": [5], "neck": [18], "head": [31], "fl": [0, 0.05, 0], "fr": [0, 0.04, 0], "tail": [34, 0, -10]}, "out"),
        (0.72, {"body": [0.03, 0, 1], "neck": [4], "head": [5], "fl": [0, 0.025, 0], "fr": [0, 0.02, 0], "tail": [10]}),
        (0.95, {})]),
    "attack_toss": ("Horn toss", "Scoops its horn under the target and heaves its head and forefeet up, flinging it skyward.", 0.95, [
        (0.0, {}),
        (0.16, {"body": [0, -0.022, -7], "neck": [-17], "head": [-20], "tail": [14]}, "out"),
        (0.30, {"body": [0.02, -0.026, -8], "neck": [-19], "head": [-24], "tail": [18]}),
        (0.44, {"body": [0.03, 0.018, 13], "spine": [6], "carry": [1, 1, 0, 0], "fl": [0, 0.01, 0.03], "fr": [0, 0.02, 0.045], "neck": [18], "head": [30], "tail": [32, 0, -10]}, "in"),
        (0.53, {"body": [0.03, 0.022, 15], "spine": [7], "carry": [1, 1, 0, 0], "fl": [0, 0.01, 0.035], "fr": [0, 0.02, 0.05], "neck": [20], "head": [37], "tail": [36, 0, -12]}, "out"),
        (0.70, {"body": [0.03, -0.012, -3], "fl": [0, 0.03, 0], "fr": [0, 0.03, 0], "neck": [-4], "head": [2], "tail": [12]}, "in"),
        (0.95, {})]),
    "attack_slam": ("Shoulder slam", "Sidesteps to load its weight, then throws its armoured shoulder into the target.", 0.95, [
        (0.0, {}),
        (0.18, {"body": [-0.01, -0.01, 0, 9, -4, -0.03], "head": [0, 10], "tail": [10, -20]}, "out"),
        (0.30, {"body": [-0.012, -0.012, 0, 11, -5, -0.035], "head": [0, 12], "tail": [10, -24]}),
        (0.44, {"body": [0.04, 0, 0, -15, 9, 0.065], "spine": [0, -6], "head": [-5, -12, 6], "fl": [0.05, 0.03, 0], "hl": [0.03, 0.01, 0], "tail": [14, 30]}, "in"),
        (0.52, {"body": [0.042, 0.002, 0, -17, 10, 0.07], "spine": [0, -7], "head": [-6, -15, 8], "fl": [0.05, 0.03, 0], "hl": [0.03, 0.01, 0], "tail": [14, 36]}, "out"),
        (0.95, {})]),
}

# --- power moves (the blow at 0.92) --------------------------------------------------------------------------------------
POWERS = {
    "power_quake": ("Crystal quake", "Coils, rears up onto its hind legs and crashes both forefeet into the ground.", 1.6, [
        (0.0, {}),
        (0.28, {"body": [-0.02, -0.03, -4], "neck": [-8], "head": [-8], "tail": [-6]}, "out"),
        (0.60, {"body": [-0.035, 0.02, 25], "spine": [8], "carry": [1, 1, 0, 0], "fl": [0, 0, 0.045], "fr": [0, -0.015, 0.03], "neck": [9], "head": [12], "tail": [30]}, "out"),
        (0.80, {"body": [-0.035, 0.024, 28], "spine": [9], "carry": [1, 1, 0, 0], "fl": [0, -0.01, 0.04], "fr": [0, 0.005, 0.05], "neck": [11], "head": [17], "tail": [34, 8]}),
        (0.92, {"body": [0.03, -0.032, -8], "spine": [-5], "fl": [0, 0.05, 0], "fr": [0, 0.05, 0], "neck": [-11], "head": [-9], "tail": [42, 0, 10]}, "in"),
        (1.02, {"body": [0.03, -0.016, -3], "spine": [-2], "fl": [0, 0.05, 0], "fr": [0, 0.05, 0], "neck": [-4], "head": [-2], "tail": [24]}, "out"),
        (1.30, {"body": [0.015, -0.004, 0], "fl": [0, 0.025, 0], "fr": [0, 0.025, 0], "head": [3]}),
        (1.6, {})]),
    "power_charge": ("Avalanche charge", "Paws the ground twice, coils back, then explodes forward and sweeps its horn across.", 1.6, [
        (0.0, {}),
        (0.16, {"body": [-0.01, -0.008, -3], "neck": [-10], "head": [-12], "fr": [0, 0.03, 0.03]}, "out"),
        (0.28, {"body": [-0.015, -0.01, -4], "neck": [-12], "head": [-14], "fr": [0, -0.035, 0, 1]}, "in"),
        (0.40, {"body": [-0.02, -0.01, -4], "neck": [-12], "head": [-13], "fr": [0, 0.03, 0.03]}, "out"),
        (0.52, {"body": [-0.03, -0.014, -5], "neck": [-14], "head": [-16], "fr": [0, -0.035, 0, 1], "tail": [20]}, "in"),
        (0.68, {"body": [-0.05, -0.02, -6], "neck": [-16], "head": [-18, -14], "fr": [0, -0.02, 0], "tail": [28]}, "out"),
        (0.92, {"body": [0.11, 0, 4], "spine": [4, 6], "neck": [14, 8], "head": [24, 14], "fl": [0, 0.1, 0], "fr": [0, 0.085, 0], "hl": [0, 0.075, 0], "hr": [0, 0.09, 0], "tail": [36, 0, -10]}, "in"),
        (1.02, {"body": [0.115, 0.004, 5], "spine": [5, 9], "neck": [17, 12], "head": [31, 22], "fl": [0, 0.1, 0], "fr": [0, 0.085, 0], "hl": [0, 0.075, 0], "hr": [0, 0.09, 0], "tail": [40]}, "out"),
        (1.30, {"body": [0.06, 0, 1], "head": [6, 6], "fl": [0, 0.05, 0], "fr": [0, 0.04, 0], "hl": [0, 0.04, 0], "hr": [0, 0.045, 0]}),
        (1.6, {})]),
    "power_stomp": ("Earthshaker", "Stamps its left forefoot, then its right, then rears and brings both down together.", 1.6, [
        (0.0, {}),
        (0.20, {"body": [0, 0.004, 2, 0, 4, -0.01], "fl": [0, 0.01, 0.06], "head": [4, -6]}, "out"),
        (0.32, {"body": [0, -0.012, -2, 0, -2, 0.004], "fl": [0, 0.02, 0], "head": [-6, -4]}, "in"),
        (0.50, {"body": [0, 0.004, 2, 0, -4, 0.01], "fl": [0, 0.02, 0], "fr": [0, 0.01, 0.06], "head": [4, 6]}, "out"),
        (0.62, {"body": [0, -0.012, -2, 0, 2, -0.004], "fl": [0, 0.02, 0], "fr": [0, 0.02, 0], "head": [-6, 4]}, "in"),
        (0.80, {"body": [-0.03, 0.02, 22], "spine": [7], "carry": [1, 1, 0, 0], "fl": [0, 0, 0.04], "fr": [0, 0, 0.04], "neck": [8], "head": [14], "tail": [30]}, "out"),
        (0.92, {"body": [0.02, -0.034, -9], "spine": [-5], "fl": [0, 0.045, 0], "fr": [0, 0.045, 0], "neck": [-12], "head": [-10], "tail": [40, 0, 10]}, "in"),
        (1.03, {"body": [0.02, -0.016, -3], "fl": [0, 0.045, 0], "fr": [0, 0.045, 0], "head": [-2], "tail": [20]}, "out"),
        (1.6, {})]),
    # the Crystal Rhino's own (its spell, Prism Beam: lights circle into the horn from 0.2 s, the beam leaves it at 0.86,
    # lands at 0.92 and holds to 1.2)
    "power_prism": ("Prism beam", "Dips, then lifts its horn high as the light gathers; drives it level at the target and holds, braced, while the beam burns.", 1.6, [
        (0.0, {}),
        (0.20, {"body": [-0.008, -0.01, -2], "neck": [-6], "head": [-8]}, "out"),
        (0.55, {"body": [-0.028, 0.004, 5], "spine": [3], "neck": [12], "head": [20], "tail": [18]}, "out"),
        (0.80, {"body": [-0.04, 0.006, 7], "spine": [4], "neck": [15], "head": [26, 0, 4], "tail": [26, 6]}),
        (0.89, {"body": [0.045, -0.022, -5], "spine": [-3], "neck": [-10], "head": [-22], "tail": [40, 0, 8]}, "in"),
        (0.97, {"body": [0.034, -0.016, -3], "spine": [-2], "neck": [-8], "head": [-17], "tail": [22]}, "out"),
        (1.20, {"body": [0.03, -0.014, -3], "spine": [-2], "neck": [-8], "head": [-19], "tail": [14]}),
        (1.42, {"body": [0.01, -0.004, 0], "head": [-4], "tail": [6]}),
        (1.6, {})]),
}

HITS = {
    "hit_brace": ("Brace", "Too heavy to throw: it takes the blow with a grunt, its head jolting aside, and plants itself.", 0.4, [
        (0.0, {}),
        (0.07, {"body": [-0.02, -0.008, 2, 3, -3], "neck": [4, 6], "head": [7, 9, 5], "tail": [8, -18]}, "out"),
        (0.20, {"body": [-0.008, -0.004, -1, -1, 1], "head": [-3, -5, -3], "tail": [4, 10]}),
        (0.4, {})]),
    "hit_stagger": ("Stagger", "Knocked off line, it lurches a step sideways with its legs braced wide.", 0.4, [
        (0.0, {}),
        (0.08, {"body": [-0.012, -0.012, 0, -7, 9, 0.035], "neck": [0, -10], "head": [2, -9, 7], "fl": [0.03, 0, 0], "tail": [0, 22]}, "out"),
        (0.24, {"body": [-0.006, -0.008, 0, -3, 4, 0.02], "fl": [0.035, 0, 0], "hl": [0.02, 0, 0], "head": [0, 6, -4]}),
        (0.4, {})]),
}

FALLS = {
    "fall_crash": ("Crash", "Its forelegs buckle first and its chin hits the ground, then its hindquarters thump down.", 1.2, [
        (0.0, {}),
        (0.20, {"body": [0, 0.004, 3], "head": [8]}, "out"),
        (0.55, {"body": [0.01, -0.075, -13], "spine": [-4], "neck": [2], "head": [8], "tail": [10]}, "in"),
        (0.63, {"body": [0.01, -0.068, -11], "neck": [4], "head": [12]}, "out"),
        (0.95, {"body": [0.01, -0.105, -5, 0, 6], "spine": [-3], "neck": [5], "head": [9, 6, 8], "tail": [-10, 14]}, "in"),
        (1.2, {"body": [0.01, -0.108, -5, 0, 7], "spine": [-3], "neck": [6], "head": [11, 8, 10], "tail": [-12, 16]}, "out")]),
    "fall_topple": ("Topple", "Sways, then goes over onto its side like a felled tree, bouncing once.", 1.2, [
        (0.0, {}),
        (0.25, {"body": [0, 0, 0, 0, -5], "head": [5, 0, -6]}, "out"),
        (0.85, {"root": [88, 0.17, -0.225, 0], "fl": [0, -0.02, 0.04], "fr": [0, -0.02, 0.05], "hl": [0, 0.02, 0.04], "hr": [0, 0.02, 0.05], "neck": [-6], "head": [-10], "tail": [-10, 20]}, "in"),
        (0.95, {"root": [83, 0.17, -0.225, 0], "fl": [0, -0.02, 0.05], "fr": [0, -0.02, 0.06], "hl": [0, 0.02, 0.05], "hr": [0, 0.02, 0.06], "neck": [-4], "head": [-6], "tail": [-6, 24]}, "out"),
        (1.2, {"root": [88, 0.17, -0.225, 0], "fl": [0, -0.03, 0.06], "fr": [0, -0.03, 0.07], "hl": [0, 0.03, 0.06], "hr": [0, 0.03, 0.07], "neck": [-8], "head": [-14], "tail": [-10, 25]}, "in")]),
}

WINS = {
    "win_salute": ("Horn salute", "Dips its head, then rears and tosses its horn at the sky twice.", 1.6, [
        (0.0, {}),
        (0.28, {"body": [-0.01, -0.02, -4], "neck": [-8], "head": [-10]}, "out"),
        (0.52, {"body": [-0.02, 0.015, 16], "spine": [6], "carry": [1, 1, 0, 0], "fl": [0, 0, 0.03], "fr": [0, 0.01, 0.04], "neck": [14], "head": [28], "tail": [30]}, "in"),
        (0.74, {"body": [-0.02, 0.012, 13], "spine": [5], "carry": [1, 1, 0, 0], "fl": [0, 0.005, 0.03], "fr": [0, 0.005, 0.035], "neck": [6], "head": [10], "tail": [26]}),
        (0.94, {"body": [-0.02, 0.016, 17], "spine": [6], "carry": [1, 1, 0, 0], "fl": [0, 0.01, 0.04], "fr": [0, 0, 0.03], "neck": [15], "head": [31], "tail": [32]}, "in"),
        (1.2, {"body": [0, -0.014, -3], "fl": [0, 0.02, 0], "fr": [0, 0.02, 0], "head": [-2], "tail": [12]}, "in"),
        (1.6, {"body": [0, 0.004, 3], "spine": [3], "neck": [8], "head": [8], "fl": [0, 0.02, 0], "fr": [0, 0.02, 0], "tail": [20, 0, 10]}, "out")]),
    "win_stomp": ("Victory stomp", "Stamps each forefoot in turn with its head swinging, then stands tall and snorts.", 1.6, [
        (0.0, {}),
        (0.18, {"body": [0, 0.004, 2, 0, 4, -0.01], "fl": [0, 0.01, 0.055], "head": [6, -10]}, "out"),
        (0.30, {"body": [0, -0.01, -2, 0, -2, 0.004], "fl": [0, 0.015, 0], "head": [-5, -6]}, "in"),
        (0.50, {"body": [0, 0.004, 2, 0, -4, 0.01], "fl": [0, 0.015, 0], "fr": [0, 0.01, 0.055], "head": [6, 10]}, "out"),
        (0.62, {"body": [0, -0.01, -2, 0, 2, -0.004], "fl": [0, 0.015, 0], "fr": [0, 0.015, 0], "head": [-5, 6]}, "in"),
        (0.82, {"body": [0, 0.004, 2, 0, 4, -0.01], "fl": [0, 0.01, 0.055], "fr": [0, 0.015, 0], "head": [6, -8]}, "out"),
        (0.94, {"body": [0, -0.01, -2, 0, -2, 0.004], "fl": [0, 0.015, 0], "fr": [0, 0.015, 0], "head": [-5, -4]}, "in"),
        (1.6, {"body": [0, 0.005, 4], "spine": [3], "neck": [9], "head": [10], "fl": [0, 0.015, 0], "fr": [0, 0.015, 0], "tail": [24, 0, 10]}, "out")]),
    "win_proud": ("Proud snort", "Draws itself up, chest out and horn high, and looks slowly over its beaten foes.", 1.6, [
        (0.0, {}),
        (0.35, {"body": [0, 0.005, 4], "spine": [4], "neck": [10, -10], "head": [10, -14], "tail": [22, -10, 8]}, "out"),
        (0.95, {"body": [0, 0.006, 5], "spine": [4], "neck": [11, 10], "head": [11, 16], "tail": [24, 12, 8]}),
        (1.25, {"body": [0, 0.002, 2], "spine": [2], "neck": [4], "head": [-4], "tail": [16]}, "in"),
        (1.6, {"body": [0, 0.005, 4], "spine": [3], "neck": [9], "head": [9], "tail": [22, 0, 10]}, "over")]),
}

CLIPS = {
    "idle_paw": ("Snort and paw", "idle", "Head low, it scrapes a forefoot back through the dirt twice, tail flicking.", LOOP, idle_paw, True),
    "idle_whet": ("Horn whet", "idle", "Lowers its head and grinds its horn from side to side on the ground, then lifts it.", LOOP, idle_whet, True),
    "idle_guard": ("Sentinel", "idle", "Stands heavy and square, breathing slow, turning its head across the field; snorts once.", LOOP, idle_guard, True),
    "walk_heavy": ("Heavy walk", "run", "The game's pace: four slow beats, rolling onto each planted foot, the head nodding.", 0.75, walk_heavy, True),
    "run_charge": ("Charge", "run", "A gallop with the head down and the horn out in front, tail held stiff.", 0.56, run_charge, True),
    "run_trot": ("Heavy trot", "run", "Diagonal pairs, the back level, the head nodding with each beat.", 0.5, run_trot, True),
    "run_canter": ("Rolling canter", "run", "A three-beat canter: the whole body rocks like a boat.", 0.66, run_canter, True),
}
for kind, table in (("attack", ATTACKS), ("power", POWERS), ("hit", HITS), ("fall", FALLS), ("win", WINS)):
    for k, (name, desc, secs, keys) in table.items():
        CLIPS[k] = (name, kind, desc, secs, rp.keyed(keys), False)
