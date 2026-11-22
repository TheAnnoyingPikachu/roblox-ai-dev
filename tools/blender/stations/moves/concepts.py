"""Idle, attack and power attack concepts for the nine base animals, in Creatures.client's terms.

A pose is {joint: [pitch, yaw, roll, x, y, z]}: degrees, and studs x the model's Scale for offsets.
Positive pitch lifts the nose / swings a foot (or an upright animal's arm) forward; a negative tail
pitch raises the tail; positive yaw turns left; positive roll swings a hanging leg's foot to the
animal's right (a flamingo's left wing, leg_bl, lifts with +roll, its right, leg_br, with -roll).
Body x is to the animal's right, y up, -z forward.

Idles are functions of t looping every LOOP seconds. Attacks are 0.95 s with the hit at 0.44 s,
power attacks 1.6 s with the impact at 0.92 s (Creatures.LENGTH, MAGIC_IMPACT)."""
import math

LOOP = 4.8
TAU = math.tau


def wave(t, period, phase=0.0):
    return math.sin(t * TAU / period + phase)


def bump(t, start, length):
    """0 outside [start, start + length] (in the loop), rising smoothly to 1 in its middle"""
    u = (t % LOOP - start) / length
    return math.sin(math.pi * u) ** 2 if 0 <= u <= 1 else 0.0


def hold(t, start, length, ramp=0.25):
    """1 inside [start, start + length] (in the loop), easing in and out over `ramp` seconds"""
    x = t % LOOP
    u = min((x - start) / ramp, (start + length - x) / ramp, 1.0)
    u = max(0.0, u)
    return u * u * (3 - 2 * u)


def steps(t, marks, ramp=0.16):
    """a value that holds and snaps: marks [(time, value), ...] in the loop, the first at 0"""
    x = t % LOOP
    v = marks[-1][1]
    out = marks[0][1] if x < marks[0][0] else v
    prev = marks[-1][1]
    for at, val in marks:
        if x >= at:
            u = min(1.0, (x - at) / ramp)
            out = prev + (val - prev) * u * u * (3 - 2 * u)
        prev = val
    return out


def breath(t, deep=1.0):
    return {"body": [1.0 * deep * wave(t, 2.4), 0, 0, 0, 0.02 * deep * wave(t, 2.4), 0], "head": [1.5 * deep * wave(t, 2.4, 0.8)]}


def merge(*poses):
    out = {}
    for p in poses:
        for j, v in p.items():
            cur = out.get(j, [0] * 6)
            v = list(v) + [0] * (6 - len(v))
            out[j] = [cur[k] + v[k] for k in range(6)]
    return out


def crouch(front=24, back=-14):
    return {"leg_fl": [front], "leg_fr": [front], "leg_bl": [back], "leg_br": [back]}


def P(*parts, **joints):
    return merge(*parts, joints)


# ---------------------------------------------------------------------------------------------- jackal
JACKAL = {
    "idle": {
        "1_prowl": ("Prowling sniff", "Head low and nose to the ground, it sniffs along, sweeping its head from side to side; now and then it lifts a forepaw mid-step.",
                    lambda t: P(breath(t), body=[-4, 0, 0, 0, -0.04, 0],
                                head=[-16 + 3 * math.sin(t * TAU / 0.24) * (bump(t, 0.3, 1.4) + bump(t, 2.9, 1.3)), 20 * wave(t, LOOP), 0],
                                tail=[12, 12 * wave(t, 1.6), 0], leg_fr=[20 * bump(t, 2.2, 0.8)], leg_fl=[4])),
        "2_sit": ("Anubis sit", "Sits up tall like a temple statue, tail curled on the ground, head high and turning slowly to watch the field.",
                  lambda t: P(breath(t, 0.7), body=[28, 0, 0, 0, -0.1, 0.2], leg_fl=[-28], leg_fr=[-28], leg_bl=[30], leg_br=[30],
                              head=[-22, steps(t, [(0.0, 0), (0.8, 35), (2.2, 35), (2.5, -30), (3.9, -30), (4.3, 0)], 0.5), 0],
                              tail=[30, 14 * wave(t, 2.4), 0])),
    },
    "attack": {
        "a_snap": ("Hamstring snap", "Darts in low to one side, twists its head and snaps at the target's leg, then springs back out of reach.", [
            (0.00, {}),
            (0.18, P(crouch(22, -10), body=[-6, 18, 0, 0.35, -0.1, 0.25], head=[-18, -10, 0], tail=[-10, 15])),
            (0.44, P(body=[-10, -22, 6, -0.25, -0.08, -0.9], head=[-22, 30, 35], leg_fl=[-25], leg_fr=[-18], leg_bl=[18], leg_br=[18], tail=[-18, -25])),
            (0.56, P(body=[-8, -18, 4, -0.2, -0.06, -0.8], head=[-14, 15, 20], leg_fl=[-15], leg_fr=[-10], leg_bl=[12], leg_br=[12], tail=[-14, -15])),
            (0.76, P(body=[-2, 6, 0, 0.1, 0, 0.15], head=[6], tail=[-12])),
            (0.95, {}),
        ]),
        "b_leap": ("Leaping bite", "A quick crouch, a hop up and forward, and it lands jaws-first on the target with a shake of the head.", [
            (0.00, {}),
            (0.16, P(crouch(24, -14), body=[-6, 0, 0, 0, -0.12, 0.25], head=[-12], tail=[-10])),
            (0.32, P(body=[12, 0, 0, 0, 0.45, -0.7], head=[10], leg_fl=[50], leg_fr=[46], leg_bl=[-34], leg_br=[-34], tail=[-24])),
            (0.44, P(body=[-12, 0, 0, 0, 0, -1.25], head=[-28], leg_fl=[-10], leg_fr=[-10], leg_bl=[8], leg_br=[8], tail=[14])),
            (0.58, P(body=[-6, 0, 0, 0, 0, -1.05], head=[-10, 20, 12])),
            (0.70, P(body=[-6, 0, 0, 0, 0, -1.0], head=[-10, -20, -12])),
            (0.95, {}),
        ]),
    },
    "power": {
        "p_frenzy": ("Frenzy", "Three lunging snaps, each one further in, the last a huge bite at the impact, then it thrashes its head to tear.", [
            (0.00, {}),
            (0.15, P(crouch(20, -12), body=[-4, 0, 0, 0, -0.1, 0.3], head=[-14])),
            (0.32, P(body=[4, 10, 0, 0, 0, -0.5], head=[18, -15, -15], leg_fl=[-14], leg_fr=[10])),
            (0.44, P(crouch(16, -8), body=[-4, 0, 0, 0, -0.08, -0.2], head=[-12])),
            (0.60, P(body=[4, -10, 0, 0, 0, -0.8], head=[18, 15, 15], leg_fr=[-14], leg_fl=[10])),
            (0.74, P(crouch(22, -12), body=[-6, 0, 0, 0, -0.1, -0.5], head=[-20])),
            (0.92, P(body=[10, 0, 0, 0, 0.12, -1.5], head=[28], leg_fl=[-28], leg_fr=[-28], leg_bl=[-20], leg_br=[-20], tail=[-24])),
            (1.08, P(body=[-4, 0, 0, 0, 0, -1.3], head=[-10, 28, 25], tail=[-10, 20])),
            (1.22, P(body=[-4, 0, 0, 0, 0, -1.3], head=[-10, -28, -25], tail=[-10, -20])),
            (1.38, P(body=[0, 0, 0, 0, 0, -0.8])),
            (1.60, {}),
        ]),
        "p_pin": ("Pounce and pin", "Rocks back on its haunches, leaps high onto the target, pins it with both forepaws at the impact and savages it.", [
            (0.00, {}),
            (0.30, P(body=[18, 0, 0, 0, 0.05, 0.5], head=[10], leg_fl=[30], leg_fr=[30], leg_bl=[-22], leg_br=[-22], tail=[-15])),
            (0.66, P(body=[8, 0, 0, 0, 0.85, -1.0], leg_fl=[70], leg_fr=[66], leg_bl=[-40], leg_br=[-40], tail=[-30])),
            (0.92, P(body=[-16, 0, 0, 0, 0.05, -1.8], head=[-30], leg_fl=[-8], leg_fr=[-8], leg_bl=[20], leg_br=[20], tail=[18])),
            (1.06, P(body=[-14, 0, 0, 0, 0.05, -1.75], head=[-34, 22, 18], leg_fl=[-8], leg_fr=[-8], leg_bl=[18], leg_br=[18], tail=[12, 15])),
            (1.20, P(body=[-14, 0, 0, 0, 0.05, -1.75], head=[-34, -22, -18], leg_fl=[-8], leg_fr=[-8], leg_bl=[18], leg_br=[18], tail=[12, -15])),
            (1.36, P(body=[-6, 0, 0, 0, 0, -1.2], head=[-6])),
            (1.60, {}),
        ]),
    },
}

