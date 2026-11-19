# 0034: Animal Stations ranch tycoon: three upgrades that change how the ranch looks

Status: proposed (for SHANNON at the first Animal Stations checkpoint)
Date: 2026-11-13. Builds on 0029 (the ranch is the player's base and a tycoon). Draft numbers.

## Decision

From SHANNON: "make it an upgradeable tycoon area like this image", "have upgrades that improve
training times and storage and such and each upgrade also makes the ranch look bigger and
better", then "make it a super high detail finished product now, but dont worry about the ui so
much. just the actual ranch". The reference image is a square fenced ranch: a stone gate, a paved
path up to a ranch house, a roaming paddock, a habitat, and glowing colour-coded training areas
with a sign each.

**Three upgrades**, bought one level at a time at a glowing pad on the ranch:

| Upgrade | Gives | New ranch | Levels |
|---|---|---|---|
| Ranch House | animals training at once | 2 | 3, 4, 5, 6 |
| Barn | animals you can keep | 10 | 20, 30, 45, 60, 80 |
| Training Grounds | training speed | 100% | 115, 130, 150, 175, 200% |

- **Cost:** coins, and from the third level also **samples** (dropped by harder waves, as SHANNON
  described the tycoon: "hard to aquire enough gold and samples"). First levels cost 500 to 1,000
  coins; top levels 400,000 to 500,000 coins and 60 to 150 samples.
- A new ranch now starts with 2 training places (was 4) and room for 10 animals (was 100), so the
  first upgrades matter.
- Buying Training Grounds settles training first: time already spent counts at the old speed.
- A save is never cut down to fit: animals over the Barn's room are kept, only buying more is
  refused.

**Every level changes the ranch** (`src/stations/Ranch.luau` builds the plot from the owner's
levels and builds it again after each upgrade, about 20 ms):

- Ranch House: a small log cabin, then wider and taller with a porch and lit windows, a chimney
  with smoke and dormers, side wings and a gold paw emblem, a flag.
- Barn: a lean-to with hay, then a red barn that grows, with barrels, silos, a weather vane, a
  hay cart and a gold star.
- Training Grounds: six bare pads, then courts in each stat's colour with a sign, glowing edges
  and pylons, the stat's own gear (hurdles, barbell, pool, crystal, spring, dummy), lights and a
  beam.
- The sum of all levels brings the rest: paved paths and a plaza, lantern posts, flowers, ponds,
  benches, a rest pavilion, a well, a fountain, flags, and more trees, bushes, rocks and grass.

The layout follows the reference: gate and path in the middle, roaming area on one side (the
Rhinos pace there for now), the barn and its yard on the other, the courts in a row across the
middle, the house at the back.

## Why

- Three clear upgrades cover what was asked (training time, storage, "and such": training
  places) without inventing systems nobody asked for.
- Rebuilding the whole plot from three numbers is simple, cannot drift from the save, and lets
  every level look different.

## Costs and limits

- Coins and samples cannot be earned in play until wave fights are built. In Studio only, a
  purple ball by each gate gives test funds; it does not exist on a live server.
- One kind of sample for now.
- No upgrade menu: the pads are the whole interface, plus a samples line in the HUD.
- A fully upgraded ranch is about 2,000 parts. Three of them is fine; watch it on phones.
- The ranch does not grow past its fence. Expanding the plot is not built.
