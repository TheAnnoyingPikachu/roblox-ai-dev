"""Pacing check for Lantern Express v0.1 (planning aid for docs/game-design/game6-gdd.md; not shipped).

From the GDD's numbers: how long the first minutes, a stop, a leg and a run take for 1 to 6 players;
how often a crew reaches Dawn Station, runs out of coal or loses its lanterns; what a run pays
(Tickets, XP, Parts); how many runs the Critter Album takes. Two player profiles: CASUAL (misjudges
the fog on 12% of risky trips) and NEW (30%). At night each lamp works through its share of a wave:
it notices a wisp `react` s after it spawns, swings onto it at `swing` degrees a second (a lone lamp
covers the whole circle, four lamps a quarter each) and holds the beam for the puff time; a wisp it
cannot finish before it reaches its lantern gets through. LANTERN-015 calibrated the casual lamp to
the Studio bot (a lamp that notices in 1 s and swings 120 degrees a second; see the task's
evidence). LANTERN-003 and LANTERN-004 copy the check values into Lune specs, so a config change
that moves them fails CI.

Usage: python -I docs/game-design/game6-pacing.py [runs_per_case]   (default 300; seeded; stdlib only)
"""
import math
import random
import sys

# --- GDD section C values; src/shared/LanternConfig.luau holds the same numbers ------------------
SPEED = [20, 23, 26]            # cruise by Boiler level I / II / III, studs/s
ACCEL = 4                       # studs/s^2, speeding up and braking
RIDE = 700                      # studs: hub or stop to the next stop
NIGHT = 3600                    # studs: stop 3 to the Depot (Dawn Station on leg 3)
COAL_PER_STUD = 1 / 60
BUNKER = [80, 100, 120]         # coal cap by Bunker level; a run starts full
COAL_SACK = 5
CALM = 70                       # s from arrival to the fog bell
DEPTH = 160                     # studs from the platform edge to the far edge of a stop
FOG_V0, FOG_ACC, FOG_VMAX = 6, 1.0, 16
WALK, SMALL, BIG, CRITTER_SOLO, CRITTER_DUO = 16, 15, 13, 9, 13
PICK, LOAD, UNSEAT = 0.5, 0.3, 1.0
GRACE = 3                       # s after everyone is seated before the train leaves
DEPOT_MEAN, DAWN_ARRIVAL = 45, 10
LANTERN_MAX, DEPOT_LANTERN, DIVE_DIM = 100, 40, 10
WISP_DIM = {1: 4.5, 2: 3.5, 3: 3.5, 4: 2.75}  # lantern lost per wisp that gets through, by min(n, 4) (LANTERN-015; 4+: LANTERN-016)
WISP_SPEED = {1: 6, 2: 7, 3: 8, 4: 8}  # studs/s a wisp drifts, by min(n, 4) (LANTERN-015)
SPAWN, SPREAD = (60, 75), 3     # studs from the train a wisp starts; s a wave's spawns spread over
OIL_POUR, OIL_AUTO, OIL_AUTO_BELOW, OIL_STORE = 12, 8, 25, 6
PUFF = [0.6, 0.45, 0.35]        # s of beam that puffs a wisp, by Lamps level
WAVE_FIRST, WAVE_GAP = 8, 25
PER_TURRET = [4, 6, 8]          # wisps per manned turret per wave on legs 1 / 2 / 3
LAKE_EXTRA = 1
LAMPEATER_AT, DIVE_EVERY = 50, 8
UPGRADES = {"boiler": [30, 60], "bunker": [25, 50], "lamps": [30, 60]}
COAL_BUY = (30, 12)             # 30 coal for 12 Parts
VALUE = {"coal": 1, "parts": 1, "oil": 1, "supply": 8}
CRITTER_VALUE = {"common": 10, "uncommon": 15, "rare": 25, "epic": 50, "legendary": 100}
PARTS = {"parts": 3, "supply": 10}
XP = dict(small=2, big=5, rescue=20, new=50, puff=2, stop=5, depot=40, dawn=150)
DEPOT_TICKETS, DAWN_TICKETS, FED_TICKETS = 30, 150, 50
RARITY = ["common", "uncommon", "rare", "epic", "legendary"]
ODDS = {  # basis points by (band, line, leg 3)
    ("near", False): {"forest": [7000, 2500, 500, 0, 0], "lake": [7000, 2500, 500, 0, 0]},
    ("near", True): {"forest": [7000, 2500, 500, 0, 0], "lake": [7000, 2500, 500, 0, 0]},
    ("far", False): {"forest": [4600, 3400, 1500, 500, 0], "lake": [4000, 3400, 1800, 800, 0]},
    ("far", True): {"forest": [4300, 3400, 1500, 500, 300], "lake": [3700, 3400, 1800, 800, 300]},
}
SPECIES = {  # id: (rarity, lines)
    "mossmouse": ("common", "fl"), "puddlefrog": ("common", "fl"), "wickmole": ("common", "fl"),
    "burrbun": ("common", "fl"), "lanternbeetle": ("uncommon", "fl"), "fogpup": ("uncommon", "fl"),
    "acornowlet": ("uncommon", "fl"), "teapotcat": ("rare", "fl"), "reedfox": ("rare", "fl"),
    "mistfawn": ("epic", "f"), "bellturtle": ("epic", "l"), "moonhare": ("legendary", "fl"),
}
BIG_SITES = [22, 40, 58, 78, 96, 114, 132, 150]   # depth of the 8 big sites in every tile
NEAR = 70
# react: s to notice a wisp; swing: degrees a second onto it; hit: chance an attempt holds a wobbling
# wisp in the 7-degree cone long enough. Assumptions (LANTERN-015) between the Studio evidence: two
# bots that notice in 1 s and swing 120 degrees a second puffed 86% (old numbers) and 93% (new) of a
# solo night's wisps; the LANTERN-012 runs aimed by keyboard puffed about 12% and lost by wave 5.
PROFILES = {
    "casual": dict(react=1.0, swing=120, hit=0.5, greed=0.12, aim=0.7),  # a fair player
    "new": dict(react=1.6, swing=70, hit=0.35, greed=0.30, aim=0.5),
}


