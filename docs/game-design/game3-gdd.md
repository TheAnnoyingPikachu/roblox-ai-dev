# Hundred Demon Night: game design spec (v0.1)

Status: draft for SHANNON. Concept B in `game3-concepts.md`. Needs decision record 0007 (economy, remotes, save schema; CLAUDE.md rule 8) and a task file before build.

## A. Product

- **Pitch:** the Night Parade of a Hundred Demons is crashing a lantern-lit shrine festival. Alone or with up to 5 others, hold the courtyard through 10 waves of floating yokai with a katana, a launcher, a dash and a Demon Trigger. Chase SSS style ranks, pick a blessing between waves, and slay the giant skeleton Gashadokuro on wave 10.
- **Audience:** players under 18. Roblox's built-in filtered text chat stays on. No custom chat, no personal data beyond the saved game profile.
- **Platforms:** PC, mobile, console. Four actions beyond walk and jump: Attack, Skill, Dash, Trigger.
- **Pillars:**
  1. Slashing yokai within 10 seconds of pressing PLAY.
  2. Every second asks for a choice (which move, which target, dodge now); every break asks for a build choice.
  3. Complete alone, better together; nobody waits more than 15 seconds to play.
  4. Detailed and themed in the first screenshot.
- **Non-goals:** PvP, trading, Robux or paid items (decision 0002), custom chat, more than one mode, hand-made animations, parties or matchmaking across servers.
- **Server size:** 6 players. One shared night per server.

## B. Run flow ("a night")

States, in order: `Idle`, `Countdown`, `Wave(w)`, `Break(w)`, `Victory`, `Defeat`. Rules live in `RunRules` (section L).

