"""The shared four-legged clip options (first written on the Eternal Sun Cheetah): the fallback for any species
without a set of its own. CLIPS = {key: (name, kind, description, seconds, pose function of t, loops)}.
Poses are rigpose.py's spec; distances are in model units (an animal is about 0.96 long)."""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import rigpose as rp

TAU = math.tau


def cyc(t, period, phase=0.0):
    return math.sin(TAU * (t / period + phase))


def span(t, a, b, loop=4.8):
    """0 outside [a, b] of an idle loop, rising smoothly to 1 in its middle: a beat that happens once a loop."""
    x = t % loop
    return math.sin(math.pi * (x - a) / (b - a)) ** 2 if a < x < b else 0.0


def foot_cycle(c, start, duty, step, lift):
    """A foot's [fwd, up] at cycle position c: planted and sweeping back for `duty`, then swinging forward lifted."""
    u = (c - start) % 1
    if u < duty:
        return step - 2 * step * u / duty, 0.0
    k = (u - duty) / (1 - duty)
    e = 0.5 - 0.5 * math.cos(math.pi * k)
    return -step + 2 * step * e, lift * math.sin(math.pi * k)


def gait(t, period, starts, duty, step, lift, body):
    c = (t / period) % 1
    pose = {}
    for ft, s in starts.items():
        fw, up = foot_cycle(c, s, duty, step, lift)
        pose[ft] = [0, fw, up]
    pose.update(body(c))
    return pose


# --- idles (loops) ----------------------------------------------------------------------------------------------------
def idle_watch(t):  # 4 s
    look = math.sin(TAU * t / 4)
    return {"spine": [1.5 * cyc(t, 2)], "body": [0, 0.004 * cyc(t, 2)], "neck": [2, 18 * look],
            "head": [3 * cyc(t, 4, 0.25), 10 * look], "tail": [6, 22 * cyc(t, 2.2), 4 + 6 * cyc(t, 1.1)]}


def idle_stalk(t):  # 4 s: low, hunting
    twitch = max(0.0, cyc(t, 4)) ** 4
    return {"body": [0.01, -0.05, -5, 0, 0], "spine": [-3], "neck": [-12, 6 * cyc(t, 4, 0.1)],
            "head": [8, 4 * cyc(t, 4, 0.2)], "tail": [-6, 10 * cyc(t, 1.4) + 25 * twitch, 18 * twitch]}


def idle_proud(t):  # 4 s: chest up, a paw lifted now and then
    paw = max(0.0, math.sin(TAU * (t / 4))) ** 2
    return {"body": [0, 0.01, 5], "spine": [4], "neck": [10], "head": [6, 8 * cyc(t, 4, 0.5)],
            "fr": [0, 0.02 * paw, 0.05 * paw], "tail": [18, 14 * cyc(t, 2.4), 22]}


# --- runs (loops) -----------------------------------------------------------------------------------------------------
def run_gallop(t):  # rotary gallop, 0.6 s a stride
    return gait(t, 0.6, {"hl": 0.0, "hr": 0.1, "fl": 0.45, "fr": 0.55}, 0.38, 0.13, 0.09,
                lambda c: {"body": [0, 0.03 + 0.02 * math.cos(TAU * c), 6 * math.sin(TAU * c)],
                           "spine": [10 * math.sin(TAU * c + 0.6)], "neck": [-6 * math.sin(TAU * c)],
                           "head": [5 * math.sin(TAU * c + 0.3)], "tail": [4, 8 * math.sin(TAU * c), 10 * math.sin(TAU * c + 1)]})


def run_bound(t):  # bounding: pairs together, big spine flex (a cheetah's sprint), 0.55 s
    return gait(t, 0.55, {"hl": 0.0, "hr": 0.03, "fl": 0.5, "fr": 0.53}, 0.32, 0.14, 0.1,
                lambda c: {"body": [0, 0.04 + 0.03 * math.cos(TAU * c), 9 * math.sin(TAU * c)],
                           "spine": [13 * math.sin(TAU * c + 0.4)], "neck": [-9 * math.sin(TAU * c)],
                           "head": [8 * math.sin(TAU * c + 0.2)], "tail": [-4, 6 * math.sin(TAU * c), 16 * math.sin(TAU * c + 1.2)]})


