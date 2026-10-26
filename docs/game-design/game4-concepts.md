# Game 4 concepts (GAME4-001)

Author: Game Designer (A06). Date: 2026-10-25.

Why a fourth game: SHANNON wants the studio's next game to be "similar to collect a brainrot or hatch an egg or grow a garden", the collection and idle simulator genre that set Roblox's concurrency records in 2025.

Constraints carried in: Rojo + Luau, server-authoritative, rules in pure `src/shared/` modules tested by Lune; fun solo; under-18 audience; no Robux or paid items (decision 0002), soft currency only; no gambling-like pressure on children, free hatch odds published in game anyway; trading cut or strictly safeguarded; parts and Roblox materials plus at most 10 AI-generated meshes; one build cycle of scope.

## 1. Research: why these games are sticky

### Facts (with sources)

Most sources are fan guides and news sites, not the developers. Where guides disagree, the disagreement is noted. Read numbers as rough, and game details as "at the time of the source".

| # | Fact | Source |
|---|---|---|
| G1 | **Grow a Garden** (released 26 March 2025, made by a 16-year-old): plant and harvest crops for Sheckles, buy more exotic seeds. **Crops keep growing while the player is offline.** Seed stock rotates; exclusive items are released weekly and players must be online to claim them. Pets come from loot boxes. Robux can speed up waiting, give perks and steal crops. Record 22.3M concurrent players on 23 August 2025. The developer says about 35% of players are under 13. Trading rare items for real money on eBay or Discord is common and breaks Roblox's terms. | [Wikipedia, Grow a Garden](https://en.wikipedia.org/wiki/Grow_a_Garden) |
| G2 | **Steal a Brainrot** (released 16 May 2025): a conveyor belt in the middle of the map sells "Brainrots"; owned ones **generate income over time** in your base. Players steal from each other, defend with a base button that makes a temporary shield, buy traps, and rebirth to reset for better stats. Peaks: 20M (August 2025), 25.4M (October 2025). Criticism: pay-to-win ("the best items are only available for cash", Polygon), many cheaters using automation scripts for collecting and stealing (GameRant), and **viral videos of children crying after losing their Brainrots**. One character was removed for months over a **licensing dispute**. | [Wikipedia, Steal a Brainrot](https://en.wikipedia.org/wiki/Steal_a_Brainrot) |
| G3 | Steal a Brainrot details: the conveyor is ranked common to rarest; you walk onto a placed Brainrot's platform to collect its cash; base lock 30 s on join then 60 s re-locks (+10 s per rebirth) per one guide, 50 s per another; a thief carrying a Brainrot is slowed and one hit returns it. | [Playnews guide, July 2026](https://www.playnews.gg/en/guides/steal-a-brainrot-roblox-the-complete-strategy-rebirth-and-tier-list-guide-for-july-2026), [Poki page](https://poki.com/en/g/steal-a-brainrot) |
| G4 | Grow a Garden mutations: random **server-wide weather** changes crops; mutations multiply crop value steeply (guides list Wet ×2, Gold ×20, Rainbow ×50 or ×500, values disagree) and stack with exclusion rules. A forecast board shows the next two weathers. Pets raise mutation chances. | [Deltia's weather guide](https://deltiasgaming.com/?p=203882), [Deltia's mutations guide](https://deltiasgaming.com/grow-a-garden-roblox-complete-mutations-guide), [Pocket Tactics](https://www.pockettactics.com/grow-a-garden-mutations), [Sportskeeda, why GaG is popular](https://www.sportskeeda.com/roblox-news/why-grow-garden-popular) |
| G5 | Egg hatching (Bubble Gum Simulator Infinity): odds per rarity tier, e.g. Infinity Egg Common 60%, Unique 20%, Rare 6%, Epic 2.5%, Legendary 0.5%, Secret about 1 in 40M; a specific pet is a fraction of its tier; luck potions raise odds. | [Sportskeeda, Infinity Egg](https://www.sportskeeda.com/roblox-news/infinity-egg-bubble-gum-simulator-infinity-how-hatch-hatch-rates) |
| G6 | Roblox policy: **paid** random items (explicitly including hatching an egg for a pet) must show every outcome with numerical odds as percentages totalling 100%, before purchase; a bare "(i)" icon is not enough; odds boosters must state their effect. Free rewards need no disclosure. `PolicyService` flags `ArePaidRandomItemsRestricted` and `IsPaidItemTradingAllowed` restrict some users. | [Creator Docs, paid random items](https://create.roblox.com/docs/production/monetization/paid-random-items) |
| G7 | Grow a Garden trading before an official trade window: gifting was the only way and is not simultaneous, so one side could keep both items; scammers posed as admins; an "old server" scam took rare items for nothing; off-platform trade groups carry scam and grooming risk. | [Ginx, how to trade](https://www.ginx.tv/en/grow-a-garden-trading), [Gamezebo, scams](https://www.gamezebo.com/walkthroughs/what-happens-if-you-get-scammed-in-grow-a-garden/), [Kinzoo parents' guide](https://www.kinzoo.com/blog/a-parents-guide-to-robloxs-grow-a-garden) |
| G8 | Steal a Brainrot runs scheduled "admin abuse" events twice a week (with the weekly update, and "Taco Tuesday"), 30–45 minutes, giving exclusive items. Days and times differ between guides. | [Designbeep](https://designbeep.com/2026/09/05/when-is-the-next-admin-abuse-in-steal-a-brainrot/), [Finding Dulcinea](https://findingdulcinea.com/steal-a-brainrot-admin-abuse-schedule/) |
| G9 | On 23 August 2025 the two games staged a joint mock "admin war" and Roblox set a platform record of 47.4M concurrent players. | [Wikipedia, Steal a Brainrot](https://en.wikipedia.org/wiki/Steal_a_Brainrot) |
| G10 | Be a Lucky Block (another 2026 collector): brainrots keep earning while players are offline. | [RoWatcher listing](https://rowatcher.com/games/9787206684/be-a-lucky-block) |

Carried from `game3-concepts.md`: Roblox ranks on play-through, first-play bounce, play days and playtime, then co-play days (F3); casual sessions are about 2 minutes (F12); Dubit tests the base action first (F11).

Unverified opinion, not used for numbers: creation.dev's glossary says offline income should be capped and must not make active play pointless ([creation.dev](https://www.creation.dev/glossary/idle-mechanics)).

### Assumptions (our reading of the facts)

- **A1. The genre runs on four clocks at once.** Seconds: walk, tap, collect. Minutes: an egg or crop finishes, a reveal. Hours: offline growth means there is always something waiting (G1, G10). Days and weeks: weather, restocks and events (G1, G4, G8).
- **A2. The reveal is the hook.** A rarity roll with a visible chase item (G4, G5) gives a reason to do "one more". For children this is also the risk: it is the slot-machine part. Our version must keep the reveal and remove the pressure (published odds, a pity meter, no near-miss animation, nothing paid).
- **A3. Income per second is the "number that goes up" and the brag.** Brainrot income (G2) and garden value (G1) are shown on the base for everyone to see.
- **A4. Stealing drives spikes but costs trust.** It creates tension and co-presence (G2), but also tears (G2), exploit pressure (G2) and needs other players to be fun. For under-18 players with no paid shields, it is a net negative for us.
- **A5. Trading is the scam surface.** Every safeguard we could build (G7) is a feature to build, moderate and support. For one build cycle it should be cut.
- **A6. Server-wide timed weather is the cheapest "event".** It needs no live team, gives everyone the same story ("Rainbow Shower now!"), and makes waiting into a plan (forecast, G4).
- **A7. Original creatures, not memes.** Licensed or meme characters can be pulled (G2); our creatures are our own.

## 2. Scorecard

Same criteria and weights as `game3-concepts.md` (total = sum of score × weight / 5). Plus one hard gate, **Child safety**: a concept that needs stealing or trading to work fails the gate unless the mechanic is cut.

| Criterion (weight) | A. Moonpetal Garden | B. Lantern Pets | C. Parade Snatchers | D. Egg Garden |
|---|---|---|---|---|
| Fun in the first 60 s, solo (15) | 3 | 5 | 3 | 4 |
| Core-loop appeal (17) | 4 | 4 | 5 | 5 |
| Differentiation (13) | 2 | 2 | 2 | 4 |
| Audience demand (13) | 5 | 4 | 5 | 5 |
| Feasibility, zero budget (13) | 4 | 4 | 3 | 4 |
| Retention (9) | 5 | 4 | 4 | 5 |
| Social play (8) | 3 | 3 | 5 | 3 |
| Content scalability (4) | 5 | 5 | 4 | 5 |
| Monetisation compatibility (4) | 4 | 5 | 3 | 4 |
| Technical simplicity (4) | 4 | 4 | 2 | 4 |
| **Total** | **75.4** | **77.8** | **74.4** | **87.0** |
| Child-safety gate | pass | pass | **fail** (stealing is the core) | pass |

Scores are the designer's judgement (hypotheses), anchored to the facts where one exists (demand: G1, G2, G5; retention: G1, G10; social: G2, G9).

## 3. Concepts

### A. Moonpetal Garden (grow and sell)

- **Pitch:** plant moonpetal seeds in your garden, grow glowing fruit in real time (offline too), harvest at the right moment, sell at the market stall, buy rarer seeds from a restocking shop. Weather mutates fruit into Golden or Rainbow versions worth many times more. The Grow a Garden pattern (G1, G4).
- **Loops:**
  - *Second:* walk your rows, harvest a ripe fruit, water a sprout.
  - *Minute:* sell a basket, buy seeds when the shop restocks (every 5 min), plant.
  - *Session:* save up for the next seed tier; wait for a weather event to harvest under it.
  - *Day:* offline growth; come back to a full garden; daily streak and quests.
- **Collection and rarity hook:** fruit weight and mutations; a fruit book with mutation variants.
- **Social hook:** visit gardens, server-wide weather everyone shares, "biggest fruit" leaderboard.
- **Differentiator:** almost none against Grow a Garden; a moonlit theme.
- **Riskiest assumption:** players do not see us as a clone, and selling fruit is satisfying without creatures to love.
- **Kill criterion:** median first session under 6 minutes over the first 500 visits.

### B. Lantern Pets (classic pet simulator)

- **Pitch:** smash glowing lanterns across festival zones with your pets for coins, buy eggs at shrines, hatch with a reveal, equip your best pets to smash faster, unlock the next zone. The Pet Simulator / Bubble Gum pattern (G5).
- **Loops:**
  - *Second:* tap a lantern, pets swarm it, coins burst.
  - *Minute:* hatch an egg (instant), equip, smash faster.
  - *Session:* unlock the next zone gate (coin cost), fill the pet index.
  - *Day:* daily streak, quests; nothing grows while you are away.
- **Collection and rarity hook:** eggs per zone with published odds, golden versions by combining duplicates.
- **Social hook:** pets follow you, hatch announcements, leaderboard by pets hatched.
- **Differentiator:** weak; the genre is crowded.
- **Riskiest assumption:** instant hatching without offline growth brings players back tomorrow (it is the weakest day loop of the four).
- **Kill criterion:** D1 retention under 15% over the first 500 visits.

### C. Parade Snatchers (Steal a Brainrot pattern)

- **Pitch:** a parade of yokai marches down the central road; buy one as it passes, park it in your base where it earns coins per second, rebirth for multipliers. When another player's gate shield is down, sneak in and snatch one of theirs.
- **Loops:**
  - *Second:* run, grab, dodge an owner's bonk.
  - *Minute:* buy from the parade, shield your gate, snatch.
  - *Session:* rarer yokai, more slots, rebirth.
  - *Day:* offline income; come back to see what was taken.
- **Collection and rarity hook:** parade rarity tiers, income per second.
- **Social hook:** stealing and defending (the strongest of the four, G2).
- **Differentiator:** yokai theme; the rest is the template.
- **Riskiest assumption:** children accept losing what they collected (G2 says many do not), and stealing is fun in a server of one.
- **Kill criterion:** fails the child-safety gate as written. If kept, any report of distress in playtests or under 50% D1 return among players who were stolen from.

### D. Egg Garden (hatch-and-grow collector) — recommended

- **Pitch:** plant creature eggs in your garden beds. They grow in real time, even while you are offline. Hatch them when they are ripe; if a weather event is on (Sunbeam, Moonfall, Rainbow Shower), the creature may hatch Golden, Moonlit or Rainbow. Your creatures live in your garden and fill their coin pads every second; walk over a pad to collect, buy better eggs from the restocking egg cart, and complete the Garden Index.
- **Loops:**
  - *Second:* walk your garden collecting coin pads, water a growing egg, tap a ripe one.
  - *Minute:* a hatch reveal every 30 s to 3 min early on; buy eggs when the cart restocks (every 5 min); swap a weaker creature out for a better one.
  - *Session:* reach the next egg tier (level gates), buy beds and pen slots, decide whether to hatch a ripe egg now or wait for the next weather on the forecast board.
  - *Day:* Moon and Star eggs take 1 to 4 hours, so there is always something ripe tomorrow; offline coins at half rate; daily streak, weekly bonus, quests; weekend weather boost.
- **Collection and rarity hook:** 9 original species × 4 mutations = 36 Index entries, plus Big and Huge sizes. Every Index entry adds +2% income forever. Odds, mutation odds and a pity meter are on screen.
- **Social hook:** walk into other players' gardens (same server), water their eggs (helps them, pays you XP), leave a like, see server-wide hatch announcements and everyone's income on their garden sign, global income leaderboard. No stealing, no trading.
- **Differentiator:** the only one of the four that combines the egg reveal (G5) with Grow a Garden's offline growth and weather timing (G1, G4) and Brainrot's income pads (G2, G3), without the steal. The weather decision ("hatch now or wait for the Rainbow Shower?") is a real choice the others lack.
- **Riskiest assumption:** walking to collect pads plus watering is enough active play for the first 60 seconds and the first session, before the long timers kick in.
- **Kill criterion:** week-1 feel gate: SHANNON plays the first 15 minutes on a fresh profile and rates it below 4 out of 5. Live: under 60% of new players hatch their third egg, or median first session under 8 minutes, over the first 500 visits.

## 4. Recommendation

**D. Egg Garden.** It scores highest (87.0) and passes the child-safety gate. It is literally all three things SHANNON named: hatch an egg (the reveal), grow a garden (real-time and offline growth, weather), collect a brainrot (creatures earning per second on your pads). It keeps the genre's four clocks (A1) without the two mechanics that hurt children (stealing, A4) or need moderation (trading, A5), and it is complete in a server of one.

B (Lantern Pets) is the fallback if D fails its feel gate: it reuses D's eggs, odds, pity, creatures and meshes, and only swaps the garden for zones to smash.

The full spec is `game4-gdd.md`.
