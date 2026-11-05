# Egg Garden: Petal Catch and the Prize Wheel (v0.4 mini-game, decision 0016)

Status: proposed for SHANNON (checkpoint `docs/checkpoints/GARDEN-WHEEL.md`). SHANNON asked for "another small mini game that earns you a random egg from a wheel spin that people can play by themselves". The Studio Director fixed the shape; this file is the design record, written beside `game4-gdd.md` (sections B, C, G, H5, T, U apply unchanged; where this file names a number, this file wins for Petal Catch). Labels: **Fact** (in code or computed), **Assumption**, **Hypothesis**.

Signatures and payloads: `docs/architecture/garden-wheel.md`. Economy values and the schema field: `docs/decisions/0016-garden-petal-catch-wheel.md`.

## W1. Rules at a glance

- **Solo.** One player, one round, no queue and no other player needed. Several players can play at once in the same patch, each in their own round; each sees only their own petals. Pillar 3 (complete alone) holds; nothing in the Index, quests or rewards needs it.
- **Where:** the **Petal Patch**, a 30 × 30 stud fenced corner under a blossom tree just outside the plaza ring, north-west of the Splash Dash ready pad. A **wheel stand** at its front edge carries the "Play" prompt.
- **Play:** a 45 s round. Petals fall from the tree on a seeded rhythm: **pink petal +1**, **golden petal +3** (4 per round), **pinecone −2** (never below 0; no damage, no knockback, nothing scary). Catch them by standing under them with the basket.
- **Earn:** **12 or more** earns one spin of the prize wheel; **24 or more** earns a spin with the **lucky** odds. The round ends on time; a HUD timer is allowed by G4.7 as amended by 0012 (a round's own timer leads to no purchase).
- **Wheel:** 8 wedges: Meadow, Forest, Sunset, Moon, Star, Celestial and Aurora Egg, and a Coins wedge (10 minutes of income, at least 100). The server rolls; the client only animates the wheel to the server's wedge.
- **Prize eggs** go to `prizeEggs[egg] += 1`, the Splash Dash mechanism (T5): planted with PLANT from the egg's own unlock level, no price, no stock check, not tradable, never lost to full beds.
- **Cap:** 3 spins per player per UTC day. After the cap, rounds are unlimited **practice** ("Practice" label, no wheel). Below 12: "Nice try, play again". There is no loss state.

## W2. The Petal Patch

| Thing | Where / size | Build (`WheelWorld.luau`, GARDEN-042; models GARDEN-044) |
|---|---|---|
| Patch | centre **(−40, 0, −52)**, 30 × 30, ground level | Grass square with a low picket fence (parts), two openings on the plaza side; `Workspace.Garden.Wheel` |
| Blossom tree | patch centre, trunk radius 2, canopy 24 across at y 14 to 20 | `Props.sakura` fallback, swapped for `wheel_tree` when uploaded; decor, trunk collides |
| Wheel stand | **(−40, 0, −38)**, front edge, facing the plaza (south) | `wheel_stand` (static) and `wheel_disc` (the 8-wedge disc, 6 studs across, the only moving piece; spun on each client); fallback: a post, a Cylinder disc with 8 coloured wedges from `EGG_COLOURS` |
| Prompt | on the stand, `ActionText` "Play", `ObjectText` "Petal Catch", `MaxActivationDistance` 12, `HoldDuration` 0 | server `ProximityPrompt`, through `admit` and the shared 0.35 s limit, like the ready pad |
| Stand label | BillboardGui above the wheel | text set **client-side** from the player's own `Profile.wheelToday`: "3 spins left today", "2 spins left today", "All 3 spins used today · practice rounds open", "Saving is off on this server · practice only" |
| Basket | held in the right hand during a round | client-only `wheel_basket` on the local character (others do not see it); fallback: a small Cylinder |
| Petals, pinecone | `petal_pink`, `petal_gold`, `pinecone` | client clones from `ReplicatedStorage.NightModels` (`CLIENT_MODELS`); fallbacks: a flattened pink or gold Ball, a brown Ball |

The centre keeps 5 studs from the 315° lamp post (radius 42), 10 from the plot 6 path and clear of plot 6's square (its nearest corner is at radius 85, 320°; plot 6 spans 283° to 317°). **Assumption:** checked by hand against GDD I1; the engineer confirms in Studio and may move the centre by up to 10 studs if a path or lamp collides. The centre is not an economy value.

Players pass through each other in the patch: every character is already in the `Racers` collision group (architecture 4.3a), so two players under the same petal never push each other.

## W3. The round

### W3.1 Schedule (pure, seeded, the same on server and client)

`WheelRules.schedule(seed, startAt)` returns **40 drops**: a fixed composition of **26 pink, 4 golden, 10 pinecones**, shuffled with `Rng` (Fisher–Yates, `Rng.int`), one drop every **1.0 s** from `startAt + 2` (drop 1 at +2, drop 40 at +41). Each drop lands at a seeded spot on a ring **4 to 12 studs** from the trunk (`r = 4 + 8 × sqrt(u)`, angle `2π × v`), so no petal ever falls on the trunk or outside the fence (15). Two `Rng.next` draws per drop after the shuffle.

A fixed composition means **every round can reach lucky**: perfect play scores 26 + 12 = **38**; catching everything including every pinecone scores 38 − 20 = **18**; ignoring the pinecones is the difference between a spin and a lucky spin. **Hypothesis:** a first-time player scores 10 to 16, a practised one 24 to 34. Checked at the greybox feel gate; thresholds are the lever, the composition stays.

### W3.2 Fall and catch geometry

- Canopy height **16**; fall speed **4 studs/s** straight down (the client may add a cosmetic sway of under 0.5 studs; the server's catch uses the straight line).
- **Catch band:** a drop can be caught while its `y` is between **1 and 7** above the patch ground, from **2.25 s to 3.75 s** after its drop time: 1.5 s, so the server's 5 Hz samples see it **7 times**. Below 1 it has landed: a petal settles on the grass, a pinecone rolls to a stop. Nothing is ever shown as a "miss".
- **Caught** when, at a server sample inside the band, the player's root is within **3.5 studs** horizontally of the drop's spot and within −2 to +10 of the patch ground in `y`. A sample may catch more than one drop; each drop is resolved once. About 4 drops are in the air at any time; a walker (16 studs/s) crosses the whole ring in 1.5 s and sees a petal 2.25 s before it can be caught, so every drop is reachable from anywhere in the patch.
- No bounds check on the patch: the ring plus the radius reaches 15.5, so a player a hair outside the fence can catch an edge petal. Harmless; it is their own round.

### W3.3 Scoring and tiers

| Kind | Points | Per round | Feel |
|---|---|---|---|
| Pink petal | +1 | 26 | tick, a small "+1" |
| Golden petal | +3 | 4 | chime, "+3" in gold |
| Pinecone | −2, **floored at 0** | 10 | no sound, a brown "−2", no red, no shake |

`tier` at the end: **`none`** below 12 or in a practice round, **`spin`** at 12 to 23, **`lucky`** at 24 and above.

## W4. The wheel

### W4.1 Wedges and odds (basis points, each column sums to 10,000; economy values, decision 0016)

Order on the disc, clockwise from the pointer: Meadow, Forest, Sunset, Coins, Moon, Star, Celestial, Aurora. The wedges are painted in the egg's own `EGG_COLOURS` pair; Coins is the garden gold (`UI.GOLD`, a coin stack).

| Wedge | Standard | Lucky | Director's standard / lucky | Prize |
|---|---|---|---|---|
| `meadow` | 3,600 | 2,000 | 3,500 / 2,000 | 1 Meadow Egg |
| `forest` | 2,800 | 2,500 | 2,800 / 2,500 | 1 Forest Egg |
| `sunset` | 1,750 | 2,600 | 1,700 / 2,200 | 1 Sunset Egg |
| `moon` | 1,200 | 1,800 | 1,200 / 1,800 | 1 Moon Egg |
| `star` | 400 | 700 | 500 / 1,000 | 1 Star Egg |
| `celestial` | 20 | 25 | 60 / 150 | 1 Celestial Egg |
| `aurora` | 5 | 15 | 15 / 50 | 1 Aurora Egg |
| `coins` | 225 | 360 | 225 / 300 | `scaled(100, 10)`: 10 minutes of income, at least 100 |

**Changed from the Director's odds: star and above are lower**, as the Director's brief asked if the pacing check called for it; it does (W5). Lucky stays luckier than standard on every wedge from Sunset up (Celestial 1 in 400 against 1 in 500, Aurora 1 in 667 against 1 in 2,000) and worse on Meadow and Forest, which is the point of it.

- The server rolls once with `Rng` from its own seed (not the petal seed, so a client that reads its petal seed learns nothing about the wedge) and applies the prize in the same step. `wheelSpin` tells the client the wedge; the client's 3.5 s spin is theatre that ends on that wedge, with a cosmetic offset inside it.
- Odds are published on the wheel panel (G4.2) as percentages for both wheels, with "The lucky wheel is for a score of 24 or more".

### W4.2 Prizes, cap and practice

- An egg wedge: `prizeEggs[egg] += 1` (limit `PRIZE_STORE` 1,000,000), the 0012 store. PLANT works from the egg's own level (Meadow 1, Forest 2, Sunset 5, Moon 10, Star 18, Celestial 25, Aurora 32), no price, no stock check (`GardenRules.plantPrize`, 0012 item 3 applies). Prize eggs cannot be traded or given (G3; the v0.4 trading design excludes `prizeEggs`).
- Coins wedge: `GardenProgress.scaled(p, 100, 10)`, clamped to `MAX_COINS`, paid at once.
- **Cap: 3 spins per player per UTC day**, counted in the new saved field `wheelToday = { day, spins }` (schema v3 together with v0.4; decision 0016). A spin is counted only when a prize is applied, so a practice round never spends one.
- **Eligible** = a saving session (`Profiles.isOnline`) and under the cap, taken at the start of the round like Dash. A round that starts ineligible is a **practice round**: the HUD says "Practice" from the first second, the stand label says why, and the end card says "Practice round · 17 petals" with no wheel. A capped player's new UTC day does not reopen a round already running.
- **Every spin is one `Profiles.apply`** with an idempotent spin id (W6).

## W5. Pacing: expected value per spin (Fact, computed)

Value of an egg = its average hatch income at the GDD U6 rates (coins/s): Meadow 3, Forest 12, Sunset 75, Moon 299, Star 735, Celestial 20,488, Aurora 6,362. The budget: three spins a day must stay under the Dash prize (one Moon Egg, 299) × 2 = **598 coins/s**, so **199.3 per spin**.

| Wheel | Director's odds | Final odds | × 3 spins | In Moon Eggs per spin |
|---|---|---|---|---|
| Standard | 222.3 | **127.0** | 381 | 0.42 |
| Lucky | 486.6 | **189.1** | **567** | 0.63 |

Per wedge, final odds, coins/s: standard meadow 1.1, forest 3.4, sunset 13.1, moon 35.9, star 29.4, celestial 41.0, aurora 3.2; lucky 0.6, 3.0, 19.5, 53.8, 51.5, 51.2, 9.5. The Director's lucky Celestial alone (150 bp × 20,488) was 307 coins/s, over the whole per-spin budget, which is why Celestial and Aurora dropped most.

**By level band** (only eggs the player can plant count now; the rest wait in `prizeEggs` at the egg's level, so the realised value is at most the band's number and the worst band is the last one):

| Band | Plantable wedges | Standard / spin | Lucky / spin | 3 lucky spins |
|---|---|---|---|---|
| Level 1 | meadow | 1.1 | 0.6 | 1.8 |
| 2 to 4 | + forest | 4.4 | 3.6 | 10.8 |
| 5 to 9 | + sunset | 17.6 | 23.1 | 69.3 |
| 10 to 17 | + moon | 53.4 | 76.9 | 230.8 |
| 18 to 24 | + star | 82.8 | 128.4 | 385.1 |
| 25 to 31 | + celestial | 123.8 | 179.6 | 538.8 |
| 32 and up | all | 127.0 | 189.1 | **567.4** |

Under 598 in every band. Worst case assumes 3 lucky spins every day, which needs 24 or more three times a day.

- **Early game (T6 logic):** nothing changes before Level 10 except Meadow, Forest and Sunset eggs, which the player already buys for 50 to 3,000 coins; a free one is worth under a minute of Level 5 income. The Level 10 gate that 0012 chose for the Moon prize holds here by the same rule.
- **Price view (Fact):** by egg price the expected value is 4.5M (standard) to 10.0M (lucky) coins per spin, almost all of it the 1 in 400 Celestial and 1 in 667 Aurora. The Director's brief measures income, not price, and a prize egg cannot be sold, only hatched (release returns at most 60% of a price). A Celestial win is one Celestial Egg about 3 days earlier than the day-10 purchase at Level 25; at Level 25 income is about 8,700 coins/s, so the hatch (20,488) is a step, the same step the first bought Celestial is. **Hypothesis:** at 1 in 400 to 1 in 500 spins (about 130 to 170 days of three spins) it is a server story, not a pacing lever. If live data shows otherwise, the lever is these two rows, under a new decision.
- **Coins wedge:** 10 minutes of income at 2.25% to 3.6% a spin is 13 to 22 expected seconds of income per spin; the day-7 streak pays 15 minutes. Not an egg, outside the egg budget.

## W6. Server authority and exploit limits

- **The server owns the round:** seed, start and end times, every catch, the score, the tier, the roll and the prize. All of it is pure rules in `WheelRules` on the server's own **5 Hz root samples**, the Dash pattern (T7): the client sends only `wheelStart` (or uses the prompt). **No remote carries a catch, a position, a score or a wedge.**
- The client renders petals from the seed so what the player sees is what the server scores; a slow connection sees the petal where it is (server time) and the 1.5 s band absorbs the replication delay of the root (about 0.1 to 0.3 s).
- **Spin id:** `spinId = today × 10 + n`, `n` the spin's number that day (1 to 3). The prize op is pure and captures `(today, n, wedge)`; it applies only when `wheelToday.spins == n − 1` for `today` (or the record is on an older day and `n == 1`). Re-applying it on the stored record inside `UpdateAsync` is therefore a no-op once it is in, and the leave flush writes it. Nothing new in `Profiles`.
- **What an exploiter can do:** move faster than a walk and catch every petal (the client is trusted for its own physics, as for pads and Dash). **What they cannot do:** score above 38, earn a wedge they were not rolled, spin more than 3 times a day, affect another player's round, or get anything from a round they leave. Accepted: the prize is capped and the client's physics are already trusted for pads (0008). No speed strike here: a round is 45 s and alone, and a flagged walk would only cost its owner.
- Leaving the server, HOME or `BindToClose` mid-round drops the round with no spin; nothing was earned yet, nothing is lost. A Dash start mid-round teleports the player away; the round runs out with whatever it has.
- **Rate:** `wheelStart` is under the shared 0.35 s limit; a round is refused while one is running, so at most one round per player per 45 s. Petal positions are computed on the server only at the player's samples: 40 drops × 7 band samples is under 300 distance checks per round.

## W7. UI, sounds, art

### W7.1 HUD during a round (`WheelFx`, display only)

- Top centre: **score** (large), the **timer** (`45`, counting down from `endAt` with `GetServerTimeNow`), and a slim progress bar with two marks, "Spin 12" and "Lucky 24", filling with the score (the bar is the score, so a pinecone shrinks it a little; no flash, no red)
- Top right under the bar: "2 spins left today" or "Practice".
- Catch feedback: the petal pops into the basket with a "+1" (pink) or "+3" (gold); a pinecone bounces off the basket with a small brown "−2". No screen shake, no red tint, no sad sound.
- End card (3 s, closes on tap): "Nice catch! 17 petals" then either the wheel panel, or "Nice try, play again" (under 12), or "Practice round" (capped or offline). Never "so close" or "you nearly had it" (G4.3).
- Wheel panel: the disc with 8 painted wedges, the pointer at the top, a "SPIN" button that starts the **pre-decided** animation (3.5 s, 4 turns plus the wedge, ease out, one chime at the stop; no ticking as it slows: G4.3 slot-machine rule), then the prize: "Moon Egg! Saved with your prize eggs. Open DASH to plant it." or "+36,300 coins". Celestial and Aurora get the fanfare and a burst in the egg's colours, a Legendary reveal's size and no more. Below: both odds columns as percentages. No "spin again" of any kind.
- Phone and gamepad: the prompt and walking are the only inputs; the SPIN button is large and also fires on gamepad A; the HUD stays clear of the jump button and the quick-button column. No new quick button on the HUD (the column fits 7 at 384 px; the panel opens from the stand and from the end card).
- Display names nowhere: a round is private. No text input.

### W7.2 Sounds (reused `ClientState.SFX`, obey the `sfx` setting)

| Moment | Sound |
|---|---|
| pink catch | `tick` at pitch 1.6, volume 0.3 |
| golden catch | `chime` at pitch 1.3, volume 0.4 |
| pinecone | none |
| round start, round end | `whoosh` 0.3 |
| wheel starts spinning | `whoosh` 0.3, once |
| wheel stops (any wedge) | `chime` 1.0 |
| Celestial or Aurora | `fanfare` 0.5 after the chime |
| score under 12, practice | nothing beyond the round-end whoosh; no failure sound |

### W7.3 Blender props (GARDEN-044, same toy style as `garden-blender-plan.md`)

| Name | Size | Notes |
|---|---|---|
| `wheel_stand` | 7 wide, 8 tall | post, backboard, pointer; static; the disc is a separate model |
| `wheel_disc` | 6 across, 0.6 thick | 8 painted wedges in the egg colour pairs and gold for Coins, baked as texture; bounding box centre on the axle (pivots are not kept, architecture 9) |
| `wheel_basket` | 1.6 across | woven, one mesh; client attaches to the right hand |
| `petal_pink`, `petal_gold` | 1.2 across, under 100 tris | one mesh each, flat; `petal_gold` baked bright |
| `pinecone` | 1.0 tall, under 200 tris | brown, soft, cute (round scales, no spikes) |
| `wheel_tree` | 24 canopy, 20 tall | a blossom tree with a 2-radius trunk at the bounding box centre in x and z |

Code never waits for art: every prop has a part fallback (W2) and `Models.nightReady` decides.

## W8. Child safety (G4, binding)

- No Robux, no paid spins, no paid odds, no luck boosts anywhere near the patch or the panel. Odds published for both wheels.
- No countdown to the next free spin, no "come back tomorrow" timer, no daily-reset clock anywhere: only "N spins left today" (and the practice text at 0).
- No loss state: under 12 is "Nice try, play again"; a pinecone is a quiet −2 floored at 0; no failure sounds, no red, no shake, no near-miss text, no "so close" wedge animation (the wheel never wobbles back from a rarer wedge: it eases straight to its wedge).
- Nothing exclusive: the wheel runs every day, the same for everyone; prize eggs never expire.
- Nothing another player does can touch your round or your prizes. Prize eggs cannot be traded.
- The round timer is a game's own timer (0012 amendment of G4.7); it counts down to nothing but the end card.

## W9. Edge cases

| Case | What happens |
|---|---|
| Prompt used while a round runs | Refused silently; the running round continues |
| Prompt used while racing in Splash Dash | Refused (`Dash.isRacing`) |
| Player leaves or disconnects mid-round | Round dropped, no spin, nothing saved or lost |
| HOME mid-round | Leaves the round (teleport home), no spin |
| Dash countdown ends mid-round | The player is teleported to the start deck; the wheel round runs out with no more catches, end card shows wherever they are |
| Character dies or resets mid-round | Round continues; the new character at the plot gate can walk back; no catches meanwhile |
| Session offline or locked | Practice rounds only; stand label and HUD say "Saving is off on this server"; `wheelOver` tier `none` |
| Session goes offline mid-round | The prize is applied in memory with the normal unsaved notice (Dash's `UNSAVED_TEXT` pattern) |
| Already at 3 spins | Practice rounds, unlimited; label "All 3 spins used today · practice rounds open" |
| Day rolls over mid-round | Eligibility was taken at the start; a capped player's round stays practice; an eligible round's prize uses the day of the finish and is spin 1 of the new day |
| Beds full or below the egg's level | The egg waits in `prizeEggs`; PLANT is greyed in the DASH panel ("BEDS FULL", "LEVEL 25") |
| Celestial or Aurora below Level 25 or 32 | Saved and shown; "Plant it at Level 25" |
| Coins wedge at `MAX_COINS` | 0 coins, "Coins!" with no complaint; the spin still counts |
| Two players under the same petal | Each has their own petals; a player's root can catch only their own round's drops |
| Weather event | No effect on the round, the odds or the prize |
| Server shutdown | Rounds dropped, no spin; applied spins save in `BindToClose` |
| Server crash | No round state is saved, so nothing is stuck; `wheelToday` keeps spins already written |

## W10. Check values

| Check | Value |
|---|---|
| `schedule(seed, 100)` | 40 drops, `at` 102, 103, …, 141; 26 pink, 4 gold, 10 cone for every seed; every spot 4 to 12 from the centre |
| Same seed twice / seeds 1 and 2 | identical / a different order or spots |
| Drop at 102: band | catchable from 104.25 to 105.75; landed after 105.75 |
| Sample at 105.0, root 3.4 from the spot / 3.6 | caught / not caught |
| Sample at 104.0, root on the spot | not caught (above the band), and still catchable at 104.4 |
| Sample at 106.0, root on the spot | not caught (landed) |
| Score 1, then a pinecone | 0, not −1 |
| Score 11 / 12 / 23 / 24 at the end | `none` / `spin` / `spin` / `lucky` |
| Eligible false, score 38 | `none` |
| Odds | both columns sum to 10,000; 100,000 rolls hit every wedge, each within 15% of its bp |
| Spins today 2 then a spin / 3 then a round | spin 3 applied, `spinsLeft` 0 / practice, nothing applied |
| `award(p, today, 2, "moon")` twice | second returns `false` and the same profile |
| `award` with `n = 3` when `spins = 1` | refused |
| Day `today + 1` | `spinsLeft` 3; `award(p, today + 1, 1, …)` resets `wheelToday` |
| Coins at 60.5 coins/s / 0 | 36,300 / 100 |
| `prizeEggs.celestial` 999,999 then a Celestial | 1,000,000 (capped) |
| `sanitize` of a v2 record | `wheelToday = { day = -1, spins = 0 }`; `spins = 9` becomes 3 |
| EV per spin (W5) | standard 127.0, lucky 189.1 coins/s |

## W11. Studio test plan (GARDEN-045, one client; a second is optional)

Record the build stamp (rule 13). Seeded rounds: in Studio only (`RunService:IsStudio()`), `Wheel.start` reads `Workspace.Garden.Wheel:GetAttribute("Seed")` when set and uses it instead of its own seed; never outside Studio.

1. Walk to the stand, prompt "Play". **Expect:** `wheelStart` with `practice = false`, petals appear from the canopy on the 1 s rhythm, HUD 0 / 45, label "3 spins left today".
2. Set `Seed = 12345`, start a round, and from the command bar print `WheelRules.schedule(12345, startAt)` drops 1 to 8 (kind, spot). **Scripted root walk:** a server command-bar script `PivotTo`s the test character onto drop `i`'s spot at `at + 2.6 s` for `i = 1..8`, then away. **Expect:** a `wheelCatch` for each of drops 1 to 8 with `score` running as the kinds say (pinecones −2, floored at 0); no catch for drop 9 onward while the character stands at the stand.
3. Let the round run out. **Expect:** `wheelOver` with the score and the tier the thresholds give; if `spin` or `lucky`, `wheelSpin` with a wedge; the disc animation ends on that wedge; the `Profile` attribute shows `prizeEggs` or `coins` changed and `wheelToday.spins = 1`; label "2 spins left today".
4. Two more rounds to the cap with any play (the walk script again). **Expect:** spins 2 and 3 applied; the fourth round starts with "Practice", ends with tier `none`, nothing applied, label "All 3 spins used today · practice rounds open".
5. Stop play mid-round and restart. **Expect:** no spin from the dropped round; the saved record (DataStores on) holds `wheelToday` and the prize eggs.
6. Local file with DataStores off. **Expect:** practice only, the "Saving is off" texts, no `wheelSpin`.
7. Optional, two clients: start a round on each. **Expect:** neither sees the other's petals; catches are independent; each label shows its own count.
8. Sounds: `sfx` off silences everything; no sound on a pinecone or on an under-12 end.

## W12. Unit tests (`tests/WheelRules.spec.luau`, GARDEN-041)

Seeded schedule deterministic (same seed equal, different seeds differ); composition 26 / 4 / 10 for 200 seeds; times `startAt + 2 + (i − 1)`; every spot 4 to 12 from the centre; catch window geometry (inside the radius in the band catches; outside the radius, above the band or landed does not; the band lasts 1.5 s, so 5 Hz sees at least 7 samples); a resolved drop never resolves again; score floor at 0; points per kind; thresholds 11 / 12 / 23 / 24 and practice gives `none`; both odds columns sum to 10,000, every wedge has a non-zero chance and 100,000 rolls land within 15% of each bp; `spinsLeft`, the cap and day rollover; `award` idempotent on `(today, n)`, refuses out-of-order and past the cap, caps `prizeEggs` at `PRIZE_STORE` and coins at `MAX_COINS`, pays `scaled(100, 10)`; `spinId` distinct across `n` and days; inputs never mutated; `GardenProgress.spec`: a v2 record gets the default `wheelToday` and an over-cap count is clamped; `GardenConfig.spec`: 8 wedges, every egg wedge is a sold egg; `Purity.spec` covers `WheelRules` automatically.

## W13. Facts, assumptions, hypotheses

- **Fact:** root positions are client-owned (0008); the server samples them at 5 Hz already (`fastTick`), so the wheel adds no sampling.
- **Fact (computed, W5):** the expected values above follow from the odds and the U6 rates; the Director's odds exceed the budget on the lucky wheel by 2.4 times.
- **Assumption:** replication delay of the root is under 0.3 s on a typical connection, well inside the 1.5 s band. If phones miss catches they clearly made, widen the band (fall speed 3.5) at the feel gate; the band is not an economy value.
- **Assumption:** the patch centre (−40, 0, −52) is clear of paths and lamps; the engineer may move it up to 10 studs.
- **Hypothesis:** 12 and 24 are right: a first-timer earns a spin, a practised player a lucky one. Thresholds are the tuning lever (a decision record, since they set the spin rate); the composition is not.
- **Hypothesis:** three 45 s rounds a day is a pleasant daily ritual rather than a chore; the practice rounds keep the patch alive for players who like it.

**Cut on purpose:** a HUD quick button (the stand and the end card open the panel); the basket visible to others; petal sway in the server's maths; seeded time jitter; a speed strike; leaderboards, best scores, XP, quests or Index entries from the wheel; more wheels or seasonal wedges; a "spin again".

**Cut order if the cycle runs long:** `wheel_tree` (keep `Props.sakura`); the basket; the progress bar (score and timer only).
