# Neon Spire: art bible (v0.1)

Status: draft for SHANNON (SPIRE-001). Companion to `game5-gdd.md` (section letters refer to it). The asset approach in section 9 is proposed in decision 0010 and needs SHANNON's approval before any asset is made.

## 1. The look in one sentence

A permanent rainy night in a dense vertical city, where every surface is dark and wet and every light source is a saturated neon colour reflected twice: once in the glass, once in the puddles.

Mood words: rain-noir, holographic, humming, vertical, busy, safe. It should feel exciting to stand in, never threatening: crowds carry umbrellas, drones deliver noodles, the billboards advertise silly products (Synth-Soda, Hover Socks, Byte-Size Snacks). No weapons, gangs, grime or broken people.

## 2. Palette

| Role | Name | Hex | Use |
|---|---|---|---|
| Base | Night Asphalt | `#0B0F1A` | ground, UI panel fill |
| Base | Wet Steel | `#1C2333` | building bodies, slabs |
| Base | Smog Violet | `#2A1B3D` | atmosphere, distant towers |
| Accent 1 | Grid Cyan | `#00F0FF` | primary UI, valid placement, Data Farm |
| Accent 2 | Hot Magenta | `#FF2A6D` | secondary UI, invalid placement, Ad Agency |
| Accent 3 | Volt Violet | `#7B2FFF` | Quantum Core, Shares, rare highlights |
| Accent 4 | Sodium Amber | `#FFB800` | warnings, Flash Sale, Fusion Core, level 5 gold |
| Accent 5 | Acid Lime | `#B6FF3B` | income, Data Boom, Synth Lab |
| Accent 6 | Signal White | `#E8F6FF` | text, window light |

Brand colours (company trim, GDD G): the six accents plus Coral `#FF6B4A` and Ice `#9FD8FF`. Every accent pair used on screen together must keep a contrast ratio of at least 3:1 against `#0B0F1A`.

Department colour code (used on facades, UI cards and icons): Data cyan, Fusion amber, Ad magenta, Synth lime, Drone coral, Quantum violet, Orbital white.

## 3. Lighting recipe (baseline "Normal")

All values are starting points to tune in the M2 look pass; the final values go into `src/spire-client/Atmos.client.luau` (client-applied so events can change them per client without server work).

- `Lighting.Technology = Future`, `ClockTime = 0.3`, `Brightness = 1.2`, `Ambient = (20, 18, 40)`, `OutdoorAmbient = (40, 36, 80)`, `EnvironmentDiffuseScale = 0.4`, `EnvironmentSpecularScale = 1`, `GlobalShadows = true`, `ShadowSoftness = 0.3`.
- `Atmosphere`: density 0.38, offset 0.15, colour `(60, 40, 110)`, decay `(20, 10, 40)`, glare 0.2, haze 2.2. This gives the purple distance fade that hides the map edge.
- `Bloom`: intensity 0.9, size 28, threshold 0.92 (Neon parts bloom, white text does not).
- `ColorCorrection`: contrast 0.12, saturation 0.18, tint `(235, 230, 255)`.
- `DepthOfField`: off in play; on in the start menu (far intensity 0.25, focus 60).
- `SunRays`: off. Sky: Roblox default sky with stars off, celestial bodies hidden; the smog and backdrop do the work.
- Point lights: each lit sign gets at most one `SurfaceLight` or `PointLight` (range ≤ 16). Budget: 60 dynamic lights within 200 studs of the camera; the rest are Neon material only (bloom gives the glow for free).

Events (GDD F), tweened over 3 s on each client:
- **Data Boom:** `ColorCorrection.tint (220, 255, 230)`, green data-rain particles.
- **Neon Night:** rain ×1.5, `Bloom.intensity 1.2`, city billboards run a synchronised colour sweep (UIGradient offset tween, ≤ 1 cycle per second).
- **Flash Sale:** amber holograms over Build terminals, amber tint on the Market board.

## 4. Materials and the wet look

