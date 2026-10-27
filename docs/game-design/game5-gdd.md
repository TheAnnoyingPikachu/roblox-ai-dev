# Neon Spire: game design spec (v0.1)

Status: draft for SHANNON (SPIRE-001). Working title. Game 5: a cyberpunk tycoon about building a corporate megatower and its plaza. Needs decision records 0009 (economy, saves, remotes; CLAUDE.md rule 8) and 0010 (asset approach; rule 9 and SHANNON's per-game asset approval) before build. Companion documents: `game5-art-bible.md` (look and assets), `game5-production-plan.md` (milestones, gates, risks), `docs/architecture/spire.md` (technical design), `game5-pacing-sim.py` (balance check behind section E).

## A. Product

- **Pitch:** you are the founder of a tiny start-up in a rain-soaked neon megacity. Start with a lobby and one server rack. Stack floors, fill them with machines, keep the power on, and dress your plaza until crowds pour in. Your tower climbs into the skyline where every player in the server can see it. At floor 20, take your company public (IPO) for Shares that make every future tower grow faster.
- **Audience:** players under 18 (studio default, decisions 0002 and 0003). Roblox's built-in filtered chat stays on. No custom chat, no text input, no personal data beyond the saved game profile. No weapons, crime, gambling, drugs or gore: the cyberpunk is in the look (neon, rain, holograms, drones), not in the themes.
- **Platforms:** PC, mobile, console. Every action works with touch, mouse and gamepad. Building is done from menus and a build camera, not by precise 3D dragging.
- **Pillars:**
  1. **Visible growth.** Every purchase changes the tower or plaza on screen within one second, with a short construction effect. The skyline is the scoreboard.
  2. **One clear puzzle at a time.** Power (can I run this?), stacking (what goes next to my ad agency?), plaza space (what fits?). Each is readable from the HUD without maths.
  3. **Always a next goal in under two minutes**, and a big goal for tomorrow (floor 20, the IPO, the crown).
  4. **Polished to the last pixel.** Every button has a sound and a response; every number animates; nothing pops in without an effect. A first-screenshot test (section L) gates the look.
  5. **Fair and kind.** Nothing anyone does can take what you own. No paid advantages (decision 0002). No random loot, no near-misses, no limited-time pressure.
- **Non-goals for v0.1:** stealing or sabotage, trading or gifting, Robux or paid items, custom chat or names, combat, NPC management sims (staff, wages), more than one map, multiple towers per player.
- **Server size:** 6 players, 6 lots.

## B. Core loop

1. **Earn:** every module in your tower earns credits (¢) every second, online automatically.
2. **Build:** in BUILD mode, buy modules for empty slots, upgrade them (levels 1 to 5), and buy the next floor. Each new floor asks you to pick a department.
3. **Power:** most modules draw power. When you run out, build a Fusion Core floor. The power bar shows the headroom.
4. **Stack:** Holo Ad Agency floors boost the floors directly above and below them. Where you put them matters.
5. **Plaza:** place items on your plaza grid. Each item adds Hype; Hype multiplies all income (capped by your tower's height). Crowds, drones and lights in your plaza grow with it.
6. **React:** catch Hot Data sparks on your floors (a bonus of 30 seconds of income), and plan around the city-wide Market Pulse events.
7. **IPO:** at floor 20 or higher, reset the tower for permanent Shares (+10% income each). Plaza, cosmetics and level stay.

**Target pacing** (from `game5-pacing-sim.py`, a greedy player catching about half the Hot Data; hypothesis to confirm in playtests):

| Milestone | First run (active play) | Second run (10 Shares, plaza kept) |
|---|---|---|
| Floor 3 (Fusion Core unlocks) | 2 min | 1 min |
| Floor 5 (Ad Agency unlocks) | 3.5 min | 1 min |
| Floor 8 (Synth Lab) | 10 min | 2.5 min |
| Floor 10 | 18 min | 6 min |
| Floor 15 | 35 min | 13 min |
| Floor 20 (IPO available) | 86 min | 31 min |
| Floor 25 | 3 h | 77 min |
| Floor 30 (Spire Crown) | about 19 h | about 9.5 h |

Offline income (E4) roughly halves these in calendar time for players who return daily. Floor 30 on the first run is a week-long goal, not a session goal.

## C. Lot and tower

Each player is given the lowest-numbered free lot (1 to 6) on join and spawns in its lobby. The saved company is position-independent and is rebuilt on whichever lot the player gets. Rules live in `TowerRules` (pure).

### C1. Lot layout

- A lot is 64 × 92 studs: a tower footprint of 36 × 36 at the back and a private plaza of 48 × 32 at the front, facing the shared Grid Plaza.
- Floor 1 is the **Lobby** (height 20 studs), always present: the lift, the company logo wall, the Vault display (shows income), and the BUILD terminal.
- Floors 2 to 30 are **department floors**, 14 studs each. The top of floor 30 is at 426 studs, plus the crown.

### C2. Floors

- `floors` counts owned floors including the lobby: 1 to 30. A new profile has 2 (lobby and one Data Farm floor).
- Floor `n` (2 to 30) costs, in credits:

| n | Cost | n | Cost | n | Cost |
|---|---|---|---|---|---|
| 2 | (free, new profile) | 12 | 127,000 | 22 | 267,000,000 |
| 3 | 129 | 13 | 272,000 | 23 | 575,000,000 |
| 4 | 277 | 14 | 585,000 | 24 | 1,240,000,000 |
| 5 | 596 | 15 | 1,260,000 | 25 | 2,660,000,000 |
| 6 | 1,280 | 16 | 2,710,000 | 26 | 5,710,000,000 |
| 7 | 2,760 | 17 | 5,820,000 | 27 | 12,300,000,000 |
| 8 | 5,930 | 18 | 12,500,000 | 28 | 26,400,000,000 |
| 9 | 12,700 | 19 | 26,900,000 | 29 | 56,800,000,000 |
| 10 | 27,400 | 20 | 57,800,000 | 30 | 122,000,000,000 |
| 11 | 58,900 | 21 | 124,000,000 | | |

  (Generated as `60 × 2.15^(n − 2)` rounded to 3 significant figures; the table is the rule, stored in `SpireConfig`.)
- `buyFloor(dept)` buys floor `floors + 1` with the chosen department. Refused if `floors = 30`, the department is locked (C3), or credits < cost.
- `refitFloor(n, dept)`: changes an empty floor's department (no modules on it). Free. To refit a full floor, sell its modules first.

### C3. Departments

Each floor holds one department and **4 module slots** of that department's module.

| Id | Department | Module | Income per module at L1 (¢/s) | Power draw per module | Module cost (L1) | Lowest floor number it can go on |
|---|---|---|---|---|---|---|
| `data` | Data Farm | Server Rack | 1 | 1 | 15 | 1 (start) |
| `fusion` | Fusion Core | Fusion Cell | – (supplies power, C5) | 0 | 150 | 3 |
| `ad` | Holo Ad Agency | Holo Projector | 6 | 2 | 600 | 5 |
| `synth` | Synth Lab | Bio-Printer | 40 | 4 | 8,000 | 8 |
| `drone` | Drone Port | Courier Drone | 250 | 6 | 150,000 | 12 |
| `quantum` | Quantum Core | Q-Mind | 1,600 | 10 | 3,000,000 | 17 |
| `orbital` | Orbital Uplink | Uplink Dish | 10,000 | 16 | 60,000,000 | 23 |

A department is available for floor `n` (when buying or refitting it) if `n ≥` its number in the last column, so floor 3 can be the first Fusion Core. Locked departments show in the floor picker with "Unlocks at floor 8". Plaza unlocks (D2) use `floors ≥`.

### C4. Modules and levels

- `buyModule(floor, slot)`: places a level-1 module in an empty slot. Refused if the slot is filled, credits < cost, or the power check fails (C5).
- `upgradeModule(floor, slot)`: level `L` to `L + 1` (max 5) costs `cost × UP[L]` with `UP = {2, 5, 12, 30}`. Upgrades never change power draw.
- Income multiplier by level: `LV = {1, 2, 4, 8, 16}`. Fusion supply by level: `{8, 18, 32, 50, 75}`.
- `sellModule(floor, slot)`: removes it and refunds `floor(0.5 × spent)`, where `spent` is the L1 cost plus every upgrade paid (Flash Sale discounts included at the price actually paid). Refused if selling a Fusion Cell would leave draw > supply.
- **Check values:** a Server Rack taken to L5 costs 15 + 30 + 75 + 180 + 450 = 750 and earns 16 ¢/s; selling it refunds 375. A Bio-Printer L3 earns 160 ¢/s.
- Visuals: L1 plain, L2 adds cable runs, L3 adds a neon trim, L4 adds a holo readout, L5 "overclocked" with a particle aura and the slot's neon turns gold.

### C5. Power

- `supply = 6 + Σ fusionSupply[level]` over all Fusion Cells. `draw = Σ draw` over all non-fusion modules.
- A `buyModule` that would make `draw > supply` is refused with "Not enough power: build or upgrade a Fusion Core" and the BUILD panel shows the missing amount.
- The HUD power bar shows `draw / supply`; amber above 80%, red at 100%.
- Power never "browns out": income is never reduced by power. The rule only blocks new modules. This keeps the rule simple and nothing ever breaks while the player is away.
- **Check values:** new profile: supply 6, draw 1. Six Server Racks and nothing else: draw 6, a seventh is refused. One Fusion Cell L1 adds 8.

### C6. Stacking: Ad Agency boost

- An `ad` floor with at least one module gives **+25%** to the module income of each income floor directly above and directly below it (not to other `ad` or `fusion` floors). A floor between two active `ad` floors gets +50%.
- During Neon Night (F) the boost is +50% per neighbour.
- `floorMult(n) = 1 + 0.25 × (active ad neighbours of n)`, 1 for `ad` and `fusion` floors.
- **Check value:** a Data Farm floor with 4 racks at L3 (16 ¢/s) between two active ad floors earns 24 ¢/s before Hype.

## D. Plaza

Rules live in `PlazaRules` (pure).

### D1. Grid

- The private plaza is a grid of **12 × 8 cells**, 4 studs each. Cell `(x, y)`, `x` 0 to 11 left to right, `y` 0 to 7 from the tower door outwards.
- Columns `x = 5` and `x = 6` are the **walkway** to the lobby door and stay empty (80 usable cells).
- An item is placed with `(x, y, r)`, rotation `r` 0 to 3 (quarter turns). Footprint `w × d`, swapped when `r` is odd. Accepted when every cell is in bounds, not the walkway, and not covered by another item.
- At most **60 items** per plaza (part budget).

### D2. Items

Hype items (unlock by `floors ≥`):

| Id | Item | Cost (¢) | Hype | Size | Max | Unlock |
|---|---|---|---|---|---|---|
| `bench` | Neon Bench | 100 | 1 | 1 × 1 | 12 | 2 |
| `palm` | Holo Palm | 800 | 2 | 1 × 1 | 10 | 3 |
| `vending` | Vending Bot | 6,000 | 3 | 1 × 1 | 8 | 5 |
| `noodle` | Noodle Stall | 40,000 | 5 | 2 × 1 | 6 | 7 |
| `arcade` | Arcade Kiosk | 300,000 | 8 | 2 × 2 | 4 | 10 |
| `fountain` | Holo Fountain | 2,500,000 | 12 | 2 × 2 | 2 | 13 |
| `maglev` | Maglev Stop | 20,000,000 | 20 | 3 × 2 | 1 | 17 |
| `billboard` | Mega Billboard | 150,000,000 | 25 | 2 × 1 | 2 | 21 |
| `idol` | Hologram Idol | 1,500,000,000 | 40 | 3 × 3 | 1 | 25 |

Decor items (0 Hype, for expression; unlock by level, cost ≤ 2,000): Street Lamp, Bollard, Planter, Neon Arrow, Cable Arch, Puddle Tile, Trash-Bot, Holo Koi. Max 20 decor in total, inside the 60.

- All hype items together give 252 Hype and need 85 cells, more than the 80 available: players choose.
- `placeItem(id, x, y, r)`: buys and places. `moveItem(uid, x, y, r)`: free. `sellItem(uid)`: refunds `floor(0.5 × cost)`.

### D3. Hype

- `hype = min(Σ item hype, 10 × floors, 200)`. The cap of 10 per floor ("your tower draws the crowd") stops the plaza from carrying the early game.
- `hypeMult = 1 + hype / 100` (×1 to ×3).
- Crowd: the client spawns `min(40, 2 + floor(hype / 5))` walking NPC silhouettes in that plaza (visual only, section L).
- **Check values:** 12 benches and 10 palms at floor 3: raw 32, cap 30, `hypeMult = 1.30`. At floor 20 with every item but the Idol: 212 raw, cap 200, ×3.

## E. Income

Rules live in `SpireEconomy` (pure).

### E1. Formula

```
moduleIncome = baseIncome(dept) × LV[level] × eventMult(dept)
floorIncome  = Σ moduleIncome on the floor × floorMult(floor)
income       = Σ floorIncome × hypeMult × shareMult
shareMult    = 1 + 0.10 × shares
```

`eventMult` is 2 for `data` and `quantum` during Data Boom, else 1 (F).

**Check value:** floors = 6: Data Farm (4 racks L2), Fusion Core (1 cell), Ad Agency (2 projectors L1), Data Farm (4 racks L1), Data Farm (2 racks L1), 30 Hype, 0 Shares. Floor 2: 8 (no ad neighbour: floor 3 is fusion). Floor 4: 12. Floor 5 (above ad floor 4): 4 × 1.25 = 5. Floor 6: 2. Sum 27 × 1.30 = **35.1 ¢/s**.

### E2. Online

- The server adds `income` every second (fractions carried in memory, never lost). Credits are shown with the short format (1.2K, 3.4M, 5.6B, 7.8T, 9.1Qa).
- Visual: a stream of data packets flows from busy floors down the tower into the lobby Vault; the HUD number counts up smoothly (client-side tween between server values).
- There is no collect button or pad: income always lands. (Egg Garden's unbanked pad coins caused review finding M1; this design avoids the class of bug.)

### E3. Hot Data (active bonus)

- While the owner is online, the server schedules a Hot Data spark every 60 to 120 s (uniform, server `Random`) on a random filled non-fusion slot of their tower. One at a time; it lasts 45 s.
- The owner (only) uses the `Grab` prompt within 12 studs: bonus `floor(30 × income)` credits, plus 5 XP. Missing it costs nothing.
- The HUD shows "HOT DATA · Floor 14 · 38 s" with a GO button that rides the lift there (E is reachable in two taps on mobile).
- Expected value if a player catches half: about +12% income; the sim uses +15% for Hot Data and events together.

### E4. Offline

- On load, `offline = floor(baseIncome × 0.5 × min(away, 28,800))` where `baseIncome` is `income` from the saved profile with no event multiplier, and `away = max(0, now − lastSeen)`.
- Shown on a "While you were away" card. Offline pays half rate for up to 8 hours, so being online is always better.
- **Check values:** income 35.1 ¢/s, away 1 h: 63,180. Away 12 h: 505,440 (capped at 8 h).

### E5. Limits

- Credits are clamped to 1e15 and `lifetimeEarned` to 1e18. Short format handles up to `Qa` (1e15).

## F. Market Pulse (server-wide events)

Rules live in `MarketRules` (pure; same scheduling pattern as Egg Garden's `WorldRules`).

- Window `w = floor(unix / 600)` (10 minutes). An event is active for the first 300 s of the window; the rest is Normal. Every server shows the same event at the same time.
- `state = Rng.seed(w, 7077)`, `r = Rng.int(state, 1, 10000)`:

| Day (UTC) | Normal | Data Boom | Neon Night | Flash Sale |
|---|---|---|---|---|
| Monday–Friday | 5500 | 2000 | 1500 | 1000 |
| Saturday, Sunday ("Neon Weekend") | 3500 | 2500 | 2000 | 2000 |

- **Data Boom:** Data Farm and Quantum Core income ×2. Look: green data rain falls from the sky, server racks pulse.
- **Neon Night:** Ad Agency boost +50% per neighbour; every billboard in the city switches to a synchronised light show; heavier rain.
- **Flash Sale:** module purchases and upgrades cost 25% less (`floor(price × 0.75)`), floors and plaza items unchanged. Look: amber "SALE" holograms over every Build terminal.
- Weekday rule as Egg Garden: `weekday = (floor(unix / 86400) + 3) mod 7`, Monday 0.
- **Market board** in the Grid Plaza and a HUD chip show the current event, time left and the next two windows.
- Fairness: events are on a fixed published schedule and repeat; nothing is exclusive.

## G. Company identity (no text input)

- **Name:** chosen from two lists, so no free text and no filtering are needed. Prefixes (24): Neon, Kuro, Vanta, Ion, Hexa, Nova, Chroma, Pulse, Synth, Arc, Zen, Echo, Volt, Lumen, Onyx, Cipher, Flux, Orbit, Prism, Quanta, Riven, Static, Vector, Zero. Suffixes (16): Dynamics, Systems, Industries, Labs, Works, Corp, Networks, Holdings, Robotics, Media, Logic, Foundry, Group, Collective, Sciences, Interactive. 384 names; duplicates across players are fine. A new profile gets a random one; RENAME is free.
- **Logo:** 12 geometric glyphs (built from UI frames and parts, not images) × 8 neon colours.
- **Brand colour:** the tower's neon trim colour, 8 choices from the art bible palette.
- Shown on the tower's rooftop holo-sign, the lobby wall, the plaza sign and the leaderboard.

## H. IPO (prestige)

Available when `floors ≥ 20`. Built in milestone M4 (production plan), after the core loop passes its playtests.

- `ipo()`: `gained = floor(sqrt(runEarned / 10,000,000))`; `shares = min(500, shares + gained)`. Refused if `floors < 20` or `gained < 1`.
- **Resets:** credits to 100, floors to 2 (lobby + Data Farm with no modules), all modules, `runEarned` to 0.
- **Keeps:** plaza items (they count again as Hype once the tower regrows; D3 cap), level and XP, cosmetics, company identity, likes, streaks, lifetime stats.
- **Check values:** `runEarned` 1.13e9 (the sim's floor 20) gives 10 Shares (+100%); 1.08e10 (floor 25) gives 32.
- The IPO screen shows the exact Shares gained, what resets and what stays, and needs a second confirm. A ceremony plays: bell, confetti in brand colours, the tower de-rezzes floor by floor into the lobby.
- **Share milestones** unlock facade skins (1, 10, 30, 75 Shares: Chrome, Carbon, Jade Glass, Prism) and crowns.

## I. Players together and child safety

### I1. What other players can do

- **Visit:** walk into any plaza; ride a visitor lift to the **Sky Deck** on any tower's roof (if its gate is open) and look at the city.
- **Endorse** a company: `endorse(userId)`, once per company per UTC day, at most 30 per day given. Adds 1 to the owner's `endorsements` (shown on their sign). There is no negative action.
- **Announcements:** a city-wide ticker shows milestones (floor 10, 20, 30, an IPO) with the company name only, e.g. "VOLT ROBOTICS reached floor 20!". Display names are not shown on the ticker; the plaza sign shows the owner's display name.
- **Skyline:** every tower in the server is visible from everywhere. Taller is the bragging right.

### I2. Gate (owner setting)

`setGate("open" | "friends" | "closed")`, default `open`. Controls the visitor lift and endorsements, as Egg Garden G2. Plazas are always walkable (they are the street); a closed gate only closes the lift and the Sky Deck.

### I3. Cut on purpose

- No stealing, sabotage, raids or "rob the vault" mechanics (common in tycoons; the cause of distress and exploit pressure; see `game4-concepts.md` G2).
- No trading or gifting (scams; same reasoning as Egg Garden G3).
- No random loot of any kind in v0.1, free or paid.

### I4. Anti-pressure rules (under-18)

1. No Robux, paid items, paid boosts or "2× cash" passes (decision 0002). Any later cosmetic monetisation needs its own decision record, a policy review and SHANNON's approval (production plan, M6).
2. No near-miss effects, slot sounds or "so close!" messages.
3. Nothing exclusive forever; events repeat on a published schedule.
4. Offline income never expires. Only the streak count is lost by missing a day.
5. No pop-up offers, no countdowns except the Market board and Hot Data.
6. **Photosensitivity:** no full-screen flashes; no light flickers faster than 3 per second anywhere; a Reduce Flashing setting (default off) also stops strobes and slows neon pulses.

### I5. Anti-exploit

- Every action is a `Request` decided by the pure rules against the server's own profile; the client sends ids and grid cells only, never amounts, prices or outcomes.
- Prompts (Hot Data, lift, endorse) are server-side `ProximityPrompt.Triggered` with a distance check against the server-side character position.
- Hot Data bonuses are bounded by the server schedule (at most one per 60 s), so speed hacks gain nothing.
- Sell refunds are 50%, so no buy-sell loop gains credits (property test, section R).

## J. Meta game (reused)

| Piece | Source | Plan |
|---|---|---|
| Daily streak, weekly bonus, daily quests, levels, cosmetics unlock/buy/equip, sanitise helpers, day maths | `src/shared/MetaRules.luau` | **Reused** with a Spire config and the `scale` reward hook (rewards scale with income, as Egg Garden H5). |
| Level curve | 0006 | Reused: `floor(sqrt(xp / 40)) + 1`, cap 50. |
| Seeded generator | `src/shared/Rng.luau` | Reused for the Market schedule and Hot Data placement. |
| Profiles: 3-try load, offline mode, coalesced `UpdateAsync` re-apply, session lock | `src/garden/Profiles.luau` (after the GARDEN-006 fixes) | **Copied** with store names `SpireProfile<suffix>` and ordered `SpireBoard<suffix>`. |
| Request router, rate limit | `src/garden/Remotes.luau`, `GardenServer` router | Copied, with the token bucket of decision 0009. |
| Start menu, panels, toasts, gold claim dot, music player, settings | `src/garden-client/Menu.client.luau` | **Forked** and restyled to the cyberpunk UI kit (art bible section 6). |
| Mesh loader | `src/relay/Models.luau` | Reused for the hero props. |

- **XP:** module bought 2, upgrade 2 × new level, floor bought 10 × department tier (data 1 … orbital 6), plaza hype item 5, Hot Data 5, endorsement given 3 (first 10 a day).
- **Contracts (daily quests):** 3 a day, same for everyone, all solo: Buy 10 modules; Upgrade 15 modules; Reach level 5 on a module; Catch 5 Hot Data; Place 3 plaza items; Buy a floor; Earn 1 hour of income (counted from income at claim); Endorse 2 companies. Rewards scale: `max(base, floor(income × 60 × minutes))`.
- **Locker cosmetics:** facade skin, crown (Antenna, Halo Ring, Spire Needle, Holo Logo, Satellite Crown; most unlock by level or Shares, a few by credits), lobby floor style, plaza tile style, trail colour for the player (neon footstep trail).
- **Leaderboards:** "Top Spires" board in the Grid Plaza, global top 10 by `lifetimeEarned` (ordered store, written at most every 120 s when changed). Session leaderstats: Floors and Income.
- **Stats panel:** level, floors, income, lifetime earned, Shares, IPOs, Hot Data caught, endorsements, best tower height.
- **Settings** (client, not saved): music, SFX, Reduce Flashing, rain density (Low/Med/High; Low by default on mobile), camera shake on/off, announcements on/off, How to Play, power and Hype explainer cards.

## K. UI and UX

Full visual spec in `game5-art-bible.md` section 6. Interaction rules here.

### K1. Start menu

Title "NEON SPIRE" in a glitching neon logotype (glitch at most twice per second, I4.6). Tagline "Build to the sky." Background: slow camera crane up a finished showcase tower in the rain, past drones, to the skyline. Buttons: PLAY, LOCKER, REWARDS, STATS, SETTINGS. Gold dot on anything claimable.

### K2. HUD

- Top left: credits (large, counts up), income/s, a small "+30s" pop when Hot Data lands.
- Top centre: Market Pulse chip (event icon, time left, next two).
- Top right: level and XP bar, gold dot, menu.
- Left edge: **power bar** (draw/supply, colour by headroom) and **Hype bar** (hype/cap, shows "cap 60 · build higher to raise it").
- Bottom right: **BUILD** (big), **LIFT**, **HOME**.
- Hot Data toast with GO.
- Mobile: buttons at least 56 × 56 px, nothing important within 20% of the bottom-left (thumbstick). Console: every button reachable with the d-pad; selection ring in cyan.

### K3. Build mode (the heart of the game)

- **Tower view:** the camera swings out to a 3/4 view of the player's own tower; the front facade fades to a holographic wireframe so the floors read as a cross-section. Swipe, scroll or right-stick to move up and down; the current floor is highlighted.
- Tap a floor to open its **floor card**: department, 4 slots as module cards (level pips, income, BUY / UPGRADE with price, SELL in a long-press or a second menu), the floor's Ad boost, and a live preview: "+40 ¢/s · Power 34/50 → 38/50".
- Top of the tower: a ghost floor "BUY FLOOR 9 · 12.7K" opens the **department picker** (cards with icon, income, draw, cost, short description, lock reason).
- Buttons that cannot succeed are shown greyed with the reason ("Need 2 more power"), never hidden. Prices that cannot be afforded show in red with "in 0:42" (time to afford at current income).
- **Plaza view:** top-down camera over the plaza grid. Palette of item cards along the bottom; tap one, then tap a cell to see a ghost (cyan when valid, magenta with the reason when not); ROTATE and PLACE buttons; PC shortcuts R (rotate), Esc (cancel); gamepad d-pad moves the cell. Tap a placed item: MOVE, ROTATE, SELL.
- Every preview number comes from the same pure modules the server uses, so the preview never disagrees with the result.
- Exit with BACK or Esc; the camera returns to the character.

### K4. Lift

- Lift pads in every lobby. Owner: any owned floor or the roof. Visitor (gate open): Sky Deck only.
- Ride: 0.6 s door close, screen-edge motion blur and a whoosh, floor counter ticks, doors open on the new floor. The server teleports the character (decision 0009 checks); the client hides the cut with the transition.

### K5. First session script (timed, acceptance S)

| Time from PLAY | What the player sees | Goal |
|---|---|---|
| 0 s | Camera flies from the skyline into their lobby; logo wall shows their generated name | Ownership |
| 5 s | Arrow to the BUILD terminal: "Your first server rack is waiting" | |
| ≤ 15 s | Buys a Server Rack (15 ¢ of the starting 100) in a guided floor card; data packets start flowing | First income |
| ≤ 45 s | Buys 3 more racks; "Upgrade one" prompt | |
| ≤ 2 min | Buys floor 3, sees the Fusion Core unlock card and the power bar explainer | Second puzzle |
| ≤ 3 min | First Hot Data, guided GO button | Active bonus |
| ≤ 4 min | Plaza tab opens; places a Neon Bench; crowd NPCs appear | Third puzzle |
| ≤ 6 min | Floor 5: Ad Agency unlock card with the stacking explainer | |

Each prompt disappears once done; nothing blocks the player from ignoring it.

### K6. Juice list (each item is an acceptance check in SPIRE-007)

Floor bought: a holographic scaffold sweeps up in 1.2 s, then panels materialise from the bottom with sparks, a bass thump and a short camera nudge. Module bought: drone flies in with it. Upgrade: ring flash in the level colour. Level 5: gold neon and a chord. Hype change: crowd count eases up or down. Credits: smooth count-up, `+` pops at 1 Hz near the counter. Refusal: soft buzz and the reason in a toast, never a silent no. Every button: hover/press scale (1.04 / 0.96) and a click sound.

### K7. Accessibility

Colour is never the only signal (power bar has a number and an icon; valid/invalid ghost has a ✓/✕ shape). Text at least 18 px on mobile, high contrast against dark panels. Reduce Flashing and camera-shake settings (I4.6, J). All tutorials can be reopened from How to Play.

## L. World and art plan (summary)

Full spec in `game5-art-bible.md`.

- **Setting:** "Vantage City", a permanent rainy night. Six lots on a ring around the shared **Grid Plaza** (spawn area, Market board, Top Spires board, Contracts kiosk, maglev station). Beyond the lots: an elevated maglev loop, highway lanes with hover-traffic (client-only), and a megacity backdrop of 200 to 600-stud towers built from textured boxes with lit window patterns, plus a blimp with a rotating ad.
- **Asset approach:** decision 0010 (proposed): procedural primitives for the tower shell, plaza grid, city and effects; Blender (the studio's headless pipeline from Night) for hero props and module models, with AI mesh generation as a fallback. Needs SHANNON's approval.
- **Budgets:** client parts ≤ 12,000 in view; server-owned parts ≤ 4,000; tower exteriors ≤ 20 parts per floor; interiors built only near the camera (architecture section 5).
- **First-screenshot test:** the start-menu frame shows at least three towers of different heights with lit brand colours, rain streaks, a wet reflective plaza with crowds, holo billboards, flying traffic and a skyline. Reviewed by SHANNON (acceptance S).

## M. Audio

- Music: synthwave or dark electronic tracks from the Roblox audio library (APM or other Roblox-licensed partners): two for normal play, one heavier for Neon Night, a calm one for the menu, an IPO fanfare. Picked by SHANNON from a shortlist; registered before use.
- Ambience: rain loop, distant traffic hum, crowd murmur (volume follows Hype), neon buzz near signs.
- SFX: UI click/hover, purchase, refusal buzz, construction thump, drone whirr, Hot Data chime, lift whoosh, upgrade chimes rising by level, event stingers.

## N. Saved profile (schema v1, store `SpireProfile<suffix>`)

```
{ schemaVersion, xp, credits, lifetimeEarned, runEarned, lastSeen,
  floors = { { d, m = { l1, l2, l3, l4 }, s = { s1, s2, s3, s4 } } },  -- dept id; slot levels (0 empty); spent per slot
  plaza = { nextUid, items = { { u, id, x, y, r, paid } } },
  shares, ipos, hotCaught, endorsements, gate,
  company = { p, s, glyph, colour, trim },
  cosmetics = { skin, crown, lobby, tiles, trail }, owned,
  endorsed = { day, ids }, daily = { streak, last }, week = { key, days, lastDay, claimed },
  quests = { day, progress, claimed },
  session = { id, at } }                                          -- session lock (decision 0009)
```

- Sanitising (`SpireProgress.sanitize`): numbers floored and clamped; `floors` list length 1 to 30, floor 1 always `lobby`, unknown department → empty floor of `data`; slot levels 0 to 5; `spent` clamped to the real maximum for that level; draw > supply after sanitising → highest-draw modules removed and refunded at `spent` until it fits; plaza items with unknown ids, out-of-bounds, walkway or overlapping cells dropped (later items lose), count capped at 60; `company` fields out of range → defaults; cosmetics unknown or locked → defaults; `lastSeen` in the future → now; `shares` 0 to 500.
- Estimated encoded size: 30 floors × about 40 bytes + 60 items × about 45 bytes + meta about 1.5 KB ≈ 5.4 KB (under 2% of the 4 MB key limit). To log in SPIRE-005, as GARDEN-004 did.
- Writes: coalesced `UpdateAsync` re-apply, at most one per player per 7 s, 60 s autosave, final write on leave and in `BindToClose`, session lock taken on load. Details in decision 0009.

## O. Remote contract (for decision 0009)

- `ReplicatedStorage.SpireRemotes.Request` (RemoteFunction): `Request(action: string, arg: string?) -> (boolean, string?)` returning ok and a refusal code for the toast. Common checks: loaded session; `action` a string; `arg` nil or a string of at most 40 characters; token bucket of 6 requests, refilled 4 per second, per player; known action; a non-nil `arg` to an action that takes none is refused.

| Action | `arg` format (Lua pattern) | Accepted when |
|---|---|---|
| `buyFloor` | dept id `^%l+$` | C2 |
| `refitFloor` | `^(%d+):(%l+)$` floor, dept | C2 (floor ≥ 2, owned, no modules) |
| `buyModule` | `^(%d+):([1-4])$` floor, slot | C4, C5 |
| `upgradeModule` | `^(%d+):([1-4])$` | C4 |
| `sellModule` | `^(%d+):([1-4])$` | C4 |
| `placeItem` | `^(%l+):(%d+):(%d+):([0-3])$` id, x, y, r | D1, D2 |
| `moveItem` | `^(%d+):(%d+):(%d+):([0-3])$` uid, x, y, r | D1 (ignores its own cells) |
| `sellItem` | `^(%d+)$` uid | owned |
| `lift` | `^(%d+)$` floor, or `roof` | K4; character within the lobby lift pad zone or an owned floor's lift zone |
| `home` | nil | has a character |
| `endorse` | `^(%d+)$` UserId | I1, target in server, not self, gate allows |
| `setGate` | `open`, `friends`, `closed` | always |
| `setCompany` | `^(%d+):(%d+):(%d+):(%d+)$` prefix, suffix, glyph, colour (1-based list indices) | indices in range |
| `ipo` | nil | H (M4 only) |
| `claimDaily`, `claimWeekly` | nil | MetaRules |
| `claimQuest` | quest id | MetaRules |
| `buyCosmetic`, `equipCosmetic` | cosmetic id | MetaRules |

- **Prompts** (server `Triggered`): Hot Data `Grab` (owner, 12 studs, spark active), visitor lift (gate check), BUILD terminal opens the client build mode (no server effect).
- `ReplicatedStorage.SpireRemotes.Fx` (RemoteEvent, server to clients, display only): `built {lot, floor, slot?, kind}`, `hot {lot, floor, slot, until}`, `grabbed {lot, amount}`, `ticker {company, text}`, `endorse {lot}`, `ipo {lot}`. The server ignores `Fx.OnServerEvent`.
- `ReplicatedStorage.SpireStatus` (StringValue, JSON, written on change and each second): `{ event, eventLeft, forecast = { kind, kind } }`.
- **Lot attributes:** each lot model `Owner` (UserId), `State` (JSON of the public tower and plaza: floors, levels, plaza items, company, cosmetics), written on change at most 4 times per second. Every client builds the visuals from it.
- **Player attributes:** `Profile` (JSON, own player only reads), `ProfileOnline`, `Credits`, `Income`, `Floors`, `Lot`, `OfflineCredits`.

## P. Edge cases and disconnects

- **Clock:** server `os.time()` (UTC) everywhere; `away` never negative.
- **Two servers at once:** session lock on the stored record (Egg Garden's GARDEN-006 fix, decision 0009); a server that cannot take the lock runs the session offline and tells the player.
- **Event boundary:** event read at the instant the server accepts a request; the chip can be up to 1 s behind. Flash Sale price shown on a card that changes while it is open is re-read on BUY; the server is the truth and the toast shows the price actually paid.
- **Sell during Data Boom:** refunds use `spent`, unaffected by events.
- **Lot full:** 6 players and 6 lots (Max Players must be 6 in place settings, as Egg Garden). The leaver's lot is freed before their final write.
- **Leave during a lift ride:** nothing to save; the character is removed.
- **Owner leaves while visitors are on their roof:** visitors are moved to the Grid Plaza with a toast before the tower is removed.
- **Crash:** the last autosave holds `credits` and `lastSeen`; at most 60 s of online income is paid at the offline rate instead.

## Q. Scope for v0.1 and cut order

In: 30 floors, 7 departments, module levels, power, ad stacking, plaza with 9 hype and 8 decor items, Hot Data, Market Pulse with 3 events, offline, company identity, endorse, gate, lift, Sky Deck, all meta hallmarks, the world in `game5-art-bible.md`. IPO lands in M4 after the core passes.

**Cut order if the cycle runs long:** Orbital Uplink (cap at floor 25); decor items beyond four; Sky Deck; `friends` gate option; Neon Weekend table; trail cosmetic; refit (players sell modules instead). Never cut: build mode polish, power, stacking, plaza Hype, saves, Hot Data, the first-session script.

## R. Module plan and unit tests

New pure modules in `src/shared/` (no Roblox APIs), each with `tests/<Module>.spec.luau` registered in `tests/run.luau`:

| Module | Contents | Tests (beyond every rule's check values) |
|---|---|---|
| `SpireConfig` | departments, floor costs, levels, plaza items, events, names, glyphs, cosmetics, quests (data only) | floor cost table matches C2; unlock floors strictly increase; every event row sums to 10,000; ids unique |
| `TowerRules` | `buyFloor`, `refitFloor`, `buyModule`, `upgradeModule`, `sellModule`, `supply`, `draw`, `floorMult`, layout maths (`floorY`, `slotOffset`) | power refusals at the exact boundary; ad boost +25/+50 and not on ad/fusion; Neon Night +50; refund floors; selling a needed Fusion Cell refused |
| `PlazaRules` | grid, rotation, footprint, `placeItem`, `moveItem`, `sellItem`, hype and cap | walkway, bounds and overlap at each edge for every rotation; 60-item cap; hype caps 10 × floors and 200 |
| `SpireEconomy` | `income`, `tick` with fraction carry, `offline`, `hotBonus`, `ipoShares`, `short` | E1 and E4 check values; fraction carry sums exactly over 1,000 ticks; no sequence of buys and sells increases credits + refund value (property test over 10,000 random sequences) |
| `MarketRules` | `eventAt(unix)`, `forecast(unix, n)`, `isWeekend`, `price(price, event)` | same unix gives the same event; active only in the first 300 s; Friday 23:59 / Saturday 00:00 tables; frequencies within 1 point over 20,000 windows |
| `SpireProgress` | MetaRules config, XP table, defaults, `sanitize`, request ops applied to stored records, session lock helpers | every N sanitise rule; defaults (100 ¢, lobby + Data Farm floor, random company); lock claim/hold/stale |
| `SpireBalance` (spec only) | Luau port of `game5-pacing-sim.py` | pacing within ±30% of the B table for floors 5, 10, 15, 20; fails CI if a config change moves them |

## S. Acceptance criteria (v0.1)

- [ ] All unit tests in section R pass in CI, including the balance spec and the buy/sell property test.
- [ ] A new player buys their first module within 15 s of pressing PLAY and reaches floor 3 within 3 minutes (Studio playtest, timed; and staging on a phone).
- [ ] Every K6 juice item is present (checklist with a short screen recording).
- [ ] Build mode works with touch, mouse and gamepad (staging test on a phone and with a controller).
- [ ] Leaving and rejoining after 10 minutes pays the predicted offline amount and keeps every floor, module and plaza item (staging, DataStores on).
- [ ] Two clients: visit, Sky Deck with gate open, blocked with gate closed, endorse once a day.
- [ ] Six full towers (30 floors, 116 modules, 60 plaza items each): server frame time under 8 ms (MicroProfiler); client at least 30 fps on SHANNON's phone with rain on Low and 60 fps on a mid PC.
- [ ] Start-menu screenshot passes the first-screenshot test (L), reviewed by SHANNON.
- [ ] Every mesh, track and SFX has a register row; no Robux prompts, paid items, trading or random loot.
- [ ] The published staging build shows the expected build stamp (production plan, M0) before any playtest note counts.

## T. Kill criteria

- **Greybox feel gate (end of M1):** SHANNON plays 15 minutes on a fresh profile in the greybox and rates it below 4 out of 5, or says the build loop is not fun. Then fix the loop before any art spend; if a second attempt also fails, stop and rethink the concept.
- **Live:** under 60% of new players buy floor 3, or the median first session is under 8 minutes, over the first 500 visits.
- **Live:** under 25% of players who reach floor 10 come back the next day.

## U. Facts, assumptions, hypotheses

- **Fact:** the repo already has `MetaRules`, `Rng`, a session-locked `Profiles` pattern, a forkable start menu and a mesh loader (Egg Garden, Hundred Demon Night, Relay Rounds).
- **Fact:** Egg Garden's review found that money held outside the saved balance (unbanked pads) could be paid twice across a server hop (GARDEN-006 M1). This design credits income directly.
- **Fact:** Bake Rush's staging place showed only a baseplate when SHANNON joined (handoff 2026-10-24); the cause is unresolved. See the production plan, risk R1.
- **Fact:** none of the studio's four games has a recorded staging playtest with notes yet; their tasks are `in_review`.
- **Fact (from decision 0008 and `docs/architecture/garden.md` resolution 5):** the old 6 s per-key DataStore cooldown no longer applies; Egg Garden keeps 7 s coalescing as a write-budget choice, and so does this game.
- **Assumption:** the current per-server DataStore request budgets cover 6 players at one write per 7 s plus leaderboard writes every 120 s. Re-check against the Creator Docs limits page in SPIRE-003.
- **Assumption:** client-built tower visuals from a JSON state attribute replicate cheaply enough (state changes a few times a minute per lot, about 2 to 6 KB each).
- **Assumption:** a 426-stud tower with 20 exterior parts per floor renders at 30 fps on mid phones when interiors are built only near the camera.
- **Assumption:** "Cyberpunk" is a registered trademark of CD Projekt for its games; we use it as a genre word in descriptions only, not in the title or logo.
- **Hypothesis:** the power bar plus the ad stacking give enough decisions to keep building interesting through floor 20.
- **Hypothesis:** the growing skyline, visible to the whole server, motivates more than a leaderboard.
- **Hypothesis:** Hot Data at 60 to 120 s keeps players moving through their tower without feeling like a chore.
- **Hypothesis:** the pacing in B (IPO in about 90 minutes of play) hits a first prestige on day 2 for most players.

## V. Open questions (for SHANNON)

Listed with recommendations in `game5-production-plan.md` section 9.
