"""The meerkats' own clips: an upright animal, a sentry and a digger, quick and twitchy. Lengths and blow times are the
game's (idle loop 4.8 s, attack 0.95 s with the blow at 0.44, power 1.6 s with the blow at 0.92, hit 0.4 s, fall
1.2 s, win 1.6 s). It stands on its hind legs ("hl", "hr": planted); "fl" and "fr" are its hands, [side, forward, up]
from where they hang, and always ride with the body; a positive body pitch leans it back."""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import rigpose as rp
from clipsets.quad import cyc, gait, span, TAU

SPRING = (2.8, 0.3)  # a thin stiff tail it props itself on: it barely lags
LOOP = 4.8
ARMS, JUMP = [1, 1, 0, 0], [1, 1, 1, 1]


def U(**pose):
    """A key: the hands ride with the body unless the key says all four leave the ground."""
    pose.setdefault("carry", ARMS)
    return pose


# --- idles ----------------------------------------------------------------------------------------------------------
def idle_sentry(t):  # on watch: bolt upright, the head snapping from point to point; now and then it stretches taller
    look = math.copysign(abs(cyc(t, 4.8)) ** 0.3, cyc(t, 4.8))
    tall = span(t, 2.9, 4.1)
    return {"body": [0, 0.003 * cyc(t, 1.6) + 0.012 * tall, 2 * tall], "spine": [1.5 * cyc(t, 1.6) + 3 * tall, 4 * look],
            "neck": [4 * tall, 20 * look], "head": [2 + 4 * tall, 22 * look], "fl": [0, 0.01 * tall, 0.02 * tall], "fr": [0, 0.01 * tall, 0.02 * tall],
            "tail": [0, 6 * cyc(t, 2.4), 0]}


def idle_scratch(t):  # scratches its belly with one hand, looking about, then shakes the hand out
    s = span(t, 0.8, 3.2)
    rub = math.sin(TAU * t / 0.28)
    return {"body": [0, 0.003 * cyc(t, 1.6), -3 * s, 0, 2 * s], "spine": [-4 * s, 5 * cyc(t, 4.8)], "neck": [-6 * s, 12 * cyc(t, 4.8, 0.1)],
            "head": [-8 * s, 10 * cyc(t, 4.8, 0.15)], "fr": [0.2 * s, 0.07 * s, -0.02 * s + 0.02 * rub * s], "fl": [0, 0, 0.01 * cyc(t, 1.6)],
            "tail": [0, 8 * cyc(t, 2.4), 0]}


def idle_peek(t):  # ducks down small, then pops up as tall as it can go and scans the sky
    d = span(t, 0.4, 1.8)
    u = span(t, 1.9, 4.2)
    return {"drop": [0.3 * d], "body": [0, 0.003 * cyc(t, 1.6) + 0.016 * u, -8 * d + 5 * u], "spine": [-10 * d + 5 * u], "neck": [-6 * d + 10 * u, 16 * u * cyc(t, 1.4)],
            "head": [10 * d + 14 * u, 14 * u * cyc(t, 1.4, 0.1)], "fl": [-0.04 * d, 0.05 * d, 0.06 * d + 0.02 * u], "fr": [0.04 * d, 0.05 * d, 0.06 * d + 0.02 * u],
            "tail": [0, 8 * cyc(t, 2.4), 0]}


# --- walks and runs -------------------------------------------------------------------------------------------------
def swing(c, reach, lift=0.0):
    """The hands of a two-legged gait: each swings against the leg of its side."""
    return {"fl": [0, -reach * math.sin(TAU * c), lift * abs(math.sin(TAU * c))], "fr": [0, reach * math.sin(TAU * c), lift * abs(math.sin(TAU * c))]}


def walk_scurry(t):  # the game's pace: quick short steps, leaning into it, hands pumping small, the tail trailing
    return gait(t, 0.42, {"hl": 0.0, "hr": 0.5}, 0.58, 0.045, 0.02,
                lambda c: {"body": [0, 0.004 * math.cos(2 * TAU * c), -7, 3 * math.sin(TAU * c), 2.5 * math.sin(TAU * c), 0.004 * math.sin(TAU * c)],
                           "spine": [-2, -4 * math.sin(TAU * c)], "neck": [4], "head": [6, 2 * math.sin(TAU * c)], **swing(c, 0.035, 0.008),
                           "tail": [-4, 8 * math.sin(TAU * c + 0.8), 0]})