# -------------------------------------------------------------------------------------------- tortoise
TORTOISE = {
    "idle": {
        "1_ancient": ("Old and patient", "Slowly stretches its neck out and draws it back in, chewing as it goes; one front foot shifts its weight now and then.",
                      lambda t: P(breath(t, 0.6),
                                  head=[-4 + 6 * wave(t, LOOP) + 2 * math.sin(t * TAU / 0.48) * max(0.0, wave(t, LOOP)), 12 * wave(t, LOOP, 1.2), 0,
                                        0, 0.04 * wave(t, LOOP), -0.12 - 0.18 * wave(t, LOOP)],
                                  leg_fl=[10 * bump(t, 3.4, 0.9)])),
        "2_bask": ("Sun basking", "Sprawls flat with its legs out, belly down, and holds its head up to the sun, swaying slowly; a contented nod now and then.",
                   lambda t: P(breath(t, 0.5), body=[0, 0, 0, 0, -0.3, 0], leg_fl=[18, 0, -34], leg_fr=[18, 0, 34], leg_bl=[-18, 0, -34], leg_br=[-18, 0, 34],
                               head=[30 + 4 * wave(t, LOOP) - 12 * bump(t, 3.2, 0.9), 14 * wave(t, LOOP, 0.5), 0], tail=[8])),
    },
    "attack": {
        "a_snap": ("Snapping strike", "Pulls its head deep into its shell, holds a beat, then shoots it out in a fast snapping bite.", [
            (0.00, {}),
            (0.24, P(head=[-6, 0, 0, 0, 0.05, 0.7], body=[-3, 0, 0, 0, -0.05, 0.15], leg_fl=[8], leg_fr=[8])),
            (0.36, P(head=[-4, 0, 0, 0, 0.05, 0.8], body=[-3, 0, 0, 0, -0.05, 0.18], leg_fl=[8], leg_fr=[8])),
            (0.44, P(head=[-16, 0, 0, 0, -0.05, -0.75], body=[-4, 0, 0, 0, -0.02, -0.25], leg_fl=[-8], leg_fr=[-8], leg_bl=[8], leg_br=[8])),
            (0.60, P(head=[-8, 0, 0, 0, 0, -0.6], body=[-2, 0, 0, 0, 0, -0.2])),
            (0.95, {}),
        ]),
        "b_sweep": ("Shell sweep", "Twists away, then swings its whole heavy shell round sideways into the target.", [
            (0.00, {}),
            (0.28, P(body=[2, 35, -6, 0.3, 0.05, 0.1], head=[-10, -20], leg_fl=[10], leg_fr=[-10], tail=[0, -20])),
            (0.44, P(body=[-2, -30, 10, -0.5, 0.08, -0.4], head=[-6, 25], leg_fl=[-10], leg_fr=[12], tail=[0, 25])),
            (0.60, P(body=[0, -22, 6, -0.35, 0.03, -0.3], head=[-4, 15])),
            (0.95, {}),
        ]),
    },
    "power": {
        "p_sumo": ("Sumo stomp", "Like a sumo wrestler: leans and stamps one forefoot, then the other, then rears up and drops its whole weight at the impact.", [
            (0.00, {}),
            (0.18, P(body=[0, 0, -8, 0.25, 0.06, 0], leg_fl=[55], head=[4, 8])),
            (0.30, P(body=[-3, 0, 2, 0.05, -0.04, 0], leg_fl=[-4], head=[-6])),
            (0.46, P(body=[0, 0, 8, -0.25, 0.06, 0], leg_fr=[55], head=[4, -8])),
            (0.58, P(body=[-3, 0, -2, -0.05, -0.04, 0], leg_fr=[-4], head=[-6])),
            (0.78, P(body=[16, 0, 0, 0, 0.25, 0.15], leg_fl=[45], leg_fr=[45], leg_bl=[-16], leg_br=[-16], head=[10], tail=[-8])),
            (0.92, P(body=[-8, 0, 0, 0, -0.1, -0.25], leg_fl=[-12], leg_fr=[-12], leg_bl=[8], leg_br=[8], head=[-14, 0, 0, 0, 0, -0.2])),
            (1.12, P(body=[-2, 0, 0, 0, 0, -0.1], head=[-4])),
            (1.60, {}),
        ]),
        "p_spin": ("Shell spin", "Pulls its head and legs into its shell and spins like a top straight through the target, then pops back out.", [
            (0.00, {}),
            (0.25, P(body=[0, 0, 0, 0, -0.1, 0], head=[0, 0, 0, 0, 0, 0.75], tail=[0, 0, 0, 0, 0.15, 0.25],
                     leg_fl=[0, 0, 0, 0, 0.45, 0], leg_fr=[0, 0, 0, 0, 0.45, 0], leg_bl=[0, 0, 0, 0, 0.45, 0], leg_br=[0, 0, 0, 0, 0.45, 0])),
            (0.45, P(body=[0, 180, 0, 0, 0.15, 0.1], head=[0, 0, 0, 0, 0, 0.75], tail=[0, 0, 0, 0, 0.15, 0.25],
                     leg_fl=[0, 0, 0, 0, 0.45, 0], leg_fr=[0, 0, 0, 0, 0.45, 0], leg_bl=[0, 0, 0, 0, 0.45, 0], leg_br=[0, 0, 0, 0, 0.45, 0])),
            (0.70, P(body=[0, 450, 0, 0, 0.2, -1.0], head=[0, 0, 0, 0, 0, 0.75], tail=[0, 0, 0, 0, 0.15, 0.25],
                     leg_fl=[0, 0, 0, 0, 0.45, 0], leg_fr=[0, 0, 0, 0, 0.45, 0], leg_bl=[0, 0, 0, 0, 0.45, 0], leg_br=[0, 0, 0, 0, 0.45, 0])),
            (0.92, P(body=[0, 720, 0, 0, 0.1, -1.8], head=[0, 0, 0, 0, 0, 0.75], tail=[0, 0, 0, 0, 0.15, 0.25],
                     leg_fl=[0, 0, 0, 0, 0.45, 0], leg_fr=[0, 0, 0, 0, 0.45, 0], leg_bl=[0, 0, 0, 0, 0.45, 0], leg_br=[0, 0, 0, 0, 0.45, 0])),
            (1.06, P(body=[0, 735, 5, 0, 0, -1.65], head=[0, 0, 0, 0, 0, 0.75], tail=[0, 0, 0, 0, 0.15, 0.25],
                     leg_fl=[0, 0, 0, 0, 0.45, 0], leg_fr=[0, 0, 0, 0, 0.45, 0], leg_bl=[0, 0, 0, 0, 0.45, 0], leg_br=[0, 0, 0, 0, 0.45, 0])),
            (1.26, P(body=[0, 720, 0, 0, 0, -1.2], head=[10])),
            (1.60, P(body=[0, 720])),
        ], {"spin": True}),
    },
}

