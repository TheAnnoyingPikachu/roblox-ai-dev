# 0085: Animal Stations: a visual overhaul of the map and landscape (concept)

Status: proposed (a concept for SHANNON; nothing in the game is changed). Date: 2026-11-18. Task STATION-088.

## What SHANNON asked

"can you make a concept for a visual overhaul of the map and landscape to make the game look more
polished?"

## What was made (`docs/concepts/visual-overhaul-card.png`)

Not a painting: the real game in Studio (local build, stamp `dev`), before and after, from the same
two cameras: the ranch valley from above, and the homestead from beside the ring path. The "after" is
the settings below applied live in a Play session and thrown away when it stopped.

What looked unpolished before: the rock and mountains were bright purple-blue, the grass one flat
green, the paths dark brown strips, the trees smooth plastic balls, the ground bare between things.

## Step 1: the look (cheap, all in code: `World.luau`'s lighting, `Valley.colours`, part colours)

| | Before | After |
|---|---|---|
| Terrain rock / slate / basalt | 132,128,146 / 84,86,120 (purple-blue) | 138,138,124 / 118,120,112 / 110,106,100 (warm grey) |
| Grass / leafy grass / ground | 150,198,118 meadow green | 108,168,72 / 92,150,62 / 176,150,112 |
| Grass blades | off | `Terrain.Decoration` on, `GrassLength` 0.3 |
| Water | 64,170,226, 0.25 clear | 48,150,196, 0.35 clear, 0.45 reflection |
| Mountains and cliffs (538 parts) | purple-blue | three warm greys (150,142,132; 136,128,120; 164,154,140) |
| Snowcaps | plastic | Snow material |
| Paths (150 parts) | dark brown, plain | sandy (214,190,146 to 196,170,128), Sand material |
| Tree foliage (about 1,650 parts) | bright plastic green | Grass material, greens varied 84,150,64 to 126,176,70 |
| Time of day | 14:00 | 15:36: longer, warmer shadows |
| Light | brightness 2.6 | 3; shadow softness 0.35; warmer ambient |
| Atmosphere | density 0.28, haze 1.2 | density 0.33, haze 1.6, glare 0.35, a warm-violet decay |
| Grading | saturation +0.12 | saturation +0.08, contrast +0.1, a warm tint (255,246,232); bloom 0.35; sun rays 0.1; a light depth of field on far land |

Fact: all of it took one Studio session and no new models or uploads. Assumption: the hub and the
arena share the lighting, so they change too (not looked at yet).

## Step 2: the land itself (models and building work, later)

1. Trees: faceted low-poly tree models in three shapes, instead of plastic balls (an upload).
2. Path edges: a border of grass tufts and stones along each path; flower clumps by buildings.
3. Water: foam at the waterfall's foot and the lake's edge; the waterfall and bridges as models
   (polish plan 3.5).
4. Mountains: break up the round rock domes with ledges and pines on the sides players see.
5. Scattered life: rocks, logs, bushes in clusters rather than single dots.

## For SHANNON to decide

1. Step 1's look: go, or changes (the grass blades in particular: they look rich but hide small
   things on the ground and cost frame rate on phones; recommended: on, short, checked on a phone).
2. Whether to go on to step 2, and in what order (recommended: trees first, they are everywhere).

## Not done

Not looked at: the hub, the arena, a training ground close up, a phone, the frame rate with the grass
blades on.
