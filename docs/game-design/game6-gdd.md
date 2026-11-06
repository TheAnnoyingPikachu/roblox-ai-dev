# Lantern Express: game design spec (v0.1)

Status: draft for SHANNON (task LANTERN-001; checkpoint `docs/checkpoints/LANTERN-V01.md`). Concept A in `game6-concepts.md`, chosen by the Director on 2026-11-06. Economy values, remotes and the save schema are decided in `docs/decisions/0018-lantern-express.md` (Proposed, CLAUDE.md rule 8); signatures in `docs/architecture/lantern.md`; tasks in `docs/production/game6-plan.md`. Facts cited as M1 to M52 are in `game6-market-research.md`. The studio lessons (`docs/production/studio-lessons.md`) are binding; section G puts the child-safety rules on the first pages, as they ask.

## A. Product

- **Pitch:** ride a tiny steam train through Hollowmere, a spooky-cute valley, with up to five friends. Scavenge each stop before the fog rolls in, keep the lanterns lit through the night with lamp turrets, and bring every lost critter home to Dawn Station.
- **Audience:** the game is published for all ages and therefore starts in Roblox's **16+ trial** (M38, M39): until it earns 250 unique plays from highly engaged players within 60 days, only age-checked players aged 16 and up can find it. It must therefore appeal to 16-year-olds first (fog sprints, a giant moth, a weekly board) and still be fit for 5-year-olds after evaluation. Target maturity label **Mild** ("mild fear": ominous music, suspense; M40). No blood, no weapons, no jump scares before the first Depot (section L). Roblox's filtered text chat stays on; the game itself has no text input of any kind.
- **Platforms:** PC, phone, console. Every action is a walk, a ProximityPrompt (`E`, gamepad X, tap) or a big on-screen button; aiming is the mouse, a drag or the right stick.
- **Sessions:** a run is three legs, 25 to 30 minutes (section P); each leg ends at a Depot where the crew can stop. The target session is the 19 to 24 minute band of M27 and holds through day 2 to 7 and 8 to 28 returns (M31) with the album, quests, login tracks and the weekly line (section H).
- **Pillars:**
  1. Playing in 10 seconds, a critter rescued inside the first minute, a goal and a choice before the third (section K).
  2. Every stop is a risk-and-return decision with a clip at the end of it: the fog sprint (Q8).
  3. Better with friends, complete alone: every system scales from one player to six (section C6).
  4. Nothing earned is ever lost (section J). Losing a run costs only the run.
  5. Looks finished in the first screenshot: the Blender HD standard on every mesh, a style test before features (section M).
- **Non-goals (v0.1):** combat, weapons, stealing, trading, gifting, text input, Robux or paid items (decision 0002), permanent train cars, more than one biome, character animation rigs.
- **Server:** one crew of up to 6 per server (decision 0018: one place, Max Players 6).

## B. Core loop

**30 seconds.** The train stops at a village. You jump off and grab coal, spare parts or a lost critter's crate: three small things or one big one. The fog bell rings and the fog rolls over the village towards the platform; you sprint back, a friend helps you haul the critter crate, and you sit down as the whistle screams. At night you sit at a lamp turret and sweep the beam over shadow wisps drifting at the train; caught in the light they puff into sparkles. Nobody is ever hurt.

**A leg (8 to 10 minutes).** Ride → stop 1 → ride → stop 2 → ride → stop 3 → the night → a Depot. The crew spends this run's Parts on the train (boiler, bunker, lamps, coal, oil), votes on the next branch (Forest Line or Lake Line), and sees its rescued critters riding in the passenger car.

**A run (25 to 30 minutes).** Lamplight Depot (the hub) → leg 1 (always the Forest Line) → Depot → leg 2 (Forest or Lake) → Depot → leg 3 → the Lampeater → Dawn Station. Every load pays its Tickets, XP and album entries into each crew member's save the moment it reaches the train, so a run that ends early, a player who leaves, or a server that shuts down takes nothing away.

**Ten days.** Fill the 12-critter Hollowmere Album (Moon Hare only on leg 3 far crates), level up, earn role badges, follow the weekly and monthly login tracks to the Midnight Express livery and the Ember Kit, and climb the Line of the Week board.

## C. Numbers (the master table; `LanternConfig` holds every value)

### C1. The train

| Value | Number | Notes |
|---|---|---|
| Cars | Engine (with tender), Cargo Car, Lamp Car, Passenger Car | in that order; 78 studs long |
| Seats | 12: Stoker 1 (cab), lamp turrets 4 (engine roof, two on the Lamp Car, Passenger roof), Mender 1 (Lamp Car lantern rack), passenger 6 | a crew of 6 always has a seat |
| Cruise speed | 20 / 23 / 26 studs/s | Boiler I / II / III |
| Acceleration and braking | 4 studs/s² | the train brakes to stop exactly at a platform |
| Stoke | +25% speed for 6 s, costs 2 coal, 6 s cooldown | Stoker seat only, while moving |
| Ride between stops | 700 studs | 40 s at Boiler I, 33 s at III |
| Night stretch | 3,600 studs | 180 s at Boiler I (7 waves), 138 s at III (6 waves) |
| Coal burn | 1 coal per 60 studs travelled | 95 coal a leg: 35 for the rides, 60 for the night |
| Coal bunker | 80 / 100 / 120 | Bunker I / II / III; a run starts full |
| Out of coal | the train coasts to a halt at 2 studs/s² and the run ends | warning chip at 15 coal and at "not enough for tonight" |
| Lantern meter | 0 to 100, starts at 100 | the train's light; 0 ends the run |
| Oil store | up to 6 cans | an oil can loaded with the store full pours at once (+8) |
| Auto-pour | +8 lantern from one can when the lantern is under 25 | every 3 s while it stays under 25 and oil remains |
| Mend | +12 lantern from one can, 3 s cooldown | Mender seat only, lantern 88 or less |

### C2. Stops and the fog

| Value | Number | Notes |
|---|---|---|
| Stop size | 120 studs wide, 160 deep | one tile from the kit, beside the platform |
| Calm time | 70 s from arrival to the fog bell | the HUD shows the bell time; the train's own timer, not a pressure offer (G3.6) |
| Fog | starts at the far edge at the bell, 6 studs/s rising by 1 studs/s each second to 16 | crosses 160 studs in 13.1 s, so a stop lasts at most 83 s |
| Who the fog catches | any crew member whose root is deeper than the fog front | drops what they carry, waits 10 s in the fog, reappears seated on the train |
| Leaving early | everyone in the crew seated for 3 s, and at least 10 s after arrival | on arrival everyone is stood up automatically |
| Leaving at the fog | when the fog reaches the platform | crew on the platform are seated automatically; caught players come back after their 10 s |
| Walk speed | 16 studs/s | Roblox default |
| Carrying | 3 small: 15; a supply crate: 13; a critter crate alone: 9; a critter crate with a helper: 13 (both) | set by the server |
| Pick-up reach | 8 studs from the item | ProximityPrompt, 0.3 s hold |
| Loading | walk into the train's load box (the platform side of any car, 6 studs out) | everything carried loads at once |
| Help-carry break | carriers more than 14 studs apart | the helper lets go; the first carrier keeps the crate |

Fog check (script, section P): leaving at the bell, a lone critter carrier gets home from 118 studs or nearer; two carriers, anyone carrying small items, or a supply crate get home from anywhere (159 studs). The fog sprint is the greed decision: one more trip after the bell, or a far critter alone.

