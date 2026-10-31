"""Pacing check for Egg Garden v0.2: Celestial Egg and the Splash Dash prize (decision 0012).
Planning aid, not shipped. Numbers are copied from src/shared/GardenConfig.luau; the proposed ones
are in CELESTIAL, MOON_PRIZE_LEVEL and friends below.

Part 1 (exact): buy, hatch and release return per egg and weather (Director rule: at most 60% of the
price), and payback seconds per egg (the curve should not fall at the top).
Part 2 (simulated): a good-but-not-perfect player who buys the best egg they can afford and keeps the
best creatures on the pads. Median of RUNS seeds. Stock, offline pay, rewards and XP follow the GDD.
Hands are limited: one hatch or planting per ACTION seconds, because beds, the cart and the reveal
are walked and watched. Eggs of 5 minutes or more get 3 waters (15%, 9 XP); weather is a random hatch
time, not waiting for events. Daily rewards are paid at login, 3 quests and the weekly bonus at the
end of a session.

Usage: python game4-pacing-check.py            all tables
       python game4-pacing-check.py static     part 1 only
"""
import math
import random
import statistics
import sys

RUNS = 15
DAYS = 45
STEP = 5  # seconds online per tick
ACTION = 10  # seconds of walking and reveal per hatch or planting
HOUR_MARKS = (20, 40, 60, 90, 120)  # online minutes on day 1

# id: price, grow, level, stock (chance, min, max), odds, top, meter, xp
EGGS = {
    "meadow": (50, 30, 1, None, [("bunny", 6000), ("frog", 3000), ("pup", 900), ("cat", 100)], "cat", 50, 10),
    "forest": (400, 180, 2, (100, 2, 4), [("frog", 4000), ("pup", 3500), ("cat", 2000), ("owl", 500)], "owl", 30, 25),
    "sunset": (3000, 900, 5, (60, 1, 2), [("cat", 4500), ("owl", 3500), ("fox", 1700), ("turtle", 300)], "turtle", 40, 60),
    "moon": (25000, 3600, 10, (30, 1, 1), [("fox", 5000), ("turtle", 4000), ("lion", 950), ("dragon", 50)], "dragon", 100, 150),
    "star": (200000, 14400, 18, (10, 1, 1), [("turtle", 5500), ("lion", 4000), ("dragon", 500)], "dragon", 25, 400),
}
# Proposed (decision 0012). Director's first suggestion was a price of 2,500,000.
CELESTIAL = {"price": 1_000_000_000, "grow": 28800, "level": 25, "chance": 5, "meter": 10, "xp": 1000, "mult": 20}
MOON_PRIZE_LEVEL = 10
PRIZES_PER_DAY = 3

RATE = {"bunny": 1, "frog": 2, "pup": 5, "cat": 12, "owl": 30, "fox": 70, "turtle": 180, "lion": 500, "dragon": 1500}
MUT = {"normal": 1, "golden": 3, "moonlit": 5, "rainbow": 10}
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


def celestial_egg(c=CELESTIAL):
    return (c["price"], c["grow"], c["level"], (c["chance"], 1, 1), [("lion", 8500), ("dragon", 1500)], "dragon", c["meter"], c["xp"])


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


def static_tables(c=CELESTIAL):
    print("Part 1: exact checks. Return = expected release coins / price (Lucky Meter included).")
    print(f"{'egg':10}{'price':>12}{'clear':>8}{'sunbeam':>9}{'moonfall':>9}{'shower':>8}{'avg coins/s':>13}{'payback s':>11}")
    worst = 0
    eggs = dict(EGGS, celestial=celestial_egg(c))
    event = sum(mut_avg(w) * bp / 10000 for w, bp in WEEKDAY) / 2 + mut_avg("clear") / 2
    for egg, (price, _, _, _, odds, top, meter, _) in eggs.items():
        base = species_avg(odds, top, meter) * SIZE_AVG
        fixed = c["mult"] if egg == "celestial" else None
        row = []
        for w in WEATHER:
            ret = base * (fixed or mut_avg(w)) * RELEASE_SECONDS / price
            row.append(ret)
            worst = max(worst, ret)
        rate = base * (fixed or event)
        print(f"{egg:10}{price:>12,}" + "".join(f"{100 * r:>{n}.1f}%" for r, n in zip(row, (7, 8, 8, 7))) + f"{rate:>13,.0f}{price / rate:>11,.0f}")
    print(f"Worst return {100 * worst:.1f}% (rule: at most 60%).")
    assert worst <= 0.6


