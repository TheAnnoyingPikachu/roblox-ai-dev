# Animal Stations (game 7): read this first

Egg animal collector, at framework stage: hatch animals, level their six stats at your ranch, and
send a team of three plus a Titan through endless waves. The ranch is the player's base (a tycoon
later); the hub is for vendors. Keep things simple: placeholders, draft numbers.

- Project `stations.project.json` (CI builds and place-checks it). No publish environment yet.
- Docs: `docs/game-design/game7-gdd.md` (the current summary), `docs/game-design/game7-animals.md`
  (roster and looks), decisions 0019 to 0046 (0029 to 0046 are the latest and replace parts of the rest).
- Not built: wave battles in the arena (so coins and samples cannot be earned in play), what waves pay. In Studio only, the ranch menu has a test funds button. Gear is not designed: the gear vendor only has a message.

## Files

| File | Owns |
|---|---|
| `StationsServer.server.luau` | entry: builds the world, ranch assignment and spawn, teleport prompts, kit Saves (`StationsProfile`), kit Router + `StationsRemotes` (profile, buy, hatch, open, upgrade, team, train, stop; funds in Studio only) |
| `../stations-client/Hud.client.luau` | coins and player level, toasts, Animals panel (team button, one train button per stat), and three plain lists opened by prompts in the world: the ranch menu (house door), the egg vendor, the egg storage; display only |
| `Ranch.luau` | everything that stands on a ranch plot, built from its owner's upgrade levels and built again after each upgrade: house, barn and yard, six training courts, the hatchery and egg storage (`Ranch.eggs` shows the eggs), the egg and gear vendors' stalls, paths, scenery |
| `Creatures.luau` | animal models: loads a `StationAssets` model once, rigs it with Motor6Ds from the manifest joints, `spawn`, `play` (sets `Anim` and `AnimAt`), `speed` |
| `../stations-client/Creatures.client.luau` | animates every model tagged `Creature` (idle, walk, attack, magic) and plays the magic attack's effects; display only |
| `World.luau` | the hub (plaza, Hatchery fountain, south walk, teleport pad, north road, scenery), the wave arena canyon, three ranch islands (the plot only: lawn, fence, gate, teleport pad), the mountains and invisible walls round every area, lighting, spawn |

Pure rules in `src/shared`: `StationConfig` (stats, stat levels, roles, groups, species, variants,
eggs, stations), `StationRules` (hatch, stat levels, roles), `BattleRules` (wave fights on a clock),
`LevelRules` (waves, rewards), `StationProgress` (saved profile and every change to it). Each has a spec.

## Must stay true

