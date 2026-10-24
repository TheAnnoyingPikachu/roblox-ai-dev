# Pilot concepts (PILOT-001)

Constraints: zero budget, all content on SHANNON's personal account, audience younger players, genre "whatever is trending".

**Evidence status:** no live Roblox trend data was checked. Demand scores are hypotheses to test, not facts.

Scores use the blueprint scorecard (1–5 per criterion, weighted to 100).

| Criterion (weight) | A. Sky Ladder obby | B. Bake Rush | C. Relay Rounds |
|---|---|---|---|
| Core-loop appeal (20) | 4 | 3 | 4 |
| Differentiation (15) | 2 | 3 | 3 |
| Audience demand (15) | 4 | 4 | 3 |
| Feasibility, zero budget (15) | 5 | 4 | 4 |
| Retention (10) | 3 | 4 | 3 |
| Social play (10) | 2 | 2 | 5 |
| Content scalability (5) | 3 | 4 | 3 |
| Monetisation compatibility (5) | 2 | 2 | 2 |
| Technical simplicity (5) | 5 | 4 | 4 |
| **Total** | **69** | **67** | **71** |

## A. Sky Ladder (obstacle course)

- **Pitch:** a 30-stage tower of jumps. Each stage unlocks the next; reaching the top is the goal.
- **Core loop:** attempt, fall, respawn at the last checkpoint, retry.
- **Differentiator:** stage design that teaches one new move per stage.
- **Session:** first stage in under 60 seconds.
- **Progression:** stage count and a personal best time.
- **Riskiest assumption:** young players stay engaged after the third fall.
- **Kill criterion:** under 50% of new players finish stage 3 in playtest.

## B. Bake Rush (click simulator)

- **Pitch:** tap to bake, sell pastries, upgrade the oven.
- **Core loop:** collect, bake, sell, upgrade.
- **Differentiator:** a short, readable economy with no timers.
- **Session:** first sale within 30 seconds.
- **Progression:** oven tiers with visible unlocks.
- **Riskiest assumption:** the upgrade curve feels fair without spending Robux.
- **Kill criterion:** players stop before the second oven upgrade in playtest.
- **Note:** the server owns all coins and sales; the client only requests bakes.

## C. Relay Rounds (round-based team game)

- **Pitch:** 2–4 player teams race through a shrinking course, passing a baton; the slowest team each round is eliminated.
- **Core loop:** round, race, eliminate or advance.
- **Differentiator:** short rounds (about 90 seconds) that suit young players.
- **Session:** a full game in about 8 minutes.
- **Progression:** round count and unlockable course themes (free).
- **Riskiest assumption:** players find matchmaking with strangers fine without voice or chat.
- **Kill criterion:** fewer than 30% of players start a second round in playtest.
- **Note:** free text chat must be off or filtered; the team mechanics need servers that handle disconnects.

## Recommendation

Concept **C** has the highest score, but it depends most on multiplayer, which is the hardest part to test headless. Concept **A** scores close behind and is the simplest to build and verify, so it suits the pilot's job of proving the pipeline. SHANNON decides.
