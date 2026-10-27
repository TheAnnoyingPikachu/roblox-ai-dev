# Hundred Demon Night: Blender asset plan

Owner request (2026-10-27): replace every visual asset in Night with custom models made in
Blender. This plan lists each asset, where it comes from today, its target size and polygon
budget. Scripts live in `tools/blender/night/`; outputs go to `build/blender/night/` (not
committed). Uploading and wiring the IDs into the code is a later step (needs an upload
credential and register rows, CLAUDE.md rule 9). No game code changes in this step.

## Conventions (all assets)

- 1 Blender unit = 1 stud. Modelled facing Blender +Y, exported with forward -Z / up Y, so the
  front faces Roblox -Z (same as the current meshes, which the code spawns with yaw 180 to face
  the courtyard).
- Origin at the base centre, lowest point at y = 0. Roblox recentres a MeshPart on its bounding
  box anyway, and `Models.spawn` already places by the bottom face, so nothing sinks.
- One baked 1024 PNG per asset (colour x baked AO, plus emission), one material, smart UV.
- Multi-part assets (enemies whose code moves pieces, weapons with a tinted blade) export several
  mesh objects in one FBX sharing the one texture.
- Palette (from `src/night/Arena.luau` 22-29 and `src/night/Enemies.luau` 149-153): ink
  (22,18,26), vermilion (196,40,28), wood (110,70,45), slate (88,86,96), stone (150,148,140),
  purple neon (170,60,255), warm lantern (255,170,90), paper (245,232,200), lacquer (120,22,26),
  gold (220,175,60), ember (255,60,40), rope (214,190,120), roof blue-grey (46,50,70),
  wisp blue (90,160,255)/(200,235,255), sakura pink (255,183,210).
- Style: stylised and chunky, bevelled edges, readable silhouettes at phone distance, warm
  lantern reds/oranges against cool night blues. Glowing bits (eyes, lantern paper, neon) are
  baked bright; code keeps its PointLights. Where code needs real Neon (gate neon strips, blade)
  that piece is a separate mesh so it can be set to Neon or tinted.

## Budgets

Props 500-3k tris, landmarks up to 9k, hero/boss 5-10k. Repeated props (forest, wall) are lower.

## Assets

