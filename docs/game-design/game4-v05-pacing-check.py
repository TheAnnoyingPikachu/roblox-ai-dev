"""Pacing check for Egg Garden v0.5: the login reward tracks (weekly and monthly) with the exclusive
Weekly and Monthly Eggs and their six species (decision 0017, GDD section X3, X4). Copied from
game4-v04-pacing-check.py (charms on); LOGIN = False gives the v0.4 rewards (daily streak + weekly
bonus) on the same seeds, LOGIN = True the v0.5 tracks. Part 1 adds the exclusive eggs' expected value
against the Dash and Wheel per-day budgets. The UI and valley move no coins. Planning aid, not shipped.

Part 1 (exact): buy, hatch and release return per egg and weather, charm expectation included, for all
7 weathers (Director rule: at most 60% of the price in every pair), and payback seconds per egg.
Part 2 (simulated): a good-but-not-perfect player who buys the best egg they can afford and keeps the
best creatures on the pads. Median of RUNS seeds over DAYS days. Stock, offline pay, rewards and XP
follow the GDD. Hands are limited: one hatch or planting per ACTION seconds. Eggs of 5 minutes or
more get 3 waters (15%, 9 XP); weather is a random hatch time, not waiting for events.

Usage: python game4-v05-pacing-check.py            all tables
       python game4-v05-pacing-check.py static     part 1 only
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
    "moth": 55,  # v0.4 event creature (GDD V2)
    # v0.5 login exclusives (GDD X3)
    "puffin": 10, "otter": 50, "capybara": 220,
    "redpanda": 650, "peacock": 2000, "snowleopard": 6000,
}
EXCLUSIVE = ("puffin", "otter", "capybara", "redpanda", "peacock", "snowleopard")
LOGIN = True
# Exclusive eggs: no price, planted free from prizeEggs at any level; grow, odds, top, meter, xp.
LOGIN_EGGS = {
    "weekly": (3600, [("puffin", 6000), ("otter", 3200), ("capybara", 800)], "capybara", 12, 150),
    "monthly": (14400, [("redpanda", 7000), ("peacock", 2500), ("snowleopard", 500)], "snowleopard", 8, 400),
}
# slot -> (sign-in count, coins base, minutes) or (sign-in count, egg id). Extra slots also grant a cosmetic (no coin value).
WEEK_TRACK = [(1, 100, 3), (2, 150, 5), (3, 200, 8), (4, 300, 12), (5, "weekly"), (6, 400, 15), (7, 500, 20)]
MONTH_TRACK = [(3, 200, 10), (7, 300, 20), (12, 500, 30), (18, "monthly"), (22, 600, 40), (26, 800, 50), (30, 1000, 60)]
DASH_MOON_PER_DAY = 3  # prize cap, decision 0012
DASH_MINUTES_PER_DAY = 6  # 6 x scaled(100, 1)
WHEEL_MINUTES_PER_DAY = 30  # 3 spins x scaled(100, 10), decision 0016
CHARMS_ON = True
# weather -> (charm id, multiplier, basis points of hatches in that weather that get it)
CHARM = {"snowfall": ("frosted", 1.5, 2500), "petals": ("blooming", 2.0, 1500), "thunder": ("stormy", 3.0, 1000)}
# Lantern Moth takes 300 bp from one slot of the Forest and Sunset eggs while a rare weather is active.
EVENT = {"forest": ("frog", 300), "sunset": ("cat", 300)}
MILESTONES = {20: 5000, 40: 50000, 60: 1_000_000, 80: 0}  # coins on claim; 80 is an Aurora voucher
MUT = {"normal": 1, "golden": 3, "moonlit": 5, "rainbow": 10, "celestial": 20}
SIZES = [("normal", 1.0, 8000), ("big", 1.5, 1700), ("huge", 2.5, 300)]
WEATHER = {
    "clear": [("normal", 9790), ("golden", 200), ("rainbow", 10)],
    "sunbeam": [("normal", 7450), ("golden", 2500), ("rainbow", 50)],
    "moonfall": [("normal", 7750), ("golden", 200), ("moonlit", 2000), ("rainbow", 50)],
    "shower": [("normal", 8500), ("golden", 500), ("rainbow", 1000)],
    "snowfall": [("normal", 8800), ("golden", 1000), ("moonlit", 150), ("rainbow", 50)],
    "petals": [("normal", 8500), ("golden", 1000), ("rainbow", 500)],
    "thunder": [("normal", 8800), ("golden", 800), ("moonlit", 300), ("rainbow", 100)],
}
WEEKDAY = [("clear", 5200), ("sunbeam", 2500), ("moonfall", 1500), ("shower", 500), ("snowfall", 100), ("petals", 100), ("thunder", 100)]
RARE = ("snowfall", "petals", "thunder")


def weekend(event):
    """Weekend table: the week's event weather gets 1000, the other two rare weathers 200 each (GDD V2)."""
    return [("clear", 2100), ("sunbeam", 3500), ("moonfall", 2000), ("shower", 1000)] + [
        (w, 1000 if w == event else 200) for w in RARE]
