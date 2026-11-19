# 0088: Animal Stations: every animal and variant remade with ForgeGUI

Status: accepted (SHANNON, 2026-11-18: "these sheets are amazing make it exactly like those and make it so
it can upload animations to roblox or break it in blender whatever works best"); built by STATION-095.
Date: 2026-11-18. Task STATION-095.

## What SHANNON asked

New concepts for every animal and variant "following the look of the lion" SHANNON made on ForgeGUI
(faceted, spiky layered shapes, bold colours), then the models made exactly like the sheets, with the
animations kept working. One change: the Crystal Rhino keeps the current one's crystal formations
along its back.

## What was made

- Nine ForgeGUI concept sheets (one per species, the basic animal and its variants), and a single
  Crystal Rhino concept drawn from the current model's card.
- 26 ForgeGUI 3D models, one per animal and variant, each from its crop of the sheets.
- `tools/blender/stations/assets/forge.py` cuts each model into the seven pieces every clip already
  moves (body, head, tail, leg_fl, leg_fr, leg_bl, leg_br; the meerkats' arms and the flamingos'
  wings are the pieces the hand-built models used), caps the cuts, finds each joint where its piece
  meets the body, scales the model to the height its hand-built model had, and bakes the ForgeGUI
  texture into the usual 1024 atlas. `build.py` then exports it like any other model, so the upload
  workflow, the rainbow coats and `StationAssets.luau` work unchanged. The hand-built scripts stay;
  `forge.py` overrides the assets of the same names.

## Why cut in Blender rather than upload animations

Fact: ForgeGUI's animation output targets its own rig, and its Roblox animation upload route is
unavailable ("animation_intake_not_implemented", asset_capabilities v6). Fact: the game animates
every creature in code by posing Motor6Ds between named pieces (`Creatures.client.luau`). Cutting
the models into those pieces keeps every existing clip, attack and power move working with no game
code change.

## Known limits

- Assumption: the cuts are straight by face position, so a piece turned far shows a capped seam.
  The clips turn pieces little, so this should rarely show; checked only on still renders.
- Fact: the models are 11,000 to 19,600 triangles, against 1,000 to 12,000 for the hand-built ones.
  Hypothesis: a herd plus a wave on a phone may cost frames; not measured.
- Fact: no Neon `_glow` pieces: glows are painted in the texture, so they do not light up in the dark.
- Fact: the basic Meerkat's ForgeGUI model came out with a patchy face; worth a second try.