# --------------------------------------------------------------------------------------------- meerkat
# upright (decision 0055): its front legs are arms (positive pitch swings one forward and up, 180 is
# straight up), its back legs its legs, which turn against the body so its feet stay flat.
MEERKAT = {
    "idle": {
        "1_sentinel": ("Sentinel", "Stands tall on its toes, paws tucked at its chest, and snaps its head round in quick looks: left, right, up at the sky.",
                       lambda t: P(breath(t, 0.6), body=[0, 0, 0, 0, 0.04, 0], leg_fl=[62], leg_fr=[62],
                                   head=[steps(t, [(0.0, 0), (3.2, 24), (4.2, 0)], 0.14),
                                         steps(t, [(0.0, 0), (0.6, 48), (1.5, -44), (2.4, 0), (3.2, 0)], 0.14), 0])),
        "2_boxer": ("Boxer", "Fists up in a guard, bouncing on its toes and bobbing its head; every so often it throws a quick jab at the air.",
                    lambda t: P(body=[-4, 8 * wave(t, 1.2), 0, 0, 0.05 * abs(math.sin(t * TAU / 1.2)), 0],
                                leg_fl=[100 + 30 * bump(t, 1.9, 0.32), 0, 0], leg_fr=[88 + 36 * bump(t, 3.6, 0.32)],
                                leg_bl=[4 + 5 * wave(t, 1.2)], leg_br=[4 - 5 * wave(t, 1.2)],
                                head=[6 + 3 * wave(t, 0.6), -6 * wave(t, 1.2), 0])),
    },
    "attack": {
        "a_combo": ("Jab, jab, hook", "A quick left jab, a right jab, then a big swinging right hook that lands on the hit.", [
            (0.00, {}),
            (0.08, P(leg_fl=[80], leg_fr=[70])),
            (0.16, P(body=[-6, -15, 0, 0, 0, -0.1], leg_fl=[100], leg_fr=[66])),
            (0.24, P(leg_fl=[76], leg_fr=[70])),
            (0.32, P(body=[-6, 15, 0, 0, 0, -0.15], leg_fl=[76], leg_fr=[100])),
            (0.38, P(body=[0, -28, 0], leg_fl=[80], leg_fr=[60, 0, 40])),
            (0.44, P(body=[-10, 35, 0, 0, 0, -0.3], head=[0, -10], leg_fl=[70], leg_fr=[95, 0, -30])),
            (0.60, P(body=[-4, 20, 0, 0, 0, -0.2], leg_fl=[70], leg_fr=[70])),
            (0.95, {}),
        ]),
        "b_dive": ("Diving headbutt", "Crouches, then dives flat out head-first with its arms out in front, butts the target and bounces back to its feet.", [
            (0.00, {}),
            (0.20, P(body=[-10, 0, 0, 0, -0.15, 0.1], leg_bl=[30], leg_br=[30], leg_fl=[-30], leg_fr=[-30], head=[6])),
            (0.44, P(body=[-62, 0, 0, 0, 0.1, -1.1], head=[30], leg_fl=[150], leg_fr=[150], leg_bl=[10], leg_br=[10])),
            (0.60, P(body=[-40, 0, 0, 0, 0, -0.8], head=[20], leg_fl=[100], leg_fr=[100], leg_bl=[25], leg_br=[25])),
            (0.80, P(body=[-6, 0, 0, 0, 0, -0.2], leg_bl=[6], leg_br=[6])),
            (0.95, {}),
        ]),
    },
    "power": {
        "p_burrow": ("Burrow ambush", "Dives head-first into the ground, tunnels across under the target and bursts up beneath it with a double uppercut at the impact.", [
            (0.00, {}),
            (0.18, P(body=[-15, 0, 0, 0, -0.2, 0], leg_fl=[-20], leg_fr=[-20], head=[-10], leg_bl=[15], leg_br=[15])),
            (0.42, P(body=[-85, 0, 0, 0, -3.5, -0.5], head=[-10], leg_fl=[180], leg_fr=[180])),
            (0.76, P(body=[0, 0, 0, 0, -7.0, -1.6], leg_fl=[180], leg_fr=[180])),
            (0.92, P(body=[6, 0, 0, 0, 0.6, -1.6], leg_fl=[175], leg_fr=[160], leg_bl=[-10], leg_br=[-10], head=[20])),
            (1.10, P(body=[0, 0, 0, 0, 0.05, -1.5], leg_fl=[120], leg_fr=[120])),
            (1.35, P(body=[0, 0, 0, 0, 0, -0.8], leg_fl=[40], leg_fr=[40])),
            (1.60, {}),
        ], {"dig": True}),
        "p_dropkick": ("Tail-spring dropkick", "Leans right back onto its tail like a tripod, tucks its knees, then springs off and drop-kicks the target with both feet.", [
            (0.00, {}),
            (0.35, P(body=[35, 0, 0, 0, -0.1, 0.35], leg_bl=[-25], leg_br=[-25], leg_fl=[30], leg_fr=[30], head=[-25])),
            (0.70, P(body=[55, 0, 0, 0, 0.05, 0.4], leg_bl=[60], leg_br=[60], head=[-30], leg_fl=[-20], leg_fr=[-20])),
            (0.92, P(body=[70, 0, 0, 0, 0.6, -1.3], leg_bl=[95], leg_br=[95], leg_fl=[-40], leg_fr=[-40], head=[-40])),
            (1.10, P(body=[40, 0, 0, 0, 0.3, -1.0], leg_bl=[40], leg_br=[40], head=[-20])),
            (1.32, P(body=[0, 0, 0, 0, 0, -0.6])),
            (1.60, {}),
        ]),
    },
}