def counts(n):
    return dict(coal=6 + 3 * n, parts=2 + n, oil=2 + n // 2, supply=1 + n // 2, critter=1 + math.ceil(n / 2))


def wisps(n, leg, lake):
    k = min(n, 4)  # four turrets; a fifth and sixth player add one wisp each
    return PER_TURRET[leg] * k + (n - k) + (LAKE_EXTRA if lake else 0)


def fog_front(t):
    """Depth of the fog front t seconds after the bell (DEPTH at the bell, 0 at the platform)."""
    t_max = (FOG_VMAX - FOG_V0) / FOG_ACC
    tt = min(max(t, 0), t_max)
    d = FOG_V0 * tt + FOG_ACC * tt * tt / 2 + FOG_VMAX * max(0, t - t_max)
    return max(0.0, DEPTH - d)


FOG_TIME = next(t / 100 for t in range(10000) if fog_front(t / 100) <= 0)


def safe(depth, start, speed):
    """A carrier leaving `depth` at stop time `start` reaches the platform ahead of the fog."""
    t, x = start, depth
    while x > 0:
        if t >= CALM and x >= fog_front(t - CALM):
            return False
        t, x = t + 0.05, x - speed * 0.05
    return True


def ride_time(dist, v):
    return dist / v + v / ACCEL  # cruise plus the ramp up and the brake


def roll_critter(rng, band, line, leg3):
    r = rng.randrange(10000)
    for i, bp in enumerate(ODDS[(band, leg3)][line]):
        if r < bp:
            break
        r -= bp
    pool = [s for s, (ra, lines) in SPECIES.items() if ra == RARITY[i] and line[0] in lines]
    return rng.choice(pool), RARITY[i]


def stop(rng, n, coal_need, leg, line, first, prof):
    """One stop for a crew of n: (seconds, loads, coal, oil, parts, caught)."""
    c = counts(n)
    sites = BIG_SITES[:]
    rng.shuffle(sites)
    if first:  # stop 1 of every run puts one critter crate on the nearest site
        sites.remove(BIG_SITES[0])
        sites.insert(0, BIG_SITES[0])
    crates = [("critter", d) for d in sites[: c["critter"]]]
    crates += [("supply", d) for d in sites[c["critter"] : c["critter"] + c["supply"]]]
    smalls = sorted((rng.uniform(15, 150), k) for k in ("coal", "parts", "oil") for _ in range(c[k]))
    free = [UNSEAT] * n
    coal = oil = parts = caught = 0
    loads = []
    while True:
        i = min(range(n), key=lambda j: free[j])
        t = free[i]
        if t > CALM + FOG_TIME:
            break
        coal_piles = [s for s in smalls if s[1] == "coal"]
        if coal < coal_need and coal_piles:
            kind, picked, speed = "small", coal_piles[:3], SMALL
        elif crates:  # critters first (a critter crate counts as 60% of its distance), then supply
            kind, d = min(crates, key=lambda x: x[1] if x[0] == "supply" else x[1] * 0.6)
            speed = (CRITTER_DUO if n >= 2 else CRITTER_SOLO) if kind == "critter" else BIG
            picked = [(d, kind)]
        elif smalls:
            kind, picked, speed = "small", smalls[:3], SMALL
        else:
            break
        far = max(d for d, _ in picked)
        out = t + far / WALK + PICK * len(picked)
        helper = None
        if kind == "critter" and n >= 2:
            others = [j for j in range(n) if j != i and free[j] <= t + 2]
            helper = others[0] if others else None
            speed = CRITTER_DUO if helper is not None else CRITTER_SOLO
        ok = safe(far, out, speed)
        if not ok and rng.random() > prof["greed"]:  # a careful player boards instead
            free[i] = 10 ** 9
            continue
        if kind == "small":
            for s in picked:
                smalls.remove(s)
        else:
            crates.remove((kind, far))
        busy = [i] + ([helper] if helper is not None else [])
        if not ok:  # caught: the load drops in the fog, the player waits on the train
            caught += 1
            for j in busy:
                free[j] = 10 ** 9
            continue
        for j in busy:
            free[j] = out + far / speed + LOAD
        if kind == "critter":
            loads.append(("critter", roll_critter(rng, "near" if far < NEAR else "far", line, leg == 2)))
        elif kind == "supply":
            parts += PARTS["supply"]
            loads.append(("supply", None))
        else:
            for _, k in picked:
                coal += COAL_SACK if k == "coal" else 0
                oil += 1 if k == "oil" else 0
                parts += PARTS["parts"] if k == "parts" else 0
                loads.append((k, None))
    active = [f for f in free if f < 10 ** 9]
    end = min(max(active) + GRACE if active else CALM + FOG_TIME, CALM + FOG_TIME)
    return end, loads, coal, oil, parts, caught


def wave_puffs(rng, w, k, puff, prof):
    """Wisps k lamps puff in a wave of w: each lamp takes every k-th wisp in spawn order, notices it
    `react` s after it spawns, swings onto it (up to 180 / k degrees: a lone lamp turns all round)
    and holds the beam `puff` s, landing it with chance `hit`. A wisp a lamp misses gets one more
    try from the next lamp if that lamp is free in time (crews cover for each other); a wisp nobody
    finishes before it reaches its lantern gets through."""
    free = [0.0] * k
    missed = []
    got = 0
    for i in range(w):
        lamp, born = i % k, SPREAD * i / w
        arrive = born + rng.uniform(*SPAWN) / WISP_SPEED[k]
        start = max(free[lamp], born + prof["react"]) + rng.uniform(0, 180 / k) / prof["swing"]
        if start + puff <= arrive:
            free[lamp] = start + puff
            if rng.random() < prof["hit"]:
                got += 1
                continue
        missed.append((lamp, arrive))
    for lamp, arrive in missed if k > 1 else []:
        other = (lamp + 1) % k
        start = free[other] + rng.uniform(0, 180 / k) / prof["swing"]
        if start + puff <= arrive:
            free[other] = start + puff
            got += rng.random() < prof["hit"]
    return got


def night(rng, n, leg, lake, lamps, speed, oil, lantern, prof):
    """(lantern, oil, puffs, fed, seconds) after one night."""
    secs = NIGHT / speed
    k = min(n, 4)
    waves = [WAVE_FIRST + WAVE_GAP * i for i in range(20) if WAVE_FIRST + WAVE_GAP * i < secs]
    if leg == 2:
        waves = [w for w in waves if w < LAMPEATER_AT]
    puffs = 0

    def pour(lantern, oil):
        while lantern < OIL_AUTO_BELOW and oil > 0:
            lantern, oil = lantern + (OIL_POUR if n >= 5 else OIL_AUTO), oil - 1  # a 5th player mends
        return lantern, oil

    for _ in waves:
        w = wisps(n, leg, lake)
        got = wave_puffs(rng, w, k, PUFF[lamps], prof)
        puffs += got
        lantern, oil = pour(lantern - (w - got) * WISP_DIM[k], oil)
    fed = False
    if leg == 2:
        window = secs - LAMPEATER_AT
        need = 15 + 8 * (n - 1)
        rate = k * 0.45 * prof["aim"]  # beam-seconds a second on the moth
        fed = rate * window >= need
        dives = int((need / rate if fed else window) // DIVE_EVERY)
        p = min(0.95, (0.5 + 0.12 * k) * prof["aim"] / 0.7)
        for _ in range(dives):
            if rng.random() > p:
                lantern -= DIVE_DIM
            lantern, oil = pour(lantern, oil)
    return min(LANTERN_MAX, lantern), oil, puffs, fed, secs


def share(v, n):
    return math.ceil(v * (1 + 0.1 * (n - 1)) / n)


def run(rng, n, prof):
    lv = dict(boiler=0, bunker=0, lamps=0)
    coal, oil, lantern, pool = BUNKER[0], 0, LANTERN_MAX, 0
    tickets = xp = caught = 0
    album, leg_times, parts_by_leg, nights = [], [], [], []
    end = "dawn"
    for leg in range(3):
        lake = leg > 0 and rng.random() < 0.5  # leg 1 is always the Forest Line
        line = "lake" if lake else "forest"
        v = SPEED[lv["boiler"]]
        t, gained = (GRACE if leg == 0 else 0.0), 0
        for s in range(3):
            t += ride_time(RIDE, v)
            coal -= RIDE * COAL_PER_STUD
            need = ((2 - s) * RIDE + NIGHT) * COAL_PER_STUD + 6 - coal
            need = max(0.0, min(need, BUNKER[lv["bunker"]] - coal))
            secs, loads, c, o, p, ca = stop(rng, n, need, leg, line, leg == 0 and s == 0, prof)
            t += secs
            caught += ca
            coal, oil, pool, gained = min(BUNKER[lv["bunker"]], coal + c), min(OIL_STORE, oil + o), pool + p, gained + p
            for kind, crit in loads:
                if kind == "critter":
                    tickets += share(CRITTER_VALUE[crit[1]], n)
                    xp += XP["rescue"] + XP["big"] / n
                    album.append(crit[0])
                else:
                    tickets += share(VALUE[kind], n)
                    xp += (XP["big"] if kind == "supply" else XP["small"]) / n
            xp += XP["stop"]
        parts_by_leg.append(gained)
        coal -= NIGHT * COAL_PER_STUD
        if coal < 0:
            end = "coal"
            leg_times.append(t)
            break
        lantern, oil, puffs, fed, secs = night(rng, n, leg, lake, lv["lamps"], v, oil, lantern, prof)
        nights.append(lantern > 0)
        t += secs
        xp += puffs * XP["puff"] / n
        if lantern <= 0:
            end = "lantern"
            leg_times.append(t)
            break
        if leg < 2:
            tickets += DEPOT_TICKETS
            xp += XP["depot"]
            lantern = min(LANTERN_MAX, lantern + DEPOT_LANTERN)
            t += DEPOT_MEAN
            next_need = (3 * RIDE + NIGHT) * COAL_PER_STUD  # buy coal when the bunker holds under half a leg
            while coal < next_need / 2 and pool >= COAL_BUY[1] and coal + COAL_BUY[0] <= BUNKER[lv["bunker"]]:
                coal, pool = coal + COAL_BUY[0], pool - COAL_BUY[1]
            for up in ("boiler", "lamps", "bunker"):
                if lv[up] < 2 and pool >= UPGRADES[up][lv[up]]:
                    pool -= UPGRADES[up][lv[up]]
                    lv[up] += 1
        else:
            tickets += DAWN_TICKETS + (FED_TICKETS if fed else 0)
            xp += XP["dawn"]
            t += DAWN_ARRIVAL
        leg_times.append(t)
    tickets += math.ceil(pool / n)
    return dict(t=sum(leg_times), end=end, tickets=tickets, xp=xp, album=album, caught=caught,
                leg_times=leg_times, upgrades=sum(lv.values()), parts=parts_by_leg, nights=nights)


def level(xp):
    return min(50, int(math.sqrt(max(xp, 0) / 40)) + 1)


def med(xs):
    xs = sorted(xs)
    return xs[len(xs) // 2] if xs else 0


def main():
    cases = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    rng = random.Random(6)
    print("== First minutes (solo, empty server) ==")
    stop1 = GRACE + ride_time(RIDE, SPEED[0])
    d = BIG_SITES[0]
    first = stop1 + UNSEAT + d / WALK + PICK + d / CRITTER_SOLO + LOAD
    print(f"  train leaves {GRACE} s after PLAY seats the player; stop 1 opens at {stop1:.0f} s; "
          f"first critter rescued (crate at {d} studs) at {first:.0f} s")
    print(f"  fog bell at {stop1 + CALM:.0f} s; stop 2 opens by {stop1 + CALM + FOG_TIME + GRACE + ride_time(RIDE, SPEED[0]):.0f} s")
    print("\n== Fog ==")
    print(f"  bell {CALM} s after arrival; the fog crosses {DEPTH} studs in {FOG_TIME:.1f} s; a stop lasts at most {CALM + FOG_TIME:.1f} s")
    for speed, name in [(WALK, "nothing"), (SMALL, "3 small"), (BIG, "a supply crate"), (CRITTER_DUO, "a critter, two"), (CRITTER_SOLO, "a critter, one")]:
        far = max(x for x in range(DEPTH + 1) if safe(x, CALM, speed))
        print(f"  leaving at the bell with {name:15} ({speed:2} studs/s): home from {far} studs or nearer")
    print("\n== Rides by Boiler level ==")
    for v in SPEED:
        n_w = len([1 for i in range(20) if WAVE_FIRST + WAVE_GAP * i < NIGHT / v])
        print(f"  {v} studs/s: a ride {ride_time(RIDE, v):.0f} s, the night {NIGHT / v:.0f} s with {n_w} waves")
    per_leg = (3 * RIDE + NIGHT) * COAL_PER_STUD
    print(f"  coal a leg {per_leg:.0f} (rides {3 * RIDE * COAL_PER_STUD:.0f}, night {NIGHT * COAL_PER_STUD:.0f}); "
          f"a crew that loads no coal runs dry {(BUNKER[0] - 3 * RIDE * COAL_PER_STUD) / COAL_PER_STUD:.0f} studs into the first night")
    print("\n== Wisps a wave, legs 1 / 2 / 3 (Lake +1) ==")
    for n in range(1, 7):
        print(f"  crew {n}: {' / '.join(str(wisps(n, l, False)) for l in range(3))}")
    for name, prof in PROFILES.items():
        r = random.Random(1)
        rates = [sum(wave_puffs(r, wisps(n, 0, False), min(n, 4), PUFF[0], prof) for _ in range(400)) / (400 * wisps(n, 0, False)) for n in (1, 2, 4, 6)]
        print(f"  {name} lamps puff on leg 1 (Lamps I), crews 1 / 2 / 4 / 6: {' / '.join(f'{x:.0%}' for x in rates)}")
    for name, prof in PROFILES.items():
        print(f"\n== Runs, {name} players ({cases} seeded runs a crew size) ==")
        print("  crew | run min | leg min (incl. Depot) | night 1 won | Lampeater met | Dawn | out of coal / lanterns | Tickets | XP | critters | caught | upgrades | Parts a leg")
        for n in (1, 2, 3, 4, 6):
            rs = [run(rng, n, prof) for _ in range(cases)]
            dawn = [r for r in rs if r["end"] == "dawn"]
            legs = [lt / 60 for r in dawn for lt in r["leg_times"]] or [0]
            print(f"   {n}   | {med(r['t'] / 60 for r in dawn):5.1f} | {med(legs):4.1f} ({min(legs):.1f} to {max(legs):.1f}) | "
                  f"{sum(r['nights'][:1] == [True] for r in rs) / cases:4.0%} | {sum(len(r['nights']) >= 3 for r in rs) / cases:4.0%} | "
                  f"{len(dawn) / cases:4.0%} | {sum(r['end'] == 'coal' for r in rs) / cases:3.0%} / {sum(r['end'] == 'lantern' for r in rs) / cases:3.0%} | "
                  f"{med(r['tickets'] for r in rs):4} | {med(r['xp'] for r in rs):5.0f} | {sum(len(r['album']) for r in rs) / cases:4.1f} | "
                  f"{sum(r['caught'] for r in rs) / cases:3.1f} | {sum(r['upgrades'] for r in rs) / cases:3.1f} | "
                  f"{med(p for r in rs for p in r['parts']):3}")
    print("\n== Album (12 species): runs to fill it, median and 90th percentile, casual ==")
    for n in (1, 2, 4):
        out = []
        for _ in range(150):
            seen, runs = set(), 0
            while len(seen) < 12 and runs < 400:
                runs += 1
                seen.update(run(rng, n, PROFILES["casual"])["album"])
            out.append(runs)
        out.sort()
        print(f"  crew {n}: {out[len(out) // 2]} runs (90%: {out[int(len(out) * 0.9)]}), about {out[len(out) // 2] * 28 / 60:.0f} h")
    leg3_far = [r for r in (run(rng, 1, PROFILES["casual"]) for _ in range(cases))]
    print(f"  solo runs with a Moon Hare: {sum('moonhare' in r['album'] for r in leg3_far) / cases:.0%}")
    xp_run = med(run(rng, 1, PROFILES["casual"])["xp"] for _ in range(cases))
    print(f"\n== Levels (solo casual, {xp_run:.0f} XP a run) ==")
    print("  " + ", ".join(f"{k} runs: level {level(xp_run * k)}" for k in (1, 3, 10, 30, 100)))


if __name__ == "__main__":
    main()
