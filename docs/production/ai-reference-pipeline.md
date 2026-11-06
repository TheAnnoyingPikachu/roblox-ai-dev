# AI reference pipeline (Roblox Studio AI tools)

Studio's built-in AI tools are reached through the Roblox Studio MCP server. Use them as follows.

## 1. Creature and prop concepts: `generate_mesh`, then a Blender remake

Owner feedback (2026-11-06): the v0.2 Roblox-generated creatures were "the best so far", and the hand-built Blender ones "look silly". Studio has no plain image generator. Its text-to-3D generator is the closest thing, and its output is what the owner liked. We use it as concept art, then rebuild in Blender so the art stays editable, consistent and within budget.

Steps:

1. **Generate.** Open an empty place (`rojo build` of a baseplate project). Run `generate_mesh` with `segmentation: "none"`, `maxTriangles: 6000` and a size of about 3 x 4 x 3 studs.
   - Prompt template: `Cute chibi baby <animal> pet, big round head, large sparkly eyes, tiny body, <signature feature>, <palette>, kawaii plush toy style, <standing|sitting>, front facing`.
   - Run it with `async: true` and collect each job with `wait_job_finished`.
2. **Photograph.** The generated model faces -Z. Take `screen_capture` shots in Edit mode with camera params:
   - front at (x, 3, -7)
   - three-quarter at (x+5, 3.5, -5)
   - side at (x+6.5, 3, 0)
   - back at (x, 3, 7)
   - Set Lighting Brightness to 3 and Ambient to 120 grey.
   - Save the shots to `assets/<game>/refs/<id>_<angle>.jpg`.
   - Record the generated asset id in the table below.
3. **Remake.** The Blender artist rebuilds the creature in `tools/blender/<game>`, matching the reference's proportions, palette and face.
   - The face is what sells it: large glossy black eyes with two highlights, pink blush ovals, a tiny nose and mouth.
   - Shapes are soft plush: no hard creases.
   - Keep the HD kit standard (tools/blender/garden/README.md): the 6,000-tri limit applies.
4. **Compare.** Render the Blender model at the same angles and put each render beside its reference (`compare.py`). The Director signs off a creature only when the two read as the same character.
5. **Upload.** Upload as usual with `upload-assets.yml`.

Why not ship the generated meshes directly? Generated meshes vary run to run, can't be adjusted by hand (rarity variants, colours, size), and carry an unknown topology. The Blender remake keeps one style across all 26 creatures. If a remake can't match its reference, the fallback is to ship the generated mesh. That is a Director call, recorded in the table below.

## 2. Other tools

| Tool | Use | Notes |
|---|---|---|
| `generate_texture` / `generate_material` | Ground, path and wall surface ideas | Use as reference or as a MaterialVariant. Check the look under the game's lighting. |
| `generate_procedural_model` / `generate_scene` | Fast set-dressing blockouts | Replace with kit art before release. |
| `generate_animation` | R15 NPC or avatar emotes | Needs an R15 rig. Our creatures are single meshes with no rig, so they keep their tween bob/hop. |
| `character_navigation` | Bot play-tests during Studio integration and QA | Walk paths, check reachability and spawn. |
| `segment_mesh` | Split a generated mesh into parts | Only if a generated mesh is ever shipped. |

## Reference log

| Creature | Generated asset id | Shots | Remake status |
|---|---|---|---|
| bunny (Sprout Bunny) | 127619955912104 | front, side, back | Remade 2026-11-06 (`creature_bunny`, 5,820 tris), not uploaded; awaiting Director sign-off |
| fox (Cactus Fox) | 134610036961315 | front, 3/4, side, back | Remade 2026-11-06 (`creature_fox`, 5,692 tris; now orange, was green), not uploaded; awaiting Director sign-off |

Note: the generated fox came out with a pink flower, but no cactus. The remake adds a small cactus beside the flower so it stays a "Cactus Fox".

The remakes use the new kit helpers (`k.zone` fur markings, the soft painted blush, `sheen` eyes). The values to copy for the other creatures are in the "Reference remakes" section of `tools/blender/garden/README.md`.
