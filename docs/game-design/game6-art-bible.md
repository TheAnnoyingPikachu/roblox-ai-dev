# Lantern Express: art bible (v0.1)

Author: Art Director. Date: 2026-11-06. Branch `game6/style`. Companion to `game6-gdd.md` (section M, "Look") and `docs/architecture/lantern.md` section 9 (asset names, sizes, pivots). The tools are `tools/blender/lantern/` (README there). The style test is section 10.

## 1. The look in one sentence

A toy steam train with a glowing brass lamp rolls through a misty dusk valley of mushroom-roofed cottages, where round, soft critters carry paper lanterns and the fog is lilac, never black.

Mood words: cosy, spooky-cute, warm-against-cool, round, toy-like, hushed. The fantasy is ours: **lanterns against fog**. No guns, no Wild West, no zombies, no brainrot. The warm light is always the hero, and everything a player wants is lit.

What it must do (`game6-market-research.md`):
- **Its own look** at thumbnail size, so the game is not read as a Dead Rails reskin (M34, A4).
- **Spooky enough for a 16-year-old** in the trial (M38), yet at the **Mild** label for 5 to 8 year olds (M40, section 9 here).
- **Readable at 768 × 432 and as a 50 px icon:** one bright warm focal point, big shapes, two colour temperatures.

## 2. Palette

sRGB. Constants of the same names are in `tools/blender/lantern/kit.py`.

| Role | Name | RGB | Hex | Use |
|---|---|---|---|---|
| Sky | Dusk Violet | 58, 44, 110 | `#3A2C6E` | zenith, night sky, deep shadows |
| Sky | Dusk Teal | 62, 128, 140 | `#3E808C` | sky band above the horizon, terrain shade |
| Sky | Horizon Peach | 246, 168, 140 | `#F6A88C` | thin warm band at the horizon (dusk only) |
| Fog | Fog Lilac | 190, 180, 210 | `#BEB4D2` | Atmosphere colour, the fog wall, distance |
| **Hero** | **Lantern Amber** | 255, 176, 64 | `#FFB040` | every lantern, the primary UI colour, the headlamp |
| Hero | Lamp Glow (Neon) | 255, 206, 110 | `#FFCE6E` | Neon headlamp lens and lamp glass |
| Hero | Window Glow (Neon) | 255, 196, 104 | `#FFC468` | lit windows, street lamps |
| Hero | Ember (Neon) | 255, 128, 48 | `#FF8030` | firebox, cab glow, ember accents |
| Village | Cosy Cream | 255, 238, 210 | `#FFEED2` | plaster walls, platform edge line, UI paper |
| Village | Brick | 178, 84, 66 | `#B25442` | plinths, chimneys, platform faces (baked brick bond) |
| Village | Timber | 128, 84, 60 | `#80543C` | frames, benches, beams |
| Village | Roof Plum | 128, 70, 116 | `#804674` | shingled roofs (scalloped) |
| Village | Door Teal | 56, 118, 128 | `#387680` | doors, shutters: the cool note on warm walls |
| Train | Lamplight Red | 196, 52, 62 | `#C4343E` | the default livery (GDD H6 `classic`) |
| Train | Brass | 196, 134, 56 → 255, 214, 128 | gradient | bands, rims, lamp body, buffers |
| Train | Iron Plum | 64, 56, 90 → 132, 118, 164 | gradient | smokebox, chimney, frames (never pure black) |
| Critter | Periwinkle | 148, 164, 250 | `#94A4FA` | Ember Kit fur (the mascot) |

**Rules**
- **Two temperatures.** Everything is cool (teal, violet, lilac, plum) except light and its sources (amber, ember, cream, brass, red). The brightest pixel in any shot is a lantern.
- **No pure black or pure white surfaces.** Iron is plum, shadows are violet, white is cream. The only near-white is Neon glass and the moon.
- **Critters** keep the Garden HD family's pastel saturation, shifted to dusk (periwinkle, lilac, moss, apricot, moon silver). Each gets one warm accent: a lantern, an ember tip or a candle stub.
- **Rarity colours** are GDD C7, unchanged. UI and crate glows use them only for rarity.

## 3. Lighting plan (Roblox)

These are starting values for the look review. They are applied on the client, so phases can tween (LANTERN-007). The style-test render (section 10) stands in for them in Blender.

**Lighting:** `Technology = Future`, `GlobalShadows = true`, `ShadowSoftness = 0.4`, `EnvironmentDiffuseScale = 0.5`, `EnvironmentSpecularScale = 0.4`.