- Ground and plaza: `SmoothPlastic` or `Concrete` in Night Asphalt, `Reflectance 0.15`. Puddle decals: thin `Glass` parts (0.05 thick) in `#0B0F1A`, `Reflectance 0.35`, `Transparency 0.2`, scattered 10 to 20 per plaza. Future lighting makes the neon read in them.
- Building bodies: `SmoothPlastic` Wet Steel; window bands `Glass` tinted by department at `Transparency 0.3`; trims `Neon`.
- Holograms: `ForceField` material or Neon at `Transparency 0.4` to 0.6 with a slow flicker (transparency tween at most 3 Hz, GDD I4.6).
- Metal props: `Metal` and `DiamondPlate` in Wet Steel.
- Avoid: `Grass`, `Wood`, bright `Plastic`, pastel colours. These break the night.

## 5. Tower kit (procedural, client-built)

The tower is generated from the lot's `State` (GDD O) by `src/spire-client/TowerView.client.luau` using shared layout maths (`TowerRules.floorY`, `slotOffset`). Every piece below is built from primitives.

### 5.1 Exterior grammar per floor (≤ 20 parts)

- Floor slab band: one 36 × 1 × 36 block, Wet Steel, with a 0.3-stud Neon strip on the front edge in the brand colour.
- Corner pillars: 4 tall thin blocks per floor, slightly proud of the facade (shadow line).
- Facade: 4 `Glass` panels (one per side), tinted by department, with the window rhythm below.
- Department signature (one or two parts):
  - Data Farm: vertical cyan light bars behind the glass (rack rows visible from outside).
  - Fusion Core: a glowing amber ring around the floor and heat-haze particles at the vents.
  - Ad Agency: a curved holo screen on the front face (SurfaceGui with an animated ad from a list of 12 silly products).
  - Synth Lab: lime tubes running diagonally.
  - Drone Port: an open landing deck jutting out on one side; drones launch from it (client).
  - Quantum Core: a violet floating orb visible through the glass, slow rotation.
  - Orbital Uplink: a white dish on an outrigger.
- Level 5 floors (all four modules at L5): the slab strip turns gold.
- Every 5th floor: a cantilevered balcony with a planter and a railing (2 parts) to break the silhouette.

### 5.2 Lobby

Double-height glass front with the company name in Neon letters (built from the glyph set), logo wall, Vault display (SurfaceGui income ticker), lift pads with cyan floor rings, BUILD terminal (a kiosk with a holographic tower above it), two planters, a reception desk with an idle receptionist bot (hero prop, optional).

### 5.3 Interiors (built only near the camera)

Each department has a 4-slot interior template: floor tiles, ceiling light strips, 4 module models at their slot offsets, cable trays. Module models are 6 to 15 parts each, with level details per GDD C4. Interiors are built for the owner's current floor ±2, in build mode for the selected floor ±1, and never for distant towers.

### 5.4 Crowns (cosmetic, GDD J)

Antenna (default), Halo Ring, Spire Needle, Holo Logo (the company glyph 20 studs tall), Satellite Crown. Each ≤ 25 parts, each with a slow beacon blink (0.5 Hz) for aircraft-light realism.

### 5.5 Facade skins (Shares, GDD H)

Chrome (silver slab, cyan glass), Carbon (matte black, magenta trim), Jade Glass (green tint, gold trim), Prism (glass hue cycles slowly through the brand colour family; obeys I4.6).

## 6. UI kit

