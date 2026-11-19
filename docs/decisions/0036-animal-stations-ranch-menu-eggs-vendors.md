# 0036: Animal Stations ranch menu, egg storage and hatchery, vendors on the ranch

Status: proposed (for SHANNON at the first Animal Stations checkpoint)
Date: 2026-11-13. Changes how upgrades are bought (0034) and how eggs work (0025, 0031).

## Decision

From SHANNON: "get rid of the pads and add a very basic ui that you access at the home", "make an
egg storage, only six eggs can be hatching at once", "when eggs are finished you have to interact
with them to open them and manually choose what egg to hatch next", "get rid of the egg stands in
the centre and add an egg vendor to all the ranches, also add a gear vendor to the ranches as
well", "make the ranch look cooler where possible".

- **Ranch menu.** The upgrade pads are gone. The Ranch House door opens a plain list: each of the
  three upgrades with what it gives and a button for its next level, and the player's eggs.
- **Eggs are no longer instant.** A bought egg goes to the **egg storage** (a rack on the ranch,
  up to 24 eggs). The player chooses which stored egg to hatch next; **six can hatch at once**, in
  the hatchery's six nests. An egg takes time: Meadow 1 minute, Wild 10 minutes, Safari 1 hour,
  Golden 4 hours (drafts). Time runs while the player is away.
- **Nothing happens by itself.** A finished egg stays in its nest, sparkling, until its owner
  walks up and opens it. A stored egg never starts on its own. If the Barn is full the egg cannot
  be opened and keeps its nest.
- The animal inside is rolled by the server when the egg is bought and is never sent to the
  client, so the wait cannot be used to peek or re-roll.
- **Vendors on the ranch.** The hub's four egg stands are removed. Every ranch has an **egg
  vendor** stall (a list of the eggs with prices and hatch times) and a **gear vendor** stall.
  Gear is not designed yet: the gear vendor only says it is coming.
- **Looks:** the hatchery (six nests under a roof), the egg rack, the two stalls with striped
  awnings and keepers, and a windmill with turning sails once the ranch's total level is 5.

## Why

- Pads cluttered the ranch; one door is tidier and leaves the ground for things worth looking at.
- Choosing and opening eggs by hand gives a reason to come home and something to do there.

## Costs and limits

- Coins still cannot be earned in play until wave fights are built. In Studio only, the ranch menu
  has a "Test funds" button; the server action behind it does not exist on a live server.
- The hub now has no vendors. SHANNON's earlier plan put vendors there; this moves them home.
- Eggs are told apart by their place in the list, which is enough while one player acts at a time.
- The menus are plain lists (SHANNON: "dont worry about the ui so much").