def run_dash(t):  # flat out: bent well forward, long strides, hands tucked
    return gait(t, 0.34, {"hl": 0.0, "hr": 0.5}, 0.42, 0.06, 0.035,
                lambda c: {"body": [0, 0.01 * math.cos(2 * TAU * c), -18, 4 * math.sin(TAU * c), 3 * math.sin(TAU * c)],
                           "spine": [-6, -5 * math.sin(TAU * c)], "neck": [10], "head": [14], "fl": [-0.03, 0.06 - 0.03 * math.sin(TAU * c), 0.05],
                           "fr": [0.03, 0.06 + 0.03 * math.sin(TAU * c), 0.05], "tail": [14, 8 * math.sin(TAU * c + 0.8), 0]})


def run_hop(t):  # bounding: both feet together, the whole body a spring
    c = (t / 0.4) % 1
    up = max(0.0, math.sin(TAU * c))
    return {"carry": [1, 1, up > 0.02, up > 0.02], "body": [0, 0.05 * up - 0.02 * max(0.0, -math.sin(TAU * c)), -8 + 6 * math.cos(TAU * c)],
            "spine": [-4 + 4 * math.cos(TAU * c)], "neck": [4], "head": [6 - 4 * math.cos(TAU * c)], "hl": [0, 0, 0.02 * up], "hr": [0, 0, 0.02 * up],
            "fl": [0, 0.03 * math.cos(TAU * c), 0.04 * up], "fr": [0, 0.03 * math.cos(TAU * c), 0.04 * up], "tail": [10 * up, 0, 0]}


# --- one-shots -----------------------------------------------------------------------------------------------------
ATTACKS = {
    "attack_claw": ("Claw rake", "Winds its right hand back over its shoulder and rakes it down and across.", 0.95, [
        (0.0, U()),
        (0.22, U(body=[-0.015, 0.004, 5, 10], spine=[3, 10], neck=[0, -8], head=[0, -10], fr=[-0.06, -0.05, 0.2], fl=[0, 0.03, 0.03], tail=[0, -12]), "out"),
        (0.44, U(body=[0.03, -0.012, -10, -14], spine=[-6, -14], neck=[0, 8], head=[4, 12], fr=[0.22, 0.16, 0.0], fl=[0, -0.02, 0.02], hr=[0, 0.03, 0], tail=[0, 20]), "in"),
        (0.52, U(body=[0.03, -0.008, -8, -17], spine=[-5, -16], head=[4, 14], fr=[0.25, 0.12, -0.03], fl=[0, -0.02, 0.02], hr=[0, 0.03, 0], tail=[0, 26]), "out"),
        (0.76, U(body=[0.01, 0, -2, -5], spine=[-1, -5], fr=[0.08, 0.04, 0], hr=[0, 0.015, 0], tail=[0, 8])),
        (0.95, U())]),
    "attack_slaps": ("One-two", "A quick left, then the right with its weight behind it.", 0.95, [
        (0.0, U()),
        (0.12, U(body=[0, 0.002, 2, -8], spine=[0, -8], fl=[0.05, -0.04, 0.16], head=[0, 8]), "out"),
        (0.26, U(body=[0.015, -0.004, -5, 10], spine=[-3, 10], fl=[-0.18, 0.15, 0.06], head=[2, -8], tail=[0, -14]), "in"),
        (0.34, U(body=[0.005, 0, 2, 12], spine=[0, 12], fl=[-0.06, 0.05, 0.06], fr=[-0.05, -0.05, 0.18], head=[0, -10]), "out"),
        (0.44, U(body=[0.035, -0.012, -10, -14], spine=[-6, -14], fl=[0, 0, 0.03], fr=[0.2, 0.17, 0.04], hr=[0, 0.03, 0], head=[4, 12], tail=[0, 22]), "in"),
        (0.52, U(body=[0.035, -0.008, -8, -16], spine=[-5, -15], fr=[0.23, 0.13, 0.0], hr=[0, 0.03, 0], head=[4, 14], tail=[0, 26]), "out"),
        (0.76, U(body=[0.012, 0, -2, -5], fr=[0.08, 0.04, 0], hr=[0, 0.015, 0])),
        (0.95, U())]),
    "attack_bite": ("Lunge bite", "Drops, darts its whole body forward from the hips and snaps.", 0.95, [
        (0.0, U()),
        (0.2, U(drop=[0.15], body=[-0.02, 0, 6], spine=[4], neck=[-6], head=[-6], fl=[-0.03, -0.03, 0.05], fr=[0.03, -0.03, 0.05], tail=[-6]), "out"),
        (0.42, U(body=[0.06, -0.01, -30], spine=[-14], neck=[14], head=[12], fl=[-0.02, 0.1, 0.06], fr=[0.02, 0.1, 0.06], hl=[0, 0.04, 0], tail=[20]), "in"),
        (0.50, U(body=[0.055, -0.006, -26], spine=[-12], neck=[18], head=[26], fl=[-0.02, 0.08, 0.05], fr=[0.02, 0.08, 0.05], hl=[0, 0.04, 0], tail=[16]), "out"),
        (0.76, U(body=[0.02, 0, -6], spine=[-3], head=[4], hl=[0, 0.02, 0])),
        (0.95, U())]),
}