1. **Idle:** no run. Players in the start menu watch the camera orbit; players who pressed PLAY stand at the shrine steps.
2. **PLAY in Idle:** the run enters `Countdown` (3 s) with that player as its first participant and **host**. The tier is fixed now: the host's `tierPick`, clamped to the highest tier the host has unlocked (section H3).
3. **Countdown end:** `Wave(1)`.
4. **Wave(w):** enemies spawn (section D). The wave is **cleared** when every enemy in its composition has spawned and died (waves 5 and 10: when the boss dies; its summons vanish). Rewards for the wave are paid at once (section F).
5. **Cleared Wave(w), w < 10:** `Break(w)` for 12 s: blessing pick (section E) and heal (section G). Then `Wave(w + 1)`.
6. **Cleared Wave(10):** `Victory` for 8 s (victory bonus, confetti, podium camera).
7. **Defeat:** during a wave, if every participant is downed and none has a charm revive pending (section G), the run enters `Defeat` for 8 s. Rewards already paid are kept.
8. **After Victory or Defeat:** if any participant is still in the arena, a new `Countdown` starts with them (same host rule, host's tier re-read). Otherwise `Idle`. Players who pressed PLAY during Victory or Defeat join that countdown.
9. **Empty run:** if the participant list becomes empty in `Countdown`, `Wave` or `Break`, the run returns to `Idle`.

Target: a full night in 8 to 10 minutes (hypothesis: waves 30–60 s, 9 breaks of 12 s, boss about 90 s).

### B2. Joining and leaving

- **PLAY during Countdown, Wave or Break:** the player joins immediately at the shrine steps with full HP and one charm, unless the run already has 6 participants (then the request is refused; with a 6-player server this cannot happen, but the rule is tested).
- **Catch-up blessings:** a player who joins during `Wave(w)` receives `w − 1` blessings at once; during `Break(w)` they receive `w − 1` at once and then get this break's offer like everyone else. Each catch-up blessing is offer 1 of a seeded offer (section E), so it is deterministic.
- **Leave:** the `leaveRun` request, opening the start menu, or disconnecting removes the player from the participants. Paid rewards stay. If the host leaves, the earliest-joined remaining participant becomes host (the tier does not change mid-run).
- **Scaling** uses `n` = number of participants at the start of each wave. Joining mid-wave does not change the current wave.

## C. Combat

All damage, hits, cooldowns, HP and kills are decided by the server. The client sends `Combat(action)` with no other data and plays VFX at once (prediction); damage numbers appear when the server confirms. Rules live in `CombatRules`.

### C1. Weapons (light attack combos)

The light attack is a combo of `steps` hits. Data per weapon:

| Weapon | Unlock | Damage per step | Interval (s) | Combo window (s) | Recovery after last step (s) | Range (studs) | Arc (degrees) | Finisher knockback (studs) |
|---|---|---|---|---|---|---|---|---|
| Katana (default) | Level 1 | 12, 12, 24 | 0.32 | 0.70 | 0.50 | 8 | 110 | 30 |
| Twin Kodachi | Level 6 | 8, 8, 8, 8, 18 | 0.20 | 0.60 | 0.50 | 6.5 | 140 | 20 |
| Nodachi | Level 14 | 20, 36 | 0.55 | 0.90 | 0.60 | 11 | 160 | 45 |

Combo rule for an `attack` request at time `t`, given the last accepted attack at `t0` with step `s`:

- If `s < steps` and `t − t0 < interval`: refused (too early).
- If `s = steps` and `t − t0 < recovery`: refused.
- Otherwise accepted. The new step is `s + 1` if `s < steps` and `t − t0 ≤ window`, else 1.
- The first attack of a run is step 1. The **finisher** is the last step.
- Weapons are sidegrades: katana ~42 damage per second over a full cycle, kodachi ~38 with a wider arc, nodachi ~49 but slow and committal. Equipping a weapon is refused while the player is a run participant.

### C2. Hit test

A target is hit when, using the server's replicated root positions (horizontal plane x, z):

- the vertical gap `|dy|` ≤ 6 studs (8 for Rising Slash), and
- either the horizontal distance minus the target's radius is ≤ 1 (point blank, any angle), or it is ≤ the attack's range and the angle between the attacker's facing (root LookVector, flattened) and the direction to the target is ≤ arc / 2.

Every target that passes is hit (attacks cleave). Enemy radii: wisp 1.5, lantern 2.5, kasa 2.5, oni 3.5, Oni General 5, boss hand 6, boss skull 9.

### C3. Skill: Rising Slash (E, gamepad Y, touch SKILL)

- Cooldown 5.0 s. Base damage 20, range 8, arc 120.
- Launches every non-armoured enemy hit: **airborne** for 1.2 s (rises 10 studs and hangs). A second launch refreshes the timer to 1.2 s.
- Airborne enemies take ×1.25 damage, deal no damage, do not move and cancel any telegraphed attack.
- The client hops the player 12 studs up with the slash so they can juggle (client movement, cosmetic for the rules; the 8-stud vertical band keeps air hits in reach).

### C4. Dash (Q, Left Shift, gamepad X, touch DASH)

- Reuses Relay's dash (burst in the move direction, afterimages), usable on the ground or once per airtime, cooldown 1.0 s.
- The client sends `Combat("dash")` as it dashes. The server accepts if at least 0.95 s have passed since the last accepted dash and grants **invulnerability for 0.35 s**.
- Damage blocked by dash invulnerability counts as a **dodge** (once per enemy attack instance).

### C5. Demon Trigger (R, gamepad B, touch TRIGGER)

- Gauge 0 to 100. Gains `damage dealt / 4 × gaugeRate` per hit (fractions kept), capped at 100. No gain while Trigger is active.
- Request accepted only at gauge 100: Trigger lasts 8 s (plus blessings), gauge set to 0.
- While active: damage ×1.4, move speed ×1.2, heal 2 HP per hit landed (capped at max HP), every hit staggers armoured enemies. Red aura, demon-wing VFX, music filter.

### C6. Damage formula

`damage = floor(base × damageMult × (1.25 if target airborne) × (1.4 if Trigger active) + 0.5)`

`damageMult` comes from blessings (section E). Boss parts apply their own multiplier last (section D3). No random crits: every result is deterministic.

### C7. Hit reactions

- **Normal enemies:** any hit staggers for 0.4 s (no move, no attack, telegraph cancelled). Finishers push them `knockback` studs directly away from the attacker over 0.25 s.
- **Armoured** (oni, Oni General): only finishers and Trigger-state hits stagger; knockback ×0.3; cannot be launched.
- **Bosses** (Gashadokuro): never stagger, never move from knockback.

### C8. Player HP and taking damage

- Max HP 100 (plus blessings). HP is the server's own number; the Humanoid is kept alive (`BreakJointsOnDeath` off, health mirrored for the default bar).
- **Contact damage** is checked at 10 Hz: an enemy whose horizontal distance to the player is ≤ its radius + 2.5 and `|dy|` ≤ 5 deals its contact damage, at most once per (enemy, player) pair per 1.0 s.
- **Attack damage** (fireball, slam, dash line, boss attacks) hits each player at most once per attack instance.
- No damage while invulnerable (dash, 2 s after any revive) or downed.
- Taking damage resets the player's style meter.

### C9. Feel (client only, never affects rules)

Slash arc VFX (neon wedge plus blade trail in the equipped Blade Art colours), white hit flash on the enemy (Highlight, 0.08 s), hit sparks, damage numbers, camera shake (0.15 s; 0.25 s on finishers), FOV punch on Trigger, slow-motion VFX burst (0.1 s) on kills, soft lock (the character turns to the nearest enemy within 12 studs and 90 degrees of the camera before an attack is sent). Character animation: Roblox's built-in tool **Slash** animation (Animate script `toolanim` = "Slash") for steps, **Lunge** for finishers, plus a code-driven blade sweep (the weapon part is tweened through a 120-degree arc around the hand in 0.15 s) so the swing reads even if the built-in animation is weak. Ninja Animation Package for locomotion (already registered).

### C10. Anti-exploit

- Combat requests are refused for players who are not alive run participants, for unknown actions, for non-string arguments, and above 20 combat requests per second.
- **Teleport guard:** the server samples each participant's root at 10 Hz; if it moves more than 12 studs between samples (120 studs/s; Relay's dash tops out at 95 studs/s), attacks are refused for the next 1.0 s.

## D. Enemies and waves

All enemies float or hop, so none needs a walk animation. They are server-owned models built from parts (no Humanoids), moved by the server with `AlignPosition` and `AlignOrientation`. Rules (stats, scaling, composition, targeting) live in `WaveRules`; boss patterns in `BossRules`.

### D1. Enemy roster (tier 1, one player)

