# Lantern Express v0.1 checkpoint (put to SHANNON once, by LANTERN-014)

Decision `docs/decisions/0018-lantern-express.md` (Proposed), GDD `docs/game-design/game6-gdd.md`, plan `docs/production/game6-plan.md`. Work continues on the recommended option for every item while it can be undone (branches, docs, Studio, staging-only code). Nothing here is published, spent or made public before SHANNON answers (CLAUDE.md rule 7). Attach the milestone's evidence when asking (section D).

## A. Before the first staging publish (SHANNON's hands; nothing public)

| # | Decision or step | Recommendation | If rejected |
|---|---|---|---|
| 1 | **Place structure** (0018 §1): one place; each server is one crew of up to 6 with the Depot hub in the same place; no lobby place, no `TeleportService`, no reserved servers. Friends arrive with Roblox's Join button or a private server and join at the next stop. | Accept. | A lobby place plus a reserved server per run: two more tasks (teleports with retries, MemoryStore access codes so friends can follow, a second publish target), and run start and end can no longer be tested in Studio. |
| 2 | **Create a new experience "Lantern Express"** under SHANNON's account (private while on staging) with one place; set **Max Players 6** (Creator Hub > the place > Settings; a place file cannot carry it); turn **private servers on at price Free**. | Accept all three. Free private servers are the friend-crew space and count as co-play (M30); no Robux involved. | Private servers off: friends use the Join button only, and fewer co-play days are counted. Max Players above 6 makes the server warn and players wait (the train has seats for 6). |
| 3 | **GitHub environment `lantern-staging`** with variables `ROBLOX_UNIVERSE_ID`, `ROBLOX_PLACE_ID` and secret `ROBLOX_API_KEY` (an Open Cloud key with place publishing and Luau execution for this universe only). | A new key scoped to this universe (least privilege). | Add this universe to the key `garden-staging` uses: one key with a wider reach. |
| 4 | **Publish:** run `publish.yml` with `lantern-staging` on the `v*` tag LANTERN-014 names (or let the release thread run it once you have answered). | Accept after items 1 to 3. | Staging waits; the feel gate below cannot run. |

## B. Design and economy (rule 8 items; all data, reversible)