POWERS = {
    "power_dig": ("Sandstorm", "Digs like a machine, hands a blur, then flings what it dug with both arms.", 1.6, [
        (0.0, U()),
        (0.16, U(drop=[0.3], body=[0.02, 0, -30], spine=[-16], neck=[10], head=[12], fl=[-0.04, 0.12, -0.08], fr=[0.04, 0.06, -0.02], tail=[10]), "out"),
        (0.28, U(drop=[0.3], body=[0.02, 0, -31], spine=[-16], neck=[10], head=[12], fl=[-0.04, 0.05, -0.02], fr=[0.04, 0.13, -0.08], tail=[12, 8])),
        (0.40, U(drop=[0.3], body=[0.02, 0, -30], spine=[-16], neck=[10], head=[12], fl=[-0.04, 0.13, -0.08], fr=[0.04, 0.05, -0.02], tail=[10, -8])),
        (0.52, U(drop=[0.3], body=[0.02, 0, -31], spine=[-16], neck=[10], head=[12], fl=[-0.04, 0.05, -0.02], fr=[0.04, 0.13, -0.08], tail=[12, 8])),
        (0.64, U(drop=[0.32], body=[0.02, 0, -32], spine=[-17], neck=[10], head=[12], fl=[-0.04, 0.13, -0.08], fr=[0.04, 0.05, -0.02], tail=[10, -8])),
        (0.78, U(drop=[0.36], body=[0.0, 0, -36], spine=[-18], neck=[8], head=[8], fl=[-0.03, 0.1, -0.1], fr=[0.03, 0.1, -0.1], tail=[6]), "out"),
        (0.92, U(body=[0.03, 0.012, 8], spine=[8], neck=[4], head=[6], fl=[0.02, 0.2, 0.3], fr=[-0.02, 0.2, 0.3], hl=[0, 0.02, 0], hr=[0, 0.02, 0], tail=[24]), "in"),
        (1.02, U(body=[0.026, 0.008, 11], spine=[9], head=[8], fl=[0.03, 0.17, 0.34], fr=[-0.03, 0.17, 0.34], hl=[0, 0.02, 0], hr=[0, 0.02, 0], tail=[16]), "out"),
        (1.32, U(body=[0.01, 0, 2], spine=[2], fl=[0, 0.05, 0.08], fr=[0, 0.05, 0.08], hl=[0, 0.01, 0], hr=[0, 0.01, 0])),
        (1.6, U())]),
    "power_slam": ("Mob drop", "Crouches, springs straight up with both fists over its head, and comes down on them.", 1.6, [
        (0.0, U()),
        (0.30, U(drop=[0.45], body=[0, 0, -14], spine=[-10], neck=[8], head=[10], fl=[-0.03, 0.02, 0.02], fr=[0.03, 0.02, 0.02], tail=[-6]), "out"),
        (0.50, U(drop=[0.5], body=[0, 0, -16], spine=[-11], neck=[8], head=[12], fl=[-0.03, -0.02, 0.0], fr=[0.03, -0.02, 0.0], tail=[-8])),
        (0.74, U(carry=JUMP, body=[0.02, 0.2, 10], spine=[8], head=[10], fl=[-0.08, 0.02, 0.42], fr=[0.08, 0.02, 0.42], hl=[0, -0.02, 0.03], hr=[0, -0.02, 0.03], tail=[20]), "out"),
        (0.92, U(drop=[0.4], body=[0.05, 0, -34], spine=[-16], neck=[10], head=[8], fl=[-0.05, 0.2, -0.06], fr=[0.05, 0.2, -0.06], hl=[0, 0.03, 0], hr=[0, 0.03, 0], tail=[30]), "in"),
        (1.02, U(drop=[0.3], body=[0.045, 0, -28], spine=[-13], neck=[10], head=[10], fl=[-0.05, 0.19, -0.03], fr=[0.05, 0.19, -0.03], hl=[0, 0.03, 0], hr=[0, 0.03, 0], tail=[18]), "out"),
        (1.34, U(body=[0.02, 0, -6], spine=[-3], fl=[0, 0.05, 0], fr=[0, 0.05, 0], hl=[0, 0.015, 0], hr=[0, 0.015, 0])),
        (1.6, U())]),
    "power_call": ("Alarm call", "Rises as tall as it can, throws its arms wide and barks the alarm; the whole body shakes with it.", 1.6, [
        (0.0, U()),
        (0.25, U(drop=[0.2], body=[0, 0, -8], spine=[-6], neck=[-4], head=[-6], fl=[-0.04, 0.04, 0.04], fr=[0.04, 0.04, 0.04]), "out"),
        (0.70, U(body=[-0.01, 0.014, 6], spine=[6], neck=[8], head=[14], fl=[0.02, -0.02, 0.1], fr=[-0.02, -0.02, 0.1], tail=[6]), "out"),
        (0.84, U(body=[-0.012, 0.016, 7], spine=[7], neck=[9], head=[18], fl=[0.03, -0.03, 0.12], fr=[-0.03, -0.03, 0.12], tail=[6])),
        (0.92, U(body=[0.02, 0.016, -4], spine=[-2], neck=[6], head=[20], fl=[0.14, 0.06, 0.26], fr=[-0.14, 0.06, 0.26], tail=[18]), "in"),
        (1.02, U(body=[0.018, 0.016, -3], spine=[-1, 3], neck=[6, 4], head=[22, 4], fl=[0.15, 0.05, 0.27], fr=[-0.15, 0.05, 0.27], tail=[14, 8]), "out"),
        (1.28, U(body=[0.016, 0.014, -3], spine=[-1, -3], neck=[6, -4], head=[20, -4], fl=[0.14, 0.05, 0.25], fr=[-0.14, 0.05, 0.25], tail=[12, -8])),
        (1.6, U())]),
}

