# Game 3 concepts (GAME3-001)

Author: Game Designer (A06). Date: 2026-10-25. Branch `game3/concept`.

Why a third game: SHANNON rejected Relay Rounds as "not good enough", even after v0.4 added a circuit, movement kit, style meter, menus, rewards, music and generated models. Owner feedback to answer: "there's no detail at all", "it's boring running in a straight line", "why is it in the air", "take inspiration from anime running games and stuff like Devil May Cry", "refer to established roblox games and make it as good as possible", "it needs all the hallmarks of a good game".

Constraints carried in: Rojo + Luau, server-authoritative, rules in pure `src/shared/` modules tested by Lune; fun solo, better with others, no long waits; parts and Roblox materials plus at most 8 AI-generated meshes, licensed music and SFX, no hand-made animations; under-18 audience; no Robux (decision 0002); one core mode done well.

## 1. Research: what is popular and sticky on Roblox now

### Facts (with sources)

Most figures below come from third-party trackers and search summaries, not Roblox's own charts. They disagree with each other by tens of thousands of players. Read them as rankings, not exact counts.

| # | Fact | Source |
|---|---|---|
| F1 | June 2026 live-player ranking: Brookhaven RP (~497K), Adopt Me! (~324K), +1 Speed Keyboard Escape (~307K), 99 Nights in the Forest (~285K), RIVALS (~222K), Blox Fruits (~218K), Murder Mystery 2 (~199K), Jujutsu Shenanigans (~178K), Steal a Brainrot (~151K), Fish It! (~143K), Sell Lemons, Kick a Lucky Block, Dress To Impress, Pet Simulator 99. | [RoWatcher, "Most popular Roblox games right now"](https://rowatcher.com/news/the-most-popular-roblox-games-right-now-ranked-by-live-players) |
| F2 | The concurrency records of 2025 were set by idle and collection games: Grow a Garden 22.3M (23 Aug 2025), Steal a Brainrot over 25M, Steal an Egg 14.25M. 99 Nights in the Forest (co-op survival horror) peaked at 14.2M and had 26B visits by April 2026. | [Wikipedia, List of Roblox games](https://en.wikipedia.org/wiki/List_of_Roblox_games) |
| F3 | Roblox's "Recommended for You" ranks games mainly on **play-through rate**, **first-play bounce rate** (negative), **play days per user** and **playtime per user** (capped at 60 min a day). Secondary signals: qualified play sessions, **intentional co-play days** (coming back to play with friends through joins, invites, private servers) and spend. | [Roblox Creator Docs, Discovery](https://create.roblox.com/docs/discovery) |
| F4 | Roblox says D1 retention and average session time matter most early, and suggests funnel analytics on onboarding when D1 lags. It publishes no D1 number. | [Roblox Creator Docs, Analytics](https://create.roblox.com/docs/production/analytics) |
| F5 | +1 Speed games: your speed stat climbs as you play, higher speed opens harder stages and outruns chasing bosses, wins buy trails that multiply speed, and rebirth resets speed for a permanent multiplier. | [allthings.how guide](https://allthings.how/1-speed-keyboard-escape-how-to-build-speed-farm-wins-and-rebirth/) |
| F6 | Escape Tsunami for Brainrots: run out across a field, grab collectibles (rarer ones farther out), get back to base before the wave hits; the collection earns money for speed, carry and base upgrades. Waves differ in speed; being hit sends you back to base. | [Beebom beginner's guide](https://beebom.com/escape-tsunami-for-brainrots-walkthrough-beginners-guide/amp/) |
| F7 | Jujutsu Shenanigans is the leading "battlegrounds" (anime combat) game, peaking around 338K after a March 2026 update. Its kit: M1 combos, four numbered skills, directional dash (Q), block (F), special (R), awakening (G). The Strongest Battlegrounds is built on ragdoll knockback and combo timing. | [RoWatcher on JJS](https://rowatcher.com/news/jujutsu-shenanigans-surges-past-338k-peak-players-after-disaster-plants-update), [Earnaldo comparison](https://earnaldo.com/blog/the-strongest-battlegrounds-vs-jujutsu-shenanigans) |
| F8 | 99 Nights in the Forest: gather by day, defend the campfire by night, rescue four children before night 99; classes with abilities; playable solo, easier in groups. Won Best Adventure and Best Horror at the 2025 Roblox Innovation Awards. | [Wikipedia list](https://en.wikipedia.org/wiki/List_of_Roblox_games), [ExitLag guide](https://www.exitlag.com/blog/99-nights-in-the-forest-roblox/) |
| F9 | Anime tower defence (Anime Vanguards, Anime Last Stand): summon anime units, place them against waves, co-op, monthly updates. Anime Vanguards passed 1.9B visits by July 2026. | [Playnews, best anime games 2026](https://www.playnews.gg/en/guides/roblox-the-10-best-anime-games-in-2026) |
| F10 | Steal a Brainrot and Grow a Garden drove record spikes with live "admin abuse" events that hand out exclusive items. | [Wikipedia, Steal a Brainrot](https://en.wikipedia.org/wiki/Steal_a_Brainrot) |
| F11 | Dubit (an agency that builds Roblox games) prototypes only the base action first and tests whether a player can "pick it up, understand what to do, and want to keep doing it"; Roblox players "click and are playing within seconds". Progression comes after the core loop works; social and sharing features after that. | [Dubit, "How we build hit Roblox games"](https://dubit.io/blog/how-we-build-hit-roblox-games) |
| F12 | GameAnalytics' 2025 Roblox report: most players sample and bounce; casual sessions were about 2 minutes against 37+ minutes for core users (mid-2025). | [GameAnalytics 2025 Roblox report](https://www.gameanalytics.com/cn/reports/2025-roblox-report) (search summary only) |

Unverified third-party claims, not used for decisions: RoLearn puts "good" D1 retention at 30 to 40% ([RoLearn](https://rolearn.dev/guidance/first-week-retention-optimization)); creation.dev says 20 to 30%. Neither publishes a method.

### Assumptions (our reading of the facts)

- **A1. The first minute decides everything.** Bounce rate is a ranking signal (F3) and casual sessions are about 2 minutes (F12). A visitor must be doing the fun thing within about 10 seconds and see a reward within about 30.
- **A2. Hits share a number that goes up and a visible show-off.** Speed (F5), collection value (F2, F6), unit power (F9). Players need a reason to come back tomorrow that they can see on screen.
- **A3. Short repeatable runs with a risk choice keep people in.** Tsunami runs (F6), nights (F8), waves (F9).
- **A4. Anime combat is a top genre, but the PvP versions need full servers and custom animation.** Battlegrounds games (F7) are PvP and animation-heavy. A PvE version that plays well alone is an open gap on our evidence; we did not find a leading PvE "stylish action" game in these sources.
- **A5. Co-op without voice works when roles are obvious.** 99 Nights (F8) and tower defence (F9) are co-op with no need to talk. Co-play days are a discovery signal (F3), so friends should have a reason to come back together.
- **A6. Relay Rounds failed on fun, not on features.** It had every hallmark but its core action (hold forward through a lane) was shallow, needed other players, and gave the player few choices. The next game's second-to-second action must be interesting with nobody else in the server.

## 2. Scorecard

Same 1–5 scale and method as `concepts.md` (total = sum of score × weight / 5). New criterion **Fun in the first 60 seconds, solo** (weight 15); the other weights are scaled by 0.85 and rounded so the total stays 100.

| Criterion (weight) | Relay Rounds (baseline, rescored with hindsight) | A. Demon Tide | B. Hundred Demon Night | C. Hundred Gates | D. Spirit Pond |
|---|---|---|---|---|---|
| Fun in the first 60 s, solo (15) | 2 | 4 | 5 | 3 | 3 |
| Core-loop appeal (17) | 2 | 4 | 5 | 4 | 3 |
| Differentiation (13) | 2 | 3 | 4 | 3 | 2 |
| Audience demand (13) | 2 | 5 | 4 | 4 | 4 |
| Feasibility, zero budget (13) | 4 | 5 | 3 | 3 | 5 |
| Retention (9) | 3 | 4 | 4 | 3 | 5 |
| Social play (8) | 4 | 3 | 4 | 4 | 2 |
| Content scalability (4) | 3 | 4 | 4 | 4 | 5 |
| Monetisation compatibility (4) | 3 | 4 | 4 | 3 | 5 |
| Technical simplicity (4) | 3 | 4 | 2 | 2 | 5 |
| **Total** | **52.6** | **81.0** | **82.2** | **67.6** | **72.0** |

Scores are the designer's judgement (hypotheses), anchored to the facts above where a fact exists (demand: F1, F2, F5–F9).

## 3. Concepts

### A. Demon Tide (escape-the-wave collector)

- **Pitch:** every 60 seconds a tide of shadow pours down the mountain into a shrine valley. Sprint out along branching paths, snatch spirit relics (rarer the farther you go), and get back to your shrine plot before the tide hits. Relics on your plot earn souls; souls buy speed, carry slots and dash upgrades.
- **Core loop:**
  - *Second to second:* run, double-jump, air-dash over rooftops, bridges and gaps; grab a relic; glance at the tide timer.
  - *Minute to minute:* one tide cycle. Choose how far to push: the far ridge has a gold relic but you may not make it back.
  - *Session to session:* upgrade speed and carry, unlock farther zones, rebirth for a permanent multiplier (the +1 Speed pattern, F5), fill the collection book.
- **Differentiator:** a hand-built, non-linear valley with rooftops and shortcuts, and Relay's movement kit, against the flat strips most tsunami games use (F6).
- **Why it beats Relay on fun:** no matchmaking; a risk-or-retreat choice every minute; a visible collection that grows.
- **Riskiest assumption:** the owner accepts a game whose action is still mostly running ("it's boring running in a straight line") and a clone of a trending format.
- **Kill criterion:** under 40% of new players start a third tide cycle, or SHANNON rejects the first playable on "it's just running".

### B. Hundred Demon Night (stylish co-op wave combat) — recommended

- **Pitch:** the Night Parade of a Hundred Demons (Hyakki Yagyō, Japanese folklore) is crashing a lantern-lit shrine festival. Alone or with up to 5 others, hold the courtyard through 10 waves of floating yokai with a katana, a launcher, a dash and a Demon Trigger, chase SSS style ranks, pick a blessing between waves, and slay the giant skeleton Gashadokuro on wave 10.
- **Core loop:**
  - *Second to second:* slash combos, launch a yokai and juggle it, dash through a telegraphed slam, pop Demon Trigger; the style rank climbs only if you mix moves (the DMC rule, kept from Relay's `StyleRules`).
  - *Minute to minute:* one wave (30 to 60 s) then a 12 s break: pick 1 of 3 blessings (roguelite build), heal, see your souls tick up.
  - *Session to session:* a 9 to 10 minute night; win to unlock the next moon tier; level up to unlock new weapons (sidegrades) and buy Blade Arts and masks; daily streak, weekly bonus, quests.
- **Differentiator:** PvE stylish action on Roblox, solo-first, with a style meter that pays (A4). Battlegrounds games are PvP and need full servers (F7); tower defence is passive (F9).
- **Why it beats Relay on fun:** the player makes a decision every second (which move, which target, dodge now) and every minute (which blessing). Enemies come to you, so there is no straight line and nothing in the air. It is complete with one player in the server.
- **Riskiest assumption:** combat feels punchy without custom animations, using Roblox's built-in tool slash animation, a code-driven blade swing, VFX, knockback and camera shake.
- **Kill criterion:** week-1 feel gate: SHANNON plays three runs of waves 1 to 3 and rates combat below 4 out of 5, or calls it "not good enough". Then switch to concept A, which reuses most of the same world and movement code. Live: under 60% of new players clear wave 2.

### C. Hundred Gates (co-op haunted shrine descent)

- **Pitch:** descend through a hundred shrine gates; each room is a short puzzle or a yokai with one rule (don't move while the noppera-bō looks, hide in a lantern when the bell rings). Reach gate 100. The Doors pattern.
- **Core loop:**
  - *Second to second:* explore, listen for audio cues, react to a monster rule.
  - *Minute to minute:* clear a room, find the key, open the next gate.
  - *Session to session:* reach deeper gates, unlock lore cards, cosmetics.
- **Differentiator:** gentle folklore horror themed for younger players instead of jump scares.
- **Why it beats Relay on fun:** tension and discovery, and the rooms change each run.
- **Riskiest assumption:** room variety the AI can build fast enough (a run needs about 30 distinct rooms to stay fresh), and horror pacing that suits under-13s without being dull.
- **Kill criterion:** under 50% of new players pass gate 10.

### D. Spirit Pond (yokai fishing and collection)

- **Pitch:** fish yokai koi and spirits from a shrine pond, reveal rarity, display your best catches in your own pond, sell the rest for souls, upgrade rods and bait. Weather and moon events bring rare spirits. The Fish It! and Grow a Garden pattern (F1, F2).
- **Core loop:**
  - *Second to second:* cast, wait, timing mini-game.
  - *Minute to minute:* a catch and a rarity reveal every 15 to 30 s.
  - *Session to session:* collection book, rod tiers, events.
- **Differentiator:** themed shrine and festival setting with a collection book.
- **Why it beats Relay on fun:** a constant drip of rewards and a collection that persists.
- **Riskiest assumption:** the owner, who asked for Devil May Cry, accepts an idle fishing game; the mini-game alone carries the action.
- **Kill criterion:** median first session under 5 minutes.

## 4. Recommendation

**B. Hundred Demon Night.** It scores highest (82.2) and is the only concept that answers every line of the owner's feedback: Devil May Cry and anime (style ranks, launcher, Demon Trigger), no straight line and nothing in the air (a ground-level courtyard where enemies come to you), detail (a festival shrine at night), and established Roblox patterns (wave co-op from 99 Nights and tower defence, anime combat from battlegrounds, daily rewards and quests from everything). It also scores best on the new first-60-seconds criterion: you are slashing yokai within 10 seconds of pressing PLAY.

A (Demon Tide) is 1.2 points behind and is cheaper and safer to build. It is the planned fallback if B fails its week-1 feel gate; both share the shrine world, the meshes and the movement kit, so little work is lost. SHANNON decides.

The full spec is `game3-gdd.md`.