| # | Decision | Recommendation | If rejected |
|---|---|---|---|
| 5 | **The seated rule** (0018 §2): the train moves only while every crew member is seated; standing up while moving puts you back in a seat within 0.5 s. | Accept. It removes characters walking on moving physics, the concept's biggest technical risk. | Walking on the moving train: a new physics task (moving platforms with client ownership) and a jitter risk at every stop. |
| 6 | **Shared rewards** (GDD H3, H4): every active crew member gets each rescued critter in their album and a share of each load's Tickets, ceil(v × (1 + 0.1(n − 1)) / n); loot per stop grows with the crew. A player earns 709 Tickets a run alone and 779 in a crew of 4 (GDD P). | Accept. | Rewards to the carrier only: crews turn competitive (a race for crates) and strangers stop helping; one function in `LanternProgress`. |
| 7 | **Depot prices** (GDD F): Boiler 30 / 60, Bunker 25 / 50, Lamps 30 / 60 Parts; coal 30 for 12; oil 2 for 10. A solo player buys about 2 upgrades a run, a crew of 4 all 6. | Accept. | Any numbers; `LanternConfig.UPGRADES` is data and the pacing script reruns in seconds. |
| 8 | **Ticket and XP values** (0018 §5): critters 10 / 15 / 25 / 50 / 100, Depot 30, Dawn 150, Lampeater fed 50; cosmetics 1,200 to 6,000 Tickets (the first priced cosmetic after about 2 runs); level 6 after the first run, 17 after ten. | Accept. | Data only, as item 7. |
| 9 | **Critter odds** (GDD H4): near crates 70 / 25 / 5 / 0 / 0%; far crates up to 3% Legendary, the Moon Hare only on leg 3 far crates. A solo player fills the 12-critter album in a median of 10 runs (90%: 24); 9% of solo runs find a Moon Hare. | Accept. | A higher Moon Hare chance (5% is one number) or a pity counter on far crates (a new save field). |
| 10 | **Difficulty** (GDD P): casual crews always reach Dawn; new players lose 6% to 30% of runs, at night and mostly in the third leg. Losing costs only the run (nothing earned). | Keep for v0.1 and judge at the feel gate (item 15). | Harder: wisps per turret 4 / 7 / 9 and the Lampeater diving every 6 s, then rerun the script. |
| 11 | **Login tracks** (GDD H5): weekly 40 / 60 / 80 / 100 / **Midnight Express livery** / 120 / 150; monthly at 3 / 7 / 12 / **18: Ember Kit** / 22 / 26 / **30: Aurora Beam**, 1,400 Tickets in all; earned slots and completed daily quests left unclaimed are **paid automatically at the rollover** (the Garden QA M1 rule, extended to quests). | Accept. | Exclusives at the end of each track only (7 and 30): harder to reach; two rows of data. |
| 12 | **Save schema v1** (0018 §4): a new store `LanternProfile<suffix>`, one player's record, nothing ever writes two saves together, no migration; a newer save loads read-only (a backwards-compatible kit addition). | Accept. | Nothing to migrate either way; the schema can still change before the first public publish. |
| 13 | **The Medic role is called Mender** (nobody is ever hurt; the Mender refills the lanterns). Roles are badges anyone can earn, never seat limits. | Accept. | Keep "Medic" as the badge name; one string. |
| 14 | **One shared UI kit** (`src/kit-roblox/modules/UiKit.luau`, from Garden's, theme injected); Garden keeps its own copy until a Garden release moves it. | Accept. | Copy Garden's UiKit into the Lantern client: faster now, two kits to keep in step later (the v0.5 lesson). |

## C. Gates on staging

| # | Gate | Recommendation | If rejected |
|---|---|---|---|
| 15 | **Feel gate** (GDD R): on staging, one leg solo on a fresh profile and one leg with a second player; rate 1 to 5. Under 4 twice after fixes stops the game and moves to concept C, which reuses the carrying, crates, houses, pings and critters. | Play it with the build stamp noted (about 25 minutes). | |
| 16 | **Feel gate and look review together on the art build**, instead of a separate greybox checkpoint first. Art is branch work and can be undone; if the gate fails, concept C keeps most of it. | Accept. | LANTERN-012's greybox build gets its own staging card first, and the art uploads (LANTERN-011) wait for its answer: about a week later. |
| 17 | **Look review:** the start menu, a stop at the fog bell, a night with four beams, the Lampeater, the album. | Rate each frame, or give a fix list. | |

## D. Before a first public publish (not needed for staging; start the slow ones now)

| # | Step | Recommendation | If rejected |
|---|---|---|---|
| 18 | **All-ages reach needs the owner account ID-verified (age check) and 2-Step Verification on** (M38). | Do both now: no cost, and verification can take days. | The game can only ever be published for 16+. |
| 19 | **Plus or Premium held for 2 months, or the refundable 1,000 Robux fee per game** (M38, M39). | The refundable fee, at the launch checkpoint (spending needs your approval then, not now). | A subscription started now would be 2 months old by launch; or stay 16+ only. |
| 20 | **Maturity questionnaire** (0018 §6): Violence mild (non-human wisps puff into sparkles, no damage), Fear mild, everything else none, no paid random items, no trading, not a hangout, no free-form creation, Roblox chat only. Expected label **Mild**. | Answer as listed at the first public publish; check the live form's wording first. | Answering Violence "None" also leads to Mild (fear) if Roblox agrees it is not violence. |
| 21 | **Sponsored ads** to reach the trial's 250 engaged plays (M42). | Decide at the launch checkpoint with staging retention data. | Organic trial only. |
| 22 | **Production:** `PRODUCTION_UNIVERSE_ID` stays nil and no production environment exists until you approve a production release. | Accept. | |

## Evidence (filled by LANTERN-013 and LANTERN-014)

- **CI run:** (link). **Test counts:** `lune run tests/run` n/n. **Build stamp on staging:** (sha), seen in the corner label and the `[Build]` line.
- **Pacing:** `python -I docs/game-design/game6-pacing.py 300` equals GDD section P.
- **QA verdict:** `docs/qa/lantern-review.md` (blockers, majors, re-review).
- **Timings** (GDD K, Studio and staging, with the stamp): train leaves, stop 1, first rescue, stop 2.
- **Recordings and screenshots:** the train at cruise speed on a second client; a fog sprint; a night with beams; the Lampeater; the start menu; the album with odds; a phone at 844 × 390.
- **Performance:** MicroProfiler server frame time with 6 players and 34 wisps; phone fps at a stop and at night.
- **Nothing lost:** leave mid-leg and rejoin; run ends by coal and by lantern; a quest and a login slot across a rollover.