HITS = {
    "hit_duck": ("Duck", "Flinches down small with both hands thrown up over its head.", 0.4, [
        (0.0, U()),
        (0.08, U(drop=[0.35], body=[-0.02, 0, -10], spine=[-8], neck=[-8], head=[-12], fl=[-0.1, 0.06, 0.3], fr=[0.1, 0.06, 0.3], tail=[10]), "out"),
        (0.22, U(drop=[0.2], body=[-0.01, 0, -5], spine=[-4], head=[-4], fl=[-0.06, 0.05, 0.18], fr=[0.06, 0.05, 0.18])),
        (0.4, U())]),
    "hit_reel": ("Reel", "Knocked back onto its heels, arms windmilling, it catches its balance on its tail.", 0.4, [
        (0.0, U()),
        (0.08, U(body=[-0.03, 0.004, 14], spine=[8], neck=[6], head=[8], fl=[0.06, -0.06, 0.16], fr=[-0.06, -0.02, 0.1], tail=[-10]), "out"),
        (0.22, U(body=[-0.012, 0, 4], spine=[2], fl=[0.02, 0.04, 0.06], fr=[-0.02, -0.02, 0.12], head=[-2])),
        (0.4, U())]),
}

FALLS = {
    "fall_side": ("Keel over", "Stiffens, sways, and goes over sideways like a felled post, hands clutched to its chest.", 1.2, [
        (0.0, U()),
        (0.28, U(body=[0, 0.004, 4, 0, -6], spine=[3], head=[8, 0, -8], fl=[-0.1, 0.08, 0.1], fr=[0.1, 0.08, 0.1]), "out"),
        (0.84, U(root=[86, 0.2, 0, 0], head=[-6, 0, 0], fl=[-0.16, 0.1, 0.12], fr=[0.16, 0.1, 0.12], hl=[0, 0.01, 0.02], hr=[0, 0.02, 0.03], tail=[0, 14]), "in"),
        (0.94, U(root=[81, 0.2, 0, 0], head=[-2, 0, 6], fl=[-0.16, 0.1, 0.12], fr=[0.16, 0.1, 0.12], hl=[0, 0.01, 0.03], hr=[0, 0.02, 0.04], tail=[0, 18]), "out"),
        (1.2, U(root=[88, 0.2, 0, 0], head=[-8, 0, 0], fl=[-0.16, 0.1, 0.12], fr=[0.16, 0.1, 0.12], hl=[0, 0.01, 0.02], hr=[0, 0.02, 0.03], tail=[0, 16]), "in")]),
    "fall_sit": ("Sit and slump", "Its legs give; it sits down hard, sways, and folds forward over its own knees.", 1.2, [
        (0.0, U()),
        (0.2, U(body=[0, 0.004, 5], head=[8], fl=[0.02, 0, 0.04], fr=[-0.02, 0, 0.04]), "out"),
        (0.55, U(drop=[0.95], body=[-0.02, 0, 8], spine=[4], head=[6], fl=[0.03, 0.02, 0.05], fr=[-0.03, 0.02, 0.05], tail=[-6]), "in"),
        (0.66, U(drop=[0.88], body=[-0.02, 0, 10], spine=[5], head=[10], fl=[0.03, 0.02, 0.07], fr=[-0.03, 0.02, 0.07]), "out"),
        (1.0, U(drop=[0.95], body=[0.0, 0, -34], spine=[-22], neck=[-10], head=[-14], fl=[0, 0.14, -0.1], fr=[0, 0.14, -0.1], tail=[6, 10]), "in"),
        (1.2, U(drop=[0.97], body=[0.0, 0, -38], spine=[-24], neck=[-12], head=[-16, 8, 8], fl=[0, 0.15, -0.12], fr=[0, 0.15, -0.12], tail=[6, 12]), "out")]),
}

