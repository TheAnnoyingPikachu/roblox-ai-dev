# Egg Garden v0.5 checkpoint (put to SHANNON once, at the end of GARDEN-056)

Decision `docs/decisions/0017-garden-v05-look-valley-login.md` (Proposed), GDD section X. Work continues on the recommended option for every item: all of it is branch code, docs and staging. Attach the milestone's evidence when asking: CI run, test counts, build stamp, the start-menu frame and the EGGS panel next to the v0.4 build, the spawn and PLAY fly recording, the valley from the orbit (large sakura, hill bands, snow caps, pond, lanterns at Moonfall), the WEEKLY and MONTHLY tabs with a claim, a Weekly Egg hatch.

| # | Decision | Recommendation | If rejected |
|---|---|---|---|
| 1 | **Login tracks replace the daily streak and weekly bonus** (X3): distinct days, not streaks; weekly slots 1 to 7 with the Weekly Egg at 5 and two extras; monthly slots 3 / 7 / 12 / 18 / 22 / 26 / 30 with the Monthly Egg 4th and three extras; unclaimed slots expire at the rollover; no countdown anywhere. | Accept. | Keep the H5 streak beside the tracks: two more rows in REWARDS and 10 more minutes of income a day; a pacing rerun. |
| 2 | **Reward values** (X3.1, X3.2): 16 minutes of income a day in coins across both tracks (Wheel pays 30, Dash 6, the replaced H5 rewards 10.4), floors 100 to 1,000 coins. | Accept. | Any other minutes table; `GardenConfig.LOGIN` is data and the script reruns in a minute. |
| 3 | **Exclusive eggs plant at level 1** (0012 item 3 amended for these two only): they cannot arrive before day 5 or day 18, worth 66 and 2,383 coins/s expected against a Moon Egg's 301 at day 2. | Accept. | Gate them at Level 5 and Level 18 as the sold eggs of similar value; one number each. |
| 4 | **Six exclusive species, Index 108, milestones unchanged at 20 / 40 / 60 / 80** (X3.4): nothing is added at 100 or 108. | Accept. | A 100 milestone (a title) is one row in V4's table and `claimMilestone 100`. |
| 5 | **Exclusives are tradable under V1** (fairness by rate, friends, 3 a day). | Accept. | Mark `exclusive` species untradeable: one check in `TradeRules.canPick`. |
| 6 | **Five login-only cosmetics** (`grant = "login"`, never buyable): Blossom Can, Lantern Fence, Lily Pads, Sakura Fence, Peacock Pitcher; the second time a slot would grant one it pays coins only. | Accept. | Coins only in the extra slots; drop the five rows. |
| 7 | **Schema v3 gains `login`** (rule 7): `{ week, weekDays, weekLast, weekClaimed, month, monthDays, monthLast, monthClaimed }`, no conversion job, `sanitize` fills defaults; `daily` and `week` stay in the save. **Note:** garden/v04 (0015) and garden/wheel (0016) both call their shape v3; when all three land the merge keeps one `SCHEMA_VERSION = 3` with every field, or SHANNON asks for 4. | Accept (stay at 3; it is additive). | Bump to 4: one constant and one spec line. |
| 8 | **Spawn on a plaza pad facing the Great Egg Tree; the character goes to its gate on PLAY** (X2), not at join. Respawns land on the plaza. | Accept. | Keep the join-time move after the `SpawnLocation`: one `toGate` line back. |
| 9 | **Valley additions and budgets** (X2): 12 large sakura, three hill bands (terrain near, `hill_a/b/c` meshes mid and far), pond at (−50, 0, −92), 24 lanterns, 900 flowers; world budget 7,500 parts (was 6,000). | Accept, checked at the greybox gate with the `Parts` attribute and a low-end phone frame time. | Cut the plaza flower boxes and half the lanterns first; the sakura and hills are the brief. |
| 10 | **UI kit look** (X1): left icon strip with badges, top coin pill and level ring, ribbon panels with a close X and tabs, 3D buttons, card grids, bottom toasts, logo and PLAY start menu with the showcase; every panel keeps its function. | Accept, checked with the side-by-side screenshots. | Keep the v0.4 widgets and take only the strip and the start menu; the kit still lands for Rewards. |
| 11 | **16 icon decals drawn with Pillow** and uploaded as Decals (owned by SHANNON's account), glyph fallback until then. | Accept. | Text glyphs only; no upload. |
| 12 | **`claimDaily` and `claimWeekly` leave the remote table**; `claimLogin` and `play` join it. | Accept. | Keep the two actions refusing with a notice for one release. |
| 13 | **Six creature models, two eggs, three sakura, three hills, a spawn pad and a lantern** from the Blender pipeline (about 60,000 new static tris); cries from licensed partners when found, silent until registered. | Accept. | Any model stays on its part fallback; nothing in code waits. |

## Evidence (filled by GARDEN-056)

- CI run, test counts, build stamp: pending.
- Screenshots: start menu and EGGS panel v0.4 against v0.5; the orbit frame with the large sakura, hill bands and a snow cap; the pond; lanterns at Moonfall; `Workspace.Garden` `Parts` attribute: pending.
- Recording: join on the spawn pad facing the tree, PLAY fly to the gate; a respawn landing on the pad: pending.
- Login: WEEKLY tab with a claim and the toast; a day rollover while online counting the next day (clock moved in Studio); a Weekly Egg planted from the Dash panel and hatched; an exclusive species in the Index (108): pending.
- A literal v3 save without `login` loaded with every field kept and `login` defaulted: pending.
- Pacing: `python docs/game-design/game4-v05-pacing-check.py` output matching GDD X4: pending.