| Phase | ClockTime | Brightness | Ambient | OutdoorAmbient | ColorShift_Top |
|---|---|---|---|---|---|
| Depot and stops (dusk) | 18.4 | 1.6 | 44, 38, 74 | 110, 100, 150 | 255, 190, 150 |
| Ride into night (tween over the 700 studs after stop 3) | 18.4 → 0.5 | 1.6 → 0.6 | | | |
| Night | 0.5 | 0.6 | 34, 30, 64 | 64, 60, 110 | 150, 150, 255 |
| Dawn Station | 6.2 | 2.0 | 60, 52, 80 | 150, 130, 150 | 255, 210, 170 |

**Atmosphere (the fog):** `Color = Fog Lilac`, `Decay = (96, 84, 150)`, `Density = 0.42`, `Offset = 0.25`, `Glare = 0.3`, `Haze = 1.8` at dusk. This gives about 250 studs of view (GDD world, the performance budget). At night use `Density 0.5`, `Color (120, 112, 170)`, `Decay (40, 36, 80)`.

**The fog wall at stops** is client-drawn (GDD L). It is a soft lilac bank about 20 studs tall that rolls in towards the platform:
- layered transparent parts with smoke `ParticleEmitter`s (Fog Lilac, `LightEmission 0.3`, so it glows faintly instead of reading as murk);
- a brighter leading edge with a few drifting sparkles;
- no dark core.

**Sky:**
- a 6-face skybox drawn with Pillow from the section 2 ramp (horizon peach, teal band, violet zenith; one register row);
- the moon at `MoonAngularSize 14`;
- `StarCount 1500` at night, 0 at dusk.

**Post effects:**
- `Bloom`: Intensity 0.6, Size 24, Threshold 0.92. Neon lamps bloom; cream walls do not.
- `ColorCorrection`: Saturation 0.08, Contrast 0.05, Tint (255, 246, 240).
- `DepthOfField`: off in play; in the start menu, FarIntensity 0.2.
- The GDD's "Calm night" setting halves the vignette and Bloom.

**Lantern glow: Neon or baked.**
- Props and vehicles carry their glass as separate `_glow` meshes that code sets to **Neon** in the manifest's `glow` colour. Examples are `train_engine_lamp_glow` and `house_cottage_glow`; `Models.luau` already leaves `_glow` meshes untextured.
- Critters stay one mesh. Their lanterns are **baked bright** (paint `emit`), and code hangs a `PointLight` in them (range 8, brightness 1.5, shadows off).

**Lights in game:**
- headlamp `SpotLight`: range 60, angle 50, brightness 3, Lamp Glow;
- cab `PointLight`: Ember, range 12;
- one `PointLight` per lit window cluster: range 12, brightness 1.2;
- street lamps: range 18;
- turret beams: a `SpotLight` plus a `Beam` in the player's lamp colour (GDD H6).

**Budget:** at most 24 dynamic lights inside the fog, with shadows only on the headlamp. The rest is Neon, which Bloom lights for free.

## 4. Shape language

- **Round and chunky.** Domes, drums, barrels, beans. Edges are bevelled or rounded. The only points are ear tips, chimney crowns and roof finials. Nothing is spiky.
- **Toy proportions.** Big heads and small bodies on critters (Garden HD). Big wheels, tall flared chimneys and oversized lamps on trains. Roofs are about 40% of a house's height.
- **The train** is a chunky toy 4-4-0:
  - a tall flared chimney with a brass crown;
  - a big brass box headlamp set on the smokebox;
  - a red boiler with brass bands and a plum-iron smokebox with a brass ring;
  - an open cab whose spectacles glow with firelight;
  - a tender heaped with coal.
  
  Cars share the 8-stud width, the red-and-brass livery and the plum roofs. **No faces on the train**: the smokebox has a door, a ring and a handle, nothing that reads as eyes.
- **Houses** are round drums of cream plaster on brick plinths, under domed, scalloped, plum shingle roofs (the mushroom-cottage silhouette). Round windows have timber crosses and flower boxes; doors are round-topped. Every house shows at least two lit windows towards the track.
- **Critters** belong to the same family as the Egg Garden HD creatures (`tools/blender/garden/README.md`, "Creature standard"):
  - one fused body and the shared face (glossy eyes with two catchlights, blush);
  - nocturnal palette and one lantern-themed prop or accent each (GDD H4 looks);
  - accessories are small, round and coloured: a cap, a scarf, a walnut-shell hat.
- **Wisps and the Lampeater:** see section 9.

## 5. Materials

- **Meshes** are Blender bakes: one 1024 full-RGB texture with 192-sample AO and a baked top light (`finalize=k.HD`). Use `SmoothPlastic` (Reflectance 0) on textured MeshParts for the soft toy look, and `Neon` on `_glow` meshes.
- **Surface detail** lives in the texture:
  - baked brick bond (`k.brick`): bricks 1 × 0.5 studs, darker at the ground;
  - plank bands and wood grain;
  - plaster grain under 5%;
  - coal flecks.
  
  Keep texture noise low: at 250 studs of fog, detail is read from silhouette and colour, not grain.
