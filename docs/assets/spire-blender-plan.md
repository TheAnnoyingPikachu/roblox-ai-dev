# Neon Spire: Blender asset plan

Owner request (2026-10-27): custom Blender models for Neon Spire, made the same way as the
Hundred Demon Night set (`docs/assets/night-blender-plan.md`). Task `studio/tasks/SPIRE-012.json`.
Scripts in `tools/blender/spire/`, exports in `assets/spire/`, upload with the
**Upload Blender assets** workflow (`game: spire`), ids in `src/shared/SpireAssets.luau`.

## Conventions

- Facts: 1 unit = 1 stud, front faces Roblox -Z, origin at the base centre (lowest point y = 0),
  one baked 1024 colour texture per asset, FBX uploads as a Model. Roblox's FBX importer brings
  models in about 100x too big, so `Models.luau` fits each model to the manifest height.
- Palette from the art bible section 2 (`src/spire-client/ClientState.luau` 494-505): asphalt
  `#0B0F1A`, wet steel `#1C2333`, smog violet, and the neon accents cyan, magenta, violet, amber,
  lime, coral, ice, signal white.
- Neon: every glowing piece is a separate `<asset>_glow` mesh (`_glow2`, `_glow3` for more
  colours). It stays untextured; the loader sets it to `Neon` in the manifest colour so Bloom makes
  it glow, and code may recolour it (department colour, brand trim, L5 amber). Screens and small
  lights that do not need bloom are baked bright into the texture.
- Budgets (phone first): props 200-3k tris, hero pieces (crest, idol) up to 8k. Repeated pieces
  are cheap: `viaduct_segment` x48 is 118 tris, `lift_ring` (one per floor) under 700.
- Wiring: an asset whose model id is nil returns nil from `Models.spire` / `Kit.model`, and the
  caller builds exactly what it builds today.

## Assets (36 built, 41302 tris in all)

Sizes are the measured Roblox size (x, y, z) from `tools/blender/spire/manifest.json`; tris are
built / budget. Glow lists the neon meshes. Source lines in this table are as of commit 3921f57,
before the wiring commit added the model calls next to them.