class Player:
    def __init__(self, seed, minutes, prizes=0, prize_level=1, cel=CELESTIAL, cel_on=True):
        self.r, self.seed = random.Random(seed), seed
        self.minutes, self.prizes, self.prize_level = minutes, prizes, prize_level
        self.eggs = dict(EGGS)
        self.cel = cel
        if cel_on:
            self.eggs["celestial"] = celestial_egg(cel)
        self.coins, self.xp, self.bed_count, self.pen = 100.0, 0, 3, 6
        self.beds = [("starter", 8)]  # (egg, ready time)
        self.pads, self.index = [], set()
        self.pity = {e: 0 for e in self.eggs}
        self.t, self.streak, self.prize_store, self.busy = 0, 0, 0, 0
        self.daily_income, self.trace = [], {}
        self.first = {}
        self.hatched_cel = 0
        self.income_at = {}

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
            _, _, _, _, odds, top, meter, xp = self.eggs[egg]
            s = top if self.pity[egg] >= meter - 1 else self.roll(odds)
            self.pity[egg] = 0 if s == top else self.pity[egg] + 1
            weather = "clear" if self.r.random() < 0.5 else self.roll(WEEKDAY)
            m = "celestial" if egg == "celestial" else self.roll(WEATHER[weather])
            z = self.r.randint(1, 10000)
            size = 2.5 if z > 9700 else 1.5 if z > 8000 else 1.0
        key = s + ":" + m
        if key not in self.index:
            self.index.add(key)
            xp += 50
        self.xp = min(1_000_000, self.xp + xp)
        rate = RATE[s] * (self.cel["mult"] if m == "celestial" else MUT[m]) * size
        self.hatched_cel += egg == "celestial"
        self.pads.append(rate)
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

    def spend(self, now, left, window):
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
            if self.prize_store > 0 and level >= self.prize_level:
                self.prize_store -= 1
                self.plant("moon", now)
                self.first.setdefault("prize", now)
                return
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
            if egg not in self.first:
                self.first[egg] = now
                self.income_at[egg] = self.income()

    def play_day(self, day):
        online = self.minutes * 60
        now = day * 86400
        away = now - self.t if day else 0
        self.coins += self.income() * 0.5 * min(away, OFFLINE_CAP)
        self.streak += 1
        minutes = DAILY_MINUTES[min(self.streak, 7) - 1]
        self.coins += max(50, self.income() * 60 * minutes)
        self.prize_store += self.prizes
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
            self.spend(t, left, window)
            if tick % 12 == 0 and tick // 12 in HOUR_MARKS and day == 0:
                self.trace[tick // 12] = self.income()
            for mark in (5, 10, 18, 25):
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
    times = [p.first.get(key, math.inf) for p in runs]
    return statistics.median(times)


def fmt(t, minutes):
    if t == math.inf:
        return ">45d"
    d, m = day_of(t, minutes)
    return f"{m:.0f}m" if d == 1 else f"day {d}"


INCOME_DAYS = (1, 2, 3, 7, 14, 45)


def pacing(title, minutes, **kw):
    runs = run(minutes, **kw)
    keys = ["forest", "sunset", "moon", "star", "L18", "L25", "celestial"]
    cells = [fmt(median_first(runs, k), minutes) for k in keys]
    inc = [statistics.median(p.daily_income[d - 1] for p in runs) for d in INCOME_DAYS]
    print(f"{title:38}" + "".join(f"{c:>8}" for c in cells) + "".join(f"{i:>10,.0f}" for i in inc))
    return runs


def first_hours(title, **kw):
    runs = run(180, **kw)
    cells = [statistics.median(p.trace[m] for p in runs) for m in HOUR_MARKS]
    print(f"{title:38}" + "".join(f"{c:>8,.0f}" for c in cells))


def main():
    static_tables()
    if len(sys.argv) > 1:
        return
    heads = ["forest", "sunset", "moon", "star", "L18", "L25", "cel."]
    head = f"{'scenario':38}" + "".join(f"{k:>8}" for k in heads) + "".join(f"{'inc d' + str(d):>10}" for d in INCOME_DAYS)
    print()
    print("Part 2: median first buy ('day N' calendar day, 'Nm' online minutes on day 1), income at end of day.")
    print(head)
    print("Existing eggs only:")
    for minutes in (30, 60, 180):
        pacing(f"  {minutes} min/day", minutes, cel_on=False)
    print("With the Celestial Egg as proposed:")
    for minutes in (30, 60, 180):
        pacing(f"  {minutes} min/day", minutes)
    print("Price check, 60 and 180 min/day (the suggested 2.5M is under 5 minutes of income at level 25):")
    for minutes in (60, 180):
        for price in (2_500_000, 200_000_000, 1_000_000_000, 2_000_000_000):
            pacing(f"  {minutes} min/day, {price:,}", minutes, cel=dict(CELESTIAL, price=price))
    print("Free Moon Eggs, 60 min/day, worst case (3 prizes every day from day 1):")
    for level in (1, 5, MOON_PRIZE_LEVEL):
        pacing(f"  planted from level {level}", 60, prizes=PRIZES_PER_DAY, prize_level=level)
    print()
    print("Day 1 income at online minute, 180 min/day, worst case (3 prizes at the start of day 1):")
    print(f"{'scenario':38}" + "".join(f"{str(m) + 'm':>8}" for m in HOUR_MARKS))
    first_hours("  no prizes")
    for level in (1, 5, MOON_PRIZE_LEVEL):
        first_hours(f"  planted from level {level}", prizes=PRIZES_PER_DAY, prize_level=level)


if __name__ == "__main__":
    main()