- **Terrain:**
  - `Grass` tinted (70, 104, 96), a dusk moss green;
  - `Ground` (104, 84, 92) for paths;
  - `Mud` for track beds;
  - rail ballast from `rail_32`.
  
  No bright Garden greens: the valley is in shade.
- **Liveries** (GDD H6) are **texture swaps** of the same `train_engine` and car meshes. Roblox ignores `Color` on textured MeshParts, so each livery is a re-bake of the same geometry with a palette swap. This keeps identical UVs, because `smart_project` is deterministic for identical geometry; LANTERN-008 must verify it. The result is one PNG per livery per car and one register row each.

## 6. Scale rules (studs)

| Thing | Size | Source |
|---|---|---|
| Player | 5 tall, 2 wide (R15) | Roblox |
| Train width | 8 (cars and engine) | architecture 9 |
| Engine with tender | 22 × 11 × 8; cab floor 2.3; chimney top 11 | architecture 9; `train.py` |
| Cars | cargo 16 × 7 × 8, lamp 16 × 9 × 8, passenger 18 × 10 × 8 | architecture 9 |
| Car and cab floors | 2.3 above the rail top | `train.py` |
| Platform top | 2.0 (`depot_platform` 40 × 2 × 10): a 0.3 step up into the car, never a jump | architecture 9 |
| Critter crate | 3.6 × 3 × 2.6, carried end-on by two players in line | architecture 9 |
| Gaps a carried crate passes through (gates, arches between buildings) | at least 6 wide and 7 tall | crate 2.6 wide + two shoulders' clearance |
| Paths between buildings on a tile | at least 8 wide (a crate pair passes a single player) | |
| Decorative house doors (not entered) | about 3.4 × 5.8; nothing on a tile is entered | `tiles.py` |
| Stop tile | 120 × 160 footprint, houses 14 to 20 tall, tile height up to 40 (48 for lighthouse and windmill) | architecture 9 |
| Critters | 2.0 (commons) to 3.5 (Moon Hare) tall, footprint within 3 × 3 | architecture 9 |
| Ember Kit | 2.9 tall (2.89 × 2.9 × 2.74) | `critters.py` |
| Wisps | 2.5 across; the Lampeater has a 40-stud wingspan | architecture 9, GDD E4 |

## 7. UI tie-in

The GDD generalises `UiKit` with an injected theme. Lantern's theme uses the Garden token names (`src/garden-client/ClientState.luau` `UI`), so the kit code does not change:

| Token | Lantern value | Meaning |
|---|---|---|
| `CREAM` | 255, 243, 222 | ticket-paper panel background |
| `PANEL` | 250, 234, 206 | panel body |
| `CARD` | 255, 250, 240 | cards |
| `INK` | 52, 40, 78 | night-plum text |
| `INK_SOFT` | 100, 86, 120 | secondary text |
| `MUTED` | 128, 112, 140 | disabled text |
| `GOLD` | 255, 176, 64 | **primary buttons, the lantern meter**, Tickets pill |
| `RING` | 255, 226, 150 | amber core: level ring, highlights |
| `CORAL` / `BADGE` | 196, 52, 62 | Lamplight Red: the fog bell chip, badges, danger |
| `AQUA` | 62, 128, 140 | Dusk Teal: secondary buttons, Lake Line |
| `MINT` | 120, 170, 110 | moss: common, Forest Line |
| `LEAF` | 84, 140, 96 | success |
| `SKY` | 90, 160, 230 | lake blue: uncommon |
| `LILAC` | 170, 120, 230 | lantern violet: rare |
| `PINK` | 255, 150, 170 | rose: login track |
| `GREY` | 200, 192, 205 | inactive |
| `WHITE` | 255, 255, 255 | |
| `SHADOW` | 30, 22, 48 | drop shadow at 0.7 transparency |
| `GLASS` | 0.35 | HUD chips: **`INK` at this transparency (dark glass)**, cream text. The theme needs a chip-colour token (`CHIP = INK`), because the Garden kit draws white glass |

**Font:** `FredokaOne` everywhere (the studio kit). The logo "LANTERN EXPRESS" is `LuckiestGuy` in cream with an amber outline and a small lantern for the "O". Cream on dark glass over the dusk world reads at 12 px on an 844 × 390 phone; amber is never used for body text.

## 8. Thumbnail and icon

**Thumbnail** (1920 × 1080, uploaded at 768 × 432 or larger; it shows real game art, M34):
- **Layout:** the mascot in the left third, close to the camera; the engine's headlamp near the centre and the brightest point; a lit house on the right; the lilac fog wall and the moon behind.
- **Text:** none, or the logo small in a corner. The image carries the pitch.