- The server decides prices, hatches and times; profile changes are pure `StationProgress` functions that capture their inputs (SaveStore runs them twice).
- "Level" has three meanings: wave (`LevelRules`, `Profile.best`), stat level (0 to `MAX_LEVEL`, `Owned.trained`) and player level (`StationProgress.playerLevel`, from `Profile.xp`).
- `BattleRules` is for wave fights only. Fights between players will work differently and stats will not affect them: build nothing with PvP in mind.
- Each stat has exactly one job in a wave fight (Speed swing, Stamina rest, Strength damage, Mana energy per attack, Health HP, Defence damage cut); the spec checks it. A stat's value is the species number grown by its level, so species still matter.
- Training runs in real time, also while the player is away, with no cap; level times come from `StationRules.levelSeconds` (whole seconds).
- A role and a group come from the species, never from stats. The Titan is never in `Profile.team`; it uses `Profile.titan`.
- `sanitize` repairs an animal's missing stats from its species; it only drops unknown species and duplicate ids. Keep it that way when stats change.
- World and Ranch are display only. Tags for the server: `TrainPad` (`Ranch`, `Station`), `RanchSpot` (`Ranch`, `Index`), `RanchNest` (`Ranch`), prompts `RanchMenu`, `EggStorage`, `Egg` (`Index`, `Due`) and `Vendor` (`Kind`), all with `Ranch`, `Teleport` prompts (`To` = "hub" or "ranch"), `WaveStand` and `WaveSpawn` in the arena. Everything on a ranch is built by Ranch.luau and replaced when the ranch or its eggs change: reach them through CollectionService signals, never keep a reference.
- Eggs (decision 0036): the animal is rolled at purchase and kept in the save; the client only ever gets `StationProgress.public`. Nothing starts hatching or opens by itself: `start` and `crack` are asked for by the player. Prompts act on the client (`ProximityPromptService.PromptTriggered` in the HUD), which checks the ranch is the player's own; a prompt must stay enabled on the server or its trigger is dropped.
- Ranch upgrades (decision 0034) are data in `StationConfig.UPGRADES`; `StationProgress.value` is the only place their effect is read. A save is never cut down to fit an upgrade level.
- Ranch.luau's layout numbers are written for a 120-stud plot and stretched by `World.RANCH_HALF / 60`; paths and the scenery outside the fence use real plot coordinates. Anything else placed on a ranch (the showcase lanes, the Studio test pad) must follow the plot's size the same way.
- A mountain's close-up detail (foothills, pines, ledges) is built only on the side given as `toward`. Sign text uses `Props.label`'s inset so posts never cover it.
- Ranch.luau builds from three numbers and a fixed seed, so the same levels always give the same ranch, and a higher level only adds to the scattered scenery. Keep creatures and anything else that must survive an upgrade out of the plot's `Built` folder. A ranch's `Owner` attribute is the UserId or 0.
- Ranches lie behind the hub's mountains (`World.RANCH_DIST`), south, east and west; the north is the wave arena. Each is reached by teleport or on foot up its pass (`pass` in World.luau: a road, a ramp of parts, mountains and walls down both sides). Terrain lands on 4-stud steps: the island cylinder tops at 18 so the surface is `World.RANCH_Y` = 22 (measured); the hub block tops at -2 for a surface at 0.
- Every area is closed: mountains (rock domes) with an invisible `Barrier` wall in front. The hub's wall is at `World.HUB_RADIUS` and opens only into the arena canyon and the three passes; keep new hub content inside it.
- A hatched animal's `stats` are exactly its version's numbers; what varies is `trained`, the stat levels (base 1 to `BASE_MAX` on hatch, jackpot `MAX_LEVEL`).
- The SpawnLocation is placed in code (`World.SPAWN`, the hub fallback); Rojo ignores `Position` in the project file. Owners are moved to their ranch after spawning.
- The enemies of the waves are the Hexbound (decision 0040), `StationConfig.FOES`, never animals: a foe is not in `SPECIES`, never hatched, owned or saved (`sanitize` and `hatch` look only at species). `StationConfig.foe` and the `StationRules.role` and `BattleRules.fighter` lookups are the only places that know both. Only `LevelRules.enemies` builds them.
- A foe's model, size and tint are in its `StationConfig.FOES` entry; `Creatures.spawnFoe` and `Creatures.foeSize` read them. Models for two-legged foes carry a `Biped` attribute (the client uses the biped poses), the dragon `Winged`; set in `Creatures.build` from the asset name, so a new foe model named `foe_<kind>` needs a kind added to `FOE_KINDS`, a pose set if it is not four-legged, and an entry in the foe tests.
- Real wave fights (decision 0043): the `wave` action in `StationsServer` decides with `LevelRules.fight`, pays with `StationProgress.clear`, then `WaveShow.run` replays it; one fight in the arena at a time (`WaveShow.active`), and `readyAt` keeps a player from starting the next one before this one's fight time is up. `WaveShow.run` calls its `report` exactly once (at the end or when cleared). The wave gate is a prompt tagged `WaveGate` (World.luau); the client opens the wave list.
- The HUD (decision 0044) is `stations-client/Hud.client.luau` over `Style.luau` (colours, cards, chips, buttons, sheets) and `Portrait.luau` (a picture frame of a model; the server publishes the models in `ReplicatedStorage.Portraits`). Lay everything out in design units inside the scaled root; make buttons at least 44 units tall; give cards a fixed size and let them wrap. Set a player's `UiSize` (Vector2) and `UiOpen` (a sheet's name) attributes to look at a phone or tablet layout on a desktop.
- The arena (decisions 0045 to 0047): `ArenaKit.luau` holds the shared palette and parts (`demonHead`, `column`); `Breach.luau` builds the road and the great portal ring behind the gate; `Arena.luau` builds the whole pit, walls, gatehouse, dais dressing, statues and the Hexbound's gate (a portal tagged "ArenaGate"); `World.luau` makes the dais's stand (tagged "WaveStand") at `Arena.DAIS_AT`; `stations-client/ArenaMood.client.luau` fades the local light to dusk inside the canyon; `WaveShow.run` stands the teams on them, walks the enemies out of the gate and sets the player's `CamFocus` and `CamRadius` attributes, which `stations-client/ArenaCamera.client.luau` frames the camera from until `WaveShow.clear` removes them.
- `WaveShow.luau` replays `BattleRules.battle`'s log in the arena; it never decides a result or touches a profile. Creatures that fight carry `Side`, `Hp` and `MaxHp` attributes; the client draws their health bars and damage numbers from those.
- Animals look dangerous, not cute, and big animals are big (decision 0033). Their models are built in Blender (`tools/blender/stations`), uploaded only by the Upload Blender assets workflow, and listed in the generated `src/shared/StationAssets.luau` (never edit it by hand; a spec keeps it in step with the manifest).
- A model's size is its built size. Its `Scale` attribute is its leg length over the length the client's poses were written for; poses, effects and walk speed all use it. Move a walking creature at `Creatures.speed` or its feet slide.
- Animation runs on each client from the model's attributes; the server never poses a joint. The herd at the end of the server script shows the owner's first eight animals wandering the roaming area; `Creatures.asset` names the model for a species or variant.
- The admin menu (decision 0038) only shows models. `isAdmin` on the server (the owning user, or Studio) guards every `look` action; the hidden button is not the protection. Keep anything that changes a save out of it.
- Every creature model must be passed to `describe` on the server (species, variant, six stats as attributes): the card under the cursor (decision 0039) reads only those, and finds the model by its unseen `Hit` box (tag `CreatureHit`). A model's `Hp` attribute, once fights set it, drives the health bar.
- Max Players must be 3 (= `World.RANCHES`). A place file cannot carry it: set it in Game Settings when publishing.
- Fight presentation (decision 0048, display only): `WaveShow` sets `HitPower`, `HitDmg`, `HitAt` on a struck model and `StopAt` / `StopFor` on a melee attacker, and makes archers' arrows and mages' bolts (in the player's show folder); `Creatures.client` turns them into sparks, a shock disc, a flinch and a hit-stop, `ArenaCamera` into a FOV punch. Timings and curves are `src/shared/FightFx.luau`. Read these attributes tolerantly (they arrive in any order) and never let one decide or delay a result.