BEDS = {4: 500, 5: 2000, 6: 8000, 7: 25000, 8: 75000, 9: 200000, 10: 500000, 11: 1200000, 12: 3000000}
OFFLINE_CAP = 28800
RELEASE_SECONDS = 6
DAILY_MINUTES = [2, 3, 4, 5, 6, 8, 15]
QUEST_MINUTES = 4.5  # pool average, 3 a day
WEEKLY_MINUTES = 30
SIZE_AVG = sum(m * bp for _, m, bp in SIZES) / 10000


def aurora_egg(a=AURORA):
    return (a["price"], a["grow"], a["level"], (a["chance"], 1, 1), AURORA_ODDS, AURORA_TOP, a["meter"], a["xp"], None)


def event_odds(egg, odds, weather):
    if weather in CHARM and egg in EVENT:
        frm, bp = EVENT[egg]
        return [(s, b - bp if s == frm else b) for s, b in odds] + [("moth", bp)]
    return odds


def charm_avg(weather):
    if not CHARMS_ON or weather not in CHARM:
        return 1.0
    _, mult, bp = CHARM[weather]
    return 1 + (mult - 1) * bp / 10000


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
    print("Part 1: exact checks. Return = expected release coins / price (Lucky Meter, charm odds and the Moth included).")
    print("'bound' is the worst of the 7 weathers with the Lucky Meter bounded as tests/GardenRules.spec.luau does (top rate / meter).")
    print(f"{'egg':10}{'price':>16}" + "".join(f"{w:>9}" for w in WEATHER) + f"{'bound':>8}{'avg coins/s':>13}{'payback s':>12}")
    worst, worst_pair = 0, ""
    eggs = dict(EGGS, aurora=aurora_egg(a))
    assert sum(bp for _, bp in WEEKDAY) == 10000 and all(sum(bp for _, bp in weekend(e)) == 10000 for e in RARE)
    assert all(sum(bp for _, bp in t) == 10000 for t in WEATHER.values())
    event = sum(mut_avg(w) * charm_avg(w) * bp / 10000 for w, bp in WEEKDAY) / 2 + mut_avg("clear") / 2
    pins = []
    for egg, (price, _, _, _, odds, top, meter, _, fixed) in eggs.items():
        assert sum(bp for _, bp in odds) == 10000, egg
        mult = MUT[fixed] if fixed else None
        row, bound = [], 0
        for w in WEATHER:
            o = event_odds(egg, odds, w)
            base = species_avg(o, top, meter) * SIZE_AVG
            bounded = (species_avg(o) + RATE[top] / meter) * SIZE_AVG
            row.append(base * (mult or mut_avg(w)) * charm_avg(w) * RELEASE_SECONDS / price)
            b = bounded * (mult or mut_avg(w)) * charm_avg(w) * RELEASE_SECONDS / price
            bound = max(bound, b)
            if b > worst:
                worst, worst_pair = b, f"{egg} {w}"
        base = species_avg(odds, top, meter) * SIZE_AVG
        rate = base * (mult or event)
        pins.append(f'{egg} "{100 * row[0]:.1f} {100 * row[3]:.1f} {100 * max(row[4:]):.1f} {rate:.0f} {price / rate:.0f}"')
        print(f"{egg:10}{price:>16,}" + "".join(f"{100 * r:>8.1f}%" for r in row) + f"{100 * bound:>7.1f}%{rate:>13,.0f}{price / rate:>12,.0f}")
    print(f"Worst bound {100 * worst:.1f}% at {worst_pair} (rule: at most 60%).")
    print("Pins (clear, shower, worst rare weather, avg coins/s, payback s): " + "; ".join(pins))
    login_eggs(event)
    for w in RARE:
        print(f"  {w}: mutation x{mut_avg(w):.3f} * charm x{charm_avg(w):.3f} = x{mut_avg(w) * charm_avg(w):.3f} (Rainbow Shower is x{mut_avg('shower'):.3f})")
    assert worst <= 0.6