- **Fonts** (Roblox built-ins; to verify in Studio): display `Sarpanch` Bold (titles, big numbers), body `TitilliumWeb` or `BuilderSans` SemiBold, numbers `RobotoMono` (so counters do not jitter).
- **Panels:** fill `#0B0F1A` at 12% transparency, `UICorner` 6 px, `UIStroke` 1.5 px Grid Cyan at 40% transparency, a 2 px top accent bar in the panel's department colour, faint scanline `UIGradient` (8% opacity).
- **Buttons:** primary = Grid Cyan fill with Night Asphalt text; secondary = outline; danger = Hot Magenta outline. States: hover +4% scale and stroke to 0% transparency; press 96% scale; disabled 40% opacity with the reason text below, never hidden.
- **Motion:** panels open with Quint-out 180 ms (scale 0.96 → 1, fade 0 → 1); toasts slide 220 ms; numbers count with a 400 ms ease; nothing above 400 ms blocks input.
- **Icons:** drawn with UI frames (circles, bars, chevrons) or a single uploaded icon sheet (one registered asset, decision 0010). Every icon has a text label.
- **Sounds:** every interactive element has hover (desktop) and press sounds; refusal buzz; purchase ka-ching (synth version); panel whoosh.
- **Safe areas:** use `ScreenGui.ScreenInsets = DeviceSafeInsets`; test at 16:9, 19.5:9 phone and 4:3 tablet.

## 7. VFX catalogue (client-side unless noted)

| Effect | Build | Budget |
|---|---|---|
| Rain | `ParticleEmitter` on a part that follows the camera (box 120 × 1 × 120 at +60 studs), streak texture from Roblox's built-in particle textures | rate 600 High / 350 Med / 150 Low |
| Rain splashes | emitter on the plaza ground near the camera | rate 80 |
| Steam vents | 3 per plaza, smoke texture `rbxasset://textures/particles/smoke_main.dds` (already registered) | rate 6 each |
| Data packets | `Beam` segments with a moving texture offset from busy floors down to the lobby | 1 beam per 3 floors |
| Construction sweep | wireframe of the new floor (thin Neon edges) scaling up, then panels fading in bottom to top | 1.2 s, then destroyed |
| Drones | small part models on Bezier paths around towers with Drone Ports; blinking lights | ≤ 24 in the city |
| Hover traffic | 3 lanes at heights 80, 140, 220 studs; cars are hero meshes with Neon tail lights; client-side tween along loops | ≤ 40 cars visible |
| Searchlights | 4 `Beam` cones sweeping from the Grid Plaza | 4 |
| Billboards | SurfaceGui ads with `UIGradient` animation | ≤ 30 in view |
| Blimp | hero mesh on a slow orbit at 380 studs with a SurfaceGui ad band | 1 |
| Hot Data spark | small Neon octahedron with sparkles and a vertical beam visible from the plaza | 1 per tower |

## 8. City and Grid Plaza

- **Layout:** Grid Plaza at the centre (radius 50): spawn, Market board, Top Spires board, Contracts kiosk, maglev station, a central holo-sculpture of the city crest. Six lots on a ring at radius 130, angles 0°, 60° … 300°, plazas facing the centre.
- **Streets:** a ring road between the plaza and the lots with crossings, street lamps, bollards and vending machines; ground-level traffic is cut (pedestrian city; hover-traffic is overhead).
- **Elevated maglev:** a ring viaduct at radius 210, height 40, with a train hero mesh looping every 90 s (client).
- **Backdrop megacity:** beyond radius 260, procedurally generated towers (fixed seed, built once on the client): 120 boxes, 150 to 650 studs tall, Wet Steel with window bands (Neon strips at random heights or one registered window texture, decision 0010), rooftop blinkers, a few giant holo ads. Atmosphere hides the far edge.
- **Part budget:** Grid Plaza ≤ 800, streets ≤ 1,500, backdrop ≤ 2,500 (boxes are big and cheap), each lot's exterior at 30 floors ≤ 700 plus plaza items ≤ 400.

## 9. Asset approach (decision 0010, needs SHANNON's approval)

