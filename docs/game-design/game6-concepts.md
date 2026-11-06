# Game 6 concepts (GAMESIX-001)

Author: Market Researcher and Designer (A06). Date: 2026-11-06. Branch `game6/concept`.

SHANNON's brief: "take all you've learned and go make an entirely new game, make it good and likely to succeed in the roblox landscape". Evidence: `game6-market-research.md` (facts M1 to M52, assumptions A1 to A4, hypotheses H1 to H3).

**Must differ from:** Bake Rush (click simulator), Relay Rounds (team race), Hundred Demon Night (wave brawler), Egg Garden (hatch-and-collect garden), Neon Spire (tycoon).

**Constraints carried in:** Rojo and Luau; server-authoritative; rules in pure `src/shared/` modules tested by Lune; the shared kit for saves and remotes (decision 0011); `MetaRules` for XP, quests, streaks and cosmetics. Art is procedural Blender **static meshes** with no skeletal animation: creatures bob and hop in code, and players use Roblox's default avatar animations. Audio is licensed from the Creator Store. No human artists, a small QA budget, and one owner who merges and publishes. Under-18 audience with game 4's G4 anti-pressure rules. No stealing, no gambling-like paid randomness, filtered chat only, no text input. Free first; cosmetics only after a policy review (decision 0002).

## 1. What the evidence asks of game 6

| # | Requirement | From |
|---|---|---|
| Q1 | Playing in 10 s, first reward in 60 s, a goal and a choice before 180 s | bounce windows M30; casual players leave in under 2 min (M28) |
| Q2 | Sessions of about 20 min with a reason to return on days 2 to 7 and 8 to 28 | M27, M31 |
| Q3 | Better with friends, and fine alone; co-play counts in ranking | M14, M30 |
| Q4 | Appeals to players aged 16 and up, because they are the only audience during the trial | M38, M39, A1 |
| Q5 | Maturity label Minimal or Mild, so 5 to 8 year olds can play after evaluation | M40 |
| Q6 | Works without chat: roles, pings, emotes | M41 |
| Q7 | Its own fantasy and look; not a reskin of a live hit | M34, M51, A4 |
| Q8 | A built-in clip moment of 5 to 15 s | M18 |
| Q9 | A fortnightly content beat from launch | M12, M17 |
| Q10 | Art from static meshes; no character animation needed | studio constraint |

## 2. Scorecard

Same criteria and weights as `game3-concepts.md` and `game4-concepts.md`: 1 to 5 per criterion, total = sum of score × weight / 5. **Child safety** is a hard gate, as in game 4: a concept fails if it needs stealing, paid randomness, trading or free text to work. Four new checks from the research are shown under the totals but not weighted, so the totals stay comparable with games 3 and 4.

| Criterion (weight) | A. Lantern Express | B. Junkyard Derby | C. Wobbly Movers | D. Hide & Squeak | E. Splashball |
|---|---|---|---|---|---|
| Fun in the first 60 s, solo (15) | 4 | 4 | 3 | 2 | 3 |
| Core-loop appeal (17) | 5 | 4 | 4 | 4 | 4 |
| Differentiation (13) | 4 | 4 | 4 | 2 | 3 |
| Audience demand (13) | 5 | 4 | 4 | 4 | 4 |
| Feasibility, zero budget (13) | 3 | 3 | 3 | 5 | 3 |
| Retention (9) | 4 | 3 | 3 | 3 | 3 |
| Social play (8) | 5 | 4 | 5 | 5 | 5 |
| Content scalability (4) | 5 | 4 | 4 | 4 | 3 |
| Monetisation compatibility (4) | 4 | 5 | 4 | 4 | 4 |
| Technical simplicity (4) | 2 | 2 | 2 | 4 | 3 |
| **Total** | **84.2** | **74.8** | **72.6** | **71.2** | **70.0** |
| Child-safety gate | pass | pass | pass | pass | pass |
| Q4: 16+ trial appeal | high | medium | high | medium | medium |
| Q5: label | Mild (mild fear) | Minimal | Minimal | Minimal | Minimal |
| Q6: works without chat | yes (pings, roles) | yes | yes (pings) | yes | yes |
| Q7: clone risk | medium (Dead Rails) | low | low | high (Paint & Seek wave) | medium |

