# 0045: Animal Stations: eggs stay at the ranch, a level for the Safari Egg, the battle arena overhaul

Status: proposed (for SHANNON at the first Animal Stations checkpoint)
Date: 2026-11-14. Builds on 0036, 0043 and 0044. The arena part is built out by decision 0046.

## Decision

From SHANNON: "keep eggs at the ranch, lock the safari egg behind level ten, then do the battle arena
overhaul".

- **Eggs stay at the ranch.** The bottom bar (decision 0044) has two buttons, Animals and Waves. The
  egg storage opens from its rack at the ranch (and from the ranch menu), the egg shop from the vendor's
  stall, and finished eggs are opened at the hatchery, all at the ranch as before.
- **The Safari Egg unlocks at player level 10** (it was open from the start; its price, 15,000 coins,
  is unchanged). The Golden Egg stays at level 15. A locked egg shows "Unlocks at level N" and a tap
  says which level it needs.
- **The battle arena.** The canyon north of the hub is now a place for a fight, not an empty floor:
  - **The pit:** a paved stone floor with violet trim, with braziers (warm near the team, violet
    near the gate) and red banners down both sides.
  - **The dais:** the team stands on a blue stone dais with a glowing ring.
  - **The Hexbound's gate:** at the far end of the pit, two dark towers, a stone lintel with spires and a
    glowing eye, and a shimmering violet portal. The enemies walk out of the portal to meet the team
    (at about 13 studs a second), instead of walking in from nowhere.
  - **Closer lines:** teams stand nearer one another and nearer their neighbours, so the fighters fill
    more of the picture.
  - **A fight camera:** while a wave is shown, the camera takes over (`ArenaCamera.client.luau`):
    it stands back and above on the dais side, far enough that both teams show whatever the
    screen's shape (`UiLayout.fightDistance`, from a focus and a radius the server sets on the player),
    drifts a little, and gives the camera back when the fight is left. The player's character
    stands by the pit's edge, out of the picture.
  - **A wave title:** "WAVE 7", or "BOSS WAVE 10" in red, with the enemies' names, fades over the
    start of every fight.

## Why

- Eggs are the ranch's loop; keeping them there keeps players moving between the two places.
- A level for the Safari Egg gives the first mid-game goal between the Wild Egg and the Golden Egg.
- Nearly all of a fight was a small animal far away on a bare floor. A frame that fits the fight, an
  entrance and a stage make the fight the game's best moment.

## Costs and limits

- Viewed on a desktop in Studio only. The camera's framing for a phone held upright follows from the
  screen's shape (tested as a number), not from a phone.
- The arena is about 50 parts and 18 lights and fire emitters, and the Hexbound's own glows: not
  measured on a phone.
- The camera is not skippable and no fight can be watched from a different angle.
- Archers and mages still fire nothing visible; there are no hit effects beyond the existing ones.
- The old red "spawn" strip at the far end of the canyon is still there, out of sight.
