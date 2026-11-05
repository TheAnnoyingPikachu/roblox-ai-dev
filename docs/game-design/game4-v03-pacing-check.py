"""Pacing check for Egg Garden v0.3: 19 species, 8 rarities, widened Celestial Egg and the Aurora Egg
(decision 0014, GDD section U). Copied from game4-pacing-check.py (decision 0012) and extended; the
player model is unchanged so the two scripts agree on v0.2 numbers. Planning aid, not shipped.

Part 1 (exact): buy, hatch and release return per egg and weather (Director rule: at most 60% of the
price), and payback seconds per egg (the curve should not fall at the top).
Part 2 (simulated): a good-but-not-perfect player who buys the best egg they can afford and keeps the
best creatures on the pads. Median of RUNS seeds over DAYS days. Stock, offline pay, rewards and XP
follow the GDD. Hands are limited: one hatch or planting per ACTION seconds. Eggs of 5 minutes or
more get 3 waters (15%, 9 XP); weather is a random hatch time, not waiting for events.

Usage: python game4-v03-pacing-check.py            all tables
       python game4-v03-pacing-check.py static     part 1 only
"""
import math
import random
import statistics
import sys

RUNS = 15
DAYS = 90
STEP = 5  # seconds online per tick
ACTION = 10  # seconds of walking and reveal per hatch or planting

# id: price, grow, level, stock (chance, min, max), odds, top, meter, xp, fixed mutation (None = weather roll)
EGGS = {
    # Director's meadow was bunny 5000, frog 2500, duck 1500, pup 800: the spec's Lucky Meter bound gives 62.1% in Rainbow Shower.
    "meadow": (50, 30, 1, None, [("bunny", 5800), ("frog", 2400), ("duck", 1100), ("pup", 500), ("lamb", 100), ("cat", 100)], "cat", 50, 10, None),
    "forest": (400, 180, 2, (100, 2, 4), [("frog", 3000), ("pup", 3000), ("lamb", 1500), ("cat", 1700), ("owl", 500), ("hedgehog", 300)], "hedgehog", 30, 25, None),
    "sunset": (3000, 900, 5, (60, 1, 2), [("cat", 3500), ("owl", 2500), ("hedgehog", 1500), ("fox", 1700), ("turtle", 300), ("deer", 300), ("panda", 200)], "panda", 40, 60, None),
    "moon": (25000, 3600, 10, (30, 1, 1), [("fox", 4000), ("turtle", 2500), ("deer", 1500), ("panda", 1000), ("lion", 600), ("unicorn", 350), ("dragon", 50)], "dragon", 100, 150, None),
    "star": (200000, 14400, 18, (10, 1, 1), [("turtle", 3000), ("panda", 2500), ("lion", 2500), ("unicorn", 1500), ("dragon", 400), ("phoenix", 100)], "phoenix", 25, 400, None),
    "celestial": (1_000_000_000, 28800, 25, (5, 1, 1), [("lion", 6000), ("unicorn", 2500), ("dragon", 1200), ("phoenix", 300)], "phoenix", 10, 1000, "celestial"),
}
# Proposed (decision 0014). The Director's price was 25,000,000,000: first Aurora on day 25 at 60 min/day,
# 15 days after the first Celestial (target 4 to 10). Level is not the gate (Level 32 comes on day 11).
AURORA = {"price": 5_000_000_000, "grow": 43200, "level": 32, "chance": 3, "meter": 20, "xp": 3000}
AURORA_ODDS = [("dragon", 3500), ("phoenix", 3000), ("whale", 2000), ("kirin", 1200), ("axolotl", 300)]
AURORA_TOP = "axolotl"

RATE = {
    "bunny": 1, "frog": 2, "duck": 3,
    "pup": 5, "lamb": 8, "cat": 12,
    "owl": 30, "hedgehog": 45, "fox": 70,
    "turtle": 180, "deer": 250, "panda": 350,
    "lion": 500, "unicorn": 800,
    "dragon": 1500, "phoenix": 2500,
    "whale": 5000, "kirin": 7500,
    "axolotl": 25000,
}
MUT = {"normal": 1, "golden": 3, "moonlit": 5, "rainbow": 10, "celestial": 20}
SIZES = [("normal", 1.0, 8000), ("big", 1.5, 1700), ("huge", 2.5, 300)]
WEATHER = {
    "clear": [("normal", 9790), ("golden", 200), ("rainbow", 10)],
    "sunbeam": [("normal", 7450), ("golden", 2500), ("rainbow", 50)],
    "moonfall": [("normal", 7750), ("golden", 200), ("moonlit", 2000), ("rainbow", 50)],
    "shower": [("normal", 8500), ("golden", 500), ("rainbow", 1000)],
}
WEEKDAY = [("clear", 5500), ("sunbeam", 2500), ("moonfall", 1500), ("shower", 500)]
BEDS = {4: 500, 5: 2000, 6: 8000, 7: 25000, 8: 75000, 9: 200000, 10: 500000, 11: 1200000, 12: 3000000}
OFFLINE_CAP = 28800
RELEASE_SECONDS = 6
DAILY_MINUTES = [2, 3, 4, 5, 6, 8, 15]
QUEST_MINUTES = 4.5  # pool average, 3 a day
WEEKLY_MINUTES = 30
SIZE_AVG = sum(m * bp for _, m, bp in SIZES) / 10000