def run_trot(t):  # a fast trot: diagonal pairs, level back, 0.5 s
    return gait(t, 0.5, {"hl": 0.0, "fr": 0.02, "hr": 0.5, "fl": 0.52}, 0.45, 0.11, 0.07,
                lambda c: {"body": [0, 0.015 * abs(math.cos(TAU * c)), 0, 0, 3 * math.sin(TAU * c)],
                           "head": [2 * math.cos(2 * TAU * c), -2 * math.sin(TAU * c)], "tail": [10, 14 * math.sin(TAU * c), 6]})


# --- one-shots -----------------------------------------------------------------------------------------------------
REST = {}
JUMP = [1, 1, 1, 1]
ATTACKS = {
    "attack_pounce": ("Sun pounce", "Sinks low and back, springs forward with all four paws off the ground, slams both forepaws down.", 1.0, [
        (0.0, REST),
        (0.25, {"body": [-0.03, -0.05, -6], "spine": [-8], "neck": [-8], "head": [6], "tail": [-10, 0, 10]}),
        (0.45, {"body": [0.10, 0.09, 12], "spine": [10], "carry": JUMP, "fl": [0, 0.06, 0.03], "fr": [0, 0.06, 0.03],
                "hl": [0, -0.05, 0.03], "hr": [0, -0.05, 0.03], "head": [-6], "tail": [20, 0, -10]}),
        (0.6, {"body": [0.12, -0.03, -10], "spine": [-6], "fl": [0, 0.15, 0], "fr": [0, 0.15, 0], "hl": [0, 0.06, 0], "hr": [0, 0.06, 0],
               "neck": [-10], "head": [-8], "tail": [30, 0, 10]}),
        (0.8, {"body": [0.1, -0.02, -6], "fl": [0, 0.15, 0], "fr": [0, 0.15, 0], "hl": [0, 0.06, 0], "hr": [0, 0.06, 0], "tail": [15, 15, 5]}),
        (1.0, REST)]),
    "attack_swipe": ("Claw swipe", "Rears a little onto its hind legs and rakes a forepaw across, head following through.", 0.9, [
        (0.0, REST),
        (0.25, {"body": [-0.02, 0.02, 14], "carry": [1, 0, 0, 0], "fl": [0.0, 0.02, 0.02], "fr": [-0.06, 0.1, 0.13], "head": [-4, 15], "tail": [10, -15]}),
        (0.45, {"body": [0.02, 0.01, 10, -10], "carry": [1, 0, 0, 0], "fr": [0.1, 0.12, 0.05], "head": [-8, -20], "tail": [10, 25]}),
        (0.6, {"body": [0.01, 0, 4, -6], "fr": [0.06, 0.05, 0], "head": [-4, -10], "tail": [8, 15]}),
        (0.9, REST)]),
    "attack_bite": ("Lunge bite", "Drops its head and lunges low, snaps its jaws up at the end, tail flung straight up.", 0.8, [
        (0.0, REST),
        (0.2, {"body": [-0.02, -0.02, -3], "neck": [-6], "head": [8], "tail": [-6]}),
        (0.4, {"body": [0.07, -0.025, -6], "spine": [-4], "neck": [-14], "head": [-4], "fl": [0, 0.05, 0], "tail": [35, 0, 10]}),
        (0.5, {"body": [0.07, -0.015, -3], "neck": [4], "head": [18], "fl": [0, 0.05, 0], "tail": [30, 10, 10]}),
        (0.8, REST)]),
}
POWERS = {
    "power_rear": ("Solar roar", "Rears high onto its hind legs, forepaws raised, and roars at the sky, then crashes down.", 1.6, [
        (0.0, REST),
        (0.3, {"body": [-0.02, -0.03, -4], "neck": [-6], "tail": [-8]}),
        (0.6, {"body": [-0.03, 0.03, 25], "spine": [8], "carry": [1, 1, 0, 0], "fl": [0, -0.03, 0.06], "fr": [0, -0.01, 0.04],
               "neck": [14], "head": [26], "tail": [30, 0, 10]}),
        (1.0, {"body": [-0.03, 0.03, 26], "spine": [10], "carry": [1, 1, 0, 0], "fl": [0, -0.02, 0.07], "fr": [0, -0.03, 0.05],
               "neck": [18], "head": [30], "tail": [35, 10, 10]}),
        (1.2, {"body": [0.04, -0.03, -8], "fl": [0, 0.07, 0], "fr": [0, 0.07, 0], "neck": [-10], "head": [-6], "tail": [20]}),
        (1.6, REST)]),
    "power_spin": ("Sunwheel leap", "Springs straight up and spins a full barrel roll in the air, landing in a crouch.", 1.4, [
        (0.0, REST),
        (0.25, {"body": [0, -0.05, -2], "spine": [-6], "tail": [-10]}),
        (0.45, {"root": [0, 0, 0.25, 0.22], "carry": JUMP, "fl": [0, 0.0, 0.07], "fr": [0, 0.0, 0.07], "hl": [0, 0, 0.07], "hr": [0, 0, 0.07],
                "tail": [10, 0, 20]}),
        (0.8, {"root": [360, 0, 0.25, 0.22], "carry": JUMP, "fl": [0, 0.0, 0.07], "fr": [0, 0.0, 0.07], "hl": [0, 0, 0.07], "hr": [0, 0, 0.07],
               "tail": [10, 0, 20]}),
        (1.0, {"root": [360, 0, 0.25, 0], "body": [0, -0.06, -4], "spine": [-6], "tail": [20]}),
        (1.4, {"root": [360, 0, 0.25, 0]})]),
    "power_slam": ("Dawn crash", "Crouches, leaps high with its forelegs raised, and crashes both forepaws into the ground.", 1.3, [
        (0.0, REST),
        (0.3, {"body": [-0.02, -0.06, -6], "spine": [-10], "neck": [-10], "tail": [-12]}),
        (0.6, {"body": [0.04, 0.16, 24], "spine": [12], "carry": JUMP, "fl": [0, -0.02, 0.08], "fr": [0, -0.02, 0.08],
               "hl": [0, -0.04, 0.02], "hr": [0, -0.04, 0.02], "neck": [12], "head": [10], "tail": [25, 0, -10]}),
        (0.8, {"body": [0.08, -0.04, -14], "spine": [-10], "fl": [0, 0.1, 0], "fr": [0, 0.1, 0], "hl": [0, 0.05, 0], "hr": [0, 0.05, 0],
               "neck": [-14], "head": [-6], "tail": [35, 0, 12]}),
        (1.0, {"body": [0.06, -0.035, -10], "fl": [0, 0.1, 0], "fr": [0, 0.1, 0], "hl": [0, 0.05, 0], "hr": [0, 0.05, 0], "tail": [25]}),
        (1.3, REST)]),
}
HITS = {
    "hit_flinch": ("Flinch", "Jolts back from the blow, head snapping up and away, then braces.", 0.5, [
        (0.0, REST), (0.1, {"body": [-0.04, 0.01, 6, 8, -6], "neck": [8, 10], "head": [10, 12], "tail": [10, -20]}),
        (0.3, {"body": [-0.02, -0.01, -2, 4], "head": [-4, 4], "tail": [4, -8]}), (0.5, REST)]),
    "hit_stagger": ("Stagger", "Knocked sideways, it stumbles a step with its legs braced wide and shakes it off.", 0.7, [
        (0.0, REST), (0.12, {"body": [0, -0.01, 0, -10, 14, 0.04], "neck": [0, -14], "head": [0, -10, 8], "fl": [0.03, 0, 0.03], "tail": [0, 25]}),
        (0.35, {"body": [0, -0.01, 0, -4, 6, 0.03], "fl": [0.04, 0, 0], "hl": [0.03, 0, 0], "head": [0, 8, -6], "tail": [0, -15]}),
        (0.7, REST)]),
}
FALLS = {
    "fall_slump": ("Slump", "Its legs fold under it and it sinks onto its belly, head drooping to the ground.", 1.2, [
        (0.0, REST), (0.25, {"body": [0, -0.02, 4], "head": [8]}),
        (0.8, {"body": [0, -0.11, -4], "spine": [-4], "neck": [-22], "head": [-14], "tail": [-10, 10]}),
        (1.2, {"body": [0, -0.12, -6], "spine": [-4], "neck": [-30], "head": [-18, 10, 8], "tail": [-12, 20]})]),
    "fall_topple": ("Topple", "Sways, then topples onto its side, legs folding as it lands.", 1.2, [
        (0.0, REST), (0.3, {"body": [0, 0, 0, 0, -6], "head": [6, 0, -6]}),
        (0.9, {"root": [84, 0.1, 0, 0], "fl": [0, -0.02, 0.05], "fr": [0, -0.02, 0.06], "hl": [0, 0.02, 0.05], "hr": [0, 0.02, 0.06],
               "neck": [-6, 0], "head": [-10, 0, 0], "tail": [-10, 20]}),
        (1.2, {"root": [88, 0.1, 0, 0], "fl": [0, -0.03, 0.07], "fr": [0, -0.03, 0.08], "hl": [0, 0.03, 0.07], "hr": [0, 0.03, 0.08],
               "neck": [-8, 0], "head": [-14, 0, 0], "tail": [-10, 25]})]),
}
WINS = {
    "win_sunrise": ("Sunrise salute", "Rears up on its hind legs and paws at the air twice, tail held high.", 1.6, [
        (0.0, REST),
        (0.4, {"body": [-0.03, 0.03, 24], "spine": [8], "carry": [1, 1, 0, 0], "fl": [0, 0.02, 0.06], "fr": [0, -0.03, 0.02], "neck": [10], "head": [14], "tail": [35, 0, 20]}),
        (0.7, {"body": [-0.03, 0.03, 25], "spine": [8], "carry": [1, 1, 0, 0], "fl": [0, -0.03, 0.02], "fr": [0, 0.02, 0.07], "neck": [12], "head": [18], "tail": [35, 15, 20]}),
        (1.0, {"body": [-0.03, 0.03, 24], "spine": [8], "carry": [1, 1, 0, 0], "fl": [0, 0.02, 0.06], "fr": [0, -0.03, 0.02], "neck": [10], "head": [14], "tail": [35, -15, 20]}),
        (1.6, REST)]),
    "win_hop": ("Victory spin", "Hops and turns a full circle on the spot, landing proud with its chest up.", 1.4, [
        (0.0, REST),
        (0.2, {"body": [0, -0.04, -2], "tail": [-8]}),
        (0.4, {"root": [0, 0, 0, 0.1, 90], "carry": JUMP, "fl": [0, 0, 0.04], "fr": [0, 0, 0.04], "hl": [0, 0, 0.03], "hr": [0, 0, 0.03], "tail": [20, 20, 10]}),
        (0.7, {"root": [0, 0, 0, 0.1, 270], "carry": JUMP, "fl": [0, 0, 0.04], "fr": [0, 0, 0.04], "hl": [0, 0, 0.03], "hr": [0, 0, 0.03], "tail": [20, 20, 10]}),
        (0.9, {"root": [0, 0, 0, 0, 360], "body": [0, -0.03, 0]}),
        (1.4, {"root": [0, 0, 0, 0, 360], "body": [0, 0.01, 8], "spine": [6], "neck": [10], "head": [8], "tail": [30, 0, 25]})]),
    "win_stretch": ("Lazy stretch", "A long cat stretch: forepaws reach far forward with its chest low and rear up, then it stands proud.", 1.8, [
        (0.0, REST),
        (0.6, {"body": [0.02, -0.02, -11], "spine": [-10], "fl": [0, 0.12, 0], "fr": [0, 0.12, 0], "neck": [8], "head": [12], "tail": [40, 0, 20]}),
        (1.1, {"body": [0.02, -0.02, -11], "spine": [-10], "fl": [0, 0.12, 0], "fr": [0, 0.12, 0], "neck": [10], "head": [14], "tail": [40, 15, 20]}),
        (1.8, {"body": [0, 0.01, 6], "spine": [4], "neck": [10], "head": [8], "tail": [25, 0, 20]})]),
}

CLIPS = {
    "idle_watch": ("Sun watch", "idle", "Calm breathing, looks slowly round the horizon, tail swaying.", 4.0, idle_watch, True),
    "idle_stalk": ("Stalk", "idle", "Low and still like a hunter, head forward, tail tip twitching.", 4.0, idle_stalk, True),
    "idle_proud": ("Proud stance", "idle", "Chest up, tail high and curled, lifts a forepaw now and then.", 4.0, idle_proud, True),
    "run_gallop": ("Gallop", "run", "A rotary gallop: hind feet then forefeet, the back rocking.", 0.6, run_gallop, True),
    "run_bound": ("Sprint bound", "run", "A cheetah's sprint: the spine coils and stretches, pairs of feet together.", 0.55, run_bound, True),
    "run_trot": ("Fast trot", "run", "Diagonal pairs, back level, steady and light.", 0.5, run_trot, True),
}
for kind, table in (("attack", ATTACKS), ("power", POWERS), ("hit", HITS), ("fall", FALLS), ("win", WINS)):
    for k, (name, desc, secs, keys) in table.items():
        CLIPS[k] = (name, kind, desc, secs, rp.keyed(keys), False)

