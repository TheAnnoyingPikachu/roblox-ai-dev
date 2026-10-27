"""Greedy pacing sim for Neon Spire (planning aid for docs/game-design/game5-gdd.md; not shipped).
A good-but-not-perfect player buys whatever gives the most income per credit, respecting power,
and catches about half the Hot Data bonuses (ACTIVE_BONUS). SPIRE-004 ports this to a Luau
balance spec so CI fails if a config change moves the pacing targets.

Usage: python3 game5-pacing-sim.py [minutes] [shares] [floorBase] [floorGrowth] [keep]
  e.g. python3 game5-pacing-sim.py 6000 0 60 2.15         first run
       python3 game5-pacing-sim.py 3000 10 60 2.15 keep    second run, 10 shares, plaza kept"""
import sys

MAX_FLOORS = 30
SLOTS = 4
LV_MULT = [1, 2, 4, 8, 16]
UP_COST = [2, 5, 12, 30]
BASE_SUPPLY = 6
ACTIVE_BONUS = 1.15
FUSION_SUPPLY = [8, 18, 32, 50, 75]
AD_ADJ = 0.25

DEPTS = {  # id: (income per module at L1, power draw, module cost, floors owned to unlock)
    "data": (1, 1, 15, 1),
    "fusion": (0, 0, 150, 3),
    "ad": (6, 2, 600, 5),
    "synth": (40, 4, 8000, 8),
    "drone": (250, 6, 150000, 12),
    "quantum": (1600, 10, 3000000, 17),
    "orbital": (10000, 16, 60000000, 23),
}

PLAZA = [  # name, cost, hype, cells, max count
    ("bench", 100, 1, 1, 12), ("palm", 800, 2, 1, 10), ("vending", 6000, 3, 1, 8),
    ("noodle", 40000, 5, 2, 6), ("arcade", 300000, 8, 4, 4), ("fountain", 2500000, 12, 4, 2),
    ("maglev", 20000000, 20, 6, 1), ("billboard", 150000000, 25, 2, 2), ("idol", 1500000000, 40, 9, 1),
]
PLAZA_CELLS, HYPE_CAP = 80, 200


def floor_cost(n, base, growth):
    return round(base * growth ** (n - 2))


