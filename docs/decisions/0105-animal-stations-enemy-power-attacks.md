# 0105: Animal Stations: what the Shadow Legion's power attacks do

Status: accepted (SHANNON, 2026-11-22, below); raising up to three, which enemies sweep and leaving the power
scores alone are Claude's draft, to confirm at the checkpoint.
Date: 2026-11-22. Task STATION-118.

## Context

- Every enemy is remade and rigged (STATION-113). The effect pass gives each one a power move of its own.
- Before this, every enemy power attack struck one animal for `POWER` times its damage; the Battle Priest's
  also healed its most hurt ally (twice the heal), and the Necromancer's raised one fallen ally (0104).
- SHANNON, 2026-11-22: "the necromancer power move will be raising a few enemies from the dead at 50% the
  battle priest power move will heal enemies and the darkcaster is just magic dps so he will actually have
  a power move ... make it so the much harder enemies like dragons and siege golems can hit all your
  animals with their power attack".

## What

- **Necromancer:** a power attack raises up to `BattleRules.REVIVE_MAX` (3) fallen allies at `REVIVE_PCT`
  (50%) of their HP, each still only once a fight. The log's `revive` (one) becomes `revives` (a list).
- **Battle Priest:** its power attack heals its whole side (every ally standing and arrived), as a Utility
  animal's already heals the team. Its normal attacks still heal the most hurt ally.
- **Sweep:** a new foe `ability`, `"sweep"`, on the Dark Drake, the Shadow Dragon, the Ancient Alpha Dragon
  and the Siege Golem: their power attack strikes every animal of the team that stands, each for the whole
  blow (each animal's Defence cuts its own share; the shield halves it for all). Their normal attacks still
  strike one. The extra strikes are in the hit's `also`, which WaveShow already shows.
- **Darkcaster:** no rule change; it gets its own power move (a bolt) in the effect pass.
- **The moves (SHANNON, 2026-11-22: "go ahead and implement all these power attack concepts"):** each enemy's
  power clip is its concept's (`MAGICS` in Creatures.client) and its effects are the concept's, drawn by
  `FoePowers` on the client. Before a power attack plays, WaveShow names who it reaches on the attacker
  (`PowerAim`: the struck slots; `PowerAllies`: the slots it raises or heals), display only. Two timings differ
  from the concepts: the charge starts with the clip (the concepts began it in the warning), and the Dark
  Drake's four spits come sooner, so every fireball lands by the hit as its damage shows.
- **Power scores (0096) are not changed:** they still count one raise, one heal and one target. So a wave
  with a Necromancer, a Battle Priest, a dragon or a Siege Golem is now harder than its shown power, which
  is what was asked for. The swarm factors (0101) are not re-tuned for the same reason.

## Checkpoint (SHANNON)

- Up to 3 raised per power attack? (Recommended. If not: pick the number; it is `REVIVE_MAX`.)
- Only the three dragons and the Siege Golem sweep, not the commanders? (Recommended: they are the "much
  harder" ones. If not: add `ability = "sweep"` to the others.)
- Leave the power scores as they are, so these waves really are harder? (Recommended. If not: count the
  sweep, the raises and the side heal in `scoreOf`; the swarm builder then scales those waves' other enemies
  down to match, so they play differently but are about as hard as before.)

## Consequences

- Boss waves are harder: a dragon's power attack now lands on the whole team. The shield matters more.
- Tests: `tests/BattleRules.spec.luau` checks the raise count, the sweep striking exactly the animals still
  standing, other foes still striking one, and the Priest's side heal.
