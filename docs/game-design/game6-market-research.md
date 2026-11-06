# Game 6 market research (GAMESIX-001)

Author: Market Researcher and Designer (A06). Date: 2026-11-06. Branch `game6/concept`.

Why: SHANNON asked the studio to "take all you've learned and go make an entirely new game, make it good and likely to succeed in the roblox landscape". This doc is the evidence; `game6-concepts.md` turns it into five concepts and a recommendation.

## How to read this doc

Every fact has a link and a source grade. Player counts on Roblox are never exact: Roblox publishes no live chart of its own, trackers sample the public API, and two pages of the same tracker often disagree. Read counts as orders of magnitude and rankings, not as exact numbers.

| Grade | Meaning | Examples |
|---|---|---|
| **P** | Primary: Roblox itself or the game's own developers | Creator Docs, Roblox newsroom, DevForum staff posts, SEC filings, earnings calls, DevForum creator spotlights |
| **R** | Reputable secondary | Wikipedia, Bloomberg (via The Star), GamesBeat, PC Gamer, Dexerto, TechCrunch, GameAnalytics, Newzoo (via GameDev Reports) |
| **T** | Third-party tracker, sampled from Roblox's public API | RoWatcher, Rotrends, Rolimon's. Peaks before a tracker started are undercounted; pages conflict |
| **L** | Low quality: SEO, code and guide sites, agency marketing | ejaw.net, rolearn.dev, creation.dev, allthings.how, ts2.tech, games.gg, StudioKrew, noping. Used for colour only, never for a decision |

Facts are numbered M1 to M60. Section 9 separates facts, assumptions and hypotheses (CLAUDE.md rule 10).

## 1. Top insights

1. **Discovery now pays for 28-day retention and play with friends, not for spikes.** Since June 2026, Recommended for You measures play days, playtime, co-play days and spend over day 1, days 2 to 7 and days 8 to 28 (M30, M31). Roblox says games that "emphasize short-term monetization" now get fewer impressions, and the bookings hit landed mostly in the US under-13 cohort (M33). New games still break through: about 40% of the weekly top 100 by Recommended impressions were created in the last three months (M35).
2. **A new game reaches under-16 players only after it wins over players aged 16 and up.** Since 19 May 2026, an all-ages game starts in a 16+ trial. It needs 250 unique plays from "highly engaged" players (account tenure, playtime, a purchase on Roblox in the last 60 days) within 60 days. The owner also needs ID verification, two-step verification, and either Plus or Premium or a refundable 1,000 Robux fee per game (M38, M39). Roblox itself says this slows games "without an existing audience" (M39). Game 6 must appeal to teenagers first, and must stay at a Minimal or Mild maturity label to reach 5 to 8 year olds (M40).
3. **The collector and idle pillar is saturated. The second biggest 2025 to 2026 pillar, co-op survival with friends, still has no kid-safe leader.** About 3,300 "Steal a ___" games exist, and one holds 92% of that cluster's players (M50, M51). Meanwhile 99 Nights in the Forest reached 14.2M concurrent players with five core people in three months (M4). Dead Rails, Escape Tsunami For Brainrots and the asymmetric horror games show the same "survive it together, with risk and return" appeal (M8, M9, M14). The studio already has a collector in Egg Garden.
4. **Longer sessions go with better retention and spend.** In GameAnalytics' 2025 data, games whose sessions average 19 to 24 minutes have a median D1 of 11.5% and median ARPPU of $1.71. Games under 3 minutes have 4.3% and $0.48 (M27). Casual players leave in under 2 minutes (M28). The first two minutes must hook; the design must then hold a player for about 20 minutes.
5. **Spikes come from shared events and clips, then decay fast.** Server-wide events and crossovers made the records: 47.4M on Roblox during the Grow a Garden and Steal a Brainrot "admin war" (M1). So did weekly update parties (M4) and celebrity collaborations (M10). Steal a Brainrot is now about 99% below its peak, and Steal An Egg about 95% below its peak (M3, M23). Retention systems, not the launch spike, decide success.

## 2. Who is on top

### 2.1 The 15 biggest experiences of 2025 and 2026 (by best-known peak)

Selection: games launched or broken out in 2024 to 2026, by all-time peak concurrent users (CCU). Evergreens such as Brookhaven, Adopt Me! and Blox Fruits are in 2.2.