| Id | Name | Cost | HP | Speed | Damage | Behaviour | Look |
|---|---|---|---|---|---|---|---|
| `wisp` | Hitodama | 1 | 24 | 14 | 6 contact | Homes on its target, bobbing 3 studs off the ground. | Neon blue-white flame ball, fire particles, trail |
| `lantern` | Chōchin-obake | 2 | 50 | 8 | 12 fireball | Keeps 18–28 studs from its target. Every 3.5 s, if its target is within 40 studs: glows for 0.8 s (telegraph), then fires a fireball (speed 35, radius 2). | Generated lantern-yokai mesh, one eye, tongue, orange light |
| `kasa` | Kasa-obake | 2 | 45 | 10 | 15 dash | Every 4 s within 30 studs: a red line appears on the ground for 1.0 s (telegraph), then it dashes 30 studs along it at 60 studs/s, hitting anyone it passes within 3 studs. | Paper umbrella of parts (cone, one leg, one eye), hops |
| `oni` | Possessed Yoroi | 4 | 160 | 9 | 6 contact, 25 slam | **Armoured.** Within 8 studs of its target: a red circle (radius 9) for 1.2 s, then a slam. | Hovering empty samurai armour of parts, horned helmet, red glow inside |
| `general` | Oni General (wave 5) | – | 900 | 11 | 30 slam | **Armoured.** Slam radius 12 with 1.0 s telegraph. Every 10 s roars and summons 4 wisps (at most 8 of its wisps alive). | Generated oni statue mesh (reused), glowing eyes, chains of parts |
| `boss` | Gashadokuro (wave 10) | – | 3000 | 0 | see D3 | Skull and two hands; section D3. | Generated skull and hand meshes |

### D2. Targeting and stuck enemies

- An enemy targets the nearest participant who is not downed (horizontal distance); ties go to the earlier-joined participant. It re-picks every 1.0 s. With no valid target it holds position.
- An enemy that has not been within 30 studs of any participant for 20 s is moved to the nearest demon gate.

### D3. Gashadokuro (wave 10)

- Rises from the boss pit at the north of the courtyard. Total HP 3000 (scaled, D5). Hits on a hand count ×1.0, on the skull ×1.5.
- **Stagger:** after every Hand Slam, the skull lowers to the ground for 4 s; hits on the skull count ×2.0 during it (instead of ×1.5).
- **Attacks** (2.5 s gap between attacks):
  - *Hand Slam:* a shadow circle (radius 10) follows a target player for 1.5 s, locks for 0.6 s, then the hand slams: 30 damage inside the circle.
  - *Double Slam:* both hands, two different targets if there are two or more players.
  - *Sweep:* a red line across the arena for 1.5 s, then a hand sweeps along the ground: 25 damage to players within 4 studs of the line whose feet are less than 4 studs above the ground (jump or dash to avoid).
  - *Summon:* 6 wisps and 2 lanterns from the gates.
- **Phases** by HP left: phase 1 above 66%, phase 2 from 66% to 33%, phase 3 below 33%. Patterns repeat in order:
  - Phase 1: Slam, Slam, Sweep.
  - Phase 2: Slam, Sweep, Slam. Entering phase 2 triggers one Summon first.
  - Phase 3: Double Slam, Sweep, Sweep. Entering phase 3 triggers one Summon first.
- The boss dies at 0 HP and the wave is cleared; its summons vanish.

### D4. Wave composition

Budgets are for tier 1, one player; `B = round(base × (1 + 0.6 × (n − 1)))`.

| Wave | Content | Base budget | Allowed types | Gates open |
|---|---|---|---|---|
| 1 | 6 + 3 × (n − 1) wisps, speed ×0.7 (tutorial) | – | wisp | 1 (south-east) |
| 2 | budget | 8 | wisp, lantern | 1–2 |
| 3 | budget | 11 | wisp, lantern, kasa | 1–2 |
| 4 | budget | 14 | wisp, lantern, kasa, oni | 1–4 |
| 5 | Oni General | – | general (+ summons) | 1–4 |
| 6 | budget | 18 | all four | 1–4 |
| 7 | budget | 21 | all four | 1–4 |
| 8 | budget | 24 | all four | 1–4 |
| 9 | budget | 28 | all four | 1–4 |
| 10 | Gashadokuro | – | boss (+ summons) | 1–4 |

Fill rule (budget waves), using the run's seeded random generator (section L):

1. In an **intro wave** (2: lantern, 3: kasa, 4: oni) the first enemy is the newly introduced type.
2. Repeat while budget remains: pick uniformly among allowed types whose cost fits the remaining budget and, for `oni`, only while the oni count is below `floor(w / 3) + floor((n − 1) / 2)`. Subtract its cost.
3. Wisps cost 1, so the composition's total cost always equals `B` exactly.

Spawning: in composition order, one every 0.5 s while alive enemies are fewer than `12 + 4 × (n − 1)`. The i-th spawn uses gate `((i − 1) mod gatesOpen) + 1`.

### D5. Scaling

With `n` participants at wave start and tier `t` (1 to 5):

- Regular enemy HP: `round(baseHp × (1 + 0.15 × (n − 1)) × (1 + 0.35 × (t − 1)))`
- Oni General and Gashadokuro HP: `round(baseHp × (1 + 0.75 × (n − 1)) × (1 + 0.35 × (t − 1)))`
- Enemy damage: `round(baseDamage × (1 + 0.2 × (t − 1)))`
- Summons use the regular formulas with the wave's `n` and `t`.