| # | Asset | Replaces (current source) | Target size (studs, W x H x D) | Tris budget | Style notes | Priority |
|---|---|---|---|---|---|---|
| 1 | `shrine_hall` | Generated `shrineHall` mesh (`src/relay/Models.luau` 60-64), spawned at x1.3 in `src/night/Arena.luau` 347-374 (part fallback 351-370) | 40 x 39 x 42 | 9k | Hip-and-gable roof with upturned eaves, vermilion pillars, dark wood walls, stone steps, gold ridge ornaments, shimenawa over the door | P1 |
| 2 | `kagura_stage` | Parts in `Arena.luau` 251-315 (deck, ramps, pillars, roof, rope, shide) | 52 x 23 x 52 (incl. ramps) | 6k | Plank deck on ink skirt, four ramps, red pillars, gabled slate roof, rope and shide front and back. Keep invisible collision parts for the deck and ramps | P1 |
| 3 | `demon_gate` | Parts in `Arena.luau` 587-613 (x4 at the gates) | 19 x 15.5 x 2 | 2k | Black torii, cracked, purple glow strips; neon strips as separate `glow` mesh; portal disc and particles stay parts | P1 |
| 4 | `entrance_torii` | `Props.torii` (`src/relay/Props.luau` 105-149) called from `Arena.luau` 635 | 24 x 17.5 x 2.4 | 2k | Vermilion torii, black kasagi with upswept ends, stone footings; plaque text stays a SurfaceGui part | P1 |
| 5 | `stone_lantern` | `Props.lantern` (`Props.luau` 152-168), used at `Arena.luau` 639 and 670-687 (16 on the rim) | 3 x 6 x 3 | 1k | Kasuga toro: hex base, post, firebox with glowing windows, curled roof, jewel top | P1 |
| 6 | `sacred_tree` | Generated `sacredTree` (`Models.luau` 55-59), `Arena.luau` 376-426 (rope and shide 397-414) | 44 x 49 x 44 | 9k | Thick twisted camphor trunk, roots, clustered canopy, shimenawa rope and shide in the mesh | P1 |
| 7 | `oni_statue` | Generated `oni` (`Models.luau` 13-17), pit guardians `Arena.luau` 341-344 and the Oni General body `src/night/Enemies.luau` 367-412 | 15 x 19 x 13 | 8k | Crouching red oni on a plinth, horns, club, tiger-skin loincloth, glowing eyes | P1 |
| 8 | `komainu` | Generated `komainu` (`Models.luau` 38-42), `Arena.luau` 638 | 4.6 x 8 x 6.4 | 3k | Seated stone lion-dog, curly mane, on a low plinth | P1 |
| 9 | `lantern_yokai` | Generated `lanternYokai` (`Models.luau` 65-69), `Enemies.luau` 210-243 (part fallback) | 3.5 x 5.3 x 4.5 | 3k | Chochin-obake: ribbed paper lantern split into a grin, one big eye, long tongue, black caps | P1 |
| 10 | `kasa_obake` | Parts in `Enemies.luau` 246-302 | 5.6 x 5.4 x 5.6 | 2.5k | Red paper umbrella with ribs, one eye, tongue, single leg with geta sandal | P1 |
| 11 | `yoroi` | Parts in `Enemies.luau` 305-364 (enemy kind `oni`, Possessed Yoroi) | 6.5 x 7 x 3.5 | 4k | Hovering empty samurai armour, layered lacquer plates, kabuto with gold horns, red glow inside | P1 |
| 12 | `wisp` | Parts in `Enemies.luau` 170-207; idle wisp `Arena.luau` 615-631; spirit flame `src/night-client/CombatFx.client.luau` 1104 | 3 x 4.5 x 3 | 1.6k | Hitodama teardrop flame with a curled tail, blue-white. Fire, trail and light stay | P1 |
| 13 | `boss_skull` | Generated `bossSkull` (`Models.luau` 45-49), `Enemies.luau` 513-548 | 17 x 24 x 23 | 10k | Huge cracked Gashadokuro skull, deep sockets glowing red, jagged teeth | P1 |
| 14 | `boss_hand` | Generated `boneHand` (`Models.luau` 50-54), `Enemies.luau` 537-548 (used twice) | 10 x 16 x 4 | 6k | Skeletal open hand with long claws, bone white, wrist stump | P1 |
| 15 | `festival_stall` | Parts in `Arena.luau` 508-581 (x5) | 12 x 10 x 9.2 | 3k | Wooden counter, posts, striped awning, crates, goods; three texture variants (red, indigo, white) on one mesh. Sign text stays a SurfaceGui part | P2 |
| 16 | `paper_lantern` | `paperLantern` parts `Arena.luau` 126-133 (stage, hall, stalls, board) | 1.8 x 3 x 1.8 | 600 | Ribbed chochin with black caps and a hanging cord | P2 |
| 17 | `arched_bridge` | `bridge` parts `Arena.luau` 430-457 (x2) | 31 x 5 x 6.6 | 2.5k | Red taiko-bashi arch, plank deck, rails with giboshi caps | P2 |
| 18 | `sakura_tree` | Generated `sakura` (`Models.luau` 33-37, shared with Relay), `Arena.luau` 732-745 (x12) | 16 x 16 x 16 | 5k | Gnarled dark trunk, puffy pink blossom clusters | P2 |
| 19 | `leaderboard_frame` | Parts `Arena.luau` 641-667 | 2 x 16 x 19 | 1.5k | Ink notice board (kokuban) with red posts and roof; the text face stays a part with the SurfaceGui | P2 |
| 20 | `taiko_drum` | Part `Arena.luau` 306-314 | 3.4 x 4 x 3.4 | 1k | Barrel drum with tacks on a wooden stand | P2 |
| 21 | `wall_segment` | Wall and fence parts `Arena.luau` 224-246 (42 segments) | 13.6 x 8.6 x 2.4 | 600 | Stone wall with slate cap and wooden fence on top | P2 |
| 22 | `katana`, `kodachi`, `nodachi` | Tool parts `src/night/Gear.luau` 19-23, 76-129 | blade 4.2 / 2.6 / 6, grip 1.4 / 1 / 2 | 800 each | Wrapped grip, gold tsuba, curved blade as a separate `blade` mesh that keeps the Blade Art tint and trail attachments | P2 |
| 23 | `cedar_tree` | Forest parts `Arena.luau` 747-775 (x140) | 11 x 26 x 11 | 400 | Low-poly stacked cedar cones; very low budget because of the count | P3 |
| 24 | `mask_kitsune`, `mask_tengu`, `mask_oni`, `mask_eclipse`, `mask_okame`, `mask_hannya` | Mask parts `Gear.luau` 134-235 | 1.3 x 1.6 x 1.2 (face; horns and ears extra) | 3k each | Sculpted face shells (brow, cheekbones, nose, carved eye holes), horns/ears/teeth and side ties, in each cosmetic's colours (`src/shared/NightProgress.luau` 80-86) | P3 |
| 25 | `slash_arc`, `demon_wing` | VFX parts `CombatFx.client.luau` 144-178 (slash), 1218-1233 (Trigger wings) | arc 8 x 0.2 x 8; wing 0.3 x 3.5 x 3 | arc 300, wing 900 | White untextured shapes the code tints; crescent with taper, bat wing with arm and finger bones and a scalloped membrane | P3 |
| 26 | `koi` | Parts `Arena.luau` 478-490 | 0.6 x 0.3 x 1.6 | 500 | Small koi, orange/white | P3 |

## Kept as parts or effects (not worth a mesh)

- Courtyard disc, cobble paths, terrain, pond water, mountains (`Arena.luau` 193-222).
- Boss pit decals and neon cracks (`Arena.luau` 319-340), lantern-string bulbs and beams (690-728),
  moon (777-781), fog, fireflies, petals, confetti.
- Combat VFX that are spheres, rings and sparks (`CombatFx.client.luau` 179-214, 1025-1050).
- Pond rim stones and stepping stones (`Arena.luau` 461-476): could reuse `stone_lantern` style
  later; low value.
- Pickups: Night has none today (souls and XP are paid as rewards, `src/night/Profiles.luau` 252-273).

## Risks and open points

- Fact: the FBX is exported at 1 unit = 1 stud. Assumption: the Roblox importer is set to
  "studs" scale; either way `Models.luau` sets `Size` explicitly from the manifest.
- Fact: a textured MeshPart ignores `Color`. Masks and blades that the code tints per cosmetic
  either ship one texture per variant (masks) or keep the tinted piece untextured (blade, VFX).
- The stage and bridges are walked on: keep the current invisible collision parts and set the
  meshes `CanCollide = false`, or use `CollisionFidelity = PreciseConvexDecomposition`.