| # | Experience | Genre | Launch | Peak CCU (date, grade) | Team (if known) | Core hook |
|---|---|---|---|---|---|---|
| 1 | Steal a Brainrot | idle collector with player stealing | 16 May 2025 | 25.4M, Oct 2025 ([Wikipedia](https://en.wikipedia.org/wiki/Steal_a_Brainrot), R); 25.8M ([RoWatcher](https://rowatcher.com/news/is-the-brainrot-trend-dying-what-ccu-data-from-three-top-games-reveals), T) | small; SpyderSammy acquired and remade an earlier game ([The Star / Bloomberg](https://www.thestar.com.my/tech/tech-news/2026/03/25/robloxs-hit-game-steal-a-brainrot-battles-its-many-imitators), R) | buy meme creatures off a conveyor, they earn per second in your base, steal other players' |
| 2 | Grow a Garden | idle farming collector | 26 Mar 2025 | 22.3M, 23 Aug 2025 ([Wikipedia](https://en.wikipedia.org/wiki/Grow_a_Garden), R) | started by a 16-year-old "in like three days" ([PC Gamer](https://www.pcgamer.com/games/survival-crafting/a-roblox-farming-game-made-by-a-teenager-in-like-three-days-had-8-9-million-players-online-at-the-same-time-steam-peaked-at-11-5-million-across-all-games-on-the-same-day), R) | crops grow offline, server-wide weather mutations, weekly restocks |
| 3 | Steal An Egg | steal-and-hatch collector | Jul 2026 | 14.3M, 19 Sep 2026 ([RoWatcher](https://rowatcher.com/games/10563114921/steal-an-egg), T) | not confirmed | steal eggs, hatch pets that earn, train Speed on a treadmill |
| 4 | 99 Nights in the Forest | co-op survival horror | Jun 2025 | 14.2M ([DevForum spotlight](https://devforum.roblox.com/t/creator-spotlight-the-story-behind-99-nights-in-the-forest/4036940), P) | 5 core people, built in about 3 months from a game jam (same source) | gather by day, defend the campfire by night, rescue four children, unlockable classes |
| 5 | Escape Tsunami For Brainrots | risk-and-return collector | 15 Dec 2025 | 4.1M, Feb 2026 ([RoWatcher](https://rowatcher.com/games/9363735110), T) | group "Wave of Brainrots" | run out for collectibles and get back to base before the wave |
| 6 | Plants vs Brainrots | tower-defence collector | Aug 2025 | 3.2M, Sep 2025, unverified ([ts2.tech citing Rolimon's](https://ts2.tech/en/robloxs-newest-phenomenon-plants-vs-brainrots-breaks-records-heres-why-everyones-obsessed/), L) | Yo Gurt Studio (same source) | plant defenders against meme waves, collect and upgrade |
| 7 | Fish It! | luck-based fishing collector | 21 Oct 2024 (T) | 2.72M, undated ([RoWatcher](https://rowatcher.com/news/fish-it-reels-in-270k-players-inside-roblox-s-most-addictive-casual-game-of-2026), T); another page says 1.4M | Fish Atelier | "1 in X" catch odds, AFK auto-fishing, 77-minute average sessions |
| 8 | Dead Rails | co-op train survival | 1 Jan 2025, beta ([Rotrends](https://rotrends.com/game/7018190066), T) | 1.5M, undated (Rotrends, T, unverified); "over 600K" one weekend ([GameAnalytics](https://www.gameanalytics.com/blog/dead-rails-and-the-hit-makers-formula), R) | RCM Games | drive a train across a zombie Wild West, scavenge towns for fuel, survive the nights |
| 9 | Break and Steal an Egg | steal-and-hatch follower | Sep 2026 (T) | 1.3M, 18 Oct 2026 ([RoWatcher](https://rowatcher.com/games/10765288803/break-and-steal-an-egg), T; another page says 30K) | Roblox says it was "created almost entirely with AI" ([Q3 2026 letter](https://www.sec.gov/Archives/edgar/data/0001315098/000162828026068235/ex991-q32026earningsshar.htm), P) | a variant of Steal An Egg |
| 10 | Blue Lock: Rivals | anime soccer | Jul 2024 (T) | 713K, Apr 2025 ([RoWatcher](https://rowatcher.com/games/6325068386), T) | fan group | 5v5 soccer with anime character abilities |
| 11 | Dress to Impress | fashion contest (avatar play) | 11 Nov 2023 | 651K, Aug 2024 ([Wikipedia](https://en.wikipedia.org/wiki/Dress_to_Impress_(video_game)), R); trackers claim about 1.7M, unverified | Gigi, who started at 14, and a small group (same source) | 6-minute themed outfit rounds, catwalk, players rate each other 1 to 5 stars |
| 12 | Fisch | skill-based fishing | Oct 2024 | 510K, 17 Oct 2026 event ([RoWatcher](https://rowatcher.com/games/5750914919/fisch-venue-encore/dying), T) | not known | fishing mini-game, bestiary, event islands |
| 13 | Jujutsu Shenanigans | anime battlegrounds PvP | about 2022 | about 412K, Mar 2026 ([RoWatcher](https://rowatcher.com/news/the-10-fastest-growing-roblox-games-in-march-2026), T) | Tze's Shenanigans | combo PvP; all 21 fighters free ([RoWatcher](https://rowatcher.com/news/jujutsu-shenanigans-surges-past-338k-peak-players-after-disaster-plants-update), T) |
| 14 | Violence District | asymmetric horror (one killer against survivors) | 31 Oct 2024 | 278K, 24 Oct 2026 ([RoWatcher](https://rowatcher.com/games/6739698191/week-2-x-butcher-violence-district), T) | developer Cerealboii (same source) | killer-versus-survivors rounds with weekly event "weeks" |
| 15 | Sell Lemons | idle tycoon | Mar 2025 (T) | 229K, Jul 2026 ([RoWatcher](https://rowatcher.com/games/7395930870/sell-lemons), T) | BloxByte Games | sell lemons, unlock powers, offline income |

Also noted: **Forsaken** (asymmetric horror, late December 2024, 138K peak, Best Survival at the 2025 Innovation Awards; [RoWatcher](https://rowatcher.com/news/forsaken-s-floral-update-drives-the-survival-horror-hit-past-86k-players), T) and **Throw Food For Animals** (September 2026; throw food with a power meter to lure animals, place them for passive income; 156K live on 6 November 2026; [RoWatcher](https://rowatcher.com/games/10766972131/throw-food-for-animals), T; [guide](https://progameguides.com/roblox/complete-throw-food-for-animals-beginners-guide-roblox/), L). Also **Murder Mystery 2**, at 473K during its Halloween event on 29 October 2026 ([StudioKrew citing RoWatcher](https://studiokrew.com/blog/?p=2072), L).

### 2.2 Who leads right now

RoWatcher's live chart, read on 6 November 2026 ([rowatcher.com/charts](https://rowatcher.com/charts), T, no timestamp on the page), in concurrent players:

> Steal An Egg 732K · Blox Fruits 221K · Brookhaven RP 197K · Murder Mystery 2 187K · Throw Food For Animals 156K · Break and Steal an Egg 135K · RIVALS 96K · Adopt Me! 95K · Steal a Brainrot 95K · 99 Nights in the Forest 84K · Anime Adventures 80K · Fish It! 63K · Jujutsu Shenanigans 54K · DONT SPLASH 53K · Fisch 51K · Dandy's World 49K · The Strongest Battlegrounds 46K · Violence District 42K · Catalog Avatar Creator 40K · Attack on Titan Revolution 40K · Evade 38K · Pet Simulator 99 37K · Sol's RNG 37K · Tap Simulator 35K

- **M1.** The platform record is 47.4M concurrent users, set during the joint Grow a Garden and Steal a Brainrot "admin war" on 23 August 2025 ([Wikipedia](https://en.wikipedia.org/wiki/Steal_a_Brainrot), R).
- **M2.** In June 2026 Brookhaven (about 497K), Adopt Me! (324K), +1 Speed Keyboard Escape (307K), 99 Nights (285K) and RIVALS (222K) led the live ranking ([RoWatcher](https://rowatcher.com/news/the-most-popular-roblox-games-right-now-ranked-by-live-players), T).
- **M3.** Steal An Egg went from about 2.2M in August to 14.3M on 19 September 2026, and is at 732K now ([RoWatcher](https://rowatcher.com/games/10563114921/steal-an-egg), T).

## 3. How fast small teams broke out

- **M4.** 99 Nights in the Forest: development started in March 2025, launched June 2025, reached 14M concurrent. Five core people (game design and art lead, programming lead, building lead, one more artist, one animator). It updates weekly and holds a 45-minute weekend "Update Party" with players. Their advice: "Don't scope super high and follow the fun!" ([DevForum spotlight](https://devforum.roblox.com/t/creator-spotlight-the-story-behind-99-nights-in-the-forest/4036940), P).
- **M5.** Steal a Brainrot: launched 16 May 2025; 5M concurrent by July, over 20M on 23 August, 25.4M in October ([Wikipedia](https://en.wikipedia.org/wiki/Steal_a_Brainrot), R). Estimated in-game purchases since launch: $64M ([The Star / Bloomberg](https://www.thestar.com.my/tech/tech-news/2026/03/25/robloxs-hit-game-steal-a-brainrot-battles-its-many-imitators), R, based on RoMonitor data).
- **M6.** Roblox at GDC 2026: "teams of fewer than 10 are capturing 25M+ concurrent users" ([Roblox newsroom](https://about.roblox.com/newsroom/2026/03/roblox-gdc-2026), P).
- **M7.** Grow a Garden was started by a teenager "in like three days" ([PC Gamer](https://www.pcgamer.com/games/survival-crafting/a-roblox-farming-game-made-by-a-teenager-in-like-three-days-had-8-9-million-players-online-at-the-same-time-steam-peaked-at-11-5-million-across-all-games-on-the-same-day), R), and reached 22.3M five months after launch ([Wikipedia](https://en.wikipedia.org/wiki/Grow_a_Garden), R).
- **M8.** Escape Tsunami For Brainrots went from launch on 15 December 2025 to 4.1M in February 2026 ([RoWatcher](https://rowatcher.com/games/9363735110), T).
- **M9.** Dead Rails grew after Roblox's own TikTok, Instagram and X accounts featured it in late February 2025, followed by large YouTubers such as Flamingo. The analysis calls the game "MAYA" (Most Advanced Yet Acceptable): familiar survival mechanics in a new setting ([GameAnalytics](https://www.gameanalytics.com/blog/dead-rails-and-the-hit-makers-formula), R).
- **M10.** Dress to Impress was made by a teenage developer. A "Pose 28" TikTok meme and streamers (Kai Cenat, CaseOh, Pokimane) spread it. The Charli XCX *Brat* collaboration took it to 651K concurrent in August 2024 ([Wikipedia](https://en.wikipedia.org/wiki/Dress_to_Impress_(video_game)), R).
- **M11.** AI-built games now reach the top: "Break and Steal an Egg" and "Huss Valley" were "created almost entirely with AI" and reached the top 20 by concurrent players ([Q3 2026 letter](https://www.sec.gov/Archives/edgar/data/0001315098/000162828026068235/ex991-q32026earningsshar.htm), P). Roblox's CEO also said discovery avoids "flooding users with games that might have an AI kind of name to them that aren't as long-term retentive" ([Q2 2026 call transcript](https://transcripts.platformaeronaut.com/transcripts/RBLX-2Q26-transcript), P, third-party transcript host).
- **M12.** Decay is steep. Newzoo: Grow a Garden had left the top 10 by December 2025, and Steal a Brainrot had lost about 30% of its monthly visits since August ([GameDev Reports / Newzoo](https://gamedevreports.substack.com/p/newzoo-top-roblox-games-in-2025), R). Steal a Brainrot at about 215K is 99% below its peak ([RoWatcher](https://rowatcher.com/news/is-the-brainrot-trend-dying-what-ccu-data-from-three-top-games-reveals), T).
- **M13.** Concentration runs both ways. The top 10 games hold about 20% of hours, down from about 30% three years ago ([Q2 2026 call](https://transcripts.platformaeronaut.com/transcripts/RBLX-2Q26-transcript), P). But the single largest title's share of top-10 visits rose from 22% to 43% during 2025 ([GameDev Reports / Newzoo](https://gamedevreports.substack.com/p/newzoo-top-roblox-games-in-2025), R).

## 4. What drove growth: mechanics and formats

| # | Pattern | Evidence | What it means for us |
|---|---|---|---|
| M14 | **Survive it together.** Co-op with no talking needed, a shared threat, and roles | 99 Nights: "banding together with peers or strangers to survive and protect each other" (M4, P). Dead Rails (M9). Forsaken and Violence District (table) | Co-play days are a ranking signal (M30). The strongest pillar that is not a collector |
| M15 | **Risk and return.** Go out for loot, get back before a timer | Escape Tsunami (M8), Dead Rails' town stops (M9), 99 Nights' day and night cycle (M4) | A decision every 30 seconds; natural clip moments |
| M16 | **A number that goes up, plus passive income** | Steal a Brainrot, Grow a Garden, Steal An Egg, Sell Lemons, Throw Food For Animals (table) | Proven but saturated (section 7); the studio already has Egg Garden |
| M17 | **Server-wide live events** | The admin war made the 47.4M platform record (M1). 99 Nights' weekly update party (M4). Event tags in titles on today's chart, such as "[WEEK 2 x BUTCHER]" and "[VENUE ENCORE]" (2.2). Fisch peaked at 510K in an October 2026 event (table) | A weekly or fortnightly content beat, announced in the title |
| M18 | **Shareable moments** | Dress to Impress's Pose 28 TikTok meme (M10). Roblox's own social accounts pushed Dead Rails (M9). Roblox Moments, open to users 13 and up, lets players clip 30 seconds and post it to an in-app feed; viewers can jump straight into the game. 240M videos were captured in experiences by September 2025 ([TechCrunch](https://techcrunch.com/2025/09/05/roblox-announces-short-form-video-feed-for-gameplay-clips-new-ai-tools-for-creators-and-more), R; [Roblox newsroom](https://about.roblox.com/newsroom/2025/09/roblox-moments-user-generated-discovery), P) | Design one 5-to-15-second "you had to see it" moment into the core loop |
| M19 | **Collection and rarity** | Fish It!'s "1 in X" odds over a million fish variants (table). Egg odds and pity in our own game 4 research | Works; paid odds and luck passes are what we exclude (section 6) |
| M20 | **Trading** | Adopt Me! and Murder Mystery 2 economies (2.2). Scams and off-platform trades ([game4-concepts.md G1, G7](game4-concepts.md)) | A moderation surface; cut again unless a decision record covers it |
| M21 | **Idle and AFK** | Fish It!'s AFK auto-fishing gives 77-minute average sessions ([RoWatcher](https://rowatcher.com/news/fish-it-reels-in-270k-players-inside-roblox-s-most-addictive-casual-game-of-2026), T). But Recommended for You counts playtime only up to 60 minutes per user, per game, per day ([Creator Docs](https://create.roblox.com/docs/discovery), P) | AFK time past 60 minutes earns no ranking; play days and day-8-to-28 return matter more (M31) |
| M22 | **Avatar and UGC-style play** | Dress to Impress (table). Catalog Avatar Creator in the live top 25 (2.2). Roblox reports 274M daily avatar updates in 2025 ([GamesBeat headline](https://gamesbeat.com/roblox-saw-274m-daily-avatar-updates-in-2025/), R) | Players like to show their avatar; cosmetics should be on the avatar or on things everyone sees |
| M23 | **Meme IP is borrowed and fragile** | Italian Brainrot was declared dead by its creators in December 2025; search interest peaked in May 2025 ([RoWatcher](https://rowatcher.com/news/is-the-brainrot-trend-dying-what-ccu-data-from-three-top-games-reveals), T). One Steal a Brainrot character was pulled over licensing ([game4-concepts.md G2](game4-concepts.md)) | Own original characters |
| M24 | **Clones of paid co-op hits ("friendslop")** | Roblox's CLIFF copies PEAK ([Kotaku](https://kotaku.com/peak-roblox-cliff-knock-off-aggro-crab-2000614671), R). Co-op games for friends were "the year's" indie trend ([PC Gamer](https://www.pcgamer.com/games/2025-was-the-year-friendslop-reigned-and-so-many-low-cost-ways-to-have-fun-with-your-pals-couldnt-have-come-at-a-better-time), R). Roblox "Paint & Seek" clones of the Steam hit Meccha Chameleon drew 150K to 200K combined in July 2026 ([games.gg](https://games.gg/es/news/los-clones-de-meccha-chameleon-en-roblox-superan-al-original-en-jugadores/), L) | Teen demand for co-op comedy exists; direct clones risk demotion (M34) |
| M25 | **Simple, readable first action** | Fish It! grew over Fisch with luck-based play that is easier to start than skill mini-games (M21 source, T). Dubit tests "pick it up, understand what to do, and want to keep doing it" ([game3-concepts.md F11](game3-concepts.md)) | One verb in the first 10 seconds |
| M26 | **Older players are a growth segment** | US 18-to-34 DAU and hours are growing about 40% a year ([Q2 2026 call](https://transcripts.platformaeronaut.com/transcripts/RBLX-2Q26-transcript), P). 27% of age-checked DAU were over 18 in January 2026 ([GamesBeat](https://gamesbeat.com/roblox-unveils-jumpstart-and-incubator-programs-to-help-creators-expand-possibilities-exclusive/), R) | Teen and adult appeal also opens the 16+ trial (M39) |

### 4.1 Session shape (GameAnalytics 2025, thousands of Roblox games)

- **M27.** Median D1, D7 and ARPPU rise with average session length ([GameAnalytics 2025 Roblox report](https://www.gameanalytics.com/reports/2025-roblox-report), R):

| Avg. session | D1 median | D1 top 10% | D7 median | D30 median | ARPPU median |
|---|---|---|---|---|---|
| 0–3 min | 4.31% | 9.25% | 0.41% | 0.13% | $0.48 |
| 7–12 min | 7.91% | 11.55% | 0.90% | 0.24% | $0.77 |
| 13–18 min | 10.24% | 14.96% | 1.20% | 0.34% | $1.21 |
| 19–24 min | 11.46% | 18.20% | 1.61% | 0.46% | $1.71 |
| 25+ min | 10.76% | 18.86% | 1.82% | 0.50% | $2.12 |

- **M28.** Casual users leave in under 2 minutes; core users average 37 minutes per session. The platform median session is 6.6 minutes and the median daily playtime 16.8 minutes (same source).
- **M29.** Correlation, not cause: longer-session games may simply be deeper games. The doc uses this as a target band (about 20 minutes), not as a law.

## 5. Discovery on Roblox now

### 5.1 How Recommended for You ranks

- **M30.** Two stages: retrieval, then personal ranking. Signals in priority order: play-through rate; first-play bounce at under 60 s and at 61 to 180 s (negative); play days per user; playtime per user (capped at 60 min per day). Then intentional co-play days (joins, invites, **private servers**), qualified play sessions, spend days and Robux spent. All are per-user averages, so small games are not penalised. **Only users who arrive organically from Recommended for You count**; players from ads, search or friends are excluded from the ranking stage ([Creator Docs, Discovery](https://create.roblox.com/docs/discovery), P).
- **M31.** On 15 June 2026 the windows moved "from 7 days to 28 days": day 1, days 2 to 7 and days 8 to 28. Play-through and bounce are measured separately, and creators can see each signal's weight in Creator Analytics ([DevForum](https://devforum.roblox.com/t/recommended-for-you-algorithm-improvements-that-better-value-long-term-retention/4684575), P; [Roblox newsroom](https://about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox), P).
- **M32.** On 20 August 2026 Home recommendations started favouring "games players return to over time" and "games where players find value in the purchases they make". In Roblox's words, "Monetization alone can't create a sustainable game." Their advice is to build "natural moments to purchase" into progression ([DevForum, Chief Growth Officer](https://devforum.roblox.com/t/boost-your-discovery-by-building-games-people-want-to-play/4779042), P).
- **M33.** Roblox's CEO said the change brings "a lower frequency of impressions with games that emphasize short-term monetization rather than long-term retention", and "We have seen this impact monetization, primarily in the US under 13 cohort". The CFO called it the "primary factor" in a bookings miss ([Q2 2026 call](https://transcripts.platformaeronaut.com/transcripts/RBLX-2Q26-transcript), P).
- **M34.** Roblox reduces exposure for games that lead with giveaways in their metadata, whose metadata does not match the content, or that are "non-unique games that closely resemble existing ones". A custom thumbnail is required for Home impressions, and thumbnails must reflect the game. New games go through "explore and expand": tested on small cohorts, then shown to similar cohorts if they engage ([Creator Docs](https://create.roblox.com/docs/discovery), P). Roblox will test thumbnail personalisation by play-through rate ([DevForum](https://devforum.roblox.com/t/recommended-for-you-algorithm-improvements-that-better-value-long-term-retention/4684575), P).
- **M35.** About 40% of the weekly Recommended for You top 100 by impressions were games created in the last three months. Roblox also added age-cohort data to the weighting in Q3 2026 ([Q3 2026 letter](https://www.sec.gov/Archives/edgar/data/0001315098/000162828026068235/ex991-q32026earningsshar.htm), P).
- **M36.** Other surfaces: Standout Games (hand-picked for unique mechanics, distinctive visuals or under-represented genres), Live Events, Sponsored, and semantic search ([Creator Docs](https://create.roblox.com/docs/discovery), P). The Top Trending chart is the "fastest-growing" sort and is the same for every user ([DevForum](https://devforum.roblox.com/t/testing-an-enhanced-discover-page-top-charts-and-new-sorts/2954676), P).
- **M37.** Competition is enormous. In one week of September 2026, 286,963 new games appeared and RoWatcher counted 545 "algorithm breakouts" ([RoWatcher W37](https://rowatcher.com/news/roblox-week-in-numbers-2026-w37), T). Of about 8.5M games, about 19,000 had a player, 1,370 had 1,000+ CCU, 112 had 10,000+ and 12 had 100,000+ (June 2026, [RoWatcher](https://rowatcher.com/news/how-many-games-are-on-roblox-in-2026), T).

### 5.2 The age gate (new in 2026)

- **M38.** Roblox Kids covers ages 5 to 8 and Roblox Select ages 9 to 15. To publish for all ages: an age-checked, verified creator (facial age estimation under 18, government ID 18+), 2-Step Verification, and either a Plus or Premium subscription at least 2 months old or a refundable per-game fee. Then an evaluation: a trial for age-checked users 16 and older; **"250 unique plays from highly engaged players in the last 60 days"** (account tenure, playtime in the game, and a purchase anywhere on Roblox in the last 60 days); and a safety review. Games that do not pass stay 16+ only. Optional expedited review costs a refundable 50,000 Robux ([Creator Docs, Kids and Select](https://create.roblox.com/docs/production/publishing/kids-and-select), P).
- **M39.** In effect from 19 May 2026. The fee is 1,000 Robux, refundable. Roblox: "These changes can lengthen the time it takes for new games without an existing audience to grow their playerbase"; it suggests promoting to users over 16 ([DevForum](https://devforum.roblox.com/t/new-publishing-requirements-evaluation-process-for-games/4573166), P).
- **M40.** Maturity labels: Kids sees only **Minimal** or **Mild**. Mild allows "mild fear-based content" ("jump scares, ominous music, and/or gameplay that builds suspense"), repeated mild violence and mild crude humour. **Moderate** (moderate fear, light realistic blood) reaches Select and 16+ only. Playable gambling, "including simulated gambling", is banned at every label. **Social hangouts without private spaces and free-form user creation are limited to 16+.** Unrated games are restricted for everyone ([Creator Docs, Content Maturity](https://create.roblox.com/docs/production/promotion/content-maturity), P).
- **M41.** Chat now needs an age check and is banded by age cohort. 64% of DAU had completed an age check by the end of Q3 2026 ([Q3 2026 letter](https://www.sec.gov/Archives/edgar/data/0001315098/000162828026068235/ex991-q32026earningsshar.htm), P). Kids accounts have chat off by default ([Creator Docs, Kids and Select](https://create.roblox.com/docs/production/publishing/kids-and-select), P). **Social play has to work without words.**

### 5.3 Paid acquisition

- **M42.** Sponsored ads: cost per play fell "over 71%"; "you can now get a player into your experience for less than $0.01"; 1 Ad Credit = 263 Robux. Roblox claims "the 5 newest experiences to reach the top 20 by earnings all started with Sponsored Experience ads" ([DevForum, September 2025](https://devforum.roblox.com/t/ads-for-creators-rdc-recap-and-what%E2%80%99s-next/3929106), P, Roblox's own claim). Ad traffic does not count toward Recommended ranking (M30), but it can fund the 16+ trial plays (M38). Spending needs SHANNON's approval (CLAUDE.md rule 7).

### 5.4 What a new game must look like in its first 10 minutes (derived from M27 to M41)

1. **0 to 10 s:** playing, not reading. One obvious verb (M25), on mobile too.
2. **10 to 60 s:** a first reward and a first "oh!" moment, or the play is counted as a first-play bounce (M30).
3. **1 to 3 min:** a goal and a choice; the second bounce window ends at 180 s (M30). Show other players or friends doing the fun thing.
4. **3 to 10 min:** the first clip-worthy moment (M18), the first permanent unlock, and a visible reason to return tomorrow, because day 2 to 7 and day 8 to 28 return now rank (M31).
5. **Store page:** a custom thumbnail that shows real gameplay (M34), an original name and look so the game is not read as a clone (M34), no giveaways in the text (M34), and a Minimal or Mild label so Kids can play once evaluation passes (M40).
6. **Must appeal to players aged 16 and up as well,** because they are the only audience during the trial (M38).

## 6. Monetisation without dark patterns (under-13 audience)

### 6.1 Rules

- **M43.** Paid random items: anything random bought with Robux, directly or through a currency bought with Robux, including egg hatching, chests, enhancement chances and luck boosts. Every outcome and its numerical odds must be shown before purchase, as percentages summing to 100%. A bare icon is not enough. `PolicyService` flags `ArePaidRandomItemsRestricted` (some users cannot use paid random generators at all) and `IsPaidItemTradingAllowed` (some users cannot trade paid items) ([Creator Docs](https://create.roblox.com/docs/production/monetization/paid-random-items), P).
- **M44.** Playable or simulated gambling is banned at every maturity label (M40).
- **M45.** Rewarded video ads are shown only to users 13 and older, and only in games with 100K+ DAU averaged over 28 days ([DevForum](https://devforum.roblox.com/t/more-creators-can-now-use-rewarded-video-ads/3838678), P). Ads for under-13s are reported to be contextual direct deals only ([Pulse / AdExchanger summary](https://www.pulse.bot/marketing/news/roblox-opens-up-advertising-to-kids-under-13-bb791f75-3f70-497b-85e7-c5a22df56a87/), L).
- **M46.** Steal An Egg gated Speed behind watching a short-video feed on a treadmill, with Robux to skip ([Dexerto](https://www.dexerto.com/roblox/viral-roblox-game-recreates-black-mirrors-iconic-treadmill-scroll-3401534/), R). It was taken down for about 3 hours on 24 to 25 August 2026 and came back without the feed. No official reason was posted ([allthings.how](https://allthings.how/steal-an-egg-roblox-ban-why-it-happened-and-how-it-returned/), L). TechSpot reported it as Roblox ["cracking down on games that reward kids for doomscrolling"](https://www.techspot.com/news/113630-roblox-cracking-down-games-reward-kids-doomscrolling.html) (R, headline only; the page refused our fetch).
- **M47.** Legal climate: several US states sued Roblox over child safety in 2026, and Roblox settled with three states for $35.8M ([Claims Journal](https://www.claimsjournal.com/news/national/2026/04/22/337051.htm), R). Expect more scrutiny of anything aimed at children.

### 6.2 What the market does, and what we take from it

- **M48.** Fish It! sells an "Advanced Luck" pass (545 Robux, +150% luck), Robux-only mystery crates and a paid event-pass skip ([RoWatcher](https://rowatcher.com/news/fish-it-reels-in-270k-players-inside-roblox-s-most-addictive-casual-game-of-2026), T). These are paid probability modifiers and paid random items under M43. **We exclude all of them.**
- **M49.** Platform trends: monthly unique payers fell 16% to 30M while bookings per payer rose 5% (Q3 2026). Roblox Plus has "millions of subscribers" who "spend more and play longer" ([Q3 2026 letter](https://www.sec.gov/Archives/edgar/data/0001315098/000162828026068235/ex991-q32026earningsshar.htm), P). Payers are fewer and spend more each.

**Fits a child-safe game (assumption, built on M30, M32, M43 and M44):**

| Item | Why it is safe | Notes |
|---|---|---|
| Cosmetic passes and items (avatar, vehicle, base looks) | No power, no randomness | Shown to everyone in the server (M22) |
| Private servers (Roblox built-in) | Friends play together; counted as co-play (M30) | Free or cheap |
| A free event track with cosmetic rewards | Gives a reason to return without pressure | No paid skip, no "last chance" countdowns (game 4 G4 rules) |
| Cosmetic subscription (later) | Matches Roblox's push (M49) | Needs its own policy review (decision 0002) |
| **Never:** paid odds, luck passes, paid revives mid-run, energy timers, ad-watching for power, paid trading | M43, M45, M46, M48 | Also the studio's hard rules |

Studio status: decision 0002 still holds. Game 6 ships free first; cosmetics come after the core loop passes playtests and a policy review.

## 7. Saturation map

| Format | Evidence | Status | For this studio |
|---|---|---|---|
| "Steal a ___" and brainrot collectors | About 3,300 "Steal a" games ([RoWatcher](https://rowatcher.com/news/how-many-games-are-on-roblox-in-2026), T) (M50); in one snapshot 105 live clones, with the leader holding 92% of their players ([RoWatcher](https://rowatcher.com/news/105-games-cloned-steal-a-one-holds-92-of-the-players), T) (M51); at least four lawsuits by Steal a Brainrot's owners ([The Star / Bloomberg](https://www.thestar.com.my/tech/tech-news/2026/03/25/robloxs-hit-game-steal-a-brainrot-battles-its-many-imitators), R); meme fatigue (M23) | **Saturated** | Fails the no-stealing rule anyway |
| Grow, hatch and idle collectors | Grow a Garden 2 fell 58.9% in one week ([RoWatcher W37](https://rowatcher.com/news/roblox-week-in-numbers-2026-w37), T) (M52); "top two games in most simulator subgenres control over 80% of all revenue" ([RoWatcher opportunity map](https://rowatcher.com/news/roblox-genre-opportunity-map-2026-where-smart-developers-are-building-next), T, method not stated) | **Saturated** | Already covered by Egg Garden |
| "+1 Speed" escapes, obbies | About 36,600 obby-named games (M37 source); new "+1" entries every week (M52 source) | **Saturated**, low barrier | No |
| Fishing | Fisch, Fish It!, Hooked! +9,019% in March 2026 ([RoWatcher](https://rowatcher.com/news/the-10-fastest-growing-roblox-games-in-march-2026), T) | **Crowded** | Close to a collector |
| Anime battlegrounds and RPGs | JJS, The Strongest Battlegrounds, Blox Fruits (2.2); combo combat needs custom animation ([game3-concepts.md F7](game3-concepts.md)) | **Crowded**, high cost | No animation pipeline |
| Asymmetric horror (killer against survivors) | Forsaken, Violence District, Dandy's World (2.1, 2.2) | **Strong, growing** | The killer needs animation; usually Moderate fear |
| Co-op survival and journey | 99 Nights 14.2M (M4), Dead Rails (table); horror shows "extremely high growth" ([Roblox genre insights](https://about.roblox.com/newsroom/2024/07/roblox-genre-insights-what-will-you-create-next), P) | **Proven; few kid-safe entries** (hypothesis, H1) | Strong fit (section 8) |
| Social hangouts and roleplay | Brookhaven leads (2.2); 16+ only without private spaces (M40) | **Closed** to new under-16 games | No |
| Free-form building and drawing games | 16+ only (M40) | **Closed** for under-16 | No |
| Racing and driving | "Nearly 12.5 million" searches and "players want much more" (Q1 2024, [Roblox genre insights](https://about.roblox.com/newsroom/2024/07/roblox-genre-insights-what-will-you-create-next), P); no racing game in today's top 25 (2.2) | **Under-served**, but the evidence is 2.5 years old | Vehicles are static meshes |
| Sports | 13.5M searches, "unmet demand" (same source, P); Blue Lock: Rivals 713K (table) | **Under-served** | PvP matchmaking (Relay Rounds lesson) |
| Strategy, RPG and shooters for older players | "Heavily underrepresented despite strong demand from older age groups" ([GamesBeat on Roblox's incubator](https://gamesbeat.com/roblox-unveils-jumpstart-and-incubator-programs-to-help-creators-expand-possibilities-exclusive/), R) | **Under-served** | Off our under-18 audience |
| Puzzle | CEO: "doubling down on our support for everything from 2D puzzle games to strategy" ([Q2 2026 call](https://transcripts.platformaeronaut.com/transcripts/RBLX-2Q26-transcript), P); demand data only from L sources | **Open**, weak demand evidence | Possible as a part, not the core |
| Co-op physics comedy ("friendslop") | PEAK and R.E.P.O. clones on Roblox (M24) | **Emerging**, mostly direct clones | Fits static props; physics is the risk |
| Fashion and dress-up | Dress to Impress, It Girl (M10) | **Crowded** | Needs a clothing art pipeline we lack |

## 8. Studio fit

Constraints (from the brief and CLAUDE.md): Luau and Rojo; pure rules unit-tested by Lune; procedural Blender static meshes with **no skeletal animation** (creatures bob and hop in code); licensed Creator Store audio; no human artists; a small QA budget; one owner who merges and publishes; child-safe and server-authoritative; no stealing, no paid randomness, filtered text only.

Strengths: server-authoritative systems, deep meta (`MetaRules`: XP, quests, streaks, cosmetics), collections, safe economies, cute stylised art, fast iteration, the shared kit for saves and remotes (decision 0011).

| Evidence says | Studio constraint | Consequence for game 6 |
|---|---|---|
| Co-op and 28-day return rank (M30, M31) | Strong at meta and server-side run state | Pick a co-op game with a deep meta |
| Need 16+ appeal first (M38, M39) | Under-18 audience, child-safe | Teen-friendly themes (spooky, funny, competitive) while staying at the Mild label (M40) |
| Chat is restricted (M41) | No custom chat | Pings, emotes and obvious roles |
| Clips spread games (M18) | No animators | The clip must come from situations and physics (a near miss, a chase, a reveal), not from character animation |
| Animation-heavy genres lead (battlegrounds, killers) | No skeletal pipeline | Avoid; prefer vehicles, props, floating creatures and Roblox's default avatar animations |
| Collectors are saturated (M50 to M52) | Egg Garden exists | Do not make game 4 again |
| Fast decay after spikes (M12) | Fast iteration, unit-tested rules | Plan a fortnightly content beat from day one (M17) |

## 9. Facts, assumptions, hypotheses

**Facts:** M1 to M52 as cited above, at their stated grade. Grade T and L numbers are indicative only.

**Assumptions (our reading):**

- **A1.** The Kids and Select trial (M38) makes "would a 16-year-old play this with friends?" a launch requirement, not a nice-to-have.
- **A2.** Since ads and friend traffic do not count toward ranking (M30), the first weeks' job is to turn the few organic Recommended players into day-2 to day-28 returners. Ads only buy evaluation plays and test cohorts.
- **A3.** A game that is spooky but Mild (M40) reaches the widest audience: teenagers for the trial, and children once evaluated.
- **A4.** "Non-unique" demotion (M34) and clone data (M51) mean a new entrant needs its own fantasy and look, even inside a proven format (MAYA, M9).

**Hypotheses to test:**

- **H1.** There is no kid-safe, non-violent co-op journey game in the top 25 today. Based on the 2.2 chart; not checked beyond it.
- **H2.** Roblox's racing and sports demand (2024 searches) still exists in 2026. No 2025 to 2026 racing breakout was found, so the gap may be lack of demand rather than lack of supply.
- **H3.** A session of about 20 minutes with a mid-run save point keeps both D1 (M27) and the bounce windows (M30) healthy for a co-op run game.
