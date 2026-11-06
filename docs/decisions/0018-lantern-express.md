# 0018: Lantern Express v0.1: place structure, seated rule, remotes, save schema v1, economy, age rating

Date: 2026-11-06
Status: **Proposed** for SHANNON (checkpoint `docs/checkpoints/LANTERN-V01.md`). Proposed by A06 (Designer and Architect thread, task LANTERN-001) under CLAUDE.md rule 8, for the concept the Director chose (A in `docs/game-design/game6-concepts.md`). Implements `docs/game-design/game6-gdd.md` (the GDD; section letters below refer to it); signatures in `docs/architecture/lantern.md`. Uses the kit (decision 0011) and `MetaRules`; monetisation stays off (decision 0002). Hard rules: no stealing, no trading, no text input, no paid anything, the G3 anti-pressure list, nothing earned is ever lost (GDD J).

## Decision

### 1. Place structure: one place, one crew per server

One Rojo project, `lantern.project.json`, builds one place. Each server holds Lamplight Depot (the hub), both track loops, the stop sites, Dawn Station and **one train with one crew of up to 6**. Max Players is 6. A run starts at the hub, runs three legs that each return to the hub Depot (leg 3 ends at Dawn Station) and ends at the hub; the server then waits for the next run. There is no lobby place, no `TeleportService` and no reserved server.

Why this and not a lobby place with a reserved server per run:

- **Friends get in with Roblox's own tools.** The Join button on a friend's profile follows them into a public server, and private servers (free, if SHANNON approves) give a fixed crew its own server. A reserved server cannot be joined through the Join button; letting a friend reach a run there needs the access code stored in a MemoryStore, a lobby that looks it up and a teleport that can fail and must be retried. That is the whole of GDD I4 ("friends join at the next stop") done by the platform instead of by us.
- **Testing works.** `TeleportService` does not work in Studio, so every run-start and run-end path in a two-place design is untested until staging. In one place, Studio runs the whole game with Test > Players 2 to 6.
- **One publish target.** `publish.yml` publishes one place per environment (`ROBLOX_PLACE_ID`); a second place would need a second id, a second upload and a second post-publish check.
- **No save hand-off race.** A teleport makes the next server load the profile while the last one is still writing; the kit's session lock then reports "busy" and the player plays offline for that run. With no teleport the profile loads once per visit.
- **Co-op by default.** Roblox fills public servers, so a solo player in a busy game is usually joined by others at the next stop. That is the design (GDD I1, pillar 3). A player who wants to ride alone uses a private server or a quiet server; the game works for a crew of one (section P of the GDD).

Costs accepted: a public server's crew is whoever Roblox matched (no ready-up lobby); a server with a stuck run cannot be left without leaving the server (the hub returns after any run end, and an empty crew ends the run); Max Players is set by hand in Creator Hub (a place file cannot carry it), so the server warns in the log when `Players.MaxPlayers` is above 6, as Garden does.

### 2. The seated-while-moving rule

The train moves only while every crew member is seated or in the fog (a caught player is hidden and anchored until they reappear seated). Exactly:

1. The train leaves a platform only when every crew member is seated; at a departure forced by the fog, the Depot's 90 s or the hub's 20 s, the server seats every crew member who is not seated and not in the fog (nearest free seat of their last kind, else any).
2. While the train moves, a crew member who leaves a seat (jump, Sit off, an exploit) is put back in a seat by the server within 0.5 s (a 0.25 s check), and the train does not slow or stop for it. The client also disables jumping while seated on a moving train, so a normal player never sees this.
3. A player who presses PLAY while the train moves is placed straight into a seat (GDD I4). A non-crew player (still in the start menu) who sits in a train seat is stood up at once and is never carried away.
4. Nobody walks on a moving car, so no character physics runs on the train; the only moving bodies are the server's own cars.

Train physics: each car is one unanchored assembly whose base part has `RootPriority = 127`, the server is its network owner (`SetNetworkOwner(nil)`, re-asserted after every seat change, since a SeatWeld merges the character into the car assembly), and a rigid `AlignPosition` plus `AlignOrientation` (one attachment, `RigidityEnabled`) pull it to `TrackRules.at(track, d − offset)` every Heartbeat. Cars are not jointed to each other; wheels and decor do not collide; floors do. Clients see interpolated physics replication. **Fallback** if the two-client check in LANTERN-012 shows jitter at cruise speed: anchored server cars and a client-drawn train from the replicated distance and speed, budgeted as its own task (the seat welds then need the client copy; not designed here).