def aurora_egg(a=AURORA):
    return (a["price"], a["grow"], a["level"], (a["chance"], 1, 1), AURORA_ODDS, AURORA_TOP, a["meter"], a["xp"], None)


def species_avg(odds, top=None, meter=None):
    """Average base rate; with a meter, the exact long-run top-species share under the Lucky Meter."""
    p = {s: bp / 10000 for s, bp in odds}
    if top is None:
        return sum(RATE[s] * q for s, q in p.items())
    q = p[top]
    cycle = (1 - (1 - q) ** meter) / q  # expected hatches per top species
    share = 1 / cycle
    rest = 1 - q
    return share * RATE[top] + (1 - share) * sum(RATE[s] * v / rest for s, v in p.items() if s != top)


def mut_avg(weather):
    return sum(MUT[m] * bp / 10000 for m, bp in WEATHER[weather])


def static_tables(a=AURORA):
    print("Part 1: exact checks. Return = expected release coins / price (Lucky Meter included).")
    print("'bound' is the worst weather with the Lucky Meter bounded as tests/GardenRules.spec.luau does (top rate / meter).")
    print(f"{'egg':10}{'price':>16}{'clear':>8}{'sunbeam':>9}{'moonfall':>9}{'shower':>8}{'bound':>8}{'avg coins/s':>13}{'payback s':>12}")
    worst = 0
    eggs = dict(EGGS, aurora=aurora_egg(a))
    event = sum(mut_avg(w) * bp / 10000 for w, bp in WEEKDAY) / 2 + mut_avg("clear") / 2
    for egg, (price, _, _, _, odds, top, meter, _, fixed) in eggs.items():
        assert sum(bp for _, bp in odds) == 10000, egg
        base = species_avg(odds, top, meter) * SIZE_AVG
        bounded = (species_avg(odds) + RATE[top] / meter) * SIZE_AVG
        mult = MUT[fixed] if fixed else None
        row = []
        for w in WEATHER:
            ret = base * (mult or mut_avg(w)) * RELEASE_SECONDS / price
            row.append(ret)
        bound = max(bounded * (mult or mut_avg(w)) * RELEASE_SECONDS / price for w in WEATHER)
        worst = max(worst, bound)
        rate = base * (mult or event)
        print(f"{egg:10}{price:>16,}" + "".join(f"{100 * r:>{n}.1f}%" for r, n in zip(row, (7, 8, 8, 7))) + f"{100 * bound:>7.1f}%{rate:>13,.0f}{price / rate:>12,.0f}")
    print(f"Worst bound {100 * worst:.1f}% (rule: at most 60%).")
    assert worst <= 0.6