# --------------------------------------------------------------------------------------------- cheetah
CHEETAH = {
    "idle": {
        "1_stalk": ("Stalking crouch", "Low on its haunches with its head level and eyes locked ahead, creeping its forepaws one at a time, tail tip twitching.",
                    lambda t: P(breath(t, 0.6), crouch(42, -24), body=[-3, 0, 0, 0, -0.24, 0],
                                leg_fl=[14 * bump(t, 0.6, 0.9)], leg_fr=[14 * bump(t, 2.9, 0.9)],
                                head=[-6, 6 * wave(t, LOOP), 0], tail=[6, 10 * math.sin(t * TAU / 0.4) * (bump(t, 1.4, 1.2) + bump(t, 3.8, 0.9)), 0])),
        "2_restless": ("Restless", "Shifts its weight from side to side, tail swaying wide and head following something; halfway through it licks a forepaw.",
                       lambda t: P(breath(t), body=[0, 4 * wave(t, LOOP), 3 * wave(t, 2.4), 0.06 * wave(t, 2.4), 0, 0],
                                   head=[-38 * bump(t, 2.8, 1.6), 25 * wave(t, LOOP, 0.4) * (1 - bump(t, 2.8, 1.6)) + 22 * bump(t, 2.8, 1.6), 0],
                                   leg_fr=[50 * bump(t, 2.8, 1.6), -10 * bump(t, 2.8, 1.6)], tail=[-6, 25 * wave(t, 2.4), 0])),
    },
    "attack": {
        "a_trip": ("Trip swipe", "Dashes in low and hooks the target's legs out from under it with a sideways sweep of one forepaw.", [
            (0.00, {}),
            (0.18, P(crouch(30, -16), body=[-6, 0, 0, 0, -0.1, 0.2], head=[-8], tail=[-10])),
            (0.34, P(body=[-4, 0, 0, 0, 0, -1.1], head=[-6], leg_fl=[-20], leg_fr=[45, 0, 30], leg_bl=[12], leg_br=[12], tail=[-16, 12])),
            (0.44, P(body=[-6, -18, -6, 0, -0.04, -1.5], leg_fr=[40, 0, -30], leg_fl=[10], head=[-10, -20], tail=[-14, -30])),
            (0.60, P(body=[-2, -10, 0, 0, 0, -1.2], head=[0, -10])),
            (0.95, {}),
        ]),
        "b_clamp": ("Throat clamp", "Springs up and forward, clamps its jaws down on the target's throat at the hit and drags it back.", [
            (0.00, {}),
            (0.20, P(crouch(28, -14), body=[-4, 0, 0, 0, -0.12, 0.25], head=[-10])),
            (0.36, P(body=[16, 0, 0, 0, 0.35, -0.9], head=[24], leg_fl=[55], leg_fr=[50], leg_bl=[-30], leg_br=[-30], tail=[-20])),
            (0.44, P(body=[12, 0, 0, 0, 0.3, -1.1], head=[-26], leg_fl=[40], leg_fr=[40], leg_bl=[-24], leg_br=[-24], tail=[-18])),
            (0.62, P(body=[2, 0, 0, 0, 0.05, -0.6], head=[-20, 10, 8], leg_fl=[10], leg_fr=[10], leg_bl=[-6], leg_br=[-6], tail=[-8])),
            (0.95, {}),
        ]),
    },
    "power": {
        "p_blitz": ("Blitz", "A burst of speed: darts left, right, left through the target, lands a two-paw strike at the impact and skids to a stop.", [
            (0.00, {}),
            (0.25, P(crouch(30, -16), body=[-6, 0, 0, 0, -0.14, 0.35])),
            (0.45, P(body=[-4, 35, -8, -1.2, 0.05, -0.6], leg_fl=[40], leg_fr=[40], leg_bl=[-30], leg_br=[-30], tail=[-10, -30], head=[0, -20])),
            (0.62, P(body=[-4, -35, 8, 1.2, 0.05, -1.2], leg_fl=[-20], leg_fr=[-20], leg_bl=[20], leg_br=[20], tail=[-10, 30], head=[0, 20])),
            (0.78, P(body=[-4, 30, -8, -0.8, 0.05, -1.7], leg_fl=[40], leg_fr=[40], leg_bl=[-30], leg_br=[-30], tail=[-10, -30], head=[0, -15])),
            (0.92, P(body=[10, 0, 0, 0, 0.3, -2.1], leg_fl=[60], leg_fr=[56], leg_bl=[-36], leg_br=[-36], head=[10], tail=[-20])),
            (1.08, P(body=[-8, 0, 0, 0, -0.05, -1.9], leg_fl=[-24], leg_fr=[-24], leg_bl=[10], leg_br=[10], head=[-6])),
            (1.30, P(body=[-2, 0, 0, 0, 0, -1.0])),
            (1.60, {}),
        ]),
        "p_lash": ("Tail-whip turn", "Sprints in, plants its forepaws and whips its whole body round so its long tail lashes through the target, then turns back.", [
            (0.00, {}),
            (0.30, P(crouch(28, -14), body=[-6, 0, 0, 0, -0.12, 0.3])),
            (0.60, P(body=[-4, 0, 0, 0, 0.1, -1.4], leg_fl=[40], leg_fr=[36], leg_bl=[-28], leg_br=[-28], tail=[-12])),
            (0.78, P(body=[-10, 40, 0, 0, -0.05, -1.7], leg_fl=[-22], leg_fr=[-22], leg_bl=[14], leg_br=[14], tail=[-14, -30], head=[-10, -10])),
            (0.92, P(body=[-6, 170, 0, 0, 0.1, -1.8], tail=[-10, 45], head=[0, 20], leg_bl=[30], leg_br=[30], leg_fl=[-10], leg_fr=[-10])),
            (1.12, P(body=[-2, 200, 0, 0, 0, -1.7], tail=[-10, -20], head=[0, 10])),
            (1.32, P(body=[0, 100, 0, 0, 0.05, -1.0])),
            (1.60, {}),
        ]),
    },
}