`build/blender/lantern/style_test.png` is version A. Three versions go to Roblox's thumbnail personalisation test (M34):
- **A, Arrival:** the style test. Cosy, with a wide appeal.
- **B, Night:** four amber beams crossing over the train, with wisps' glowing eyes in the fog and the Lampeater's silhouette across the moon. The 16+ hook.
- **C, Fog sprint:** two avatars hauling a crate glowing in its rarity colour up the platform, with the fog wall at their heels. The clip moment (GDD).

**Icon** (512 × 512, must read at 50 px):
- the Ember Kit's face, three-quarter view, with its red cap;
- the lantern glowing beside its cheek;
- a teal-to-violet gradient behind and a thin amber rim.

No text. At 50 px, three shapes must survive: two eyes, the red cap and the amber dot.

## 9. What "Mild" means on screen (M40; GDD G, rule 8)

- **Wisps** (`shadow_wisp`):
  - soft round puffs of deep indigo (never black) with a lilac rim light;
  - two round glowing eyes in amber or pale lilac, with a catchlight;
  - **no mouth, or a tiny "o"; no teeth, no claws, no red eyes**;
  - they drift, wobble and swell; caught in a beam they pop into pastel sparkles with a chime, never a burst or splatter.
- **The Lampeater:**
  - a soft, majestic moth in the family of Garden's Lantern Moth (`creature_moth`): fluffy cream ruff, round body, feathery antennae;
  - dusk-gradient wings (violet to pale lilac) with amber eye-spots;
  - round lantern-glass eyes, warm amber with catchlights;
  - **no mandibles, fangs, spikes, stingers or hooked claws**;
  - it swoops in arcs and never lunges at the camera; it purrs when fed. Scale and grace make it feel big, not teeth.
- **Fog:** lilac and softly glowing, never solid black. It never hides the player's own character, and being caught fades the screen to lilac, not black.
- **Night:** never pitch dark. Ambient keeps silhouettes readable, and the train is always the brightest thing in view.
- **Never:**
  - jump scares before the first Depot, and none unannounced after it (GDD);
  - full-screen faces;
  - camera shake above a gentle rumble;
  - blood, gore or red splatter;
  - skulls or graves;
  - human-like monsters.
  
  Red appears only on the train, the fog bell and badges.
- **The test:** each night asset is shown to the look review beside a Garden creature. If it would look out of place in Egg Garden's family, it is too scary.

## 10. Style test (2026-11-06)

**The three hero assets, at the HD standard, built by `tools/blender/lantern/build.py`:**

| Asset | Size (x, h, d) | Tris | Meshes |
|---|---|---|---|
| `train_engine` | 8.14 × 10.98 × 22.28 | 10,804 / 12,000 | body, `_lamp_glow`, `_fire_glow` |
| `critter_emberkit` | 2.89 × 2.9 × 2.74 | 5,380 / 6,000 | one |
| `house_cottage` | 20.6 × 16.56 × 19.99 | 9,602 / 10,000 | body, `_glow` |

**Render:** `build/blender/lantern/style_test.png`. It is a dusk scene from the exported files:
- Cycles, with a volume fog bank and a thin ground fog;
- Bloom (compositor Glare);
- a warm key light and a cool rim light;
- a light at every glow island, plus the headlamp SpotLight.

**Verdict:** yes, it stops the scroll for a cosy co-op audience. It has a single bright focal point (the headlamp), a mascot face the size of the frame's lower third, and a palette no live train game uses. It is calm; the 16+ hook comes from thumbnail B.

**Changed during the test:**
- **Plum roofs, not teal:** teal roofs vanished into the teal sky.
- **Periwinkle fur saturated:** grey-purple sank into the dusk.
- **Ember Kit markings painted, not modelled:** the chest patch and tail tip are paint marks, because separate pieces cut ragged edges through the decimated body.
- **Smokebox door plate removed:** it made the engine read as a face.
- **Resized to the architecture contract:** the engine was rebuilt from 12 to 8 wide with a tender and an open cab, and the critter scaled to the 3 × 3 footprint.

**Open for the look review:**
- **The house is too heavy for its tile.** At 9,602 tris it is over the share a house can take of `stop_village`'s 15,000 (3 to 5 buildings). Either LANTERN-009 uses it as the tile's one hero house with simpler siblings (about 2,000 each, without a platform), or the tile budget rises to 20,000.
- **Shingle notches look like stars.** The scalloped roof tiers show small star-shaped notches. They read as a charming "starry roof" at distance, but can be softened.
- **The wheels do not turn,** as the GDD allows. Spinning wheels need the wheel sets as separate meshes, a code change, and LANTERN-008 to decide.
