# 0130: Animal Stations: admin coats, levels, eggs and egg times

Status: accepted (SHANNON, 2026-11-27: "can you also add the ability to choose coats and a level slider for animals
on the admin menu as well as letting me add eggs to my inventory and letting me skip all egg times"). Task
STATION-191. Date: 2026-11-27.

## What

Every one of these is checked by `isAdmin` on the server (SHANNON only, decision 0084) and changes only the admin's
own save.

- **Add animals:** above the rows, a coat button (none, then each of `StationConfig.COATS` in turn) and a level slider
  (1 to `MAX_LEVEL`; drag it or click along it). A row adds that animal at the level, in the coat.
- **Eggs tab:** "Skip all egg times" makes every hatching egg ready to open now (`StationProgress.skipHatching`;
  eggs in the storage are left alone); each egg has Add 1, Add 5 and Add 10, into the egg storage (or waiting
  when it is full), with the animal inside rolled by the server as for any egg.
- Remote contract: `admin_add(k, level, coat)`: the third argument is now `"none"` or a coat id (it was a rainbow
  boolean); new `admin_egg(egg id, count 1 to 10)` and `admin_skip()`.
- `StationProgress.give`'s last argument takes a coat id as well as `true` (rainbow); an unknown coat is refused.
