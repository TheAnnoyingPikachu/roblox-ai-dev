# 0117: Animal Stations: the eternal rarity, sold for Robux and given in the beta

Status: accepted (SHANNON, 2026-11-24: "now add them into the game. make them the absolute highest rarity infact
make a new rarity for them, dont put them into eggs but put them into everything else and aldo give them coats
and whatnot", then "this rarity will be obtain via robux and beta rewards", then "yes we're adding it we're
monetising the game"). The numbers, the tier's name and colour, and who gets the beta reward are Claude's
draft, for the checkpoint. Tasks STATION-151 and STATION-152. Date: 2026-11-24.

## Context

- Fact: decision 0002 (Bake Rush, 2026-10-24) kept paid items cosmetic. SHANNON has now chosen to sell these
  two fighters for Robux in Animal Stations: paid items here change progression. Decision 0002 still holds for
  the other games.
- Fact: a tier above celestial already existed, "secret", in every rarity table but with no power band and no
  animal. It is left as it is.
- Fact: the Sahara Guardian and the Sahara Mammoth were made, rigged, uploaded and given moves in STATION-145
  and 147, owned by nobody.
- Fact: every variant hatched from an egg (a spec checked it); coats are rolled only on a hatch.

## What

- A new rarity, **Eternal**, the top of every list (`StationConfig.RARITIES`, after "secret"), sun gold
  (`Style.RARITY`), its power floor 2300 (a Titan's 3680). A spec keeps it for the exclusive variants only.
- Two **exclusive** variants (`Variant.exclusive`): the Sahara Guardian (`sahara_lion`, the Lion's, strength,
  mult 7: power 2310) and the Sahara Mammoth (`sahara_elephant`, the Elephant's and so a Titan, strength, mult
  5: power 3850). No egg drops them (a spec checks); every animal keeps its two egg variants.
- Everywhere else, like any animal: rarity sorting and the reveal (`RANK`, `BIG` 6), the Hall of Fame, the
  Animals menu (they show in "Seen" with "Shop" as where they come from), trading (worth 800), release (40,000
  coins, twice with a coat), fusion, the admin menus, both rainbow coats (uploaded, run 45499381991).
- **Robux** (`StationConfig.PRODUCTS`): each is a developer product. The Eggs window's shelf shows an "Eternal
  animals" row; a card asks Roblox to sell it. The server's `ProcessReceipt` grants it into the save once per
  receipt (`StationProgress.grant`, keyed by PurchaseId in `Profile.receipts`, the newest 200), writes the save
  (kit `Saves.flush`), and only then tells Roblox it is granted; a full save or a failed write leaves the
  receipt for Roblox to send again. A bought animal has every stat level at `BASE_MAX` and rolls a coat like a
  hatch from no egg.
- **The beta reward** (`StationConfig.BETA_GIFT`): every save that plays while it is set gets the Sahara
  Guardian once (`Profile.beta`), the same way. Set it to nil when the beta ends.
- The save version goes to 3 (new variants; `receipts` and `beta` in the save).

## Not done

- The products are not made: `product` is nil for both, and the shelf says "Coming soon". Making them (and
  their prices) on the Creator Dashboard is SHANNON's; then their ids go into `PRODUCTS`.
- No game passes, no other paid items: the monetisation concept is a separate proposal.

## To confirm at the checkpoint

1. Prices. Recommended: the Sahara Guardian 799 Robux, the Sahara Mammoth 1,499 (the strongest Titan).
2. The beta reward: everyone who plays the beta gets the Guardian (recommended; it makes the beta feel special
   and the Mammoth stays the paid one), or only some (wave reached, days played).
3. Trading paid animals: on, like any animal (as built). Roblox allows trading; some games block paid items
   from trades to avoid scams and chargebacks. If rejected, a spec-checked `exclusive` skip in `StationTrade`.
4. The numbers: floor 2300, release 40,000, trade worth 800, `BASE_MAX` levels on a bought one.
5. The name and colour of the tier ("Eternal", sun gold).
6. A Roblox policy check before release: paid random items need odds shown; these are not random (the animal
   is fixed, only the coat is rolled: say if the coat roll should go, so nothing paid is random).