# ----------------------------------------------------------------------------------------------- rhino
RHINO = {
    "idle": {
        "1_paw": ("Pawing bull", "Head low and snorting, it scrapes one forefoot back through the dirt twice, tail flicking.",
                  lambda t: P(breath(t), body=[-2, 0, 0, 0, -0.02, 0],
                              head=[-14 + 6 * (bump(t, 0.5, 0.25) + bump(t, 0.9, 0.25)), 6 * wave(t, LOOP), 0],
                              leg_fr=[22 * math.sin((t % LOOP - 2.4) * TAU / 0.8) * hold(t, 2.4, 1.6, 0.2)],
                              tail=[0, 20 * math.sin(t * TAU / 0.6) * bump(t, 1.2, 1.0), 0])),
        "2_whet": ("Horn whetting", "Lowers its head and grinds its horn along the ground from side to side, then lifts it to look round.",
                   lambda t: P(breath(t), body=[-4 * hold(t, 0.3, 2.6), 0, 0, 0, -0.04 * hold(t, 0.3, 2.6), 0],
                               head=[-30 * hold(t, 0.3, 2.6), 14 * math.sin(t * TAU / 0.8) * hold(t, 0.3, 2.6) + 18 * wave(t, LOOP, 1.0) * (1 - hold(t, 0.3, 2.6)), 0],
                               tail=[0, 12 * wave(t, 1.2), 0])),
    },
    "attack": {
        "a_gore": ("Sideways gore", "Swings its head low to one side, then rips its horn up and across the target.", [
            (0.00, {}),
            (0.26, P(head=[-26, 30, -15], body=[-4, 10, 0, 0.1, -0.06, 0.25], leg_fl=[8], leg_fr=[8], tail=[-10])),
            (0.44, P(head=[28, -25, 20], body=[4, -12, 0, -0.1, 0.06, -0.8], leg_fl=[-18], leg_fr=[-18], leg_bl=[-14], leg_br=[-14], tail=[18])),
            (0.62, P(head=[12, -12, 8], body=[2, -6, 0, 0, 0.02, -0.5])),
            (0.95, {}),
        ]),
        "b_check": ("Shoulder check", "Steps out to the side, then slams its armoured flank into the target.", [
            (0.00, {}),
            (0.24, P(body=[0, 28, 6, 0.4, 0.04, 0.2], head=[-8, -20], leg_fl=[0, 0, -14], leg_fr=[0, 0, -14], tail=[0, 20])),
            (0.44, P(body=[-2, -32, -10, -0.7, 0, -0.7], head=[-6, 26], leg_fl=[0, 0, 14], leg_fr=[0, 0, 14], leg_bl=[0, 0, 10], leg_br=[0, 0, 10], tail=[0, -24])),
            (0.60, P(body=[0, -20, -4, -0.5, 0, -0.5], head=[-4, 14])),
            (0.95, {}),
        ]),
    },
    "power": {
        "p_bulldoze": ("Bulldozer fling", "Drops its horn, drives it under the target and shoves forward two strides, then flings it skyward at the impact.", [
            (0.00, {}),
            (0.25, P(head=[-34], body=[-6, 0, 0, 0, -0.1, 0.3], leg_fl=[10], leg_fr=[10], leg_bl=[-12], leg_br=[-12], tail=[-10])),
            (0.50, P(head=[-38], body=[-8, 0, 0, 0, -0.12, -0.6], leg_fl=[-18], leg_fr=[22], leg_bl=[18], leg_br=[-14])),
            (0.72, P(head=[-38], body=[-8, 0, 0, 0, -0.12, -1.4], leg_fl=[22], leg_fr=[-18], leg_bl=[-14], leg_br=[18])),
            (0.92, P(head=[45], body=[14, 0, 0, 0, 0.2, -1.9], leg_fl=[30], leg_fr=[30], leg_bl=[-24], leg_br=[-24], tail=[20])),
            (1.10, P(head=[30], body=[8, 0, 0, 0, 0.08, -1.8], leg_fl=[14], leg_fr=[14])),
            (1.30, P(body=[0, 0, 0, 0, 0, -1.0], head=[8])),
            (1.60, {}),
        ]),
        "p_split": ("Earth splitter", "Stamps its forefeet, left and right, faster and faster, then rears and drives its horn into the ground to split the earth.", [
            (0.00, {}),
            (0.12, P(leg_fl=[30], body=[2, 0, -4, 0, 0.03, 0], head=[-6])),
            (0.24, P(leg_fl=[-4], body=[-2, 0, 0, 0, -0.03, 0])),
            (0.36, P(leg_fr=[34], body=[2, 0, 4, 0, 0.04, 0], head=[-6])),
            (0.48, P(leg_fr=[-4], body=[-2, 0, 0, 0, -0.03, 0])),
            (0.72, P(body=[20, 0, 0, 0, 0.35, 0.3], leg_fl=[44], leg_fr=[40], leg_bl=[-20], leg_br=[-20], head=[24], tail=[-14])),
            (0.92, P(body=[-12, 0, 0, 0, -0.1, -0.5], head=[-40], leg_fl=[-18], leg_fr=[-18], leg_bl=[12], leg_br=[12], tail=[20])),
            (1.10, P(body=[-8, 0, 0, 0, -0.06, -0.4], head=[-36, 6])),
            (1.30, P(body=[-2, 0, 0, 0, 0, -0.2], head=[-10])),
            (1.60, {}),
        ]),
    },
}

# -------------------------------------------------------------------------------------------- flamingo
# its front legs are its legs, its back legs its wings; its feet never leave the ground in the game now
# (PLANTED), which the Sky dive would change for it.
FLAMINGO = {
    "idle": {
        "1_oneleg": ("One-legged rest", "Stands on one leg with the other tucked up, its head laid back along its body; now and then it lifts its head to look round.",
                     lambda t: P(breath(t, 0.6), body=[0, 0, 0, -0.06, 0, 0], leg_fr=[-40, 0, 0, 0, 0.45, 0],
                                 head=[44 - 44 * hold(t, 2.2, 1.6, 0.45), 18 * wave(t, 1.6) * hold(t, 2.2, 1.6, 0.45), 0], tail=[0, 6 * wave(t, 2.4), 0])),
        "2_preen": ("Preening", "Turns its long neck round to its wing and nibbles at its feathers, wing lifted, then does the other side.",
                    lambda t: P(breath(t),
                                head=[-30 * (hold(t, 0.3, 1.8) + hold(t, 2.7, 1.7)) + 3 * math.sin(t * TAU / 0.2) * (hold(t, 0.6, 1.2) + hold(t, 3.0, 1.1)),
                                      115 * hold(t, 0.3, 1.8) - 115 * hold(t, 2.7, 1.7), 0],
                                leg_bl=[0, 0, 14 * hold(t, 0.3, 1.8)], leg_br=[0, 0, -14 * hold(t, 2.7, 1.7)], tail=[0, 8 * wave(t, 1.2), 0])),
    },
    "attack": {
        "a_buffet": ("Wing buffet", "Throws its wings wide, then beats them forward in a gust into the target, leaning in.", [
            (0.00, {}),
            (0.26, P(leg_bl=[0, 0, 60], leg_br=[0, 0, -60], body=[6, 0, 0, 0, 0, 0.15], head=[10], tail=[-10])),
            (0.44, P(leg_bl=[30, 0, 20], leg_br=[30, 0, -20], body=[-10, 0, 0, 0, 0, -0.4], head=[-20])),
            (0.60, P(leg_bl=[0, 0, 35], leg_br=[0, 0, -35], body=[-4, 0, 0, 0, 0, -0.2])),
            (0.95, {}),
        ]),
        "b_lash": ("Neck lash", "Swings its long neck far out to one side, then whips it across like a flail.", [
            (0.00, {}),
            (0.28, P(head=[-20, 70, 20], body=[0, 15, 0], tail=[0, -20])),
            (0.44, P(head=[-30, -45, -20], body=[-4, -15, 0, 0, 0, -0.3], tail=[0, 25])),
            (0.60, P(head=[-14, -25, -10], body=[-2, -8, 0, 0, 0, -0.2])),
            (0.95, {}),
        ]),
    },
    "power": {
        "p_twirl": ("Flamingo twirl", "Rises onto one leg with its wings wide and pirouettes a full turn, whipping up a whirlwind, then thrusts its wings forward at the impact.", [
            (0.00, {}),
            (0.20, P(leg_fr=[-30, 0, 0, 0, 0.3, 0], leg_bl=[0, 0, 70], leg_br=[0, 0, -70], head=[20], body=[0, 0, 0, 0, 0.05, 0])),
            (0.50, P(leg_fr=[-30, 0, 0, 0, 0.3, 0], leg_bl=[0, 0, 70], leg_br=[0, 0, -70], head=[20], body=[0, 180, 0, 0, 0.08, 0])),
            (0.78, P(leg_fr=[-30, 0, 0, 0, 0.3, 0], leg_bl=[0, 0, 70], leg_br=[0, 0, -70], head=[14], body=[0, 340, 0, 0, 0.08, 0])),
            (0.92, P(body=[-10, 360, 0, 0, 0, -0.3], leg_bl=[35, 0, 15], leg_br=[35, 0, -15], head=[-25])),
            (1.10, P(body=[-4, 360, 0, 0, 0, -0.2], leg_bl=[0, 0, 30], leg_br=[0, 0, -30], head=[-10])),
            (1.60, P(body=[0, 360])),
        ], {"spin": True}),
        "p_dive": ("Sky dive", "Beats its wings and rises into the air, legs dangling, then folds its wings and dives beak-first onto the target.", [
            (0.00, {}),
            (0.10, P(leg_bl=[0, 0, 70], leg_br=[0, 0, -70], head=[10])),
            (0.20, P(leg_bl=[0, 0, -20], leg_br=[0, 0, 20], body=[0, 0, 0, 0, 0.15, 0], head=[10])),
            (0.30, P(leg_bl=[0, 0, 70], leg_br=[0, 0, -70], body=[0, 0, 0, 0, 0.35, 0], head=[12], leg_fl=[-10], leg_fr=[-10])),
            (0.40, P(leg_bl=[0, 0, -20], leg_br=[0, 0, 20], body=[0, 0, 0, 0, 0.55, 0], head=[12], leg_fl=[-15], leg_fr=[-15])),
            (0.50, P(leg_bl=[0, 0, 70], leg_br=[0, 0, -70], body=[0, 0, 0, 0, 0.8, 0], head=[14], leg_fl=[-20], leg_fr=[-20])),
            (0.60, P(leg_bl=[0, 0, -20], leg_br=[0, 0, 20], body=[0, 0, 0, 0, 1.0, 0], head=[14], leg_fl=[-25], leg_fr=[-25])),
            (0.72, P(leg_bl=[0, 0, 60], leg_br=[0, 0, -60], body=[10, 0, 0, 0, 1.1, 0.1], head=[20], leg_fl=[-25], leg_fr=[-25])),
            (0.92, P(body=[-40, 0, 0, 0, 0.15, -1.4], head=[-35], leg_bl=[-30, 0, 10], leg_br=[-30, 0, -10], leg_fl=[-35], leg_fr=[-35], tail=[-10])),
            (1.08, P(body=[-15, 0, 0, 0, 0, -1.2], head=[-20], leg_bl=[0, 0, 40], leg_br=[0, 0, -40])),
            (1.30, P(body=[0, 0, 0, 0, 0, -0.6])),
            (1.60, {}),
        ]),
    },
}