### C3. What a stop holds (crew size n = active crew as the train approaches the stop; section I3)

| Item | Kind | Count | On loading |
|---|---|---|---|
| Coal sack | small | 6 + 3n | +5 coal (to the bunker cap; a full bunker refuses coal and the sack stays carried) |
| Parts bag | small | 2 + n | +3 Parts |
| Oil can | small | 2 + floor(n / 2) | +1 oil in the store |
| Supply crate | big | 1 + floor(n / 2) | +10 Parts |
| Critter crate | big, heavy | 1 + ceil(n / 2) | the critter is rescued (section H4) |

Every tile has 24 small sites (up to 3 items each, depth 15 to 150 studs) and 8 big sites at depths 22, 40, 58, 78, 96, 114, 132 and 150 studs. Critter crates take big sites first (seeded order), supply crates the rest. **Stop 1 of every run puts one critter crate on the 22-stud site**, so the first rescue is always close. Crates glow in their rarity colour (C7) from 40 studs; the species stays hidden until it reaches the train.

### C4. Nights, wisps and the Lampeater

| Value | Number | Notes |
|---|---|---|
| Waves | first 8 s into the night, then every 25 s | 7 at Boiler I, 6 at II and III |
| Wisps a wave | (4 / 6 / 8 on legs 1 / 2 / 3) × min(n, 4) + (n − 4 if n > 4) | +1 on the Lake Line; table C6 |
| Wisp approach | spawn 60 to 75 studs from the train, 4 to 20 high, spread over 3 s; drift at 6 / 7 / 8 studs/s (crew 1 / 2 / 3+) to a lantern point with a 2-stud wobble | in the train's own frame, so a moving train does not change the aim; one or two lamps turn all round, so their wisps come slower (LANTERN-015) |
| Beam | 7° half-angle cone, range 80 / 90 / 100 studs | Lamps I / II / III |
| Puff | 0.6 / 0.45 / 0.35 s of beam on a wisp | Lamps I / II / III; the exposure adds up from every beam on it |
| A wisp that reaches a lantern | dims the lantern by 4.5 / 3.5 / 3.5 / 2.75 | by crew size 1 / 2 / 3 / 4+ (LANTERN-015: was 6 / 4.5 / 3.5 / 3; both unassisted solo Studio runs lost the lantern by wave 5. LANTERN-016: 4+ from 3 to 2.75, so a crew of 4 is no harder than a crew of 3, QA m12) |
| Lampeater | leg 3 only, from 50 s into the night (after two waves) to Dawn Station | circles the train 45 studs out, 25 up |
| Lampeater dive | every 8 s, 3 s long, at one lantern point | shooed by 0.8 s of beam during the dive; otherwise −10 lantern |
| Feeding the Lampeater | 15 + 8 × (n − 1) beam-seconds on it in total | it purrs and flies to the moon: +50 Tickets each; at Dawn it flies away anyway |
| Turret aim | yaw all round, pitch −15° to +75° | sent as a direction only (section E2) |

### C5. Depot, hub and run end

| Value | Number |
|---|---|
| Hub (start of a run) | the train leaves 3 s after every crew member is seated, or 20 s after the first one sits (the rest are seated automatically) |
| Depot stay | leaves 3 s after everyone is seated and at least 10 s after arrival, or at 90 s (everyone seated automatically) |
| Depot arrival | +40 lantern (to 100), +30 Tickets and +40 XP for each crew member |
| Dawn Station | +150 Tickets and +150 XP for each crew member; +50 Tickets more if the Lampeater was fed |
| Run end summary | 12 s card, then everyone is at the hub |

### C6. Crew size table

| Crew | Coal sacks | Parts bags | Oil cans | Supply crates | Critter crates | Wisps a wave, legs 1 / 2 / 3 | Dim a wisp | Lampeater beam-seconds |
|---|---|---|---|---|---|---|---|---|
| 1 | 9 | 3 | 2 | 1 | 2 | 4 / 6 / 8 | 4.5 | 15 |
| 2 | 12 | 4 | 3 | 2 | 2 | 8 / 12 / 16 | 3.5 | 23 |
| 3 | 15 | 5 | 3 | 2 | 3 | 12 / 18 / 24 | 3.5 | 31 |
| 4 | 18 | 6 | 4 | 3 | 3 | 16 / 24 / 32 | 2.75 | 39 |
| 5 | 21 | 7 | 4 | 3 | 4 | 17 / 25 / 33 | 2.75 | 47 |
| 6 | 24 | 8 | 5 | 4 | 4 | 18 / 26 / 34 | 2.75 | 55 |

### C7. Rarity

| Rarity | Crate glow and tag colour | Rescue sound | Tickets (before sharing) |
|---|---|---|---|
| Common | moss green (120, 170, 110) | one soft chime | 10 |
| Uncommon | lake blue (90, 160, 230) | two rising chimes | 15 |
| Rare | lantern violet (170, 120, 230) | three chimes and a sparkle | 25 |
| Epic | amber gold (240, 180, 60) | a bell and a choir swell | 50 |
| Legendary | moon white with a shimmer (235, 240, 255) | the whistle tune on a celesta, a moon flash | 100 |

Tiers look and sound different (studio lesson); no near-miss reveals and no slot sounds (G3).

## D. Stops, carrying and the fog

1. **Arrival.** The train brakes at the platform, everyone is stood up, and the HUD shows "Scavenge! Fog bell in 1:10" and the coal bar ("Tonight: 44 / 60"). The stop tile is already built (the server builds it as the train brakes).
2. **Pick up.** Each free item has a prompt. Small items stack on your back (up to 3, any mix); a big item takes both hands and nothing else. The server checks reach (8 studs) and the carry rule; a refused pick tells you why ("Hands full: drop or load first").
3. **Help carry.** A critter crate carried by one player shows a "Help carry" prompt to the others. A helper takes the other handle; both walk at 13. If they drift more than 14 studs apart, the helper lets go. A helper never takes the crate: the first carrier keeps it (G1).
4. **Load.** Walking into the train's load box loads everything you carry. Coal goes to the bunker (a full bunker refuses coal), Parts to the crew pool, oil to the store, critters to the passenger car (and to every active crew member's album, H4). Every load pays Tickets and XP to the saves at once (section J).
5. **Drop.** The DROP button puts everything you carry on the ground where you stand. Anyone may pick it up again until the train leaves.
6. **The bell.** At 70 s the bell rings, the whistle screams and the fog rolls from the far edge (C2). The HUD bell chip turns red; nothing else counts down on screen.
7. **Caught.** A crew member deeper than the fog front is caught: what they carry drops there, the screen greys and the sound muffles for 10 s, and they reappear seated on the train ("The fog carried you back"). Nothing they own changes.
8. **Leaving.** The train leaves 3 s after everyone is seated (and at least 10 s after arrival) or when the fog reaches the platform. Items still on the ground or in the fog are gone for this run; a critter crate left behind goes back to its stop, and its species can be rolled again on any later stop (section J).