The scores are the designer's judgement (hypotheses), anchored to facts where one exists. Demand uses M4, M8, M9, M14, M24, and the racing and sports rows of section 7 in the research doc. Social play uses M14 and M30. Feasibility and technical simplicity use the studio's static-mesh pipeline and the games 1 to 5 history.

## 3. Concepts

### A. Lantern Express (co-op journey survival), recommended

- **One-line pitch:** Ride a tiny steam train through a spooky-cute valley with up to five friends. Scavenge each stop before the fog rolls in, keep the lanterns lit through the night, and bring every lost critter home to Dawn Station.
- **30-second loop:** The train stops at a village. You sprint off and grab coal, spare parts or a lost critter's crate (one big item or three small). The fog bell rings, and you race the rolling fog wall back to the platform. At night you sit at a lamp turret on the train and sweep its beam over drifting shadow wisps that try to dim the train's lanterns. Wisps caught in the light puff into sparkles. Nobody is hurt.
- **10-minute hook:** One leg is three stops and one night, about 8 to 10 minutes. It ends at a Depot where the crew spends the haul on upgrades (boiler speed, coal bunker, lamp brightness), picks the next branch (Forest Line or Lake Line), and sees its rescued critters riding in the passenger car. A full run is three legs, about 25 to 30 minutes, which fits the session band in Q2. Leg 3 ends with the Lampeater, a giant moth (a static mesh that swoops by code), circling the train while every lamp turns on it.
- **10-day hook:**
  - The **Critter Album**: about 40 original critters across biomes, rescued by carrying their crate home. Rarer ones sit at farther and riskier stops. All rolls are free and server-side, and odds are shown.
  - **Permanent train cars** that change runs: Greenhouse grows coal, Kitchen heals, Observatory shows the fog timer early.
  - New biomes unlock by reaching Dawn Station: Snow Line, Lake Line.
  - A weekly **Line of the Week**: one seed for every server, with a board for best distance and most critters saved.
  - Seasonal event lines every two weeks (Q9). Daily quests and streaks reuse `MetaRules`.
- **Social and co-op hook:**
  - Roles: Stoker, Scout, Lamplighter, Medic. They are crew badges unlocked by play and are visible on your avatar.
  - Critter crates need two carriers.
  - A six-phrase ping wheel ("Coal here!", "Help carry!", "Back to the train!"). No text.
  - Friends join a run at the next stop, so nobody waits more than one stop.
  - Private servers for friend crews; Roblox counts these as co-play (M30).
- **Shareable moment:** The **fog sprint.** The whistle screams, the fog swallows the village behind you, two friends haul a crate up the platform, and the last one dives through the door as the train pulls away. Also the Lampeater's swoop over the roof at the end of a run.
- **Why now (evidence):**
  - 99 Nights reached 14.2M concurrent with five people in three months. The pitch was "banding together… to survive" (M4).
  - Dead Rails proved the train-scavenge loop (M9).
  - Escape Tsunami proved risk-and-return (4.1M, M8).
  - Recommended for You now rewards co-play days and returns on days 8 to 28 (M30, M31).
  - Horror shows "extremely high growth" in Roblox's own genre data (research section 7).
  - Hypothesis H1: no kid-safe, non-violent journey game is in today's top 25.
  - Spooky-but-Mild appeals to the 16+ trial audience and still reaches 5 to 8 year olds after evaluation (M40, A3).
