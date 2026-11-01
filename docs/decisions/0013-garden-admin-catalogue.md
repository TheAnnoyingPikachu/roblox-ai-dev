# 0013: Egg Garden admin catalogue

Date: 2026-11-01
Status: Accepted by SHANNON 2026-11-01 (asked for the menu in the published game). Adds to decision 0008's `Request` table and 0012's rules.

## Decision

- `GardenConfig.ADMINS` lists the UserIds that may use the catalogue: SHANNON's account `96807256` only. It is public data; it grants nothing on a client.
- New `Request` action `adminGrant`, argument `species:mutation:size`. The router refuses it unless `ADMINS[player.UserId]`, before any rule runs. The client's hidden buttons are convenience, not the check.
- `GardenRules.grant` adds one creature to the caller's own garden: lowest free pad, else storage, refused when full. It accepts exactly what `GardenConfig.indexable` and `GardenConfig.size` allow, so a granted creature always survives `sanitize`.
- A grant adds the Index entry, and with it the Index income bonus. It pays no XP, hatch count, coins or Lucky Meter.
- The save schema does not change. There is no action to give creatures to another player.

## Consequences

- SHANNON's income can pass any honest player's, and it shows on the shared income board. Accepted: the board is not a prize.
- Adding an admin is a one-line change in `GardenConfig`, reviewed like any other code.
- A remote `Request` for `adminGrant` from anyone else returns false and changes nothing.
- A granted creature is a normal creature: releasing one pays coins and counts for quests (a Huge Celestial Dragon pays 450,000). Only the owner can do this.
- A granted Index entry takes the place of a hatch's first find, so that key's 50 XP is not paid on a later hatch, and it counts towards Index-gated cosmetics.
