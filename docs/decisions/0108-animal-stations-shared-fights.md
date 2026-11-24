# 0108: Animal Stations: shared fights on the Legion's battlefield

Status: accepted (SHANNON, 2026-11-24, below). The numbers are Claude's draft, to confirm at the checkpoint.
Date: 2026-11-24. Tasks STATION-123 (the rules), STATION-124 (the battlefield, the wave portal and its
light) and STATION-125 (the fight in play: server, show, HUD, camera).

## Context

- Fact: a server holds three players and the arena held one player's fight at a time, so the other two
  read "The arena is busy" (the release review of 2026-11-23).
- Concept: the canvas "New Arena Concepts", boards "Fighting grounds" and "Castle battlefield", built in
  Studio from SHANNON's picture of a purple castle in the mountains above a battleground.
- SHANNON, 2026-11-23 and 24:
  - "make a battlefield following this artstyle and objects ... a castle in the mountains and a large
    battleground area build over the studio concept that fits three players. make it one shared target and
    add a camera for each player."
  - "get rid of the uhh plates beneath the creatures now, just put them on the ground instead now we have
    the map".
  - "when three players join a fight the rewards are the same as solo and theyre the same for all three but
    itll be easier to fight the enenimes"; "crowds will scale for each player in the game"; "all clicks do
    damage to the closest target to your team"; "everyone receives the same amount of coins regardless of
    player count and stuff so no splitting the coins"; "players will vote on a boon with a tie picking
    randomly".
  - Carried health: "option B" (a player whose whole team is knocked out gets it back at 25% for the next
    wave). Joining: "everyone joins the portal thing and when it starts everyone inside joins the fight".
  - Then (amended, STATION-126): "this concept is amazing can you build that over the old arena, alter that
    area of the map to make it all look fitting and such, also dead players come back at 25% each round".

## What

### The battlefield and the wave portal

- The wave fights happen on the Legion's battlefield (`Battlefield.luau`, at `World.FIELD`), built over the
  old arena: the canyon north of the hub is now its approach (`Battlefield.REACH`, 750 studs from the hub's
  north edge to where the teams stand), a road between peaks and pines past the Legion's ruined gateway,
  braziers and banners, and the old pit, its gate and its road beyond are gone. The battlefield: the castle on a rock shelf, mountains all round, a waterfall, a river and a bridge, forest, and
  on the field watchtowers, catapults, tents, ruins, barricades, braziers, banners and the summoning circle
  the Legion walks out of. The animals stand on the ground; each player's place has a camp behind it in
  their colour (gold, green, blue).
- The wave portal stands where the road leaves the hub: a ring with a standing portal behind it, on a
  stone floor across the road. Its prompt opens the wave list. Everyone in the ring when a wave starts goes
  to the fight. The field can also be walked to, up the road; walls keep players on the approach and the
  field, short of the castle.
- The light there is its own (`ArenaMood.client`): early afternoon, the sun behind the teams. It fades in
  up the road north and out on the way back, in place of the canyon's dusk.

### A fight is a party's

- A party is one to three players: whoever starts the wave, and everyone standing in the portal's ring
  with a team. This holds at a run's first wave and at every wave after, so a player can join a run that
  is already going by waiting in the ring. A new joiner's animals start at full health and take the run's
  boons.
- There is one field. While a party fights, or picks its boon (60 seconds at most), another party's
  `wave` is refused ("field").
- Teams stand side by side, turned in towards the one crowd (`Battlefield.SEATS`): each team's animals in
  a line and its Titan behind them.
- Each player has their own camera, behind their own team (`ArenaCamera.client`), nearer for a team of
  small animals.

### The rules (`BattleRules`, `LevelRules`, `WaveRuns`)

- The crowd for two and three players' teams has `PARTY_COUNT` (1.5 and 2) times the foes and elites and
  `PARTY_POWER` (1.6 and 2.1) times the power, with one boss. The power grows by less than a whole wave's
  for each player, so a wave is easier fought together.
- The front line is `FRONT_MORE` (3) longer for each player after the first: 6, 9, 12. Each foe in it has a
  place along it; a foe that steps up takes the place the longest empty. Player k's team stands before the
  k-th part of the line.