## E. Blessings (roguelite build)

At the start of each `Break(w)` every participant is offered 3 blessings. They pick with `pickBlessing("1" | "2" | "3")` once per break; if they have not picked when the break ends, offer 1 is applied. Rules live in `BlessingRules`.

**Offer rule:** 3 distinct blessings drawn with a generator seeded from `(runSeed, participant join index, w)`, excluding blessings at their max stacks and excluding party-only blessings when the run has 1 participant. If fewer than 3 are eligible, all eligible ones are offered.

| Id | Name | Max stacks | Effect per stack |
|---|---|---|---|
| `edge` | Sharpened Edge | 3 | damageMult +0.12 |
| `swift` | Swift Steps | 2 | move speed +10% |
| `iron` | Iron Skin | 3 | max HP +20 (and heal 20 now) |
| `foxfire` | Kitsune Fire | 1 | finishers also launch a fox-fire bolt forward: 20 base damage, 30 studs at 60 studs/s, hits the first enemy within 2 studs of its path |
| `thunder` | Thunder Dash | 2 | an accepted dash deals 15 base damage to enemies within 3 studs of the dash path (start to position 0.35 s later) |
| `lantern` | Lantern Heart | 2 | heal 3 HP per kill |
| `hunger` | Demon Hunger | 2 | gaugeRate +0.3 |
| `longnight` | Long Night | 2 | Trigger duration +3 s |
| `ninetails` | Nine Tails | 1 | +1 charm (section G) |
| `storm` | Rising Storm | 2 | Rising Slash cooldown −1.5 s (minimum 2 s) |
| `shockwave` | Shockwave | 1 | Rising Slash hits all around you within 10 studs instead of the arc |
| `link` | Spirit Link | 1 | party-only: when you revive an ally or an ally revives you, both heal to max HP |

`BlessingRules.modifiers(stacks)` returns: `damageMult = 1 + 0.12·edge`, `speedMult = 1 + 0.1·swift`, `maxHp = 100 + 20·iron`, `gaugeRate = 1 + 0.3·hunger`, `triggerDuration = 8 + 3·longnight`, `charms = 1 + ninetails`, `risingCooldown = max(2, 5 − 1.5·storm)`, `healOnKill = 3·lantern`, `thunderDamage = 15·thunder`, and booleans `foxfire`, `shockwave`, `link`. Blessings last for the run only.

## F. Style and rewards

### F1. Style meter (reused `StyleRules`, now server-side)

The meter now pays, so the server runs it from events it observes; the client only displays the rank attribute. Same ranks (D, C, B, A, S, SS, SSS), same repeat penalty (full, 1/2, 1/3...), same decay (7 points/s) and cap (240). New events: `hit` 3, `finisher` 8, `launch` 10, `airHit` 6, `dodge` 15, `kill` 5, `trigger` 20. Relay's events stay. Taking damage resets the meter. The server tracks each player's **highest rank reached in the current wave**.

### F2. Wave rewards

Paid to every participant in the run when a wave is cleared (downed players included), using `n` = participants at the moment of clearing:

- `R = tierMult × styleMult × partyMult`
- `tierMult = 1 + 0.5 × (t − 1)`
- `styleMult` by highest rank this wave: D 1.0, C 1.1, B 1.2, A 1.3, S 1.5, SS 1.75, SSS 2.0
- `partyMult = 1 + 0.1 × min(3, n − 1)`
- XP `= floor((15 + 3w) × R)`, souls `= floor((8 + 2w) × R)`
- **Victory bonus** (wave 10 cleared): XP `floor(150 × tierMult)`, souls `floor(100 × tierMult)`.

Example: a solo tier-1 night won at rank D earns 465 XP and 290 souls (level 4 from zero). Kills do not pay directly, so stealing kills gains nothing.

### F3. Stats counted (for quests, stats panel and leaderboard)

At each wave clear: `waves +1`; `kills`, `launches`, `triggers` += this wave's counts for that player; `rankS +1` if the highest rank this wave was S or better; `generals +1` on wave 5; `bosses +1` on wave 10. `runs +1` at the player's first wave clear in each run. `wins +1` and `bestTier = max(bestTier, t)` on Victory.

## G. Downs, revives and charms

- At 0 HP a player is **downed**: cannot act, enemies ignore them, a spirit-flame marker shows where they are.
- **Charm:** each participant starts a run with `charms` charms (1, or 2 with Nine Tails). On going down with a charm left, one is spent and the player stands up after 3 s with 50% max HP. A pending charm revive counts as "not downed" for the defeat check.
- **Ally revive:** a participant who is not downed standing within 6 studs of a downed ally for 2.0 s in a row revives them at 40% max HP. Several helpers do not speed it up; leaving the radius resets the timer.
- Any revive gives 2 s of invulnerability.
- **Break heal:** at the start of each break, downed players stand up at 50% max HP and everyone else heals 25 HP (capped at max).
- **Solo:** one charm means one free mistake; the second down with no charm ends the night (Defeat), and the next night starts 8 s later.

## H. Meta game (reused and new)