class Player:
    def __init__(self, seed, minutes, aurora=AURORA, aurora_on=True):
        self.r, self.seed = random.Random(seed), seed
        self.minutes = minutes
        self.eggs = dict(EGGS)
        if aurora_on:
            self.eggs["aurora"] = aurora_egg(aurora)
        self.coins, self.xp, self.bed_count, self.pen = 100.0, 0, 3, 6
        self.beds = [("starter", 8)]  # (egg, ready time)
        self.pads, self.index = [], set()
        self.pity = {e: 0 for e in self.eggs}
        self.t, self.streak, self.busy = 0, 0, 0
        self.daily_income = []
        self.first = {}

    def level(self):
        return min(50, int(math.sqrt(self.xp / 40)) + 1)

    def income(self):
        return sum(self.pads) * (1 + 0.02 * len(self.index))

    def roll(self, table):
        r = self.r.randint(1, 10000)
        for item, bp in table:
            r -= bp
            if r <= 0:
                return item
        return table[-1][0]

    def hatch(self, egg):
        if egg == "starter":
            s, m, size = "pup", "normal", 1.0
            xp = 10
        else:
            _, _, _, _, odds, top, meter, xp, fixed = self.eggs[egg]
            s = top if self.pity[egg] >= meter - 1 else self.roll(odds)
            self.pity[egg] = 0 if s == top else self.pity[egg] + 1
            weather = "clear" if self.r.random() < 0.5 else self.roll(WEEKDAY)
            m = fixed or self.roll(WEATHER[weather])
            z = self.r.randint(1, 10000)
            size = 2.5 if z > 9700 else 1.5 if z > 8000 else 1.0
        key = s + ":" + m
        if key not in self.index:
            self.index.add(key)
            xp += 50
        self.xp = min(1_000_000, self.xp + xp)
        self.pads.append(RATE[s] * MUT[m] * size)
        self.pads.sort(reverse=True)
        self.pads = self.pads[: self.pen + 1]  # one spare in storage, a reason to buy a slot

    def stock(self, window):
        """Per-player quantities this window, the same for the window (seeded by it)."""
        out = {}
        rng = random.Random(window * 7919 + self.seed)
        for egg, data in self.eggs.items():
            s = data[3]
            if s:
                out[egg] = rng.randint(s[1], s[2]) if rng.randint(1, 10000) <= s[0] * 100 else 0
        return out

    def plant(self, egg, now):
        grow = self.eggs[egg][1]
        self.beds.append((egg, now + grow * (0.85 if grow >= 300 else 1)))
        self.xp = min(1_000_000, self.xp + (9 if grow >= 300 else 0))
        self.busy = now + ACTION

    def spend(self, now, left):
        # Upgrades first when cheap against coins, then the dearest egg that fits a free bed.
        if len(self.beds) >= self.bed_count and self.bed_count < 12 and BEDS[self.bed_count + 1] <= self.coins * 0.6:
            self.coins -= BEDS[self.bed_count + 1]
            self.bed_count += 1
        cost = 300 * 2 ** (self.pen - 6)
        if len(self.pads) > self.pen and self.pen < 20 and cost <= self.coins * 0.6:
            self.coins -= cost
            self.pen += 1
        level = self.level()
        if len(self.beds) < self.bed_count and now >= self.busy:
            options = [
                e for e, d in self.eggs.items()
                if d[0] <= self.coins and level >= d[2] and (d[3] is None or left.get(e, 0) > 0)
            ]
            if not options:
                return
            egg = max(options, key=lambda e: self.eggs[e][0])
            self.coins -= self.eggs[egg][0]
            if egg in left:
                left[egg] -= 1
            self.plant(egg, now)
            self.first.setdefault(egg, now)

    def play_day(self, day):
        online = self.minutes * 60
        now = day * 86400
        away = now - self.t if day else 0
        self.coins += self.income() * 0.5 * min(away, OFFLINE_CAP)
        self.streak += 1
        minutes = DAILY_MINUTES[min(self.streak, 7) - 1]
        self.coins += max(50, self.income() * 60 * minutes)
        window, left = -1, {}
        for tick in range(online // STEP):
            t = now + tick * STEP
            if t // 300 != window:
                window = t // 300
                left = self.stock(window)
            ripe = [b for b in self.beds if b[1] <= t]
            if ripe and t >= self.busy:
                self.beds.remove(ripe[0])
                self.hatch(ripe[0][0])
                self.busy = t + ACTION
            self.coins += self.income() * STEP * 0.9  # 90%: pads are walked, not instant
            self.spend(t, left)
            for mark in (25, 32):
                if self.level() >= mark and f"L{mark}" not in self.first:
                    self.first[f"L{mark}"] = t
        self.t = now + online
        self.daily_income.append(self.income())
        self.coins += self.income() * 60 * QUEST_MINUTES * 3
        if day % 7 == 6:
            self.coins += self.income() * 60 * WEEKLY_MINUTES


def day_of(t, minutes):
    """Day number and online minutes played at time t."""
    day = int(t // 86400)
    return day + 1, day * minutes + (t - day * 86400) / 60


def run(minutes, **kw):
    runs = []
    for seed in range(RUNS):
        p = Player(seed, minutes, **kw)
        for d in range(DAYS):
            p.play_day(d)
        runs.append(p)
    return runs


def median_first(runs, key):
    return statistics.median(p.first.get(key, math.inf) for p in runs)


def fmt(t, minutes):
    if t == math.inf:
        return f">{DAYS}d"
    d, m = day_of(t, minutes)
    return f"{m:.0f}m" if d == 1 else f"day {d}"


INCOME_DAYS = (1, 7, 14, 30, 45, 90)
KEYS = ["moon", "star", "L25", "celestial", "L32", "aurora"]


def pacing(title, minutes, **kw):
    runs = run(minutes, **kw)
    cells = [fmt(median_first(runs, k), minutes) for k in KEYS]
    inc = [statistics.median(p.daily_income[d - 1] for p in runs) for d in INCOME_DAYS]
    print(f"{title:34}" + "".join(f"{c:>8}" for c in cells) + "".join(f"{i:>12,.0f}" for i in inc))
    return runs


def main():
    static_tables()
    if len(sys.argv) > 1:
        return
    print()
    print("Part 2: median first buy ('day N' calendar day, 'Nm' online minutes on day 1), income (coins/s) at end of day.")
    print(f"{'scenario':34}" + "".join(f"{k:>8}" for k in KEYS) + "".join(f"{'inc d' + str(d):>12}" for d in INCOME_DAYS))
    print("v0.3 roster, no Aurora Egg:")
    for minutes in (30, 60, 180):
        pacing(f"  {minutes} min/day", minutes, aurora_on=False)
    print("With the Aurora Egg as proposed:")
    for minutes in (30, 60, 180):
        pacing(f"  {minutes} min/day", minutes)
    print("Aurora price check, 60 min/day (target: 4 to 10 days after the first Celestial; Level 32 is reached before any price is):")
    for price in (2_500_000_000, 5_000_000_000, 7_500_000_000, 10_000_000_000, 25_000_000_000):
        pacing(f"  {price:,}", 60, aurora=dict(AURORA, price=price))


if __name__ == "__main__":
    main()