def login_egg(egg):
    grow, odds, top, meter, xp = LOGIN_EGGS[egg]
    return (math.inf, grow, 1, None, odds, top, meter, xp, None)


def sold_avg(egg, event):
    price, _, _, _, odds, top, meter, _, _ = EGGS[egg]
    return species_avg(odds, top, meter) * SIZE_AVG * event


def login_eggs(event):
    """Expected coins/s of one hatch of each exclusive egg (Lucky Meter, average weather, size) and the
    per-day value of both tracks against the Dash and Wheel budgets (decisions 0012, 0016)."""
    print()
    print("Login eggs (X3): expected coins/s per hatch and per-day value of the tracks against Dash and Wheel.")
    moon = sold_avg("moon", event)
    ev = {}
    for egg, (grow, odds, top, meter, xp) in LOGIN_EGGS.items():
        assert sum(bp for _, bp in odds) == 10000, egg
        ev[egg] = species_avg(odds, top, meter) * SIZE_AVG * event
        print(f"  {egg:8} grow {grow // 60:>4} min  avg {ev[egg]:>8,.1f} coins/s per hatch"
              f"  (forest {sold_avg('forest', event):,.0f}, sunset {sold_avg('sunset', event):,.0f}, moon {moon:,.0f}, star {sold_avg('star', event):,.0f})")
    wk = sum(t[2] for t in WEEK_TRACK if len(t) == 3)
    mo = sum(t[2] for t in MONTH_TRACK if len(t) == 3)
    old = sum(DAILY_MINUTES) / 7 + WEEKLY_MINUTES / 7
    print(f"  coins as minutes of income per day: weekly track {wk / 7:.1f}, monthly track {mo / 30:.1f}, both {wk / 7 + mo / 30:.1f}"
          f"  (replaced H5 daily streak + weekly bonus at a 7-day streak: {old:.1f}; Dash {DASH_MINUTES_PER_DAY}; Wheel {WHEEL_MINUTES_PER_DAY})")
    eggs_day = ev["weekly"] / 7 + ev["monthly"] / 30
    print(f"  creature value per day from the eggs: {eggs_day:,.1f} coins/s  (Dash prize cap {DASH_MOON_PER_DAY} Moon Eggs = {DASH_MOON_PER_DAY * moon:,.0f} coins/s per day)")
    assert wk / 7 + mo / 30 <= WHEEL_MINUTES_PER_DAY and eggs_day <= DASH_MOON_PER_DAY * moon


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
        self.day, self.t_now, self.charms = 0, 0, 0
        self.prizes, self.exclusive = [], 0
        for e in LOGIN_EGGS:
            self.eggs[e] = login_egg(e)
            self.pity[e] = 0

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
            table = WEEKDAY if self.day % 7 < 5 else weekend(RARE[(self.day // 7) % 3])
            weather = "clear" if self.r.random() < 0.5 else self.roll(table)
            s = top if self.pity[egg] >= meter - 1 else self.roll(event_odds(egg, odds, weather))
            self.pity[egg] = 0 if s == top else self.pity[egg] + 1
            m = fixed or self.roll(WEATHER[weather])
            z = self.r.randint(1, 10000)
            size = 2.5 if z > 9700 else 1.5 if z > 8000 else 1.0
            if CHARMS_ON and weather in CHARM and self.r.randint(1, 10000) <= CHARM[weather][2]:
                size *= CHARM[weather][1]
                self.charms += 1
        key = s + ":" + m
        if key not in self.index:
            self.index.add(key)
            xp += 50
            if len(self.index) in MILESTONES:
                self.coins += MILESTONES[len(self.index)]
                self.first.setdefault(f"I{len(self.index)}", self.t_now)
        self.xp = min(1_000_000, self.xp + xp)
        if s in EXCLUSIVE:
            self.exclusive += 1
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
        if self.prizes and len(self.beds) < self.bed_count and now >= self.busy:
            self.plant(self.prizes.pop(0), now)  # a free egg is planted before anything is bought
            return
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
        self.day = day
        away = now - self.t if day else 0
        self.coins += self.income() * 0.5 * min(away, OFFLINE_CAP)
        if LOGIN:
            self.login(day)
        else:
            self.streak += 1
            minutes = DAILY_MINUTES[min(self.streak, 7) - 1]
            self.coins += max(50, self.income() * 60 * minutes)
        window, left = -1, {}
        for tick in range(online // STEP):
            t = now + tick * STEP
            self.t_now = t
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
        if not LOGIN and day % 7 == 6:
            self.coins += self.income() * 60 * WEEKLY_MINUTES

    def login(self, day):
        """Daily sign-in (day 0 is a Monday and the 1st; months of 30 days): the slot whose sign-in count
        is reached today pays coins as minutes of income (floor: the base) or queues the egg."""
        for track, count in ((WEEK_TRACK, day % 7 + 1), (MONTH_TRACK, day % 30 + 1)):
            for slot in track:
                if slot[0] == count:
                    if len(slot) == 2:
                        self.prizes.append(slot[1])
                    else:
                        self.coins += max(slot[1], self.income() * 60 * slot[2])


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
KEYS = ["moon", "star", "celestial", "aurora", "I20", "I40", "I60", "I80"]


def pacing(title, minutes, **kw):
    runs = run(minutes, **kw)
    cells = [fmt(median_first(runs, k), minutes) for k in KEYS]
    inc = [statistics.median(p.daily_income[d - 1] for p in runs) for d in INCOME_DAYS]
    excl = statistics.median(p.exclusive for p in runs)
    index = statistics.median(len(p.index) for p in runs)
    print(f"{title:28}" + "".join(f"{c:>8}" for c in cells) + "".join(f"{i:>12,.0f}" for i in inc) + f"{excl:>6.0f}{index:>6.0f}")
    return runs


def main():
    static_tables()
    if len(sys.argv) > 1:
        return
    print()
    print("Part 2: median first buy or Index milestone ('day N' calendar day, 'Nm' online minutes on day 1), income (coins/s) at end of day, exclusive creatures hatched and Index size at day 90.")
    print(f"{'scenario':28}" + "".join(f"{k:>8}" for k in KEYS) + "".join(f"{'inc d' + str(d):>12}" for d in INCOME_DAYS) + f"{'excl':>6}{'index':>6}")
    global LOGIN
    LOGIN = False
    print("v0.4 rewards (daily streak + weekly bonus, charms on):")
    for minutes in (30, 60, 180):
        pacing(f"  {minutes} min/day", minutes)
    LOGIN = True
    print("v0.5 login tracks (a player who signs in every day: 7/7 and 30/30):")
    for minutes in (30, 60, 180):
        pacing(f"  {minutes} min/day", minutes)


if __name__ == "__main__":
    main()