### H1. What is reused, generalised or new

| Piece | Source | Plan |
|---|---|---|
| Daily streak, weekly bonus, daily quests, levels, unlock/buy/equip, sanitise, day/week maths | `src/shared/ProgressRules.luau` | **Generalise** into `MetaRules`, configured by a per-game table (reward amounts, quest pool, cosmetic list, record fields). Relay's `ProgressRules` becomes Relay's config plus its match rules; `tests/ProgressRules.spec.luau` must still pass unchanged. Same reward amounts as decision 0006 for daily (50–400) and weekly (500); same level curve (`floor(sqrt(xp / 40)) + 1`, cap 50). |
| Quest selection (`questsFor`) | `ProgressRules` | Reused with an 8-quest pool; must stay correct for any pool size ≥ 3 (unit test). |
| Cosmetic data shape (id, name, colours, level, wins, price) | `ProgressRules.TRAILS` | Reused, plus a `slot` field (`blade` or `mask`) and a `tier` unlock kind. Equip is per slot. |
| Style meter | `src/shared/StyleRules.luau` | **Reused**, new combat events added (F1); now also runs on the server. |
| Profiles: load with 3 tries, offline mode, `UpdateAsync` re-apply pattern, Request remote validation, 0.35 s rate limit | `src/relay/Profiles.luau` | **Reused** pattern with new store names (`NightProfile<suffix>`, ordered `NightWins<suffix>`). |
| Start menu, HUD, Locker, Rewards, Stats, Settings, toasts, music player | `src/relay-client/Menu.client.luau` | **Forked** into `src/night-client/Menu.client.luau`: same style and panels; PLAY opens the Night panel; Locker gets Blade Arts, Masks and Weapons tabs. |
| Double jump, dash, afterimages, Ninja animations | `src/relay-client/Movement.client.luau` | **Reused** without launch and boost pads; dash also sends `Combat("dash")`. |
| Camera shake, FOV kick | `src/relay-client/CameraFx.client.luau` | **Reused.** |
| Mesh loader | `src/relay/Models.luau` | **Reused.** |
| Combat, waves, enemies, bosses, blessings, run state | – | **New** pure modules (section L). |
| Arena, enemies, VFX, HUD combat widgets | – | **New.** |

### H2. Start menu and HUD