| Option | What | Quality ceiling | Speed for the studio | Risks |
|---|---|---|---|---|
| A. Primitives and procedural (code-built parts, built-in materials, Neon, ForceField, particles) | Everything in sections 5, 7, 8 | Good: cyberpunk is unusually friendly to primitives (boxes, glass, glowing strips) | Fastest; fully reviewable in Git; no uploads | Can look flat on hero props (vehicles, creatures, statues) |
| B. Roblox AI mesh generation (as used in Relay, Night, Garden) | 10 to 14 hero props (section 10) | Good for props; style can drift | Fast; assets owned by SHANNON's account; studio has a working flow and register rows | Unreadable results (fallback to option A); needs SHANNON in Studio to run prompts |
| C. Blender (custom modular kit: facade panels, railings, signage, vehicles) | A matched kit with SurfaceAppearance PBR textures | Highest | Slowest; needs either SHANNON or a human artist in Blender, or headless Blender scripts plus an Open Cloud Assets upload key | New credential scope (rule 7: SHANNON's approval), large binary files, review is harder |
| D. Creator Store free models | Anything | Varies | Fast | Hidden scripts, unclear licences, mismatched style; studio rule 9 defaults against it |

**Recommendation:** A for all architecture, UI and effects, plus B for the hero props listed in section 10, with every mesh registered before use. Defer C: decide after the M2 look gate, only if the screenshot test fails on prop quality. Use D only for Roblox-owned or Roblox-licensed audio and Roblox-built content, as before.

## 10. Hero props (option B prompts)

Style suffix on every prompt: "stylised low-poly cyberpunk game asset, clean hard-surface shapes, dark gunmetal body with cyan and magenta neon light strips, friendly design, no text, no logos".

| # | Prop | Prompt | Size |
|---|---|---|---|
| 1 | Courier Drone | "small quadcopter delivery drone carrying a glowing parcel" | 3 studs |
| 2 | Hover Car A | "sleek two-seat hover car with no wheels and glowing underside" | 12 studs |
| 3 | Hover Car B | "chunky hover taxi with a roof light" | 13 studs |
| 4 | Vending Bot | "cute vending machine robot with a screen face and little arms" | 6 studs |
| 5 | Noodle Stall | "street food noodle stall with a hanging lantern sign and steaming pot" | 8 × 4 studs |
| 6 | Arcade Kiosk | "pair of retro arcade cabinets under a small glowing awning" | 8 × 8 studs |
| 7 | Hologram Idol | "abstract singer silhouette made of light ribbons on a round stage" (not a real or identifiable person) | 12 × 12 studs |
| 8 | Maglev Train | "three-car streamlined maglev train" | 60 studs |
| 9 | Blimp | "advertising blimp with a long screen band" | 80 studs |
| 10 | Trash-Bot | "round cleaning robot with a broom arm" | 3 studs |
| 11 | Holo Koi | "translucent glowing koi fish" | 4 studs |
| 12 | Receptionist Bot | "friendly receptionist robot torso with a screen face" | 5 studs |
| 13 | Uplink Dish | "satellite dish on a lattice tower" | 10 studs |
| 14 | City Crest Sculpture | "abstract tall sculpture of interlocking rings" | 30 studs |

Fallback for any prop that is unreadable after three tries: a primitive build in the same palette (option A). Every prop gets a `docs/assets/register.md` row before use (CLAUDE.md rule 9).

## 11. Screenshot gate (M2)

SHANNON reviews these five frames from the staging build:

1. Start-menu frame (GDD L test).
2. Street level in the Grid Plaza looking at two towers, rain on.
3. A full plaza with 40 crowd NPCs and every hype item.
4. Build mode: tower cross-section with a floor card open.
5. A 30-floor tower top with crown, from the Sky Deck, at Neon Night.

Each frame is captured on PC (High) and on a phone (graphics level auto). The gate passes when SHANNON rates each at least 4 out of 5 or names what to fix.

## 12. Performance checks

- Client part count in view ≤ 12,000; instance count total ≤ 60,000.
- Phone (SHANNON's device): ≥ 30 fps in the Grid Plaza with rain Low and 6 full towers; memory under 800 MB (Developer Console, Memory tab).
- PC mid (GTX 1060 class): ≥ 60 fps with rain High.
- Server heartbeat ≤ 8 ms at 6 players (GDD S).