# ------------------------------------------------------------------------------------------------ lion
LION = {
    "idle": {
        "1_king": ("King's survey", "Stands tall with its chest out and head high, slowly surveying its land, tail swishing; now and then a huge yawn.",
                   lambda t: P(breath(t), body=[2, 0, 0, 0, 0.02, 0], leg_fl=[-3], leg_fr=[-3],
                               head=[10 + 24 * bump(t, 3.0, 1.3), 22 * wave(t, LOOP) * (1 - bump(t, 3.0, 1.3)), 0],
                               tail=[-4, 16 * wave(t, 2.4), 0])),
        "2_growl": ("Growling guard", "Head low and shoulders hunched, weight forward, tail lashing; every few seconds it shakes out its mane with a growl.",
                    lambda t: P(breath(t), crouch(18, -8), body=[-6, 0, 0, 0, -0.12, -0.05],
                                head=[-24 + 3 * max(0.0, wave(t, 1.2)), 6 * wave(t, LOOP), 18 * math.sin(t * TAU / 0.24) * bump(t, 2.6, 0.9)],
                                tail=[-6, 30 * wave(t, 1.2), 0])),
    },
    "attack": {
        "a_maul": ("Rearing maul", "Rears up on its hind legs with its claws out, then crashes both forepaws down onto the target.", [
            (0.00, {}),
            (0.24, P(body=[30, 0, 0, 0, 0.4, 0.25], head=[-10], leg_fl=[70], leg_fr=[64], leg_bl=[-28], leg_br=[-28], tail=[-20])),
            (0.44, P(body=[-12, 0, 0, 0, -0.08, -0.75], head=[-14], leg_fl=[-10], leg_fr=[-6], leg_bl=[10], leg_br=[10], tail=[-14])),
            (0.62, P(body=[-6, 0, 0, 0, -0.04, -0.55], head=[-8, 12, 8], tail=[-12])),
            (0.95, {}),
        ]),
        "b_swipe": ("Haymaker", "Rises onto three legs and smashes one huge forepaw sideways across the target.", [
            (0.00, {}),
            (0.24, P(body=[8, 18, 6, 0.15, 0.1, 0.1], leg_fr=[70, 0, 35], head=[4, -12], tail=[-14, -15])),
            (0.44, P(body=[-4, -25, -6, -0.15, 0.02, -0.5], leg_fr=[45, 0, -40], head=[-10, 20], tail=[-12, 25])),
            (0.60, P(body=[-2, -15, 0, -0.1, 0, -0.35], leg_fr=[10, 0, -15], tail=[-10])),
            (0.95, {}),
        ]),
    },
    "power": {
        "p_roar": ("King's roar", "Rears back drawing in a great breath, then slams its forepaws down and roars at the target, its whole head shaking with it.", [
            (0.00, {}),
            (0.40, P(body=[16, 0, 0, 0, 0.22, 0.4], head=[24], leg_fl=[34], leg_fr=[30], leg_bl=[-16], leg_br=[-16], tail=[-16])),
            (0.78, P(body=[22, 0, 0, 0, 0.32, 0.5], head=[32], leg_fl=[46], leg_fr=[42], leg_bl=[-20], leg_br=[-20], tail=[-24])),
            (0.92, P(body=[-10, 0, 0, 0, -0.1, -0.4], head=[-2, 0, 0, 0, 0, -0.2], leg_fl=[-14], leg_fr=[-14], leg_bl=[10], leg_br=[10], tail=[-20])),
            (1.04, P(body=[-10, 0, 0, 0, -0.1, -0.4], head=[0, 0, 5, 0, 0, -0.2], leg_fl=[-14], leg_fr=[-14], leg_bl=[10], leg_br=[10], tail=[-20])),
            (1.16, P(body=[-10, 0, 0, 0, -0.1, -0.4], head=[0, 0, -5, 0, 0, -0.2], leg_fl=[-14], leg_fr=[-14], leg_bl=[10], leg_br=[10], tail=[-20])),
            (1.30, P(body=[-4, 0, 0, 0, -0.04, -0.2], head=[-4], tail=[-10])),
            (1.60, {}),
        ]),
        "p_flurry": ("Mauling flurry", "Rears onto its hind legs and rains blows, left, right, left, then smashes both forepaws down at the impact.", [
            (0.00, {}),
            (0.20, P(body=[34, 0, 0, 0, 0.42, 0.2], leg_fl=[80], leg_fr=[60], leg_bl=[-30], leg_br=[-30], head=[-12], tail=[-22])),
            (0.36, P(body=[30, 8, 0, 0, 0.38, 0.1], leg_fl=[20], leg_fr=[90], leg_bl=[-28], leg_br=[-28], head=[-16, -8], tail=[-22])),
            (0.52, P(body=[30, -8, 0, 0, 0.38, 0.0], leg_fl=[90], leg_fr=[20], leg_bl=[-28], leg_br=[-28], head=[-16, 8], tail=[-22])),
            (0.66, P(body=[30, 8, 0, 0, 0.38, 0.0], leg_fl=[20], leg_fr=[90], leg_bl=[-28], leg_br=[-28], head=[-16, -8], tail=[-22])),
            (0.80, P(body=[40, 0, 0, 0, 0.5, 0.1], leg_fl=[100], leg_fr=[100], leg_bl=[-34], leg_br=[-34], head=[-6], tail=[-24])),
            (0.92, P(body=[-14, 0, 0, 0, -0.1, -0.8], leg_fl=[-12], leg_fr=[-12], leg_bl=[12], leg_br=[12], head=[-16], tail=[-16])),
            (1.12, P(body=[-6, 0, 0, 0, -0.04, -0.5], head=[-8], tail=[-12])),
            (1.60, {}),
        ]),
    },
}