- **Start menu:** title "HUNDRED DEMON NIGHT" with 百鬼夜行 beneath, over a slow camera orbit of the lit courtyard (yokai drifting at the gates in Idle). Buttons: PLAY, LOCKER, REWARDS, STATS, SETTINGS. A gold dot marks anything claimable (reused).
- **PLAY panel:** tier picker (locked tiers greyed with their unlock rule), weapon picker (level-locked ones greyed), **Invite friends** (Roblox's built-in game invite prompt), and START (or JOIN NIGHT, with the current wave, if a run is on).
- **HUD in a run:** HP bar, Trigger gauge (glows at 100), Rising Slash and dash cooldown rings, style rank meter (reused), wave banner ("WAVE 3 / 10", boss HP bar on waves 5 and 10), souls counter, level and XP bar (reused), charm icons, teammates' HP pips. Touch: ATTACK (large), SKILL, DASH, TRIGGER on the right; jump as default.
- **First run** (`runs = 0`): prompts appear in order and disappear once done: "Click / tap to slash" (wave 1 start), "E: Rising Slash" (after 3 hits), "Q: Dash through attacks" (after the first launch), "R: DEMON TRIGGER" (when the gauge first fills), "Pick a blessing" (first break).
- **Blessing cards:** three cards slide up in the break with icon, name, effect and stack count; number keys 1–3 or tap.

### H3. Progression

- **Levels** from XP (shared curve). Level unlocks: Twin Kodachi at 6, Nodachi at 14, plus cosmetics below.
- **Moon tiers:** 1 Crescent, 2 Half, 3 Full, 4 Blood, 5 Eclipse. Tier 1 is always unlocked; tier `t > 1` is unlocked when `bestTier ≥ t − 1` (you won the tier below). `tierPick` is clamped to the highest unlocked tier.
- **Souls** (soft currency, stored as `coins`) buy cosmetics only. Nothing bought changes combat.

### H4. Cosmetics (Locker)

| Slot | Id | Name | Unlock |
|---|---|---|---|
| blade | `steel` | Steel (default) | Level 1 |
| blade | `sakura` | Sakura | Level 3 |
| blade | `ember` | Ember | Level 5 |
| blade | `moonlight` | Moonlight | Level 8 |
| blade | `shadow` | Demon Shadow | Level 12 |
| blade | `rainbow` | Rainbow | Level 18 |
| blade | `gold` | Champion Gold | 5 nights won |
| blade | `lightning` | Lightning | 750 souls |
| blade | `galaxy` | Galaxy | 1,500 souls |
| blade | `inferno` | Inferno | 2,500 souls |
| blade | `void` | Void | 5,000 souls |
| mask | `none` | No mask (default) | – |
| mask | `kitsune` | Kitsune | Level 4 |
| mask | `tengu` | Tengu | Level 10 |
| mask | `oni` | Oni | 3 nights won |
| mask | `eclipse` | Eclipse | Tier 5 won |
| mask | `okame` | Okame | 600 souls |
| mask | `hannya` | Hannya | 1,000 souls |

Blade Arts colour the blade, the slash arc and the trail (Relay's trail colours reused). Masks are small part models welded to the head.

### H5. Rewards

- **Daily streak:** reused (days 1–7: 50, 75, 100, 125, 150, 200, 400 souls; day 7 repeats while the streak holds; a missed day restarts at 1).
- **Weekly bonus:** reused (online on 5 different UTC days, Monday to Sunday: 500 souls).
- **Daily quests:** 3 a day from this pool, the same for everyone on a given UTC day. All are completable solo.

| Id | Label | Stat | Goal | Souls |
|---|---|---|---|---|
| `nights3` | Play 3 nights | runs | 3 | 100 |
| `waves10` | Clear 10 waves | waves | 10 | 100 |
| `kills60` | Defeat 60 yokai | kills | 60 | 100 |
| `launch30` | Launch 30 yokai | launches | 30 | 120 |
| `trigger5` | Use Demon Trigger 5 times | triggers | 5 | 120 |
| `rankS3` | Reach S rank in 3 waves | rankS | 3 | 150 |
| `general2` | Defeat the Oni General twice | generals | 2 | 150 |
| `boss1` | Defeat the Gashadokuro | bosses | 1 | 250 |

### H6. Leaderboard, stats, settings, music

- **Leaderboard:** a lantern board at the shrine steps shows the global top 10 by nights won (`NightWins` ordered store, names from `GetNameFromUserIdAsync`, refreshed every 60 s). Session leaderstats: Level and Nights.
- **Stats panel:** level, XP, souls, nights won, best tier, runs, waves, kills; "saving offline" notice when DataStores are unavailable (reused).
- **Settings** (client-only, not saved): music on/off, sound effects on/off, camera shake on/off, damage numbers on/off, How to Play card.
- **Music:** menu and breaks: "Serenity Through Shadows" (Distrokid, registered); waves: "Killshot C", "Boom Bang C", "We're Taking Over Tonight" (APM, registered); boss: a new APM track to pick and register before use. Music ducks during breaks and swells on Trigger.
- **SFX:** reused gong (wave start), resonant gong (victory), beep (countdown), whooshes (dash, slash). New from Pro Sound Effects, registered before use: two sword slashes, a heavy impact, a yokai death puff, a fireball, a slam boom, a temple bell (break start).

### H7. Saved profile (schema v1, store `NightProfile<suffix>`)

`{ schemaVersion, xp, coins, wins, runs, waves, kills, bestTier, tierPick, weapon, blade, mask, owned, daily = { streak, last }, week = { key, days, lastDay, claimed }, quests = { day, progress, claimed } }`

Sanitising: as decision 0006 (numbers floored and clamped: XP 1,000,000, coins 10,000,000, counts 1,000,000), plus `bestTier` clamped 0–5, `tierPick` clamped 1–5, `weapon` falls back to `katana` if unknown or locked, `blade` to `steel` and `mask` to `none` if unknown or locked, unknown `owned` ids dropped. Saved after each wave clear, each claim, purchase or equip, and on leave, using the `UpdateAsync` re-apply pattern.

## I. Arena and art plan

### I1. Layout ("Shrine of a Hundred Lanterns", all ground level)

Centre (0, 0, 0). North is −Z. A circular stone courtyard, radius 100, inside a stone wall and wooden fence.

| Feature | Where | Build |
|---|---|---|
| Kagura dance stage | centre, 32 × 32, 4 studs high, ramps on all four sides | WoodPlanks deck, red pillars, a hanging shimenawa rope, paper lanterns at the corners |
| Boss pit | north, (0, 0, −65); no props within 30 studs | Cracked slate ring with purple neon cracks; two oni statues (reused mesh) at (±30, 0, −80) |
| Shrine main hall | north, (0, 0, −115), outside the wall as the backdrop | Generated mesh |
| Sacred tree | south-west, (−55, 0, 45) | Generated mesh, with paper streamers of parts |
| Koi pond | west, (−60, 0, −10), radius 18 | Shallow terrain water, two red arched bridges, stepping stones |
| Festival stalls | east, five stalls along x = 60 | Fabric awnings in red, white and indigo, signs, crates, hanging lanterns |
| Demon gates | (±60, 0, ±60); gate 1 is south-east | Black torii with purple neon, swirling particle portal, glow on the ground |
| Entrance and spawn | south, stairs at (0, 0, 95), spawn at (0, 0, 80) | Two komainu (reused mesh), stone lanterns, the leaderboard board |
| Stone lanterns | 16 around the rim at radius 92 | Parts, warm `PointLight` (range 18) |
| Lantern strings | from stage corners to the rim | Beams with small neon lanterns every 6 studs |
| Sakura ring | 12 trees outside the wall, radius 110–130 | Generated sakura mesh (reused) |
| Far scenery | beyond 200 studs | Terrain mountains, a forest of part trees, a big low moon |

### I2. Look

- **Lighting:** `ClockTime` 0, `Ambient` (40, 35, 60), `OutdoorAmbient` (70, 60, 100); `Atmosphere` density 0.35, colour (90, 60, 140), decay (40, 20, 60); `Bloom` intensity 0.6; `ColorCorrection` tint (225, 215, 255), contrast 0.1, saturation 0.15; sky moon angular size 20.
- **Materials:** Slate courtyard with Cobblestone paths, WoodPlanks stage, red Wood torii, Neon accents only on lanterns, gates and VFX, Fabric awnings, Grass outside the wall.
- **Life:** fireflies (particles) near the pond and tree, falling sakura petals, drifting fog, lantern flicker, yokai idling at the gates in the menu orbit.
- **Budgets:** arena under 5,000 parts; each enemy under 15 parts; at most 32 enemies alive (`12 + 4 × 5`).
- **First screenshot test:** the start-menu orbit frame must show lit lanterns, the stage, a torii or demon gate, the moon and festival stalls (acceptance, section M).

### I3. Generated meshes (8 in total: 5 new, 3 reused)

| # | Mesh | Prompt | Size | Status |
|---|---|---|---|---|
| 1 | Boss skull | "giant cracked yokai skull, Gashadokuro, bone white with glowing red eye sockets, jagged teeth, stylised anime" | about 26 studs | New |
| 2 | Boss hand | "giant skeletal bone hand with long claw fingers, open palm, bone white, stylised anime" | about 16 studs (used twice, mirrored) | New |
| 3 | Sacred tree | "huge ancient Japanese camphor tree with thick twisted trunk, a shimenawa rope with white paper zigzag streamers around it" | about 50 studs tall | New |
| 4 | Shrine hall | "Japanese Shinto shrine main hall, sweeping curved roof, red pillars, wooden walls, stone steps" | about 45 studs wide | New |
| 5 | Lantern yokai | "Japanese paper lantern yokai, chochin-obake, one big eye and a long tongue, red and cream paper" | about 10 studs, scaled to 5 in game | New |
| 6 | Oni statue | (existing asset 116124333528107) | about 20 studs | Reused: boss-pit guardians and the Oni General's body |
| 7 | Komainu | (existing asset 130213651134294) | about 10 studs | Reused: entrance guardians |
| 8 | Sakura tree | (existing asset 139101786875815) | about 25 studs | Reused: ring outside the wall |

Each new mesh needs a row in `docs/assets/register.md` before use (CLAUDE.md rule 9).

## J. Remote contract (for decision 0007)

- `ReplicatedStorage.NightRemotes.Request` (RemoteFunction): `Request(action: string, arg: string?) -> boolean`. Actions: `play`, `leaveRun`, `pickBlessing("1" | "2" | "3")`, `setTier("1"–"5")`, `equipWeapon(id)`, `claimDaily`, `claimWeekly`, `claimQuest(id)`, `buyCosmetic(id)`, `equipCosmetic(id)`. Same checks as decision 0006: type checks, `arg` at most 32 characters, one request per 0.35 s, every action validated by the pure rules against the server's own state.
- `ReplicatedStorage.NightRemotes.Combat` (RemoteEvent, client to server): `Combat(action: string)` with `attack`, `skill`, `dash` or `trigger`. No positions, targets or amounts. Checks in C10.
- `ReplicatedStorage.NightRemotes.Fx` (RemoteEvent, server to clients): display-only events (hit with enemy id, amount and position; kill; telegraph; revive). Clients never send it.
- `ReplicatedStorage.NightStatus` (StringValue, JSON): state, wave, tier, seconds left, participant UserIds, boss HP fraction.
- Player attributes (server-written): `Profile` (JSON), `HP`, `MaxHP`, `Gauge`, `StyleRank`, `Charms`, `Blessings` (JSON), `Offers` (JSON).

## K. Disconnects and edge cases

- A participant disconnecting is the same as leaving (B2). Their enemies re-target within 1.0 s.
- The last participant leaving ends the run (`Idle`); enemies are removed.
- A downed player who leaves is removed and does not count for the defeat check.
- Joining while every participant is downed is allowed: the joiner is alive, so the run continues.
- Requests during the wrong state (`pickBlessing` outside a break, `equipWeapon` in a run, a second pick in one break) are refused and change nothing.

## L. Module plan and unit tests

New pure modules in `src/shared/` (no Roblox APIs), each with `tests/<Module>.spec.luau` registered in `tests/run.luau`:

| Module | Contents | Tests |
|---|---|---|
| `Rng` | Small seeded generator (`next(state) -> (value in [0,1), state)`, `int(state, lo, hi)`), so every random choice is reproducible under Lune | same seed gives the same sequence; `int` stays in range |
| `CombatRules` | Weapon table, `attack(state, t)` combo logic, `hits(attacker, facing, targets, attack)`, damage formula, gauge gain, trigger accept, dash accept, teleport guard | every C1 combo case (too early, window, recovery, reset); arc and range edges, point-blank, vertical band; C6 rounding with each multiplier; gauge cap and no gain in Trigger; dash 0.95 s tolerance; guard threshold |
| `WaveRules` | Enemy stats, scaling (D5), composition (D4), spawn order and gates, targeting (D2) | budget sum equals `B` for waves 2–9, n 1–6, 50 seeds; intro-wave first enemy; only allowed types; oni cap; wave 1 count; gate rotation; alive cap; scaling values at n = 1, 6 and t = 1, 5; nearest-target ties |
| `BossRules` | Phases, attack sequences, skull multipliers, stagger timing | phase at 66% and 33% boundaries; summon once on entering phases 2 and 3; sequence order loops; multipliers ×1.0, ×1.5, ×2.0 |
| `BlessingRules` | Pool, offers, apply, `modifiers` | offers distinct and deterministic per seed; maxed and party-only excluded; fewer than 3 when few remain; every modifier formula including the rising-cooldown floor |
| `RunRules` | State machine (B), join and leave (B2), host, tier clamp, downs and revives (G), defeat check, catch-up count, break heal | every transition in B; join in each state; 6-participant cap; host hand-over; defeat only with no charm pending; revive timing and reset; break heal values |
| `MetaRules` (generalised `ProgressRules`) | Days, weeks, streak, weekly, quests, levels, cosmetics by slot, sanitise | existing ProgressRules specs pass for Relay; `questsFor` gives 3 distinct quests for pool sizes 3–12 over 400 days; per-slot equip; tier unlock |
| `NightProgress` | Night config for `MetaRules`, `waveRewards` (F2), `applyWave`, `applyVictory`, weapon unlocks, profile sanitise (H7) | F2 example (465 XP, 290 souls); each multiplier; stats in F3; sanitise fallbacks |

Server scripts (`src/night/`): `NightServer` (run loop, combat requests, enemies), `Enemies` (models, movement, attacks), `Arena` (build), `Profiles` (reused pattern). Client (`src/night-client/`): `Menu`, `Movement`, `CameraFx`, `CombatFx` (input, VFX, soft lock, HUD widgets). Project file `night.project.json`, staging environment `night-staging`.

## M. Acceptance criteria (v0.1)

- [ ] All unit tests in section L pass in CI.
- [ ] Combo, hit test, damage, gauge and dash rules follow section C exactly (unit tests).
- [ ] Wave composition, scaling and spawning follow section D (unit tests).
- [ ] Boss phases and attack order follow D3 (unit tests).
- [ ] Blessing offers and modifiers follow section E (unit tests).
- [ ] Rewards and stats follow section F; the solo tier-1 rank-D win pays 465 XP and 290 souls (unit test).
- [ ] Run states, joins, leaves, downs and revives follow sections B, G and K (unit tests).
- [ ] Relay's existing `ProgressRules` tests still pass after the `MetaRules` change.
- [ ] A solo player can go from PLAY to killing the first wisp in under 15 s and finish wave 1 in under 60 s (Studio playtest, timed).
- [ ] A solo tier-1 night can be won by the designer in under 12 minutes (Studio playtest).
- [ ] Two clients in a local server: the second joins mid-wave, gets catch-up blessings, and revives the first (Studio multi-client test).
- [ ] Server frame time stays under 8 ms with 32 enemies alive (MicroProfiler capture).
- [ ] Start-menu screenshot passes the I2 first-screenshot test, reviewed by SHANNON.
- [ ] Every mesh, track and SFX has a register row; no Robux prompts, no paid items.

## N. Kill criteria

- **Week-1 feel gate:** after combat, wave 1–3 enemies and the arena block-out are built, SHANNON plays three runs and rates combat below 4 out of 5 or calls it "not good enough". Then stop and switch to concept A (Demon Tide), reusing the arena, meshes and movement.
- **Live:** under 60% of new players clear wave 2, or the median first session is under 6 minutes, over the first 500 visits.
- **Live:** fewer than 30% of players who finish a night start another.

## O. Facts, assumptions, hypotheses

- **Fact:** Roblox ranks games on play-through, first-play bounce, play days and playtime, then co-play days (Creator Docs, Discovery; sources in `game3-concepts.md`).
- **Fact:** anime combat (battlegrounds) and co-op wave games are among the most-played genres in 2026 (sources in `game3-concepts.md`).
- **Fact:** the existing Relay modules (`ProgressRules`, `StyleRules`, `Profiles`, `Menu`, `Movement`, `CameraFx`, `Models`) and six generated meshes are in this repo and registered.
- **Assumption:** Roblox's default Animate script plays the built-in tool Slash and Lunge animations on R15 when a tool sets `toolanim`. To verify in Studio on day 1; the code-driven blade sweep (C9) is the fallback.
- **Assumption:** server-decided hits feel fair at typical ping because hitboxes are generous (110–160 degree arcs, point-blank rule) and VFX play at once on the client.
- **Assumption:** 32 part-built enemies with `AlignPosition` stay within the server budget.
- **Assumption:** Roblox's mesh generator can make a recognisable skull, bone hand, camphor tree, shrine hall and lantern yokai at these sizes.
- **Hypothesis:** a 9-to-10-minute night with banked rewards per wave keeps players for a second night.
- **Hypothesis:** paying souls by style rank teaches players to mix moves without a tutorial.
- **Hypothesis:** the party bonus, revives and Spirit Link give friends a reason to come back together (co-play days).

## P. Open questions

- Decision 0007 for the economy, remotes and save schema (rule 8), and a task file in `studio/tasks/` (rule 1), before build.
- Boss music: which APM track (SHANNON's taste).
- **Cut order if the build cycle runs long:** Nodachi, then Twin Kodachi, then the mask slot, then tiers 4–5, then the Shockwave and Spirit Link blessings. The core (katana, four enemies, two bosses, ten blessings, three tiers, all meta hallmarks) stays.