### 3. Remote contract

`ReplicatedStorage.LanternRemotes` is made by the kit's `Remotes.create("LanternRemotes", router)`: `Request` (RemoteFunction) and `Fx` (RemoteEvent). The server adds one `UnreliableRemoteEvent` named `Aim` to the same folder.

**`Request(action, arg?) -> (ok, code?)`** through `kit/Router`: loading → rate (burst 6, 4 a second; `ping` costs 2 tokens) → known action → `Payload` → handler. `arg` is nil or a string of at most 32 bytes matching the action's pattern; an `arg` to an action that takes none is refused. Refusal codes are short strings the client maps to text (`loading`, `rate`, `unknown`, `payload`, `phase`, `seat`, `far`, `full`, `coal`, `oil`, `parts`, `max`, `cooldown`, `owned`, `locked`, `tickets`, `refused`, `error`).

| Action | `arg` | Accepted when (server state only) |
|---|---|---|
| `play` | nil | profile loaded; not in the crew; crew under 6. Joins the crew and places the character per GDD I4 |
| `sit` | `any`, `turret`, `stoker`, `mender` or `passenger` | in the crew; not in the fog; a free seat of that kind; when the train stands, the character's root within 40 studs of the train |
| `stand` | nil | seated; the train is not moving |
| `drop` | nil | carrying anything (GDD D5) |
| `stoke` | nil | in the Stoker seat; the train moving; coal ≥ 2; 6 s since the last stoke |
| `mend` | nil | in the Mender seat; oil ≥ 1; lantern ≤ 88; 3 s since the last mend |
| `buy` | `boiler`, `bunker`, `lamps`, `coal` or `oil` | phase `depot`; in the crew; `DepotRules.buy` (Parts, level, bunker room, oil room) |
| `vote` | `forest` or `lake` (Depot before legs 2 and 3); `free` or `weekly` (hub) | the phase offers that vote; in the crew; replaces the player's earlier vote |
| `ping` | a ping id (`coal`, `critter`, `help`, `back`, `wisps`, `thanks`), or `<id>:<itemId>` | in the crew; 2 s since the player's last ping; an item id names an item of the current stop within 60 studs |
| `claimQuest` | quest id | today's quest, progress ≥ goal, not claimed (`MetaRules.claimQuest`) |
| `claimLogin` | `week` or `month` | `LanternProgress.canClaimLogin` (the next slot's sign-in count reached this period) |
| `buyCosmetic` | cosmetic id | priced, not owned, Tickets ≥ price (`MetaRules.buy`) |
| `equip` | cosmetic id | unlocked (`MetaRules.equip`; `livery` or `lamp` slot) |
| `badge` | `stoker`, `lamplighter`, `scout`, `mender` or `none` | the role's tier ≥ 1 (or `none`) |
| `follower` | species id or `none` | the species is in the player's album (or `none`) |

**Server-side prompts** (ProximityPrompt `Triggered`, no remote): `Pick up` on every free item and `Help carry` on a critter crate carried alone, checked by `CarryRules` and the reach from the character's server position (8 studs). **Loading** is automatic: the server checks every carrier's root against the train's load box at 5 Hz during a stop.

**`Aim:FireServer(dir: Vector3)`** (client to server, unreliable): the lamp direction in the train's frame. Accepted when `typeof(dir) == "Vector3"`, every component finite, `0.5 ≤ dir.Magnitude ≤ 1.5`, the sender sits in a turret seat, and the sender's aim bucket allows it (burst 4, 12 a second; extra events are dropped silently). The server normalises it, clamps pitch to −15° to +75°, stores it with `os.clock()`, and treats it as stale after 0.5 s. The server never receives a hit, a target, a position or a time.

**`Fx` (server to clients, display only; the server ignores `Fx.OnServerEvent`):** `arrive {phase, leg, stop, tile, line}`, `bell {at}`, `depart`, `load {by, kind, count}`, `rescue {by, species, rarity}`, `new {species}` (to that player only), `caught {userId}`, `back {userId}`, `wisps {list = {id, born, from, target, speed, phase}}`, `puff {ids}`, `dim {id, lantern}`, `lampeater {born, seed}`, `dive {at, target}`, `fed`, `ping {userId, id, pos}`, `buy {userId, id, level}`, `payout {tickets, xp, text}` (to one player), `runEnd {reason, summary}` (to each player, their own numbers), `announce {name, species, rarity}`, `notice {text}` (to one player).

**`ReplicatedStorage.LanternRun`** (Folder; server-written attributes, on change, `D` at 2 Hz): `Phase`, `Leg`, `Stop`, `Line`, `Weekly`, `Tile`, `PhaseAt`, `BellAt`, `LeaveAt` (all times `GetServerTimeNow` seconds), `D`, `Speed`, `Coal`, `CoalCap`, `CoalNeed`, `Lantern`, `Oil`, `Parts`, `Boiler`, `Bunker`, `Lamps`, `Wave`, `Conductor` (UserId), `Crew` (JSON: userId, seat kind, active, badge), `Votes` (JSON tallies).

**Player attributes** (server-written): `Profile` (JSON of the save the client needs), `ProfileOnline`, `Tickets`, `Level`, `XP`, `LastReward`, `Carry` (JSON), `Seat`, `Badge`, `Follower`, `Lamp`.

### 4. Save schema v1 (one player's save only)

Store `LanternProfile<suffix>` (`_studio`, `_staging` or production; `PRODUCTION_UNIVERSE_ID` stays nil until SHANNON approves a production release), key `player_<UserId>`, through the kit's `Saves.start` (session lock, coalesced `UpdateAsync` at most every 7 s, 60 s autosave, final write on leave and in `BindToClose`).

```
{ schemaVersion = 1,
  xp, coins,                       -- coins are Tickets (the MetaRules field)
  lastSeen,
  index = { "<species>", ... },    -- album: species rescued at least once, first-rescue order
  rescues = { [species] = count },
  stats = { runs, dawns, legs, depots, loads, rescues, rareRescues, puffs, stokes, mends, caught, fed },
  best = { critters, dist },       -- all-time single-run bests
  weekBest = { week, critters, dist },
  milestones = { ["4"] = true, ["8"] = true, ["12"] = true },
  follower,                        -- species id or ""
  livery, lamp, badge,             -- cosmetic slots; badge is a role id or ""
  owned = { [cosmeticId] = true }, -- priced and granted cosmetics
  daily = { streak, last }, week = { key, days, lastDay, claimed },   -- MetaRules fields (ticked, pay nothing)
  quests = { day, progress, claimed },
  login = { week, weekDays, weekLast, weekClaimed, month, monthDays, monthLast, monthClaimed } }
```

Sanitising (`LanternProgress.sanitize`): numbers floored and clamped (XP 1,000,000; Tickets 10,000,000; counts 1,000,000; `best.dist` 20,000); unknown species dropped from `index` and `rescues`; every `rescues` species with a count of 1 or more is in `index` (appended in id order if missing) and `index` holds no species without a count; `follower` must be in `index`, else ""; `livery`, `lamp` fall back to `classic`, `warm` when unknown or locked; `badge` must be a role with a tier of 1 or more, else ""; `owned` keeps priced and granted ids only; `milestones` keeps the keys 4, 8, 12; `lastSeen` in the future becomes now; `login` as `LoginRules.sanitize` (the same field shapes); `weekBest` older than this week resets to zeros. A record without `schemaVersion` loads as v1.

**A newer save loads read-only:** a record whose `schemaVersion` is above 1 (written by a later build after a rollback) runs that session offline and is never written, so its unknown fields survive. This is a backwards-compatible kit addition (`SaveStore` option `newer`, LANTERN-005, noted in decision 0011).

**One save per write:** every reward is computed from the run state and written to each crew member's own record with its own `saves.apply`. No operation changes two players' records as one unit and nothing moves between players, so no ledger, idempotent ids or heal at load are needed (studio lessons, Engineering). Critter species are rolled when a stop is built, never inside a change, so a flush that re-applies a change never re-rolls.

**Weekly boards:** ordered stores `LanternWeekCritters<week><suffix>` and `LanternWeekDist<week><suffix>`, key `player_<UserId>`, written once per player per run end when the run beat their `weekBest` (`UpdateAsync` keeping the larger value); read with `GetSortedAsync` (top 10) every 60 s; names from `GetNameFromUserIdAsync`, cached.

### 5. Economy values (rule 8; the GDD tables are the record)

- **Train and run (C1):** cruise 20 / 23 / 26 studs/s; accel 4; ride 700 studs; night 3,600; coal 1 per 60 studs; bunker 80 / 100 / 120, full at start; stoke +25% for 6 s, 2 coal, 6 s cooldown; lantern 100; oil store 6; auto-pour +8 under 25; mend +12, 3 s cooldown.
- **Stops (C2, C3):** calm 70 s; fog 6 studs/s +1 a second to 16 over 160 studs; caught 10 s; walk 16, carrying 15 / 13 / 9 / 13; reach 8; help break 14. Per stop with n active: coal sacks 6 + 3n (5 coal each), Parts bags 2 + n (3 Parts), oil cans 2 + floor(n/2), supply crates 1 + floor(n/2) (10 Parts), critter crates 1 + ceil(n/2); stop 1 of a run has a crate on the 22-stud site.
- **Nights (C4):** waves at 8 s then every 25 s; wisps a wave 4 / 6 / 8 per min(n, 4) on legs 1 / 2 / 3, + (n − 4) above 4, +1 on the Lake Line; beam 7°, range 80 / 90 / 100; puff 0.6 / 0.45 / 0.35 s; dim 6 / 4.5 / 3.5 / 3 by crew size; Lampeater from 50 s on leg 3, dives every 8 s, −10, shooed by 0.8 s of beam, fed at 15 + 8(n − 1) beam-seconds.
- **Depot (F):** Boiler 30 / 60, Bunker 25 / 50, Lamps 30 / 60 Parts; coal 30 for 12; oil 2 for 10; stay 90 s max; +40 lantern on arrival.
- **Tickets (H3, C7):** a load worth v pays each active crew member ceil(v × (1 + 0.1(n − 1)) / n): small items 1, supply crate 8, critters 10 / 15 / 25 / 50 / 100 by rarity. Depot +30 each; Dawn +150 each; Lampeater fed +50 each; leftover Parts ceil(Parts / n) each.
- **XP (H3):** small load 2, big load 5, crew rescue 20, new species 50, puff 2, stoke 1, mend 3, stop left aboard 5, Depot 40, Dawn 150; levels by the shared curve.
- **Quests (H5):** the 8-quest pool, 100 to 250 Tickets; completed and unclaimed at the day's end, paid automatically.
- **Login (H5):** weekly 40 / 60 / 80 / 100 / Midnight Express livery (150 once owned) / 120 / 150; monthly at 3 / 7 / 12 / 18 / 22 / 26 / 30: 100 / 150 / 200 / Ember Kit (250 once owned) / 250 / 300 / Aurora Beam + 400 (400 once owned); earned and unclaimed paid at the rollover.
- **Album (H4):** the five odds rows; species split evenly within a rarity by line and tile; milestones 4 (200 Tickets), 8 (Mossback livery), 12 (Moonlit lamp and 1,000 Tickets).
- **Cosmetics (H6):** liveries `classic` L1, `ember` L5, `fern` L10, `brass` 2,500, `ivory` 6,000, `mossback` album, `midnight` login; lamps `warm` L1, `mint` L3, `rose` L8, `sky` 1,200, `gold` 4,000, `moonlit` album, `aurora` login. Role badges (H7) by counts 30 / 300 / 1,500 stokes, 100 / 1,000 / 5,000 puffs, 50 / 500 / 2,500 loads, 15 / 150 / 750 mends.

Pacing check (GDD P): a run 24.7 to 28.0 minutes by crew size, legs 8.3 to 9.3 minutes with the Depot, 709 to 868 Tickets and about 1,050 to 1,270 XP a player a run, the album in a median of 10 solo runs.

### 6. The 16+ trial and the maturity questionnaire

- **Audience setting:** all ages. That requires, before the first public publish (not for a private staging experience), an owner account that is ID-verified (age-checked), has 2-Step Verification on, and either a Plus or Premium subscription held for 2 months or the refundable 1,000 Robux per-game fee (M38, M39; spending needs SHANNON's approval, rule 7). The game then starts in the 16+ trial and needs 250 unique plays from highly engaged players within 60 days, plus Roblox's safety review, to reach Roblox Kids (5 to 8) and Select (9 to 15).
- **Questionnaire answers** (Creator Hub, the experience's Maturity and Compliance questionnaire; the wording below is our reading of the Content Maturity categories in M40 and must be checked against the live form at the checkpoint):

| Category | Answer | Why |
|---|---|---|
| Violence | Mild, unrealistic | lamp beams make non-human shadow wisps puff into sparkles; no weapons, no damage, no death, no player ever hurt. Answering "Mild" rather than "None" is the conservative reading and does not change the target label |
| Blood and gore | None | |
| Fear | Mild | ominous music, fog, suspense, a giant moth; no jump scares before the first Depot and every big moment announced |
| Crude humour | None | |
| Romance | None | |
| Alcohol, drugs, tobacco | None | the inn tile shows tea, not drink; artists check the tile props |
| Strong language | None | there is no text in the game but our own |
| Gambling (including simulated) | None | critter rolls are free, earned by play and never bought (M44) |
| Paid random items | None | no paid items at all |
| Paid item trading | None | no trading |
| Social hangout | No | a goal-driven game; no private spaces |
| Free-form user creation | No | no building, drawing or text |
| Text chat | Roblox's default chat only | no custom chat, no text input |

Expected label: **Mild** (fear). Kids sees Minimal and Mild only, so Mild keeps the game open to 5 to 8 year olds after evaluation.

### 7. Child safety (GDD G)

No combat, no stealing, no trading, no gifting, no text input, no paid anything; odds published; no near-miss reveals; the only timers on screen are the run's own; nothing earned expires (quests and login slots are paid at the rollover); losing a run costs only the run; display names only; Mild fear with no jump scare before the first Depot and a "Calm night" setting.

## Why

- The place structure is the simplest one that gives 1 to 6 friends a run with the platform's own join tools, and the only one that can be tested end to end in Studio (section 1).
- The seated rule removes the hardest problem in a train game, characters on moving physics, by never having one (section 2).
- Paying every load at once, to each player's own save, is what makes "nothing earned is ever lost" true by construction, and it removes the need for a ledger (section 4).
- Shared rescues and shared load Tickets make strangers in a public server a crew without chat, and the per-crew loot keeps a player's earnings close whatever the crew size (GDD P).

## Consequences

- LANTERN-002 adds `lantern.project.json`, the CI build and place check, and the `lantern-staging` target to `publish.yml`; SHANNON creates the experience, sets Max Players 6 and the private server price, and creates the GitHub environment (checkpoint).
- LANTERN-005 moves the UI kit into `src/kit-roblox/modules/UiKit.luau` with an injected theme and adds the `newer` option to `SaveStore`, both noted in decision 0011; Garden keeps its own `UiKit.luau` until a Garden release moves it.
- `src/relay/Models.luau` reads `LanternAssets` the way it reads `GardenAssets` (three lines); asset names must not collide with Night or Garden names (a spec checks).
- Any later change to these values, remotes or the schema needs an amendment here or a new record (rule 8); schema v2 keeps every v1 field (studio lessons).

## Amendment 1 (2026-11-06, LANTERN-012, integration)

Section 3 as built; no value, schema or client-to-server contract changes.

- **`Fx shoo {target}`** (server to all, display only): a Lampeater dive that the beams light for 0.8 s is shooed (`WispRules` event `shoo`) instead of dimming the lantern; clients play a sparkle on the moth.
- **Carry refusal codes `gone`, `taken`, `hands`, `big`** (`CarryRules.canPick`/`canHelp`: the item went first, someone else carries it, the hands hold a big item, small items are held when picking a big one) join `full` and the rest. They come from the server's `Pick up` and `Help carry` prompts, which have no reply channel, so players see them as `Fx notice` words; no `Request` action returns them.
- **Shapes the clients read:** the `Carry` attribute is JSON `{ small = { kinds }, big = kind?, help = itemId? }` (`help` when the player holds the other end of a critter crate); the `Stop` model (`Workspace.Lantern.Stop`) carries its stop frame as the `Site` CFrame attribute (architecture lantern 4.4: origin on the deck's track edge 4 studs out, +Z into the stop), which the client reads for the fog wall.