def run(minutes, base=60, growth=1.85, shares=0, verbose=False, keep_plaza=False):
    cr = 100.0
    floors = []  # dept per floor 2..; mods[i] list of levels
    mods = []
    plaza = {p[0]: 0 for p in PLAZA}
    if keep_plaza:
        plaza.update(bench=12, palm=10, vending=8, noodle=6, arcade=4, fountain=2, maglev=1, billboard=2)
    t = 0
    earned = 0.0
    marks = {}

    def supply():
        return BASE_SUPPLY + sum(FUSION_SUPPLY[l - 1] for i, d in enumerate(floors) if d == "fusion" for l in mods[i] if l)

    def draw():
        return sum(DEPTS[d][1] for i, d in enumerate(floors) if d != "fusion" for l in mods[i] if l)

    def hype():
        return min(HYPE_CAP, 10 * nfloors(), sum(plaza[p[0]] * p[2] for p in PLAZA))

    def cells():
        return sum(plaza[p[0]] * p[3] for p in PLAZA)

    def floor_mult(i):
        if floors[i] in ("ad", "fusion"):
            return 1
        n = sum(1 for j in (i - 1, i + 1) if 0 <= j < len(floors) and floors[j] == "ad" and any(mods[j]))
        return 1 + AD_ADJ * n

    def raw():
        return sum(DEPTS[d][0] * LV_MULT[l - 1] * floor_mult(i) for i, d in enumerate(floors) if d != "fusion" for l in mods[i] if l)

    def mult():
        return (1 + hype() / 100) * (1 + 0.10 * shares)

    def income():
        return raw() * mult()

    def nfloors():
        return len(floors) + 1

    def newest():
        un = [d for d, v in DEPTS.items() if nfloors() >= v[3] and d not in ("fusion", "ad")]
        return max(un, key=lambda d: DEPTS[d][0])

    def pick_dept():
        nd = newest()
        if nfloors() >= 3 and draw() + 2 * DEPTS[nd][1] > supply():
            # fusion floors are full or none: open a new fusion floor
            if all(all(mods[i]) and min(mods[i]) == 5 for i, d in enumerate(floors) if d == "fusion") or "fusion" not in floors:
                return "fusion"
        k = len(floors)
        if nfloors() >= 5 and k % 3 == 2:
            return "ad"
        return nd

    while t < minutes * 60:
        sup, drw = supply(), draw()
        m = mult()
        best = None
        for i, d in enumerate(floors):
            inc, dr, cost, _ = DEPTS[d]
            fm = floor_mult(i)
            for k, l in enumerate(mods[i]):
                if l == 5:
                    continue
                c = cost if l == 0 else cost * UP_COST[l - 1]
                if d == "fusion":
                    g = 1e9 if drw + 10 > sup else 0.0
                else:
                    if l == 0 and drw + dr > sup:
                        continue
                    g = inc * (LV_MULT[l] - (LV_MULT[l - 1] if l else 0)) * fm * m
                    if d == "ad":
                        # an ad module lights up neighbours on first module
                        if l == 0 and not any(mods[i]):
                            for j in (i - 1, i + 1):
                                if 0 <= j < len(floors) and floors[j] not in ("ad", "fusion"):
                                    g += AD_ADJ * sum(DEPTS[floors[j]][0] * LV_MULT[x - 1] for x in mods[j] if x) * m
                sc = g / c
                if best is None or sc > best[0]:
                    best = (sc, c, ("mod", i, k))
        if nfloors() < MAX_FLOORS:
            nd = pick_dept()
            c = floor_cost(nfloors() + 1, base, growth)
            g = 1e9 if nd == "fusion" else DEPTS[nd][0] * m
            free_ok = any(l == 0 and d != "fusion" and drw + DEPTS[d][1] <= sup for i, d in enumerate(floors) for l in mods[i])
            sc = 0 if (free_ok and nd != "fusion") else g / (c + DEPTS[nd][2])
            if nd == "fusion" and (drw + 10 <= sup):
                sc = 0
            if best is None or sc > best[0]:
                best = (sc, c, ("floor", nd))
        if hype() < min(HYPE_CAP, 10 * nfloors()):
            for name, cost, hy, cl, mx in PLAZA:
                if plaza[name] < mx and cells() + cl <= PLAZA_CELLS:
                    g = raw() * (1 + 0.10 * shares) * hy / 100
                    sc = g / cost
                    if best is None or sc > best[0]:
                        best = (sc, cost, ("plaza", name))
        if best and best[0] > 0 and best[1] <= cr:
            cr -= best[1]
            a = best[2]
            if a[0] == "mod":
                mods[a[1]][a[2]] += 1
            elif a[0] == "floor":
                floors.append(a[1])
                mods.append([0] * SLOTS)
            else:
                plaza[a[1]] += 1
            continue
        inc = income() * ACTIVE_BONUS
        dt = 1 if inc == 0 else max(1, min(60, (best[1] - cr) / inc if best else 60))
        cr += inc * dt
        earned += inc * dt
        t += dt
        for mk in (3, 5, 8, 10, 12, 15, 18, 20, 25, 30):
            if nfloors() >= mk and mk not in marks:
                marks[mk] = (t, income(), earned)
    return marks, dict(floors=floors, mods=mods, plaza=plaza, income=income(), hype=hype(), earned=earned)


if __name__ == "__main__":
    minutes = float(sys.argv[1]) if len(sys.argv) > 1 else 600
    shares = int(sys.argv[2]) if len(sys.argv) > 2 else 0
    marks, s = run(minutes, base=float(sys.argv[3]) if len(sys.argv) > 3 else 60, growth=float(sys.argv[4]) if len(sys.argv) > 4 else 1.85, shares=shares, keep_plaza=len(sys.argv) > 5)
    for mk, (t, inc, e) in sorted(marks.items()):
        print(f"floor {mk:2d}: {t/60:7.1f} min  income {inc:14,.0f}/s  run earnings {e:.3g}")
    print("final", len(s["floors"]) + 1, "floors, income %.3g/s" % s["income"], "hype", s["hype"], "earned %.3g" % s["earned"])
    print(" ".join(s["floors"]))
    print(s["plaza"])