# --------------------------------------------------------------------------------------------- giraffe
# its head joint is at the base of its neck: the head turns the whole neck
GIRAFFE = {
    "idle": {
        "1_browse": ("Browsing", "Neck stretched up and forward to the treetops, head turning slowly as it nibbles and chews; tail swatting flies.",
                     lambda t: P(breath(t, 0.6), head=[12 + 2 * math.sin(t * TAU / 0.48) * (0.5 + 0.5 * wave(t, 2.4)), 14 * wave(t, LOOP), 0],
                                 tail=[0, 20 * math.sin(t * TAU / 0.6) * bump(t, 2.0, 1.2), 0])),
        "2_drink": ("Watering hole", "Splays its front legs wide and dips its long neck right down to the ground to drink, then swings back up to keep watch.",
                    lambda t: P(breath(t, 0.6), body=[-3 * hold(t, 0.4, 2.8, 0.6), 0, 0, 0, -0.08 * hold(t, 0.4, 2.8, 0.6), 0],
                                leg_fl=[6 * hold(t, 0.4, 2.8, 0.6), 0, -22 * hold(t, 0.4, 2.8, 0.6)], leg_fr=[6 * hold(t, 0.4, 2.8, 0.6), 0, 22 * hold(t, 0.4, 2.8, 0.6)],
                                head=[-68 * hold(t, 0.4, 2.8, 0.6) + 3 * math.sin(t * TAU / 0.6) * hold(t, 1.0, 1.6), 10 * wave(t, LOOP, 2.0) * (1 - hold(t, 0.4, 2.8, 0.6)), 0],
                                tail=[0, 10 * wave(t, 1.2), 0])),
    },
    "attack": {
        "a_neck": ("Necking swing", "Swings its long neck far out to one side, then whips it across to club the target with its horned head.", [
            (0.00, {}),
            (0.28, P(head=[-10, 65, 25], body=[0, 12, 0], tail=[0, -20], leg_fl=[0, 0, -8], leg_fr=[0, 0, -8])),
            (0.44, P(head=[-28, -50, -30], body=[-2, -14, 0, 0, 0, -0.15], tail=[0, 25], leg_fl=[0, 0, 8], leg_fr=[0, 0, 8])),
            (0.60, P(head=[-18, -30, -16], body=[0, -8, 0])),
            (0.95, {}),
        ]),
        "b_kick": ("Front kick", "Rocks back and cocks one front leg, then strikes forward with its hoof.", [
            (0.00, {}),
            (0.24, P(body=[12, 0, 0, 0, 0.1, 0.05], leg_fr=[-15], head=[12])),
            (0.44, P(body=[2, 0, 0, 0, 0.05, -0.2], leg_fr=[70], head=[-4])),
            (0.60, P(body=[0, 0, 0, 0, 0, -0.1], leg_fr=[20])),
            (0.95, {}),
        ]),
    },
    "power": {
        "p_topple": ("Tower topple", "Draws its neck up tall and back, then brings it crashing down like a falling tower, slamming its head into the ground.", [
            (0.00, {}),
            (0.40, P(head=[30], body=[8, 0, 0, 0, 0.05, 0.15], tail=[-10], leg_fl=[6], leg_fr=[6])),
            (0.78, P(head=[42], body=[12, 0, 0, 0, 0.08, 0.2], tail=[-16], leg_fl=[8], leg_fr=[8])),
            (0.92, P(head=[-72], body=[-8, 0, 0, 0, -0.05, -0.15], leg_fl=[-10], leg_fr=[-10], leg_bl=[6], leg_br=[6], tail=[16])),
            (1.06, P(head=[-66], body=[-6, 0, 0, 0, -0.04, -0.1])),
            (1.30, P(head=[-20])),
            (1.60, {}),
        ]),
        "p_buck": ("Double-barrel buck", "Swings its rump round to the target, looks back over its shoulder and fires both hind hooves into it.", [
            (0.00, {}),
            (0.40, P(body=[0, 150, 0, 0, 0, -0.1], head=[-4, -50], tail=[0, 20])),
            (0.70, P(body=[-4, 165, 0, 0, 0.02, -0.15], head=[0, -70])),
            (0.80, P(body=[4, 165, 0, 0, 0, -0.1], leg_bl=[25], leg_br=[25], head=[0, -70])),
            (0.92, P(body=[-18, 165, 0, 0, 0.05, -0.2], leg_bl=[-65], leg_br=[-60], leg_fl=[18], leg_fr=[18], tail=[-30], head=[-10, -70])),
            (1.08, P(body=[-10, 165, 0, 0, 0.02, -0.2], leg_bl=[-40], leg_br=[-40], leg_fl=[10], leg_fr=[10], head=[-6, -60])),
            (1.30, P(body=[0, 90, 0, 0, 0, -0.1], head=[0, -20])),
            (1.60, {}),
        ]),
    },
}