- **Studio fit:**
  - *Art:* everything is a static mesh: train, cars, houses, crates, lamps, critters, the moth. That is the procedural Blender pipeline's strongest output. Stops are built from a small tile kit (village, farm, windmill, lighthouse, mill) picked by a seed.
  - *Animation:* none needed. Players use Roblox's default animations. Wisps, critters and the moth bob, drift and swoop in code, the way Egg Garden's creatures move. Carrying is a weld or `AlignPosition` to the character.
  - *Physics:* walking on a moving train jitters on Roblox, so **the train moves only while every player is seated.** Lamp turrets are seats, and stops are stationary.
  - *Server authority:* the train runs along a fixed spline, so its distance, speed, coal, lantern meter and timers are one pure state machine (Lune-testable, like `RunRules`). Loot and critter rolls happen server-side. Carry is checked by distance, and rewards are paid at Depots.
  - *Reuse:* the kit, `MetaRules`, cosmetics, the Locker and the settings panel. Audio: ominous-but-cosy music and a train whistle from the Creator Store.
- **Child safety:**
  - No weapons and no combat; light "shoos" wisps away. No blood.
  - Being caught by the fog drops what you carry (it stays on the ground for anyone to fetch), and you reappear on the train after 10 s. Nothing saved is ever lost.
  - No player can take anything from another.
  - Running out of coal ends the run at the last Depot with every reward kept.
  - Mild fear only (ominous music, suspense), with no jump scares before the first Depot.
  - G4-style rules: no paid revives, no paid coal, no countdown offers.
- **Risks:**
  - (1) Being read as a Dead Rails reskin and hit by the "non-unique" demotion (M34). Mitigation: an original fantasy (lantern, fog, critter rescue, no guns), an original name and thumbnail.
  - (2) Train and multiplayer networking. Mitigation: the seated-while-moving rule and the spline-driven train.
  - (3) Procedural stops can look samey. v0.1 needs at least 8 stop tiles and 12 critters in one biome.
  - (4) Pacing solo versus with six players: scale wisps and carry limits by crew size.
  - (5) The fear level must stay Mild.
  - (6) A 25-minute run versus early bounce. Mitigation: the first stop opens within 45 s of PLAY.
- **Riskiest assumption:** the fog sprint and the lamp turrets are exciting enough without combat for players aged 16 and up, who decide the trial (Q4).
- **Kill criterion:**
  - Feel gate: SHANNON plays one leg solo and one with a second player and rates it under 4 out of 5.
  - Live: under 50% of new players reach the first night, or median first session under 10 minutes, over the first 500 visits.

### B. Junkyard Derby (build-a-kart racing)

- **One-line pitch:** Bolt scavenged junk onto a go-kart (a bathtub body, shopping-trolley wheels, a leaf-blower engine), then race it down wild downhill tracks against friends and the ghosts of the server's best runs.
- **30-second loop:** Steer, drift round a hairpin, hit a boost pad, smash a crate (parts fly out), take the jump and land the shortcut.
- **10-minute hook:** A cup is three 90-second races. Between races, in the garage, swap the body, wheels, engine and wing. Every part changes stats (grip, speed, boost, weight) and looks.
- **10-day hook:** A Parts Book of about 60 parts, all earned by play with no paid randomness. A daily track built from a modular kit by seed. A weekly cup with a ghost leaderboard. Your garage on show in the lobby.
- **Social hook:** Race friends in the same server. Asynchronous ghosts make solo play complete. Private-server cups. A spectator camera.
- **Shareable moment:** The absurd build, such as a bathtub on four trolley wheels, winning a photo finish after a huge jump.
- **Why now:** "Nearly 12.5 million" racing and driving searches, and "players want much more" (Roblox, Q1 2024; research section 7). No racing game is in today's top 25 (research 2.2). Karts are the ideal cosmetic sink.
- **Studio fit:** Karts and parts are static meshes, a perfect fit for the procedural pipeline. The avatar sits in a seat, so no animation is needed. Tracks come from modular pieces. The server validates checkpoint order and lap times against a speed cap. Ghosts are recorded positions replayed on the client.
- **Risks:**
  - The demand evidence is 2.5 years old, and no 2025 to 2026 racing breakout was found (H2).
  - Vehicle feel needs many Studio playtests, the studio's weakest loop.
  - Client-owned vehicle physics invites speed hacks; impossible laps are discarded server-side.
  - SHANNON rejected Relay Rounds as "running in a straight line". Tracks need drift, jumps and branches.
