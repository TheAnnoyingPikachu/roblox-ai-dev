# 0097: Animal Stations: fight feel (Perfect timing, combos, the shield, spectacle, stars)

Status: accepted (SHANNON, 2026-11-19, from the fight concepts page: "lineup entrance and fight are all good
but just slow mo last hit for finish reward is good next wave is good. A and B and C are all good"); built by
STATION-103.
Date: 2026-11-19. Task STATION-103.

## What SHANNON chose

- The loop is line up, entrance, fight, finish, reward, next wave. The **finish** is only the slow motion of
  the last hit: the camera no longer cuts in on it.
- **A, arena spectacle:**
  - A camera behind the team, with a sweeping entrance.
  - A cut-in and the move's name in big letters when one of the team's power attacks lands.
  - Bigger damage numbers: gold for a power hit, bigger still for a Perfect.
  - A flash and a shake on a Perfect or a combo, and a short freeze on a knockout.
  - A boss that lands from the sky, with a health bar across the top.
  - Fight music, a victory sting, and a sound for each kind of hit.
- **B, Perfect timing** (rules in `BattleRules`, with taps only):
  - **Perfect:** a tap 2.5 s after the meter filled (0.15 s early to 0.4 s late) is a Perfect: x1.5 on
    top of the power attack's x2. The client draws a ring that closes at the moment to press. The press
    reaches the server `TAP_AHEAD` (about 1.2 s) ahead of the show, which is why the ring closes about
    1.3 s after the meter fills.
  - **Combo:** a power attack by a different animal of the team within 3 s of the last one adds to the
    combo, up to x4. Each step past the first adds 25% damage.
  - **Shield:** a tap on the shield (slot 0) raises it for 1.2 s and halves every enemy power attack that
    lands meanwhile. The next shield can go up 6 s later. Before each enemy power attack a warning ring
    shows under the attacker.
  - The server still decides everything. A tap is replayed from the start (decision 0092), and the shield's
    cooldown is `BattleRules.shields`.
- **Stars** (saved):
  - Up to three a wave: one for the win, one when none of the team was knocked out, one for winning
    within the target time.
  - The target is 95% of the time the fight takes with nobody tapping, or that whole time when no meter
    could fill. The 85% on the concepts page could not be reached, since tapping well shortens a fight by
    about 5 to 10%.
  - Each wave keeps its best.
  - A **star chest** is due every 15 stars. In turn: 10 wave pays; the best egg; 20 wave pays and 10
    samples; the best egg with training x2 for 1 hour; a Golden Egg.
- **The reward moment:**
  - The stars pop in one by one.
  - Coins burst towards the counter, with the claim chime. The ka-ching stays for purchases only (SHANNON, earlier).
  - The MVP (most damage) is named.
  - "Next wave" is ready in the same spot.

## How (facts)

- Rules: `BattleRules` (`PERFECT_*`, `COMBO_*`, `SHIELD_*`, `shields`, the log's `perfect`, `combo` and
  `shielded`), `LevelRules.stars` / `target` (`STAR_TIME` 0.95).
- Save schema (StationProgress):
  - `stars`: a string, character n is wave n's best, "0" to "3", at most 5,000 waves.
  - `chests`: star chests opened.
  - Older saves load with none of either.
- Chests: `StationRewards.CHESTS`, `nextChest`, `claimChest`.
- Remotes: `shield` (raise the shield), `claim_chest`.
