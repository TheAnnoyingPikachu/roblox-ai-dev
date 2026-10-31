# Egg Garden v0.2 checkpoint (put to SHANNON once, at the end of GARDEN-011)

Work continues on the recommended option for everything here except item 1. Attach the milestone's evidence when asking: CI run, test counts, build stamp, playtest notes.

| # | Decision | Recommendation | If rejected |
|---|---|---|---|
| 1 | **Schema v2 migration** (rule 7, always human-approved). Loading adds `prizeEggs` and `dash` to every save. A build older than 0012 would drop Celestial eggs and creatures, so publishing must restart every server, and there is no rollback past 0012. | Approve, staging first. | v0.2 does not publish. Nothing else is at risk. |
| 2 | **Celestial Egg price 1,000,000,000**, not the suggested 2,500,000. The suggested price is under 5 minutes of income at Level 25. | Accept. | One value in `GardenConfig`. At 2.5M the first egg comes on day 10 at 1 hour a day, day 3 at 3 hours. |
| 3 | **Prize eggs are planted from Level 10**, not at any level. Without it, a prize halves income in the first 40 minutes and doubles it at the hour. | Accept. | Remove one check in `GardenRules.plantPrize`; the first-hour curve changes as in GDD T6. |
| 4 | **Child-safety rule G4.7 widened** so a round may show its own start and finish timers. | Accept: no timer leads to a purchase or a daily reset. | Rounds still need a limit; the HUD could hide the number and use a shrinking bar. |
| 5 | **Income passes the old ceiling.** Day 45 at 1 hour a day: about 496,000 coins/s, against 42,752 without the egg. It is the last tier. | Accept the multiplier of 20; review with live data. | A multiplier of 12 gives about 248,000 at day 45. |
| 6 | **Moon Egg stays the prize at every level**, though it is worth little after Level 25. | Keep for v0.2. | A Star Egg from Level 18 would need a new decision and a pacing check. |
| 7 | **Name:** "Splash Dash" as the final player-facing name. | Accept. | Change one `GardenConfig.DASH.name` and the HUD button text. |
| 8 | **Players no longer bump into each other anywhere**, not only in the race (a one-line collision group for the whole session). | Accept: nothing depends on bumping. | Scope the group to rounds: about 10 more lines. |
| 9 | **Open QA finding N2** (GARDEN-006): during a DataStore outage over 10 s at leave, queued changes can be dropped, a prize among them. | Accept for v0.2, fix in `Profiles.finish` next. | Fix it in GARDEN-009, with its own review. |
| 10 | **HOME keeps a ready player ready**, as GDD T3 promises (architecture said it un-readied them). HOME in the 5 s start hold leaves the round. | Accept. | One condition in the `home` branch of `GardenServer`. |
| 11 | **Minimum finish 28 s, spread over the legs and held in silence.** Was 25 s with a strike at the finish. A client can still miss the obstacles by hopping between zones, but only at this pace, and T7 now says so. The fastest honest walk is 30.8 s. | Accept: bounded by the cap of 3 eggs a day. | One value in `GardenConfig.DASH`; the floors follow it. |