- **Riskiest assumption:** kart handling can feel good without a human tuner.
- **Kill criterion:** feel gate under 4 out of 5, or under 60% of new players start a second race.

### C. Wobbly Movers (co-op physics comedy)

- **One-line pitch:** Run a moving company for the world's oddest clients. Carry a grand piano down a spiral staircase, a full fish tank across a rooftop, and a sleeping walrus in a bathtub. Get everything into the truck before the timer ends, and do not break anything.
- **30-second loop:** Grab one end of a sofa while a friend grabs the other, wobble it round a corner, tilt it through a door. A vase slides off a shelf; dive and catch it.
- **10-minute hook:** A job is one house (4 to 6 minutes) with a star rating for how much was delivered and how little was damaged. Coins buy a bigger truck, tools (dolly, rope, trampoline) and new districts (castle, lighthouse, space station).
- **10-day hook:** A Client Book collection of odd cargo. A weekly "Impossible Job" seed. Van liveries and crew uniforms.
- **Social hook:** Two-person items, throwing small items to a friend through a window, crew ratings. Private servers.
- **Shareable moment:** The piano escaping down the stairs and out through the wall: physics chaos made for short clips.
- **Why now:** "Friendslop" co-op comedy is the indie trend, and Roblox is full of PEAK and R.E.P.O. clones (M24). The 18 to 34 cohort is growing about 40% a year (M26). It suits the 16+ trial (Q4).
- **Studio fit:** All cargo is static meshes. Houses come from a kit. No animation is needed: carry uses `AlignPosition`. Delivery and damage are scored on the server.
- **Risks:**
  - Two-player carrying on Roblox physics means network-ownership hand-offs and jitter, the hardest engineering of the five.
  - Weaker alone; a dolly helps.
  - Carrying is awkward on touch screens.
  - Damage depends on client-owned physics, so caps are needed. Co-op only, so a cheater gains little.
- **Riskiest assumption:** carrying feels funny, not frustrating, on mobile.
- **Kill criterion:** feel gate under 4 out of 5, or under 50% of new players finish a second job.

### D. Hide & Squeak (hide-and-seek party)

- **One-line pitch:** Hide as anything in a giant toy house: a teapot, a sock, a rubber duck. Or paint yourself to vanish into the wallpaper. Seekers have three minutes and a squeaky-hammer ping to find you.
- **30-second loop:** As a hider, pick a prop, find a spot, match the colour, hold still. As a seeker, scan the room, tap a suspect (a wrong tap costs time), and use the squeak ping that makes nearby hiders squeak.
- **10-minute hook:** Three-minute rounds with roles rotating. XP unlocks new props and seeker gadgets.
- **10-day hook:** A Prop Album, a new room every week, seasonal maps, hider trails and seeker hats.
- **Social hook:** Rounds with friends in private servers. A "best hide" vote by button, no text.
- **Shareable moment:** "I was the lamp the whole time": the replay of the last hider.
- **Why now:** Paint & Seek clones of Meccha Chameleon drew 150K to 200K combined in July 2026 (M24, grade L). Hide-and-seek is a perennial Roblox format.
- **Studio fit:** The best of the five. Props are static meshes, the studio's specialty. A hider *becomes* a mesh, so no animation at all. Small maps; round state and tags are decided on the server.
- **Risks:**
  - A crowded clone wave, which may be over by launch, and the "non-unique" demotion (M34).
  - Needs six or more players, so solo play is weak without bots.
  - Exploits that clip hiders into walls.