**Stop tiles (8; one tile a stop, picked by the seed from the line's six).** Forest Line: village, farm, windmill, orchard, inn, mill. Lake Line: village, farm, inn, mill, lighthouse, boathouse. A tile is a ground plate, three to five buildings and props with the 32 sites marked in `LanternConfig.TILES`; the tile mesh is decor and the sites are data, so code never reads the mesh.

## E. Nights, lamp turrets and the Lampeater

### E1. The night

Leaving stop 3, the light turns to dusk over the 700-stud ride; the night stretch starts dark. Every crew member is seated (turrets first: the server offers each player their last seat, else a free turret, else the Stoker, Mender and passenger seats). Waves come as C4. Wisps are soft dark puffs with two glowing eyes that drift in visibly from the fog; caught in a beam they swell, sparkle and pop with a chime. A wisp that reaches a lantern makes it flicker and dim. The lantern meter sits top centre; at 25 the auto-pour fires with a glug.

### E2. Lamp turrets (no hit is ever decided by a client)

- Sitting in a turret seat gives the lamp: the camera sits behind the lamp head, the mouse, a drag or the right stick swings it, and the beam is always lit.
- The client sends only the beam direction, in the train's frame, at most 10 times a second, over an unreliable remote (decision 0018). The server clamps it to the turret's pitch range, ignores a direction older than 0.5 s, and runs the hit test itself at 10 Hz against its own wisp positions: a wisp counts as lit when it is inside the 7° cone and the range. Exposure adds up across beams; at the puff time the server puffs it and every client plays the puff.
- Wisp paths are deterministic from their spawn record (`WispRules.pos`), so clients draw them without per-frame replication and the server tests against the same positions.

### E3. Stoker and Mender

- **Stoker** (cab seat): the STOKE button (+25% speed for 6 s, 2 coal). A shorter night means fewer waves; stoking trades coal for time.
- **Mender** (lantern rack seat on the Lamp Car): the MEND button pours one stored oil can for +12 (auto-pour gives +8).

### E4. The Lampeater (leg 3 finale)

At 47 s into the third night a warning ("Something big is coming...", a shadow across the moon, the music drops to a low drone) comes 3 s before the Lampeater rises from the fog: a giant soft-winged moth (about 70 studs wingspan, a soft amber glow) with lantern-glass eyes that sweeps in across the moon, then circles the train with slow wing beats, hungry for light. Every 8 s it dives at a lantern; enough beam during the dive shoos it. Beam on it at any time feeds it. When it has had its fill (C4) it purrs, glows and flies up to the moon, and the crew gets +50 Tickets each; if Dawn comes first it flies away at sunrise. The Lampeater never touches a player and never takes anything; it can only dim the lantern. The clip moment: the moth swooping low over the roof with four beams on it.

## F. The Depot

Every leg ends at Lamplight Depot (the hub; the two lines are loops that return to it, and leg 3 branches off to Dawn Station before the loop closes). The Depot panel opens on arrival for every crew member:

| Upgrade (this run only) | II | III | Effect |
|---|---|---|---|
| Boiler | 30 Parts | 60 Parts | cruise 20 → 23 → 26 studs/s |
| Bunker | 25 Parts | 50 Parts | coal cap 80 → 100 → 120 (the bunker keeps its coal) |
| Lamps | 30 Parts | 60 Parts | puff 0.6 → 0.45 → 0.35 s; range 80 → 90 → 100 |
| Coal | 12 Parts for 30 coal | repeatable while it fits | |
| Oil | 10 Parts for 2 cans | repeatable to the store cap of 6 | |

- **Parts are a crew pool for this run**, shown on the HUD with "for this run". Any crew member can buy at the Depot; the board shows who bought what ("Mia: Boiler II"). Every upgrade helps the whole crew, so there is nothing to grief. Parts left at the run end become Tickets: ceil(Parts / n) for each crew member (section J).
- **Branch vote** (before legs 2 and 3): two big cards, FOREST LINE ("more coal, gentler nights") and LAKE LINE ("rarer critters, one more wisp a wave"). Each crew member taps one; the train takes the majority at departure; a tie or no votes takes the Forest Line. The Lake Line's far crates use the Lake odds (H4) and its waves add one wisp.
- **Line of the Week vote** (at the hub, before leg 1): FREE RUN or LINE OF THE WEEK, the same way; a tie takes FREE RUN.
- The rescued critters of this run ride in the passenger car windows (up to 8 shown); followers walk beside their owners on the platform.

What the pacing check says a casual crew buys (P): a solo player about 2 upgrades a run (42 Parts a leg), a crew of 4 about 5 of the 6 (144 Parts a leg).

## G. Player interaction and child safety

### G1. What other players can do

- **Help:** carry the other end of a critter crate; load items for the whole crew; man a turret; vote; ping.
- **Nothing else.** No player can pick up an item another player carries, take a crate from its carrier, unseat another player, spend another player's Tickets, or change another player's save. Shared things (coal, Parts, lantern, upgrades) belong to the run and help everyone.
- **Announcements** in the server only: "Mia rescued a RARE Teapot Cat!" for Rare and above. Display names only.

### G2. Cut on purpose

- No combat and no weapons: the lamps light things up, and wisps puff into sparkles. No blood, no deaths, no player damage: a player is never hurt by anything.
- No stealing, no trading, no gifting (G1 of game 4: the genre's harms). Rewards are paid to each player's own save; nothing moves between players.
- No text input anywhere: pings, votes and roles carry the social play (M41). Roblox's filtered chat stays as Roblox provides it; the game adds no chat of its own and no announcement ever shows player text.
- No paid randomness and no paid anything (decision 0002, section N).

### G3. Anti-pressure rules (under 18; the game 4 G4 list adapted)

1. No Robux, no paid items, no paid revives, no paid coal, no skips, no luck boosts (decision 0002).
2. Odds are published in the Album (H4) even though Roblox requires it only for paid items.
3. No near-miss reveals, no slot-machine sounds, no "so close!" messages. A crate's rarity glow is shown before you pick it up; the species is shown when it reaches the train.
4. Nothing is exclusive forever: every critter can be rescued on any run that week and every week; the login exclusives repeat every week and every month; the Line of the Week returns every Monday.
5. Nothing earned expires: earned login slots and completed daily quests left unclaimed are paid automatically at the rollover (section J); Tickets, XP and the album never decrease.
6. The only timers on screen are the run's own: the fog bell at a stop, the Depot's departure, the hub's departure and the Lampeater's dive. No countdown on any offer, reward or login.
7. Losing a run costs only that run's train (coal, Parts, upgrades). The run end card leads with what was earned ("You rescued 6 critters and earned 412 Tickets") and never says "you lost".
8. Mild fear only: ominous-but-cosy music, fog, wisps with soft faces. No jump scares before the first Depot; after it, every big moment (the Lampeater) is announced 3 s ahead. A "Calm night" setting (client-only) softens the music and the vignette.

### G4. Anti-exploit

- Every action is a `Request` validated by the pure rules on the server's own state, or a server-side ProximityPrompt; the server checks reach from the character's server position (pick 8 studs, help 8, load box).
- The client never sends an amount, a price, an outcome, an item value, a position or a hit. Turret aim is a direction only (E2); pings carry an id and at most an item id.
- Carry speed is set by the server; every server tick, before that tick's loads, the carrier's move is checked as distance over time: they earn 1.25 × their carry speed in studs every second, banked up to 2 s of carrying + 4 studs, and every move spends it; a move the bank cannot pay drops the load at their last valid position. So a phone whose position froze for up to 2 s catches up without losing anything, and 21 studs/s with a crate (honest 9 alone, 13 helped) is dropped before the train (LANTERN-017, QA r3). The check starts where the item was picked up, a pick with full hands is checked up to the pick spot first (QA r2), and a carrier loads only after one checked step (LANTERN-016, QA M2).
- A carrier cannot press SIT: they walk the load to the train ("Bring it to the train first"; QA M1). A helper may sit and lets go; the first carrier keeps the crate.
- Rewards are counted only for active crew members (section I3), so an idle account seated in a crew earns nothing from loads; the turret's own keep-alive aim does not count as activity (QA M3).
- A crew member who leaves loses nothing; nobody gains by leaving or rejoining (loads are paid when they happen, to whoever is there).

### G5. Moderation surface

Display names only (crew list, Depot board, announcements, the weekly board). No player-made text, images or names. The only free choice that shows to others is a cosmetic from a fixed list.

## H. Meta game

### H1. Reused, generalised or new

| Piece | Source | Plan |
|---|---|---|
| Saves, remotes, rate limits, payload checks | `src/kit` (decision 0011) | **Reused**: `SaveStore` through `Saves.start`, `Router`, `Payload`, `RateLimit`, `Remotes.create`. SaveStore gains an optional newer-save guard (a kit addition, LANTERN-005) and `reclaim`: a session that could not claim its save keeps its changes and stores them once it can (LANTERN-016) |
| Levels, quests, cosmetics, day and week maths | `MetaRules` | **Reused** with a Lantern config (Tickets are the `coins` field) |
| Login tracks | `LoginRules` (Garden) | **Same pattern**, Lantern's own slots; reuses `LoginRules.monthOf` and `periodOf`, which are pure calendar maths |
| UI kit | `src/garden-client/UiKit.luau` (architecture garden 6.4) | **Generalised** into `src/kit-roblox/modules/UiKit.luau` with an injected theme, so Lantern and later games share one kit; Garden's own file is a shim over it since LANTERN-005 |
| Seeded rolls | `Rng` | **Reused** |
| Mesh loader | `src/relay/Models.luau` | **Reused** in place, plus `LanternAssets` (three lines, as Garden's) |
| Train, stops, carry, wisps, Depot, album, roles | | **New** pure modules (architecture section 3) |

### H2. Start menu and HUD

- **Start menu** (`UiKit.startMenu`): "LANTERN EXPRESS" logo, tagline "Bring them home before the fog.", a slow orbit around the train at Lamplight Depot, the showcase row of rescued critters (or silhouettes), PLAY, and a side column: ALBUM, LOCKER, REWARDS, BOARD, SETTINGS. Badges on anything claimable.
- **PLAY** joins the crew at once (section I4). In an empty server the player is seated in the cab and the train leaves 3 s later.
- **HUD:** top centre the lantern meter (a lantern icon that dims) and the phase chip ("Stop 2 of 3 · Mossy Farm", the bell chip at stops, "Night · wave 3", "Depot · leaving when all aboard"); top left coal (bar with tonight's need marked), Parts and oil; top right Tickets (coin pill) and the level ring; bottom centre the carry slots (three small or one big) and DROP; right side the seat buttons (SIT, STOKE, MEND when seated there); left the crew list (name, role badge, seat, ping icons); bottom left the ping wheel button. Every text at least 12 px on an 844 × 390 phone (UiKit).

### H3. Progression

- **XP:** each item you load 2 (small) or 5 (big); each critter rescued by the crew 20; a new album species 50; each wisp you puff 2; each stoke 1; each mend 3; each stop left aboard (not caught) 5; each Depot reached 40; Dawn Station 150.
- **Levels:** the shared curve `floor(sqrt(xp / 40)) + 1`, cap 50. Pacing (P): level 5 after the first run, 9 after three, 16 after ten.
- **Tickets** (the `coins` field): shares of loads, Depot and Dawn payouts, quests, login slots, milestones, leftover Parts. Spent only on cosmetics in the Locker.
- **Load shares:** each active crew member receives ceil(v × (1 + 0.1 × (n − 1)) / n) Tickets for a load worth v (C3, C7; small items v = 1, supply crate 8). The 10% a crew member is the co-op bonus; a crew's stops hold more loot (C6), so a player in a crew of 4 earns about 10% more a run than alone (P).

### H4. The Critter Album (Hollowmere, v0.1)

Rescuing a critter adds it to **every active crew member's** album (count +1; "NEW!" the first time). The album shows each species' card, rescue count, where it lives and its odds. Twelve species can be rolled, plus one login exclusive:

| Id | Name | Rarity | Lines | Tiles | Look (for the artist) |
|---|---|---|---|---|---|
| `mossmouse` | Moss Mouse | common | both | all 8 | round grey mouse with a moss cap and a dandelion seed |
| `puddlefrog` | Puddle Frog | common | both | farm, mill, lighthouse, boathouse | fat teal frog wearing a walnut-shell boat as a hat |
| `wickmole` | Wick Mole | common | both | village, inn, mill, orchard | velvet mole with a tiny lit candle stub on its head |
| `burrbun` | Burr Bunny | common | both | farm, windmill, orchard, village | cream bunny covered in soft burrs, one ear flopped |
| `lanternbeetle` | Lantern Beetle | uncommon | both | farm, windmill, orchard, village | round beetle whose glass abdomen glows amber |
| `fogpup` | Fog Pup | uncommon | both | village, inn, lighthouse, boathouse | fluffy pale puppy that fades into mist at the tail, knitted scarf |
| `acornowlet` | Acorn Owlet | uncommon | both | orchard, windmill, mill, inn | owl chick sitting in an acorn cup, huge eyes |
| `teapotcat` | Teapot Cat | rare | both | inn, village, farm | tabby curled inside a chipped teapot, lid on its head |
| `reedfox` | Reed Fox | rare | both | mill, lighthouse, boathouse, orchard | slim russet fox with cattails in its tail |
| `mistfawn` | Mist Fawn | epic | Forest only | all Forest tiles | white fawn with glowing antler buds and star freckles |
| `bellturtle` | Bell Turtle | epic | Lake only | all Lake tiles | turtle whose shell is a bronze bell with lily pads |
| `moonhare` | Moon Hare | legendary | both | all, far crates on leg 3 only | silver hare with a crescent-moon mark and long whiskers |
| `emberkit` | Ember Kit | exclusive (monthly login) | none | never rolled | fox kit holding a tiny lantern, ember-tipped tail |

**Rarity odds per critter crate (basis points; each row sums to 10,000):**

| Crate | Common | Uncommon | Rare | Epic | Legendary |
|---|---|---|---|---|---|
| Near site (under 70 studs), any line, any leg | 7,000 | 2,500 | 500 | 0 | 0 |
| Far site, Forest Line, legs 1 and 2 | 4,600 | 3,400 | 1,500 | 500 | 0 |
| Far site, Lake Line, leg 2 | 4,000 | 3,400 | 1,800 | 800 | 0 |
| Far site, Forest Line, leg 3 | 4,300 | 3,400 | 1,500 | 500 | 300 |
| Far site, Lake Line, leg 3 | 3,700 | 3,400 | 1,800 | 800 | 300 |

**Species within a rarity:** equal shares among the species of that rarity that live on this line and this tile; if none lives on the tile, equal shares among that rarity's species on the line. The ALBUM's "Where" tab shows, for the stop tile the train is at (or any tile picked from a list), the exact species odds per crate band computed by `LootRules.odds`, summing to 100%.

**Album milestones** (paid automatically at the load that reaches them): 4 species, 200 Tickets; 8 species, the Mossback livery; 12 species, the Moonlit lamp colour and 1,000 Tickets. Pacing (P): a solo player fills the 12 in a median of 11 runs (90%: 27); 10% of solo runs find a Moon Hare.

### H5. Rewards: daily quests and login tracks

**Daily quests** (`MetaRules.questsFor`, 3 a UTC day from this pool, the same for everyone, all doable alone). A completed quest left unclaimed at the day rollover is paid automatically ("saved for you"; section J).

| Id | Label | Stat | Goal | Tickets |
|---|---|---|---|---|
| `rescue3` | Rescue 3 critters | rescues | 3 | 100 |
| `rescue10` | Rescue 10 critters | rescues | 10 | 200 |
| `load20` | Load 20 items yourself | loads | 20 | 100 |
| `puff30` | Puff 30 wisps | puffs | 30 | 100 |
| `stoke15` | Stoke the boiler 15 times | stokes | 15 | 100 |
| `depot2` | Reach 2 Depots | depots | 2 | 150 |
| `dawn1` | Reach Dawn Station | dawns | 1 | 250 |
| `rare1` | Rescue a Rare or better | rareRescues | 1 | 150 |

**Login tracks** (the Garden v0.5 X3 rules: distinct UTC sign-in days, not streaks; claims in order with `claimLogin week|month`; earned slots left unclaimed are paid at the rollover; no countdown).

| Weekly sign-in | 1 | 2 | 3 | 4 | **5** | 6 | 7 |
|---|---|---|---|---|---|---|---|
| Reward | 40 Tickets | 60 | 80 | 100 | **Midnight Express livery** (login-only; 150 Tickets once owned) | 120 | 150 |

| Monthly sign-in | 3 | 7 | 12 | **18** | 22 | 26 | **30** (or the month's length) |
|---|---|---|---|---|---|---|---|
| Reward | 100 Tickets | 150 | 200 | **Ember Kit** rescued into the album (250 Tickets once owned) | 250 | 300 | **Aurora Beam lamp colour** (login-only; 400 Tickets once owned) and 400 Tickets |

A full week pays 550 Tickets and the livery; a full month 1,400 Tickets, the Ember Kit and the Aurora Beam (about two runs' worth).

### H6. Cosmetics (Locker)

| Slot | Id | Name | Unlock |
|---|---|---|---|
| livery | `classic` | Lamplight Red (default) | Level 1 |
| livery | `ember` | Ember Orange | Level 5 |
| livery | `fern` | Fern Green | Level 10 |
| livery | `brass` | Polished Brass | 2,500 Tickets |
| livery | `ivory` | Ivory and Gold | 6,000 Tickets |
| livery | `mossback` | Mossback | album milestone 8 (`grant = "album"`) |
| livery | `midnight` | Midnight Express | weekly login (`grant = "login"`) |
| lamp | `warm` | Warm Glow (default) | Level 1 |
| lamp | `mint` | Mint | Level 3 |
| lamp | `rose` | Rose | Level 8 |
| lamp | `sky` | Sky Blue | 1,200 Tickets |
| lamp | `gold` | Sunbeam Gold | 4,000 Tickets |
| lamp | `moonlit` | Moonlit | album milestone 12 (`grant = "album"`) |
| lamp | `aurora` | Aurora Beam | monthly login (`grant = "login"`) |

The **lamp** colour is your own beam (everyone sees it). The **livery** paints the train when you are the conductor: the crew member who has been aboard longest (shown with a cap icon in the crew list); the Locker preview shows your livery on the engine. A third slot, **badge**, is H7.

### H7. Roles and badges

Roles are badges you earn by doing things anyone can do; they never limit what you may do or where you may sit.

| Role | Counts | Bronze | Silver | Gold |
|---|---|---|---|---|
| Stoker | stokes | 30 | 300 | 1,500 |
| Lamplighter | wisps puffed | 100 | 1,000 | 5,000 |
| Scout | items you loaded | 50 | 500 | 2,500 |
| Mender | cans poured (MEND) | 15 | 150 | 750 |

You equip one role badge; it shows as a small icon above your head (capped at 28 px, never over another player's tag) and in the crew list, at its highest tier earned.

### H8. Line of the Week

One seed for every server from Monday 00:00 UTC (`MetaRules.weekOf`), chosen by the hub vote (F). Its stops, tiles and critter rolls are the same everywhere for the same branch choices and crew size. Two boards at the Depot and in the BOARD panel, global top 10 this week: **Most critters in one run** and **Farthest** (studs travelled before the run ended; a finished run is the full 3 legs). Each player's best this week counts; the boards show display names only. Free runs never count.

### H9. Followers

Pick any rescued species as your **follower** in the ALBUM. It hops behind you at Lamplight Depot (the hub and the Depot stops; code hop, no rig). Other players see it. Riding on the arm of your seat during runs (first in O's cut order) and names for followers (a fixed word list, no text input) are v0.2 (LANTERN-016, QA m6).

### H10. Saved profile

Schema v1 in decision 0018 (store `LanternProfile<suffix>`, one player's record; nothing ever writes two players' saves together).

## I. Social play

### I1. Crew and roles

The crew is every player in the server who has pressed PLAY (up to 6). Seats are free for anyone; the role badges (H7) show who usually does what. The conductor (H6) is a cosmetic honour, not a power: there is no host decision anywhere (votes are majority, departures are automatic).

### I2. Ping wheel (no text; M41)

Hold `Q`, the gamepad's left bumper, or tap the ping button; pick one of six:

| Id | Phrase | Placed at |
|---|---|---|
| `coal` | "Coal here!" | you, or the item you look at |
| `critter` | "Critter here!" | you, or the crate you look at |
| `help` | "Help carry!" | the crate you carry |
| `back` | "Back to the train!" | the train door |
| `wisps` | "Wisps there!" | 40 studs along your turret's beam (night) or you |
| `thanks` | "Thanks!" | above you |

A ping is a coloured marker with the phrase and your name for 8 s and an icon in the crew list; one ping per 2 s per player, at most 3 of yours on screen. The client sends only the ping id and at most an item id; the server places it.

### I3. Crew size and activity

`n` is the number of **active** crew members: those who in the last 180 s had a request accepted, walked 10 studs or more while standing (a move or stand-up made by the server does not count), or turned their turret aim by more than 1 degree (LANTERN-016, QA M3: the client re-sends a still aim every 0.3 s to keep the beam fresh, which is not activity). A puff is not activity either, and puff credit goes to active shooters only: an idle player's untouched lamp keeps shining where it was left, which helps the crew, but earns its player nothing (LANTERN-017, QA r1; switching it off would punish the crew for a friend who stepped away). 180 s is the same idle window for every input: longer than a night, so a player who stops to read the HUD keeps their share, and short enough that an AFK player is out of shares, the album and wave sizes by the next stop; their next real input counts at once. Nothing already earned is touched. Loot counts use `n` as the train approaches the stop; waves use `n` at each wave; load shares use `n` at the load. An inactive member stays seated and is carried along, but earns no load shares (G4). Depot, Dawn and Parts payouts go to every crew member aboard.

### I4. Friends joining (nobody waits more than one stop)

Pressing PLAY mid-run joins the crew at once:

| Phase | Where you appear |
|---|---|
| hub | seated in a free seat (the Stoker seat first) |
| ride, by day | seated in a passenger seat ("Next stop in 0:25") |
| night | seated at a free turret, else the Mender or Stoker seat, else a passenger seat |
| stop | on the platform at the train door, with an arrow to the nearest free item |
| Depot | on the Depot platform, with the Depot panel open |
| run end | at the hub; the next run starts when the crew sits down |

Friends reach the server with Roblox's own Join button or a private server (decision 0018). Private servers count as intentional co-play days (M30).

## J. Failure states: nothing earned is ever lost

**The rule:** a thing is *earned* when a game rule writes it to a player's save. Tickets, XP, album entries, quest progress, login slots, cosmetics, milestones and bests are earned; they never decrease by any game rule, and the only way to spend Tickets is a Locker purchase the player makes. Coal, Parts, oil, the lantern and upgrades belong to the run (the HUD says "for this run") and end with it; leftover Parts are converted into Tickets for everyone aboard when the run ends. A player who leaves mid-run leaves the Parts to the crew (their shares grow), and a solo run left early ends with no end card and no conversion: Parts were never earned (LANTERN-016, QA m5).

| Item or value | Carried | Dropped (DROP button) | Carrier caught by the fog | Carrier leaves the game | Left at the stop when the train leaves | Loaded on the train | Run ends (any reason) |
|---|---|---|---|---|---|---|---|
| Coal sack | not earned | on the ground, anyone may pick it up | dropped in the fog, gone for this run | dropped where they stood | gone for this run | +5 coal to the run; its Tickets and XP written to the saves at once | coal ends with the run |
| Parts bag | not earned | as above | as above | as above | gone for this run | +3 Parts to the run's pool; Tickets and XP saved at once | leftover Parts → ceil(Parts / n) Tickets to each crew member aboard at the end (not on leaving) |
| Oil can | not earned | as above | as above | as above | gone for this run | +1 oil (or +8 lantern if the store is full); Tickets and XP saved at once | oil ends with the run |
| Supply crate | not earned | as above | as above | as above | gone for this run | +10 Parts; Tickets and XP saved at once | as Parts |
| Critter crate | not rescued yet | as above | dropped in the fog; the critter **goes back to its stop** and its species can be rolled on any later stop | dropped where they stood | goes back to its stop | **rescued**: the album entry, count, Tickets and XP are written to every active crew member's save at once; it rides in the passenger car | stays rescued; the album keeps it |
| Tickets, XP, album, quest progress, roles, bests | | | | | | | kept; the run end card lists what this run added |
| Depot payout | | | | | | paid on arrival to each crew member aboard | already paid |
| Dawn and Lampeater payouts | | | | | | paid at Dawn Station | not paid if the run ends before Dawn (they were never earned) |
| Completed daily quest, unclaimed | | | | | | | paid automatically at the UTC day rollover (or at the next join), with the "(saved for you)" toast |
| Earned login slot, unclaimed | | | | | | | paid automatically at the week or month rollover (Garden QA M1 rule) |
| Equipped follower, cosmetics | | | | | | | kept |

- **Run ends** by reaching Dawn Station, running out of coal (the train coasts to a halt), the lantern reaching 0, or the last crew member leaving. Every ending returns the crew to Lamplight Depot, the last Depot, with the run end card.
- **A player leaving mid-run** has already been paid for every load; their carried items drop; the crew carries on.
- **A server shutting down** runs `BindToClose`, which writes every queued change; the only possible loss is the platform crash case, bounded by the kit's 7-second write coalescing (the same bound as every studio game; assumption S in section S).
- **Rejoining within 2 minutes of a crash** (the crashed server's save lock is still fresh) or a DataStore outage at the join: the player plays on, the HUD says "Saving paused", every change is kept and the server claims the save every 15 s; once it can, the stored save plus everything earned this session is written and the player is told. The end card never says "saved" while paused (LANTERN-016, QA M4).
- **Being caught by the fog** never touches the save: it drops what was not yet earned and costs 10 seconds.

## K. The first three minutes (beat by beat)

Solo player, empty public server, fresh profile. Times from pressing PLAY; numbers from section C and the pacing script.

| Time | What happens | Requirement |
|---|---|---|
| 0:00 | PLAY. The camera flies from the orbit to the cab (1.6 s); the player is seated at the Stoker seat. Whistle. | |
| 0:03 | Everyone (one player) is seated: the train leaves. Chuff, smoke, wheels. A big pulsing STOKE button: "Tap to stoke!" | |
| 0:06 | First stoke: the chimney puffs, the train surges (+25%). | **playing in 10 s** |
| 0:10 to 0:43 | Misty woods, fireflies, a fox crossing the line (decor). A chip appears: "Tonight the train needs coal: 44 / 60" with a moon icon. The quest chip shows today's three quests. | a goal is visible |
| 0:43 | **Stop 1**, Mossy Farm. Everyone stands up. "Scavenge! Fog bell in 1:10." A critter crate glows 22 studs from the platform, with an arrow. | first stop under 45 s |
| 0:46 | Picks up the crate (prompt). Walks back at 9 studs/s; the crate wobbles and a tiny face peeks out. | |
| 0:49 | Loads it. Reveal card: "NEW! Moss Mouse (Common)", one soft chime, +10 Tickets, +75 XP. **Level 2.** The Moss Mouse hops into the passenger car window. | **first reward in under 60 s** (49 s) |
| 0:50 to 1:53 | The choice: coal sacks (three at a time, the coal bar fills towards tonight's 60) or the second critter crate, glowing blue 96 studs out at the far end. | **a choice** |
| 1:53 | The fog bell. Whistle. The fog rolls in from the far edge; a far carrier sprints. | the clip moment |
| 2:06 at the latest | The fog reaches the platform; the train leaves (earlier if the player sat down). | |
| 2:49 at the latest | **Stop 2.** A second choice: a violet (Rare) crate 132 studs out against a coal pile by the platform; "Tonight: 52 / 60". | goal and choice before 180 s |

Joining a running crew instead: the player appears per I4. On a stop they are carrying something within 10 s; at night they are aiming within 5 s and earn a puff (XP) at once; by day they are seated with "Next stop in 0:xx" and the STOKE or turret seat free to try. The first load the crew makes pays them a share and the first rescue fills their album too, so the first reward still lands inside a minute in every phase except a full night stretch (up to 3 minutes, during which they are puffing wisps: XP and the `puff30` quest).

## L. Feel (what SHANNON judges; each line is an acceptance check)

- **Train:** chuff rate follows speed (v0.2: no chuff sound is registered yet, QA m13); steam puffs from the chimney; the whistle at every departure and at the bell; a gentle camera sway while seated; the train never jitters on screen at cruise speed with two clients (decision 0018 section 2: anchored server cars moved by CFrame).
- **Stops:** the tile builds before the train stops (no pop-in); items bob slightly and glow by rarity; pick-up has a squash-and-stretch and a soft thud; carried items swing on the back; loading pops the item into the car with a puff of dust and a "+N" float on the coal, Parts or Tickets.
- **Fog:** a visible wall of rolling mist with wisp silhouettes inside, a rising whoosh, the bell's low clang; the vignette tightens on a player near the front; being caught greys and muffles the screen for the 10 s with a heartbeat-free soft hum (no scare).
- **Night:** a cool blue night with warm lantern pools; beams are visible cones with dust motes; a lit wisp swells, sparkles and pops with a chime; a dim makes the lanterns gutter; the auto-pour glugs.
- **Lampeater:** announced 3 s ahead; a slow low swoop over the roof; the moth's eyes reflect the beams; fed, it purrs and spirals up to the moon.
- **Rewards:** the rescue reveal (C7 sounds), the Depot payout card counting up, the level-up ring pulse, the album "NEW!" stamp.
- **UI:** UiKit throughout; no text under 12 px on an 844 × 390 phone; every animation skipped under Reduced Motion.

## M. World and art plan

- **Hollowmere:** a misty valley at the edge of a lake. Lamplight Depot (red brick, brass lamps, a clock) sits between two loops of track: the Forest Line (east, pines and birches, mossy farms) and the Lake Line (west, reeds, a lighthouse, a boathouse). Each loop is 5,700 studs long: stops at 700, 1,400 and 2,100 studs, then the 3,600-stud night stretch back to the Depot; leg 3 leaves the loop 400 studs before the Depot onto the spur to Dawn Station (a white station on a hill facing the sunrise). Atmosphere fog keeps the view to about 250 studs, which is the look and the performance budget at once.
- **Look:** spooky-cute and warm: dark teal and blue nights, amber lamplight, soft round shapes, every critter with the studio's one shared cute face (glossy eyes with two catchlights, blush). All meshes are procedural Blender static meshes at the HD standard (`tools/blender/garden/README.md` "Creature standard (HD pass)"): full RGB 1024 textures with baked 192-sample AO, 6,000 tris a critter. Critters, wisps and the Lampeater move by code (bob, hop, drift, swoop); players use Roblox's default avatar animations.
- **Style test first:** the art director's three hero assets (the engine, one critter, one stop house) at the HD standard, reviewed before any feature art (studio lessons). The full asset list with names, sizes and pivots is architecture section 9.
- **Audio** (licensed Creator Store partners, a register row before use): an ominous-but-cosy day theme, a night theme with a heartbeat-free pulse, a Lampeater theme, a Dawn sting; whistle, chuff, bell, fog whoosh, pick-up, load thunk, five rescue chimes, puff, dim, stoke, pour, ping pop, Depot fanfare, level up. **v0.1 ships** the menu, day and night music and the whistle, bell, fog whoosh, load tick, rescue chimes (one sound, one to five chimes rising in pitch by rarity), puff and pour; the Lampeater theme, the Dawn sting, the chuff and the pick-up, dim, stoke, ping, Depot fanfare and level-up sounds are **v0.2** (they need register rows first; LANTERN-016, QA m13).

## N. Monetisation

Off for v0.1 (decision 0002): no Robux prompts, no game passes, no developer products, no paid private servers. **Private servers free** (price 0) if SHANNON approves (checkpoint): they are the friends' crew space and count as co-play (M30). Cosmetic liveries, lamp colours and whistles are the candidates for a later policy-reviewed proposal; paid revives, paid coal, skips, luck and anything random stay out for good (M43, M48).

## O. Scope for v0.1 and cut order

**In:** one biome (Hollowmere), two lines, 8 stop tiles, the train with 4 car types and 4 turrets, carrying with help-carry, fog, nights with waves, the Lampeater, the Depot with three upgrades, coal, oil and both votes, 12 critters plus the Ember Kit, the album with odds and milestones, roles and badges, pings, joining mid-run, levels, daily quests, weekly and monthly login tracks, the Locker (livery, lamp, badge), the Line of the Week with two boards, followers, the run end card, settings (music, SFX, Calm night, Reduced Motion is Roblox's own).

**Cut order if the build runs long** (first cut first): follower riding on the seat (keep the Depot follower); the Farthest board (keep Most critters); the Mender seat (auto-pour only); the Lake Line (Forest only, 6 tiles; legs 2 and 3 repeat the Forest Line with leg odds); the Line of the Week vote (every run free; the board waits for v0.2). The core (train, stops, fog, carry, night, Lampeater, Depot upgrades, album, levels, quests, login tracks) stays.

**Later (v0.2 and on, not designed here):** the follower riding on the seat and the M sounds v0.1 lacks (LANTERN-016); permanent train cars (Greenhouse grows coal, Kitchen, Observatory), the Snow Line biome, fortnightly event lines (Q9), follower names from a word list, Roblox badges, a harder line if the feel gate finds runs too easy (P), cosmetic monetisation after a policy review.

## P. Pacing results (`docs/game-design/game6-pacing.py`, 2026-11-06; nights reworked by LANTERN-015, crews of 4+ by LANTERN-016)

`python -I docs/game-design/game6-pacing.py 300` (seeded, stdlib only). The model: players take the best trip available (coal until tonight's need plus 6 is met, then critter crates, supply crates, small items), skip a trip the fog would catch unless they misjudge (12% casual, 30% new), carry critters in pairs when a partner is free, and buy coal, then Boiler, Lamps and Bunker at Depots. At night each lamp takes its share of a wave in spawn order: it notices a wisp 1 s after it spawns (new players 1.6 s), swings onto it at 120 degrees a second (new 70; a lone lamp turns all round, four lamps a quarter each), holds the beam for the puff time and lands it with chance `hit` (casual 0.5, new 0.35); a wisp one lamp misses gets one more try from the next lamp when it is free in time. Stoking, mending and the help-carry walk to a crate are not modelled.

**Assumption (LANTERN-015):** `hit` is not measured from people yet. Two Studio bots that notice in 1 s and swing at 120 degrees a second puffed 86% (old numbers) and 93% (new numbers, seeing only what is on screen) of a solo night's wisps; the LANTERN-012 runs aimed by keyboard puffed about 12% and lost the lantern by wave 5. The old model (every reachable wisp puffed) said every casual crew reached Dawn, which the integration runs contradicted.

- **First minutes (solo):** the train leaves 3 s after PLAY; stop 1 opens at 43 s; the first critter is rescued at 49 s; the fog bell at 1:53; stop 2 opens by 2:49.
- **Fog:** crosses 160 studs in 13.1 s; a stop lasts at most 83.1 s. Leaving at the bell, a lone critter carrier gets home from 118 studs or nearer; every other load from anywhere.
- **Rides:** 40 / 36 / 33 s by Boiler level; the night 180 / 157 / 138 s with 7 / 6 / 6 waves. A leg burns 95 coal; a crew that loads no coal runs dry 2,700 studs into the first night.
- **Lamps on leg 1 (Lamps I), crews 1 / 2 / 4 / 6:** casual puff 51% / 75% / 75% / 75%, new 37% / 56% / 58% / 58% (a lone lamp has nobody to cover its misses).

| Crew | Run (min, median) | Leg incl. Depot (min) | Night 1 won, casual / new | Meet the Lampeater, casual / new | Reach Dawn, casual / new | Tickets a player a run (casual) | XP a run (casual) | Critters rescued (casual) | Caught a run (casual) | Upgrades bought (casual) | Parts a leg |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 28.0 | 9.3 (8.7 to 10.0) | 100% / 100% | 94% / 24% | 88% / 2% | 697 | 989 | 17.0 | 1.1 | 1.7 | 42 |
| 2 | 27.4 | 9.3 (7.9 to 10.0) | 100% / 100% | 100% / 21% | 100% / 13% | 718 | 1,005 | 18.0 | 1.1 | 4.0 | 93 |
| 3 | 26.4 | 8.9 (7.5 to 9.9) | 100% / 95% | 92% / 0% | 92% / 0% | 745 | 1,149 | 26.3 | 0.1 | 3.9 | 105 |
| 4 | 25.6 | 8.7 (7.3 to 9.6) | 100% / 89% | 91% / 0% | 91% / 0% | 778 | 1,130 | 26.2 | 0.0 | 5.7 | 144 |
| 6 | 24.7 | 8.3 (7.1 to 9.3) | 100% / 93% | 99% / 0% | 99% / 0% | 867 | 1,254 | 35.9 | 0.0 | 6.0 | 192 |

- **The solo retune (LANTERN-015):** with the old numbers (drift 8, dim 6) the same model gives a casual solo the first night 99% of the time but Dawn only 7% (the later nights' 6 and 8 wisps a wave, one lamp, no cover); the new drift 6 and dim 4.5 give 100% and 91% (sweep of 150 runs). Crews of 3 or more keep drift 8 and dim 3.5.
- **The crew-of-4 retune (LANTERN-016, QA m12):** with dim 3 a crew of 4 was the hardest size (casual Dawn 88 / 100 / 92 / **65** / 87%), because four lamps face 8 wisps each on leg 3 and nobody mends. Dim 2.75 for 4+ gives 88 / 100 / 92 / 91 / 99%: no crew size is harder than the solo run, and from two players up the Dawn rate eases off smoothly to 91% at four. Crews of 5 and 6 are the easiest on purpose: the fifth and sixth players add one wisp each (four turrets) and the fifth mends, and making them harder would punish friends for joining (pillar 3). Sweep: dim 2.5 gives 98% for 4, 2.75 gives 91%, 3 gives 65%.
- **Album:** 12 species in a median of 11 runs solo (90%: 30), 8 in a pair (90%: 19), 7 in a crew of 4 (90%: 15); a Moon Hare in 9% of solo runs.
- **Levels (solo casual, 988 XP a run):** level 5 after 1 run, 9 after 3, 16 after 10, 28 after 30, 50 after 100.
- **Login tracks:** a full week 550 Tickets and the livery; a full month 1,400 Tickets, the Ember Kit and the Aurora Beam.
- **Reading:** legs and runs sit in the 8 to 10 and 25 to 30 minute bands (a crew of 6 clears stops faster: 24.7 minutes). A fair solo player (hit 0.5) wins the first night every time and meets the Lampeater in 94% of runs; fair crews reach Dawn in 88% to 100% of runs (a crew of 4: 91%), every loss at night. New players lose most runs at night from the second leg on, and crews of 3 or more never reach the Lampeater: losing costs nothing earned, but whether that is too harsh is the feel gate's question (checkpoint item, with a crew playtest to measure `hit`); the levers are `DIM`, `WAVES.speed`, `perTurret` and the Lampeater's dive rate.

## Q. Acceptance criteria (v0.1)

- [ ] Every spec in architecture section 8 passes in CI, including the check values of section P (`LanternBalance` cases in the `TrainRules` and `LootRules` specs).
- [ ] Odds rows sum to 10,000; `LootRules.odds` sums to 10,000 for every line, leg, tile and band; over 100,000 seeded rolls each rarity is within 0.5 points of its odds (unit tests).
- [ ] Carry, load, drop, catch and close follow sections D and J for every row of the J table (unit tests, one case per cell).
- [ ] The server never accepts a hit, a position, an amount or an outcome from a client: a client firing aims outside the cone or at 100 Hz puffs nothing extra (QA attack, notes with the build stamp).
- [ ] Studio, solo, timed from PLAY: the train leaves within 10 s, stop 1 opens within 45 s, the first rescue lands within 60 s, stop 2 opens within 180 s (playtest note with the build stamp, rule 13).
- [ ] Two clients: help-carry a critter crate; the second player joins mid-ride and sits in a seat, joins at a stop and appears on the platform; pings show on both screens; votes tally (multi-client test).
- [ ] Seated rule: jumping or pressing Sit-off while the train moves puts the player back in a seat within 0.5 s and the train never stops for it; no character is ever standing on a moving train (Studio, two clients).
- [ ] Caught by the fog: load dropped, 10 s grey, reappears seated; nothing in the save changes (Studio and unit tests).
- [ ] Nothing earned is lost: leave mid-leg and rejoin, the album and Tickets hold every load made before leaving; end a run by coal and by lantern, every payout of section J is in the save; a completed unclaimed quest is paid at the next day (unit tests with the fake DataStore, Studio with DataStores on).
- [ ] The train looks smooth at cruise speed on a second client (screen recording) and the server frame time stays under 8 ms with 6 players, 34 wisps and a built stop (MicroProfiler).
- [ ] A phone (or the Device Emulator at 844 × 390) keeps 30 fps at a stop and at night, and no text is under 12 px.
- [ ] The album's odds for each tile match `LanternConfig` and total 100% (manual check against H4).
- [ ] Every mesh, sound and icon has a `docs/assets/register.md` row; no Robux prompt exists; no text input exists.
- [ ] Start-menu screenshot and a night screenshot pass SHANNON's look review at the checkpoint.

## R. Kill criteria

- **Feel gate (staging):** SHANNON plays one leg solo and one with a second player and rates it under 4 out of 5, twice after fixes. Then stop and switch to concept C (Wobbly Movers), which reuses the carrying, crates, house tiles, ping wheel and critters.
- **Live (first 500 visits):** under 50% of new players reach the first night, or the median first session is under 10 minutes.
- **Live:** fewer than 25% of players who finish a run come back the next day.

## S. Facts, assumptions, hypotheses

- **Fact:** an all-ages game starts in a 16+ trial and needs 250 unique plays from highly engaged players within 60 days; the owner needs an age-checked, verified account, 2-Step Verification, and Plus or Premium for 2 months or a refundable 1,000 Robux fee per game (M38, M39).
- **Fact:** the Mild label allows "mild fear-based content" (jump scares, ominous music, suspense); Kids sees only Minimal or Mild (M40).
- **Fact:** private servers and joins count as intentional co-play days in Recommended for You (M30).
- **Fact:** walking on a moving train jitters on Roblox (studio experience in the concept doc), which is why the train moves only while everyone is seated.
- **Fact:** the kit's `SaveStore` coalesces writes to at most one per 7 s and writes everything queued on `BindToClose` (decision 0011).
- **Assumption:** anchored server cars moved by CFrame every Heartbeat (as built, LANTERN-006; decision 0018 section 2) replicate smoothly enough with seated characters welded in; the two-client cruise check is on the checkpoint's evidence list.
- **Assumption:** a 10 Hz server hit test with a 7° cone feels fair at typical latency (under 150 ms), because wisps drift at 6 to 8 studs/s (6 / 7 / 8 by crew size 1 / 2 / 3+) and the test runs in the train's frame.
- **Assumption:** Atmosphere fog at about 250 studs of view keeps the two loops and 8 tiles inside a phone's budget without StreamingEnabled.
- **Assumption:** the maturity questionnaire's answers in decision 0018 give the Mild label; to confirm in Creator Hub at the checkpoint.
- **Hypothesis:** the fog sprint and the lamp turrets are exciting enough without combat for players aged 16 and up (the concept's riskiest assumption; the feel gate tests it).
- **Hypothesis:** shared rescues (every crew member gets the critter) make strangers in a public server feel like a crew without any chat.
- **Hypothesis:** a fair crew reaching Dawn in most runs (P, LANTERN-016: 88% to 100% by crew size) is right for the audience, and the challenge for older players comes from greed at the bell and the weekly board.
- **Hypothesis:** the album, quests, login tracks and the weekly line bring players back on days 2 to 7 and 8 to 28 (M31).

## T. Open questions (for the checkpoint, not now)

Collected with recommendations in `docs/checkpoints/LANTERN-V01.md`: the place structure, the new experience and `lantern-staging`, Max Players 6, free private servers, the questionnaire answers, the account verification for all-ages reach, the economy values worth a look (load shares, Depot prices, login values, odds), whether runs are hard enough, and whether the feel gate and the look review are taken together on staging.