- A foe attacks the team it stands before (its first standing Defence animal, else its first standing
  animal), and the usual target once that team is down.
- A click is its player's: that player's next standing animal strikes the standing foe of the front line
  nearest that player's team. Each player's clicks keep their own pace. With one player nothing changes: a
  click strikes the usual target.
- Everything else is one team's: the animals' own attacks and power attacks go for the usual target, and
  there is one combo and one shield for all. Pack and solitary bonuses stay inside each player's own team.
- Pay: every member is paid by their own save exactly as alone (`StationProgress.payout`), whatever the
  party's size. Nothing is split. Each keeps their own pot and their own stars.
- A player carried to a wave past their own best is paid its first clear, and it becomes their best
  (`StationProgress.clear` with `carried`).
- Carried health: each animal carries its own, as alone. Every animal knocked out when a wave is won,
  alone or in a party, fights the next wave at `WIPED_BACK` (25%) of its max HP (`WaveRuns.setup`). The run
  keeps it at 0 between waves, so the Revive boon still lifts it to half. (First built for a whole team only;
  SHANNON asked for every knocked-out animal.)
- The boon: each member votes. The boon with the most votes is the party's (`WaveRuns.tally`); a tie is
  picked at random among the tied, by the run's seed. It is settled when all have voted, or `VOTE_SECONDS`
  (7) after it is offered, nobody's vote or a tie picked at random; the HUD counts it down. Alone there is
  no limit. The next wave starts then.
- A member who leaves is paid their pot; the party goes on. If the host of the show leaves in the middle
  of a wave, that wave ends for everyone with the result as it stood.

## Evidence

- Specs: `BattleRules.spec` (shared fights), `LevelRules.spec`, `WaveRuns.spec`, `StationProgress.spec`:
  786 pass.
- Simulation, three like teams from a fresh run (no boons), 4 clicks a second each: the last wave won
  alone, by two and by three. Starter 8: 17, 19, 19. Mid 35: 39, 39, 49. Max 70: 69, 69, 69. Together is
  never harder; the boss waves are where a party stops.
- Played in Studio on build `dev` (local, one player): a run through the new path on the battlefield
  (waves 1 to 3, the boon vote, leaving); three teams of four staged against wave 66's crowd of 32 from
  each seat's camera; clicks, power taps by seat and the shield through `WaveShow`.
- Not tested: two or three real players together. Studio's play mode here has one.

## Checkpoint answers (SHANNON, 2026-11-24)

- 1, 3, 6: accepted as built (6 left to Claude: kept).
- 2: accepted, but the field is held 30 seconds for a boon (`HOLD_SECONDS`, was 60).
- 4: accepted; a carried player is paid only for the waves they fought in (as built: each wave pays its members),
  and eggs now unlock by player level, not the best wave (decision 0110, amended), so a carry opens no eggs.
- 7: as built: a run ends when the whole side is down (a solo team wiped, or every member's team in a party);
  one member's team down in a party comes back at `WIPED_BACK` for the next wave.

## To confirm at the checkpoint

1. `PARTY_COUNT` 1.5 and 2, `PARTY_POWER` 1.6 and 2.1, `FRONT_MORE` 3.
2. `WIPED_BACK` 25%, `VOTE_SECONDS` 7 from the offer (SHANNON, 2026-11-24: "a short 7 second vote"), the field held 60 seconds for a boon.
3. Joining at every wave's start, not only a run's first.
4. Carrying: a new player beside a strong one clears far waves at once, and the eggs those waves open.
   Accept (recommended: it is what playing together is for), or pay a carried player without moving their
   best.
5. Done (STATION-126): the battlefield over the old arena, the pit removed.
7. "Dead players come back at 25% each round" read as every knocked-out animal, alone too: solo runs get a
   little easier. Recommended: keep. Rejected: back to a whole team only, in a party only.
6. A foe attacks the team it faces and a click strikes the nearest foe only in a party; alone both are as
   before.

## Not changed

Boons and how they stack, rewards, the crowd rows (`CROWDS`), trading, and fights between players (none).