- **Riskiest assumption:** the format still has demand after the July 2026 clone wave.
- **Kill criterion:** under 50% of new players play a third round.

### E. Splashball (arcade team sport)

- **One-line pitch:** 3v3 water-balloon dodgeball on floating pool islands. Splash rivals, catch a balloon to bring a teammate back, and soak the other team's giant inflatable duck to win.
- **30-second loop:** Grab a balloon, aim, throw, dash-dodge, time a catch.
- **10-minute hook:** Three-minute matches; bots fill empty slots; XP and ranks.
- **10-day hook:** Seasons, new arenas, cosmetic balloons and splash trails, a weekly league.
- **Social hook:** Team up with friends, a party queue inside the server, private servers.
- **Shareable moment:** A trick-shot ricochet, or a last-player comeback.
- **Why now:** Sports had 13.5M searches and "unmet demand" (Roblox, 2024). Blue Lock: Rivals reached 713K (research section 2.1).
- **Studio fit:** Balloons and arenas are static meshes. Throws use a Roblox tool with its default animation; dashes are code.
- **Risks:**
  - Server-validated projectile hits feel laggy.
  - PvP needs full servers and matchmaking, the Relay Rounds lesson.
  - Competitive pressure on young players.
  - Thin content depth.
- **Riskiest assumption:** bots make solo matches fun.
- **Kill criterion:** under 50% of new players start a second match.

## 4. Recommendation

**A. Lantern Express.** It scores highest (84.2) and passes the child-safety gate. It is the only concept that meets all ten requirements in section 1.

- **It takes the other winning pillar.** The 2025 to 2026 records came from two places: collectors, which are saturated, fail our stealing rule and are already covered by Egg Garden; and co-op survival with friends, where 99 Nights reached 14.2M with five people (M4). Lantern Express takes the second, which game 3's wave combat did not.
- **It suits the 2026 ranking.** A co-op run of about 25 minutes with a Depot save point, a critter collection, permanent train cars and a weekly shared line aims straight at play days, co-play days and day-8-to-28 return (M30, M31). Ranking no longer rewards spikes or short-term monetisation (M32, M33).
- **It passes the age gate.** Fog, wisps and a giant moth are spooky enough for 16-year-olds in the trial (M38), and Mild enough for 5 to 8 year olds after evaluation (M40).
- **It is entirely new for the studio.** It is not a clicker, race, brawler, garden or tycoon. Its art is exactly what the studio can make: trains, houses, crates and floating creatures, all static meshes with no animation rig.
- **It has a clip moment in every stop.** The fog sprint (Q8).

**Fallback:** C (Wobbly Movers) if A fails its feel gate. C reuses A's carrying, crates, house tiles, ping wheel and critters, so little work is lost. **B (Junkyard Derby)** is the strongest bet if SHANNON prefers a solo-first, non-co-op game. It carries the biggest open question about whether the demand still exists (H2).

## 5. For SHANNON's checkpoint (one card, not now)

| # | Decision | Recommendation | If rejected |
|---|---|---|---|
| 1 | Which concept | A. Lantern Express | C, then B |
| 2 | All-ages publishing needs the owner account's ID verification, 2-Step Verification, and either a Plus or Premium subscription at least 2 months old or a refundable 1,000 Robux fee per game (M38, M39) | Use the refundable fee at launch; it is cheaper than starting a subscription now | The game stays 16+ only, cut off from the core audience |
| 3 | Monetisation | Stays off for v0.1 (decision 0002); propose cosmetic liveries, whistles and private servers after playtests | Nothing changes |
| 4 | A small Sponsored ads test at launch to reach 250 engaged plays (M38, M42) | Decide at the launch checkpoint with real retention numbers | Organic trial only; slower to reach Kids and Select |

Next step if A is chosen: `game6-gdd.md` in the game 4 GDD format, with a pacing check like `game5-pacing-sim.py` for run length, coal and Depot economy.