# -------------------------------------------------------------------------------------------- elephant
# the Titan: its trunk is part of its head
ELEPHANT = {
    "idle": {
        "1_sway": ("Swaying giant", "Rocks its great weight slowly from side to side, lifting each forefoot a little in turn, trunk swinging, tail swishing.",
                   lambda t: P(breath(t), body=[0, 0, 3 * wave(t, LOOP), -0.06 * wave(t, LOOP), 0, 0],
                               leg_fl=[8 * max(0.0, wave(t, LOOP))], leg_fr=[8 * max(0.0, -wave(t, LOOP))],
                               head=[-2 + 2 * wave(t, 2.4), 8 * wave(t, LOOP, 1.0), 2 * wave(t, LOOP)], tail=[0, 18 * wave(t, 1.2), 0])),
        "2_dust": ("Dust shower", "Lifts its trunk high and flings dust over its back, gives itself a big shake, then lowers its head and watches.",
                   lambda t: P(breath(t), body=[0, 0, 3 * math.sin(t * TAU / 0.24) * bump(t, 2.5, 0.8), 0, 0, 0],
                               head=[-6 + 46 * hold(t, 0.8, 1.4, 0.4), 6 * wave(t, LOOP, 2.0), 4 * math.sin(t * TAU / 0.24) * bump(t, 2.5, 0.8)],
                               tail=[0, 14 * wave(t, 1.2), 0])),
    },
    "attack": {
        "a_tusk": ("Tusk uppercut", "Dips its head low, then drives its tusks up and across the target.", [
            (0.00, {}),
            (0.26, P(head=[-24, 14], body=[-4, 6, 0, 0, -0.04, 0.2], leg_fl=[6], leg_fr=[6])),
            (0.44, P(head=[22, -16, 10], body=[6, -8, 0, 0, 0.06, -0.5], leg_fl=[-10], leg_fr=[-10], leg_bl=[-8], leg_br=[-8], tail=[12])),
            (0.62, P(head=[10, -8], body=[2, -4, 0, 0, 0.02, -0.3])),
            (0.95, {}),
        ]),
        "b_stomp": ("Crushing stomp", "Shifts its weight, raises one huge forefoot high and stomps it down on the target.", [
            (0.00, {}),
            (0.24, P(body=[8, 0, -6, 0.15, 0.08, 0.05], leg_fl=[50], head=[16, 8], tail=[-8])),
            (0.44, P(body=[-6, 0, 2, 0.05, -0.04, -0.35], leg_fl=[-4], head=[-12], tail=[10])),
            (0.60, P(body=[-3, 0, 0, 0, -0.02, -0.25], head=[-6])),
            (0.95, {}),
        ]),
    },
    "power": {
        "p_charge": ("Titan charge", "Lowers its head and charges with thundering strides, ramming the target tusks-first at the impact.", [
            (0.00, {}),
            (0.30, P(head=[-20], body=[-4, 0, 0, 0, -0.06, 0.4], leg_fl=[14], leg_fr=[14], leg_bl=[-10], leg_br=[-10], tail=[-10])),
            (0.50, P(body=[-2, 0, 0, 0, 0.05, -0.4], leg_fl=[30], leg_fr=[-14], leg_bl=[-20], leg_br=[16], head=[-24], tail=[-12])),
            (0.70, P(body=[-2, 0, 0, 0, 0.05, -1.2], leg_fl=[-14], leg_fr=[30], leg_bl=[16], leg_br=[-20], head=[-24], tail=[-12])),
            (0.92, P(body=[-6, 0, 0, 0, -0.02, -2.0], head=[18], leg_fl=[-18], leg_fr=[-18], leg_bl=[12], leg_br=[12], tail=[16])),
            (1.10, P(body=[-2, 0, 0, 0, 0, -1.8], head=[8])),
            (1.60, {}),
        ]),
        "p_blast": ("Trumpet blast", "Rears back with its trunk raised, trembling as it draws in the air, then thrusts forward and trumpets a blast at the impact, forefeet stamping.", [
            (0.00, {}),
            (0.40, P(body=[14, 0, 0, 0, 0.18, 0.35], head=[40], leg_fl=[30], leg_fr=[26], leg_bl=[-14], leg_br=[-14], tail=[-14])),
            (0.55, P(body=[16, 0, 1.5, 0, 0.2, 0.38], head=[44, 0, 3], leg_fl=[32], leg_fr=[28], leg_bl=[-15], leg_br=[-15], tail=[-14])),
            (0.65, P(body=[16, 0, -1.5, 0, 0.2, 0.38], head=[44, 0, -3], leg_fl=[32], leg_fr=[28], leg_bl=[-15], leg_br=[-15], tail=[-14])),
            (0.75, P(body=[16, 0, 1.5, 0, 0.2, 0.38], head=[46, 0, 3], leg_fl=[32], leg_fr=[28], leg_bl=[-15], leg_br=[-15], tail=[-14])),
            (0.85, P(body=[16, 0, -1.5, 0, 0.2, 0.38], head=[46, 0, -3], leg_fl=[32], leg_fr=[28], leg_bl=[-15], leg_br=[-15], tail=[-14])),
            (0.92, P(body=[-8, 0, 0, 0, -0.08, -0.5], head=[8, 0, 0, 0, 0, -0.2], leg_fl=[-12], leg_fr=[-12], leg_bl=[8], leg_br=[8], tail=[14])),
            (1.05, P(body=[-8, 0, 0, 0, -0.08, -0.5], head=[8, 0, 4, 0, 0, -0.2], leg_fl=[-12], leg_fr=[-12], leg_bl=[8], leg_br=[8], tail=[14])),
            (1.15, P(body=[-8, 0, 0, 0, -0.08, -0.5], head=[8, 0, -4, 0, 0, -0.2], leg_fl=[-12], leg_fr=[-12], leg_bl=[8], leg_br=[8], tail=[14])),
            (1.35, P(body=[-2, 0, 0, 0, 0, -0.2], head=[-2])),
            (1.60, {}),
        ]),
    },
}

CONCEPTS = {
    "creature_jackal_forge": ("Jackal", JACKAL),
    "creature_tortoise_forge": ("Tortoise", TORTOISE),
    "creature_meerkat_forge": ("Meerkat", MEERKAT),
    "creature_cheetah_forge": ("Cheetah", CHEETAH),
    "creature_rhino_forge": ("Rhino", RHINO),
    "creature_flamingo_forge": ("Flamingo", FLAMINGO),
    "creature_lion_forge": ("Lion", LION),
    "creature_giraffe_forge": ("Giraffe", GIRAFFE),
    "creature_elephant_forge": ("Elephant", ELEPHANT),
}


def neutral(t, upright):
    """the shared idle the animals play now (idle / idleBiped in Creatures.client)"""
    if upright:
        return {"body": [0, 0, 0, 0, 0.02 * math.sin(t * TAU / 3.4), 0], "head": [2 * math.sin(t * TAU / 3.4 + 0.8), 4 * math.sin(t * TAU / 6), 0],
                "leg_fl": [3 * math.sin(t * TAU / 3.4)], "leg_fr": [-3 * math.sin(t * TAU / 3.4)], "tail": [5 * math.sin(t * TAU / 2.6), 0, 0]}
    return {"body": [0, 0, 0, 0, 0.03 * math.sin(t * TAU / 3.2), 0], "head": [2 * math.sin(t * TAU / 3.2 + 0.8), 5 * math.sin(t * TAU / 5.6), 0],
            "tail": [0, 12 * math.sin(t * TAU / 1.9), 0]}


def ease(u):
    return u * u * (3 - 2 * u)


def sample(keys, t):
    for (t0, p0), (t1, p1) in zip(keys, keys[1:]):
        if t0 <= t <= t1:
            u = ease((t - t0) / max(1e-6, t1 - t0))
            return {j: [((p0.get(j, []) + [0] * 6)[k]) * (1 - u) + ((p1.get(j, []) + [0] * 6)[k]) * u for k in range(6)] for j in set(p0) | set(p1)}
    return dict(keys[-1][1])


def upright_tail(pose):
    """an upright animal's tail never swings below where it rests, and lifts as the body leans back"""
    tail, body = pose.get("tail", [0] * 6), pose.get("body", [0] * 6)
    tail = list(tail) + [0] * (6 - len(tail))
    out = dict(pose)
    out["tail"] = [min(tail[0], 0) - max(body[0] if body else 0, 0), tail[1], tail[2], 0, 0, 0]
    return out