| # | Asset | Replaces (current source) | Size (studs) | Tris | Glow | Priority |
|---|---|---|---|---|---|---|
| 1 | `server_rack` | Data Farm module (Server Rack): src/spire-client/TowerView.client.luau 136-155 (module box per slot) | 5.6 x 6.16 x 5.6 | 1348 / 2500 | glow | P1 |
| 2 | `fusion_cell` | Fusion Core module (Fusion Cell): src/spire-client/TowerView.client.luau 136-155 (module box per slot) | 5.17 x 5.8 x 5.17 | 1094 / 2000 | glow | P1 |
| 3 | `holo_projector` | Holo Ad Agency module (Holo Projector): src/spire-client/TowerView.client.luau 136-155 (module box per slot) | 5 x 5.21 x 5 | 288 / 1500 | glow | P1 |
| 4 | `bio_printer` | Synth Lab module (Bio-Printer): src/spire-client/TowerView.client.luau 136-155 (module box per slot) | 5.6 x 5.2 x 5.6 | 756 / 2500 | glow | P1 |
| 5 | `drone_dock` | Drone Port module (Courier Drone): src/spire-client/TowerView.client.luau 136-155 (module box per slot) | 5.46 x 3.97 x 5.46 | 1302 / 2500 | glow | P1 |
| 6 | `q_mind` | Quantum Core module (Q-Mind): src/spire-client/TowerView.client.luau 136-155 (module box per slot) | 5.6 x 6 x 5.2 | 1214 / 2500 | glow | P1 |
| 7 | `uplink_dish` | Orbital Uplink module (Uplink Dish): src/spire-client/TowerView.client.luau 136-155 (module box per slot); art bible 10 #13 | 5.28 x 6.9 x 4.98 | 750 / 2500 | glow | P1 |
| 8 | `roof_antenna` | Roof antenna and beacon: src/spire-client/TowerView.client.luau 166-170 (art bible 5.4 default crown) | 6 x 22.6 x 6 | 1024 / 3000 | glow, glow2 | P1 |
| 9 | `lift_ring` | Lift ring per floor (TowerView.client.luau 114-123) and lobby lift pad (src/spire/Lots.luau 305-316) | 8 x 0.3 x 8 | 694 / 1200 | glow | P1 |
| 10 | `city_crest` | City crest rings (src/spire-client/City.client.luau 108-143, Kit.mesh hook cityCrest); art bible 10 #14 | 11.52 x 25.35 x 14.63 | 6598 / 8000 | glow, glow2, glow3 | P1 |
| 11 | `build_terminal` | BUILD terminal box (src/spire/Lots.luau 320-321); art bible 5.2 kiosk with a holo tower | 3 x 9.7 x 1.95 | 744 / 1500 | glow | P1 |
| 12 | `neon_bench` | Plaza item bench: greybox in src/spire-client/PlazaView.client.luau 38-56 | 3.3 x 2.21 x 1.47 | 1212 / 1500 | glow | P1 |
| 13 | `holo_palm` | Plaza item palm: greybox in PlazaView.client.luau 38-56 | 5.44 x 7.77 x 5.4 | 1614 / 2500 | glow | P1 |
| 14 | `street_lamp` | City lamps (src/spire-client/City.client.luau 62-68, 146-152, 258-260) and plaza item lamp (PlazaView 38-56) | 1.6 x 12.31 x 4.91 | 368 / 1200 | glow | P1 |
| 15 | `vending_bot` | City vending kiosks (City.client.luau 274-281) and plaza item vending (PlazaView 38-56); art bible 10 #4 | 4.62 x 5.2 x 2.39 | 1080 / 2500 | glow | P1 |
| 16 | `noodle_stall` | Plaza item noodle: greybox in src/spire-client/PlazaView.client.luau 38-56 (art bible 10 #5) | 7.7 x 8.1 x 4.1 | 1288 / 3000 | glow, glow2 | P1 |
| 17 | `arcade_kiosk` | Plaza item arcade: greybox in PlazaView.client.luau 38-56 (art bible 10 #6) | 7.92 x 7.75 x 7.92 | 1008 / 3000 | glow, glow2 | P1 |
| 18 | `holo_fountain` | Plaza item fountain: greybox in PlazaView.client.luau 38-56 | 7.4 x 5.7 x 7.4 | 1342 / 3000 | glow, glow2 | P1 |
| 19 | `maglev_stop` | Plaza item maglev: greybox in PlazaView.client.luau 38-56 | 11.4 x 7.27 x 7 | 848 / 3000 | glow, glow2 | P1 |
| 20 | `mega_billboard` | Plaza item billboard: greybox in PlazaView.client.luau 38-56 | 7.54 x 13.37 x 2.18 | 380 / 1500 | glow | P1 |
| 21 | `hologram_idol` | Plaza item idol: greybox in PlazaView.client.luau 38-56 (art bible 10 #7, abstract, not a real person) | 11.4 x 11.15 x 11.4 | 3970 / 6000 | glow, glow2 | P1 |
| 22 | `searchlight` | Searchlight housings (City.client.luau 182-184); the Beam stays | 3.56 x 3.71 x 3.56 | 724 / 1200 | glow | P2 |
| 23 | `viaduct_segment` | Maglev viaduct deck, glow strip and rail (City.client.luau 285-298), 48 copies | 10.4 x 2.9 x 29.2 | 118 / 600 | glow | P2 |
| 24 | `board_frame` | Board post (src/spire/City.luau 56) and client neon frame (City.client.luau 216-239) | 17.4 x 15.5 x 1.8 | 852 / 1200 | glow | P2 |
| 25 | `lot_sign` | Lot sign post and frame (src/spire/Lots.luau 334-345) | 8.8 x 7.53 x 1.4 | 576 / 600 | glow | P2 |
| 26 | `bollard` | City bollards (City.client.luau 261-265) and plaza item bollard | 0.86 x 1.84 x 0.88 | 214 / 400 | glow | P2 |
| 27 | `planter` | Plaza item planter: greybox in PlazaView.client.luau 38-56 | 3.38 x 2.81 x 3.38 | 568 / 2000 | glow | P2 |
| 28 | `neon_arrow` | Plaza item arrow: greybox in PlazaView.client.luau 38-56 | 3 x 3.45 x 0.9 | 280 / 600 | glow | P2 |
| 29 | `trash_bot` | Plaza item trashbot: greybox in PlazaView.client.luau 38-56 (art bible 10 #10) | 3.63 x 2.89 x 2.92 | 606 / 1500 | glow | P2 |
| 30 | `cable_arch` | Plaza item arch: greybox in PlazaView.client.luau 38-56 | 7.4 x 7.75 x 0.8 | 1192 / 1500 | glow, glow2 | P2 |
| 31 | `holo_koi` | Plaza item koi: greybox in PlazaView.client.luau 38-56 (art bible 10 #11) | 6.84 x 2.13 x 6.84 | 466 / 2000 | glow, glow2 | P2 |
| 32 | `courier_drone` | City drones (art bible 7, Traffic.client.luau, SPIRE-007, not built yet); art bible 10 #1 | 3.56 x 1.44 x 3.56 | 1004 / 1500 | glow | P3 |
| 33 | `hover_car` | Hover traffic car A (art bible 7, 10 #2) | 5.34 x 2.32 x 12 | 1552 / 4000 | glow, glow2 | P3 |
| 34 | `hover_taxi` | Hover traffic taxi B (art bible 7, 10 #3) | 5.72 x 4.83 x 13 | 1608 / 4000 | glow, glow2 | P3 |
| 35 | `maglev_car` | Maglev train on the viaduct (art bible 8, 10 #8), three cars per train | 4.1 x 3.87 x 20 | 852 / 3000 | glow | P3 |
| 36 | `blimp` | Advertising blimp at 380 studs (art bible 7, 10 #9) | 24 x 26.5 x 80.07 | 1768 / 6000 | glow, glow2 | P3 |

P1: tower kit, lobby terminal, crest and every Hype item. P2: decor and city furniture. P3:
vehicles; no traffic code exists yet (Traffic.client.luau, SPIRE-007), so they are built and
registered but not wired.

## Inventory: visuals that stay procedural

Assumption: these read well as parts (cyberpunk boxes, glass and neon strips, art bible 9 option A)
or change at runtime in ways a baked mesh cannot follow.

| Visual | Source | Why it stays parts |
|---|---|---|
| Tower floor shell: slab, glass walls, pillars, brand strip, signature band | `src/spire-client/TowerView.client.luau` 80-145 | Tinted per department and brand, walls fade in build mode, strip grows on the focused floor |
| Ghost floor, build grid, placement ghost | `TowerView.client.luau` 262-300, `src/spire-client/Build.client.luau` 783-810 | ForceField / transparent cells that resize per state |
| Hot Data spark and beam | `TowerView.client.luau` 390-440 | A neon octahedron and a beam; already minimal |
| Grid Plaza disc, neon rings, spokes, chevrons, puddles, steam vents | `src/spire-client/City.client.luau` 108-205 | Flat strips and glass discs over the server collision |
| Sign pylons with animated ads | `City.client.luau` 296-305 | The ads are SurfaceGuis on parts |
| Board faces, lot sign faces | `src/spire/City.luau` 54-80, `src/spire/Lots.luau` 186-200 | SurfaceGui text; the Blender frames go around them |
| Viaduct pillars, backdrop megacity (140 towers), roof blinkers, giant holo ads | `City.client.luau` 315-400 | Big cheap boxes with random sizes, fixed seed |
| Rain, splashes, searchlight beams, lighting | `src/spire-client/Atmos.client.luau`, `City.client.luau` 210-240 | Particles, Beams and post effects |
| Lift doors and floor picker | `src/spire-client/Lift.client.luau` | 2D UI; the 3D lift is the `lift_ring` model |
| Server lift pad | `src/spire/Lots.luau` 153-163 | Invisible-ish prompt holder; the client draws the lobby `lift_ring` |
| Crowns other than the antenna, facade skins | Art bible 5.4-5.5, SPIRE-009 | Not built in code yet |

## How the game uses them

- Server start: `Models.preloadSpire()` (`src/spire/SpireServer.server.luau`) loads every uploaded
  model with InsertService (the creator must own the experience), applies the texture, makes the
  glow meshes Neon, fits the manifest height and copies the template to
  `ReplicatedStorage.SpireModels`.
- Server: `Models.spire` places `board_frame` around the Top Spires and Market boards (the client
  then skips its neon frame, attribute `Framed`), `build_terminal` and `lot_sign` per lot; the old
  parts stay for prompts and SurfaceGuis.
- Client: `Kit.waitModels()` waits up to 15 s for uploaded templates, then `Kit.model` clones them
  (never yields, no collision, no queries) for modules (scaled 0.82 at L1 to 1.1 at L5, amber glow at
  L5), lift rings, roof antennas (beacon = `glow2`, brand trim), plaza items (`MODELS` in
  `PlazaView.client.luau`), lamps (`street_lamp`, pole 1.65 behind the centre), bollards,
  searchlights, the crest (spun), vending kiosks and viaduct decks.

## Upload notes

- After merge the Director runs the workflow with `game: spire`, copies the artifact's
  `uploaded.json` and `SpireAssets.luau` into the repo, fills the ids in `docs/assets/register.md`
  and opens a PR. Meshes take a few minutes to process after upload before LoadAsset works.
- Hypothesis to check in the first playtest: 180 lift rings (6 towers x 30 floors) at about 700
  tris each are fine on a phone; if not, draw the ring only on the owner's floor range.
