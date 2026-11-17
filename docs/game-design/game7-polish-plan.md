# Animal Stations: polish plan

Date: 2026-11-17. Task STATION-085. Asked by SHANNON: "can we make a polishing plan for the game".

Where things stand: the core loop is built (eggs, hatching, training, waves, upgrades, the ranch valley
and homestead, the team pen, 9 species with variants and rainbow coats). Pull request 25 holds tasks
STATION-001 to 084; CI passes. Nothing has run outside Studio. The list below comes from the "Not
done" notes of decisions 0050 to 0083 and what Studio showed this session; items already fixed since
are left out.

Each item is marked **S** (an hour or two), **M** (a task) or **L** (several tasks), and
**[SHANNON]** when it needs an approval.

## Phase 1: prove it runs (do first)

Nothing below matters if saves or phones break, and Studio cannot show either.

| # | Item | Size |
|---|---|---|
| 1.1 | Review and merge pull request 25 (84 tasks in review). **[SHANNON]** | M |
| 1.2 | A private test place: publish there (not public), Max Players 3 in Game Settings. **[SHANNON]** | S |
| 1.3 | Saves for real: buy, hatch, train, leave, come back; the Windmill fills while away. DataStores have only run offline. | S |
| 1.4 | Three players at once: three ranches, three herds and pens, waves one at a time in the arena. | S |
| 1.5 | Phone and tablet: every menu at phone size (the `UiSize` attribute in Studio first, then a real phone), the hatch pop-up, the egg vendor's rows. | M |
| 1.6 | Frame rate: the world is about 14,700 parts before any model loads and three top-level ranches show some 500,000 triangles of area models. Measure on a phone; cut where it hurts. | M |

## Phase 2: feel (the biggest gap)

| # | Item | Size |
|---|---|---|
| 2.1 | **Sound.** There is none anywhere. Buttons, buying, an egg cracking, the rarity pop-up (a bigger sting for rarer), upgrades, collecting at the mill, hits and wins in a wave, ambience on the ranch and in the hub. Roblox-owned sounds first. | L |
| 2.2 | A real hatch end to end: rocking egg, burst, the pop-up, the animal stepping out (tried only with a hatch sent by hand). | S |
| 2.3 | Tell a player when something is ready: an egg ready to open, the mill full, a training level gained (a toast or a dot on the menu button). | M |
| 2.4 | A rainbow or mythic hatch is announced to the server's other players. | S |
| 2.5 | Effects promised by the models: the Fire Cheetah's heel flames, the Lightning Cheetah's tail crackle, the War Elephant's cannon firing in its power attack. | M |

## Phase 3: fix what looks wrong

| # | Item | Size |
|---|---|---|
| 3.1 | The Giraffe and the Diamond Giraffe use the shared attack: give them a head swing (the neck is part of the head piece, so it swings the whole neck). | M |
| 3.2 | A defeated lion's mane sinks half into the ground; a long tail dips into the ground when hit. | S |
| 3.3 | Lids for the Frost Mammoth's and War Elephant's sleep: not looked at (only the Elephant was). | S |
| 3.4 | The farmhouse's "R" bakes darker than the other letters. | S |
| 3.5 | The valley's waterfall (flat glass) and bridges (plain planks) are placeholders: models for both. | M |
| 3.6 | The valley's rock is a little bluer than the mountains' stone. | S |
| 3.7 | The team pen's gate has no door. | S |
| 3.8 | The gym's second and third rams hang still, and its smaller boulders and barbells stand there at every level, used or not. | S |
| 3.9 | The middle looks of the house and the den were checked from previews only: look in the game. | S |

## Phase 4: clearer menus

| # | Item | Size |
|---|---|---|
| 4.1 | The Animals menu shows which training grounds are taken before a player tries one (now only the refusal says). | S |
| 4.2 | Another player sees the mill's board without a sum. | S |
| 4.3 | First-time help: three short pointers (buy an egg, hatch it, put it on the team). | M |
| 4.4 | Vendor signs in the hub, and the hub's stalls and notice board do something or go. **[SHANNON]** what they are for. | M |

## Phase 5: tidy up

| # | Item | Size |
|---|---|---|
| 5.1 | `src/stations/CLAUDE.md` still says wave fights are not built (they are: decision 0043): bring it up to date. | S |
| 5.2 | Unused uploads: the first `area_spring_2_5` pair, the replaced models; archive what can be (decals only). | S |
| 5.3 | The concept-only models in `assets/giraffes.py` (`concept_giraffe_*`) and the scene switches (`PEN`, `TEAM`) stay for the cards; note them so a full build leaves them out of the manifest. | S |

## Not in this plan (new features, not polish)

Gear (the gear vendor only shows a message), the animal pen behind the Barn (decision 0077), a fifth
egg, night in the hub, the gentle giraffe looks (decision 0082). Each needs its own design first.

## Recommended order

1. Phase 1 now: it is the only one that can turn up a data-loss or crash problem, and 1.3 to 1.6 need
   1.1 and 1.2 from SHANNON first.
2. While that waits, start 2.1 (sound) and 3.1 to 3.4: none needs an approval and all can be undone.
3. Then the rest of Phase 2, Phase 4, Phase 3's bigger items, Phase 5.

## For SHANNON (one checkpoint)

1. Merge pull request 25 (recommended once you have looked over it; if not, it keeps growing).
2. Approve a **private** test place to publish to (recommended; without it phones, saves and three
   players stay untested).
3. Pick the first phase to work on (recommended: sound and the small fixes while 1 and 2 wait).
