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
4. **Compare.** Render the Blender model at the same angles and put each render beside its reference (`tools/blender/garden/refcompare.py`, which renders from the exact Studio cameras). The Director signs off a creature only when the two read as the same character.
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
| frog (Toadstool Frog) | mesh 98421910616889 | front, 3/4, side, back | Remade 2026-11-06 (`creature_frog`, 5,652 tris; eye bumps gone, a much bigger cap), not uploaded; awaiting Director sign-off |
| duck (Puddle Duckling) | mesh 131856143120623 | front, 3/4, side, back | Remade 2026-11-06 (`creature_duck`, 5,704 tris; the puddle and lily-pad hat replaced by the reference's raindrop), not uploaded; awaiting Director sign-off |
| pup (Bumble Pup) | mesh 139385013071918 | front, 3/4, side, back | Remade 2026-11-06 (`creature_pup`, 5,918 tris; black floppy ears, black rump), not uploaded; awaiting Director sign-off |
| lamb (Clover Lamb) | mesh 122675872503273 | front, 3/4, side, back | Remade 2026-11-06 (`creature_lamb`, 5,688 tris; peach face, one clover), not uploaded; awaiting Director sign-off |
| puffin (Pebble Puffin) | mesh 120449235697125 | front, 3/4, side, back | Remade 2026-11-06 (`creature_puffin`, 5,796 tris; now hugs its pebble, thrift and base gone), not uploaded; awaiting Director sign-off |
| cat (Berry Cat) | mesh 130248145290438 | front, 3/4, side, back | Remade 2026-11-06 (`creature_cat`, 5,848 tris; now lavender with a berry cluster, was a red strawberry cat), not uploaded; awaiting Director sign-off |
| owl (Pumpkin Owl) | mesh 119820589314097 | front, 3/4, side, back | Remade 2026-11-06 (`creature_owl`, 5,956 tris; boxy pumpkin owl with white eye masks, spotted cream belly, curly stem), not uploaded; awaiting Director sign-off |
| hedgehog (Acorn Hedgehog) | mesh 100166956137262 | front, 3/4, side, back | Remade 2026-11-06 (`creature_hedgehog`, 5,978 tris; cream bean under a shaggy quill ball, big ribbed acorn cap), not uploaded; awaiting Director sign-off |
| otter (River Otter) | mesh 88831462996221 | front, 3/4, side, back | Remade 2026-11-06 (`creature_otter`, 4,476 tris; now sits up hugging a blue spiral shell, was floating on its back in a pool), not uploaded; awaiting Director sign-off |
| moth (Lantern Moth) | mesh 114037612386173 | front, 3/4, side, back | Remade 2026-11-06 (`creature_moth`, 5,878 tris; now cream with orange spotted wings and a lantern in each hand, was violet wings and one lantern), not uploaded; awaiting Director sign-off |
| turtle (Lotus Turtle) | mesh 119583747233159 | front, 3/4, side, back | Remade 2026-11-06 (`creature_turtle`, 5,648 tris; now stands up, mint with a peach plastron and a pink spiky lotus-bud shell, was a lotus flower shell), not uploaded; awaiting Director sign-off |
| capybara (Spa Capybara) | mesh 90805125810496 | front, 3/4, side, back | Remade 2026-11-06 (`creature_capybara`, 5,996 tris; mandarin and lilac on its head, rolled towel under its arm, was a towel on its head), not uploaded; awaiting Director sign-off |
| deer (Blossom Fawn) | mesh 101893019081162 | front, 3/4, side, back | Remade 2026-11-06 (`creature_deer`, 5,966 tris; standing on short legs, cream face, oval ears out flat, thick forked antlers with a blossom each, white spots, shaggy white chest bib, tufted tail; was blossom spots and long legs), not uploaded; awaiting Director sign-off |
| panda (Bamboo Panda) | mesh 87349524963791 | front, 3/4, side, back | Remade 2026-11-06 (`creature_panda`, 5,052 tris; bamboo shoot growing from its head, arms down its sides, was holding a tall bamboo stalk), not uploaded; awaiting Director sign-off |
| lion (Sunflower Lion) | mesh 82239738233120 | front, 3/4, side, back | Remade 2026-11-06 (`creature_lion`, 5,764 tris; tan cub with a big sunflower mane: rust ruffles inside two rows of yellow petals, seed-pod tail up its back; was gold with a seed-ring mane). Weakest of the batch: the petals are flat lobed discs, not the reference's ruffled leaves, and the ribbed knit fur is only a faint grain. Not uploaded; awaiting Director sign-off |
| redpanda (Maple Red Panda) | mesh 117069465060657 | front, 3/4, side, back | Remade 2026-11-06 (`creature_redpanda`, 5,124 tris; sits low with paws out in front, white-rimmed ears, red tear marks, ringed tail lying out behind, maple leaf on its head; was holding a big maple leaf), not uploaded; awaiting Director sign-off |
| unicorn (Daisy Unicorn) | mesh 129254112400052 | front, 3/4, side, back | Remade 2026-11-06 (`creature_unicorn`, 5,832 tris; pink mane of locks with a forelock, tan spiral cone horn, dark-blue eyes, one daisy; was a lilac mane full of daisies and gold hooves), not uploaded; awaiting Director sign-off |
| dragon (Moonblossom Dragon) | mesh 81876159923372 | front, 3/4, side, back | Remade 2026-11-06 (`creature_dragon`, 5,990 tris; sits up with curved pink-tipped horns, big pointed ears, cheek frills, cream plated belly, pink soles, small bat wings, tail with pink tip spikes; was white petal wings and a long snout), not uploaded; awaiting Director sign-off |

The frog to cat, owl to capybara and deer to dragon references came out turned 45 degrees towards +X, so their 3/4 shot is the true front (`TURN` in `tools/blender/garden/refcompare.py`).

Note: the generated fox came out with a pink flower, but no cactus. The remake adds a small cactus beside the flower so it stays a "Cactus Fox".

The remakes use the new kit helpers (`k.zone` fur markings, the soft painted blush, `sheen` eyes). The values to copy for the other creatures are in the "Reference remakes" section of `tools/blender/garden/README.md`.