UPL, UPR = [0.06, 0.02, 0.44], [-0.06, 0.02, 0.44]
WINS = {
    "win_cheer": ("Cheer", "Jumps twice with both arms thrown up.", 1.6, [
        (0.0, U()),
        (0.16, U(drop=[0.25], body=[0, 0, -6], spine=[-4], fl=[0, 0.02, 0.02], fr=[0, 0.02, 0.02]), "out"),
        (0.38, U(carry=JUMP, body=[0, 0.1, 6], spine=[5], head=[10], fl=UPL, fr=UPR, hl=[0, 0, 0.03], hr=[0, 0, 0.03], tail=[14]), "out"),
        (0.58, U(drop=[0.25], body=[0, 0, -6], spine=[-4], fl=[0.02, 0.03, 0.16], fr=[-0.02, 0.03, 0.16], tail=[-4]), "in"),
        (0.82, U(carry=JUMP, body=[0, 0.12, 6], spine=[5], head=[12], fl=UPL, fr=UPR, hl=[0, 0, 0.03], hr=[0, 0, 0.03], tail=[14]), "out"),
        (1.02, U(drop=[0.2], body=[0, 0, -5], spine=[-3], fl=[0.02, 0.03, 0.14], fr=[-0.02, 0.03, 0.14], tail=[-4]), "in"),
        (1.6, U(body=[0, 0.008, 3], spine=[3], head=[6], fl=[0, 0.01, 0.02], fr=[0, 0.01, 0.02]), "over")]),
    "win_tall": ("Stand tall", "Draws itself up to its full height, chest out and chin up, and surveys the field.", 1.6, [
        (0.0, U()),
        (0.4, U(body=[0, 0.016, 5], spine=[6, -8], neck=[6, -12], head=[10, -14], fl=[0.03, -0.03, 0.03], fr=[-0.03, -0.03, 0.03], tail=[6]), "out"),
        (1.0, U(body=[0, 0.018, 6], spine=[6, 8], neck=[6, 12], head=[10, 16], fl=[0.03, -0.03, 0.03], fr=[-0.03, -0.03, 0.03], tail=[6, 8])),
        (1.3, U(body=[0, 0.01, 2], spine=[2], head=[-2], fl=[0.01, -0.01, 0.01], fr=[-0.01, -0.01, 0.01]), "in"),
        (1.6, U(body=[0, 0.016, 5], spine=[5], neck=[6], head=[8], fl=[0.03, -0.03, 0.03], fr=[-0.03, -0.03, 0.03], tail=[6]), "over")]),
    "win_dance": ("Victory wiggle", "Rocks from foot to foot with its arms going, tail keeping time.", 1.6, [
        (0.0, U()),
        (0.2, U(body=[0, 0.004, 0, 6, 8, 0.02], spine=[0, 0, -6], head=[4, 0, -8], fl=[0.02, 0.04, 0.2], fr=[0, 0.02, 0.06], hr=[0, 0, 0.02], tail=[0, -16]), "out"),
        (0.5, U(body=[0, 0.004, 0, -6, -8, -0.02], spine=[0, 0, 6], head=[4, 0, 8], fl=[0, 0.02, 0.06], fr=[-0.02, 0.04, 0.2], hl=[0, 0, 0.02], tail=[0, 16])),
        (0.8, U(body=[0, 0.004, 0, 6, 8, 0.02], spine=[0, 0, -6], head=[4, 0, -8], fl=[0.02, 0.04, 0.2], fr=[0, 0.02, 0.06], hr=[0, 0, 0.02], tail=[0, -16])),
        (1.1, U(body=[0, 0.004, 0, -6, -8, -0.02], spine=[0, 0, 6], head=[4, 0, 8], fl=[0, 0.02, 0.06], fr=[-0.02, 0.04, 0.2], hl=[0, 0, 0.02], tail=[0, 16])),
        (1.6, U(body=[0, 0.008, 3], spine=[3], head=[6], fl=[0, 0.01, 0.02], fr=[0, 0.01, 0.02]), "out")]),
}

CLIPS = {
    "idle_sentry": ("Sentry", "idle", "Bolt upright, its head snapping from point to point; now and then it stretches taller.", LOOP, idle_sentry, True),
    "idle_scratch": ("Scratch", "idle", "Scratches its belly with one hand, looking about.", LOOP, idle_scratch, True),
    "idle_peek": ("Duck and peek", "idle", "Ducks down small, then pops up as tall as it can go and scans the sky.", LOOP, idle_peek, True),
    "walk_scurry": ("Scurry", "run", "The game's pace: quick short steps, leaning into it, hands pumping.", 0.42, walk_scurry, True),
    "run_dash": ("Dash", "run", "Flat out: bent well forward, long strides, hands tucked.", 0.34, run_dash, True),
    "run_hop": ("Bound", "run", "Both feet together, the whole body a spring.", 0.4, run_hop, True),
}
for kind, table in (("attack", ATTACKS), ("power", POWERS), ("hit", HITS), ("fall", FALLS), ("win", WINS)):
    for k, (name, desc, secs, keys) in table.items():
        CLIPS[k] = (name, kind, desc, secs, rp.keyed(keys), False)
